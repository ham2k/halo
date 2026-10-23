# @ham2k/extension-tools

Build and package extensions for the [Ham2K Logger](https://ham2k.com).

```sh
npm install --save-dev @ham2k/extension-tools esbuild
```

The minor version is the newest extension API the packer accepts — 1.12 packs
bundles up to `"api": 12` — and matches `@ham2k/extension-sdk`'s.

## Starting one

```sh
npx h2kext-init w7abc-notes
```

Writes a whole small extension — manifest, a panel that says hello, the build
script, a tsconfig — into the working directory, and refuses rather than
overwrite anything already there. An existing `package.json` is added to, never
replaced.

It also writes a `.prettierrc.json` and the `format` / `format:check` scripts,
and what it scaffolds is already in that style — so `npm run format:check`
passes on an untouched project, and the code an agent adds to it lands
formatted the same way. Configure Prettier already, anywhere it looks, and
yours is left in charge: no config is written, and the command says so.

It takes the key rather than defaulting one: a placeholder like
`n0call-my-extension` validates, so it would ship, which is the one outcome the
naming convention exists to stop.

The `AGENTS.md` it writes points at `@ham2k/extension-sdk`'s own — the hook
reference, the sandbox's limits, and what to read for what. That matters most
if something other than you is writing the code: an agent reads a project's
`AGENTS.md` unprompted, and otherwise never learns the reference is sitting in
`node_modules`.

## Building

```js
import { build } from 'esbuild'
import { buildExtension } from '@ham2k/extension-tools'

await buildExtension(build, { dir: import.meta.dirname })
```

Reads your `manifest.json`, compiles `src/index.ts` into `build/index.js`, and
copies the manifest alongside it. The esbuild settings it applies are
requirements of the runtime rather than preferences: one IIFE because the
sandbox evaluates a script and has no module loader, `neutral` because there is
no Node and no DOM, and `es2020` because that is what its engine speaks.

esbuild is yours to bring — the preset takes your `build` function rather than
importing its own, so there is only ever one copy of it.

Everything your manifest's `sharedDependencies` names becomes a lookup on the
library the host already holds, which is worth roughly thirty times the bundle
size. Using one **without** declaring it fails the build rather than quietly
shipping a private copy; pass `inline: ['liquidjs']` if that copy is what you
want, which is how you use a version the host does not carry.

It then activates the built bundle against a stand-in host, and fails the build
if the bundle registers a settings panel that your manifest's `hooks` does not
list: the app does not show an undeclared panel. If activation needs more than
the stand-in provides, or waits on a timer or the host, the build succeeds and
prints a warning that this check did not run.

## Packaging

```sh
npx h2kext-pack build -o my-extension.h2kext
```

Packages a directory holding a built `index.js`, a `manifest.json` and an
optional `assets/`. It packages; it does not compile.

It reports every problem at once, and refuses what would install cleanly and
then misbehave where you cannot see it. Extension keys are `<callsign>-<name>`
— the namespace every author of this software already holds, so two people who
never met cannot ship the same key.

## Publishing to the catalog

```sh
export H2K_CATALOG_TOKEN=h2kc_…
npx h2kext-publish build --notes "What changed"
```

Uploads a bundle to the [Ham2K extension catalog](https://catalog.ham2k.net),
where the app finds it. Sign in there and make a token under
[/publish](https://catalog.ham2k.net/publish); the command reads it from
`H2K_CATALOG_TOKEN` and from nowhere else — there is no flag for it, because a
flag lands in your shell history — and stores it nowhere. Publishing needs a
grant for your callsign prefix, which the same page is where you ask for.

A directory is packaged first, exactly as `h2kext-pack` would; a `.h2kext`
you already made is sent as it is. A bundle must be 16 MiB or smaller: the
app never downloads more than that, the catalog refuses more than that, and
the command refuses it before sending a byte. A version's bytes are frozen
the first time a reviewer approves them: from then on the same version with
different bytes is refused, so a fix is a new version.

Release notes go up in a second request, once the upload is accepted. If
that request is refused, the version is still published — the command says
so and exits 1, and you can write the notes on the site, where they can be
edited at any time.

The result line reads `published w7abc-notes 1.2.3 → prod (pending review)`.
"Pending review" means a Ham2K reviewer has not looked yet — the version is
stored, but nobody can install it until they approve it, and your dashboard on
the site shows the outcome and any note. Every refusal prints the catalog's
reason and exits 1; nothing is retried.

A channel says how finished a release is — `stable`, `unstable`, `bleeding` —
not which app edition is asking. They cascade upward, so `stable` reaches
everyone and `bleeding` reaches only somebody who asked for it. `--channel` is
optional and defaults to `stable`.

### Screenshots

```
screenshots/
  1-logging.png
  2-map.png
  screenshots.json    optional — { "1-logging.png": "Logging a park" }
```

When your project has a `screenshots/` folder (or you name one with
`--screenshots <dir>`), `h2kext-publish` makes the catalog's screenshots for
your extension match it, after the bundle is accepted. The folder is the
whole set: PNG, JPEG or WebP files, at most 8, shown in file-name order
(`2-…` before `10-…`), captions from `screenshots.json`. Screenshots are never
packed into the bundle, and they belong to the extension rather than to a
version: every channel shows the same ones, and
`h2kext-publish build --screenshots-only` updates them without publishing a
version.

Each screenshot is at most 2 MiB and 3840 pixels on its longest side. The
command makes the thumbnail the app shows in search results itself, with
[sharp](https://sharp.pixelplumbing.com) — an optional dependency, so if it
could not install on your machine the command says so, and you can add your
screenshots on the site's [/publish](https://catalog.ham2k.net/publish) page
instead. An unchanged folder sends nothing. A new set waits for a reviewer,
like a version, while the approved one keeps showing. An empty folder named
with `--screenshots` takes every screenshot down at once; an empty
`./screenshots` found on its own is left alone.
