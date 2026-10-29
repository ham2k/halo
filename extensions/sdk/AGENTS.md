# Writing a Ham2K Logger extension

*This file describes the published `@ham2k/extension-sdk` package, as installed
in an extension project's `node_modules`. Working inside the Ham2K Logger
repository itself is a different setup — see `docs/extensions/README.md` there.*

You are building an extension for the Ham2K Logger — a TypeScript module the
app loads into a sandbox and calls through **hooks**. Extensions are where the
app's domain knowledge lives: award programs, contests, callsign lookups, spot
sources, exporters, panels.

Everything you need is in this package. `samples/` holds one worked extension
per shape — start there, with the one whose shape matches what you are
building. `docs/` is the reference, pinned to the version of the SDK installed
here; `dist/index.d.ts` is the typed surface, and is the final word wherever
prose and types disagree.

Paths like `app/lib/config/secret_policy.dart` or `app/experiments.yaml`,
mentioned in those docs, are files in the Ham2K Logger's own repository
(<https://github.com/ham2k/halo>). They are not part of your project and you
cannot read them here.

## The shape of a project

```
manifest.json      your extension's public identity — read without running code
src/index.ts       imports the manifest, calls defineExtension
build.mjs          runs @ham2k/extension-tools' build preset
build/             generated: index.js + manifest.json
```

`npx -p @ham2k/extension-tools h2kext-init <yourcallsign>-<name>` writes all of it.

## The smallest whole extension

```ts
import { defineExtension } from "@ham2k/extension-sdk"
import type { PanelHook } from "@ham2k/extension-sdk"

import manifest from "../manifest.json"

const HelloPanel: PanelHook = {
  async getPanels() {
    return [{ key: "hello", title: "Hello World", icon: "hand-wave-outline" }]
  },
  async render() {
    return { kind: "markdown", content: "# Hello, World!" }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: manifest.key, hook: HelloPanel })
  },
})
```

`manifest.json` needs at least `key`, `name`, `version`, `description`,
`category`, `api`, and the `sharedDependencies` below. The manifest is spread
into `defineExtension` rather than retyped: two sources for the same identity
drift, and the packer reads the file.

## Building and shipping

```sh
node build.mjs                              # → build/index.js
npx -p @ham2k/extension-tools h2kext-pack build -o my-extension.h2kext
```

The packer is also the checker. It reports every problem at once and refuses
anything that would install cleanly and then misbehave where you cannot watch
it, so a clean pack is the strongest evidence available outside the app itself.
Run it whenever you have changed the manifest or the hooks you register.

`tsc --noEmit` is the other half: the hook interfaces are typed, and a hook that
typechecks is registered under a category the host knows, with the methods it
will actually call.

## Where to read next

| Doing this | Read |
| --- | --- |
| Anything, before the reference — a whole worked extension of that shape | `samples/`: `k2hrc-hello-world` (the smallest panel), `k2hrc-hamqth` (lookup + credentials), `k2hrc-llota` (award program), `k2hrc-cqww` (contest + scoring), `k2hrc-radio` (HTML panel), `k2hrc-panel-scenes` (experimental interactive panel scene), `k2hrc-panafall` (panadapter and waterfall scene) |
| Any hook at all — how hooks are invoked, what every hook is handed, and which page holds each category | `docs/hooks.md` |
| A pane in a view: `getPanels`, `render`, panel content kinds | `docs/panels.md` |
| An interactive panel: layers, bindings, controls, layout, a panadapter and waterfall | `docs/scenes.md` |
| Reading or commanding the operator's radio | `docs/radio.md` |
| Callsign lookups, spot sources, exporters, reference types (POTA-style) | `docs/lookups.md`, `docs/spots.md`, `docs/import-export.md`, `docs/activities.md` §`ref:<type>` |
| Contest or award scoring, and the UI an activity contributes | `docs/scoring.md`, `docs/activities.md` §`activity` |
| Commands typed in the call field, accounts, sync | `docs/commands.md`, `docs/accounts.md` |
| A settings screen for your extension | `docs/settings.md` |
| Any form, dialog or field the user fills in | `docs/forms.md` |
| Panel text, export filenames, ADIF fields — anything with `{{ }}` in it | `docs/templates.md` |
| Packaging, the `.h2kext` format, keys, using the host's libraries | `docs/distribution.md` |

Each hook page is long. Read the section for the category you are registering,
not the page.

## What the sandbox is

No Node, no DOM, no `fetch`, no `window`, no filesystem. One ES2020 engine
evaluating one script. Reach the outside world through `host`:

```ts
import { host } from "@ham2k/extension-sdk"

await host.fetch(url)          // https only (http-only hosts the Ham2K proxy fronts excepted), and only domains your manifest lists
host.webSocket(url)            // wss:// to hosts your manifest's webSockets lists
host.setTimeout(fn, ms)        // timers — plain setTimeout reaches these too
await host.kvGet('key')        // storage, namespaced to your extension
await host.kvSet('key', value)
await host.showForm(form)      // ask the user something
await host.showMessage({ … })  // tell them something
host.log('…')                  // the app's console
```

`dist/index.d.ts` has the rest, with the types.

## Traps worth knowing before you write anything

- **A panel returns content, not widgets.** `{ kind: "markdown", content }` and
  its siblings. There is no way to reach the app's UI toolkit, by design.
- **`host.fetch` only reaches domains your manifest's `domains` lists**, over
  https. An undeclared host is refused at the call, not at build. A wildcard
  entry (`*`, `*.example.com`) never reaches the local network — loopback, the
  private ranges, link-local, `localhost` and `.local` names — so gear in the
  shack is reachable only by naming its host, or while the app is in developer
  mode.
- **At most eight `host.fetch` calls per bundle are in flight at once.** A
  ninth is refused rather than queued, so a `Promise.all` over a long list of
  URLs fails past the eighth — run them in batches.
- **Every host call is budgeted.** At most 32 of your bundle's calls may await
  an answer at once, so a loop of un-awaited `host.*` calls fails at the
  thirty-third; `kvSet` holds at most 10 keys per bundle, each key and its
  value at most 4,096 characters of JSON — session state, not a cache; a
  bundle may open a socket at most 12 times a minute. A dialog — `showForm`,
  or `showMessage` as one — is one extension's at a time: three open, three
  waiting for another extension's to close, ten a minute; `showForm`
  completes with the form's answer, `showMessage` at once, its dialog opening
  when the surface is free. The footer holds eight of your keys, each string
  at most 1,024 characters (a notice's text 16,384), ten notices a minute,
  and a storm of progress reaches it once every 100 ms. Four of your `setRadio`
  calls may be in the queue at once — a fifth is answered `busy`, so re-send
  where a dragged control is once a call answers — and one that cannot go out
  within two seconds is answered `expired`.
- **Using a shared library without declaring it fails the build.** The app
  carries `@ham2k/lib-*`, `i18next` and `liquidjs`; naming one in
  `sharedDependencies` rewrites your imports into lookups on the app's single
  copy, which is worth roughly thirty times the bundle size. Don't install them.
  `inline: ["liquidjs"]` in your build ships your own copy, for when you need a
  version the app does not carry. A scaffolded manifest already declares the
  eight this SDK's own modules reach — importing anything from it pulls them
  in — so deleting one from the manifest breaks a build that was working.
- **Your key is `<callsign>-<name>`**, lowercase. It namespaces your storage and
  is what the app shows when it says where something came from. `ham2k-` is
  reserved.
- **`host.secret()` returns null** for anything not built into the app. Degrade;
  don't throw. A hook that throws takes its whole feature down.
- **Timers are budgeted, not free.** An extension's callbacks may average 10%
  of real time; past that, or after five throwing in a row, its timers are
  suspended until the extensions restart. At most 16 at once. Reconnect with a
  growing delay, never straight from `onclose`.
- **Hook method names are routed by string.** The host finds your hook by its
  registered key and then calls the method by name, so `renderPanel` where
  `render` was meant is an extension that installs, activates, and does nothing.
  This is what typing your hook as `PanelHook` (or its siblings) catches.
- **Every hook is async and crosses a bridge.** Some context reads carry a whole
  log — fine when exporting, not on a per-keystroke path.
