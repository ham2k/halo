// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The dev link's tool end against a stand-in app. What matters is that the
// operator's answer is honoured: a no or a disconnect stops the asking for
// good, while an app that merely went away is looked for and asked again,
// since its next session has not been asked at all.

import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdir, mkdtemp, writeFile } from "node:fs/promises"
import { createServer as createHttpServer } from "node:http"
import { createServer, type Server, type Socket } from "node:net"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { test } from "node:test"

// @ts-ignore — deliberately plain JS, like the tools it sits beside.
import { appsMatching, discoverApps, LINK_VERSION, loopbackServerUrl, parseAppChoice, probeApp, startDevLink } from "./dev-link.mjs"
// @ts-ignore
import { loadEsbuild, listenWithFallback, parseArgs, USAGE } from "./h2kext-dev.mjs"

type Message = Record<string, unknown>
type App = { port: number; asks: Message[]; close: () => Promise<void> }

const APP = { name: "Ham2K Logger", edition: "dev", label: "dev link", version: "26.11.0" }

const line = (message: Message) => `${JSON.stringify({ extDevLink: LINK_VERSION, ...message })}\n`

/// An app listening for the link: answers a probe with [app] (or the whole
/// [probeReply] line, when given), and hands each ask (with its 1-based
/// count) to [onAsk] with the socket to answer on.
async function fakeApp({
  app = APP,
  port: wanted = 0,
  probeReply,
  onAsk = () => {},
}: { app?: Message; port?: number; probeReply?: string; onAsk?: (socket: Socket, ask: Message, count: number) => void } = {}): Promise<App> {
  const asks: Message[] = []
  const sockets = new Set<Socket>()
  const server: Server = createServer((socket) => {
    sockets.add(socket)
    socket.on("close", () => sockets.delete(socket))
    socket.on("error", () => {})
    socket.setEncoding("utf8")
    let buffer = ""
    let seen = false
    socket.on("data", (chunk) => {
      if (seen) return
      buffer += chunk
      const at = buffer.indexOf("\n")
      if (at === -1) return
      seen = true
      const first = JSON.parse(buffer.slice(0, at))
      if (first.probe === true) {
        socket.end(probeReply ?? line({ app }))
        return
      }
      asks.push(first)
      onAsk(socket, first, asks.length)
    })
  })
  await new Promise<void>((r) => server.listen(wanted, "127.0.0.1", () => r()))
  const port = (server.address() as { port: number }).port
  return {
    port,
    asks,
    close: () =>
      new Promise<void>((r) => {
        for (const socket of sockets) socket.destroy()
        server.close(() => r())
      }),
  }
}

/// A port nothing listens on: bound, read, released.
async function freePort() {
  const server = createServer()
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", () => r()))
  const port = (server.address() as { port: number }).port
  await new Promise<void>((r) => server.close(() => r()))
  return port
}

