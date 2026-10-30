# Installed extensions: pre-loads, the catalog, tracks, pulling and the store

How the app manages the extensions it did not build in: what ships inside
the binary, how an install moves off the retired built-ins, how catalog
installs and updates are recorded and checked, how a release is pulled or
replaced, and how the store is put back when it is lost. The author-facing
half (the format, the packer, what the operator sees) is in
[docs/extensions/packaging.md](../extensions/packaging.md) and
[publishing.md](../extensions/publishing.md); this page is the app's side.

## What the app builds in, and what it pre-loads

The app builds in only its **core** extensions: `adif`, `scoring`,
`lookups`, `templates`, the command sets and `ham2k-lofi` sync. Every other
extension is a catalog bundle. Some ship already packaged under
`app/assets/preloaded-extensions/`, and the app installs the ones the
operator has switched on into the ordinary store, after which they are
ordinary installed extensions: the same rows, the same update check, the
same Update and uninstall.

Which ones ship is staged. Today it is the catalog twin of every extension
the app used to build in, so an install moving off them has every one to
hand with no network, plus `ham2k-dxcc`, on for everyone as the core `dxcc`
chasing program was. Once installs still on a build with the built-ins are
few enough, it shrinks to the nine a new install needs (`ham2k-pota`,
`ham2k-sota`, `ham2k-wwff`, `ham2k-dxcc` and the five lookups), the rest
fetched from the catalog when switched on. The app's tests rely on only
those nine, the core and the never-shipped samples.

**Pre-loads are kept current.** `node scripts/preloaded-extensions.mjs check`
compares them with what the catalog serves, byte for byte and at the app's
extension API level; `update` replaces any that are behind, `update <key>`
adds one. The release cut refuses to ship pre-loads that fail the check
([releases.md §6.4](../releases.md)).

**They are installed once, not every launch.** A record of the highest
version ever pre-loaded per key makes that true: an app update carrying a
newer bundle installs it, a catalog release already ahead of it is left
alone, and a key the operator uninstalled stays gone, because its uninstall
leaves its switch off, which the pre-load asks before installing a newer
copy.

**Only what is switched on is installed**, by the operator's choice for the
key, else its built-in's, else on. One switched off would be a dead row in
the Extensions panel, and for a new install that is most of them. Skipped,
it is not recorded as offered, so switching on one never offered brings it
in; one already offered comes back from the catalog. A shipped key's switch
is kept after it leaves the store, and an uninstall or a Forget leaves it
off, so an app update carrying a newer copy does not bring back one the
operator removed. Nothing is installed until onboarding has been answered,
since the activities it asks about are pre-loads; onboarding settles them as
it finishes (`settleOnboardingExtensions`), as `ONBOARD_AS` does, and a
replayed onboarding (DEVONBOARD) removes nothing. An install that holds
every shipped bundle takes the pre-loads and built-ins' twins it holds
switched off out of the store once (`extensionsSwitchedOffRemoved`), keeping
their settings, credentials and switch for a reinstall, and records that
done only once it has read the whole store; other catalog extensions are the
operator's own and stay, as do file installs. A catalog install the operator
makes is always switched on, whatever switch it inherits. A pre-load may not
claim a key the app builds in, and goes through the same door as any other
install.

**Build secrets are not among what they get.** Every value a twin once
needed ships as a constant inside the extension that uses it; an installed
extension sees no build secret whatever key it claims.

## The retired built-ins

The app used to build in forty-one more extensions. Their catalog copies are
the same extensions under the reserved prefix (`pota` became `ham2k-pota`;
`ham2k-lookup` kept its name), and everything the app stores per extension
hangs off the name (settings group, panel values, account credentials, the
on/off choice), so each twin inherits from its built-in. `kRetiredBuiltIns`
is the table of retired keys and whether each was on by default; it never
shrinks, since an install may skip any number of releases.

