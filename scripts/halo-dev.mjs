#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// halo-dev: run this checkout's app and drive it from outside.
//
//   halo-dev web "<label>" [--port N] [--profile] [--onboard SPEC] [--first-op] [--no-bundle] [--fg|--bg] [-- flutter args]
//   halo-dev mac "<label>" [--data DIR] [--onboard SPEC] [--first-op] [--no-bundle] [--fg|--bg] [-- flutter args]
//   halo-dev status | reload | restart | stop | log [-n N] [--errors]       [--target web|mac]
//   halo-dev state | guess | build | targets | events | fixture            (native builds)
//   halo-dev run "<command text>" | tap <target> | field <name> <value>    (native builds)
//   halo-dev sandbox --from dev|next|prod [--to DIR] [--force]             (macOS)
//
// A run's state lives in <checkout>/.halo-run/<target>/: run.json, the run's
// log, the stdin pipe a background run reads its reload keys from, and the
// VM-service address `flutter run` writes out. The bridge calls talk to that
// address (the app's ext.halo.* extensions, app/lib/config/dev_bridge_io.dart);
// a web build answers the same calls as window.__halo in its browser tab
// instead, which no script reaches without one.

import { execFileSync, spawn } from 'node:child_process'
import { createHash } from 'node:crypto'
import fs from 'node:fs'
import net from 'node:net'
import os from 'node:os'
import path from 'node:path'

const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim()
const runRoot = path.join(root, '.halo-run')

// What a run prints once it is up, and what it prints when it is not going to
// be. Checked only until the first match: once the app runs, its own log
// lines say "Error:" for reasons that are not the run failing. "Failed to
// foreground app" is not on the list: a launch from a shell with no window
// of its own prints it and attaches all the same, and when the launch was
// handed to another instance instead, "Lost connection to device" follows.
const READY = {
  web: /is being served at (\S+)/,
  mac: /Flutter run key commands\.|A Dart VM Service on .* is available at/,
}
const FAILED = /Failed to bind|Address already in use|Failed to compile|: Error: |Error \(Xcode\)|Error launching application|Could not build the application|Lost connection to device|Unhandled exception/
// Hot reload / restart outcomes, in flutter run's wording. Anchored to the
// start of a line and case-sensitive: the app logs into the same file while
// the reload runs (its lines start "flutter: " on macOS), and its own "could
// not …" and "rejected" would otherwise read as the reload failing.
const RELOADED = /^Reloaded \d+ (of \d+ )?librar(y|ies)|^Reloaded application|^Restarted application/
const RELOAD_FAILED =
  /^(Hot reload was rejected|Hot (reload|restart) failed|Unable to hot (reload|restart)|Try again after fixing the above error|Recompile complete\. No client connected)|^\S+\.dart:\d+:\d+: Error: /
// The lines worth watching while iterating: ErrorPolicy keeps several error
// classes away from the operator, and the console is the only place they
// surface (docs/design/error-reporting.md).
const ERROR_LINES = /\[error-policy\]|\[error-reporting\]|EXCEPTION CAUGHT|Failed to compile|Lost connection|Reload rejected|was rejected/

const BUNDLE_IDS = { dev: 'com.ham2k.logger.dev', next: 'com.ham2k.logger.next', prod: 'com.ham2k.logger.prod' }
// Copied settings carry these ON, and each one reaches outside the sandbox:
// cloud sync pushes the copy's edits to the real account under the Dev
// keychain's identity, peer sync dials the LAN peers, and listening for other
// apps shares WSJT-X's port with the installed app, where a unicast datagram
// reaches only one of the two.
const SANDBOX_OFF = ['syncEnabled', 'peerSyncEnabled', 'listenForOtherAppsEnabled']

function fail(message, code = 1) {
  console.error(`halo-dev: ${message}`)
  process.exit(code)
}

