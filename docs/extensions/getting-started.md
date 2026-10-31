# Getting started

From an empty directory to an extension installed in your own copy of the
app. You need Node 20 or later, the app on a device whose Settings you can
reach, and a callsign: every extension key is `<yourcallsign>-<name>`.

## Create a project

```sh
mkdir w7abc-notes && cd w7abc-notes
npx -p @ham2k/extension-tools h2kext-init w7abc-notes
npm install
```

`h2kext-init` takes the key rather than inventing one, and refuses to
overwrite anything already there. It writes a whole small extension:

```
manifest.json        your extension's public identity
src/index.ts         one panel that says hello
build.mjs            three lines around the build preset
tsconfig.json
AGENTS.md            points the agent writing your code at the reference in node_modules
.prettierrc.json     the style the scaffolded files are already in
.gitignore
package.json         added to, never replaced
```

`--dir <path>` writes into another directory instead of the current one, and
`--name "W7ABC Notes"` sets the display name instead of deriving it from the
key.

`package.json` gains the scripts the rest of this page uses: `build`,
`dev`, `pack`, `typecheck`, `format` and `format:check`. Starting by hand
instead:

```sh
npm install @ham2k/extension-sdk
npm install --save-dev @ham2k/extension-tools esbuild typescript
```

and write the three files below yourself.

## The three files

**`manifest.json`** is everything the app and the catalog know about your
extension without running it. The scaffold's is the minimum:

```json
{
  "key": "w7abc-notes",
  "name": "W7ABC Notes",
  "version": "0.1.0",
  "description": "W7ABC Notes, an extension for the Ham2K Logger",
  "category": "dashboard",
  "api": 13,
  "icon": "hand-wave-outline",
  "hooks": ["panel"],
  "sharedDependencies": { "@ham2k/lib-callsigns": "^1.0.0", "…": "…" }
}
```

`hooks` lists what the extension registers; the app reads it without
evaluating the bundle, so a panel left out of it installs and then cannot be
found. `sharedDependencies` names the libraries the SDK itself reaches, so
deleting one breaks a build that was working. [The manifest](manifest.md)
has every field.

**`src/index.ts`** imports the manifest and calls `defineExtension`:

```ts
import { defineExtension } from "@ham2k/extension-sdk"
import type { PanelHook } from "@ham2k/extension-sdk"

import manifest from "../manifest.json"

const HelloPanel: PanelHook = {
  async getPanels() {
    return [{ key: "hello", title: "W7ABC Notes", icon: "hand-wave-outline" }]
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

The manifest is spread into the definition rather than retyped. The packer
reads the file and the app reads the definition; two copies drift.

**`build.mjs`** hands your esbuild to the build preset:

```js
import { build } from "esbuild"
import { buildExtension } from "@ham2k/extension-tools"

