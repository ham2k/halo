# The manifest

`manifest.json` is everything knowable about an extension without running
its code. The packer validates it, the catalog reviews and ranks by it, the
app shows it to the operator before installing and reads it to decide what
the extension may do. Your `src/index.ts` spreads it into `defineExtension`
so the running definition and the file never disagree.

A manifest that uses most of what there is:

```json
{
  "key": "w7abc-lakes",
  "name": "Lakes on the Air",
  "shortName": "LLOTA",
  "version": "1.2.0",
  "description": "Activate and hunt lakes worldwide; spots on llota.app",
  "category": "activity",
  "api": 13,
  "icon": "waves",
  "accentColor": "#2F7FA6",
  "keywords": ["lakes", "activation", "hunting"],
  "hooks": ["activity", "adifFields", "adifImport", "dataFile", "export", "lookup", "ref:w7abcLake", "ref:w7abcLakeActivation", "settingsPanel", "spots"],
  "domains": ["api.llota.app", "llota.app"],
  "relevance": { "continents": ["SA"], "interests": ["portable"] },
  "settings": { "section": "activities" },
  "translations": { "es": { "description": "Activa y caza lagos en todo el mundo" } },
  "sharedDependencies": {
    "@ham2k/lib-callsigns": "^1.0.2",
    "@ham2k/lib-country-files": "^1.0.202605301",
    "@ham2k/lib-dxcc-data": "^1.0.1",
    "@ham2k/lib-format-tools": "^1.1.3",
    "@ham2k/lib-geo-tools": "^1.1.1",
    "@ham2k/lib-operation-data": "^1.1.3",
    "i18next": "^23.16.8",
    "liquidjs": "^10.28.0"
  }
}
```

## Identity

| Field | | |
| --- | --- | --- |
| `key` | required | `<yourcallsign>-<name>`: lowercase letters, digits and hyphens, the callsign first. The namespace for everything the extension stores and the name the app shows when it says where something came from. `ham2k-` is reserved, and so are the bare keys of the app's own core extensions. |
| `name` | required | What the Extensions panel and the catalog show. |
| `shortName` | | The name where there is little room: a control's label, a locked switch naming the rules it follows. |
| `version` | required | Semantic version. The catalog freezes a version's bytes the first time a reviewer approves it, so a fix is a new version. |
| `description` | required | One sentence for the panel and the catalog. |
| `translations` | | `{ "<locale>": { "name"?, "description"?, "keywords"? } }`. A localized `keywords` adds to the base list; both are searched. |

Why a callsign: it is a globally unique namespace every author of this
software already holds, so two people who never met cannot ship the same
key, and nobody has to run a registry.

## Listing