function parseArgs(argv) {
  const flags = {}
  const positional = []
  let passthrough = []
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    if (arg === '--') {
      passthrough = argv.slice(i + 1)
      break
    }
    if (arg.startsWith('--')) {
      const [name, inline] = arg.slice(2).split(/=(.*)/s)
      const next = argv[i + 1]
      if (inline !== undefined) flags[name] = inline
      else if (VALUE_FLAGS.has(name) && next !== undefined) flags[name] = argv[++i]
      else flags[name] = true
    } else if (arg === '-n') {
      flags.n = argv[++i]
    } else {
      positional.push(arg)
    }
  }
  return { flags, positional, passthrough }
}
const VALUE_FLAGS = new Set(['port', 'onboard', 'data', 'target', 'from', 'to', 'label', 'n'])

const runDir = (target) => path.join(runRoot, target)
const runFile = (target, name) => path.join(runDir(target), name)

function readRun(target) {
  const file = runFile(target, 'run.json')
  let text
  try {
    text = fs.readFileSync(file, 'utf8')
  } catch (error) {
    if (error.code === 'ENOENT') return null
    throw error
  }
  try {
    return JSON.parse(text)
  } catch {
    fail(`${file} is not a run record — delete it if nothing is running`)
  }
}

/** The command line of [pid], or null when no such process exists. */
function commandOf(pid) {
  if (!pid) return null
  try {
    return execFileSync('ps', ['-p', String(pid), '-o', 'command='], { encoding: 'utf8' }).trim() || null
  } catch {
    return null
  }
}

/**
 * Whether [run]'s `flutter run` is still going. By command as well as pid:
 * .halo-run/ outlives a reboot, and by then the pid may be another
 * program's, which a stop would signal.
 */
function runAlive(run) {
  return commandOf(run?.pid)?.includes('flutter') ?? false
}

function alive(pid) {
  try {
    process.kill(pid, 0)
    return true
  } catch (error) {
    return error.code === 'EPERM'
  }
}

/** The runs of this checkout that are still alive. */
function liveRuns() {
  return ['web', 'mac'].map(readRun).filter(runAlive)
}

/** The run a command means: the one named by --target, else the only one. */
function pickRun(flags, { native = false } = {}) {
  const runs = liveRuns()
  if (flags.target) {
    const run = runs.find((r) => r.target === flags.target)
    if (!run) fail(`no ${flags.target} run is up in this checkout (halo-dev status)`)
    return run
  }
  const candidates = native ? runs.filter((r) => r.target !== 'web') : runs
  if (candidates.length === 1) return candidates[0]
  if (candidates.length === 0) {
    if (native && runs.some((r) => r.target === 'web')) {
      fail('a web build answers these calls as window.__halo in its browser tab; no native run is up here')
    }
    fail('nothing is running in this checkout — start one with `halo-dev web` or `halo-dev mac`')
  }
  fail(`several runs are up (${candidates.map((r) => r.target).join(', ')}); pick one with --target`)
}

const slug = (label) =>
  label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')

function portAnswers(port, host) {
  return new Promise((resolve) => {
    const socket = net.connect({ port, host })
    socket.once('connect', () => {
      socket.destroy()
      resolve(true)
    })
    socket.once('error', () => resolve(false))
    socket.setTimeout(500, () => {
      socket.destroy()
      resolve(false)
    })
  })
}

function portBinds(port) {
  return new Promise((resolve) => {
    const server = net.createServer()
    server.once('error', () => resolve(false))
    server.listen({ port, host: '127.0.0.1', exclusive: true }, () => server.close(() => resolve(true)))
  })
}

/**
 * The first port from [start] that nothing answers on and that binds. Both
 * checks, because a server holding the port on the other address family
 * answers without blocking the bind, and the new server would then come up
 * beside the old one while the browser keeps reaching the old.
 */
