// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The dev loop for an extension built outside the repository: the server an
// author runs from their project, speaking the protocol the app's dev client
// already knows. What matters is the loop staying up and honest — a saved
// edit reaches the app as a reload, a broken save reaches it as an error
// while the last good bundle keeps serving, and a manifest the packer would
// refuse never reaches it at all.

import assert from "node:assert/strict"
import { context } from "esbuild"
import { mkdir, mkdtemp, rename, writeFile } from "node:fs/promises"
import { request } from "node:http"
import { connect } from "node:net"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { test } from "node:test"

// @ts-ignore — deliberately plain JS, like the tools it sits beside.
import { createDevServer, DevServerError, EMPTY_BUNDLE, LOG_LINE_MAX, LOG_LINES_MAX, parseArgs, PROTOCOL, SERVER_NAME } from "./h2kext-dev.mjs"
// @ts-ignore
import { findSharedModuleReferences, H2KEXT_API_VERSION, SCAFFOLD_SHARED_DEPENDENCIES } from "./h2kext.mjs"

const KEY = "k2hrc-dev-loop"

function manifestFor(overrides: Record<string, unknown> = {}) {
  return {
    key: KEY,
    name: "Dev loop",
    version: "0.1.0",
    description: "A project the dev server serves",
    category: "dashboard",
    api: H2KEXT_API_VERSION,
    hooks: ["panel"],
    domains: ["example.org"],
    sharedDependencies: SCAFFOLD_SHARED_DEPENDENCIES,
    ...overrides,
  }
}

/// An extension that imports nothing the sandbox shares, so the build needs
/// no SDK beside it; the manifest import is what the scaffold does, and what
/// makes a manifest edit rebuild.
function sourceWith(marker: string) {
  return `import manifest from "../manifest.json" with { type: "json" }\nglobalThis.__devLoop = { key: manifest.key, marker: ${JSON.stringify(marker)} }\n`
}

async function project(marker = "ONE", manifest = manifestFor()) {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-dev-test-"))
  await mkdir(join(dir, "src"))
  await writeFile(join(dir, "manifest.json"), JSON.stringify(manifest, null, 2))
  await writeFile(join(dir, "src/index.ts"), sourceWith(marker))
  return dir
}

async function serve(dir: string) {
  const lines: string[] = []
  const dev = await createDevServer({
    dir,
    esbuild: { context },
    host: "127.0.0.1",
    port: 0,
    log: (line: string) => lines.push(line),
    warn: (line: string) => lines.push(line),
  })
  return { dev, lines }
}

/// The server's Server-Sent Events as parsed events, one `next()` at a time,
/// each bounded so a loop that never reloads fails the test rather than
/// hanging it.
async function events(url: string) {
  const res = await fetch(`${url}/events`)
  const reader = res.body!.getReader()
  const decoder = new TextDecoder()
  let buffer = ""
  const queue: Record<string, unknown>[] = []
  return {
    async next(timeoutMs = 15_000): Promise<Record<string, unknown>> {
      const deadline = Date.now() + timeoutMs
      while (queue.length === 0) {
        const remaining = deadline - Date.now()
        if (remaining <= 0) throw new Error(`no event within ${timeoutMs}ms`)
        const chunk = await Promise.race([
          reader.read(),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error(`no event within ${timeoutMs}ms`)), remaining)),
        ])
        if (chunk.done) throw new Error("event stream closed")
        buffer += decoder.decode(chunk.value, { stream: true })
        let at
        while ((at = buffer.indexOf("\n\n")) !== -1) {
          const frame = buffer.slice(0, at)
          buffer = buffer.slice(at + 2)
          for (const line of frame.split("\n")) if (line.startsWith("data: ")) queue.push(JSON.parse(line.slice(6)))
        }
      }
      return queue.shift()!
    },
    close: () => reader.cancel().catch(() => {}),
  }
}

/// Written a beat after the server settled, so the watcher sees a change
/// rather than the file it just built.
async function edit(path: string, contents: string) {
  await new Promise((r) => setTimeout(r, 150))
  await writeFile(path, contents)
}

/// The way most editors save: a temporary file renamed over the original,
/// which gives the file a new inode.
async function atomicEdit(path: string, contents: string) {
  await new Promise((r) => setTimeout(r, 150))
  await writeFile(`${path}.tmp`, contents)
  await rename(`${path}.tmp`, path)
}

