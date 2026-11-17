#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The dev loop for an extension built outside the Ham2K Logger repository.
//
//   npx h2kext-dev                 # the extension in the current directory
//   npx h2kext-dev --port 9000     # default 8787
//   npx h2kext-dev --host 127.0.0.1
//
// Builds the extension in memory through the same preset `build.mjs` uses,
// rebuilds as files are saved, and serves the result to the app's
// Settings → Developer → Extension Dev Server, which swaps that one extension
// in a running app without an install. What the extension logs comes back
// here, so an author working against a phone reads their own lines in this
// terminal.
//
// It speaks the one protocol the app's dev client knows, shared with the
// repository's own dev server (extensions/dev-server.mjs), which imports the
// constants and helpers below rather than keeping a copy: `/ping`,
// `/index.json`, `/<key>.js`, `/events` as Server-Sent Events, `POST /logs`.
// Server-Sent Events plus a plain POST rather than a WebSocket, so neither
// side needs a dependency: Node has no WebSocket server built in, and a reload
// notification is one-way.
//
// The app is pointed at a LAN address, not a local path, because the app is
// usually on a phone. 0.0.0.0 by default for that reason.
//
// The manifest is held to what the packer would accept. A dev-served bundle
// is installed with none of the packer's checks, so a manifest the packer
// refuses is reported here as a build error rather than handed to the app,
// where it would run and then fail to pack.

import { realpathSync } from "node:fs"
import { readFile, watch } from "node:fs/promises"
import { createServer } from "node:http"
import { createRequire } from "node:module"
import { isIP } from "node:net"
import { hostname, networkInterfaces } from "node:os"
import { join, resolve } from "node:path"
import { pathToFileURL } from "node:url"

import { ABOUT_FILE, buildOptionsFor, withAboutFiles } from "./h2kext-build.mjs"
import { indexEntryFor, MANIFEST_ENTRY, validateManifest } from "./h2kext.mjs"

/// The protocol the app's dev client speaks. Bumped when the shape below
/// changes, so an app built against another says so instead of failing
/// obscurely; it moves together with the repository's dev server (which
/// imports it) and the app's client.
export const PROTOCOL = 1

/// What `/ping` answers as `server`. The app's client refuses any other
/// value, so the repository's dev server and this one answer the same name.
export const SERVER_NAME = "halo-ext-dev"

export const DEFAULT_PORT = 8787

/// What `/<key>.js` serves while there is no good build yet: an extension the
/// app can load that registers nothing. Serving it, rather than a 404, is what
/// lets the app connect at all — its client fetches every listed bundle before
/// it subscribes to events, and a bundle it cannot fetch ends the connection
/// before the error backlog is read.
export const EMPTY_BUNDLE = "// h2kext-dev: nothing has built yet; the error is in the terminal and on the app's dev server screen\n"

/// A usage error: the author typed something this tool cannot act on.
export class DevServerError extends Error {}

/// What the command line asked for. Throws [DevServerError] for a flag it does
/// not know or a port it cannot listen on.
export function parseArgs(argv) {
  const options = { dir: process.cwd(), host: "0.0.0.0", port: DEFAULT_PORT, entry: "src/index.ts", inline: [], allowOrigins: [] }
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    const value = () => {
      if (i + 1 >= argv.length) throw new DevServerError(`${arg} needs a value`)
      i += 1
      return argv[i]
    }
    switch (arg) {
      case "--port": {
        const raw = value()
        const port = Number(raw)
        // Checked rather than trusted: `server.listen(NaN)` does not throw, it
        // binds an ephemeral port, and the first thing anyone does with this
        // tool is read a URL off the screen that would then name a port
        // nothing is listening on.
        if (!/^\d+$/.test(raw) || !Number.isInteger(port) || port < 1 || port > 65535) {
          throw new DevServerError(`--port must be a number between 1 and 65535, not "${raw}"`)
        }
        options.port = port
        break
      }
      case "--host":
        options.host = value()
        break
      case "--entry":
        options.entry = value()
        break
      case "--inline":
        options.inline = value()
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean)
        break
      case "--dir":
        options.dir = resolve(value())
        break
      case "--force-name":
        options.forceName = true
        break
      case "--allow-origin":
        options.allowOrigins.push(webOrigin(value()))
        break
      case "--help":
      case "-h":
        options.help = true
        break
      default:
        throw new DevServerError(`unknown option ${arg}`)
    }
  }
  return options
}