async function freePort(start) {
  for (let port = start; port < start + 50; port++) {
    if ((await portAnswers(port, '127.0.0.1')) || (await portAnswers(port, '::1'))) continue
    if (await portBinds(port)) return port
  }
  fail(`no free port in ${start}–${start + 49}`)
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

/**
 * [file] past byte [offset], decoded. The offset is a file size, so the cut
 * is made in the bytes: the log is full of multi-byte characters (—, 🔥), and
 * each one before the offset would move a cut made in the decoded text past
 * the start of the new output — past a short "Reloaded …" line entirely.
 */
function readFrom(file, offset) {
  const fd = fs.openSync(file, 'r')
  try {
    const buffer = Buffer.alloc(Math.max(0, fs.fstatSync(fd).size - offset))
    fs.readSync(fd, buffer, 0, buffer.length, offset)
    return buffer.toString('utf8')
  } finally {
    fs.closeSync(fd)
  }
}

/**
 * Waits for [pattern] (or [failure]) in [logPath] past [offset] — and past
 * the first line matching [after], when given. Answers the matching line, or
 * throws with the failing one.
 */
async function waitForLog(logPath, offset, { pattern, failure, timeoutMs, pid, after }) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    let lines = readFrom(logPath, offset).split('\n')
    if (after) {
      const start = lines.findIndex((line) => after.test(line))
      lines = start < 0 ? [] : lines.slice(start + 1)
    }
    for (const line of lines) {
      if (failure && failure.test(line)) throw new Error(line.trim())
      const match = line.match(pattern)
      if (match) return match
    }
    if (pid && !alive(pid)) throw new Error('the run exited')
    await sleep(500)
  }
  return null
}

function gitSha() {
  return execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim()
}

// ── Launching ───────────────────────────────────────────────────────────────

