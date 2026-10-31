# Packaging

An extension travels as one file, a `.h2kext`, that the app installs from a
file, a link or the catalog. This page is the format, the build that
produces its contents, the key that names it, the packer that checks and
writes it, and the API levels it declares.

## The bundle

A `.h2kext` is a **zip**:

```
manifest.json     required: identity and capabilities
index.js          required: your extension, built
assets/           optional: icons, data, licence text
```

A zip rather than a tarball because the app must read `manifest.json`
without running any JavaScript and often without unpacking the rest: to
list an installed-but-disabled extension, and to show the operator what a
file asks for before they agree to install it. A zip's central directory
makes that a seek. It also opens by double-click on a desktop, like the
other archive formats that are zips underneath.

A bundle is **16 MiB at most**: the app never downloads more, the catalog
refuses more, and `h2kext-publish` refuses to send more.

## Building

```sh
npm install @ham2k/extension-sdk
npm install --save-dev @ham2k/extension-tools esbuild
```

```js
// build.mjs
import { build } from "esbuild"
import { buildExtension } from "@ham2k/extension-tools"

await buildExtension(build, { dir: import.meta.dirname })
```

`buildExtension` reads `manifest.json`, compiles `src/index.ts` into
`build/index.js`, and copies the manifest alongside, ready for the packer.
Its esbuild settings are requirements of the sandbox: one IIFE, because the
sandbox evaluates a script and has no module loader; `neutral`, because
there is no Node and no DOM; `es2020`, because that is what the engine
speaks. esbuild is yours to bring, so there is only ever one copy of it.

**Shared libraries.** Everything your manifest's `sharedDependencies` names
becomes a lookup on the instance the app already holds; everything else you
import is bundled as usual. The difference is not small:

| | bundle | packaged |
| --- | --- | --- |
| dependencies inlined | 1,430 KB | 218 KB |
| using the app's | 22 KB | 7 KB |

Using one of the app's libraries **without** declaring it fails the build,
naming the library and the two ways out. The alternative, a bundle that
silently carries its own copy with its own module state, is the failure
nothing would ever report. If the second copy is what you want, which is how
you use a version the app does not carry, say so:

```js
await buildExtension(build, { dir: import.meta.dirname, inline: ["liquidjs"] })
```

The preset also settles a trap every hand-written esbuild configuration
hits: the SDK reaches `liquidjs`, whose package entry points are its Node
builds, and `platform: 'neutral'` ignores the `browser` field that would
pick the right one, so a hand-written build fails on unresolvable Node
built-ins before it compiles anything.

**The activation check.** After compiling, the build activates the bundle
against a stand-in host and fails if it registers a settings panel the
manifest does not declare, since the app does not show an undeclared panel.
If activation needs more than the stand-in provides, the build succeeds and
prints a warning that the check did not run.

## Keys

An extension key is **`<yourcallsign>-<name>`**:

```
ki2d-my-clock        w7abc-notes        2e0abc-contest-helper
```

Lowercase letters, digits and hyphens, the callsign first. A callsign is a
namespace every author of this software already holds, globally unique,
free, and already meaningful to everyone here, so two people who never met
cannot ship the same key. The packer refuses anything else.

`ham2k-` is reserved for Ham2K's own extensions. There is no signing, so
anyone could claim it, and the key is what the app shows when it says where
something came from. The bare keys of the app's own core extensions are
reserved too; the app refuses a collision at install, since a standalone
packer cannot know what the app it is installed into contains.

The key is also your extension's identity in the app: it namespaces
everything the extension stores, and an installed bundle with the same key
**updates in place**, keeping what the earlier version stored.

## The packer

```sh
npx h2kext-pack build                      # writes <key>-<version>.h2kext here
npx h2kext-pack build -o my-extension.h2kext
```

The directory holds your built `index.js`, your `manifest.json` and
optionally `assets/`. The packer packages; it does not compile. It reports
every problem at once rather than one per run:

```
h2kext-pack: ./build is not ready to package:
manifest.json: missing required field 'name'
manifest.json: key 'my-clock' must start with your callsign — 'my' is not one (e.g. ki2d-my-clock)
manifest.json: missing 'api' — declare the extension API this was built against (currently 13)
```

