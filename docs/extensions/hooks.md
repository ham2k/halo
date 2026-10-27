# Hook reference

Hooks are registered under a **category** with an optional **key** (defaults
to the extension key) and **priority** (higher runs first; default 0). The
host invokes them three ways:

- `invokeHook(category, key?, method, args)` — best (highest-priority) hook.
- `invokeHookAll(category, method, args)` — every hook in the category, one
  bridge round-trip, per-source error isolation.
- `invokeHookBatch(calls)` — several `invokeHook` calls, one bridge
  round-trip, per-call error isolation. Each call reaches the same hook it
  would reach on its own, so a hook cannot tell a batched call from a single
  one.

The categories are a closed list. `registerHook` takes a `HookCategory`
([`extensions/sdk/src/hookCategories.ts`](../../extensions/sdk/src/hookCategories.ts))
or `ref:<type>`, so a misspelled category fails the typecheck rather than
registering a hook nothing calls, and the build rejects a manifest `hooks`
entry that is neither. A new category goes into that list — and, when the host
calls it, into the host's catalog as well
(`packages/halo_core/lib/src/hook_names.dart`).

In both shapes that answer many hooks at once, one hook failing costs its own
entry and nothing else — whether it throws, has no handler, or answers
something JSON cannot carry (a circular object, a `BigInt`). One that runs out
of time does too, when the caller asks for partial results; otherwise, and for
a batch of several calls that runs out of time before any answer has reached
the host, the whole call fails.