**The move.** An install that ran the built-ins, one whose default profile
had a callsign before its extension state was first recorded
(`seedExtensionsMigratedDefault`), moves onto their twins at its first boot
on a build without them, unasked. The boot's catch-up
(`catchUpOnCatalogExtensions`) carries each built-in's on/off choice onto its
twin, installs the pre-loads switched on (which carry the built-in's
settings, panel values and credentials on a twin's first install), then
fetches the twin of any other built-in the operator had switched on. It
records the move done once the pre-load has run, so a boot killed half way
carries the choices again. It needs no network while every twin is
pre-loaded. The boot starts the extension runtime before settings are wired
in, so a catch-up that finds none does not count, and wiring them runs it.
Choices keep being carried afterwards too: onboarding and `ONBOARD_AS` name
activities by their built-in keys, and `offeredKeyFor` writes each choice
under both names, so a twin that arrives later still inherits it.

Once moved, the operator sees one notice, not a dialog (the move was not
theirs to decide), saying their extensions now come from the catalog,
naming each one they had switched on that did not come along, and counting
the twins still to arrive from a catalog that could not be reached. Any
catch-up, the move or not, raises the same notice when an extension was put
aside or the runtime would not start at all, and says so in place of
"ready".

A pre-load is recorded as offered only once it installed, or when the store
refuses the bundle itself: a keychain that would not open or a full disk is
tried again next launch, and meanwhile the adoption fetches the catalog's
copy if the operator had it on. A twin the pre-load did install is never
fetched back after the operator uninstalls it. A choice stored under the
pre-load's own name (`ham2k-lookup`'s, which kept its name) decides whether
it is installed, and is kept rather than dropped as stale.

**What does not come along.** A few built-ins have no twin on purpose: `qp`,
which the catalog carries as one extension per party, and `stateparks`, one
per event (`kBuiltInsWithoutTwin`); the notice names each one the operator
had switched on. Any other twin missing from the listing is asked for again
next launch: a listing lacks a key the same way whether the catalog will
never serve it or has not published it yet, and only the app knows which. A
built-in retired from the catalog on purpose joins that list in the same
change.

**A twin that will not run.** A bundle the engine will not evaluate takes
the whole runtime with it, so the catch-up puts that one aside (the boot
names the bundle it died on) and restarts once more, the notice naming it
in a sentence of its own. Refused rather than withdrawn: the panel still
lists it, badged, because the row is where an operator sees that something
they installed is doing nothing, and updating it there is what lifts the
refusal. Keyed by the version that failed, so a fixed release arrives as an
ordinary update and clears it. Only an installed extension is ever put
aside; a core one that will not evaluate is a defect in the app, and
skipping it would ship an install quietly missing part of itself. A refused
extension is treated like a revoked one in everything else: it keeps its
switch, and its downloaded data expires on the same clock as any extension
the app is not loading. A failure that names no bundle (a kernel that will
not load, an extension that throws while activating) puts nothing aside and
is reported. A twin fills the same lookup categories its built-in did,
under data-file keys of its own; each retired built-in is stamped disabled,
so a week on the stale-data purge clears the data files it left, leaving
alone the rows a live extension's data file still fills.

## Installing from the catalog

The Extensions panel lists the catalog's `stable` channel in the catalog's
order for the operator's callsign. Install and Update go through the same
consent screen as a file, over bytes that must hash to the listing's sha256;
a mismatch is refused before the zip is opened. A bundle that arrived this
way is recorded (`extensionInstalledFrom`: host, sha256, version), and that
record is what lets it carry a `ham2k-` key: the rule refusing the prefix to
a file stands, waived on every read only for a key whose record names
`catalog.ham2k.net`, and cleared by an uninstall or a file install of the
same key. A key the app ships stays refused whatever the catalog says. The
catalog's own bundle links take this verified path when they arrive as a
deep link; every other host takes the plain one.

**Every install asks**, including an update that wants nothing new. Comparing
capabilities and staying quiet when they had not grown would let a version
through on the strength of its key alone, and nothing about the code behind
a key is compared. *Update all* is the one exception: one confirmation that
names each extension and the version it moves to, and pressed on an update
notice whose text already named every extension it takes, none at all. It
is a confirmation of a job the operator started, never a way to start one
(`install_consent_scope_test` holds it to the one function that shows that
confirmation first).