/// [text] as the origin a browser sends (`http://10.0.0.5:8080`, no path),
/// which is what [originAllowed] compares; a usage error when it names none.
export function webOrigin(text) {
  let url
  try {
    url = new URL(text)
  } catch {
    throw new DevServerError(`--allow-origin needs a web origin such as http://10.0.0.5:8080, not "${text}"`)
  }
  if (url.origin === "null") throw new DevServerError(`--allow-origin needs a web origin such as http://10.0.0.5:8080, not "${text}"`)
  return url.origin
}

export const USAGE = `usage: h2kext-dev [--port <n>] [--host <address>] [--entry <file>] [--inline <pkg,…>] [--dir <path>] [--force-name] [--allow-origin <origin>]

Serves the extension in the current directory to the app's Extension Dev
Server (Settings → Developer), rebuilding it as you save and printing what it
logs. Point the app at one of the addresses it prints.

  --port    the port to listen on (default ${DEFAULT_PORT})
  --host    the address to bind (default 0.0.0.0, so a phone on the LAN can connect)
  --entry   the entry point (default src/index.ts); pass what build.mjs passes
  --inline  shared libraries to bundle rather than take from the app; pass what build.mjs passes
  --dir     the extension directory (default the current directory)
  --force-name  Ham2K's own extensions: waives the key convention, as h2kext-pack's does
  --allow-origin  a web page that may use this server besides the app's own web build (repeatable), e.g. http://10.0.0.5:8080`

/// The author's own esbuild, resolved from their project rather than from
/// wherever this file is installed: the preset is written to use the caller's
/// copy, and a second one would be a second version with its own opinions.
export async function loadEsbuild(dir) {
  const require = createRequire(resolve(dir, "noop.js"))
  let path
  try {
    path = require.resolve("esbuild")
  } catch {
    throw new DevServerError("esbuild is not installed in this project — `npm install --save-dev esbuild`")
  }
  return import(pathToFileURL(path).href)
}

/// The two manifest fields the build itself depends on, beyond what the
/// bundle imports: `sharedDependencies` decides which imports become lookups
/// on the app's copy, `api` whether the timer globals are injected. A change
/// to either needs a new build context; everything else travels with a
/// reload.
function buildShape(manifest) {
  return JSON.stringify({ api: manifest.api ?? null, sharedDependencies: manifest.sharedDependencies ?? null })
}

