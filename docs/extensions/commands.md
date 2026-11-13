# Commands & templates

A command is text the operator types into the call field: `20m`, `14.285`,
`NOTE lunch`, `SPOT`. Space tries the field's text as a command before it
advances focus; the ⌘K palette lists the commands that exist. `template` is
the hook through which the app renders Liquid templates, registered by the
app's core; it is documented so you know how a template you hand the app is
filled in. `keyerSets` offers the keyer sets of those templates. [How hooks work](hooks.md) covers registration, keys, priority
and `ctx`.

## `command`

**For:** a shortcut the operator types: a radio setting, a note on the
timeline, a spot, a lookup, a settings change.

**Called:** every registered hook, in one round trip, on **every pause in
typing** (150 ms) for the live preview, and once more with `execute: true`
right before the command runs. The app applies the first non-null answer in
priority order.

```ts
interface CommandHook {
  interpret(args: { input: string; operation?; qso?; execute? }, ctx): Promise<CommandInterpretation | null>
  catalog?(ctx): Promise<CommandCatalogEntry[]>
}
// CommandInterpretation: { expectsParams?, mixedCase?, error?, describe?, confirm?, commands?: CommandAction[] }
// CommandCatalogEntry:   { command, describe, params?, category?, needsOperation?, needsTestData?, keywords?, expectsParams?, suggest? }
```

### Interpreting

Each hook does its own matching and returns `null` for "not mine". The app
never compiles a pattern an extension supplies. A match returns an
interpretation the app previews (`describe`, inline markdown), optionally
confirms (`confirm`), and on Enter applies through `commands`.

**State changes go only through `CommandAction`**, a closed set of fields;
never arbitrary state:

| Action | Does | Needs |
| --- | --- | --- |
| `setVfo`, `setPower`, `swapRadios` | tunes the radio, sets its power, trades SO2R's Radio A and Radio B (frequency, mode, Run or S&P, each set's entry, and on two slices of one radio their antennas) | `setPower`, `swapRadios`: `requiresRadioWrite` |
| `updateQso`, `addQso` | changes the draft contact, adds a record to the log (an event row, `band: 'event'`, is how a note lands on the timeline) | |
| `updateOperation`, `markSegment` | [changes the open operation](#updating-the-open-operation), marks a break | |
| `setCallField`, `findInLog`, `navigate`, `openSettings` | moves the operator somewhere | |
| `sendSpots`, `autoRespot`, `syncAll`, `setTime` | the app's own actions; `sendSpots` with a `source` posts only to the spot sources whose hook key carries that word (`pota` for `ham2k-pota`), the app's preview names them, and a word no source carries is refused | |
| `updateSetting`, `updateSettings`, `toggleExperiment`, `setEnterSends`, `setOpStyle`, `setKeyerSpeed`, `showKeyer` | changes the app's own settings; `setOpStyle` (API 19) is `{ opStyle: 'run' \| 'normal' }`, the operating style of the set the operator is in | `requiresSettingsWrite` |

A command carrying an action its extension may not run is refused before it
runs, and the command bar says so. The developer actions (`dev…`,
`reloadDataFiles`) and the app's own upkeep (`updateDataFiles`, `updateApp`,
`updateExtensions`) run only for the app's own extensions.

**Rules of the field:**

- **Recognized but cannot run here** answers `{ error: "…" }`, never a
  silent null and never a pretend success: an operation-scoped command typed
  into the home screen's search, where no operation is open. The app shows
  the message and leaves the text in place.
- **`expectsParams: true`** says "recognized prefix, keep typing": the field
  switches to free-text entry (spaces allowed, no callsign restriction),
  Space stops advancing focus, and the interpretation is never executed
  while it still only says this.
- **`mixedCase: true`** lifts the field's uppercase rule, for a parameter
  that is prose. Return it on both the bare-prefix answer and the complete
  one, or continued typing snaps back to uppercase. It is also what keeps
  Space a literal character once a command is complete and executable, which
  `expectsParams` cannot do since it also blocks execution.
- **`interpret` runs on every pause.** A hook whose `commands` are expensive
  to build must not build them unconditionally; `execute: true` marks the
  one call that is about to run, so a hook that reads the log through
  `ctx.getQsos` does so only then.

### Updating the open operation

Return `updateOperation` in a command action to edit the operation where
the operator runs the command. The app supplies the target from the
command's context. A [panel event](scenes.md#events-and-results) can return
the same `OperationSetupPatch` (extension API 26).

- `addActivationRefs` (extension API 26) takes `{ activityKey, ref }`
  entries for activities with an activation `refList` control. Use an
  activity's short key such as `pota` or its extension key such as
  `ham2k-pota`, as in an `/operation?our.refs=` link. The app applies the
  program's [reference rules](activities.md#controls), keeps the existing
  activities and their settings, and skips a reference already on the
  operation. A different reference for a single-reference program is a
  conflict.
- `location` (extension API 26) takes a Maidenhead `grid` or both `latitude`
  and `longitude` in decimal degrees. The app measures from the center of
  a supplied grid. A stated location takes precedence over the location
  derived from activation references. Either form accepts optional `state`
  and `county` strings.
- `userTitle` and `notes` (extension API 26) set the operation's title and
  notes. Omit these fields, `state`, or `county` to keep their current
  values. An empty string clears the supplied field.
- `operatorCall` sets the operator callsign, shared for the current station
  position. `multiIdentifier` sets this device's station position locally.
  If you supply both, the callsign applies to the supplied position. An
  empty string clears either field.

The app validates the whole patch before saving it. An invalid reference,
unavailable program, or single-reference conflict identifies the entry in
the error and leaves the operation as it was.

