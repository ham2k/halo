# Writing a Ham2K Logger extension

*This file is for the coding agent working in an extension project. Put it
in your project as `AGENTS.md` or `CLAUDE.md`. `h2kext-init` writes a short
`AGENTS.md` that points at the copy inside `@ham2k/extension-sdk`, which is
this file. Paths below are relative to that package,
`node_modules/@ham2k/extension-sdk/` in your project. The same pages are
online at <https://catalog.ham2k.net/docs>.*

You are building an extension for the Ham2K Logger: a TypeScript module the
app loads into a sandbox and calls through **hooks**. Extensions are where
the app's domain knowledge lives: award programs, contests, callsign
lookups, spot sources, exporters, panels, radio front panels.

Everything you need is in this package:

- `samples/` holds one worked extension per shape. Start there, with the one
  whose shape matches what you are building; the header comment in each
  `src/index.ts` says what it leaves out.
- `docs/` is the reference, pinned to the version of the SDK installed here.
  Read the section for what you are doing, not the whole page.
- `dist/index.d.ts` is the typed surface, and the final word wherever prose
  and types disagree.

## The shape of a project

```
manifest.json      the extension's public identity, read without running code
src/index.ts       imports the manifest, calls defineExtension, registers hooks
build.mjs          three lines around @ham2k/extension-tools' build preset
build/             generated: index.js + manifest.json
```

`npx -p @ham2k/extension-tools h2kext-init <callsign>-<name>` writes all of
it, with `build`, `dev`, `pack`, `typecheck` and `format` scripts in
`package.json`.

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
`category`, `api` and `sharedDependencies`. Spread the manifest into
`defineExtension` rather than retyping it: the packer reads the file, the
app reads the definition, and two copies drift. Every category you register
goes in the manifest's `hooks`.

## Build, check, pack, install

```sh
npm run typecheck                                   # tsc --noEmit
npm run build                                       # → build/index.js
npm run dev                                         # serve to the app, rebuild on save, print its log
npm run pack                                        # → <key>-<version>.h2kext
```

While working, run `npm run dev` and point the app's **Settings → Developer →
Extension Dev Server** at the address it prints: every save that builds swaps
the extension in the running app, a save that does not build is reported with
its file and line, and `host.log` lines come back to the terminal. Before
publishing, install the packed file in the app (**Settings → Extensions &
Features → Install from file…**), which runs the packer's checks the dev
server skips. Installing the same key again updates in place.

The packer is also the checker. It reports every problem at once and
refuses anything that would install cleanly and then misbehave where you
cannot watch it, so a clean pack is the strongest evidence available outside
the app. Run it whenever you change the manifest or the hooks you register.
`tsc` is the other half: the hook interfaces are typed, so a hook that
typechecks is registered under a category the app knows, with the methods
it will call. There is no unit-test harness in this package; keep hook logic
in plain functions you can test with the project's own runner.

## Where to read next

| Doing this | Read |
| --- | --- |
| Anything, before the reference: a whole worked extension of that shape | `samples/`: `k2hrc-hello-world` (the smallest panel), `k2hrc-hamqth` (lookup + login), `k2hrc-llota` (award program), `k2hrc-cqww` (contest + scoring), `k2hrc-dxcc` (award checklist), `k2hrc-radio` (HTML panel), `k2hrc-panel-scenes` (every scene control), `k2hrc-panafall` (panadapter) |
| The model: sandbox, activation, hooks, host, budgets, API levels | `docs/concepts.md` |
| A manifest field, a grant, relevance, what the packer refuses | `docs/manifest.md` |
| Any `host.*` call, the hook context (`ctx`), calling other extensions | `docs/host.md` |
| How hooks are registered and invoked, the category list | `docs/hooks.md` |
| A pane in a view: `getPanels`, `render`, content kinds, triggers | `docs/panels.md` |
| An interactive panel: layers, bindings, controls, layout, spectrum | `docs/scenes.md` |
| Reading or commanding the operator's radio | `docs/radio.md` |
| Callsign lookups and how answers merge | `docs/lookups.md` |
| Spot feeds, posting spots, the DX cluster | `docs/spots.md` |
| An award program: references, logging controls, suggestions, offline lists, the `referenceActivity` factory | `docs/activities.md` |
| Exports, ADIF fields, ADIF import | `docs/import-export.md` |
| A contest's score, an activity's activation rules, an award checklist | `docs/scoring.md` |
| A command typed in the call field | `docs/commands.md` |
| A login the operator keeps | `docs/accounts.md` |
| A settings screen for your extension | `docs/settings.md` |
| Any form, dialog or field the operator fills in | `docs/forms.md` |
| Anything with `{{ }}` in it: panel text, filenames, ADIF fields | `docs/templates.md` |
| Translating strings, numbers, dates, what the engine lacks | `docs/localization.md` |
| The `.h2kext` format, the build, keys, API levels | `docs/packaging.md` |
| The catalog: tokens, channels, review, what the app does after | `docs/publishing.md` |

## What the sandbox is

No Node, no DOM, no `fetch`, no `window`, no filesystem, no `Intl` on native
builds. One ES2020 engine evaluating one script. Everything in and out of a
hook is JSON. Reach the outside world through `host`:

```ts
import { host } from "@ham2k/extension-sdk"

await host.fetch(url, { timeout })   // https, only hosts your manifest's `domains` lists
host.webSocket(url)                  // wss, only hosts your manifest's `webSockets` lists
host.setTimeout(fn, ms)              // timers; a bare setTimeout reaches these too
await host.kvGet("key")              // session storage, namespaced to your extension
await host.kvSet("key", value)
await host.getSettings()             // the app's settings and your own group
await host.setSettings({ … })        // persisted; your group only
await host.showForm(form)            // ask the operator something
await host.showMessage({ … })        // tell them something
host.statusBar.setMessage({ … })     // the footer
host.log("…")                        // the app's debug output
```

Every hook method is `async (args, ctx)`. `ctx` carries `online`, `locale`,
the operator's number and date conventions, and reads into the log and the
spots board. `dist/index.d.ts` has the rest.

## Rules that are easy to break

- **Everything is budgeted, and refused at the call that would exceed the
  budget.** 32 host calls awaiting an answer per bundle; 8 `host.fetch` in
  flight (a ninth is refused, so batch a long list); 10 key-value entries of
  at most 4,096 characters each; 16 timers whose callbacks average at most
  10% of real time; 4 WebSockets, 12 opens a minute; 8 footer keys, 10
  notices a minute; dialogs 3 open, 3 waiting, 10 a minute, one extension's
  at a time; 4 radio commands queued. `docs/concepts.md` has the table.
- **A panel returns content, not widgets**: `markdown` (prefer it), `svg`,
  `html` (no scripts, no network, no navigation, and not on every platform),
  or a `scene`. Markdown is at most 262,144 characters, SVG 1,048,576, HTML
  4,194,304; an SVG has at most 16,384 elements nested 32 deep. Over a budget
  the pane shows a placeholder; nothing is drawn in part.
- **`host.fetch` reaches only the hosts your manifest's `domains` lists**,
  over https, refused at the call, not at build. A wildcard never reaches
  the local network. Set `timeout` on anything optional: a fan-out shares one
  time budget across every extension in the category.
- **The key-value store is session memory.** A runtime restart (an extension
  installed, enabled or disabled) clears it. Preferences go through
  `host.setSettings` or a settings panel; a login goes through the `account`
  hook, never a settings field of your own.
- **Using a shared library without declaring it fails the build.** The app
  carries `@ham2k/lib-*`, `i18next` and `liquidjs`; naming one in
  `sharedDependencies` rewrites your imports into lookups on the app's copy,
  worth roughly thirty times the bundle size. Do not install them. The
  scaffold already declares the eight the SDK itself reaches, so deleting one
  breaks a working build. `inline: ["liquidjs"]` in `build.mjs` ships your
  own copy on purpose.
- **Your key is `<callsign>-<name>`**, lowercase; `ham2k-` is reserved. It
  namespaces your storage and is what the app shows when it says where
  something came from. Sub-keys (a second settings panel, a chasing program)
  are `<key>_suffix`.
- **Declare the lowest `api` that has what you use**, and raise it when you
  reach for something newer: `docs/packaging.md` lists what each level added.
  The packer enforces a few of these (`webSockets` 2, `chasing` 9, the
  cluster 10, `requiresRadioRaw` 11); the rest install on an older app and
  fail there. The scaffold's `sharedDependencies` ranges are open-ended;
  replace them with the versions the build suggests.
- **`host.secret()` returns null** for an installed extension. Make public
  values constants; design everything else to degrade.
- **Throw for a bug, return empty for an expected condition.** A hook that
  throws takes its feature down for that call. Not configured, not found,
  offline: return `[]` or `null` as the page says.
- **A hook that hangs is worse than one that throws**: the app times out the
  whole fan-out. Keep `lookup`, a command's `interpret` and a panel on the
  `qso` trigger cheap.
- **Hook method names are routed by string.** `renderPanel` where `render`
  was meant is an extension that installs, activates, and does nothing. Type
  every hook with its SDK interface.
- **A runtime restart cancels your timers and closes your sockets without an
  `onclose`.** Set them from `onActivation`, never only from module scope.
  Reconnect with a growing delay, never straight from `onclose`.
- **`Intl` does not exist** on native builds and its fallbacks are silently
  wrong. Work in UTC; format numbers with `fmtInteger` and the separators in
  `ctx`; let the app format anything zoned.
- **Resolve strings per call** with `createTranslator(resources, ctx.locale)`;
  the operator can change language while you run. Identify the app to a
  service as `ctx.appName`.
- **Answer batch shapes whole and in order.** `adifImport` answers one entry
  per record positionally; `claimsForQsos` by uuid for every contact; a short
  answer is discarded.

## Before you say you are done

- `npm run typecheck`, `npm run build` and `npm run pack` all pass, and you
  read the build's activation-check output.
- The manifest's `hooks` lists every category you register, `ref:<type>`
  entries included; `settingsPanel` is listed if you register one, with a
  `settings.section`.
- `domains`, `webSockets` and every `requires*` grant name exactly what the
  code uses, and nothing more: the operator reads that list at install.
- `api` is the lowest level that has what you use; `sharedDependencies`
  carry the versions the build suggested.
- Nothing you wrote stores a password outside the `account` hook, relies on
  `host.secret()`, or builds a `Liquid` of its own.
- You have exercised every hook you registered against the running app,
  through the dev server or an installed `.h2kext` with Developer Mode on, or
  you have told the person why you could not.