/// Serves one extension directory to the app. [esbuild] is the author's
/// module (its `context` is what is used); [log] and [warn] receive every line
/// this would print, so a caller may route them.
///
/// Resolves once the first build has settled, built or failed, with the
/// listening `port`, a `url` on localhost, the LAN `addresses` to print, and
/// `close()`, which stops watching and listening.
export async function createDevServer({
  dir,
  esbuild,
  host = "0.0.0.0",
  port = DEFAULT_PORT,
  entry = "src/index.ts",
  inline = [],
  forceName = false,
  allowOrigins = [],
  log = console.log,
  warn = console.error,
}) {
  const manifestPath = join(dir, MANIFEST_ENTRY)
  let startManifestText
  try {
    startManifestText = await readFile(manifestPath, "utf8")
  } catch (e) {
    throw new DevServerError(`could not read ${manifestPath}: ${e.message}`)
  }
  let startManifest
  try {
    startManifest = JSON.parse(startManifestText)
  } catch (e) {
    throw new DevServerError(`${MANIFEST_ENTRY} is not JSON: ${e.message}`)
  }
  // The key names the bundle on every route, so a manifest without a usable
  // one has nothing this tool can serve under. Every other problem is a build
  // error the app is told about, below.
  const key = typeof startManifest.key === "string" && /^[a-z0-9][a-z0-9-]*$/.test(startManifest.key) ? startManifest.key : null
  if (!key) throw new DevServerError(`${MANIFEST_ENTRY}: 'key' must be lowercase letters, digits and hyphens`)

  /// The built bundle, the manifest it was built against, and the last build
  /// error. A failed build keeps serving the previous bundle: the app asked
  /// for what builds, and a half-written file mid-keystroke is no reason to
  /// take the extension away. Until there is a good build, the index lists
  /// the extension from the manifest as it stands and the bundle route serves
  /// [EMPTY_BUNDLE], so the app connects and hears the error.
  let source = null
  // Folded now as well, so an index served before the first good build lists
  // the extension as it will ship; a problem with the files is the first
  // build's to report.
  let servedManifest = await withAboutFiles(startManifest, dir).catch(() => startManifest)
  let servedManifestText = null
  let buildError = null
  const clients = new Set()
  let watching = false

  function fail(message) {
    // The same failure again is not news, as an unchanged good build is not:
    // a rebuild with nothing new to say — a late file event, a save that
    // changed nothing — would otherwise repeat the error to the app, ahead
    // of the reload the next real change brings.
    if (buildError === message) return
    buildError = message
    if (watching) {
      warn(`${stamp()}  ✗ ${key}\n${message}`)
      broadcast(clients, { type: "buildError", key, message })
    }
  }

  /// Re-reads the manifest after a rebuild. The scaffold's entry imports it,
  /// so editing it rebuilds; a project that does not import it is covered by
  /// the directory watch below. Validated as the packer validates, so
  /// `domains` travels with the reload and a manifest the packer would refuse
  /// never reaches the app.
  async function currentManifest() {
    const text = await readFile(manifestPath, "utf8")
    let parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      throw new Error(`${MANIFEST_ENTRY}: ${e.message}`)
    }
    // As the build folds them in, so the dialog shows what will ship. The
    // text compared for "unchanged" is the folded one: an edit to ABOUT.md
    // alone is a reload too.
    parsed = await withAboutFiles(parsed, dir)
    const problems = validateManifest(parsed, { forceName })
    if (problems.length) throw new Error(problems.join("\n"))
    if (parsed.key !== key) throw new Error(`${MANIFEST_ENTRY}: 'key' changed from ${key} to ${parsed.key}; restart h2kext-dev to serve it`)
    return { parsed, text: JSON.stringify(parsed) }
  }

  /// The esbuild context, rebuilt from scratch when the manifest changes in
  /// a way the build options depend on (see [buildShape]); `ctx` is always
  /// the live one.
  let ctx = null
  let ctxShape = null
  let settleBuild = null
  const nextBuild = () =>
    new Promise((r) => {
      settleBuild = r
    })

  const plugin = {
    name: "h2kext-dev-serve",
    setup(build) {
      build.onEnd(async (result) => {
        try {
          let current = null
          let manifestProblem = null
          try {
            current = await currentManifest()
          } catch (e) {
            manifestProblem = e.message
          }
          if (current && buildShape(current.parsed) !== ctxShape) {
            // This context was built with options from a manifest that no
            // longer describes the bundle: a newly declared library is still
            // inlined (or still refused as undeclared), a raised `api` still
            // lacks its timers. Whatever this build produced, errors included,
            // is not the answer; a new context builds it right.
            servedManifest = current.parsed
            queueMicrotask(() => restartContext(current.parsed))
            return
          }
          if (result.errors.length) {
            fail(result.errors.map((e) => `${e.location ? `${e.location.file}:${e.location.line}: ` : ""}${e.text}`).join("\n"))
            return
          }
          if (manifestProblem !== null) {
            // The bundle that just built embeds the OLD manifest, so serving
            // it would quietly disagree with the file on disk.
            fail(manifestProblem)
            return
          }
          // Recovering from a build error is a reload even when the bytes are
          // the last good ones, which is what undoing a typo produces: the app
          // clears the error only when a reload arrives.
          const hadError = buildError !== null
          buildError = null
          const built = result.outputFiles[0].text
          const unchanged = source === built && servedManifestText === current.text && !hadError
          source = built
          servedManifest = current.parsed
          servedManifestText = current.text
          if (!watching || unchanged) return
          log(`${stamp()}  ✓ ${key} — ${(result.outputFiles[0].contents.byteLength / 1024).toFixed(1)} KB`)
          broadcast(clients, { type: "reload", key, ...indexEntryFor(key, servedManifest) })
        } finally {
          settleBuild?.()
        }
      })
    },
  }

  async function startContext(manifest) {
    const options = buildOptionsFor({
      entry: join(dir, entry),
      manifest,
      dir,
      inline,
      absWorkingDir: dir,
      // Errors must not abort the loop: an author saves broken code constantly,
      // and the job is to report it and stay up.
      logLevel: "silent",
      plugins: [plugin],
    })
    ctxShape = buildShape(manifest)
    const built = nextBuild()
    ctx = await esbuild.context(options)
    await ctx.watch()
    await built
  }

  let restarting = Promise.resolve()
  function restartContext(manifest) {
    restarting = restarting.then(async () => {
      const old = ctx
      ctx = null
      await old?.dispose()
      await startContext(manifest)
    })
    return restarting
  }

  await startContext(startManifest)
  await restarting
  watching = true

  // The manifest may change without changing any bundle input (an entry that
  // does not import it), and an editor that saves by writing a temporary file
  // and renaming it replaces the file's inode, which a watch on the file alone
  // would lose. So the directory is watched, for that one name — and for the
  // ABOUT files, which reach the manifest the same way.
  const manifestWatch = new AbortController()
  ;(async () => {
    try {
      for await (const event of watch(dir, { signal: manifestWatch.signal })) {
        if (event.filename !== MANIFEST_ENTRY && !ABOUT_FILE.test(event.filename ?? "")) continue
        await restarting
        await ctx?.rebuild().catch(() => {})
      }
    } catch (e) {
      if (e.name !== "AbortError") warn(`${stamp()}  ! stopped watching ${MANIFEST_ENTRY}: ${e.message}`)
    }
  })()

  const server = createServer(
    serveSafely(async (req, res) => {
      if (guardRequest(req, res, { allowOrigins })) return
      const path = requestPath(req)
      if (path === null) {
        res.writeHead(400, { "content-type": "text/plain" })
        res.end("bad request target")
        return
      }

      if (path === "/ping") return json(res, { server: SERVER_NAME, protocol: PROTOCOL, extensions: [key] })

      if (path === "/index.json") return json(res, { extensions: [indexEntryFor(key, servedManifest)] })

      if (path === "/events") {
        res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-cache", connection: "keep-alive" })
        // The backlog: an extension whose first build failed is being served as
        // [EMPTY_BUNDLE], and this is how the app learns why.
        res.write(`data: ${JSON.stringify({ type: "hello", protocol: PROTOCOL, buildErrors: buildError === null ? {} : { [key]: buildError } })}\n\n`)
        clients.add(res)
        log(`${stamp()}  ▸ app connected (${clients.size} connected)`)
        req.on("close", () => {
          clients.delete(res)
          log(`${stamp()}  ▪ app disconnected (${clients.size} connected)`)
        })
        return
      }

      if (path === "/logs" && req.method === "POST") {
        const lines = logLinesFrom(await readBody(req))
        if (lines === null) warn(`${stamp()}  ! unreadable log payload`)
        for (const line of lines ?? []) log(`${stamp()}  │ ${line}`)
        res.writeHead(204).end()
        return
      }

      if (path === `/${key}.js`) {
        res.writeHead(200, { "content-type": "application/javascript; charset=utf-8" })
        res.end(source ?? EMPTY_BUNDLE)
        return
      }

      res.writeHead(404, { "content-type": "text/plain" })
      res.end("not found")
    }, warn),
  )

  await new Promise((resolveListen, rejectListen) => {
    server.once("error", rejectListen)
    server.listen(port, host, () => {
      server.off("error", rejectListen)
      resolveListen()
    })
  })
  const listening = server.address().port

  return {
    key,
    port: listening,
    url: `http://localhost:${listening}`,
    addresses: lanAddresses().map((address) => `http://${address}:${listening}`),
    get buildError() {
      return buildError
    },
    async close() {
      manifestWatch.abort()
      await restarting
      await ctx?.dispose()
      for (const client of clients) client.end()
      clients.clear()
      await new Promise((r) => server.close(() => r()))
    },
  }
}