async function launch(target, { flags, positional, passthrough }) {
  const label = positional[0] ?? flags.label ?? process.env.DEV_LABEL
  if (!label || label === true) fail(`a label is required, naming the work at hand: halo-dev ${target} "<label>"`)
  const existing = readRun(target)
  if (runAlive(existing)) {
    fail(`a ${target} run is already up here (pid ${existing.pid}${existing.url ? `, ${existing.url}` : ''}) — \`halo-dev stop --target ${target}\` first`)
  }
  // A run that ended without `stop` (the app quit, flutter run died) can
  // leave its stdin holder, and on macOS its app — which the single-instance
  // guard would hand this launch to.
  await stopRun(existing, { quiet: true })
  if (target === 'mac' && process.platform !== 'darwin') fail('mac runs need macOS')

  const background = flags.bg === true || (flags.fg !== true && !process.stdin.isTTY)
  const dir = runDir(target)
  fs.mkdirSync(dir, { recursive: true })
  const logPath = runFile(target, 'log')
  const vmServicePath = runFile(target, 'vm-service-uri')
  fs.rmSync(vmServicePath, { force: true })

  const sha = gitSha()
  const defines = { DEV_LABEL: label, HALO_GIT_SHA: sha, HALO_DEV_WORKTREE: root }
  if (flags.onboard) defines.ONBOARD_AS = flags.onboard
  if (flags['first-op']) defines.POLO_OPEN_FIRST_OP = '1'
  const env = { ...process.env }
  const args = ['run']
  let port = null
  let dataDir = null
  if (target === 'web') {
    port = flags.port ? Number(flags.port) : await freePort(8767)
    if (flags.port && ((await portAnswers(port, '127.0.0.1')) || !(await portBinds(port)))) fail(`port ${port} is taken`)
    args.push('-d', 'web-server', '--web-port', String(port), '--web-hostname', '127.0.0.1')
  } else {
    // Always sandboxed: without it the single-instance guard hands the
    // launch to whichever build of this edition started first, and what
    // comes to the front is another checkout's code.
    dataDir = path.resolve(flags.data ?? path.join(root, '.halo-dev-data'))
    fs.mkdirSync(dataDir, { recursive: true })
    env.HALO_DEV_DATA = dataDir
    args.push('-d', 'macos', '--vmservice-out-file', vmServicePath)
  }
  if (flags.profile) args.push('--profile')
  for (const [key, value] of Object.entries(defines)) args.push(`--dart-define=${key}=${value}`)
  args.push(...passthrough)

  const logFd = fs.openSync(logPath, 'w')
  if (flags['no-bundle'] !== true) {
    console.log('▶ building the extension bundles')
    try {
      execFileSync('npm', ['run', 'build'], { cwd: path.join(root, 'extensions'), stdio: ['ignore', logFd, logFd] })
    } catch {
      fail(`the extension build failed — see ${logPath}`)
    }
  }

  // CocoaPods needs the ruby this project pins; `mise x` execs flutter in
  // its place, so the pid recorded below is flutter's own.
  const [command, commandArgs] = target === 'mac' ? ['mise', ['x', 'ruby@3.3.11', '--', 'flutter', ...args]] : ['flutter', args]
  const url = port ? `http://127.0.0.1:${port}/?${slug(label)}` : null
  const run = { target, label, url, port, log: logPath, dataDir, sha, profile: flags.profile === true, startedAt: new Date().toISOString() }

  if (!background) {
    fs.closeSync(logFd)
    console.log(`▶ ${command} ${commandArgs.join(' ')}`)
    if (url) console.log(`▶ open ${url} once it is served`)
    const child = spawn(command, commandArgs, { cwd: path.join(root, 'app'), env, stdio: 'inherit' })
    fs.writeFileSync(runFile(target, 'run.json'), JSON.stringify({ ...run, pid: child.pid, foreground: true, log: null }, null, 2))
    const forward = (signal) => child.kill(signal)
    process.on('SIGINT', forward)
    process.on('SIGTERM', forward)
    child.on('error', (error) => {
      fs.rmSync(runFile(target, 'run.json'), { force: true })
      fail(`cannot start ${command}: ${error.message}`)
    })
    child.on('exit', (code, signal) => {
      fs.rmSync(runFile(target, 'run.json'), { force: true })
      process.exit(code ?? (signal ? 1 : 0))
    })
    return
  }

  // A pipe the run reads its keys from (r, R, q). A process of its own
  // holds the write end open for the run's lifetime: with no writer left,
  // flutter run reads end-of-file and stops taking keys. The run cannot hold
  // that end itself — Dart's stdin reads nothing from a pipe opened
  // read-write.
  const stdinPath = runFile(target, 'stdin')
  fs.rmSync(stdinPath, { force: true })
  execFileSync('mkfifo', [stdinPath])
  const stdinFd = fs.openSync(stdinPath, fs.constants.O_RDONLY | fs.constants.O_NONBLOCK)
  const holdFd = fs.openSync(stdinPath, fs.constants.O_WRONLY)
  const holder = spawn('sleep', ['2147483647'], { stdio: ['ignore', holdFd, 'ignore'], detached: true })
  holder.unref()
  const offset = fs.fstatSync(logFd).size
  const child = spawn(command, commandArgs, { cwd: path.join(root, 'app'), env, stdio: [stdinFd, logFd, logFd], detached: true })
  child.unref()
  const spawnFailed = new Promise((_, reject) => child.once('error', (error) => reject(new Error(`cannot start ${command}: ${error.message}`))))
  fs.writeFileSync(runFile(target, 'run.json'), JSON.stringify({ ...run, pid: child.pid, holderPid: holder.pid }, null, 2))
  console.log(`▶ ${target} run started (pid ${child.pid}), log ${logPath}`)

  try {
    const timeoutMs = target === 'mac' ? 15 * 60_000 : 5 * 60_000
    const ready = await Promise.race([waitForLog(logPath, offset, { pattern: READY[target], failure: FAILED, timeoutMs, pid: child.pid }), spawnFailed])
    if (!ready) fail(`not up after ${timeoutMs / 60_000} minutes; still running — tail ${logPath}`, 2)
  } catch (error) {
    console.error(`halo-dev: the ${target} run failed: ${error.message}`)
    console.error(`halo-dev: see ${logPath}`)
    await stopRun(readRun(target), { quiet: true })
    process.exit(1)
  }
  console.log(url ? `✅ serving ${url}` : `✅ ${label} is running`)
  process.exit(0)
}

// ── Controlling a run ───────────────────────────────────────────────────────

function sendKey(run, key) {
  if (run.foreground) fail(`that run is in a terminal of its own — press ${key} there`)
  const fd = fs.openSync(runFile(run.target, 'stdin'), fs.constants.O_WRONLY | fs.constants.O_NONBLOCK)
  fs.writeSync(fd, `${key}\n`)
  fs.closeSync(fd)
}

