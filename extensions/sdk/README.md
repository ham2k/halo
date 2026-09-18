# @ham2k/extension-sdk

Write extensions for the [Ham2K Logger](https://ham2k.com) — the typed hook
contracts and the host API an extension is built against.

```sh
npm install @ham2k/extension-sdk
npm install --save-dev @ham2k/extension-tools esbuild
```

```ts
import { defineExtension } from '@ham2k/extension-sdk'
import type { PanelHook } from '@ham2k/extension-sdk'

import manifest from '../manifest.json'

const HelloPanel: PanelHook = {
  async getPanels() {
    return [{ key: 'hello', title: 'Hello World', icon: 'hand-wave-outline' }]
  },
  async render() {
    return { kind: 'markdown', content: '# Hello, World!' }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('panel', { key: manifest.key, hook: HelloPanel })
  },
})
```

A panel returns *content*, not widgets — which is what keeps extensions out of
the app's UI toolkit.

`npx -p @ham2k/extension-tools h2kext-init <yourcallsign>-<name>` writes
all of that and the build script; the same package packages the result into a
`.h2kext` the app can install.

## The reference is in this package

`samples/` holds one worked extension per shape — a callsign lookup with the
credentials it needs, an award program, a contest and its scorer, an HTML
panel. Each builds and packs; each says in its header what it leaves out.

`AGENTS.md` beside this file is the map — the manifest, the sandbox's limits,
and which of `docs/` answers what. `docs/` holds the references themselves:
every hook category, forms, settings panels, templates, and the bundle format.

They travel in the package rather than being linked to, so they are readable
offline and describe the version installed here rather than whatever the
repository says today. If an agent is writing your extension, point it at
`node_modules/@ham2k/extension-sdk/AGENTS.md` — `h2kext-init` does that for you.

## Export types and settings

Export hooks can register shared types with `getExportTypes()`. Use
`exportTypeDefinition(activationType, format, label)` for an identity shared
by extensions serving the same activity. `exportType` identifies the settings;
`exportKey` identifies an individual file, such as one park in an activation.

The `activityExportHook` and `huntingExportHook` helpers register their types
and forward export settings to the ADIF generator. Reference activity types
use `templateCategory: 'reference'`; other types use the other-activity defaults.
`GlobalExportSettings` provides separate normal filename, compact filename,
and title templates for each category, plus shared ADIF field templates.

When updating an exporter from SDK 0.3, keep a reference-specific identifier
in `exportKey`, register a stable `exportType`, and forward `exportSettings`,
`exportData`, `exportTitle`, and `includeLookupData` when delegating generation.
Per-type custom templates override inherited defaults only when enabled.
See `docs/hooks.md` §`export` for the complete contract and `docs/forms.md`
for the `textTemplate` form field.

## About the peer dependencies

This package lists the libraries the extension host carries — `@ham2k/lib-*`,
`i18next`, `liquidjs` — as **optional** peers, and you almost certainly do not
need to install any of them.

Your extension declares in its `manifest.json` which of them it uses, and the
build rewrites each one into a lookup on the host's single instance before
esbuild ever reaches the filesystem. Taking the host up on that is worth
roughly thirty times the bundle size. The published types have theirs rolled
in, so your editor works with only this package installed.

Install one only to `inline` it — to ship your own copy because you need a
version the host does not carry.
