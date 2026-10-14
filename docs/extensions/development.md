# The extension dev loop

Editing an extension normally means `npm run build`, restarting the app, and
finding your way back to whatever you were looking at. The dev server replaces
that: it rebuilds as you save and hands the new bundle to a **running** app,
which swaps that one extension in place. Everything else — the other forty-odd
extensions, the operation you had open, the log you were part-way through —
keeps running.

```sh
cd extensions
npm run dev                      # every extension
npm run dev -- --only adif,scoring   # just the ones you're working on
npm run dev -- --port 9000       # default is 8787
```

It prints the URLs to point the app at. Then, in the app: **Settings →
Developer → Extension Dev Server**, enter the URL, connect.

## Why it's a server and not a folder

The app has to reach your build, and most of the time the app is on a phone.
A watched local path only ever works for a desktop build on the same machine —
so the loop is a small HTTP server on your LAN, which reaches a phone, a
tablet, a second laptop, and the desktop build equally.

It binds `0.0.0.0` by default for that reason. `--host 127.0.0.1` restricts it
to this machine if you'd rather.

## What the app does with it

On connect, the app fetches the server's index and, for every extension it
offers, uses the dev bundle **instead of** the one baked into the app. That is
what lets you iterate on `pota` itself, not just on something new. Anything the
server doesn't offer keeps running from the app's own assets, so `--only` is a
narrowing of what you're overriding, not a restriction on what runs.

Each save pushes a `reload`. The app re-fetches that one bundle and reloads it:
the old version's hooks are unregistered, the new source is evaluated, and its
`onActivation` runs. The extension's stored KV **survives** — a reload is not a
reinstall, and re-entering credentials on every save would make the loop
useless.

A save that doesn't compile pushes a `buildError` instead, with the file and
line. The app says so and keeps running the last version that built, so a
half-typed line doesn't take the extension away mid-edit.

## What it does not cover

**The kernel.** Reloading it means restarting the runtime, which is a different
operation from swapping one extension, so the server never serves one. It does
watch `sdk/src/kernel.ts` and tells you when it changes — a kernel change still
needs `npm run build` and an app restart, and nothing else in the loop would
say so.

The **rest of the SDK is** covered, because every extension bundle inlines it:
editing `sdk/src/templates.ts` rebuilds every extension that uses it. Only the
ones whose bundle actually came out different reload — an edit to a comment, or
to a module a given extension does not use, rebuilds it and changes nothing, and
reloading fifty extensions for that costs the running app a teardown and
re-activation apiece.

**Anything that isn't an extension.** Only the extensions the server watches
are live; the app's own Dart code still needs a normal hot reload or restart.

**Build secrets.** `host.secret()` returns null for anything served from the dev
server, whatever key the extension claims — secrets are visible only to
extensions baked into the app's assets. So a feature that depends on one (SOTA's
SSO login is the live example) degrades in the loop exactly as it does in a
build without the value configured. Everything else about that extension still
reloads. See `README.md`'s "Expect null and degrade".

## Running a hook in a test, without any of this

For a hook whose answer you want to PIN rather than look at, `sdk/src/testing.ts`
loads an extension and calls its hooks in a plain `node:test` run — no bundles,
no QuickJS, no Flutter:

```ts
import { fixtureOperation, fixtureQsos, loadExtension } from "../../../sdk/src/testing.ts"

const pota = await loadExtension(() => import("./index.ts"))

test("an activating operation is offered the park control", async () => {
  const controls = await pota.runHook("activity", "operationControls", {
    operation: fixtureOperation({ refs: [{ type: "potaActivation", ref: "US-0001" }] }),
  })
  assert.equal(controls[0].input.refType, "potaActivation")
})
```

`loadExtension` installs a stand-in kernel, imports your entry point and
activates it, so `runHook` reaches the hook the app would call — a registration
that stops happening fails the test rather than passing quietly. It throws when
the category, the key or the method is absent, so a test cannot exercise
nothing and still be green.

`fixtureOperation`, `fixtureQso` and `fixtureQsos` are plain JSON in the shapes
a hook receives; override any field. Host calls answer benignly (`getSettings`
gives `{}`, a lookup gives `[]`, everything else null — what an extension
already has to tolerate); pass `hostCalls` to answer a particular one, and
`ctx` to set the locale or anything else the hook reads.