All argument and result types on these pages are defined in
[`extensions/sdk/src/types.ts`](../../extensions/sdk/src/types.ts). Every
hook method receives `(args, ctx)` where `ctx: HookContext` is:
* `online: boolean` — True if the device has an active network connection.
* `developerMode: boolean` — True if developer options are enabled in settings.
* `locale: string` — The active locale code of the application (e.g. `'en'`, `'es'`).
* `appName?: string` — Platform-appropriate app name ("Ham2K Logger" on
  desktop, "Ham2K Portable Logger" on mobile) — use this instead of a
  hardcoded name when identifying the app to an external service or file
  (e.g. a spot's `source` field, an ADIF `PROGRAMID` header).
* `edition?: string` — The running build's edition: `'dev' | 'next' | 'prod'`
  (see `packages/halo_build_tools/lib/src/edition.dart`). For a hook whose
  static config must vary per-edition — e.g. SOTA's OAuth redirect URL, one
  per edition and each registered separately with the provider.
* `enabledExperiments?: string[]` — Keys of every experiment
  (`app/experiments.yaml`) currently on for this user. For a hook whose own
  effect must stay invisible until an experiment gating the surface it
  belongs to has shipped ungated — checked per-call, since gating at the
  whole-extension `manifest.experiments` grain would also hide any other
  hook the same extension registers (e.g. `radio-commands`' WPM command
  checks `keyer` here; its BAND/MODE/frequency siblings don't).
* `experiments?: { key, name, aliases }[]` — The experiment catalog itself,
  on or off, so a hook can resolve a typed key-or-alias to one of the keys
  `enabledExperiments` lists (the EXP preview says "Enable"/"Disable" rather
  than "Toggle"). The app remains the authority when it flips the state.
* `getOperation?(uuid)` / `getQsos?(operationUuid)` — log-data reads, for
  hooks that only receive part of the picture as arguments (e.g. a `command`
  hook handed the operation it's typed into, needing the existing QSOs —
  dev-commands' SEED). `getOperation` resolves the operation's QSON with
  `uuid` folded in (null for an unknown uuid); `getQsos` resolves every QSO's
  raw QSON, oldest first, excluding soft-deleted records but *including*
  event markers (`band: 'event'`) — or null when the operation is unknown or
  the host has no log access, distinct from `[]` (the operation exists and
  simply has no QSOs yet). Every extension reads one copy of the log the
  runtime keeps, which asks the host only what changed since the last read:
  a call is never staler than itself, and the whole log crosses the bridge
  only the first time. Each call gets a new array. From extension API 9 its
  QSOs are that shared copy, frozen — a write throws, so copy what you mean
  to change; under an older `api` each call gets QSOs of its own.
* `getSpotsForCall?(call, maxAgeMinutes = 30)` — the spots the host has
  already fetched for `call`, no older than `maxAgeMinutes` (measured on the
  spot's own `spot.timeInMillis`, not on when it was fetched), newest first.
  Reads the host's cache and **never triggers a fetch**, so unlike the log
  reads above it is cheap enough for the lookup path; it resolves `[]`
  whenever the cache is cold or the host keeps no spots. Used by
  `spot-history` to pull a hunted park or summit into the QSO being logged.
* `host.suggestQso({qso, operationUuid?})` (extension API 12) — puts a
  station into the logging fields of the operation in front, as tapping its
  spot in the Spots Panel does: `qso.their.call`, and `freq`, `band`, `mode`
  and `refs` where given; nothing else of `qso` reaches the fields. With
  `operationUuid` — a panel's own `operation.uuid` — only that operation's
  fields, so a panel never fills a log the operator is not looking at.
  Answers `{accepted}`, false when no such operation is open. It tunes the
  radio as a tap does, so it needs `requiresRadioWrite`, and it is refused
  except from inside the extension's own panel `onEvent`: it answers the
  operator clicking something, never a timer or a render, which would
  overwrite what they are typing.
* `getSpots?(options?)` — the whole spots board the host already holds,
  for a panel showing spots its own way. Like `getSpotsForCall` it reads the
  cache and never fetches, and resolves `[]` while the cache is cold. By
  default it answers what the operator's Spots Panel shows: their sources,
  enabled bands, band and mode filters (an "auto" filter follows the radio),
  age and continents, merged and ordered as that panel does — so one spot
  can stand for several stations, its `their.call` comma-joined
  (`'K1ABC,W2XYZ'`). `filter: 'all'`
  starts instead from every held spot, one per source report, newest first.
  Either way `maxAgeMinutes`, `band`, `mode` (a mode, or `SSB`/`Phone`/`CW`/
  `Digital` for a family) and `source` (a spot source's hook key, carried on
  each spot as `hookKey`) narrow it further. Spots come back with
  `annotations` — `worked`, `isSelf`, `notices`, judged the way the Spots
  Panel strikes and accents its rows — whenever there is an operation to judge
  them against: `operationUuid`, or the `operation` the calling hook was
  handed, so a panel's render gets them without asking. The verdicts are the
  ones the app already holds for the operation open on screen, so the call
  never waits on a scorer; another operation's spots, and that one's until
  its first verdicts land, come back unannotated rather than guessed.
  From extension API 12 each also carries `display` — what the Spots Panel's
  row shows beside the call. `icons` lists every icon the row may show, each
  `{icon, iconColor?, kind}` — an MDI or `fa-` name, its tint (`#RRGGBB`,
  where its extension declares one) and what put it there, in this order:
  `scoring`, the icons scorers gave the spot; `chasing`, those of the chasing
  programs whose verdicts alert for it; and `reference`, one for each kind of
  reference the spot carries, in the order it names them — the handling
  activity's icon, or the source's own for a reference no activity handles.
  No icon appears twice. The scoring and chasing icons come only with the
  annotations, above. The panel draws three, at least one of each kind there
  is; draw as many as you have room for. `icon` and `iconColor` are the first
  reference's, and all a host from before `icons` sends. `emoji` is the
  call's note emoji, where it has one. `annotate: false` returns the spots as
  their sources gave them.
  A panel's `'spots'` trigger fires whenever this answer may have moved: a
  refresh, new verdicts, the operator's spot filters or bands, or the radio's
  band or mode. A malformed or unknown option rejects the call. The CLI host
  has no operator: its `'user'` board is every spot handed to it, never
  annotated.
* `getHistoryForCall?(call, options?)` — the most recent non-deleted contacts
  logged with `call` (five unless `limit` says otherwise, never more than
  50), across every operation, newest first, as raw QSON — the one log read
  that is cross-operation rather than scoped to a single one, since it
  answers "who is this station" from the whole log rather than "what's in
  this operation". Resolves `[]` for no match or no log access; unlike
  `getQsos` there is no "unknown call" to distinguish from "no history".
  Used by `call-history` to fold the most recent past QSO's fields into a
  lookup result.

  `options` (`HistoryForCallOptions` in `types.ts`) narrow the history
  before it is ordered and limited, so `{ refType: 'cwt' }` finds last
  month's CWT exchange behind a week of POTA contacts. The filters are
  `refType` (a ref in the QSO's own `refs` or its operation's, since an
  activation's ref lives on the operation), `refPrefix` (such a ref whose
  `ref` starts with it, ignoring ASCII case; with `refType`, the same ref
  must pass both, so `{ refType: 'potaActivation', refPrefix: 'FR-' }` finds
  every contact made activating a French park; an operation's refs are its
  base ones unless `refsSegmentAware: true`, which reads them as they stood
  at each contact, so a rove's second park or a contest that ended at a
  break is seen), `operation`/`excludeOperation`,
  `band`/`excludeBand`, `mode`/`excludeMode` (`SSB` also matches its
  sidebands, and `CW`/`PHONE`/`DATA` match their whole family), whole UTC
  days through `fromDate`/`toDate` or `fromDateMillis`/`toDateMillis`, and
  exact instants through `fromTime`/`toTime` or
  `fromTimeMillis`/`toTimeMillis`. All the bounds are inclusive. A malformed
  option, an unknown one, or an include option given no values
  (`operation: []`) rejects the call instead of answering an unfiltered
  history. Hosts older than these options ignore them and answer the latest
  five contacts unfiltered, so a caller re-checks on the results whatever it
  relies on — and an empty answer there means "none among the latest five",
  not "none at all".

Status legend: ✅ implemented · 🔜 planned (design in DESIGN.md §4).

## The hook categories

| Category | Page | What it is for |
|---|---|---|
| `lookup`, `recentContextLookup`, `lookupService` | [Lookups](lookups.md) | Callsign lookups, live-context lookups, and the orchestrator that merges them |
| `spots`, `cluster` | [Spots](spots.md) | Spot sources and spotting, and the DX cluster connection |
| `activity`, `ref:<type>`, `dataFile` | [Activities](activities.md) | What an activity adds to the app, the references it handles, and its offline datasets |
| `export`, `adifFields`, `adifImport` | [Import & export](import-export.md) | Log files, per-QSO ADIF fields, and references recovered on import |
| `scoring`, `chasing` | [Scoring & chasing](scoring.md) | Per-operation scores, and what a contact counts toward |
| `command`, `template` | [Commands & templates](commands.md) | Call-field commands, and rendering templates on the app's behalf |
| `panel` | [Panels](panels.md) | Panes in a view — and their scenes ([Panel scenes](scenes.md)) and radio calls ([Radio control](radio.md)) |
| `account`, `settingsPanel`, `syncTransport`, `bench` | [Accounts, settings & sync](accounts.md) | Account connections, settings forms, sync backends, diagnostics |

## 🔜 Planned categories

| Category | Role | Notes |
|---|---|---|
| `confirmation` | QSL/confirmation sources (spot-history cross-checking) | |
| `opSetting` | per-operation settings contributions | |

When one of these lands, it moves to the page it belongs on, with its real signature.
