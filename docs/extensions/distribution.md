# Distributing an extension — the `.h2kext` bundle

An extension can be handed to someone as a single file they install into the
app: no registry, no app-store release. This describes the format and the tool
that writes one.

Writing the extension in the first place is the dev loop's job —
[development.md](development.md).

## The format

A `.h2kext` is a **zip**:

```
manifest.json     required — identity and capabilities
index.js          required — your extension, built
assets/           optional — icons, data, licence text
```

Zip rather than tar.gz for one reason above the others: the host must read
`manifest.json` **without** running any JS and often without unpacking the
rest — to list an installed-but-disabled extension, and to show someone what a
file is asking for *before* they agree to install it. A zip's central
directory makes that a seek; a tar.gz is a solid stream that must be
decompressed from the beginning every time. Signed-archive precedent (`.vsix`,
`.xpi`, `.crx`, `.jar`, `.epub` are all zip) and being openable by
double-click on macOS and Windows settle the rest.

### manifest.json

The same manifest a built-in extension carries, plus `api`:

```json
{
  "key": "w7abc-notes",
  "name": "W7ABC Notes",
  "version": "1.2.3",
  "description": "Notes about the stations I work",
  "category": "dashboard",
  "api": 1,
  "domains": ["notes.example.org"],
  "icon": "note-text"
}
```

`api` is the extension API the bundle was built against. The host refuses one
it does not speak, so an older app meeting a newer bundle says so instead of
failing somewhere deep in a hook.

Two fields are **refused** in a distributed bundle, and it is worth
understanding why:

- **No `category`** makes an extension *core* to the host: always enabled, and
  never listed in the Extensions panel. That is a status the app grants its own
  extensions. A distributed bundle claiming it would be one the user could
  neither see nor turn off.
- **`experiments`** gates availability against the *app's* experiment catalog.
  A key the host doesn't define hides the extension permanently, with nothing
  in the UI to explain it.

### Geographic relevance

`geo` says where the extension is relevant. The catalog ranks its listing by
it, for the operators the extension was written for, and the Extensions
panel's Catalog section shows the catalog's rows in that order; nothing
hides an extension over it, and a manifest without one is worldwide. The
build index carries `geo` for the catalog and for later use; the panel does
not rank the app's own extensions by it.

```json
"geo": { "entities": ["CE"], "continents": ["SA"] }
```

Four lists, each an allowlist over the operator's own callsign: `entities`
(DXCC prefixes as the country file names them: `K`, `VE`, `CE`), `countries`
(ISO alpha-2: `us`, `cl`), `continents` (`AF AS EU NA OC SA AN`) and
`ituRegions` (`1`, `2`, `3`). A missing or empty list does not gate; values
within a list are ORed, the lists ANDed; case is the matcher's job. These are
the geo keys of HaLo's notices, rule for rule. The packer refuses:

- a `geo` that is not an object, or a key inside it other than those four;
- a list that is not a list, or an element that is not a non-empty string;
- a continent outside `AF AS EU NA OC SA AN`, or an ITU region outside `1`–`3`;
- a country that is not two letters, or an entity prefix that is not letters,
  digits and `/` (with an optional leading `*`).

The matcher reads a key it cannot parse as "does not gate", so each of the
shape errors would otherwise ship the bundle as worldwide.

## Using the host's libraries

The host carries a set of libraries and hands every extension the same
instances, so a bundle does not have to ship its own copies:

```
@ham2k/lib-callsigns      @ham2k/lib-qson-adif
@ham2k/lib-country-files  @ham2k/lib-qson-cabrillo
@ham2k/lib-cqmag-data     @ham2k/lib-qson-tools
@ham2k/lib-dxcc-data      i18next
@ham2k/lib-format-tools   liquidjs
@ham2k/lib-geo-tools
@ham2k/lib-operation-data
```

It matters more than it sounds. The same extension, built both ways:

| | bundle | packaged |
|---|---|---|
| dependencies inlined | 1430 KB | 218 KB |
| using the host's | 22 KB | **7 KB** |

**Declare what you need.** The host carries whatever version *that build*
shipped with, and you have no say in which app your bundle lands in. So the
manifest states the ranges you work with:

```json
"sharedDependencies": {
  "@ham2k/lib-callsigns": "^1.0.0",
  "liquidjs": "^10.0.0"
}
```

The host checks those before loading, and refuses a bundle it cannot satisfy —
which is a message naming the library and both versions, instead of a call
failing somewhere deep in a hook against a major you never tested.

