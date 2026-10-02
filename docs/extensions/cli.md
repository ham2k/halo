# halo-ext — the extensions on the command line

`halo-ext` boots the **real** extension runtime — the same QuickJS host, the
same built bundles, the same hooks — outside the app, and lets you call any
hook with JSON and read back what it returned. No app, no simulator, no log
to set up — though the package still resolves against the Flutter SDK, since
the host it boots is a Flutter FFI plugin.

It runs on the plain Dart VM, where `dart:ui` does not exist, so neither
`halo_cli` nor anything it imports — `halo_extension_host`, `halo_core`,
`halo_build_tools`, `halo_quickjs` — may import `package:flutter`;
`package:flutter/foundation.dart` alone is enough to stop it compiling. The
gate runs its tests with `dart test` rather than `flutter test` for that
reason, since under `flutter test` such an import passes every test, and
`halo_extension_host` does not list `flutter` as a dependency, so the analyzer
flags one there (`depend_on_referenced_packages`).

It exists to answer the questions a debugger can't: *what does POTA's
`decorateRef` actually return for this park, today, over the real API? which
command hook claims this text? what does the ADIF exporter produce for this
operation?*

```sh
mise run ext -- lookup KI2D                    # or: cd packages/halo_cli && dart run bin/halo_ext.dart …
```

Scope is deliberately **extensions only**. It has no log, no radio and no
account keychain; a `halo-cat` for CAT control and a full `halo` over the
app's own data are separate, later tools that will live beside it in
`packages/halo_cli`.

## Getting it running

Three things have to exist, and `mise run setup` makes all of them once per
checkout: the bundles (`halo-ext` reads `app/assets/extensions` and the
catalog bundles pre-loaded beside it in `app/assets/preloaded-extensions`, the
same files the app ships — so POTA is `ham2k-pota` here as in the app, off or
on by default as an install has it, and sees no configured secret, as an
installed extension does not), the host build of the JS engine
(`packages/halo_quickjs/tool/build_host.sh` — the same library `flutter test`
loads, since neither runs a platform build), and `packages/halo_cli`'s
dependencies, resolved with `flutter pub get`. After that only the bundles
go stale:

```sh
cd extensions && npm run build     # after every extension change
```

Run it from anywhere in the repo (it walks up for the bundle directory), or
point `HALO_EXT_BUNDLES` / `--bundles` at one.

### Against the extension you're editing

`--dev-server` takes extensions from a running `npm run dev`
([development.md](development.md)) instead of the last thing you built, so a
hook can be exercised against an edit that has never been written to the app's
assets:

```sh
mise run ext -- --dev-server 127.0.0.1:8787 ref pota US-1234
```

It OVERLAYS rather than replaces: the dev server serves no kernel and only the
extensions it was asked to watch, so the built bundles are still required and
everything the server isn't serving keeps coming from them. `--verbose` names
what came from where.

Dev-served and pre-loaded extensions get **no secrets**, whatever key they
claim — the same provenance rule the app applies, where an installed extension
sees none; it matters more here because `--dev-server` will happily name
another machine.

## The commands

`invoke` is the primitive, and it reaches **every** hook — including any added
after this document was written:

```sh
halo-ext invoke <category> <method> [--key K] [--all] [--args JSON]

halo-ext invoke ref:pota decorateRef --args '{"ref":{"type":"pota","ref":"US-1234"}}'
halo-ext invoke activity suggest --all --args '{"searchTerm":"yosemite"}'
```

The rest are shorthand for one `invoke` with its arguments assembled — nothing
reinterprets a hook's answer:

| Command | Hook |
|---|---|
| `list [--hooks]` | the bundle index; `--hooks` boots and reports what actually registered |
| `lookup <CALL> [--recent-context]` | `lookupService/core.lookupCallInfo` |
| `command <TEXT> [--execute]`, `command --catalog` | every `command` hook's `interpret` / `catalog` |
| `spots [--source K]` | `spots.fetchSpots` |
| `export [--list] [--type T] [--out F]` | `export.suggestExportOptions` / `generateExport` |
| `score [summaries\|sections\|qsos] [--key K] [--ref JSON]` | `scoring.scoreQsos`, merged across the operation's scorers unless `--key` |
| `suggest [TERM] [--callsign C]` | every `activity` hook's `suggest` |
| `ref <TYPE> <REF> [--validate\|--title]` | `ref:<type>.decorateRef` / `validateRef` / `suggestOperationTitle` |
| `adif-fields [--combinations]` | every `adifFields` hook |
| `data-files list\|sync [KEY…]` | downloads and imports the reference datasets |
| `account list\|set\|test\|forget` | the `account` hook: stored credentials and `testCredentials` |