async function reload(flags, key) {
  const run = pickRun(flags)
  if (run.foreground) fail(`that run is in a terminal of its own — press ${key} there`)
  if (run.profile) fail('a profile build cannot hot reload — stop it and launch again')
  const offset = fs.statSync(run.log).size
  sendKey(run, key)
  try {
    // From flutter run's own start line on: the previous reload's last lines
    // can still be landing when this one's key goes in.
    const done = await waitForLog(run.log, offset, { pattern: RELOADED, failure: RELOAD_FAILED, timeoutMs: 120_000, pid: run.pid, after: /^Performing hot (reload|restart)/ })
    if (!done) {
      const last = readFrom(run.log, offset).trim().split('\n').pop()
      fail(`no answer from the run after 2 minutes, last at "${last}" — it may be stuck; \`halo-dev stop\` and launch again\nsee ${run.log}`, 2)
    }
    console.log(`✅ ${done[0]}`)
  } catch (error) {
    if (/No client connected/.test(error.message)) fail(`no browser has the app open — open ${run.url} first`)
    // A rejected reload keeps the old code running, and nothing on screen
    // says so.
    fail(`${key === 'r' ? 'hot reload' : 'hot restart'} failed, the run still has the OLD code: ${error.message}\nsee ${run.log}`)
  }
}

/** Sends [signal] to [pid]; a process already gone is not an error. */
function signal(pid, name) {
  try {
    process.kill(pid, name)
  } catch (error) {
    if (error.code !== 'ESRCH') fail(`cannot signal pid ${Math.abs(pid)}: ${error.code ?? error.message}`)
  }
}

/** This checkout's macOS app processes, whoever started them. */
function macAppPids() {
  const products = path.join(root, 'app', 'build', 'macos', 'Build', 'Products')
  const pids = []
  for (const line of execFileSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' }).split('\n')) {
    const [, pid, commandLine] = line.match(/^\s*(\d+) (.*)$/) ?? []
    if (commandLine?.startsWith(products)) pids.push(Number(pid))
  }
  return pids
}

/**
 * Ends [run] — quitting it, else signalling it — and what it leaves behind,
 * and says so only once nothing of it is left. A run in a terminal of its
 * own is that terminal's to stop.
 */
async function stopRun(run, { quiet = false } = {}) {
  if (!run) return
  if (runAlive(run)) {
    if (run.foreground) fail('that run is in a terminal of its own — press q there')
    // q quits the app as well as flutter run; killing flutter run alone
    // leaves the app it launched running.
    sendKey(run, 'q')
    for (let i = 0; i < 40 && runAlive(run); i++) await sleep(500)
    // A run stuck mid-reload ignores SIGTERM.
    for (const name of ['SIGTERM', 'SIGKILL']) {
      if (!runAlive(run)) break
      signal(-run.pid, name)
      for (let i = 0; i < 10 && runAlive(run); i++) await sleep(500)
    }
    if (runAlive(run)) fail(`flutter run (pid ${run.pid}) outlived SIGKILL; ${runFile(run.target, 'run.json')} is left in place`)
  }
  if (commandOf(run.holderPid)?.startsWith('sleep ')) signal(run.holderPid, 'SIGTERM')
  // The macOS app is launched through `open`, outside the run's process
  // group, so it outlives a run that had to be killed rather than quit — and
  // one wedged in its shutdown ignores SIGTERM.
  if (run.target === 'mac') {
    let pids = macAppPids()
    for (const name of ['SIGTERM', 'SIGKILL']) {
      if (pids.length === 0) break
      for (const pid of pids) signal(pid, name)
      for (let i = 0; i < 10 && (pids = macAppPids()).length; i++) await sleep(500)
    }
    if (pids.length) fail(`the app outlived SIGKILL (pid ${pids.join(', ')})`)
  }
  fs.rmSync(runFile(run.target, 'run.json'), { force: true })
  fs.rmSync(runFile(run.target, 'stdin'), { force: true })
  if (!quiet) console.log(`✅ stopped the ${run.target} run`)
}

function status() {
  const runs = ['web', 'mac'].map(readRun).filter(Boolean)
  if (runs.length === 0) return console.log('nothing is running in this checkout')
  for (const run of runs) {
    const state = runAlive(run) ? 'up' : 'gone (`halo-dev stop` clears what it left)'
    console.log(`${run.target}  ${state}  pid ${run.pid}  "${run.label}"  ${run.url ?? run.dataDir ?? ''}${run.foreground ? '  (in a terminal)' : ''}`)
    if (run.log) console.log(`     log ${run.log}`)
  }
}