The packer refuses a bundle that reaches for a shared module **without**
declaring it, and one that declares a package the host doesn't carry. Anything
outside that list you bundle yourself, as normal.

Which versions a particular build carries are in its
`assets/extensions/index.json`, under `sharedModules`.

Emitting the lookups is the build preset's job — see **Building** below.

## Building

```sh
npm install @ham2k/extension-sdk
npm install --save-dev @ham2k/extension-tools esbuild
```

`npx -p @ham2k/extension-tools h2kext-init <yourcallsign>-<name>` writes a working one of everything
below — manifest, source, build script — so the rest of this section is what to
change rather than what to type.

```js
import { build } from 'esbuild'
import { buildExtension } from '@ham2k/extension-tools'

await buildExtension(build, { dir: import.meta.dirname })
```

That reads `manifest.json`, compiles `src/index.ts` into `build/index.js`, and
copies the manifest alongside it, ready for the packer. The esbuild settings it
applies are requirements of the runtime rather than preferences: one IIFE
because the sandbox evaluates a script and has no module loader, `neutral`
because there is no Node and no DOM, and `es2020` because that is what
QuickJS-NG speaks.

esbuild is yours to bring — the preset takes your `build` function rather than
importing its own, so there is only ever one copy of it.

Everything `sharedDependencies` names becomes a lookup on the host's instance.
Anything else you use is bundled, as normal.

**Using one of the host's libraries without declaring it fails the build**,
naming the library and the two ways out. That is deliberate: the alternative is
a bundle that silently carries its own copy — thirty times the size, with its
own module state — and nothing anywhere that says so. If the second copy is
what you want, which is how you use a version the host does not carry, say so:

```js
await buildExtension(build, { dir: import.meta.dirname, inline: ['liquidjs'] })
```

`extensions/samples/hello-world` is the shortest complete example. Declaring
what it uses rather than carrying it took the packaged bundle from 185 KB to
**4 KB**.

The preset also settles a trap every author would otherwise hit: the SDK
reaches `liquidjs`, whose `main`/`module` are its **Node** builds, and
`platform: 'neutral'` ignores the `browser` field that would pick the right
one, so a hand-written esbuild config fails on unresolvable Node built-ins
before it compiles anything — even for an extension that never renders a
template.

## Packaging

```sh
node extensions/tools/h2kext-pack.mjs <directory> [-o out.h2kext]
```

The directory holds your built `index.js`, your `manifest.json`, and optionally
`assets/`. The packer **packages; it does not compile** — building is yours,
which is what lets this work outside this repo.

It reports every problem at once rather than one per run:

```
h2kext-pack: ./build is not ready to package:
manifest.json: missing required field 'name'
manifest.json: key 'my-clock' must start with your callsign — 'my' is not one (e.g. ki2d-my-clock)
manifest.json: missing 'api' — declare the extension API this was built against (currently 1)
```

`--force-name` waives the naming convention below. It exists for Ham2K's own
packaging, which builds the extensions that ship inside the app under bare keys
and the reserved prefix; it does not waive what the runtime needs of a key.

`extensions/tools/h2kext.mjs` holds the format and its rules, and
`h2kext-build.mjs` the build preset. Both are free of any dependency on the
rest of this repo, and ship together as **`@ham2k/extension-tools`** — the
toolchain half, separate from the **`@ham2k/extension-sdk`** an extension
imports and bundles.

Two things about the SDK package are load-bearing rather than incidental, and
`extensions/sdk/build.mjs` asserts both:

- It ships as **one file per module**, not one bundle. Rolled into a single
  file, your bundler can no longer tell which parts your extension reaches, and
  Hello World comes out five times larger carrying an ADIF importer it cannot
  call.
- Its JavaScript keeps the shared libraries as **bare specifiers**. The build
  preset can only rewrite an import it can see; resolved inside the SDK, they
  would be gone before it ran, and every extension would carry private copies
  again.

`kernel.ts` lives in the SDK's source directory and is never published. It is
the host — it defines the runtime and holds the one instance of every shared
library that extensions look up. This repo's own
build uses the same plugin, which is what keeps the path you take from being
the untested one.

## Keys

An extension key is **`<yourcallsign>-<name>`**:

```
ki2d-my-clock        w7abc-notes        2e0abc-contest-helper
```

Lowercase, letters digits and hyphens. The callsign is a namespace every author
of this software already holds — globally unique, free, and already meaningful
to everyone here — so two people who never met cannot ship the same key. The
packer refuses anything else.

