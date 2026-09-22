// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension dev server (HALO-118): rebuilds extensions as you edit them and
// hands them to a running app, which reloads that one extension in place.
//
//   npm run dev                  # every extension, on the LAN
//   npm run dev -- --only pota   # just the ones you're working on
//
// Point the app at the printed URL under Settings → Developer → Extension Dev
// Server. It is over the LAN rather than a local file path because that is the
// only shape that reaches a phone, which is where most of this software runs.
//
// Bundles are built IN MEMORY and never written to app/assets/extensions: a dev
// session must not leave its output in the working tree, where the next test run
// would pick it up as if it had been built for shipping.
//
// The transport is Server-Sent Events plus a plain POST, not a WebSocket, so
// neither side needs a dependency for it — Node has no WebSocket server built
// in, and SSE is a one-way push, which is all a reload notification is.
//
// The kernel is watched but never SERVED: reloading it means restarting the
// runtime, which is a different operation from swapping an extension, so a
// change there is reported and left for the author to act on. The SDK *is*
// served, because every extension bundle inlines it — editing sdk/src rebuilds
// all of them, and each rebuild whose bytes actually changed reloads.

import { context } from "esbuild"
import { createServer } from "node:http"
import { networkInterfaces } from "node:os"

import { bundles, buildOptionsFor, indexEntryFor, loadHostSharedVersions, loadKnownExperiments, loadManifests, readManifest } from "./build-config.mjs"

/// Bumped when the protocol below changes shape, so an app built against an
/// older one says so instead of failing obscurely.
const PROTOCOL = 1

const args = process.argv.slice(2)
function argValue(name, fallback) {
  const i = args.indexOf(name)
  return i === -1 || i === args.length - 1 ? fallback : args[i + 1]
}

const port = Number(argValue("--port", "8787"))
// Checked rather than trusted: `server.listen(NaN)` does not throw, it binds an
// arbitrary ephemeral port — and the first thing anyone does with this tool is
// read a URL off the screen that would then name a port nothing is listening on.
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error(`--port must be a number between 1 and 65535, not "${argValue("--port", "")}"`)
  process.exit(1)
}
// 0.0.0.0 by default: a dev server only this machine can reach cannot serve the
// device the app is running on, which is the whole point.
const bindHost = argValue("--host", "0.0.0.0")
const only = argValue("--only", null)
  ?.split(",")
  .map((s) => s.trim())
  .filter(Boolean)

const hostSharedVersions = await loadHostSharedVersions()

const served = bundles.filter((b) => b.kind === "extension" && (!only || only.includes(b.key)))
if (only) {
  const unknown = only.filter((k) => !bundles.some((b) => b.key === k))
  if (unknown.length) {
    console.error(`unknown extension key(s): ${unknown.join(", ")}`)
    process.exit(1)
  }
}
await loadManifests(served)

/// Built source per extension key, and the last build error per key. A key with
/// an error still serves its previous source: the app asked for what builds, and
/// a half-written file mid-keystroke is not a reason to take the extension away.
const sources = new Map()
const buildErrors = new Map()

/// Connected apps. An SSE response per client.
const clients = new Set()

/// Resolved once each extension has built (or failed to) for the first time,
/// so startup can report a settled picture rather than a race. Until then
/// nothing is logged per-extension and nothing is broadcast: the initial build
/// is not a "reload", and there is nobody connected to hear about it.
const firstBuilds = new Map(
  served.map((b) => {
    let resolve
    const promise = new Promise((r) => {
      resolve = r
    })
    return [b.key, { promise, resolve }]
  }),
)
let watching = false

function broadcast(event) {
  const payload = `data: ${JSON.stringify(event)}\n\n`
  for (const client of clients) {
    try {
      client.write(payload)
    } catch {
      clients.delete(client)
    }
  }
}

function stamp() {
  return new Date().toTimeString().slice(0, 8)
}

const knownExperiments = await loadKnownExperiments()

/// Re-reads one extension's manifest after a rebuild. `src/index.ts` imports
/// manifest.json, so editing it triggers a rebuild — and `domains` travels with
/// the reload, so an author who just declared a new host gets it applied
/// without restarting anything.
///
/// Validated exactly as `npm run build` validates it (readManifest throws), so
/// a manifest the shipping build would reject — a changed key, a missing field,
/// an experiment the catalog doesn't define — fails here too instead of being
/// broadcast to the app.
async function refreshManifest(bundle) {
  bundle.manifest = await readManifest(bundle, knownExperiments)
}