test("the first build is served under the app's protocol, with the index entry the app reads", async () => {
  const dir = await project()
  const { dev } = await serve(dir)
  try {
    const ping = await (await fetch(`${dev.url}/ping`)).json()
    // The app's client refuses any other server name and any other protocol
    // before it reads anything else.
    assert.deepEqual(ping, { server: SERVER_NAME, protocol: PROTOCOL, extensions: [KEY] })
    assert.equal(SERVER_NAME, "halo-ext-dev")

    const index = await (await fetch(`${dev.url}/index.json`)).json()
    assert.equal(index.extensions.length, 1)
    const entry = index.extensions[0]
    // What the app decides before loading a bundle has to be here: the grant
    // list it shows, the level it checks, how the row is listed.
    assert.equal(entry.key, KEY)
    assert.equal(entry.file, `${KEY}.js`)
    assert.equal(entry.api, H2KEXT_API_VERSION)
    assert.deepEqual(entry.domains, ["example.org"])
    assert.equal(entry.core, false)
    assert.equal(entry.category, "dashboard")
    assert.equal(entry.name, "Dev loop")
    assert.deepEqual(entry.hooks, ["panel"])
    assert.equal(entry.enabledByDefault, true)

    const bundle = await (await fetch(`${dev.url}/${KEY}.js`)).text()
    assert.ok(bundle.includes('"ONE"'), "the built bundle carries the source")
    assert.ok(bundle.includes(KEY), "the manifest import is bundled in")
  } finally {
    await dev.close()
  }
})

test("a saved edit reaches the app as a reload carrying the index entry, and the new bytes serve", async () => {
  const dir = await project()
  const { dev, lines } = await serve(dir)
  try {
    const stream = await events(dev.url)
    const hello = await stream.next()
    assert.equal(hello.type, "hello")
    assert.equal(hello.protocol, PROTOCOL)
    assert.deepEqual(hello.buildErrors, {})

    await edit(join(dir, "src/index.ts"), sourceWith("TWO"))
    const reload = await stream.next()
    assert.equal(reload.type, "reload")
    assert.equal(reload.key, KEY)
    // The reload IS the index entry, so a `domains` change travels with it
    // and the app applies it without a restart.
    assert.deepEqual(reload.domains, ["example.org"])
    assert.equal(reload.category, "dashboard")

    const bundle = await (await fetch(`${dev.url}/${KEY}.js`)).text()
    assert.ok(bundle.includes('"TWO"') && !bundle.includes('"ONE"'), "the served bundle is the edit")
    assert.ok(
      lines.some((l) => l.includes(`✓ ${KEY}`)),
      "the rebuild is reported",
    )
    stream.close()
  } finally {
    await dev.close()
  }
})

test("a broken save is reported with its file and line while the last good bundle keeps serving, and fixing it reloads", async () => {
  const dir = await project()
  const { dev } = await serve(dir)
  try {
    const stream = await events(dev.url)
    await stream.next() // hello

    await edit(join(dir, "src/index.ts"), 'globalThis.__devLoop = { marker: "BROKEN"\n')
    const failure = await stream.next()
    assert.equal(failure.type, "buildError")
    assert.equal(failure.key, KEY)
    assert.match(String(failure.message), /src\/index\.ts:\d+/, "the error names the file and line")

    // The app asked for what builds; a half-written file is not a reason to
    // take the extension away.
    const bundle = await (await fetch(`${dev.url}/${KEY}.js`)).text()
    assert.ok(bundle.includes('"ONE"'), "the last good bundle still serves")
    assert.equal(dev.buildError !== null, true)

    // Undoing the typo produces the same bytes as before the error. That is
    // still a reload: the app clears the error only when one arrives.
    await edit(join(dir, "src/index.ts"), sourceWith("ONE"))
    const recovery = await stream.next()
    assert.equal(recovery.type, "reload")
    assert.equal(dev.buildError, null)
    stream.close()
  } finally {
    await dev.close()
  }
})

test("a manifest the packer would refuse is a build error, not something the app is handed", async () => {
  const dir = await project()
  const { dev } = await serve(dir)
  try {
    const stream = await events(dev.url)
    await stream.next() // hello

    await edit(join(dir, "manifest.json"), JSON.stringify(manifestFor({ webSockets: ["stream.example.org"], api: 1 }), null, 2))
    const failure = await stream.next()
    assert.equal(failure.type, "buildError")
    assert.match(String(failure.message), /'webSockets' needs 'api' 2/)

    // The index still describes the manifest the served bundle was built
    // against, never the refused one.
    const index = await (await fetch(`${dev.url}/index.json`)).json()
    assert.equal(index.extensions[0].api, H2KEXT_API_VERSION)
    assert.equal(index.extensions[0].webSockets, undefined)
    stream.close()
  } finally {
    await dev.close()
  }
})