From extension API 9 the app hands a hook the log's QSOs frozen — through
`ctx.getQsos`, and as a scorer's `qsos` — and so does `runHook`, taking the
level from your manifest (or `loadExtension(..., { api })`). A write to one
throws in your tests where it would throw in the app; copy what you mean to
change.

Timers run on a clock only the test moves. The extension's `host.setTimeout`
and friends go to the runtime's own timer queue — the same budget and rules —
and `ext.timers.advance(ms)` moves the clock, firing whatever comes due in
order and letting each callback's awaited work settle before the next:

```ts
await ext.runHook("panel", "start")
await ext.timers.advance(3_500)      // a 1000ms interval fires three times
assert.equal(ext.timers.pending, true)
```

From the first `advance`, `Date` follows the same clock, so a callback reads
the moment it fired; a fake timer read against a real clock tests nothing
(docs/design/time.md §7). It stays pinned for every test sharing that loaded
extension, and the next `loadExtension` goes back to real time. `advance`
rejects if a callback threw, a timer was ignored (one past the cap, say), or
the extension broke its budget; `loadExtension` rejects if a timer was set
while the extension was still loading, which in the app never fires. A bare `setTimeout` in the source is Node's here —
the build only rewrites it into the SDK's in a bundle — so code a test should
drive calls `host.setTimeout`.

One extension per test file, and `loadExtension` refuses a second. In the app
each bundle carries its own copy of the SDK, so `host.*` belongs to the
extension it was compiled into; in a test process they share one instance,
which binds host calls to whichever extension was defined last — two in a file
would answer each other's stubs. `node:test` already runs each file in its own
process, so this costs nothing.

Worked examples: `activities/wwbota/src/hooks.test.ts` (which controls an
activity offers, and its activation threshold) and
`contests/cqww/src/hooks.test.ts` (a contest scored over a fixture log).
Import the helper by path — it is deliberately not exported from the SDK's
index, because everything there is bundled into all fifty-odd extensions.

## Running a hook against your edit, without the app

`halo-ext` ([cli.md](cli.md)) can use the dev server too, so a hook can be
exercised against code that has never been written to the app's assets:

```sh
mise run ext -- --dev-server 127.0.0.1:8787 ref pota US-1234
```

It overlays the built bundles rather than replacing them — the server has no
kernel to give it, and everything it isn't serving still comes from the build.

## Reading your extension's log

`host.log()` output from a dev-server extension is forwarded back to the
terminal running `npm run dev`, prefixed with `│`. That's the point of the
server for the phone case: you can read your own log lines without hunting for
a device console.

## Bundles are built in memory

The dev server never writes to `app/assets/extensions`. A dev session that left
its output there would leave the working tree carrying bundles built for
iteration, which the next test run would pick up as if they had been built to
ship. `npm run build` remains the only thing that writes those files.

## The two builds cannot drift

The dev server and `build.mjs` import the same `build-config.mjs` — the same
bundle list, the same esbuild options, the same shared-module externalization.
This matters more than it sounds: a dev bundle that resolved `@ham2k/lib-*`
differently from the shipped one would send you chasing behaviour that exists
only in your loop. One module, imported by both, makes that structural rather
than a promise somebody has to keep.

## The protocol

For anyone changing either end. All JSON; `protocol` is bumped when the shape
changes.

| Endpoint | |
|---|---|
| `GET /ping` | `{server, protocol, extensions: [key…]}` — identifies the server |
| `GET /index.json` | `{extensions: [manifest entry…]}` — the same shape the app's own `index.json` uses, minus the kernel |
| `GET /<key>.js` | one bundle's source |
| `GET /events` | Server-Sent Events: `{type:'hello', protocol, buildErrors}`, `{type:'reload', key, …manifest}`, `{type:'buildError', key, message}` |
| `POST /logs` | `{lines: [String…]}` — what the app's extensions logged |

Server-Sent Events rather than a WebSocket because neither side then needs a
dependency for it: Node has no WebSocket server built in, and a reload
notification is one-way, which is all SSE is.