### Scoring

`scoreQsos` scores a whole operation in one hook call per scorer, so the
subcommands differ only in which piece of that answer they print — none of them
scores less, and none re-scores:

```sh
halo-ext score           --qson mylog.qson    # everything, as the hook returned it
halo-ext score summaries --qson mylog.qson    # the operation-wide tallies
halo-ext score sections  --qson mylog.qson    # the 24h UTC day buckets
halo-ext score qsos      --qson mylog.qson    # the per-QSO verdicts
```

By default this selects the scorers the OPERATION needs — core plus whatever
its refs and its log's hunted references call for — and merges their per-QSO
verdicts by the priority the app applies (contests.md §5.1), keying the output
by scorer. That is deliberate: this is the tool to reach for when the app's
scoring looks wrong, so it has to describe the program that is actually
running. A CLI answering `duplicate` for a contact the app credits is the most
confusing answer it could give.

`--key` asks ONE scorer instead (`core`, `cqww`, `fd`, …) and prints its raw,
unmerged result under that key alone — the view for looking at a single
scorer's own rules — and `--ref` gives it the contest reference it scopes to.
`--ref` belongs to `--key` and is refused without it: a merged pass hands each
scorer the ref that selected it, so there is nowhere for one you typed to go.
Both work on either side of the subcommand.

A scorer that fails is reported as `{"error": …}` in its own place rather than
taking the run down, since a misbehaving scorer is usually why you are here.

Add **`--md`** for a report instead of JSON:

```
$ halo-ext score summaries --md --key core --qson mylog.qson

## Summary

| Tally | Total | Detail |
|---|---:|---|
| `qsoCount` | 44 | 44 QSOs |
| `dxcc` | 4 | 4 DXCC Entities · entities: K 35, HI 7, HK 1, KP4 1 |
| `bandsAndModes` | 1 | **20m**: 44 SSB |
| `statesAndProvinces` | 15 | 15 US States · states: NC 8, VA 6, GA 2, … |
```

Without `--key` each scorer's section is printed under its own `## \`key\``
heading, in the priority order the app applies.

`score qsos --md` joins the verdicts back to the log you passed, so the table
reads by callsign and time rather than by uuid. Everything in these reports is
the scorer's own text — its tally keys, its labels, its notice keys (`newState`
raw, since the CLI has no translations) — nothing renamed or recomputed.

`--md` is refused, rather than ignored, by commands that have no report to
render: a format flag that silently does nothing is worse than one that says
it is unsupported.

### Giving it a log

Commands that work on a whole operation take one QSON file:

```sh
halo-ext --qson ~/Downloads/2026-07-15.KI2D.qson score
halo-ext --qson mylog.qson export --list
```