function watchPlugin(bundle) {
  return {
    name: "halo-dev-serve",
    setup(build) {
      build.onEnd(async (result) => {
        const done = () => firstBuilds.get(bundle.key)?.resolve()
        if (result.errors.length) {
          const message = result.errors.map((e) => `${e.location ? `${e.location.file}:${e.location.line}: ` : ""}${e.text}`).join("\n")
          buildErrors.set(bundle.key, message)
          if (watching) console.error(`${stamp()}  ✗ ${bundle.key}\n${message}`)
          if (watching) broadcast({ type: "buildError", key: bundle.key, message })
          done()
          return
        }
        try {
          await refreshManifest(bundle)
        } catch (e) {
          // A manifest that no longer parses is a build error like any other —
          // the bundle that just built embeds the OLD one, so serving it would
          // quietly disagree with the file on disk.
          const message = `manifest.json: ${e.message}`
          buildErrors.set(bundle.key, message)
          if (watching) console.error(`${stamp()}  ✗ ${bundle.key}\n${message}`)
          if (watching) broadcast({ type: "buildError", key: bundle.key, message })
          done()
          return
        }
        // Recovering from a build error is a reload even when the bytes are
        // the same as the last good ones, which is exactly what undoing a typo
        // produces: the app clears an extension's error only when a reload
        // arrives, so staying quiet here would leave it reported as broken.
        const hadError = buildErrors.has(bundle.key)
        buildErrors.delete(bundle.key)
        const built = result.outputFiles[0].text
        // Every extension inlines the SDK, so one edit under sdk/src rebuilds
        // all ~50 of them — but only a few carry code that actually changed.
        // Reloading an extension whose bytes are identical costs the running
        // app a teardown and re-activation for nothing, which at fifty at once
        // is the difference between a loop and a pause.
        const unchanged = sources.get(bundle.key) === built && !hadError
        sources.set(bundle.key, built)
        done()
        if (!watching) return // the initial build is summarised at startup
        if (unchanged) return
        const size = (result.outputFiles[0].contents.byteLength / 1024).toFixed(1)
        console.log(`${stamp()}  ✓ ${bundle.key} — ${size} KB`)
        broadcast({ type: "reload", key: bundle.key, ...indexEntryFor(bundle) })
      })
    },
  }
}

/// The kernel, built only to be watched. It is never served (see the note at
/// the top), so its output is discarded — what the author needs is to be told
/// that the runtime they are running no longer matches its source, since
/// nothing else in this loop would say so.
async function watchKernel() {
  const kernel = bundles.find((b) => b.kind === "kernel")
  if (!kernel) return
  const options = buildOptionsFor(kernel, { hostSharedVersions })
  options.logLevel = "silent"
  // Its own first build is not a change — this watcher starts after the
  // extensions', when `watching` is already true, so it cannot use that.
  let built = false
  options.plugins = [
    ...(options.plugins ?? []),
    {
      name: "halo-dev-kernel-watch",
      setup(build) {
        build.onEnd((result) => {
          const first = !built
          built = true
          if (first) return
          if (result.errors.length) {
            console.error(`${stamp()}  ✗ kernel\n${result.errors.map((e) => e.text).join("\n")}`)
            return
          }
          console.log(`${stamp()}  ⟳ kernel changed — run \`npm run build\` and restart the app to pick it up`)
        })
      },
    },
  ]
  const ctx = await context(options)
  await ctx.watch()
  return ctx
}

const contexts = []
for (const bundle of served) {
  const options = buildOptionsFor(bundle, { hostSharedVersions })
  options.plugins = [...(options.plugins ?? []), watchPlugin(bundle)]
  // Errors must not abort the server — an author saves broken code constantly,
  // and the loop's job is to report it and stay up.
  options.logLevel = "silent"
  const ctx = await context(options)
  contexts.push(ctx)
  await ctx.watch()
}
await Promise.all([...firstBuilds.values()].map((b) => b.promise))
watching = true