test("a manifest saved the way editors save, by renaming a temporary file over it, still reaches the app", async () => {
  const dir = await project()
  // An entry that does not import the manifest: the only thing that can see
  // this edit is the watch on the directory.
  await writeFile(join(dir, "src/index.ts"), 'globalThis.__devLoop = { marker: "NO-MANIFEST-IMPORT" }\n')
  const { dev } = await serve(dir)
  try {
    const stream = await events(dev.url)
    await stream.next() // hello
    await atomicEdit(join(dir, "manifest.json"), JSON.stringify(manifestFor({ domains: ["example.org", "api.example.org"] }), null, 2))
    const first = await stream.next()
    assert.equal(first.type, "reload")
    assert.deepEqual(first.domains, ["example.org", "api.example.org"])
    // A watch on the file alone would have followed the old inode and gone
    // quiet here.
    await atomicEdit(join(dir, "manifest.json"), JSON.stringify(manifestFor({ domains: ["example.org", "api.example.org", "cdn.example.org"] }), null, 2))
    const second = await stream.next()
    assert.equal(second.type, "reload")
    assert.deepEqual(second.domains, ["example.org", "api.example.org", "cdn.example.org"])
    stream.close()
  } finally {
    await dev.close()
  }
})

test("an ABOUT.md saved on its own reaches the app as a reload carrying it", async () => {
  const dir = await project()
  const { dev } = await serve(dir)
  try {
    const stream = await events(dev.url)
    await stream.next() // hello
    await edit(join(dir, "ABOUT.md"), "Keeps **notes**.\n")
    const reload = await stream.next()
    assert.equal(reload.type, "reload")
    assert.equal(reload.about, "Keeps **notes**.")
    stream.close()
  } finally {
    await dev.close()
  }
})

test("declaring a shared library in the manifest rebuilds with it taken from the app, without a restart", async () => {
  const { i18next: _declared, ...withoutI18next } = SCAFFOLD_SHARED_DEPENDENCIES as Record<string, string>
  const dir = await project("ONE", manifestFor({ sharedDependencies: withoutI18next }))
  await writeFile(join(dir, "src/index.ts"), 'import i18next from "i18next"\nglobalThis.__devLoop = { marker: "SHARED", i18next }\n')
  const { dev } = await serve(dir)
  try {
    // Undeclared, the build is refused rather than shipping a private copy,
    // and until it builds the app is served an extension that does nothing.
    assert.match(String(dev.buildError), /i18next/)
    const stream = await events(dev.url)
    const hello = await stream.next()
    assert.match(String((hello.buildErrors as Record<string, string>)[KEY]), /i18next/)
    assert.equal(await (await fetch(`${dev.url}/${KEY}.js`)).text(), EMPTY_BUNDLE)

    // The build context was made with the old `sharedDependencies`; a plain
    // rebuild under it would refuse i18next again. Declaring it has to reach
    // the build, not only the reload's manifest entry.
    await edit(join(dir, "manifest.json"), JSON.stringify(manifestFor(), null, 2))
    // A rebuild that reads the manifest while it is being written still builds
    // under the old one and reports the refusal again; only that may come first.
    let reload = await stream.next()
    for (let repeats = 0; reload.type === "buildError" && repeats < 5; repeats++) {
      assert.match(String(reload.message), /i18next/)
      reload = await stream.next()
    }
    assert.equal(reload.type, "reload")
    assert.equal(dev.buildError, null)
    const bundle = await (await fetch(`${dev.url}/${KEY}.js`)).text()
    assert.ok(bundle.includes('"SHARED"'))
    assert.deepEqual(findSharedModuleReferences(bundle), ["i18next"], "the library is a lookup on the app's copy, not inlined")
    stream.close()
  } finally {
    await dev.close()
  }
})

