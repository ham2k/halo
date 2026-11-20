// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The dev link's tool end: finds a desktop app running on this machine with
// Developer Mode on and asks it to run what this dev server serves, so the
// author never types an address into the app's settings.
//
// The app listens on a loopback port per edition. Each connection carries one
// JSON object per line; the tool's first line is either a probe, answered
// with what the app is and hung up on, or an ask, which the app puts to the
// operator. An allowed ask is held open for as long as the app runs those
// extensions: the app connects to the dev server's own HTTP address as it
// would to one typed into its settings, and reports back on this line.
//
// The operator's answer lasts one app session and is never stored, so a
// restarted app asks again; the tool keeps looking for the app while it is
// gone, and asks the new one.

import { createConnection } from "node:net"
import { createInterface } from "node:readline"

/// The link's version, sent as `extDevLink` on every line either way.
export const LINK_VERSION = 1

/// Where each edition listens. A Dev build whose port is taken (another
/// checkout's Dev build) takes the next one up.
export const EDITION_PORTS = {
  regular: [47390],
  next: [47391],
  dev: [47392, 47393, 47394, 47395, 47396, 47397, 47398, 47399],
}

export const APP_PORTS = Object.values(EDITION_PORTS).flat()

/// How long between looks for an app that is not there, or has gone.
export const REDISCOVER_MS = 3000

/// The longest line read from the app; anything longer ends the connection.
const LINE_MAX = 1 << 20

/// Which app `--app` names: an edition or a port. Null for anything else.
export function parseAppChoice(text) {
  if (Object.hasOwn(EDITION_PORTS, text)) return { edition: text }
  if (/^\d+$/.test(text)) {
    const port = Number(text)
    if (port >= 1 && port <= 65535) return { port }
  }
  return null
}

/// The apps [choice] admits from [apps]; all of them when there is none.
export function appsMatching(apps, choice) {
  if (!choice) return apps
  if (choice.port !== undefined) return apps.filter((a) => a.port === choice.port)
  return apps.filter((a) => a.app.edition === choice.edition)
}

/// How an app is named on the terminal: its name, edition and label, and the
/// port that tells two Dev builds apart.
export function describeApp({ port, app }) {
  const edition = app.edition && app.edition !== "regular" ? ` ${app.edition[0].toUpperCase()}${app.edition.slice(1)}` : ""
  const label = app.label ? ` “${app.label}”` : ""
  return `${app.name ?? "Ham2K Logger"}${edition}${label} (port ${port})`
}

/// The address the app reaches a dev server at, from where it is bound
/// (`server.address()`), or null when it is bound where a loopback
/// connection cannot reach it. Read from the bound address rather than the
/// `--host` typed: `localhost` binds `::1` on one machine and 127.0.0.1 on
/// the next, and the app given the other one finds nothing there.
export function loopbackServerUrl(bound) {
  if (!bound || typeof bound !== "object") return null
  const { address, port } = bound
  if (address === "0.0.0.0" || address === "::" || address === "127.0.0.1") return `http://127.0.0.1:${port}/`
  if (address === "::1") return `http://[::1]:${port}/`
  return null
}

/// The edition whose app listens on [port], if any.
function editionOfPort(port) {
  return Object.keys(EDITION_PORTS).find((edition) => EDITION_PORTS[edition].includes(port))
}

/// Reads [socket] as lines of JSON, handing each object to [onMessage]. A
/// line that is not a JSON object, or is too long, ends the connection: the
/// app speaks nothing else.
function readMessages(socket, onMessage) {
  let buffer = ""
  socket.setEncoding("utf8")
  socket.on("data", (chunk) => {
    buffer += chunk
    let at
    while ((at = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, at).trim()
      buffer = buffer.slice(at + 1)
      if (line === "") continue
      let message
      try {
        message = JSON.parse(line)
      } catch {
        socket.destroy()
        return
      }
      if (message === null || typeof message !== "object" || Array.isArray(message)) {
        socket.destroy()
        return
      }
      onMessage(message)
      if (socket.destroyed) return
    }
    if (buffer.length > LINE_MAX) socket.destroy()
  })
}