async function until(condition: () => boolean, what: string, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs
  while (!condition()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`)
    await new Promise((r) => setTimeout(r, 20))
  }
}

const HELLO = { tool: { name: "h2kext-dev", version: "1.29.0" }, dir: "/tmp/w7abc-notes", keys: ["w7abc-notes"], server: "http://127.0.0.1:8787/" }

function link(ports: number[], extra: Record<string, unknown> = {}) {
  const lines: string[] = []
  const handle = startDevLink({
    hello: HELLO,
    ports,
    rediscoverMs: 50,
    probeTimeoutMs: 500,
    log: (l: string) => lines.push(l),
    warn: (l: string) => lines.push(l),
    ...extra,
  })
  return { handle, lines, saw: (text: string) => lines.some((l) => l.includes(text)) }
}

test("a probe reads what the app says it is, and nothing else counts as an app", async () => {
  const app = await fakeApp()
  const silent = createServer((socket) => {
    socket.on("error", () => {})
    socket.end("HTTP/1.1 400 Bad Request\r\n\r\n")
  })
  await new Promise<void>((r) => silent.listen(0, "127.0.0.1", () => r()))
  const silentPort = (silent.address() as { port: number }).port
  const nothing = await freePort()
  try {
    assert.deepEqual(await probeApp(app.port), { port: app.port, app: APP })
    // Something else on a scanned port must not be asked to run code.
    assert.equal(await probeApp(silentPort), null)
    assert.equal(await probeApp(nothing), null)
    assert.deepEqual(await discoverApps({ ports: [nothing, silentPort, app.port] }), [{ port: app.port, app: APP }])
    assert.equal(app.asks.length, 0, "a probe is never an ask")
  } finally {
    await app.close()
    // Not awaited: a server whose last connection was reset by its peer
    // does not always report closing, and nothing here depends on it.
    silent.close()
  }
})

test("an ask carries the hello, and the app's answers reach the terminal", async () => {
  const app = await fakeApp({
    onAsk: (socket) => {
      socket.write(line({ asking: true }))
      setTimeout(() => {
        socket.write(line({ ok: true }))
        socket.write(
          line({
            state: "connected",
            keys: ["w7abc-notes"],
            refused: { "w7abc-other": "an installed extension has that key" },
            notLoaded: { "w7abc-notes": "TypeError: notes is undefined" },
          }),
        )
      }, 30)
    },
  })
  const { handle, saw } = link([app.port])
  try {
    await until(() => saw("is running w7abc-notes"), "the connected state")
    assert.deepEqual(app.asks[0], { extDevLink: LINK_VERSION, ...HELLO })
    assert.ok(saw("Waiting for the operator to allow it"))
    assert.ok(saw("allowed it for this session"))
    // A key the app would not take is said, or saving it changes nothing with no reason given.
    assert.ok(saw("w7abc-other was not taken: an installed extension has that key"))
    // Built here, so only the app knows; "is running" alone would be wrong.
    assert.ok(saw("w7abc-notes would not load in the app: TypeError: notes is undefined"))
  } finally {
    handle.close()
    await app.close()
  }
})

test("a no stops the asking: the operator is not asked again until the tool restarts", async () => {
  const app = await fakeApp({ onAsk: (socket) => socket.end(line({ ok: false, reason: "denied" })) })
  const { handle, saw } = link([app.port])
  try {
    await until(() => handle.stopped, "the link to stop")
    assert.ok(saw("said no"))
    await new Promise((r) => setTimeout(r, 300))
    assert.equal(app.asks.length, 1)
  } finally {
    handle.close()
    await app.close()
  }
})

test("a disconnect in the app stops the asking, where a quit does not", async () => {
  const app = await fakeApp({
    onAsk: (socket) => {
      socket.write(line({ ok: true }))
      setTimeout(() => socket.end(line({ closed: "disconnected" })), 30)
    },
  })
  const { handle, saw } = link([app.port])
  try {
    await until(() => handle.stopped, "the link to stop")
    assert.ok(saw("disconnected it"))
    await new Promise((r) => setTimeout(r, 300))
    assert.equal(app.asks.length, 1)
  } finally {
    handle.close()
    await app.close()
  }
})

test("an app that goes away without a word is looked for and asked again", async () => {
  const app = await fakeApp({
    onAsk: (socket, _ask, count) => {
      socket.write(line({ ok: true }))
      // The first session ends as an app quitting does: the connection drops.
      if (count === 1) setTimeout(() => socket.destroy(), 30)
    },
  })
  const { handle, saw } = link([app.port])
  try {
    await until(() => app.asks.length === 2, "a second ask")
    assert.ok(saw("went away; asking again"))
    assert.equal(handle.stopped, false)
  } finally {
    handle.close()
    await app.close()
  }
})

test("with no app running it says so once and keeps looking, then asks the one that starts", async () => {
  const port = await freePort()
  const { handle, lines, saw } = link([port])
  let app: App | null = null
  try {
    await until(() => saw("No running app with Developer Mode on found"), "the no-app line")
    await new Promise((r) => setTimeout(r, 200))
    assert.equal(lines.filter((l) => l.includes("No running app")).length, 1)
    app = await fakeApp({ port, onAsk: (socket) => socket.write(line({ ok: true })) })
    await until(() => app!.asks.length === 1, "the ask")
  } finally {
    handle.close()
    await app?.close()
  }
})

test("with several apps it asks the one chosen, and none when nobody can choose", async () => {
  const dev = await fakeApp()
  const next = await fakeApp({ app: { ...APP, edition: "next", label: "" }, onAsk: (socket) => socket.write(line({ ok: true })) })
  try {
    const unattended = link([dev.port, next.port], { choose: async () => null })
    await until(() => unattended.handle.stopped, "the unattended link to stop")
    assert.ok(unattended.saw("--app"))
    assert.equal(dev.asks.length + next.asks.length, 0)

    const chosen = link([dev.port, next.port], { choose: async (apps: { port: number }[]) => apps.find((a) => a.port === next.port) })
    await until(() => next.asks.length === 1, "the chosen app's ask")
    assert.equal(dev.asks.length, 0)
    chosen.handle.close()
  } finally {
    await dev.close()
    await next.close()
  }
})

test("an app speaking another version of the link is named, not taken for no app at all", async () => {
  const app = await fakeApp({ probeReply: `${JSON.stringify({ extDevLink: LINK_VERSION + 1, ok: false, reason: "protocol" })}\n` })
  try {
    assert.deepEqual(await probeApp(app.port), { port: app.port, speaks: LINK_VERSION + 1 })
    const { handle, saw } = link([app.port])
    await until(() => handle.stopped, "the link to stop")
    assert.ok(saw(`speaks dev link ${LINK_VERSION + 1}`), "the author is told to update, not to switch Developer Mode on")
    assert.ok(!saw("No running app"))
    handle.close()
  } finally {
    await app.close()
  }
})

test("Developer Mode switched off is said, and the app is asked again once it is back", async () => {
  const app = await fakeApp({
    onAsk: (socket, _ask, count) => {
      socket.write(line({ ok: true }))
      if (count === 1) setTimeout(() => socket.end(line({ ok: false, reason: "unavailable", message: "Developer Mode is off" })), 30)
    },
  })
  const { handle, saw } = link([app.port])
  try {
    await until(() => app.asks.length === 2, "a second ask")
    assert.ok(saw("cannot run it now: Developer Mode is off"))
    assert.ok(!saw("went away"), "the author is not sent looking for a crash")
    assert.equal(handle.stopped, false)
  } finally {
    handle.close()
    await app.close()
  }
})

test("once an app has allowed it, a different app running while it restarts is not asked", async () => {
  const port = await freePort()
  const regularPort = await freePort()
  let dev: App | null = await fakeApp({ port, onAsk: (socket) => socket.write(line({ ok: true })) })
  let regular: App | null = null
  const { handle, saw } = link([port, regularPort], { choose: async () => null })
  try {
    // Only the Dev build is up at first, so it is asked without a choice.
    await until(() => dev!.asks.length === 1, "the dev build's ask")
    regular = await fakeApp({ port: regularPort, app: { ...APP, edition: "regular", label: "" } })
    const before = regular.asks.length
    await dev.close()
    dev = null
    await until(() => saw("Waiting for the app on port"), "the wait for the restarting app")
    // The operator's logging app must not suddenly be asked to run the author's code.
    assert.equal(regular.asks.length, before)
    dev = await fakeApp({ port, onAsk: (socket) => socket.write(line({ ok: true })) })
    await until(() => dev!.asks.length === 1, "the restarted dev build's ask")
    assert.equal(regular.asks.length, before)
  } finally {
    handle.close()
    await dev?.close()
    await regular?.close()
  }
})

test("the app is handed the address the dev server is actually bound to", () => {
  assert.equal(loopbackServerUrl({ address: "0.0.0.0", port: 8787 }), "http://127.0.0.1:8787/")
  assert.equal(loopbackServerUrl({ address: "::", port: 8787 }), "http://127.0.0.1:8787/")
  // `localhost` binds ::1 on some machines; 127.0.0.1 would find nothing there.
  assert.equal(loopbackServerUrl({ address: "::1", port: 8787 }), "http://[::1]:8787/")
  assert.equal(loopbackServerUrl({ address: "192.168.1.5", port: 8787 }), null)
  assert.equal(loopbackServerUrl({ address: "127.0.0.2", port: 8787 }), null)
})

test("--app names an edition or a port, and narrows the apps asked to it", () => {
  assert.deepEqual(parseAppChoice("next"), { edition: "next" })
  assert.deepEqual(parseAppChoice("47393"), { port: 47393 })
  assert.equal(parseAppChoice("nightly"), null)
  const apps = [
    { port: 47390, app: { edition: "regular" } },
    { port: 47392, app: { edition: "dev" } },
    { port: 47393, app: { edition: "dev" } },
  ]
  assert.deepEqual(appsMatching(apps, { edition: "dev" }), apps.slice(1))
  assert.deepEqual(appsMatching(apps, { port: 47393 }), [apps[2]])
  assert.deepEqual(appsMatching(apps, null), apps)

  assert.deepEqual(parseArgs(["--app", "dev"]).app, { edition: "dev" })
  assert.throws(() => parseArgs(["--app", "nightly"]))
  assert.equal(parseArgs(["--no-app"]).link, false)
  assert.equal(parseArgs([]).link, true)
  // Only a port the author typed is held to; the default moves up when taken.
  assert.equal(parseArgs([]).portGiven, false)
  assert.equal(parseArgs(["--port", "9000"]).portGiven, true)
})

test("a taken port moves the server up when it may, and fails when the port was named", async () => {
  const holder = createHttpServer()
  await new Promise<void>((r) => holder.listen(0, "127.0.0.1", () => r()))
  const taken = (holder.address() as { port: number }).port
  const moved = createHttpServer()
  const strict = createHttpServer()
  try {
    const port = await listenWithFallback(moved, { port: taken, host: "127.0.0.1", fallback: 20 })
    assert.ok(port > taken && port <= taken + 20, `listened on ${port}`)
    await assert.rejects(listenWithFallback(strict, { port: taken, host: "127.0.0.1" }), { code: "EADDRINUSE" })
  } finally {
    await new Promise<void>((r) => moved.close(() => r()))
    await new Promise<void>((r) => holder.close(() => r()))
  }
})

test("a port another server answers on at 127.0.0.1 is taken, even where a wildcard bind beside it would succeed", async () => {
  const holder = createHttpServer()
  await new Promise<void>((r) => holder.listen(0, "127.0.0.1", () => r()))
  const taken = (holder.address() as { port: number }).port
  const wildcard = createHttpServer()
  try {
    // macOS binds 0.0.0.0 beside another process's 127.0.0.1 on the same
    // port, and the app, sent to 127.0.0.1, reaches the other server.
    const port = await listenWithFallback(wildcard, { port: taken, host: "0.0.0.0", fallback: 20 })
    assert.notEqual(port, taken)
  } finally {
    await new Promise<void>((r) => wildcard.close(() => r()))
    await new Promise<void>((r) => holder.close(() => r()))
  }
})

test("a project with no esbuild of its own builds with the package's", async () => {
  const empty = await mkdtemp(join(tmpdir(), "h2kext-no-esbuild-"))
  const esbuild = await loadEsbuild(empty)
  assert.equal(typeof esbuild.context, "function")
  // And with neither, the author is told what to install.
  await assert.rejects(loadEsbuild(empty, { fallbackFrom: join(empty, "x.js") }), /esbuild is not installed/)
})

test("a project's own esbuild that fails to load is said, not quietly replaced by the package's", async () => {
  const project = await mkdtemp(join(tmpdir(), "h2kext-broken-esbuild-"))
  const esbuildDir = join(project, "node_modules", "esbuild")
  await mkdir(esbuildDir, { recursive: true })
  await writeFile(join(esbuildDir, "package.json"), JSON.stringify({ name: "esbuild", main: "main.js" }))
  await writeFile(join(esbuildDir, "main.js"), 'throw new Error("no binary for this platform")')
  // Another copy would build output that differs from what `build.mjs` makes.
  await assert.rejects(loadEsbuild(project), /could not load esbuild from .*no binary for this platform/)

  // Damaged before it even resolves: installed all the same, so said too.
  await writeFile(join(esbuildDir, "package.json"), "{ not json")
  await assert.rejects(loadEsbuild(project), /could not load esbuild from/)
})

test("npx's command runs the one named after it, with the arguments after it", () => {
  const run = (...args: string[]) => spawnSync(process.execPath, [join(import.meta.dirname, "extension-tools.mjs"), ...args], { encoding: "utf8" })
  const dev = run("dev", "--help")
  assert.equal(dev.status, 0)
  assert.equal(dev.stdout.trim(), USAGE)
  const unknown = run("serve")
  assert.equal(unknown.status, 2)
  assert.match(unknown.stderr, /unknown command serve/)
  assert.match(run().stdout, /init\|dev\|pack\|publish/)
})
