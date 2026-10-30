# Publishing

The [extension catalog](https://catalog.ham2k.net) is how other operators
find your extension: the app's **Settings → Extensions & Features** lists
what the catalog publishes, ranked for the operator's own callsign, and
installs and updates from it. This page is the path from a packed bundle to
a listing, and what the app does with it afterwards.

## What you need

Two things from the catalog site, both under [Publish](https://catalog.ham2k.net/publish)
once you sign in:

- **A grant for your callsign prefix.** Ask once; a reviewer approves it.
  Every key you publish starts with that prefix.
- **An API token.** Create one with a name and an expiry. It is shown once.
  Keep it in your shell's environment, never in a file you commit.

## Publish

```sh
export H2K_CATALOG_TOKEN=h2kc_…
npx -p @ham2k/extension-tools h2kext-publish build --channel stable --notes "What changed"
```

`h2kext-publish` reads the token from `H2K_CATALOG_TOKEN` and from nowhere
else; there is no flag for it, because a flag lands in your shell history,
and it stores the token nowhere. A directory is packed first, exactly as
`h2kext-pack` would; a `.h2kext` you already made is sent as it is. The
catalog re-validates everything the app validates, stores the bundle with
its sha256, and answers:

```
published w7abc-notes 1.2.3 → stable (pending review)
```

- **Release notes** go up in a second request once the upload is accepted,
  and can be edited on your dashboard afterwards. If that request is
  refused the version is still published; the command says so and exits 1.
- **Every refusal** prints the catalog's reason and exits 1. Nothing is
  retried. Exit 2 is a usage problem.
- **A version's bytes freeze** the first time a reviewer approves them. From
  then on the same version with different bytes is refused, so a fix is a
  new version. A rejection does not burn the version number.
- A bundle is **16 MiB at most**.

| Flag | |
| --- | --- |
| `--channel stable \| unstable \| bleeding` | How finished this release is; default `stable` |
| `--notes "…"` | Release notes, markdown |
| `--screenshots <dir>` | The folder holding the extension's screenshots; default `./screenshots` when it exists |
| `--screenshots-only` | Update the screenshots without publishing a version |
| `--force-name` | Ham2K's own packaging; waives the key convention, nothing else |

## Channels

A channel says how finished a release is, not who is running it:

- **`stable`**: ready for anyone. This is what the app asks for.
- **`unstable`**: ready for people who agreed to try it.
- **`bleeding`**: you are still working on it.

They cascade upward: `unstable` also shows everything on `stable`, and
`bleeding` shows all three. Asking for a rougher channel adds releases; it
never takes finished ones away. Publish to `unstable` when you want testers
on a version before everyone, then publish the same version to `stable`; the
bytes are already stored, so the second publish only opens a submission. A
prerelease version like `1.3.0-beta.1` is the same story: put it on
`bleeding` or `unstable` and it stays away from `stable` installs.

## Review

Every submission is reviewed by a Ham2K reviewer before anyone can install
it. Your dashboard shows the outcome and any note. The catalog reads the
manifest and never runs the bundle, so the manifest is what it reviews, and
it holds an upload for an admin, even from a trusted publisher, over a
settings placement beyond the usual: a `settingsPanel` with no
`settings.section`, a section off the list, a sidebar entry, or rows on
Common Preferences ([Settings panels](settings.md#where-an-extensions-settings-go)).
The answer to the upload names which one held it back. A placement once
approved stays approved for later versions whose `settings` are unchanged.
To ask for one, declare it and say why in the release notes.

You can withdraw a submission yourself at any time, pending or approved,
and the previous release becomes current again.

## Screenshots

```
screenshots/
  1-logging.png
  2-map.png
  screenshots.json      optional: { "1-logging.png": "Logging a park" }
```

When your project has a `screenshots/` folder, or you name one with
`--screenshots`, `h2kext-publish` makes the catalog's screenshots match it
after the bundle is accepted. The folder is the whole set: PNG, JPEG or
WebP, at most 8, shown in file-name order (`2-…` before `10-…`), captions
from `screenshots.json`. Each is at most 2 MiB and 3,840 pixels on its
longest side. The command makes the thumbnails itself with `sharp`, an
optional dependency; where it could not install, the command says so and
the screenshots can be added on the site's Publish page instead.
Screenshots belong to
the extension, not to a version, so every channel shows the same ones, and
they are never packed into the bundle. An unchanged folder sends nothing. A
new set waits for a reviewer while the approved one keeps showing. An empty
folder named with `--screenshots` takes every screenshot down.

In the app they show as a strip of thumbnails on the extension's row in the
activity search, on the consent screen of a catalog install, and in the
installed extension's details.

## What the app does with it

**Listing.** The Extensions panel lists the catalog's `stable` channel in
the catalog's order for the operator's callsign, which `relevance` in your
manifest decides ([The manifest](manifest.md#relevance)). Under developer
mode the operator can widen the listing to `unstable` or `bleeding`.

**Installing.** Install and Update go through the same consent screen as a
file, naming what the manifest asks for, over bytes that must hash to the
listing's sha256. **Every install asks, including an update that wants
nothing new**: a bundle can change completely and still ask for the same
things, and until a bundle can be shown to come from whoever it claims, the
key alone is not enough. *Update all* is the one exception, taking every
pending update on a single confirmation that names each one.

**Updating.** At most once a day the app asks the catalog whether anything
installed has a newer release, says so in the status bar and on the row, and
never installs unasked. An install records the channel it came from as the
**track** the extension follows: an extension installed from `unstable` is
offered `unstable` releases from then on, and the operator can put it back
on stable from its details. Installing a bundle whose key is already
installed updates it in place, keeping everything it stored.

**Links.** A web page can hand the app a bundle to install:

```
com.ham2k.logger:///install_extension?url=https://example.org/w7abc-notes.h2kext
```

The URL must be https, redirects that leave https are refused, and the
consent screen names the host the bytes came from. Every edition of the app
answers that scheme, so on a device with more than one installed the
platform decides which opens; the edition-specific schemes
(`com.ham2k.logger.dev`, `.next`, `.prod`) exist, but a link should not need
them, and the catalog keeps a plain download link beside its install button
for that case. An extension's catalog page
(`/extensions/<key>?channel=unstable`) pasted into the panel's search field
installs that channel's current release, and the consent screen warns over a
release that is not stable.

**Pulling.** The catalog can revoke one version, or disable a key as a
whole. Either reaches installed copies with the next update check, at most a
day later: the extension stops loading whatever the operator's switch says,
its row shows why with the note you or the reviewer wrote, and it runs again
with an update to a version that is not pulled.

**Replacing.** The catalog can say that one key has been replaced by another:
an extension that moved to Ham2K's namespace, or to a new maintainer. The app
offers the replacement, never installs it unasked, and when the operator
accepts, carries everything the old extension stored onto the new one
(settings, panel values, credentials, the on/off choice, dock arrangements)
before uninstalling the old one.

**Removing.** Uninstalling an extension removes everything it stored.

## Versioning your extension

- `version` is semantic. A patch for a bug, a minor for a feature, a major
  for a change that breaks what an operator had set up.
- `api` is the lowest level that has what you use ([Packaging](packaging.md#api-levels)).
  Raising it narrows who can install the release; the catalog keeps offering
  an older app the newest release it can run.
- Raise a chasing program's `program.version` whenever the same contacts
  would claim something different.
- Keep the key. Everything the operator has stored hangs off it.