/// What the app on [port] says it is, or null when nothing answers there as
/// one, within [timeoutMs]. An app speaking another version of the link
/// answers with no `app`: that comes back as `{port, speaks}`, so the author
/// is told to update rather than that no app is running.
export function probeApp(port, { host = "127.0.0.1", timeoutMs = 1500 } = {}) {
  return new Promise((resolveProbe) => {
    let settled = false
    const socket = createConnection({ host, port })
    const done = (result) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      socket.destroy()
      resolveProbe(result)
    }
    const timer = setTimeout(() => done(null), timeoutMs)
    socket.on("error", () => done(null))
    socket.on("close", () => done(null))
    socket.on("connect", () => socket.write(`${JSON.stringify({ extDevLink: LINK_VERSION, probe: true })}\n`))
    readMessages(socket, (message) => {
      const app = message.app
      if (Number.isInteger(message.extDevLink) && message.extDevLink !== LINK_VERSION) return done({ port, speaks: message.extDevLink })
      done(message.extDevLink === LINK_VERSION && app && typeof app === "object" ? { port, app } : null)
    })
  })
}

/// Every app answering on [ports], in port order.
export async function discoverApps({ ports = APP_PORTS, host, timeoutMs } = {}) {
  const found = await Promise.all(ports.map((port) => probeApp(port, { host, timeoutMs })))
  return found.filter(Boolean)
}

/// Asks the operator on the terminal which of [apps] to ask, or null when
/// the terminal is not interactive (or the answer names none).
export async function chooseOnTerminal(apps, { input = process.stdin, output = process.stdout } = {}) {
  if (!input.isTTY) return null
  output.write("\nMore than one app is running:\n")
  apps.forEach((app, i) => output.write(`  ${i + 1}. ${describeApp(app)}\n`))
  const rl = createInterface({ input, output })
  // Ctrl-C at the question stops the dev server, as it would anywhere else:
  // readline takes the keystroke from the process otherwise.
  rl.on("SIGINT", () => {
    rl.close()
    process.kill(process.pid, "SIGINT")
  })
  const answer = await new Promise((resolveAnswer) => {
    rl.question(`Which one should run it? [1-${apps.length}] `, resolveAnswer)
    rl.on("close", () => resolveAnswer(""))
  })
  rl.close()
  const index = Number(String(answer).trim()) - 1
  return Number.isInteger(index) && apps[index] ? apps[index] : null
}

