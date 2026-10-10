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
refuses a manifest declaring `webSockets` under anything less; 3 adds timers
and `onShow`/`onHide`, and from 3 the build rewrites a bare `setTimeout` into
the SDK's (README's "Timers"); 4 lets `host.fetch` reach a plain-`http://` host
the app fronts with its https proxy (README's `host.fetch`); 5 adds panel
scenes' `scene` kind, native controls, `strings`, `layout`, `after` and control
`opacity` (hooks.md's `panel`); 6 adds the scene's `spectrum` control and
`host.setRadioSpectrum`; 7 adds `host.setRadio`, the keying calls
(`sendRadioCw`, `playRadioVoice`, `setRadioPtt`, `stopRadioTransmit`), what
`readRadio` adds with them, and the scene's host-fed `radio` values, scale
bindings, text glow, two-axis and menu knobs and the spectrum's `follow`,
`span` and label `decimals`.

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
manifest.json: missing 'api' — declare the extension API this was built against (currently 7)
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

The core extensions built into the app use bare keys (`adif`, `scoring`, …).
Those are reserved too: hook identity has to stay unambiguous. The app refuses
any collision at install — the packer cannot, because a standalone tool has no
way to know what the app it will be installed into contains.

## What an installed extension does not get

**Build secrets.** `host.secret()` returns null for an installed extension
whatever key it claims, exactly as it does for a dev-served one: visibility
follows where the code came from, not what it calls itself. A feature that
needs one degrades the same way it does in a build without that value
configured.

The sandbox is otherwise the same one the core extensions run in — no
filesystem, no network beyond the `domains` and `webSockets` the manifest
declares and the user approved, and timers only within their budget
(README's "Timers").

## Installing one

**Settings → Extensions & Features → Install from file…**, pick the `.h2kext`, and agree
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
unread. Pressed on the update notice when the notice's text already named every
extension it takes, it skips that confirmation too: the press under those names
was it. It is a confirmation of a job the operator started, never a way to
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

The app builds in only its **core** extensions — the ones that are the app
itself: `adif`, `scoring`, `lookups`, `templates`, the command sets and
`ham2k-lofi` sync. Every other extension is a catalog bundle, and the app ships
some of them already packaged under `app/assets/preloaded-extensions/`,
installing them into the ordinary store on first run. Afterwards they are
ordinary installed extensions — the same rows, the same update check, the same
Update and uninstall — so an operator starts with a working app and the catalog
can move it forward from there.

Which ones ship is staged. Today it is the catalog twin of every extension the
app used to build in (see [Retired built-ins](#retired-built-ins)), so that an
install moving off them has every one to hand with no network. Once installs
still on a build with the built-ins are few enough, it shrinks to the eight a
new install needs — `ham2k-pota`, `ham2k-sota`, `ham2k-wwff` and the five
lookups — and the rest are fetched from the catalog when switched on
([HALO-743](https://cabo.ham2k.com/halo/c/743)). The app's own tests rely on
only those eight, the core, and the never-shipped samples, so the shrink
touches none of them.

**They have to be kept current.** A pre-load is frozen into the binary, so
every release must carry the catalog's current stable release of each one: an
older one starts every new install behind the catalog until its first update
check. `node scripts/preloaded-extensions.mjs check` compares them with what
the catalog serves, byte for byte and at the app's extension API level;
`node scripts/preloaded-extensions.mjs update` replaces any that are behind
(`update <key>` adds one). Publishing a new release of a pre-loaded extension
is therefore also a change to this repository, and the release cut refuses to
ship pre-loads that fail the check ([releases.md §6.4](../releases.md)).

They are installed once, not every launch. A record of the highest version
ever pre-loaded per key is what makes that true: an app update carrying a
newer bundle installs it, a catalog release already ahead of it is left
alone, and a key the operator uninstalled stays gone.

An installed bundle may not claim a key the app builds in, and a pre-load is
no exception: it goes through the same door as any other install.

**Build secrets are not among what they get.** Every value a twin once needed —
SOTA's OAuth client id, WWFF's API key — ships as a constant inside the
extension that uses it, because these bundles are served to anyone who asks and
a `.h2kext` is a zip. An installed extension sees no build secret, whatever key
it claims and wherever it came from.

### Retired built-ins

The app used to build in forty-one more extensions — the activities, contests,
lookups, a spot source and a dashboard panel. Their catalog copies are the same
extensions under the reserved prefix (`pota` became `ham2k-pota`; `ham2k-lookup`
kept its name), because the catalog cannot serve a bare key. Everything the app
stores per extension hangs off the name — its settings group, its panel values,
its account credentials, the operator's on/off choice — so each twin inherits
from its built-in. The app keeps a table of the retired keys and whether each
was on by default (`kRetiredBuiltIns`), since an install may skip any number of
releases between the last one with its built-ins and this one; it never shrinks.

**The move.** An install that ran the built-ins — one whose default profile had
a callsign before its extension state was first recorded
(`seedExtensionsMigratedDefault`) — moves onto their twins at its first boot on
a build without them, unasked: there is nothing left to run instead. The boot's
catch-up (`catchUpOnCatalogExtensions`) carries each built-in's on/off choice
onto its twin, over whatever an earlier attempt left there; installs the
pre-loads, which carry the built-in's settings, panel values and credentials on
a twin's first install, and its default where the operator never chose; then
fetches the twin of any other built-in the operator had switched on. It records
the move done once the pre-load has run, so a boot killed half way carries the
choices again next time. It needs no network while every twin is pre-loaded.
The boot starts the extension runtime before settings are wired in, so a
catch-up that finds none does not count, and wiring them runs it.
Choices keep being carried after the move, too: onboarding and the
`ONBOARD_AS` define name activities by their built-in keys, and
`offeredKeyFor` writes each choice under both names, so a twin that arrives
later still inherits it.

Once moved, the operator sees one notice — not a dialog, since the move was not
theirs to decide — saying their extensions now come from the catalog, naming
anything that did not come along, and counting the twins still to arrive from a
catalog that could not be reached. Any catch-up, the move or not, raises the
same notice when an extension was put aside or the runtime would not start at
all, and says so in place of "ready".

A pre-load is recorded as offered only once it installed, or when the store
refuses the bundle itself: a keychain that would not open or a full disk is
tried again next launch, and meanwhile the adoption fetches the catalog's copy
if the operator had it on. A twin the pre-load did install is never fetched
back after the operator uninstalls it. A choice stored under the pre-load's own
name — `ham2k-lookup`'s, which kept its name — is kept rather than dropped as
stale.

**What does not come along.** A few built-ins have no twin on purpose — `qp`,
which the catalog carries as one extension per party instead, and `stateparks`,
one per event — and the app names them itself (`kBuiltInsWithoutTwin`). The
notice names each one the operator had switched on, since it is where they learn
it is gone. Any other twin missing from the listing is asked for again next
launch: a listing lacks a key the same way whether the catalog will never serve
it or has not published it yet, and only the app knows which. A built-in
retired from the catalog on purpose joins that list in the same change.

**A twin that will not run.** A bundle the engine will not evaluate takes the
whole runtime with it, so the catch-up puts that one aside — the boot names the
bundle it died on — and restarts once more, the notice naming it in a sentence
of its own. Refused rather than withdrawn: the panel still lists it, badged,
because the row is where an operator sees that something they installed is
doing nothing, and updating it there is what lifts the refusal. Keyed by the
VERSION that failed, so a fixed release arrives as an ordinary update and
clears it. Only an INSTALLED extension is ever put aside; a core one that will
not evaluate is a defect in the app, and skipping it would ship an install
quietly missing part of itself. A refused extension is treated like a revoked
one in everything else: it keeps its switch, and its downloaded data expires on
the same clock as any extension the app is not loading. A failure that names no
bundle — a kernel that will not load, an extension that throws while
ACTIVATING — puts nothing aside, and is reported.

A twin fills the same lookup categories its built-in did, under data-file keys
of its own. Each retired built-in is stamped disabled, so a week on the
stale-data purge clears the data files it left — leaving alone the rows a live
extension's data file still fills.

### Installing from the catalog

**Settings → Extensions & Features** lists what [catalog.ham2k.net](https://catalog.ham2k.net)
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

### Release tracks

A catalog channel — `stable`, `unstable` or `bleeding` — says how finished a
release is, and the catalog cascades: asking for `unstable` sees unstable and
stable releases. The panel's listing asks for `stable`. Under developer mode,
**Developer → Extension Catalog → Catalog Search Tracks** (Only Stable,
Unstable or better, Bleeding or better) widens it; turning developer mode off
puts the listing back on stable without touching anything installed. Only
the panel's listing reads it: fetching the catalog twins of retired built-ins
reads stable, since those install with no consent screen, and restoring a
missing extension reads the track it followed.

The other way to an unfinished release is a link: the catalog's install
button, or an address pasted into the panel's search field — a catalog
bundle URL, an extension's page (`/extensions/<key>?channel=unstable`, which
installs that channel's current release), the `install_extension` deep link
itself, or an https URL ending in `.h2kext`; anything else is a search. A
bundle URL is resolved against the listing on `bleeding`, which sees every
release, and the version's channel is the steadiest one it is approved on. A
page link records the channel it asked for as the track even when the release
there turns out to be steadier — the operator chose that track.

Whichever way it arrives, the consent screen warns over a release that is not
stable, and the install records its channel in the provenance record as the
TRACK the extension follows (`channel`, absent meaning stable). The update
check asks about each extension on its own track — one request per track in
use, side by side — and offers only what is newer than what is installed, so an extension installed at `0.1` unstable is updated to `1.0` stable,
and then to `1.0.1` unstable. The track only widens on an install: a stable
release landing over an unstable install leaves it on unstable. A pre-load
counts as the catalog's own here. The row and the details show the track, and
the details' **Follow stable releases only** puts it back on stable; an
uninstall or a file install clears it with the rest of the record.

At most once every six hours — on launch and on resume — the app asks the
catalog whether anything installed has a newer release, and says so in the
status bar and on the row; the notice comes down with the last update taken.
It never installs unasked: the notice's **Update all** is the panel's own,
behind the same confirmation unless the notice named every extension it takes,
and **More info** opens the panel.

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

## Where installed bundles live

Everything above is platform-neutral — the zip walk, the manifest rules, the
consent screen, the hash check. What differs is only where the bytes are kept
(`BundleStorage`):

- **natively**, one directory per key under the app's data directory, one
  file per bundle entry;
- **on web**, one IndexedDB record per key (database `halo-extensions`),
  holding every entry's bytes under its own name. IndexedDB rather than the
  Origin Private File System, which would mirror the native layout: every
  browser HaLo runs in supports it the same way, while OPFS writes from the
  page are newer and patchier on Safari.

So the web build installs from a file, installs and updates from the catalog,
pre-loads the shipped bundles and moves off the retired built-ins exactly as
the native ones do.

### When the store is lost

The store can go while the preferences describing it survive: a browser
clearing IndexedDB alone, a data directory deleted by hand, a store that
failed mid-session. (When a browser clears a whole site, preferences go with
it, and the app starts as a new install.) So what the operator installed is
kept apart from the store that holds it, and put back from there.

`extensionsInstalled` records every extension the operator installed
(`{key: name}`). Every install writes it; only an uninstall — or Forget, below
— removes it. An install that predates it is seeded from its store once, and
after that it never follows the store: a store found short is exactly what it
must not shrink to. Whatever is recorded there and not in the store is
**missing**, however it went — judged by the keys the store holds, not by the
extensions the app offers, since a built-in or a dev server can stand in front
of an installed bundle. A store that cannot be read at all has lost nothing:
that launch offers nothing, rather than everything back into a failing store.
Where each came from is its provenance record's answer, and a key with none
came from a file.

The operator's on/off choice for a missing extension is kept too: the boot
cleanup that prunes settings for keys the app no longer knows treats every
recorded key as known.

Putting them back, after the app starts:

- **Shipped bundles** come back at boot from the app's own assets, unasked and
  offline. The pre-load record says they were already offered, which is true
  and beside the point; they are installed anyway, never as a first install,
  so their settings and on/off choice stand. An install that has not taken the
  upgrade gets back only what it had.
- **Everything else** is offered in a dialog once the boot has settled:
  - extensions from the catalog in use are listed to install, at the release
    it serves now. **Later** keeps every one for the next launch;
  - extensions from a file are listed to install again from their files, and
    ones from a different catalog as not available here. Neither is fetched —
    the bytes would come from a publisher the operator never agreed to;
  - every row has **Forget**, which drops it with everything it stored — the
    only way out for one the catalog no longer serves, which would otherwise
    be offered, and fail, every launch.
- **Install** installs each on its own: one that is not listed, will not
  download or fails the check costs only itself. The runtime restarts with
  everything that landed; a bundle it will not evaluate is set aside, as the
  upgrade does, and the runtime restarts without it. The result names what
  could not be installed (offered again next launch) and what installed but
  would not run (kept, marked in the panel, where an update is the way back);
  says so when the runtime would not start at all, rather than calling it a
  success; and says the app is still busy — offering them again next launch
  — when another catalog pass holds the store.
- The offer waits for the boot's catch-up to finish, or for an upgrade that
  every catch-up stepped aside for to let go.