function showLog(flags) {
  const run = pickRun(flags)
  if (!run.log) fail('that run is in a terminal of its own; its output is there')
  let lines = fs.readFileSync(run.log, 'utf8').split('\n')
  if (flags.errors) lines = lines.filter((line) => ERROR_LINES.test(line))
  const n = Number(flags.n ?? 40)
  console.log(lines.slice(-n).join('\n'))
}

// ── Bridge calls over the VM service ────────────────────────────────────────

async function callBridge(flags, method, params = {}, { timeoutMs = 30_000 } = {}) {
  const run = pickRun(flags, { native: true })
  let uri
  try {
    uri = fs.readFileSync(runFile(run.target, 'vm-service-uri'), 'utf8').trim()
  } catch {
    fail('the run has not published its VM service yet — is it still building?')
  }
  const wsUri = `${uri.replace(/^http/, 'ws').replace(/\/?$/, '/')}ws`
  const socket = new WebSocket(wsUri)
  const pending = new Map()
  let nextId = 1
  const call = (rpc, rpcParams = {}) =>
    new Promise((resolve, reject) => {
      const id = String(nextId++)
      const timer = setTimeout(() => {
        pending.delete(id)
        reject(new Error(`no answer to ${rpc} after ${timeoutMs / 1000}s — the app may be stuck, or waiting on a dialog`))
      }, timeoutMs)
      const settle = (fn) => (value) => {
        clearTimeout(timer)
        fn(value)
      }
      pending.set(id, { resolve: settle(resolve), reject: settle(reject) })
      socket.send(JSON.stringify({ jsonrpc: '2.0', id, method: rpc, params: rpcParams }))
    })
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data)
    const waiter = pending.get(message.id)
    if (!waiter) return
    pending.delete(message.id)
    if (message.error) waiter.reject(new Error(message.error.data?.details ?? message.error.message))
    else waiter.resolve(message.result)
  })
  socket.addEventListener('close', () => {
    for (const waiter of pending.values()) waiter.reject(new Error('the VM service closed the connection — has the app quit?'))
    pending.clear()
  })
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true })
    socket.addEventListener('error', () => reject(new Error(`cannot reach the VM service at ${wsUri} — has the run stopped?`)), { once: true })
  }).catch((error) => fail(error.message))

  try {
    const vm = await call('getVM')
    let isolateId = null
    for (const ref of vm.isolates) {
      const isolate = await call('getIsolate', { isolateId: ref.id })
      if (isolate.extensionRPCs?.includes(`ext.halo.${method}`)) isolateId = ref.id
    }
    if (!isolateId) fail(`the app does not answer ext.halo.${method} — a build from before the bridge, or still booting`)
    const stringParams = Object.fromEntries(Object.entries(params).map(([k, v]) => [k, String(v)]))
    const result = await call(`ext.halo.${method}`, { isolateId, ...stringParams })
    return result.result
  } catch (error) {
    fail(error.message)
  } finally {
    socket.close()
  }
}

const print = (value) => console.log(JSON.stringify(value, null, 2))

/**
 * Prints a bridge answer, and exits non-zero when [failed]: the app answers
 * a call that did not do its job with an ordinary result, and a script
 * chaining calls must not carry on past one.
 */
function answer(value, failed) {
  print(value)
  if (failed) process.exit(1)
}

function sha256File(file) {
  try {
    return createHash('sha256').update(fs.readFileSync(file)).digest('hex')
  } catch {
    return null
  }
}