/// Keeps asking a running app to run what the dev server serves, until it
/// is told no or [close]d.
///
/// [hello] is the ask's body: `tool` ({name, version}), `dir`, `keys` and
/// `server`. [choice] narrows the apps asked ([parseAppChoice]); [choose]
/// picks one of several, or returns null to ask none. [log] and [warn]
/// receive every line this prints.
///
/// Resolves to `{ close() }` at once; the looking and asking run behind it.
export function startDevLink({
  hello,
  choice = null,
  choose = chooseOnTerminal,
  ports = APP_PORTS,
  host = "127.0.0.1",
  probeTimeoutMs = 1500,
  rediscoverMs = REDISCOVER_MS,
  log = console.log,
  warn = console.error,
}) {
  let closed = false
  let stopped = false
  let timer = null
  let socket = null
  /// The port of the app picked among several, or that allowed it: the only
  /// one asked from then on.
  let picked = null
  /// Said once while nothing answers, not once per look.
  let saidNone = false
  let saidWaiting = false
  let lastFailure = null

  function stop(message) {
    stopped = true
    if (message) warn(message)
  }

  function later() {
    if (closed || stopped) return
    timer = setTimeout(lookSafely, rediscoverMs)
  }

  function lookSafely() {
    look().catch((e) => {
      warn(`Could not look for the app: ${e?.message ?? e}`)
      later()
    })
  }

  async function look() {
    timer = null
    if (closed || stopped) return
    const found = await discoverApps({ ports, host, timeoutMs: probeTimeoutMs })
    if (closed || stopped) return
    const apps = appsMatching(
      found.filter((a) => a.app),
      choice,
    )
    if (apps.length === 0) {
      const outdated = found.find(
        (a) => a.speaks !== undefined && (!choice || (choice.port !== undefined ? a.port === choice.port : editionOfPort(a.port) === choice.edition)),
      )
      if (outdated) {
        return stop(`The app on port ${outdated.port} speaks dev link ${outdated.speaks}, this tool speaks ${LINK_VERSION}; update whichever is older.`)
      }
      if (!saidNone) {
        saidNone = true
        log(
          choice
            ? `No running app matches --app ${choice.port ?? choice.edition} with Developer Mode on (Settings → Developer); asking when one does.`
            : "No running app with Developer Mode on found (Settings → Developer); asking when one does.",
        )
      }
      return later()
    }
    saidNone = false
    // Once an app has been picked or has allowed it, only that one is asked:
    // another app that happens to be running while it restarts is the
    // operator's logging app, not the one the author meant.
    if (picked !== null) {
      const again = apps.find((a) => a.port === picked)
      if (!again) {
        if (!saidWaiting) {
          saidWaiting = true
          log(`Waiting for the app on port ${picked} to come back; restart with --app to ask another.`)
        }
        return later()
      }
      saidWaiting = false
      return ask(again)
    }
    let target = apps.length === 1 ? apps[0] : null
    if (!target) {
      target = await choose(apps)
      if (closed || stopped) return
      if (!target) {
        return stop(`More than one app is running: ${apps.map(describeApp).join(", ")}.\nRestart with --app <regular|next|dev|port> to ask one of them.`)
      }
      picked = target.port
    }
    ask(target)
  }

  function ask(target) {
    const name = describeApp(target)
    let answered = false
    let ended = false
    socket = createConnection({ host, port: target.port })
    socket.on("connect", () => socket.write(`${JSON.stringify({ extDevLink: LINK_VERSION, ...hello })}\n`))
    socket.on("error", () => {})
    socket.on("close", () => {
      socket = null
      if (closed || stopped || ended) return
      log(answered ? `${name} went away; asking again when it is back.` : `${name} hung up before answering; asking again.`)
      later()
    })
    readMessages(socket, (message) => {
      if (message.extDevLink !== LINK_VERSION) {
        ended = true
        socket.destroy()
        stop(`${name} speaks dev link ${message.extDevLink}, this tool speaks ${LINK_VERSION}; update whichever is older.`)
        return
      }
      if (message.asking === true) {
        log(`Waiting for the operator to allow it in ${name}…`)
        return
      }
      if (message.ok === true) {
        answered = true
        picked = target.port
        lastFailure = null
        log(`${name} allowed it for this session.`)
        return
      }
      if (message.ok === false) {
        ended = true
        socket.destroy()
        const detail = message.message ? `: ${message.message}` : ""
        if (message.reason === "unavailable") {
          // The app cannot take it just now: Developer Mode was switched
          // off. Looked for again, but said once, not on every look.
          const failure = `${name} cannot run it now${detail}`
          if (failure !== lastFailure) warn(failure)
          lastFailure = failure
          return later()
        }
        if (message.reason === "denied") {
          return stop(`${name} said no. Restart the dev server to ask again; the address above still works in Settings → Developer.`)
        }
        return stop(`${name} refused the request (${message.reason ?? "no reason given"})${detail}`)
      }
      if (message.state === "connected") {
        const keys = Array.isArray(message.keys) ? message.keys : []
        log(`${name} is running ${keys.length ? keys.join(", ") : "none of it"}.`)
        for (const [key, reason] of Object.entries(message.refused ?? {})) warn(`  ${key} was not taken: ${reason}`)
        // Built here but would not load in the app: only the app knows, and
        // the line above alone would claim it is running.
        for (const [key, reason] of Object.entries(message.notLoaded ?? {})) warn(`  ${key} would not load in the app: ${reason}`)
        return
      }
      if (message.state === "failed") {
        warn(`${name} could not load it: ${message.message ?? "no reason given"} (trying again every few seconds)`)
        return
      }
      if (message.closed !== undefined) {
        ended = true
        socket.destroy()
        stop(`${name} disconnected it. Restart the dev server to ask again.`)
      }
    })
  }

  lookSafely()

  return {
    /// Whether the link has stopped asking for good (a no, a disconnect).
    get stopped() {
      return stopped
    },
    close() {
      closed = true
      if (timer) clearTimeout(timer)
      socket?.destroy()
    },
  }
}