// After the first builds, so its message cannot land amid the startup summary.
const kernelContext = await watchKernel()
if (kernelContext) contexts.push(kernelContext)

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`)
  // Any origin: the app is not a browser page, and this server is a
  // development tool bound to a LAN by choice.
  res.setHeader("Access-Control-Allow-Origin", "*")
  if (req.method === "OPTIONS") {
    // `content-type: application/json` is not CORS-safelisted, so a web build
    // preflights POST /logs. Without this the preflight fell through to the
    // 404 below and log forwarding died silently — `_flushLogs` swallows it.
    res.writeHead(204, {
      "access-control-allow-methods": "GET, POST, OPTIONS",
      "access-control-allow-headers": "content-type",
      "access-control-max-age": "86400",
    })
    res.end()
    return
  }

  if (url.pathname === "/ping") {
    return json(res, {
      server: "halo-ext-dev",
      protocol: PROTOCOL,
      extensions: served.map((b) => b.key),
    })
  }

  if (url.pathname === "/index.json") {
    // Deliberately no `kernel` key: this server serves extensions only, and an
    // app that took a kernel from here would be swapping the runtime out from
    // under itself.
    return json(res, { extensions: served.filter((b) => sources.has(b.key)).map(indexEntryFor) })
  }

  if (url.pathname === "/events") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      connection: "keep-alive",
    })
    // The backlog matters: an extension that failed its FIRST build is absent
    // from /index.json, so the app quietly runs the version it shipped with
    // while the author edits a file whose code is not loaded. Without this the
    // pane would report every extension healthy and say nothing about it.
    res.write(
      `data: ${JSON.stringify({
        type: "hello",
        protocol: PROTOCOL,
        buildErrors: Object.fromEntries(buildErrors),
      })}\n\n`,
    )
    clients.add(res)
    console.log(`${stamp()}  ▸ app connected (${clients.size} connected)`)
    req.on("close", () => {
      clients.delete(res)
      console.log(`${stamp()}  ▪ app disconnected (${clients.size} connected)`)
    })
    return
  }

  if (url.pathname === "/logs" && req.method === "POST") {
    // The remote console: the app forwards what its extensions logged, so an
    // author working against a phone can read their own log lines here rather
    // than going hunting for a device console.
    const body = await readBody(req)
    try {
      for (const line of JSON.parse(body).lines ?? []) console.log(`${stamp()}  │ ${line}`)
    } catch {
      console.error(`${stamp()}  ! unreadable log payload`)
    }
    res.writeHead(204).end()
    return
  }

  const match = url.pathname.match(/^\/([\w.-]+)\.js$/)
  if (match) {
    const source = sources.get(match[1])
    if (source === undefined) {
      res.writeHead(404, { "content-type": "text/plain" })
      res.end(buildErrors.get(match[1]) ?? `no such extension: ${match[1]}`)
      return
    }
    res.writeHead(200, { "content-type": "application/javascript; charset=utf-8" })
    res.end(source)
    return
  }

  res.writeHead(404, { "content-type": "text/plain" })
  res.end("not found")
})

function json(res, body) {
  res.writeHead(200, { "content-type": "application/json; charset=utf-8" })
  res.end(JSON.stringify(body))
}

/// Reads a request body, capped and error-terminated. A client that aborts
/// mid-POST would otherwise leave this promise pending forever and the request
/// handler with it.
function readBody(req, limit = 1 << 20) {
  return new Promise((resolve) => {
    let data = ""
    req.on("data", (chunk) => {
      data += chunk
      if (data.length > limit) {
        data = data.slice(0, limit)
        req.destroy()
        resolve(data)
      }
    })
    req.on("end", () => resolve(data))
    req.on("error", () => resolve(""))
    req.on("aborted", () => resolve(""))
  })
}

server.listen(port, bindHost, () => {
  const failed = served.filter((b) => !sources.has(b.key))
  console.log(`\nHaLo extension dev server — ${sources.size} extension${sources.size === 1 ? "" : "s"} ready`)
  if (failed.length) console.log(`  ${failed.length} failed to build: ${failed.map((b) => b.key).join(", ")}`)
  console.log("\nPoint the app at (Settings → Developer → Extension Dev Server):")
  for (const address of lanAddresses()) console.log(`  http://${address}:${port}`)
  console.log("\nWatching for changes. A kernel change is reported but not served —")
  console.log("it needs `npm run build` and an app restart.\n")
})

function lanAddresses() {
  const found = []
  for (const addresses of Object.values(networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family === "IPv4" && !address.internal) found.push(address.address)
    }
  }
  // localhost last: correct for a desktop build on this machine, useless for
  // the phone case this server exists for, so it should not be the first thing
  // read off the screen.
  return [...found, "localhost"]
}

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, async () => {
    for (const ctx of contexts) await ctx.dispose()
    server.close()
    process.exit(0)
  })
}