### Answering later

A hook whose answer needs a network fetch need not block `interpret` on it.
Return a placeholder `describe` at once, start the fetch, and when it lands
call

```ts
host.updateInterpretation(input, interpretation)
```

One-way, like `host.log`. `input` must be the same string the triggering
`interpret` received; the app discards a push whose input no longer matches
the live field. Share one in-flight fetch across the `interpret` calls for
the same command until the `execute` call consumes it. Only the logging
panel's field consumes these pushes; the palette and the home search do not,
so a hook that needs its description on every surface resolves it inside
`interpret`.

### Reaching the app's settings

A command that changes a setting asks the app rather than carrying a list:

```ts
const found = await host.searchSettings({ args: "AVOID ZERO BEAT N", kind: "set" })
if (!found.found) return null
if (found.ambiguous || found.simple === false) return { describe: `Open ${found.label}`, commands: [{ openSettings: { key: found.key } }] }
return { describe: `Set ${found.label} to ${found.newValueLabel}`, commands: [{ updateSetting: { key: found.key, value: found.newValue } }] }
```

`args` is everything typed after the command word; the app decides where the
name ends and the value begins, matching by subsequence over each setting's
key, aliases and label across the settings the Settings screen shows right
now. The result carries the setting's label and section, the current value
as `valueLabel`, and the coerced new value as `newValue` with its
`newValueLabel`, all localized; a secret's value is never included. Several
matches come back `ambiguous` with `candidates`, and a setting that wants
its own form comes back `simple: false`; both are for `openSettings` rather
than `updateSetting`. [The host API](host.md#hostsearchsettings-args-kind-)
has every field.

### `catalog`

`interpret` answers "what does this text mean"; the ⌘K palette needs "what
commands exist". `catalog` returns one entry per command:

```ts
{ command: "NOTE", params: "<text>", describe: "Add a note to the log", category: "Log annotations", needsOperation: true, expectsParams: true }
```

- `command` is what the palette matches against and what it types into the
  field when chosen, so it must be something `interpret` recognizes.
  `params` is display only. `describe` is one ellipsized line of inline
  markdown.
- **Called once and cached**, dropped when the runtime restarts or the locale
  changes.
- **Matching is the app's**, case-insensitive, at the start of a word in
  `command` or `keywords`, never mid-word and never in `describe`. Every word
  that should find a command goes in `keywords`: the aliases it accepts and
  plain words for what it does.
- **List commands, not variants**: one `BAND` entry, not fifteen.
- `needsOperation` drops the row when no operation is open; `expectsParams`
  leaves the field open for typing rather than running at once; `suggest`
  opts the entry into the "Try" samples shown to someone new, so anything
  destructive, heavyweight or developer-only stays out. A hook without
  `catalog` works when its commands are typed in full and offers nothing to
  the palette. Use `ctx.developerMode` to keep developer commands out of the
  list.

**Examples:** `ham2k-satellites` and `ham2k-call-notes` in
[ham2k/extensions](https://github.com/ham2k/extensions). The app's own
command sets show the shapes: band, frequency and mode shortcuts; `NOTE`,
`SOLAR` and `WEATHER`, which add an event row to the timeline and fetch
their reading while the operator is still typing; `SET`, `SHOW` and `HIDE`,
which search the settings.

## `template`

**For:** rendering a Liquid template on the app's behalf, where the app's
own code holds the template: a CW message about to be keyed, the keyer
area's labels.

**Called:** one hook, the one the app's core registers under the key
`templates`. You do not implement it; an extension renders its own
templates through the SDK's `renderTemplate` ([Templates](templates.md)).

```ts
interface TemplateHook {
  render(args: { template: string; operation?; qso?; next?; qsoCount?: number }, ctx): Promise<{ text: string } | { error: string }>
  renderMany(args: { templates: string[]; operation?; qso?; qsoCount?: number }, ctx): Promise<{ results: ({ text: string } | { error: string })[] }>
}
```

`operation` and `qso` are the same objects a panel's `render` gets, and
`next` is the contact up next beside one just logged. The context is built
with the same `templateContext`, so a placeholder means the same wherever
the app renders it. A template that does not parse comes back as `error`
carrying the renderer's message, which is a typo of the operator's to show
them, not a failure to report.

## `keyerSets`

**For:** message sets the operator can pick for the keyer: a contest's
exchange laid out on the function keys, an activity's CQ. Extension API 21.

**Called:** every hook, each time the extensions activate. Answer what does
not change while the runtime runs.

```ts
interface KeyerSetsHook {
  getSets(args: {}, ctx): Promise<KeyerSet[]>
}

type KeyerSet =
  | { kind: "cw"; id: string; name: string; messages: string[]; labels?: string[] }
  | { kind: "voice"; id: string; name: string; templates: string[]; labels?: string[] }
```

Your sets are listed in the set picker under **Extensions**, in a folder
named for your extension. The operator picks one as they pick their own,
and cannot change it: they duplicate it to make a copy of their own to
edit. A `cw` set's `messages` and a `voice` set's `templates` are
[templates](templates.md), up to eight each, F1 first; a missing one is
empty. A voice set has no recordings, so its messages are said in the
operator's recorded words, and only when the operator has phone messages
said with words.

A set's `id` is yours to choose, without a `:`, and each kind has its own:
a `cw` set and a `voice` set may share one. Keep it from one version to the
next. The operator's pick is
stored by it, so a set whose `id` changes is no longer picked, and the keys
go back to the operator's first set. They do the same while your extension
is disabled, and come back to your set when it is enabled again, unless the
operator changed their own sets in the meantime.

A set that is not one of these shapes is left out and reported against your
key; your other sets are still offered.