A QSON file is `{"operation": {…}, "qsos": […]}` — the payload shape every
coarse hook already takes, and what PoLo writes when it exports one, so an
exported log works unedited. A QSON is a whole log, so one that lists no
contacts is an **empty** log: hooks see `[]`, the answer meaning "this
operation has no QSOs yet", rather than the null that means "this host has no
log access". `--op` on its own still means the latter. `--op` and `--qsos` supply the halves separately,
and **override** the file's when both are given: replaying a real log against
a different operation ("what would these QSOs export as, activating a
different park?") is the reason to pass both, and a merge would leave you
guessing which operation produced the answer.

Every JSON option takes a file path, `-` for stdin, or inline JSON (anything
starting with `{` or `[`). A leading `@` on the path is accepted too, for the
rare path that really does start with a brace. Results go to
stdout (indented, or one line with `--compact`); logs, warnings and anything
an extension tried to show a user go to stderr. Exit codes: `0` ok, `1` the
hook or the runtime failed, `2` you typed something wrong.

Useful global options: `--only`/`--exclude` to load a subset of extensions
(`--only ham2k-pota` runs POTA and nothing else, so nobody else's hook can answer),
`--qson`/`--op`/`--qsos`/`--qso` to supply log data, `--location lat,lon`,
`--offline` to tell hooks the device has no network, `--md` for a rendered
report where one exists, `-v` to narrate host calls.

## Accounts

Some extensions want credentials — QRZ a login, ParksnPeaks a user id and key.
The app keeps those in the platform keychain; here they go in the config file.

```sh
halo-ext account list                  # what extensions offer, and what is stored
halo-ext account set ham2k-qrz         # prompts for each field; secrets are not echoed
halo-ext account set ham2k-qrz username=N0DEV
halo-ext account test ham2k-qrz        # the extension's own testCredentials verdict
halo-ext account forget ham2k-qrz
```

`set` prompts for whatever you did not pass, so a password need never appear
in shell history. With no terminal it does not prompt — that would hang a
script on a stdin nobody is typing into — and instead names the fields still
missing; feed those with `--stdin`, as `key=value` lines, or as arguments.
A field the extension never declared is refused rather than stored, since a
misspelled one leaves an account looking configured while the hook reads null.

`account list` reports *which* fields are stored, never their values, and
`test` asks the extension itself:

```
$ halo-ext account test ham2k-qrz
{ "kvKey": "ham2k-qrz", "result": "Authentication failed: **Username/password incorrect**" }
```

Accounts whose extension is off by default need `--all-extensions` to be
visible at all. OAuth accounts (SOTA) show `"oauth2": true` and have no
fields: the app runs a PKCE browser flow for those, which this tool does not.

## Reference data

POTA's park list and SOTA's summit list back the `dbLookupSelect*` host calls,
which is where `suggest` and the grid-resolving lookups get their answers.
Without them those come back empty — correctly, but confusingly.

```sh
halo-ext data-files sync             # everything registered
halo-ext data-files sync ham2k-pota-all-parks
halo-ext data-files list             # what is registered, and what the cache holds
```

The data lands in `~/.cache/ham2k/halo-cli` (`$XDG_CACHE_HOME`, or `--cache`)
and stays there. The *invocation* is still stateless; the reference data is
not, for the same reason the app caches it — re-downloading 181k summits per
run is not a thing.

Park and summit lists become rows in a SQLite table anything can read. A
**raw** file (the callsign notes) is different: its extension parses it into
whatever shape it keeps in memory, so the cached copy is replayed into the
runtime at every boot — which is why `data-files sync ham2k-call-notes-hams-of-note` reports
`entries` and a `cachedAt` path rather than a row count.

## Configuration

Settings and account credentials live in `~/.config/ham2k/halo-cli.json`
(`$XDG_CONFIG_HOME`, or `--config`). A `--config` path that does not exist is
an error for everything except `account set`, which creates it — elsewhere,
running with none of the credentials you meant to pass looks exactly like an
extension that has none. It holds what the app keeps in
SharedPreferences and the platform keychain, so **treat it like a keychain**:
it is written `0600` and can contain a QRZ password or a SOTA refresh token.

```json
{
  "settings": { "operatorCall": "KI2D", "developerMode": true },
  "accounts": { "ham2k-qrz": { "credentials": { "username": "KI2D", "password": "…" } } },
  "extensions": { "ham2k-wwff": true }
}
```

Anything under `settings` merges over the defaults, which mirror the app's
`getSettings` view. `secrets` are the build-time values behind
`host.secret(name)`; each extension sees only the names its own key prefixes,
under the same policy the app applies (`extensionMaySeeSecret`).

The environment overrides the file, and is the right channel for CI and
one-off runs: `HALO_SECRET_<NAME>` supplies one secret and `HALO_SETTING_<key>`
one setting. Neither is ever written back — an override belongs to the
invocation, and persisting it would turn a one-off into stored state you never
chose and cannot see.

## What it cannot do

- **No log.** `getOperation`/`getQsos` answer from `--qson`/`--op`/`--qsos`
  and nothing else, so a hook that reads the log sees exactly what you handed
  it — and a request for an operation you did not supply is a miss, never a
  substitution.
- **No UI.** `showForm` answers "cancelled", status-bar calls are reported on
  stderr and dropped. A hook that shows a message still returns its data.
- **No app translations.** `host.translate` returns null; an extension
  localizing its own strings via `createTranslator` is unaffected.
- **No sync.** `syncTransport` is a stateful loop owned by the Dart core, not
  a one-shot call.

## Notes for extension authors

- `list --hooks` reports what `registerHook` actually did — the manifest's
  `hooks` array is a claim, this is the fact. They disagree when an activation
  threw halfway or a hook key was refused by the namespacing rule.
- `--only <your-extension>` is the fastest way to tell your hook's answer from
  a higher-priority one somewhere else.
- Traffic from here carries `Ham2K halo-ext/<version> (<platform> cli)`, not
  the app's User-Agent, so a debugging session is distinguishable from the
  product in an API operator's logs. The per-extension domain allowlist and
  every other `host.fetch` rule still apply — see
  [network.md](../design/network.md).