// ---------------------------------------------------------------------------
// The protocol's shared parts: the repository's dev server imports these.

/// The time of day, for every line the loop prints.
export function stamp() {
  return new Date().toTimeString().slice(0, 8)
}

/// One Server-Sent Event to every connected app; a client that cannot be
/// written to is dropped.
export function broadcast(clients, event) {
  const payload = `data: ${JSON.stringify(event)}\n\n`
  for (const client of clients) {
    try {
      client.write(payload)
    } catch {
      clients.delete(client)
    }
  }
}

/// Whether a page at [origin] may talk to a dev server: the app's own web
/// build, run on this machine or deployed under ham2k.net, or one named with
/// `--allow-origin`. Every other page open in the author's browser is refused,
/// so none can read what is being served or write into this terminal.
export function originAllowed(origin, allowOrigins = []) {
  if (allowOrigins.includes(origin)) return true
  let url
  try {
    url = new URL(origin)
  } catch {
    return false
  }
  if (url.origin !== origin) return false
  if (isLoopback(url.hostname)) return url.protocol === "http:" || url.protocol === "https:"
  return url.protocol === "https:" && (url.hostname === "ham2k.net" || url.hostname.endsWith(".ham2k.net"))
}

function isLoopback(name) {
  return name === "localhost" || name.endsWith(".localhost") || name === "[::1]" || /^127\.\d+\.\d+\.\d+$/.test(name)
}