/** What the build says it is, against what this checkout holds now. */
async function build(flags) {
  const info = await callBridge(flags, 'build')
  const extensions = info.extensions ?? {}
  delete info.extensions
  print(info)
  const notes = []
  if (info.worktree && path.resolve(info.worktree) !== root) notes.push(`⚠️  built from ${info.worktree}, not this checkout`)
  if (!info.worktree) notes.push('⚠️  not started by halo-dev: it cannot say which checkout it came from')
  const head = gitSha()
  if (info.sha && info.sha !== head) notes.push(`⚠️  built at ${info.sha}; this checkout is now at ${head}`)
  const dirty = execFileSync('git', ['status', '--porcelain', '--untracked-files=no'], { cwd: root, encoding: 'utf8' }).trim()
  if (dirty) notes.push('ℹ️  uncommitted changes: it has them only if they were hot-reloaded in')
  const stale = []
  for (const [key, bundle] of Object.entries(extensions)) {
    if (bundle.origin !== 'asset') continue
    const onDisk = sha256File(path.join(root, 'app', 'assets', 'extensions', bundle.file))
    if (onDisk !== bundle.sha256) stale.push(onDisk ? key : `${key} (gone from disk)`)
  }
  if (stale.length) notes.push(`⚠️  extension bundles rebuilt since they loaded (a restart loads them): ${stale.join(', ')}`)
  const served = Object.entries(extensions).filter(([, b]) => b.origin === 'devServer').map(([k]) => k)
  if (served.length) notes.push(`ℹ️  from the extension dev server: ${served.join(', ')}`)
  const count = Object.keys(extensions).length
  if (count === 0) notes.push('⚠️  it reports no extension bundles loaded: still booting, or its runtime failed to start')
  console.log(notes.length ? notes.join('\n') : '✅ matches this checkout')
  console.log(`   ${count} extension bundles loaded, ${stale.length} rebuilt on disk since`)
}

// ── Sandbox from an installed edition ───────────────────────────────────────

/**
 * Whether [file] exists. Unlike fs.existsSync, a file macOS will not let
 * this terminal read is an error, not an absence: reading another app's
 * container needs the terminal's own permission, and "no data" would send
 * the developer looking in the wrong place.
 */
function exists(file) {
  try {
    fs.statSync(file)
    return true
  } catch (error) {
    if (error.code === 'ENOENT') return false
    if (error.code === 'EPERM' || error.code === 'EACCES') {
      fail(`macOS will not let this terminal read ${file} — allow it under System Settings › Privacy & Security › App Management (or Full Disk Access), then run this again`)
    }
    throw error
  }
}

function sandbox(flags) {
  if (process.platform !== 'darwin') fail('sandbox copies a macOS edition; on other platforms copy by hand (DEVELOPMENT.md)')
  const edition = flags.from
  const bundle = BUNDLE_IDS[edition]
  if (!bundle) fail('--from dev|next|prod names the installed edition to copy')
  const src = path.join(os.homedir(), 'Library', 'Containers', bundle, 'Data')
  const database = path.join(src, 'Documents', 'ham2k_logger.sqlite')
  if (!exists(database)) fail(`no ${edition} data at ${src}`)
  const dest = path.resolve(flags.to ?? path.join(root, '.halo-dev-data'))
  const mac = readRun('mac')
  if (runAlive(mac) && mac.dataDir === dest) fail('the mac run is using that sandbox — halo-dev stop --target mac first')
  if (fs.existsSync(dest) && fs.readdirSync(dest).length > 0) {
    if (flags.force !== true) fail(`${dest} already holds a sandbox — --force sets it aside (renamed, not deleted) and copies a fresh one`)
    const aside = `${dest}.bak-${new Date().toISOString().replace(/[:.]/g, '-')}`
    fs.renameSync(dest, aside)
    console.log(`▶ the old sandbox is now ${aside}`)
  }
  fs.mkdirSync(dest, { recursive: true })
  // .backup, not a file copy: it reads a database that is open and mid-write
  // consistently.
  execFileSync('sqlite3', [database, `.backup '${path.join(dest, 'ham2k_logger.sqlite').replace(/'/g, "''")}'`])
  const copied = ['log']
  const missing = []
  for (const dir of ['extensions', 'data_files']) {
    const from = path.join(src, 'Documents', dir)
    if (!exists(from)) {
      missing.push(dir)
      continue
    }
    fs.cpSync(from, path.join(dest, dir), { recursive: true })
    copied.push(dir)
  }
  // The sandbox keeps its settings as JSON, not in the bundle's plist; the
  // values JSON cannot carry (data, dates) stay behind.
  const plist = path.join(src, 'Library', 'Preferences', `${bundle}.plist`)
  const convert = `
import datetime, json, plistlib, sys
prefs = plistlib.load(open(sys.argv[1], 'rb'))
out = {k: v for k, v in prefs.items() if k.startswith('flutter.') and not isinstance(v, (bytes, datetime.datetime))}
for key in sys.argv[3:]:
    out['flutter.' + key] = False
json.dump(out, open(sys.argv[2], 'w'))
`
  if (exists(plist)) {
    execFileSync('python3', ['-I', '-c', convert, plist, path.join(dest, 'shared_preferences.json'), ...SANDBOX_OFF])
    copied.push('settings')
  } else {
    fs.writeFileSync(path.join(dest, 'shared_preferences.json'), JSON.stringify(Object.fromEntries(SANDBOX_OFF.map((k) => [`flutter.${k}`, false]))))
    missing.push('settings')
  }
  console.log(`✅ copied ${edition}'s ${copied.join(', ')} into ${dest}`)
  if (missing.includes('settings')) console.log(`⚠️  ${edition} has no settings file: the sandbox starts from defaults, with no callsign or equipment`)
  if (missing.length) console.log(`   not in ${edition}'s data, so not copied: ${missing.join(', ')}`)
  console.log(`   turned off: ${SANDBOX_OFF.join(', ')}`)
  console.log('   secrets stay in the keychain under their own bundle id: equipment that needs a password asks again')
}

