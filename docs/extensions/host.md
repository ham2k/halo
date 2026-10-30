# The host API

```ts
import { host, hooks } from "@ham2k/extension-sdk"
```

`host` is the one way out of the sandbox. Every call crosses to the app, is
answered, and is held to a budget; a call that would exceed one is refused
where it is made, never queued and never dropped silently. `hooks` calls
other extensions' hooks without leaving the runtime. The last section lists
the **hook context**, the `ctx` every hook method receives.

The signatures below are the ones in `dist/index.d.ts`, which is the final
word where prose and types disagree.

## Network

### `host.fetch(url, options?)`

```ts
const { status, body } = await host.fetch("https://api.pota.app/park/US-1234", { timeout: 4000 })
```

`options`: `method` (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`), `headers`,
`body` (a string), and `timeout` in milliseconds. The answer is
`{ status, body }`, the body as text.

- **Only hosts your manifest's `domains` lists**, over https. A plain
  `http://` host is refused unless it serves http only and Ham2K's proxy
  fronts it (`api` 4). An undeclared host is refused at the call.
- **A wildcard entry never reaches the local network**: loopback, the
  private ranges, link-local, IPv6 unique-local, an IPv4 address written as
  IPv6, the unspecified addresses, and `localhost` or `.local` names. Name
  the host, or run the app in developer mode.
- **At most 8 in flight per bundle.** A ninth is refused rather than queued,
  so a `Promise.all` over a long list fails past the eighth; run them in
  batches.
- **The app stamps its own `User-Agent`** on every request and ignores yours,
  unless the manifest sets `allowUserAgentOverride`.
- **`timeout` clamps downward only.** You may declare a request not worth the
  app's default wait, never award yourself a longer one. Set it on anything
  optional: a hook fan-out shares one time budget across every extension in
  the category, so a request that stalls costs the others their answers.
  A timeout raced in JS settles your promise and leaves the request running;
  this one stops it.

### `host.webSocket(url, { protocols? })`

Extension API 2. Returns at once, connecting, shaped like a browser's
`WebSocket` with `binaryType = "arraybuffer"`: `readyState`, `protocol`,
`send(data)`, `close(code?, reason?)`, and `onopen`, `onmessage`, `onerror`,
`onclose`. The app holds the connection; frames reach your callbacks
whenever the peer sends them, outside any hook call.

```ts
const ws = host.webSocket("wss://stream.example.com/spots")
ws.onopen = () => ws.send(JSON.stringify({ subscribe: "spots" }))
ws.onmessage = (e) => { /* e.data: string, or ArrayBuffer for a binary frame */ }
ws.onclose = (e) => host.setTimeout(connect, nextBackoff())
```

- **The manifest's `webSockets` is its own grant.** `wss://` to a listed
  host; plain `ws://` only to a local-network address, by the same
  definition the fetch rule uses, judged by the name's spelling and not by
  what it resolves to; `"local"` admits every local-network address over
  either scheme.
- **At most 4 sockets per extension, 1 MiB per frame** either way. An
  oversized `send` throws; an oversized inbound frame closes the socket with
  1009.
- **At most 12 opens a minute per bundle.** Reconnect after a growing delay;
  a loop reconnecting straight from `onclose` is refused at the thirteenth.
- **A refused socket fails the way a browser's does**: `onerror`, then
  `onclose` with 1006, never a throw from `host.webSocket`. The `onerror`
  message says why.
- **A runtime restart closes your sockets without an `onclose`**: the code
  that would hear it is gone. Open them again from `onActivation`.
- On the web build the browser sets the handshake's `User-Agent`, and plain
  `ws://` to a LAN address is blocked as mixed content.

## Timers

```ts
host.setTimeout(fn, ms, ...args)     host.clearTimeout(id)
host.setInterval(fn, ms, ...args)    host.clearInterval(id)
```

Browser-shaped: extra arguments reach the callback, an id is a number,
either clear reaches either kind. They run outside any hook call, so there
is no `ctx` there. From extension API 3 the build points a bare
`setTimeout` in your bundle, npm dependencies included, at these; the app's
shared libraries run in the kernel and have no timers.

- **Real, monotonic time.** A timer is a duration the app sleeps for; it
  follows neither developer time travel nor a clock set back.
- **`setTimeout` never throws** for a function callback. A timer the app
  will not keep (past the cap, set while suspended, set before activation)
  gets an id that never fires, and the console says so once.
- **At most 16 live timers per extension.**
- **A budget instead of a minimum delay.** Every firing is charged what its
  callback took plus 1 ms per wake. Your callbacks may average **10% of real
  time**, with **five seconds** of burst. The wake charge alone puts a floor
  under intervals: at 10 ms or less none stays within budget. Anything that
  must move faster than a few times a second belongs in a scene binding.
- **Five callbacks in a row that throw** break the budget too; a promise a
  callback returns that rejects later is logged, not counted. So does a
  callback the engine has to interrupt for running past its limit, on native
  builds; the web build's Worker has no such limit, and a callback that never
  returns hangs it, as a hook that never returns does.
- **Breaking the budget suspends your timers** until the runtime restarts.
  Your hooks keep working. The console names the rule; in developer mode a
  notice names your extension.
- **Only a callback's synchronous part is measured.** Keep heavy work there,
  or in small pieces.
- **The app does not pause timers while hidden**, though the platform may:
  iOS suspends a backgrounded app, and a browser slows a hidden tab's timers
  to about once a minute. Stop and restart visible-only work from `onHide`
  and `onShow`.
- **A runtime restart cancels your timers.** Set them again from
  `onActivation`.

## Storage and settings

### `host.kvGet(key)` / `host.kvSet(key, value)`

Key-value storage namespaced to your extension, in memory for the session:
a runtime restart clears it. A bundle holds at most **10 keys**, each key
plus its JSON value at most **4,096 characters**; a `kvSet` past either
throws, and setting `null` frees the key. For a session token, a cursor, the
last answer. Not a cache, not a database.

### `host.getSettings()` / `host.setSettings(values)`

`getSettings` is the whole read view: the app's resolved core values (theme,
locale, font scale, distance units, logging toggles, bands and modes,
privacy consents, the active profile's `operatorCall`, `operatorName`,
`operatorEmail`, `operatorClub` and `operatorSection`, `syncEnabled`,
`developerMode`, `appName`, `enabledExperiments`) plus every extension's own
group under `extensions`, keyed `extension_<key>`. Reading is unrestricted;
settings are not secrets. Credentials and accounts are absent by design:
they live in the keychain, through the `account` hook. The `operator*`
fields beyond the callsign are free-form and may be `''`.