Screenshots are loaded only from the catalog's own host; a listing naming
any other is shown without them.

## Release tracks

A catalog channel says how finished a release is, and the catalog cascades.
The panel's listing asks for `stable`; under developer mode, **Developer →
Extension Catalog → Catalog Search Tracks** widens it, and turning developer
mode off puts the listing back without touching anything installed. Fetching
the twins of retired built-ins reads stable, since those install with no
consent screen.

The other way to an unfinished release is a link: the catalog's install
button, or an address pasted into the panel's search field (a catalog bundle
URL, an extension's page with `?channel=`, the `install_extension` deep link,
or an https URL ending in `.h2kext`; anything else is a search). A bundle
URL is resolved against the listing on `bleeding`, and the version's channel
is the steadiest one it is approved on; a page link records the channel it
asked for even when the release there is steadier.

Whichever way it arrives, the install records its channel in the provenance
record as the **track** the extension follows (`channel`, absent meaning
stable). The update check asks about each extension on its own track, one
request per track in use, side by side, and offers only what is newer than
what is installed, so an extension installed at `0.1` unstable is updated to
`1.0` stable, and then to `1.0.1` unstable. The track only widens on an
install: a stable release landing over an unstable install leaves it on
unstable. A pre-load counts as the catalog's own here, and restoring a
missing extension reads the track it followed. The row and the details show
the track, and the details' **Follow stable releases only** puts it back; an
uninstall or a file install clears it with the rest of the record.

At most once a day, on launch and on resume, the app asks the catalog
whether anything installed has a newer release, says so in the status bar
and on the row, and never installs unasked; the notice comes down with the
last update taken, its **Update all** is the panel's own behind the same
confirmation unless the notice named every extension it takes, and **More
info** opens the panel. An install or update narrates itself as one
status-bar progress item, from the first downloaded byte to "Installed",
mirrored on the row; installs share one queue (`ExtensionInstaller`),
downloads side by side, writes one at a time since each restarts the
runtime.

## Pulling an extension

Three ways stop an installed extension running whatever the operator's
switch says. Each leaves the row listed, with no switch and a note, and tells
the operator once.

- **A revoked version.** The catalog pulls one release, for good. The record
  (`extensionRevoked`: version and note) dies with an install of another
  version or an uninstall.
- **A disabled key.** The catalog disables every version of a key, including
  ones it never served; the update check reports every installed version as
  revoked. Unlike a revoked version it can be let go of: the app lifts a
  revocation the catalog no longer reports, but only from an answer that
  carries a `revoked` list at all.
- **The flags.** The fast path, which needs no catalog deploy and reaches a
  sideloaded key the catalog never heard of:

  ```json
  { "halo-extensions-disabled": [
      { "key": "ki2d-my-clock", "versions": ["1.2.3"], "note": "Crashes on start." },
      { "key": "w7abc-notes", "note": "Uploads the whole log." } ] }
  ```

  An entry without `versions` covers every version; one whose `versions` is
  not a list is dropped rather than read as all of them. It can sit in
  `defaults.json` or in any per-entity or per-call file; entries for one key
  combine, and one naming no versions covers them all. The full flags
  refresh needs the extension runtime up, so on its own it could never stop
  an extension that breaks the start: before the first start the boot reads
  `defaults.json` on a two-second budget and adds it to the list kept from
  the last refresh (`extensionForceDisabled`), and the start waits for that,
  so an entry meant to stop an extension that breaks the start belongs in
  `defaults.json`. After the start, a complete refresh (`defaults.json`
  answered, no file errored or timed out) replaces the kept list and a key
  that leaves it runs again; a round that missed a file changes nothing,
  since it cannot tell a lifted entry from one it did not read, and an
  offline launch keeps the list it has. Who has been told is its own record
  (`extensionForceDisabledTold`), so an entry the boot read before anything
  knew what was installed is still announced by the refresh after it. Only
  an installed extension can be stopped this way; a core one is the app's
  own code, which a release or a code push fixes. The record outlives an
  uninstall, so a reinstall of a covered version stays off.