It refuses what would install cleanly and then misbehave where you cannot
watch it: a malformed `relevance` that would ship a regional extension as a
worldwide one, a `webSockets` entry under an API level that has no sockets,
a `chasing` hook under a level whose apps would never ask it anything.
[The manifest](manifest.md#what-is-checked-and-where) lists every rule. It
prints `held for review on the catalog` for a settings placement a
reviewer will have to accept, so that is no surprise either.

`--force-name` waives the naming convention. It exists for Ham2K's own
packaging, which builds the extensions that ship inside the app under bare
keys and the reserved prefix; it does not waive what the runtime needs of a
key.

The format and its rules live in `@ham2k/extension-tools`, free of any
dependency on the app's repository, which is what lets all of this run
outside it.

## API levels

The extension API is numbered, and your manifest's `api` is the **lowest**
level that has everything you use. An app speaking an older level refuses
the bundle at install and says so; the catalog offers each app the newest
release it can run. The SDK's minor version is the level it describes
(SDK 1.13 is API 13) and `API_VERSION` exports it.

| Level | Adds |
| --- | --- |
| 1 | The hook categories, the host calls and the manifest as described on these pages, where no later level is named |
| 2 | `host.webSocket` and the manifest's `webSockets` |
| 3 | Timers (`host.setTimeout` and friends, with a bare `setTimeout` rewritten to them at build), `onShow` and `onHide` |
| 4 | `host.fetch` to a plain-`http://` host that Ham2K's proxy fronts |
| 5 | Panel scenes: the `scene` content kind, native controls, `strings`, `layout`, `after`, control `opacity` |
| 6 | The scene's `spectrum` control and `host.setRadioSpectrum` |
| 7 | `host.setRadio`, the keying calls (`sendRadioCw`, `playRadioVoice`, `setRadioPtt`, `stopRadioTransmit`), what `readRadio` adds with them, the scene's `radio` values, scale bindings, text glow, two-axis and menu knobs, the spectrum's `follow`, `span` and label `decimals` |
| 8 | The `developer` settings target |
| 9 | The `chasing` category; the log's QSOs frozen in `ctx.getQsos` and a scorer's `qsos`; `canStartTune` and `startTune` |
| 10 | The DX cluster: the `cluster` category, the `host.cluster*` calls and the three cluster grants |
| 11 | `requiresRadioRaw` and `host.sendRadioRaw`; `n1mm-history:` data-file URLs |
| 12 | `host.suggestQso`; scenes with up to 512 layers and 256 controls, `scroll` and `zoom`, `hoverSet`, `tapAt`, `scrollThrough`, `invertDrag`, the spectrum's `rising` and `autoSpan`; `display` on `ctx.getSpots` |
| 13 | A panel's `radio` trigger; the radio's dial among a scene's radio values and strings; `when` on layers and controls |

The packer enforces the levels it can tell from the manifest alone:
`webSockets` needs 2, `chasing` needs 9, a cluster grant or a `cluster` hook
needs 10, `requiresRadioRaw` needs 11. The rest is on you: a bundle that
calls `host.setRadio` under `api: 5` installs on an app that has no such
call and fails there.

Which versions of the shared libraries a given build of the app carries is
in its `assets/extensions/index.json`, under `sharedModules`. The scaffold
writes open-ended ranges (`^1.0.0`) into `sharedDependencies`; replace them
with the versions the build suggests before you ship.

## Before you ship

- `npm run typecheck`: a hook that typechecks is registered under a category
  the app knows, with the methods it calls, spelled as it calls them.
- `npm run build`, and read the activation check's output.
- `npm run pack`, clean. The packer is the strongest evidence available
  outside the app.
- Install the file in your own app (**Settings → Extensions & Features →
  Install from file…**) with **Settings → Developer → Developer Mode** on, so
  budget warnings reach you as notices, and exercise every hook you
  registered. The dev server is for the loop while you write; the installed
  file is the one path that runs everything the operator's install will.
- Check `api` against the table above, and `sharedDependencies` against the
  versions the build suggested.

Then [Publishing](publishing.md).