`setSettings` writes into **your** group only; the namespace is added for
you. Persisted by the app, and the storage behind a Tier 1 settings panel's
fields. [Settings panels](settings.md#reading-and-writing-settings) has the
field-level view.

### `host.searchSettings({ args, kind? })`

For a `command` hook that changes a setting the operator named. `args` is
everything typed after the command word, whole; where the setting's name
ends and the value begins is decided by the app, since only its settings
catalog can tell `AVOID ZERO BEAT N` from `THEME DARK`. `kind` is `set`,
`show` or `hide`; the last two reach only visibility toggles and derive the
value from the verb. Matching is by subsequence over each setting's key,
aliases and label, across every setting the Settings screen would show
right now and only those. Never rejects: an unmatched query answers
`{ found: false }`. A match carries `key`, `label`, `section`, `fieldType`,
the current value as `valueLabel` (and as `value` for a boolean only), the
coerced new value as `newValue` with its `newValueLabel`, `unchanged` when
they agree, and `expects` when the setting needs a value the text did not
give; a `secret` field's value is never included. `ambiguous` with
`candidates` means several settings matched, and `simple: false` means the
setting wants its own form: both are cases for the `openSettings` action
rather than `updateSetting`
([Commands & templates](commands.md#reaching-the-apps-settings)). This call
re-enters the runtime while your hook awaits it, which is safe, and the only
host call that does.

### `host.secret(name)`

A value built into the app, by name, or `null`. An installed extension sees
none, whatever key it claims. Nothing you ship can depend on one; where a
value is public anyway (a client id, a key a program hands out to every
app), make it a constant.

## Talking to the operator

### `host.showForm(form, state?)`

Opens a dialog from a [form definition](forms.md) with `state` pre-filled
and resolves with the submitted values, or `null` when cancelled. A dialog is
one extension's at a time: while another extension's dialogs are up, yours
waits for them to close. You may have **3 open**, one over the other, **3
waiting**, and open **10 a minute**; past any of these the call throws. (A
bundle built with an SDK before 1.12.6 opens its forms without naming
itself, and every such form shares one budget, as one extension's.)

### `host.showMessage({ presentation, title?, text, icon?, actions? })`

`presentation: "status"` is a line in the footer; `"dialog"` shares the
dialog surface and budget above, opening when the surface is free, and the
call answers at once, so a hook may await it. For a result a hook cannot
carry in its return value, such as a lookup hitting an authentication error.
Where a hook's result can carry a `userMessage` (spot posting), prefer that.

### `host.statusBar`

| Call | |
| --- | --- |
| `setMessage({ key, text?, title?, icon? })` | A transient one-line message under `key`, replacing the last one under it |
| `setProgress({ key, text?, title?, icon?, value? })` | A progress bar under `key`; omit `value` for indeterminate |
| `clear(key)` | Removes the message or progress under `key` |
| `showNotice({ key, text, title?, icon?, actions? })` | A richer, dismissible notice over the footer, kept under **Settings → About → Recent Notices** after dismissal; `text` is markdown. `actions` are buttons: `{ label, type: "link", url }`, `{ label, type: "dialog", title?, text }` or `{ label, type: "account", key, subkey? }` |
| `dismissNotice(key)` | Dismisses the notice under `key` |

Keys are namespaced to your extension. You hold at most **8 keys** in the
footer across messages, progress and notices; every string in a call is at
most **1,024 characters**, a notice's `text` **16,384**; messages and
progress reach the footer at most once every **100 ms**, the latest under
each key winning, so a download may post every chunk; notices are **10 a
minute**. Past any of these the call throws.

### `host.updateInterpretation(input, interpretation)`

One-way, like `log`. Pushes a later interpretation for the same `input` a
`command` hook's `interpret` was called with, for a hook that answers with a
placeholder and fills it in when a fetch lands. Discarded when the field has
moved on. [Commands & templates](commands.md#answering-later).

### `host.suggestQso({ qso, operationUuid? })`

Extension API 12, `requiresRadioWrite`. Puts a station into the logging
fields of the operation in front, as tapping its spot does: `qso.their.call`,
and `freq`, `band`, `mode` and `refs` where given; nothing else reaches the
fields. With `operationUuid`, only that operation's. Answers
`{ accepted }`, false when no such operation is open. It tunes the radio as a
tap does, and it is refused except from inside your own panel's `onEvent`:
it answers the operator clicking something, never a timer or a render.

## Reading the app

| Call | Answers |
| --- | --- |
| `host.getVersionInfo()` | `{ platform, edition, version, versionName, buildNumber, gitSha }`; `buildNumber` is `null` on a development build |
| `host.getLocation()` | `{ latitude, longitude }`, or `null` when location is unavailable, denied or off. Needs `requiresLocation`; may prompt the operator the first time |
| `host.translate(key)` / `host.translateAll(keys)` | One of the app's own strings by dot-path key in the active locale, or `null`; many in one round trip |
| `host.log(message)` | A line in the app's debug output, prefixed with your key |

## Reference data

The rows a `dataFile` registration fills ([Activities](activities.md#datafile))
are read back through four calls. Each row is a `LookupRow`:
`{ category, subCategory?, key, name?, lat?, lon?, flags?, data? }`.

| Call | |
| --- | --- |
| `dbLookupSelectOne(category, key)` | One row by key, or `null` |
| `dbLookupSelectAll(category, query, subCategory?, activeOnly?)` | Rows matching `query` on key and name, the first 100 found. `subCategory` filters in the query, which matters because of that cap: a common word matches thousands of rows worldwide, and filtering afterwards can empty an already-truncated set. `activeOnly` drops rows whose `flags` is 0, the convention for a reference its program has retired |
| `dbLookupSelectByLocation(category, lat, lon, delta, activeOnly?)` | Rows within `delta` degrees of a point |
| `dbLookupSelectInBounds(category, bounds, { activeOnly?, limit? })` | Every row inside `{ south, west, north, east }`, nearest the centre first, at most `limit` (default 500, never past 1,000); `west` past `east` is a box across the antimeridian. Only an app that sends `SuggestArgs.bounds` answers it, so call it only when `bounds` arrived |

The SDK's `nearbyLookupRows` reads either the point or the bounds case for
a `suggest` hook, and the `referenceActivity` factory uses it for you.

## Accounts

A hook of an extension that registers an `account` finds the operator's
stored `credentials` and `session` on `ctx.account`. `host.setAccountSession(session)`
stores a session (a token, an expiry) for that account, in the keychain
beside the credentials. [Accounts & sync](accounts.md) has the hook.

## The radio

Capabilities in the manifest gate every call; [Radio control](radio.md)
documents them.

| Call | Needs | API |
| --- | --- | --- |
| `host.listRadios()`, `host.readRadio(id?)` | `requiresRadioRead` | |
| `host.setRadio({ id, selection?, … })` | `requiresRadioWrite` | 7 |
| `host.setRadioConnection({ id, selection?, connected })` | `requiresRadioWrite` | |
| `host.setRadioSpectrum({ id, selection?, mode?, spanHz?, refLevelDb?, speed? })` | `requiresRadioWrite` | 6 |
| `host.sendRadioCw`, `host.playRadioVoice`, `host.setRadioPtt`, `host.stopRadioTransmit` | `requiresRadioWrite` | 7 |
| `host.sendRadioRaw({ id, selection?, text \| bytes, replyMs?, until? })` | `requiresRadioRaw` | 11 |

## The DX cluster

Extension API 10. The app holds one connection to the node the operator
picked, logged in as the operator, and extensions share it.
[Spots](spots.md#cluster) has the hook that receives lines.

| Call | Needs |
| --- | --- |
| `host.clusterStatus()`, `host.clusterLines({ after?, limit? })`, `host.clusterSubscribe()`, `host.clusterUnsubscribe()` | `requiresClusterRead` |
| `host.clusterPostSpot({ freq, call, comment? })` | `requiresClusterSpot` |
| `host.clusterSend(command)` | `requiresClusterCommand` |

On the web build every cluster call answers `error: 'unsupported'`.

## Calling other extensions

```ts
import { hooks } from "@ham2k/extension-sdk"
const entries = await hooks.invokeForRefs("adifFields", "fieldsForOneQSO", { qso, operation }, refs)
// [{ key, ok, value | error }, …] in priority order
```

| Call | Asks |
| --- | --- |
| `hooks.invokeAll(category, method, args)` | Every hook in the category, **your own included**: a hook that delegates within its own category re-enters itself |
| `hooks.invokeOne(category, key, method, args)` | One extension's hook, by key. Prefer this over filtering `invokeAll`'s results |
| `hooks.invokeForRefs(category, method, args, refs)` | Only the extensions that answer for one of `refs`, each by its strongest `ref:` claim, plus for `adifFields` those whose manifest sets `adifFieldsScope: "always"` |
| `hooks.invokeAllSequential(category, method, initialArgs, fold)` | Every hook one at a time in priority order, threading each result into the next call's arguments |

No bridge crossing: these run inside the runtime. They are how an exporter
collects every program's ADIF fields, and how the lookup orchestrator folds
one source's answer into the next.

## The hook context

Every hook method's second argument. Fields marked `?` are absent on an app
older than the feature; call the optional reads as `ctx.getSpots?.()`.

| Field | |
| --- | --- |
| `online` | Whether the device has a network connection. For an operation without assistance, every lookup runs with it false |
| `developerMode?` | Whether developer options are on |
| `locale?` | The app's active language: `en`, `es`, … |
| `appName?` | "Ham2K Logger" on desktop, "Ham2K Portable Logger" on mobile |
| `edition?` | `dev`, `next` or `prod` |
| `distanceUnits?` | `kilometers` or `miles` |
| `decimalSeparator?`, `groupingSeparator?` | What the operator writes numbers with; [Text and locale](localization.md#numbers) |
| `dateOrder?` | `mdy`, `dmy` or `ymd`, the device's order for a numeric date |
| `gridPrecision?` | 6 or 8, how many characters the operator shows a locator with |
| `enabledExperiments?` | Keys of the experiments on for this user |
| `experiments?` | The experiment catalog: `{ key, name, aliases }[]` |
| `account?` | `{ credentials?, session? }` for an extension with an `account` hook |
| `getOperation?(uuid)` | One operation's data with `uuid` folded in, or `null` |
| `getQsos?(operationUuid)` | Every contact in the operation, oldest first, soft-deleted ones excluded, event markers (`band: 'event'`) included; `null` when the operation is unknown or the host has no log access, distinct from `[]`. Every extension reads one shared copy of the log, which asks the app only for what changed since the last read, so the whole log crosses the bridge once; each call gets a new array. From API 9 its QSOs are that shared copy, frozen: a write throws, so copy what you mean to change. Under an older `api` each call gets QSOs of its own |
| `getHistoryForCall?(call, options?)` | The most recent contacts logged with `call` across every operation, newest first, five unless `limit` says otherwise and never more than 50; `[]` for none. Options narrow before ordering: `refType` (a ref on the contact or its operation), `refPrefix` (such a ref whose code starts with it, ignoring case; with `refType`, the same ref must pass both), `refsSegmentAware: true` (read an operation's refs as they stood at each contact, so a rove's second park is seen), `operation`/`excludeOperation`, `band`/`excludeBand`, `mode`/`excludeMode` (`SSB` matches its sidebands, `CW`/`PHONE`/`DATA` their families), whole UTC days `fromDate`/`toDate`, exact instants `fromTime`/`toTime` (both also as `…Millis`); all bounds inclusive. A malformed or unknown option, or an include option with no values (`operation: []`), rejects. An older host ignores the options and answers the latest five unfiltered, so re-check on the results what you rely on; an empty answer there means none among the latest five |
| `getSpotsForCall?(call, maxAgeMinutes?)` | The spots the app already holds for `call`, newest first, no older than `maxAgeMinutes` (default 30) by the spot's own time. Reads the cache and never fetches, so it is cheap enough for a lookup |
| `getSpots?(options?)` | The spots board the app holds, never a fetch. By default the operator's own board, filtered and merged as their Spots Panel shows it, so one spot can stand for several stations (`their.call` comma-joined); `filter: 'all'` starts from every held spot, one per source report. `maxAgeMinutes`, `band`, `mode` (or a family: `SSB`, `Phone`, `CW`, `Digital`) and `source` (a source's hook key, carried on each spot as `hookKey`) narrow it. Each spot carries `annotations` (`worked`, `isSelf`, `notices`) when there is an operation to judge it against (`operationUuid`, or the hook's own `operation`); the verdicts are the ones the app already holds for the operation on screen, so the call never waits on a scorer, and another operation's spots come back unannotated rather than guessed. From API 12 each also carries `display`: `icons`, every icon the row may show as `{ icon, iconColor?, kind }` for `scoring`, `chasing` and `reference` in that order, no icon twice (the panel draws three, at least one of each kind there is); `icon` and `iconColor`, the first reference's, and all an older host sends; and `emoji`. `annotate: false` returns spots as their sources gave them. A malformed or unknown option rejects. A panel's `spots` trigger fires whenever this answer may have moved |

The log reads carry a whole log across the bridge the first time; fine when
exporting, not on a per-keystroke path. The spot reads are cheap.