/// Whether a request's Host names this machine as the app reaches it: an IP
/// address, localhost, a `.local` name, or the machine's own name. A page
/// that points a domain of its own at this machine's address arrives under
/// that domain, as its own origin, and is refused here instead.
export function hostAllowed(host) {
  if (host === undefined) return true
  let name
  try {
    name = new URL(`http://${host}`).hostname.toLowerCase()
  } catch {
    return false
  }
  if (isIP(name.replace(/^\[|\]$/g, "")) !== 0 || isLoopback(name) || name.endsWith(".local")) return true
  const own = hostname().toLowerCase()
  return name === own || name === own.split(".")[0]
}

/// Refuses a request from a page or under a Host the dev server does not
/// answer ([originAllowed], [hostAllowed]), answers a CORS preflight, and
/// allows an accepted origin on the response. Returns true when the request
/// has been answered and needs nothing more. The app itself sends no Origin
/// unless it is the web build, which preflights `POST /logs`
/// (`content-type: application/json` is not CORS-safelisted): without the
/// preflight's answer, log forwarding dies silently, since the app swallows a
/// failed flush.
export function guardRequest(req, res, { allowOrigins = [] } = {}) {
  const origin = req.headers.origin
  if (!hostAllowed(req.headers.host)) {
    res.writeHead(403, { "content-type": "text/plain" })
    res.end("not this machine's name: point the app at its IP address\n")
    return true
  }
  if (origin !== undefined) {
    if (!originAllowed(origin, allowOrigins)) {
      res.writeHead(403, { "content-type": "text/plain" })
      res.end(`origin not allowed: ${origin} (start the dev server with --allow-origin ${origin} to allow it)\n`)
      return true
    }
    res.setHeader("Access-Control-Allow-Origin", origin)
    res.setHeader("Vary", "Origin")
  }
  if (req.method !== "OPTIONS") return false
  res.writeHead(204, {
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type",
    "access-control-max-age": "86400",
  })
  res.end()
  return true
}

/// The path a request asks for, or null for a request target that is not
/// one (`//`, an absolute URL with no host). Parsed against a fixed base,
/// never the client's Host.
export function requestPath(req) {
  try {
    return new URL(req.url ?? "/", "http://localhost").pathname
  } catch {
    return null
  }
}

/// Runs [handle] for a request, so that nothing it throws can end the
/// server: the request is answered with a 500, and the server keeps serving.
export function serveSafely(handle, warnFn = console.error) {
  return (req, res) => {
    Promise.resolve()
      .then(() => handle(req, res))
      .catch((e) => {
        warnFn(`${stamp()}  ! ${req.method} ${String(req.url).slice(0, 200)} failed: ${e?.message ?? e}`)
        if (!res.headersSent) res.writeHead(500, { "content-type": "text/plain" })
        res.end()
      })
  }
}

