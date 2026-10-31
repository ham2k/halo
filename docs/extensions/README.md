# Ham2K Logger extensions

An extension teaches Ham2K Logger something it does not know on its own: an
award program and its references, a contest and its exchange, a callsign
lookup service, a spot source, an export format, a panel on the dashboard, a
front panel for a radio. The app itself knows nothing about any of these. It
calls **hooks**, functions an extension registers, with plain JSON, and reads
plain JSON back.

An extension is a TypeScript project built against `@ham2k/extension-sdk`,
packaged with `@ham2k/extension-tools` into a single `.h2kext` file, and
installed into the app from that file or from the
[extension catalog](https://catalog.ham2k.net). It runs in a sandbox inside
the app: no filesystem, no network beyond the hosts its manifest names, no
access to the app's UI toolkit. Everything it declares about itself lives in
one `manifest.json`, which the app reads before deciding whether to run it and
the catalog reads before deciding where to list it.

## What an extension can do

| Shape | What it registers | Page |
| --- | --- | --- |
| An award program (POTA, SOTA, WWFF…) | references the operator activates and hunts, an offline list of them, logging controls, ADIF fields, a spot feed | [Activities](activities.md), [Import & export](import-export.md), [Spots](spots.md) |
| A contest | the exchange fields, a scorer, a Cabrillo or ADIF export | [Activities](activities.md), [Scoring & chasing](scoring.md) |
| An award checklist (DXCC, WAS) | what each contact counts toward | [Scoring & chasing](scoring.md) |
| A callsign lookup | who a station is, from a service or from local data | [Lookups](lookups.md) |
| A spot source or destination | spots in, spots out, the DX cluster | [Spots](spots.md) |
| A dashboard panel | a document the app draws, or a scene it keeps live | [Panels](panels.md), [Panel scenes](scenes.md) |
| A radio panel | reading and commanding the operator's transceiver | [Radio control](radio.md) |
| A command | text the operator types in the call field | [Commands & templates](commands.md) |
| An account, a settings panel | credentials in the keychain, preferences in Settings | [Accounts & sync](accounts.md), [Settings panels](settings.md) |

One extension may be several of these at once. POTA is an activity, a lookup
source, a spot source and destination, an exporter and a settings panel.

## The smallest extension

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

The manifest is spread into `defineExtension` rather than retyped: the packer
reads the file, and the app reads the definition, and the two must agree.

## How the pieces fit

1. **You write** a `manifest.json` and a `src/index.ts` that calls
   `defineExtension`. [Getting started](getting-started.md) walks through it.
2. **The build** compiles your source into one `build/index.js`, rewriting
   the libraries the app already carries into lookups on the app's copy.
3. **The packer** checks the manifest and the bundle and writes a `.h2kext`,
   a zip of the two plus optional assets. [Packaging](packaging.md).
4. **The app** installs it, shows the operator what it asks for, and evaluates
   the bundle inside its sandbox alongside every other extension.
5. **At run time** the app calls your hooks and your hooks call the host:
   `host.fetch`, `host.kvSet`, `host.showForm` and the rest.
   [How extensions run](concepts.md), [The host API](host.md).
6. **The catalog** is how other operators find it. [Publishing](publishing.md).

## Reading path

Read in this order the first time:

1. [Getting started](getting-started.md): an empty directory to a bundle
   installed in your own app.
2. [How extensions run](concepts.md): the sandbox, activation, hooks, the
   host, budgets, API levels. The mental model the rest assumes.
3. [The manifest](manifest.md): every field, and what the packer refuses.
4. [The host API](host.md): every call an extension can make, and what each
   hook is handed in its context.
5. [How hooks work](hooks.md), then the reference page for the shape you
   are building.
6. [Packaging](packaging.md) and [Publishing](publishing.md).

Writing with a coding agent? Put [AGENTS.md](agents.md) in your project. It
is the same material, condensed for an agent that reads it before touching
anything.

## Every page

| Page | What it covers |
| --- | --- |
| [Getting started](getting-started.md) | Setup, the project layout, build, pack, install, the dev server |
| [How extensions run](concepts.md) | Sandbox, bundles, activation, hooks, host calls, storage, budgets, API levels |
| [The manifest](manifest.md) | Every manifest field; grants; relevance; settings placement; the packer's rules |
| [The host API](host.md) | Every `host.*` call, the hook context, the in-runtime `hooks.*` calls, the budgets |
| [Text and locale](localization.md) | Translating your strings, numbers and dates, what the engine lacks |
| [How hooks work](hooks.md) | Registration, keys and priority, invocation shapes, isolation, the category list |
| [Lookups](lookups.md) | `lookup`, `recentContextLookup`, and how answers merge |
| [Spots](spots.md) | `spots`, `cluster` |
| [Activities](activities.md) | `activity`, `ref:<type>`, `dataFile`, the `referenceActivity` factory |
| [Import & export](import-export.md) | `export`, `adifFields`, `adifImport` |
| [Scoring & chasing](scoring.md) | `scoring`, `chasing` |
| [Commands & templates](commands.md) | `command`, `template` |
| [Panels](panels.md) | `panel`: documents, triggers, config, previews, budgets |
| [Panel scenes](scenes.md) | Scenes: layers, bindings, controls, layout, spectrum, radio values |
| [Radio control](radio.md) | Reading, setting, keying and commanding radios |
| [Accounts & sync](accounts.md) | `account`, `syncTransport` |
| [Settings panels](settings.md) | `settingsPanel`, placement, field types, reading and writing settings |
| [Forms](forms.md) | The form schema shared by dialogs and settings |
| [Templates](templates.md) | Liquid templates, their vocabulary and filters |
| [Packaging](packaging.md) | The `.h2kext` format, building, keys, the packer, API levels |
| [Publishing](publishing.md) | The catalog: tokens, channels, review, screenshots, what the app does after |
| [AGENTS.md](agents.md) | A file to put in your project for the agent writing your extension |
| [Working in the Ham2K Logger repository](in-repo.md) | For contributors to the app itself: the dev server, `halo-ext`, the test harness |

## Examples

Eight worked samples ship inside `@ham2k/extension-sdk`, under `samples/`
once it is installed, and in the repository under
[`extensions/samples`](../../extensions/samples): the smallest panel, a
lookup behind an account, an award program, a contest, a chasing program, an
HTML panel, every scene control, and a panadapter. Each builds, each packs,
and the header comment in each `src/index.ts` says what it leaves out.

Every extension Ham2K publishes lives in
[ham2k/extensions](https://github.com/ham2k/extensions), MIT-licensed and
built the same way yours is. When the reference leaves you unsure what a
hook's answer should look like, find the extension closest to yours and read
it.

## Versions

The extension API is a number. Each level adds calls, hook methods or
manifest fields, and a bundle declares in its manifest the lowest level that
has what it uses, so every app that can run it is offered it. The SDK and the
tools follow the same numbering: SDK 1.13 describes API 13 and exports it as
`API_VERSION`. [Packaging](packaging.md#api-levels) lists what each level
added.

The docs shipped inside the SDK describe the version installed beside them.
The copy on [catalog.ham2k.net](https://catalog.ham2k.net/docs) describes
the latest.
