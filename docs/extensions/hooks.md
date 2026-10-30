# How hooks work

A hook is an object whose methods the app calls. This page is what every
hook has in common: how one is registered, how the app reaches it, what it is
handed, and what happens when it fails. The pages under *Hook reference*
document each category's methods.

## Registering

```ts
defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("lookup", { hook: MyLookup, priority: 50 })
    registerHook("ref:w7abcLakes", { hook: LakeHandler })
    registerHook("chasing", { key: "w7abc-lakes_hunted", hook: HuntedLakes })
  },
})
```

`registerHook(category, { hook, key?, priority? })`:

- **`category`** is one of the closed list below, or `ref:<type>` for a
  reference handler. The type is `HookCategoryName`, so a misspelled
  category fails the typecheck rather than registering a hook nothing calls.
- **`key`** defaults to your extension's key. Where you register several
  hooks in one category, each key is your key or your key followed by `_`
  and a suffix; the host refuses anything else, at registration and again on
  the keys a settings hook's `getPanels` answers. The key is the hook's
  identity: it namespaces what the hook stores, it is what the app names
  when it reports an error, and for some categories it is how the app
  addresses the hook (a `cluster` hook is delivered lines under its key, a
  `chasing` program is known by it).
- **`priority`** orders hooks within a category. Higher runs first; the
  default is 0. Register below 0 to be a fallback that fills only what no
  other hook answered.

Type the hook object with its SDK interface (`PanelHook`, `LookupHook`,
`ChasingHook`, …). The app routes to a method by its name as a string, so a
method named almost right is a hook that is never called, and the type is
what catches it.