await buildExtension(build, { dir: import.meta.dirname })
```

## Build

```sh
npm run typecheck
npm run build
```

The build compiles `src/index.ts` into `build/index.js` and copies the
manifest beside it. Its esbuild settings are requirements of the sandbox,
not preferences: one IIFE, because the sandbox evaluates a script and has
no module loader; `neutral`, because there is no Node and no DOM; `es2020`,
because that is what the engine speaks.

Every library your manifest's `sharedDependencies` names becomes a lookup on
the copy the app already carries, which is worth roughly thirty times the
bundle size. Using one of those libraries **without** declaring it fails the
build, naming the library and the two ways out: declare it, or pass
`inline: ["liquidjs"]` to `buildExtension` to ship your own copy. The build
then activates the bundle against a stand-in host and fails if it registers
a settings panel the manifest does not declare.

The typecheck is the other half. The hook interfaces are typed, so a hook
that typechecks is registered under a category the app knows, with the
methods it will call, spelled the way it will call them.

## Pack

```sh
npm run pack                                     # writes w7abc-notes-0.1.0.h2kext here
npx h2kext-pack build -o w7abc-notes.h2kext      # or name the output yourself
```

A `.h2kext` is a zip of `manifest.json`, `index.js` and an optional
`assets/`. The packer is also the checker: it reports every problem at once,
and refuses what would install cleanly and then misbehave where you cannot
watch it. A clean pack is the strongest evidence available outside the app.
[Packaging](packaging.md) lists what it checks.

## Install it

In the app, **Settings → Extensions & Features → Install from file…**, pick
the `.h2kext`, and read what it asks for. The runtime restarts with your
extension loaded, and it appears in its category, marked *Installed*, with a
switch and a way to remove it. Your panel is now in the list of panels the
operator can place in a view's layout.

On a phone or tablet, get the file onto the device the way you get any file
there, or host it over https and open an install link on the device:

```
com.ham2k.logger:///install_extension?url=https://example.org/w7abc-notes.h2kext
```

## Iterate

```sh
npm run dev                      # h2kext-dev
npm run dev -- --port 9000       # options go after the --
```

The dev server builds your extension in memory, rebuilds it as you save, and
hands each build to a running app, which swaps that one extension in place
with no install. In the app, **Settings → Developer → Extension Dev Server**,
enter one of the addresses the server prints, connect. The address carries
the port: `10.0.0.5:8787`, not `10.0.0.5`.

| Flag | |
| --- | --- |
| `--port <n>` | The port to listen on; default `8787` |
| `--host <address>` | The address to bind; default `0.0.0.0`, every interface, so a phone on the same network can reach it. `127.0.0.1` keeps it to this machine |
| `--entry <file>` | The entry point; default `src/index.ts` |
| `--inline <pkg,…>` | Shared libraries to bundle rather than take from the app, comma-separated |
| `--dir <path>` | The extension directory; default the current one |

`--entry` and `--inline` take what your `build.mjs` passes to `buildExtension`.
Pass the same values, or the build you watch is not the build you ship.

- Each save that builds reaches the app as a reload: the extension's hooks
  are unregistered, the new bundle is evaluated, its `onActivation` runs. The
  key-value store survives a reload.
- A save that does not build is reported in the terminal with its file and
  line, and the app keeps running the last version that did.
- `host.log("…")` lines come back to the terminal, prefixed with `│`, so you
  read your own log without hunting for a device console.
- A manifest change travels with the reload, so a newly declared `domains`
  entry applies without restarting anything. A manifest the packer would
  refuse is reported as a build error instead of being handed to the app.
- Anything the server does not serve keeps running from the app's own
  assets, so the rest of your installed extensions are unaffected.

Turn on **Settings → Developer → Developer Mode** while you work: the app
then surfaces warnings it would otherwise keep to itself, such as the timer
budget being broken, as notices that name your extension.

Install from a file (above) before you publish. The dev server skips the
packer's checks on the bundle, and installing the `.h2kext` is the one path
that runs everything the operator's install will. Installing a bundle whose
key is already installed **updates it in place**: its settings, credentials
and panel configuration survive, and the consent screen is shown again every
time.

There is no unit-test harness in the published SDK. Keep the logic of a hook
in plain functions you can test with the runner you already use, and keep
the hook object itself thin: it unpacks `args`, calls your function, and
returns the shape the page documents. The dev server is where you watch a
hook run against the real app.

## Make it yours

Decide which shape you are building and start from the sample closest to it.
The samples are in `node_modules/@ham2k/extension-sdk/samples/`:

| Building | Sample | Then read |
| --- | --- | --- |
| A dashboard panel | `k2hrc-hello-world`, `k2hrc-radio` (HTML) | [Panels](panels.md) |
| An interactive panel or a radio front panel | `k2hrc-panel-scenes`, `k2hrc-panafall` | [Panel scenes](scenes.md), [Radio control](radio.md) |
| A callsign lookup, with a login | `k2hrc-hamqth` | [Lookups](lookups.md), [Accounts & sync](accounts.md) |
| An award program with references | `k2hrc-llota` | [Activities](activities.md), [Import & export](import-export.md) |
| A contest | `k2hrc-cqww` | [Activities](activities.md), [Scoring & chasing](scoring.md) |
| An award checklist | `k2hrc-dxcc` | [Scoring & chasing](scoring.md) |

Copy the sample's `manifest.json` and `src/` over the scaffolded ones, set
the `key` back to yours, build and pack. The `k2hrc-` keys belong to the
samples: the packer accepts them, since `K2HRC` reads as a callsign, but the
catalog grants that prefix to nobody, and two samples installed under one
key would overwrite each other.

Every extension Ham2K publishes is in
[ham2k/extensions](https://github.com/ham2k/extensions), built exactly this
way. When a sample is too small to answer your question, the published
extension nearest your shape usually does.

## Next

[How extensions run](concepts.md) is the model the rest assumes. Then
[The manifest](manifest.md), [The host API](host.md), and
[How hooks work](hooks.md) with the page for your shape. When it does what
you want, [Publishing](publishing.md) puts it in front of other operators.