| Field | |
| --- | --- |
| `category` | Where the Extensions panel groups it: `activity`, `award`, `contest`, `lookup`, `spots` or `dashboard`, in that display order. A value outside the list lands under *Other*. Required in a distributed bundle: without one an extension is treated as part of the app's core, always on and never listed, which is a status only the app's own extensions have. |
| `icon` | A [Material Design Icons](https://pictogrammers.com/library/mdi/) name (`pine-tree`), or a FontAwesome solid name prefixed `fa-` (`fa-tree`). An unknown name draws a placeholder. |
| `accentColor` | `#RRGGBB`, the program's own colour; the app tints the extension's icon and its references' chips with it. |
| `keywords` | Extra search terms for the panel and the catalog, beyond name and description. |
| `relevance` | Where, when and for whom the extension matters; below. |

### Relevance

`relevance` ranks; it never hides. The catalog orders its listing by it for
the operator's own callsign, and the Extensions panel's catalog section
shows that order. A manifest without one is worldwide and undated.

```json
"relevance": {
  "countries": ["us"],
  "dates": ["2026-09-19", "2027-09-18"],
  "interests": ["cw"]
}
```

**Where.** Four lists, each an allowlist matched against the operator's own
callsign: `entities` (DXCC prefixes as the country file names them: `K`,
`VE`, `CE`), `countries` (ISO alpha-2: `us`, `cl`), `continents`
(`AF AS EU NA OC SA AN`) and `ituRegions` (`1`, `2`, `3`). A missing or
empty list does not gate. Values within a list are ORed; the lists are
ANDed. Case is the matcher's concern, not yours.

**When.** `dates` lists the UTC days the extension's events start, as
`YYYY-MM-DD`. Start days, not spans. An event on a fixed calendar lists the
occurrences it knows about; one that runs to a weekly rule lists none, since
a list that must be right every week is a list that goes stale. An absent or
empty `dates` says nothing about timing.

**For whom.** `interests` draws on a closed vocabulary: the modes `cw`,
`phone`, `digital`; the band groups `hf`, `vhf`, `uhf`, `microwave`; the
styles `satellite`, `portable`, `qrp`. List one only for an extension
dedicated to it. A contest that permits CW is not a `cw` extension; a
CW-only sprint is. Listing what an extension merely allows makes every
interest match everything.

The packer refuses a `relevance` that is not an object, a key other than
those six, a list that is not a list, an element that is not a non-empty
string, a continent or region outside its set, a country that is not two
letters, an entity prefix that is not letters, digits and `/` (with an
optional leading `*`), a date that is not `YYYY-MM-DD` or names a day that
does not exist, and an interest outside the vocabulary. The matcher reads a
key it cannot parse as "does not gate", so each of these would otherwise
ship a regional extension as a worldwide one.

## Hooks and claims

| Field | |
| --- | --- |
| `hooks` | Every category the extension registers, `ref:<type>` entries included. The app reads this list without evaluating the bundle. |
| `adifFieldsScope` | `"always"`: the full ADIF export asks this extension's `adifFields` about every contact, not only the ones carrying a reference it handles. |

Three entries in `hooks` do more than describe:

- **`settingsPanel`** must be listed by an extension that registers one. The
  catalog decides what to review by it, and the app does not show a panel
  its manifest leaves out.
- **`ref:<type>`** says this extension publishes a control for references of
  that type. An operation carrying a reference of a type no running
  extension handles offers to switch on, or install from the catalog, the
  extension that declares it. List only the types you publish a control
  for; a `ref:` entry for a type you merely decorate or score would offer a
  switch that cannot clear the row.
- **`ref:<type>/<prefix>`**, a *qualified claim*, says this extension answers
  for references of a type it does not publish: the ones whose code starts
  with `<prefix>`. It exists for a type that once held many events in one
  extension and became one extension per event, so a log written before the
  split still finds its program. Nothing is rewritten; the extension reaches
  back for the reference instead. The code is matched as a lower-cased
  prefix and the longest match wins, so `ref:qp` claims a whole family at
  length zero, `ref:qp/ne` and `ref:qp/neqp` both match `NEQP` and the longer
  decides. A claim must be shaped `<type>/<prefix>` with both halves present,
  and must be backed by a control declaring the same claim in its
  `alsoHandles`; a control that answers for a claim the manifest does not
  make is never offered for it, so nothing ever reaches it.
  [Activities](activities.md#claiming-another-types-references) has the
  control side.

`adifFieldsScope` lives in the manifest rather than on the hook so the
packer can check it without running the bundle: a manifest listing
`adifFields` with neither a `ref:` type nor the opt-in is refused.
[Import & export](import-export.md#adiffields) says who is asked when.

## Network

| Field | |
| --- | --- |
| `domains` | The hosts `host.fetch` may call: exact names (`api.pota.app`), a wildcard (`*.example.com`), or `*`. |
| `webSockets` | The hosts `host.webSocket` may connect to. Same shapes, plus `"local"`. A host listed only under `domains` gets no socket: consenting to requests is not consenting to a standing connection. |
| `allowUserAgentOverride` | Lets your `host.fetch` headers set `User-Agent`. Otherwise the app stamps its own canonical one on every request and ignores yours. |

The rules the host enforces:

- `host.fetch` is **https**. A plain `http://` URL is refused unless its host
  serves http only and Ham2K's services proxy fronts it, in which case the
  request goes out over https through the proxy; `domains` still names the
  original host, and the bundle declares `api` 4 or later.
- **A wildcard never reaches the local network**: loopback, the private
  ranges, link-local, IPv6 unique-local, `localhost` and `.local` names.
  Gear in the shack is reachable only by naming its host under `domains`, or
  while the app is in developer mode. Natively the host also resolves each
  name and refuses one that answers with a local address.
- **Sockets:** `wss://` to any listed host; plain `ws://` only to a
  local-network address, since gear in the shack rarely has a certificate
  and anything past the router has no such excuse. `"local"` admits every
  local-network address over either scheme, for gear whose address only the
  operator knows, so you need not declare `*`. A name counts by its
  spelling, not by what it resolves to. `webSockets` needs `api` 2 or later,
  and the packer enforces it.
- An undeclared host is refused **at the call**, not at build time.

The install screen names every entry, so declare the hosts you use and no
more.

## Capabilities

Each of these is off unless declared, shown to the operator at install, and
refused at the call where it is missing. Declare the least you need.

| Field | Allows | Implies | API |
| --- | --- | --- | --- |
| `requiresLocation` | `host.getLocation()`, the device's own position | | |
| `requiresRadioRead` | `host.listRadios()`, `host.readRadio()`, a scene's `spectrum` control and `radio` values, a panel's `radio` trigger | | |
| `requiresRadioWrite` | `host.setRadio()`, `host.setRadioConnection()`, `host.setRadioSpectrum()`, and transmitting: `host.sendRadioCw()`, `host.playRadioVoice()`, `host.setRadioPtt()`, `host.stopRadioTransmit()`; `host.suggestQso()` (API 12) | read | 7 |
| `requiresRadioRaw` | `host.sendRadioRaw()`: any command in the radio's own protocol, unchecked; the install screen says so in those words | write | 11 |
| `requiresClusterRead` | `host.clusterStatus()`, `host.clusterLines()`, `host.clusterSubscribe()` and the `cluster` hook's `onLines` | | 10 |
| `requiresClusterSpot` | `host.clusterPostSpot()`: spots in the operator's name | cluster read | 10 |
| `requiresClusterCommand` | `host.clusterSend()`: any command in the operator's name | cluster spot | 10 |
| `requiresSettingsWrite` | A `command` hook's `updateSetting`, `updateSettings`, `toggleExperiment`, `setEnterSends`, `setKeyerSpeed` and `showKeyer` actions | | |

A capability belongs to the bundle that declared it and to the
sub-extensions that bundle defines under its own key. A separately installed
bundle never inherits one through its name.

## Settings placement

An extension that registers a `settingsPanel` says where it goes:

```json
"settings": { "section": "activities" }
```

| Key | |
| --- | --- |
| `section` | One of the app's settings sections. Prefer one that says what the extension is: `activities`, `hunting`, `contests`, `lookups`, `spotting`, `dashboard`. Four more suit an extension that tunes something the app already has a section for: `logging`, `radio`, `map`, `exports`. |
| `sidebar` | `true` asks for an entry in the Settings sidebar, for a panel that is a category of its own. Reviewed. |
| `common` | `true` lets the panel's fields flagged `common` appear in Common Preferences. Reviewed. |

The packer refuses a `settings` that is not an object, a key other than those
three, a `section` that is not a section key, and a `sidebar` or `common`
that is not a boolean. It does not refuse a placement beyond the usual, but
prints `held for review on the catalog` for each: no section for a
`settingsPanel`, a section outside the list, `sidebar` or `common`. The
catalog holds such an upload for an admin even from a trusted publisher.
[Settings panels](settings.md#where-an-extensions-settings-go) has the
whole rule, and what the app enforces against the manifest.

## Compatibility

| Field | |
| --- | --- |
| `api` | The extension API the bundle is built against: the **lowest** level that has everything it uses. An app that speaks an older level refuses the bundle at install and says so; the catalog offers each app the newest release it can run. [Packaging](packaging.md#api-levels) lists what each level added. |
| `sharedDependencies` | The libraries the app carries that your bundle reaches, with the version range you built against. |

The app carries `@ham2k/lib-callsigns`, `@ham2k/lib-country-files`,
`@ham2k/lib-cqmag-data`, `@ham2k/lib-dxcc-data`, `@ham2k/lib-format-tools`,
`@ham2k/lib-geo-tools`, `@ham2k/lib-operation-data`, `@ham2k/lib-qson-adif`,
`@ham2k/lib-qson-cabrillo`, `@ham2k/lib-qson-tools`, `i18next` and
`liquidjs`, and hands every extension the same instances. Naming one here
makes your build rewrite its imports into lookups on the app's copy, which
is worth roughly thirty times the bundle size. The app checks the ranges
before loading and refuses a bundle it cannot satisfy, naming the library
and both versions.

**Declare the version you built against, not the oldest that compiles.** The
check compares versions and cannot see which functions a version has. A
library that gained an export satisfies a `^1.0.0` declaration on a host too
old to have it, and the bundle installs, loads, and throws the first time an
operator reaches the feature. The build's own message suggests the version
installed beside you; take it.

The scaffold declares the eight libraries the SDK's own modules reach, with
open-ended ranges to replace. Importing anything from the SDK pulls them in,
so deleting one from the manifest breaks a build that was working. The
packer refuses a bundle that reaches for a shared library without declaring
it, and one that declares a package the app does not carry. Which versions a
particular build of the app carries is in its `assets/extensions/index.json`,
under `sharedModules`.

## Fields only the app's own extensions use

Three fields are meaningful for the extensions built into the app and
**refused in a distributed bundle**:

- **No `category`** makes an extension core: always on, never listed. An
  installed bundle claiming it would be one the operator could neither see
  nor turn off.
- **`experiments`** gates availability against the app's own experiment
  catalog. A key the app does not define hides the extension permanently,
  with nothing in the UI to explain why.
- **`enabledByDefault`** is a shipping app's answer for extensions it carries
  whether the operator asked or not. An installed bundle is one the operator
  went and got, so the answer is always yes.

`geo` was the earlier name of `relevance`, and a manifest still carrying it
is refused at packing and at publishing rather than ignored: nothing reads
it, so accepting it would publish a regional extension as a worldwide one
and tell its author nothing.

The app itself does **not** refuse `enabledByDefault` or `geo` at install.
The packer and the catalog answer to the author, who can fix the manifest;
refusing at the door would tell the operator instead, who can do nothing
about a published manifest. Neither costs the operator anything: an
installed extension is on because they installed it, and an unread `geo`
makes it worldwide. What the app refuses is what it cannot run.

## What is checked, and where

**The packer** refuses: a missing `key`, `name`, `version` or `description`;
a key that is not `<callsign>-<name>`, uses `ham2k-`, or is not lowercase
letters, digits and hyphens; a missing `api`, one that is not an integer, or
one newer than the packer knows; `webSockets` under `api` 2, a `chasing`
hook under 9, a cluster grant or a `cluster` hook under 10,
`requiresRadioRaw` under 11; a missing `category`;
`sharedDependencies` naming a package the app does not carry or giving no
range; `experiments`, `enabledByDefault` or `geo`; `adifFields` with neither
a `ref:` type nor `adifFieldsScope`; and every malformed `relevance` or
`settings` listed above. It reports all of them at once.

**The app**, at install, checks what the packer cannot know: that the key is
not one the app ships and does not begin `ham2k-` (waived for a bundle the
catalog served under that prefix); that `api` is one this build speaks; that
every `sharedDependencies` range is satisfied by what this build carries;
that `relevance` passes the same rules again; and that no entry name in the
zip escapes its directory. Each has its own message.

**The catalog** re-validates everything the packer does, and holds for
review the settings placements above.