Your manifest's `hooks` lists every category you register, `ref:<type>`
entries included. The app reads that list without evaluating the bundle: an
installed-but-disabled extension is described by it, a settings panel is
shown only when it is listed, and a `ref:<type>` entry is what lets the app
offer your extension for an operation that carries a reference nobody
handles. [The manifest](manifest.md#hooks-and-claims) says what each entry
does.

## How the app reaches a hook

Three shapes, and each category's page says which it uses:

| Shape | What happens | Used for |
| --- | --- | --- |
| **One hook** | The highest-priority hook in the category, or the one whose key the app names, gets the call | `ref:<type>` handlers, `lookupService`, `template`, `syncTransport` |
| **Every hook** | Each hook in the category is called with the same arguments, in one round trip; each answers on its own | `spots`, `command`, `activity`, `export`, `chasing`, `adifImport` |
| **A batch** | Several single calls travel in one round trip, each reaching the hook it would reach alone | reference decoration, links and outlines for a list of references |

Where many hooks answer at once, one hook failing costs its own entry and
nothing else, whether it throws, has no such method, or answers something
JSON cannot carry. The caller sees the other answers. One that runs out of
time costs its own entry too, where the caller asked for partial results;
otherwise, and for a batch that runs out of time before any answer has
reached the app, the whole call fails.

Some categories are also invoked **inside the runtime**, by another extension
rather than by the app, with no bridge crossing: `adifFields` by every
exporter, `lookup` by the lookup orchestrator. [The host API](host.md#calling-other-extensions)
has the calls (`hooks.invokeAll`, `hooks.invokeOne`, `hooks.invokeForRefs`).

## What a method receives

Every method has the shape `async method(args, ctx)`:

- **`args`** is the object the category's page documents for that method:
  the operation, a QSO, a reference, the text typed. Everything is JSON. An
  `operation` carries its `uuid` and, where the caller knows them, its
  `startAtMillisMin`/`startAtMillisMax` and `operatorCall`. A `qso` is the
  contact as it is logged, or the draft being composed, in the QSON shape
  `@ham2k/lib-qson-tools` defines.
- **`ctx`** is the hook context, the same for every category: `online`,
  `locale`, `developerMode`, the operator's number and date conventions,
  the build's edition, and reads into the log (`getOperation`, `getQsos`,
  `getHistoryForCall`) and the spots board (`getSpots`, `getSpotsForCall`).
  [The host API](host.md#the-hook-context) lists every field.

From extension API 9 the QSOs a hook reads through `ctx.getQsos`, and a
scorer's `qsos`, are frozen: every extension reads one shared copy of the
log, and a write throws. Copy what you mean to change.

## Time and failure

- **Throw for a bug, return empty for an expected condition.** A hook that
  throws is reported against your key and answers nothing for that call;
  nothing else is affected. Not configured, not found, offline with no local
  data: return the empty answer the page names (`[]`, `null`), never throw.
- **A hook that hangs is worse than one that throws.** The app times out the
  fan-out as a whole, not your hook. A caller that opts into partial results
  keeps the other hooks' answers and is told which went quiet; every other
  caller gets an error and no results at all. Bound every optional request
  with `host.fetch`'s `timeout`, and keep the hot paths cheap: `lookup`
  runs on a pause in typing, a command's `interpret` on every pause, a
  panel on the `qso` trigger as fast as the operator types.
- **A hook keeps running after it has been timed out.** What it holds is
  released by that resource's own bound: a fetch slot when the fetch ends,
  within the `timeout` you gave it.
- **Returned values must be JSON.** A `Date`, a `BigInt`, a function, a
  circular object fails the answer.
- **Answer the shape the page names, whole.** Where a hook answers for a
  batch (`adifImport`, `claimsForQsos`) it answers positionally or by uuid
  for every record; a short or reordered answer lands one contact's result
  on another and is discarded.

## The categories

| Category | Page | What it is for | Reached as |
| --- | --- | --- | --- |
| `lookup` | [Lookups](lookups.md) | Who a callsign is | every hook, in priority order, by the orchestrator |
| `recentContextLookup` | [Lookups](lookups.md) | What a station is doing right now, while a contact is being composed | every hook, after `lookup` |
| `lookupService` | [Lookups](lookups.md) | The orchestrator itself; the app's core registers it | one hook |
| `spots` | [Spots](spots.md) | A spot source, and posting spots | every hook |
| `cluster` | [Spots](spots.md) | Lines from the app's DX cluster connection | the hook under your key |
| `activity` | [Activities](activities.md) | Logging controls, operation setup, suggestions, a last look at a QSO before it saves | every hook |
| `ref:<type>` | [Activities](activities.md) | Validate, decorate, link and outline one kind of reference | one hook per type, batched |
| `dataFile` | [Activities](activities.md) | An offline dataset the app downloads and indexes for you | your registration |
| `export` | [Import & export](import-export.md) | A file the operator can save or share | every hook, then the chosen one |
| `adifFields` | [Import & export](import-export.md) | Your program's fields on each ADIF record | inside the runtime, by exporters: the hooks that answer for the contact's references, or the ones an export names |
| `adifImport` | [Import & export](import-export.md) | Your references recovered from imported ADIF | every hook, in batches of 500 records |
| `scoring` | [Scoring & chasing](scoring.md) | A score for an operation | the scorers whose scope matches |
| `chasing` | [Scoring & chasing](scoring.md) | What a contact counts toward in an award | every program |
| `command` | [Commands & templates](commands.md) | Text typed in the call field | every hook, first non-null answer wins |
| `template` | [Commands & templates](commands.md) | Rendering a template on the app's behalf; the app's core registers it | one hook |
| `panel` | [Panels](panels.md) | A pane in a view | your registration, per panel |
| `account` | [Accounts & sync](accounts.md) | A login the operator keeps in the keychain | your registration |
| `syncTransport` | [Accounts & sync](accounts.md) | Moving a sync payload over the network | one hook |
| `settingsPanel` | [Settings panels](settings.md) | Your preferences in Settings | your registration |
| `form` | [Forms](forms.md) | A form the app can show by key | the hook under the key |

Four more names are in the list for completeness. `bench` and `runtime` are
the kernel's own and nothing an extension registers. `callNotes` is a
convention between Ham2K's own extensions, through which the callsign-notes
extension exposes its parsed index inside the runtime. A category outside
this list cannot be registered; new ones arrive with the API level that
introduces them.
