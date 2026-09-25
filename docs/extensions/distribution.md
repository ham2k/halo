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
  "api": 2,
  "domains": ["notes.example.org"],
  "icon": "note-text"
}
```

`api` is the extension API the bundle was built against. The host refuses one
it does not speak, so an older app meeting a newer bundle says so instead of
failing somewhere deep in a hook — and the catalog does not list it for that
app at all. Declare the lowest version that has what the bundle uses, so it
reaches every app that can run it: 2 adds `host.webSocket`, and the packer
refuses a manifest declaring `webSockets` under anything less.

Three fields are **refused** in a distributed bundle, and it is worth
understanding why:

- **No `category`** makes an extension *core* to the host: always enabled, and
  never listed in the Extensions panel. That is a status the app grants its own
  extensions. A distributed bundle claiming it would be one the user could
  neither see nor turn off.
- **`experiments`** gates availability against the *app's* experiment catalog.
  A key the host doesn't define hides the extension permanently, with nothing
  in the UI to explain it.
- **`enabledByDefault`** is a shipping app's answer for the extensions it
  carries whether the operator asked for them or not. An installed bundle is
  one the operator went and got, so the answer is always yes, and a manifest
  saying otherwise describes a state it cannot reach.

**`geo` is now `relevance`**, and a manifest still carrying the old name is
refused at packing and at publishing rather than ignored. Nothing reads
`geo`, and no check anywhere looks at unknown top-level keys, so accepting it
would publish a regional extension as a worldwide one and tell its author
nothing. Rename the key; the four geographic lists inside it are unchanged.

The app itself does NOT refuse either of these at install. The packer and the
catalog answer to the author, who can fix the manifest and publish again;
refusing at the door tells the operator instead, who can do nothing about a
published manifest but go without an extension that would have worked — and
every bundle published before these rules existed carries one. Neither costs
them anything: an installed extension is enabled because they installed it,
and an unread `geo` makes it worldwide rather than regional. What the app
refuses is what it cannot run.

### Relevance

`relevance` says where, when and for whom the extension matters. The catalog
ranks its listing by it, for the operators the extension was written for, and
the Extensions panel's Catalog section shows the catalog's rows in that
order; nothing hides an extension over it, and a manifest without one is
worldwide and undated. The build index carries `relevance` for the catalog
and for later use; the panel does not rank the app's own extensions by it.

```json
"relevance": {
  "countries": ["us"],
  "dates": ["2026-09-19", "2027-09-18"],
  "interests": ["cw"]
}
```

**Where.** Four lists, each an allowlist over the operator's own callsign:
`entities` (DXCC prefixes as the country file names them: `K`, `VE`, `CE`),
`countries` (ISO alpha-2: `us`, `cl`), `continents` (`AF AS EU NA OC SA AN`)
and `ituRegions` (`1`, `2`, `3`). A missing or empty list does not gate;
values within a list are ORed, the lists ANDed; case is the matcher's job.
These are the geo keys of HaLo's notices, rule for rule.

**When.** `dates` lists the UTC days the extension's events start, as
`YYYY-MM-DD`. Start days, not spans: a reader asking "is this soon" needs no
more, and the extension's own code stays the only place that knows when an
event opens and closes to the minute. An event on a fixed calendar lists the
occurrences it knows about; one that runs to a weekly rule lists none,
because a list that must be right every week is a list that goes stale. An
absent or empty `dates` says nothing about timing — never "never".

**For whom.** `interests` draws on a closed vocabulary: the modes `cw`,
`phone`, `digital`; the band groups `hf`, `vhf`, `uhf`, `microwave`; the
styles `satellite`, `portable`, `qrp`. Only for an extension *dedicated* to
one — a contest that permits CW is not a `cw` extension, while the CWops CWT
is. Listing what an extension merely allows makes every interest match
everything, which is the same as listing none. The list is closed because an
interest nothing else spells the same way matches nobody while looking like
it works.

The packer refuses:

- a `relevance` that is not an object, or a key inside it other than those six;
- a list that is not a list, or an element that is not a non-empty string;
- a continent outside `AF AS EU NA OC SA AN`, or an ITU region outside `1`–`3`;
- a country that is not two letters, or an entity prefix that is not letters,
  digits and `/` (with an optional leading `*`);
- a date that is not `YYYY-MM-DD`, or that names a day which does not exist;
- an interest outside the vocabulary above.

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

**Declare the version you actually build against, not the oldest that
compiles.** That check compares versions, and cannot see which *functions* a
version has. A library that gained an export — `qsonToCabrillo` arrived in
`@ham2k/lib-qson-cabrillo` 1.2.0, whose earlier releases only read Cabrillo —
satisfies a `^1.0.0` declaration on a host too old to have it, so the bundle
installs, loads, and throws the first time an operator asks for the feature
that needs it. The build's own message suggests the version installed beside
you for exactly this reason; take it rather than rounding down.

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
import { build } from "esbuild"
import { buildExtension } from "@ham2k/extension-tools"

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
await buildExtension(build, { dir: import.meta.dirname, inline: ["liquidjs"] })
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
manifest.json: missing 'api' — declare the extension API this was built against (currently 2)
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
filesystem, no network beyond the `domains` and `webSockets` the manifest
declares and the user approved, no timers.

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

**Update all is the one exception.** It takes every pending catalog update on
a single confirmation that names each extension and the version it moves to,
and skips the per-extension screen for each of them: asking once per entry for
the one thing the operator asked for once is how a screen gets pressed through
unread. It is a confirmation of a job the operator started, never a way to
start one — `install_consent_scope_test` holds it to the one function that
shows that confirmation first.

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

### Pre-loaded extensions

The app ships eight of the catalog's own extensions already packaged, under
`app/assets/preloaded-extensions/`, and installs them into the ordinary store
on first run: `ham2k-pota`, `ham2k-sota`, `ham2k-wwff`, and the five lookups.
Afterwards they are ordinary installed extensions — the same rows, the same
update check, the same Update and uninstall — so an operator starts with a
working app and the catalog can move it forward from there.

They are installed once, not every launch. A record of the highest version
ever pre-loaded per key is what makes that true: an app update carrying a
newer bundle installs it, a catalog release already ahead of it is left
alone, and a key the operator uninstalled stays gone.

Each one that renames a built-in — `ham2k-pota` is the built-in `pota` under
a name the catalog can serve — carries the operator's settings, panel values
and account credentials across on its first install. Copied, not moved: the
built-in's own state stays where it is.

One rule bends for these, and only for them:

- **Built-in collisions.** An installed bundle may not claim a key the app
  ships — judged against what the app is currently OFFERING, which under the
  catalog experiment is the core extensions and nothing else. `ham2k-lookup`
  is both a built-in and a pre-load, and could otherwise never install.

**Build secrets are not among them, and used to be.** A pre-load holding a
`ham2k-` key could once read the values its name granted. Nothing needs that
now: every value it carried — SOTA's OAuth client id, WWFF's API key — ships
as a constant inside the extension that uses it, because these bundles are
served to anyone who asks and a `.h2kext` is a zip. An installed extension
sees no build secret, whatever key it claims and wherever it came from.

### The upgrade to catalog extensions

An install that has been running the app's own extensions is offered the move
at start, and again the moment the catalog experiment is switched on: that
switch is the operator asking for catalog extensions, and being made to
relaunch before anything is offered reads as nothing having happened. The
switch withdraws nothing by itself; only a taken upgrade does, and the offer
may be deferred either way. A catalog that cannot be reached says so in the
footer when the operator asked, and says nothing at a launch nobody was
watching.

Accepting installs the pre-loads, then fetches the catalog's twin of every
other built-in the operator had switched on — `wca` becomes `ham2k-wca` —
carrying its settings and credentials the same way. Nothing is withdrawn until
that finishes; a download that fails puts the app's own extensions back in use
and the offer returns next launch. Twins that did arrive stay on disk, unused
until an upgrade completes — the built-in each one supersedes is what runs
meanwhile.

A bundle the engine will not evaluate takes the whole runtime with it, so the
upgrade puts that one aside — the boot names the bundle it died on — and
restarts once more. What boots then is the upgrade minus that extension, named
in the dialog in a sentence of its own. Refused rather than
withdrawn: the panel still lists it, badged, because the row is where an
operator sees that something they installed is doing nothing, and updating it
there is what lifts the refusal. Keyed by the VERSION that failed, so a fixed
release arrives as an ordinary update and clears it. Only an INSTALLED
extension is ever put aside; a built-in that
will not evaluate is a defect in the app, and skipping it would ship an
install quietly missing part of itself.

A refusal is kept even when putting the bundle aside did not get a runtime
back: it still will not evaluate, and an extension with no built-in behind it
is in the reverted set too, so re-admitting it there would kill the boot that
was about to give the operator everything back. Every dialog, and the notice
that stands in for one, names what stayed out — except a downloaded copy the
revert superseded, whose built-in is running again. Uninstalling clears the
record, so a reinstall of the same bytes gets its chance.

A refused extension is treated like a revoked one in everything else: it
keeps its switch, and its downloaded data expires on the same clock as any
extension the app is not loading.

What this does NOT cover is a failure that names no bundle. Only a bundle
that fails while it is being EVALUATED names itself: a kernel that will not
load, or an extension that throws while ACTIVATING, takes the generation down
under a name that is not a key. Those revert the whole upgrade as before, and
it is offered again at the next launch.

The upgrade restarts the extension runtime, which takes the footer items of
the generation going down with it: a data file's import raises an error rather
than returning into a torn-down runtime, so its progress line is cleared and
the file is left unstamped for the next sweep instead of recorded as fresh
with nothing imported.

A few built-ins have no twin on purpose — `qp`, which the catalog carries as
one extension per party instead — and the app names them itself
(`kBuiltInsWithoutTwin`). Those are withdrawn without asking the catalog, and
the dialog that reports the upgrade finished names each one the operator had
switched on, since it is where they learn it is gone. Any other twin missing
from the listing fails the upgrade and is asked for again next launch: a
listing lacks a key the same way whether the catalog will never serve it or has
not published it yet, and only the app knows which. A built-in retired from the
catalog on purpose joins that list in the same change.

### Installing from the catalog

**Settings → Extensions → Catalog** lists what [catalog.ham2k.net](https://catalog.ham2k.net)
publishes on its `stable` channel, in the catalog's own order for the
operator's callsign (`relevance`, above). Install and Update go through the same consent screen as a
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
It never installs unasked: the notice's **Update all** is the panel's own,
behind the same confirmation, and **More info** opens the panel.

An install or update narrates itself as one status-bar progress item, from the
first downloaded byte to "Installed", and the Extensions panel mirrors that
item on the row being installed. Installs share one queue
(`ExtensionInstaller`): downloads run side by side, while the writes go one at
a time, since each restarts the runtime. A release the catalog has revoked is put on record
(`extensionRevoked`: version and note) and stops loading on the spot,
whatever the operator's own switch says — the row shows "Revoked" with the
note and no switch, and the record dies with an install of another version
or an uninstall.

## What is checked at install

Beyond what the packer already refused:

- the key is not one the app ships, and does not begin `ham2k-`;
- the `api` version is one this build speaks;
- every `sharedDependencies` range is satisfied by what this build carries;
- `relevance`, if present, passes the packer's rules — the shape the matcher
  reads and its vocabulary — applied again by `ExtensionRelevance.validate`;
- entry names are sanitised on extract, so `../` in one writes nothing.

Each has its own message. A bundle that cannot be installed says why.

## Native only, for now

Installed bundles are files on disk. On web the app runs from its own assets
and, for authors, the dev server — [development.md](development.md). So on
web there is nothing to install into: no install from a file, no install or
update from the catalog, and none of the pre-loaded extensions above.

"For now" is a deferral, not a fact about the platform. Almost everything
here is already platform-neutral — the zip walk, the manifest rules, the
consent screen, the hash check — and what is left is a persistence seam of
about six operations. `HALO-583` is the card that picks it up, and says what
has to be decided first.