/// At most this many lines per `POST /logs`, and this many characters a
/// line; what is cut is counted, not dropped silently.
export const LOG_LINES_MAX = 1000
export const LOG_LINE_MAX = 4000

/// The lines a `POST /logs` body asks to be printed, ready to print: an
/// array of strings and nothing else, capped ([LOG_LINES_MAX],
/// [LOG_LINE_MAX]), with every control character but tab shown escaped
/// (`\x1b`). A line cannot move the cursor, clear the screen, retitle the
/// window or reach the clipboard, nor pass for a line of the server's own.
/// Null when the body is not that shape.
export function logLinesFrom(body) {
  let lines
  try {
    lines = JSON.parse(body).lines
  } catch {
    return null
  }
  if (!Array.isArray(lines)) return null
  const printed = []
  for (const line of lines.slice(0, LOG_LINES_MAX)) {
    if (typeof line !== "string") continue
    const shown = line.length > LOG_LINE_MAX ? `${line.slice(0, LOG_LINE_MAX)}… (${line.length - LOG_LINE_MAX} more characters)` : line
    printed.push(shown.replace(/[\u0000-\u0008\u000a-\u001f\u007f-\u009f]/g, (c) => `\\x${c.charCodeAt(0).toString(16).padStart(2, "0")}`))
  }
  if (lines.length > LOG_LINES_MAX) printed.push(`… ${lines.length - LOG_LINES_MAX} more lines`)
  return printed
}

export function json(res, body) {
  res.writeHead(200, { "content-type": "application/json; charset=utf-8" })
  res.end(JSON.stringify(body))
}

/// Reads a request body, capped and error-terminated, so a client that aborts
/// mid-POST cannot leave the handler pending.
export function readBody(req, limit = 1 << 20) {
  return new Promise((resolveBody) => {
    let data = ""
    req.on("data", (chunk) => {
      data += chunk
      if (data.length > limit) {
        data = data.slice(0, limit)
        req.destroy()
        resolveBody(data)
      }
    })
    req.on("end", () => resolveBody(data))
    req.on("error", () => resolveBody(""))
    req.on("aborted", () => resolveBody(""))
  })
}

/// Every IPv4 address a phone on the LAN could reach, localhost last: right
/// for a desktop build on this machine, useless for the phone this exists for,
/// so not the first thing read off the screen.
export function lanAddresses() {
  const found = []
  for (const addresses of Object.values(networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family === "IPv4" && !address.internal) found.push(address.address)
    }
  }
  return [...found, "localhost"]
}

/// The command line. Returns an exit code only for a usage problem or a
/// start-up failure; otherwise it serves until SIGINT or SIGTERM, then exits 0.
export async function main(argv) {
  let options
  try {
    options = parseArgs(argv)
  } catch (e) {
    console.error(`h2kext-dev: ${e.message}\n\n${USAGE}`)
    return 2
  }
  if (options.help) {
    console.log(USAGE)
    return 0
  }
  let dev
  try {
    const esbuild = await loadEsbuild(options.dir)
    dev = await createDevServer({ ...options, esbuild })
  } catch (e) {
    console.error(`h2kext-dev: ${e.message}`)
    return e instanceof DevServerError ? 2 : 1
  }

  if (dev.buildError !== null) console.error(`\n✗ ${dev.key}\n${dev.buildError}`)
  console.log(`\nh2kext-dev — ${dev.key} ${dev.buildError === null ? "ready" : "is not building yet; fix the error above and save, and the app picks it up"}`)
  console.log("\nPoint the app at (Settings → Developer → Extension Dev Server):")
  for (const address of dev.addresses) console.log(`  ${address}`)
  console.log("\nWatching for changes. Install from a file before you publish; the packer's checks run there.\n")

  await new Promise((resolveExit) => {
    for (const signal of ["SIGINT", "SIGTERM"]) {
      process.on(signal, async () => {
        await dev.close()
        resolveExit()
      })
    }
  })
  return 0
}

// Run only when invoked as the bin, never when imported by a test or by the
// repository's dev server. npm's bin shim is a symlink while `import.meta.url`
// resolves to the real file, so the argument is resolved before comparing.
if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  process.exit(await main(process.argv.slice(2)))
}
