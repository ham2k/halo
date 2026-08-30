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
npm run dev -- --only pota,cwt   # just the ones you're working on
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

**The kernel.** `sdk/src/kernel.ts` and anything only it imports are not
watched. Reloading the kernel means restarting the runtime, which is a
different operation from swapping one extension — so a kernel change still
needs `npm run build` and an app restart.

The **rest of the SDK is** covered, because every extension bundle inlines it:
editing `sdk/src/templates.ts` rebuilds every extension that uses it, and each
one reloads.

**Anything that isn't an extension.** Only the extensions the server watches
are live; the app's own Dart code still needs a normal hot reload or restart.

**Build secrets.** `host.secret()` returns null for anything served from the dev
server, whatever key the extension claims — secrets are visible only to
extensions baked into the app's assets. So a feature that depends on one (SOTA's
SSO login is the live example) degrades in the loop exactly as it does in a
build without the value configured. Everything else about that extension still
reloads. See `README.md`'s "Expect null and degrade".

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