// ── Entry ───────────────────────────────────────────────────────────────────

const HELP = fs
  .readFileSync(new URL(import.meta.url), 'utf8')
  .split('\n')
  .slice(4, 12)
  .map((line) => line.replace(/^\/\/ ?/, ''))
  .join('\n')

const [command, ...rest] = process.argv.slice(2)
const parsed = parseArgs(rest)
const { flags, positional } = parsed

switch (command) {
  case 'web':
  case 'mac':
    await launch(command, parsed)
    break
  case 'status':
    status()
    break
  case 'reload':
    await reload(flags, 'r')
    break
  case 'restart':
    await reload(flags, 'R')
    break
  case 'stop': {
    // Runs that ended without a stop are cleared too: their holder, and on
    // macOS an app still running from this checkout.
    const ended = ['web', 'mac'].map(readRun).filter((run) => run && !runAlive(run) && (!flags.target || run.target === flags.target))
    for (const run of ended) {
      await stopRun(run, { quiet: true })
      console.log(`✅ cleared what the ended ${run.target} run left behind`)
    }
    if (ended.length === 0 || liveRuns().some((run) => !flags.target || run.target === flags.target)) await stopRun(pickRun(flags))
    break
  }
  case 'log':
    showLog(flags)
    break
  case 'state':
  case 'guess':
  case 'targets':
  case 'commandBarState':
    print(await callBridge(flags, command))
    break
  case 'events':
    print(await callBridge(flags, 'recentLog'))
    break
  case 'fixture': {
    const result = await callBridge(flags, 'resetFixture')
    answer(result, result?.error)
    break
  }
  case 'ready':
    if ((await callBridge(flags, 'ready', { timeoutMs: 60000 }, { timeoutMs: 70_000 })) !== true) fail('not ready after 60 seconds')
    console.log('✅ ready')
    break
  case 'build':
    await build(flags)
    break
  case 'run':
    if (!positional.length) fail('run "<command text>"')
    {
      const result = await callBridge(flags, 'runCommand', { text: positional.join(' ') }, { timeoutMs: 120_000 })
      answer(result, result?.error || result?.outcome !== 'ran')
    }
    break
  case 'tap':
    if (!positional.length) fail('tap <identifier or label>')
    {
      const result = await callBridge(flags, 'tap', { target: positional.join(' ') })
      answer(result, result?.error)
    }
    break
  case 'field':
    if (positional.length < 2) fail('field <name> <value>')
    {
      const result = await callBridge(flags, 'setField', { field: positional[0], value: positional.slice(1).join(' ') })
      answer(result, result?.error)
    }
    break
  case 'sandbox':
    sandbox(flags)
    break
  case undefined:
  case 'help':
  case '--help':
    console.log(HELP)
    break
  default:
    fail(`unknown command "${command}"\n${HELP}`)
}