A pulled extension's downloaded data expires on the same clock as any
extension the app is not loading.

## Replaced extensions

The catalog can say that one key has been replaced by another, and only its
root account can say so. The update check carries the replacement as a
release of the new key on the track the old one follows, while there is one
this app can install; the listing then leaves the old key out. The catalog
still answers the old key's own updates, for an app that predates
replacements, and the app takes none of them while the replacement is
pending. The app only ever **offers** it: a notice naming both, and a row
under Pending Updates whose **Replace** installs the new key through the
consent screen like any install. *Update all* never takes one, since each is
a new extension that asks consent of its own; until the operator replaces
it, the old one keeps running. Replacing carries everything the old
extension stored onto the new one before the install, so its first
activation finds it (its settings group, settings-panel values, docked
panels' values and secrets, account credentials, and the on/off choice,
which a replacement keeps rather than switching on), renames dock
arrangements (a panel id is `ext:<hook key>:<panel key>`, and only a hook
key that is the old key or the old key and `_…` is renamed, since a `-…` one
could as well be another extension's), then uninstalls the old one in the
same restart. When the new key is already installed, the row offers to
remove the old one instead, carrying the same things across without the
install. An uninstall forgets the docked panels' values and secrets along
with everything else the extension stored.

## What is checked at install

Beyond what the packer refused: the key is not one the app ships and does
not begin `ham2k-` (waived as above); the `api` is one this build speaks;
every `sharedDependencies` range is satisfied by what this build carries;
`relevance`, if present, passes the packer's rules again
(`ExtensionRelevance.validate`); entry names are sanitised on extract, so
`../` in one writes nothing.

## Where installed bundles live

Everything above is platform-neutral. What differs is only where the bytes
are kept (`BundleStorage`): natively, one directory per key under the app's
data directory, one file per bundle entry; on web, one IndexedDB record per
key (database `halo-extensions`), holding every entry's bytes, rather than
the Origin Private File System, whose writes are newer and patchier on
Safari. So the web build installs from a file, installs and updates from the
catalog, pre-loads and moves off the built-ins exactly as the native ones do.

## When the store is lost

The store can go while the preferences describing it survive: a browser
clearing IndexedDB alone, a data directory deleted by hand, a store that
failed mid-session. So what the operator installed is kept apart from the
store that holds it. `extensionsInstalled` records every extension the
operator installed (`{ key: name }`); every install writes it, and only an
uninstall or Forget removes it. An install that predates it is seeded from
its store once, and after that it never follows the store: a store found
short is exactly what it must not shrink to. Whatever is recorded there and
not in the store is **missing**, however it went, judged by the keys the
store holds and not by the extensions the app offers, since a built-in or a
dev server can stand in front of an installed bundle. A store that cannot be
read at all has lost nothing: that launch offers nothing, rather than
everything back into a failing store. Where each came from is its
provenance record's answer, and a key with none came from a file. The boot
cleanup that prunes settings for unknown keys treats every recorded key as
known.

Putting them back, after the app starts: **shipped bundles** come back at
boot from the app's own assets, unasked and offline, never as a first
install, so their settings and on/off choice stand; an install that has not
taken the upgrade gets back only what it had. **Everything else** is offered
in a dialog once the boot has settled: catalog extensions listed to install
at the release the catalog serves now (**Later** keeps them for the next
launch); file installs listed to install again from their files, and ones
from a different catalog as not available here, neither fetched, since the
bytes would come from a publisher the operator never agreed to; and
**Forget** on every row, which drops it with everything it stored, the only
way out for one the catalog no longer serves. **Install** installs each on
its own, so one that is not listed, will not download or fails the check
costs only itself; restarts the runtime with everything that landed,
setting aside a bundle it will not evaluate as the upgrade does; names what
could not be installed (offered again next launch) and what installed but
would not run (kept, marked in the panel, where an update is the way back);
says so when the runtime would not start at all, rather than calling it a
success; and says the app is still busy, offering them again next launch,
when another catalog pass holds the store. The offer waits for the boot's
catch-up to finish, or for an upgrade that every catch-up stepped aside for
to let go.