`ham2k-` is reserved for Ham2K's own extensions, and refused to everyone else.
There is no signing yet, so anyone could claim it, and the key is what the app
shows when it says where a hook came from.

The extensions built into the app use bare keys (`pota`, `sota`, …). Those are
reserved too: hook identity has to stay unambiguous, and build-secret
visibility is by key prefix, so an installed extension calling itself `sota`
would be asking to read `SOTA_*`. The app refuses any collision at install —
the packer cannot, because a standalone tool has no way to know what the app it
will be installed into contains.

## What an installed extension does not get

**Build secrets.** `host.secret()` returns null for an installed extension
whatever key it claims, exactly as it does for a dev-served one: visibility
follows where the code came from, not what it calls itself. A feature that
needs one degrades the same way it does in a build without that value
configured.

The sandbox is otherwise the same one the built-in extensions run in — no
filesystem, no network beyond the `domains` the manifest declares and the user
approved, no timers.

## Installing one

**Settings → Extensions → Install from file…**, pick the `.h2kext`, and agree
to what it asks for. The runtime restarts with it loaded, and the extension
appears in its own category alongside the app's own, marked *Installed* and
with a way to remove it again.

What the operator is shown before anything is written is the whole point of
the format being a zip: the file is opened and read, and only then unpacked.

Installing a bundle whose key is already installed **updates it in place**.
What it stored survives — an update is not a reinstall, and re-entering
credentials every time is how people learn not to update.

**Every install asks, including an update that wants nothing new.** Comparing
capabilities and staying quiet when they had not grown would let a version
through on the strength of its key alone, and nothing about the *code* behind
that key is compared — a bundle can change completely and still ask for the
same things. That may be worth revisiting once a bundle can be shown to come
from whoever it claims; it is not worth it while a key is all there is.

Removing an extension removes what it stored with it.

### Installing from a link

A web page can hand the app a bundle to install:

```
com.ham2k.logger:///install_extension?url=https://example.org/my-ext.h2kext
```

Every edition of Ham2K Logger answers that scheme, so on a device with more
than one installed the platform decides which one opens; the catalog keeps a
plain download link beside its install button for that reason. The
edition-specific `com.ham2k.logger.dev` / `.next` / `.prod` schemes exist
but a link should not need them. The URL must be `https`, redirects are followed by hand and refused the
moment one leaves `https`, and the consent screen names the host the bytes
came from. Nothing is written until the operator agrees.

### Installing from the catalog

**Settings → Extensions → Catalog** lists what [catalog.ham2k.net](https://catalog.ham2k.net)
publishes for this edition's channel, in the catalog's own order for the
operator's callsign (`geo`, above). Install and Update go through the same consent screen as a
file, over bytes that must hash to the sha256 the listing gives — a mismatch
is refused before the zip is opened. A bundle that arrived this way is
recorded as such (`extensionInstalledFrom`: host, sha256, version), and that
record is what lets it carry a `ham2k-` key: the rule that refuses the prefix
to a file stands, waived on every read only for a key whose record names
`catalog.ham2k.net`, and cleared by an uninstall or by a file install of the
same key. A key the app ships stays refused whatever the catalog says. The
catalog's own bundle links (`…/api/v1/extensions/<key>/versions/<version>/bundle`)
take this verified path when they arrive as a deep link; every other host
takes the plain one above.

At most once every six hours — on launch and on resume — the app asks the
catalog whether anything installed has a newer release, and says so in the
status bar and on the row; the notice comes down with the last update taken.
It never installs unasked. A release the catalog has revoked is put on record
(`extensionRevoked`: version and note) and stops loading on the spot,
whatever the operator's own switch says — the row shows "Revoked" with the
note and no switch, and the record dies with an install of another version
or an uninstall.

## What is checked at install

Beyond what the packer already refused:

- the key is not one the app ships, and does not begin `ham2k-`;
- the `api` version is one this build speaks;
- every `sharedDependencies` range is satisfied by what this build carries;
- `geo`, if present, passes the packer's rules — the shape the matcher reads
  and its vocabulary — applied again by `ExtensionGeo.validate`;
- entry names are sanitised on extract, so `../` in one writes nothing.

Each has its own message. A bundle that cannot be installed says why.

## Native only, for now

Installed bundles are files on disk. On web the app runs from its own assets
and, for authors, the dev server — [development.md](development.md).