test("what the app's extensions log comes back to the terminal", async () => {
  const dir = await project()
  const { dev, lines } = await serve(dir)
  try {
    const res = await fetch(`${dev.url}/logs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ lines: ["hello from the phone", "and again"] }),
    })
    assert.equal(res.status, 204)
    assert.ok(lines.some((l) => l.endsWith("│ hello from the phone")))
    assert.ok(lines.some((l) => l.endsWith("│ and again")))

    // The web build preflights the POST; without a 204 here that request is
    // refused and log forwarding dies silently.
    const preflight = await fetch(`${dev.url}/logs`, { method: "OPTIONS", headers: { origin: "http://localhost:8769" } })
    assert.equal(preflight.status, 204)
    assert.equal(preflight.headers.get("access-control-allow-origin"), "http://localhost:8769")
  } finally {
    await dev.close()
  }
})

/// One raw request, so the test chooses the Host and Origin headers a browser
/// would send, which fetch does not let it set.
function rawRequest(
  url: string,
  { method = "GET", path = "/", headers = {}, body }: { method?: string; path?: string; headers?: Record<string, string>; body?: string },
) {
  const { hostname, port } = new URL(url)
  return new Promise<{ status: number; headers: Record<string, unknown> }>((resolveRequest, rejectRequest) => {
    const req = request({ host: hostname, port, method, path, headers }, (res) => {
      res.resume()
      res.on("end", () => resolveRequest({ status: res.statusCode!, headers: res.headers }))
    })
    req.on("error", rejectRequest)
    req.end(body)
  })
}

test("a log line prints as text: control characters show escaped, and what is not a list of strings prints nothing", async () => {
  // Anything on the network can post here. A line that reached the terminal
  // raw could clear it, retitle the window, write the clipboard (OSC 52), or
  // print what looks like the server's own "Point the app at" block.
  const dir = await project()
  const { dev, lines } = await serve(dir)
  try {
    const post = (body: unknown) => fetch(`${dev.url}/logs`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) })
    await post({ lines: ["\u001b[2J\u001b]0;build ok\u0007Point the app at:\n  http://attacker:8787", "tab\there", "\u009b31m"] })
    const printed = lines.filter((l) => l.includes("│"))
    assert.equal(printed.length, 3, "one line in, one line out: a newline cannot start a line of its own")
    assert.ok(
      printed.every((l) => !/[\u0000-\u0008\u000a-\u001f\u007f-\u009f]/.test(l)),
      JSON.stringify(printed),
    )
    assert.ok(printed[0].endsWith("│ \\x1b[2J\\x1b]0;build ok\\x07Point the app at:\\x0a  http://attacker:8787"))
    assert.ok(printed[1].endsWith("│ tab\there"), "a tab is how the app indents a stack trace")
    assert.ok(printed[2].endsWith("│ \\x9b31m"))

    lines.length = 0
    await post({ lines: "a string is not a list" })
    await post({ lines: [42, { nested: true }] })
    assert.ok(!lines.some((l) => l.includes("│")), JSON.stringify(lines))

    lines.length = 0
    await post({ lines: ["x".repeat(LOG_LINE_MAX + 10), ...Array(LOG_LINES_MAX + 4).fill("y")] })
    const capped = lines.filter((l) => l.includes("│"))
    assert.equal(capped.length, LOG_LINES_MAX + 1)
    assert.ok(capped[0].endsWith("… (10 more characters)"))
    assert.ok(capped.at(-1)!.endsWith("│ … 5 more lines"))
  } finally {
    await dev.close()
  }
})

test("a request target the server cannot read is answered 400, and the server keeps serving", async () => {
  const dir = await project()
  const { dev } = await serve(dir)
  try {
    const { port } = new URL(dev.url)
    const reply = await new Promise<string>((resolveReply, rejectReply) => {
      const socket = connect(Number(port), "127.0.0.1", () => socket.end("GET // HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"))
      let data = ""
      socket.on("data", (chunk) => (data += chunk))
      socket.on("end", () => resolveReply(data))
      socket.on("error", rejectReply)
    })
    assert.match(reply, /^HTTP\/1\.1 400/)
    assert.equal((await (await fetch(`${dev.url}/ping`)).json()).server, SERVER_NAME)
  } finally {
    await dev.close()
  }
})

test("only the app's own web build may use the server from a browser page", async () => {
  // Any other page the author has open could otherwise read the bundle being
  // written, and post into this terminal; one whose domain resolves to this
  // machine arrives as its own origin, and is told apart by its Host.
  const dir = await project()
  const { dev, lines } = await serve(dir)
  try {
    for (const origin of ["http://localhost:8769", "https://halo-dev.ham2k.net", "https://next-halo-dev.ham2k.net"]) {
      const res = await rawRequest(dev.url, { path: "/index.json", headers: { origin } })
      assert.equal(res.status, 200, origin)
      assert.equal(res.headers["access-control-allow-origin"], origin)
    }
    for (const origin of ["https://evil.example", "http://halo-dev.ham2k.net", "https://evilham2k.net", "null"]) {
      assert.equal((await rawRequest(dev.url, { path: "/index.json", headers: { origin } })).status, 403, origin)
      assert.equal((await rawRequest(dev.url, { path: `/${KEY}.js`, headers: { origin } })).status, 403, origin)
    }
    const posted = await rawRequest(dev.url, {
      method: "POST",
      path: "/logs",
      headers: { origin: "https://evil.example", "content-type": "text/plain" },
      body: JSON.stringify({ lines: ["from a web page"] }),
    })
    assert.equal(posted.status, 403)
    assert.ok(!lines.some((l) => l.includes("from a web page")))

    assert.equal((await rawRequest(dev.url, { path: "/index.json", headers: { host: "rebound.example:8787" } })).status, 403)
    for (const host of ["192.168.1.20:8787", "[::1]:8787", "localhost:8787", "studio.local:8787"]) {
      assert.equal((await rawRequest(dev.url, { path: "/index.json", headers: { host } })).status, 200, host)
    }
  } finally {
    await dev.close()
  }
})

test("--allow-origin admits one more web page, named as a browser sends it", async () => {
  assert.deepEqual(parseArgs(["--allow-origin", "http://10.0.0.5:8080/", "--allow-origin", "https://example.org"]).allowOrigins, [
    "http://10.0.0.5:8080",
    "https://example.org",
  ])
  assert.throws(() => parseArgs(["--allow-origin", "10.0.0.5"]), DevServerError)
  const dir = await project()
  const lines: string[] = []
  const dev = await createDevServer({
    dir,
    esbuild: { context },
    host: "127.0.0.1",
    port: 0,
    allowOrigins: ["http://10.0.0.5:8080"],
    log: (l: string) => lines.push(l),
    warn: (l: string) => lines.push(l),
  })
  try {
    const res = await rawRequest(dev.url, { path: "/index.json", headers: { origin: "http://10.0.0.5:8080" } })
    assert.equal(res.status, 200)
    assert.equal(res.headers["access-control-allow-origin"], "http://10.0.0.5:8080")
  } finally {
    await dev.close()
  }
})

test("a project whose manifest the packer refuses at start still connects: the index lists it, the bundle does nothing, the hello says why", async () => {
  const dir = await project("ONE", manifestFor({ api: undefined }))
  const { dev } = await serve(dir)
  try {
    assert.match(String(dev.buildError), /missing 'api'/)
    // The app's client fetches every listed bundle before it subscribes to
    // events, so an empty index or a 404 here would end the connection before
    // the error could be read.
    const index = await (await fetch(`${dev.url}/index.json`)).json()
    assert.equal(index.extensions[0].key, KEY)
    assert.equal(await (await fetch(`${dev.url}/${KEY}.js`)).text(), EMPTY_BUNDLE)
    const stream = await events(dev.url)
    const hello = await stream.next()
    assert.match(String((hello.buildErrors as Record<string, string>)[KEY]), /missing 'api'/)
    stream.close()
  } finally {
    await dev.close()
  }
})

test("the command line refuses a port it cannot listen on, and an option it does not know", () => {
  assert.throws(() => parseArgs(["--port", "abc"]), DevServerError)
  assert.throws(() => parseArgs(["--port", "70000"]), DevServerError)
  assert.throws(() => parseArgs(["--port"]), DevServerError)
  assert.throws(() => parseArgs(["--watch"]), DevServerError)
  const options = parseArgs(["--port", "9000", "--host", "127.0.0.1", "--inline", "liquidjs, i18next"])
  assert.equal(options.port, 9000)
  assert.equal(options.host, "127.0.0.1")
  assert.deepEqual(options.inline, ["liquidjs", "i18next"])
  assert.equal(parseArgs([]).port, 8787)
  // Without it, Ham2K's own extensions could be packed but never dev-served.
  assert.equal(parseArgs(["--force-name"]).forceName, true)
  assert.equal(parseArgs([]).forceName, undefined)
})
