# Command & template hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `command` — call-field text shortcuts

Space in the logging panel's call field tries the typed text as a command
before falling back to "advance focus." The core does no matching itself —
it fans out to **every** registered `command` hook via `invokeHookAll` and
applies the first non-null result, in priority order.

```ts
interface CommandHook {
  interpret(
    args: { input: string; operation?; qso?; execute? },
    ctx,
  ): Promise<CommandInterpretation | null>
  catalog?(ctx): Promise<CommandCatalogEntry[]>
}
// CommandInterpretation: {expectsParams?, mixedCase?, error?, describe?, confirm?, commands?: CommandAction[]}
// CommandCatalogEntry: {command, describe, params?, category?, needsOperation?, needsTestData?, keywords?, expectsParams?, suggest?}
// CommandAction (closed set): {setVfo?, setPower?, updateQso?, addQso?,
//   setKeyerSpeed?, showKeyer?, setEnterSends?, sendSpots?, autoRespot?, syncAll?, updateSettings?, updateSetting?, openSettings?,
//   updateOperation?, markSegment?, findInLog?, navigate?, setCallField?, setTime?, reloadDataFiles?, devNotice?, devStatus?,
//   devProgress?, devHammer?, devSplash?, devOnboard?, devTester?, devPopup?,
//   devTimeTravel?, toggleExperiment?}
```

Each hook does its own matching internally and returns `null` for "not mine"
— the host never compiles extension-supplied regex source itself. A match
returns an interpretation the core previews (`describe`) and, on confirm,
applies: state changes go only through the closed `CommandAction` field set
(DESIGN.md §4's "whitelisted field-change operations"), never arbitrary
state. `expectsParams: true` is the "recognized prefix, keep typing" signal
described below.

A command that IS recognized but can't run in the current context returns
`{ error: '…' }` instead of matching silently or pretending to succeed —
e.g. the operation-scoped commands (SEED, NOTE, SPOT/SPOTLAST) typed into
the home screen's quick search, where no operation is open. The UI presents
the error message, never executes the interpretation, and leaves the typed
input in place for editing. Commands that work anywhere (DEVMODE, RELOAD,
band/frequency/mode…) never need it.

`interpret` is called on **every** keystroke pause (the call field's 150ms
typing-debounce, for the live `describe` preview), not just once when the
command actually runs — so a hook whose `commands` are expensive to build
must not compute them unconditionally. `execute: true` is the signal that
this particular call IS the one about to run the command (the host makes a
final `interpret` call with it set, right before dispatching `commands`,
discarding whatever a stale preview may have returned); it's false/undefined
on every describe-preview call. A hook with cheap `commands` can ignore this
entirely. `SEED` (below) is the one hook that needs it: skips its `ctx.getQsos`
read and per-generated-QSO lookups — real bridge/network-ish work — unless
`execute` is set, returning a cheap describe-only result otherwise.

A hook whose complete result needs a network fetch doesn't have to block
`interpret`'s own returned Promise on it — even on a describe-preview call.
Return quickly with a placeholder `describe` ("Fetching…"), kick the fetch
off in the background, and once it resolves call:

```ts
host.updateInterpretation(input: string, interpretation: CommandInterpretation): void
```

One-way, like `host.log` — no response ever comes back, nothing to await.
`input` must be the same `input` the triggering `interpret` call received;
the host discards a push whose `input` no longer matches the live call field
(the user typed past it), the same way it already discards a stale
describe-preview result. This is how `annotation-commands`' SOLAR/WEATHER
(below) show their fetched reading in the UI before the user ever presses
Enter, without either blocking every keystroke-debounce call on a live
fetch or requiring a second command invocation.

Note that only the logging panel consumes those pushes today — the ⌘K palette
and the Home search bar do not — so a hook that needs its describe on every
surface must resolve it inside `interpret` instead. `settings-commands` awaits
its host call for that reason.

A command that needs to reach the app's SETTINGS asks rather than carrying its
own list of them:

```ts
host.searchSettings({ args: string, kind?: 'set' | 'show' | 'hide' }): Promise<SettingsSearchResult>
```

`args` is everything the operator typed after the command word, whole: where
the setting's name ends and its value begins is decided app-side, because only
the settings catalog can tell `SET AVOID ZERO BEAT N` (a four-word name plus a
value) from `SET THEME DARK` (a one-word name plus a value). Matching is by
subsequence over each setting's key, aliases and label, and the catalog is
derived from the app's declarative settings registry — so it reaches every
setting the settings screen would currently show, and only those (`devMode`,
`environment` and `visibleWhen` all apply). The result carries the setting's
label, section, current value and the coerced new value, each already
localized; a `secret` field's value is never included. Write the result back
with the `updateSetting` action, or open the settings form with `openSettings`.

The actions that change the app's own settings — `updateSetting`,
`updateSettings`, `toggleExperiment`, `setEnterSends`, `setKeyerSpeed` and
`showKeyer` — run only for an extension whose manifest sets
`"requiresSettingsWrite": true`, which the install screen shows the operator;
`setPower` needs `requiresRadioWrite`; and the developer actions (`dev…`,
`reloadDataFiles`) run only for the app's own extensions. A command carrying
an action its extension may not run is refused before it runs, and the
command bar says so.

This call re-enters the extension runtime while the calling hook is still
awaiting it (reading every `settingsPanel` is part of building the catalog).
That is safe by construction — hook calls are keyed by id with independent
completers and no lock — but it is the only host call that does so, and any
new one that re-enters should say so here.

Implemented by `radio-commands` (band/frequency/mode shortcuts — "20m ",
"14285 ", "14.285 ", "cw "), ported from app-polo's `RadioCommands`
extension. Notably, this replaced an earlier hand-rolled Dart regex for
frequency parsing that rejected valid MHz-style input ("14.285") because it
required 3+ digits before any decimal point; the extension delegates to
`@ham2k/lib-format-tools`' published `parseFreq` instead, which already
handles this correctly. Also implemented by `dev-commands` (DEVMODE toggles
developer mode; DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the
status bar via the `devNotice`/`devStatus`/`devProgress` action fields, for
exercising that UI without a real extension driving it; DEVHAMMER
(`devHammer`) churns the footer the way a data-file sync does — items
appearing, ticking and clearing — which is what provokes the web engine into
blurring a focused text field, and which the real thing only does on a cold
profile; DEVSPLASH re-shows
the startup release-notes overlay (Issue #42) via the `devSplash` action
field, bypassing its normal once-per-version gate — for previewing that
overlay on demand instead of only once per release; RELOAD forces a
`dataFile` re-sync via the `reloadDataFiles` action field — "RELOAD POTA"/
"RELOAD SOTA" target one activity's data file(s) by category, "RELOAD ALL",
"RELOADALL", or bare "RELOAD!" target every data file, and it bypasses ETag caching
since a manual reload is usually about our own `csvToLookupEntry` mapping
changing, not the source data; SEED fills the current log with generated
QSOs via `addQso` actions — "SEED" adds 10, "SEED 20" adds 20, "SEED 15 3H"
spreads 15 over the 3 hours up to now, or over the 3 hours *ending at the
earliest existing QSO* when the log's own time span is under a third of
that spread. Calls come from the Callsign Notes data — call-notes exposes
its parsed index to other extensions through an in-runtime `callNotes`/
`allCalls` hook — and are mutated 80% of the time by swapping the digit or
a suffix letter; RSTs lean heavily toward 55/57/59; each generated QSO gets
the lookup service's offline `their.guess` decoration. The placement rule
needs the existing log: SEED reads it through `ctx.getQsos`, using the
`uuid` the logging panel folds into the `operation` map it passes to
`interpret`; EXP toggles an experimental feature via the `toggleExperiment`
action field — the hook parses "EXP <key-or-alias>" and resolves the token
against `ctx.experiments` only for its preview ("Enable"/"Disable"); the app
resolves it again when it flips the state and reports the outcome, since the
stored per-experiment state lives app-side;
LANG `<code>` switches the app's language — hidden locales (CW, QRP, QRO)
included, "LANG SYSTEM" back to the device's — with a plain `updateSetting`
on the `locale` field, which refuses a code the app has no strings for;
DEVTT/DEVTIMETRAVEL move the app clock via the `devTimeTravel` action field —
"DEVTT +3h", "DEVTT -1d", "DEVTT 2x", bare "DEVTT" to return to real time — so
anything that turns on the date or on elapsed time can be tested without
waiting for it. The hook only parses, and only while developer mode is on; the
app applies the offset, refuses it against a real sync account, and reports the
resulting time. Deliberately the one command here with NO `catalog`, so it can
never surface in the palette (docs/design/time.md)),
`annotation-commands` (ham2k/halo-dist#64, ported from
app-polo's AnnotationCommands: NOTE/TODO `<text>`, SOLAR, and WEATHER each
add an annotation row to the log — an event pseudo-QSO, `band: 'event'`,
via `addQso`, rendered as a yellow row by the QSO list. SOLAR fetches
hamqsl.com's solar indices and WEATHER fetches Open-Meteo conditions for
the operation's grid square — as soon as the command is recognized
(ham2k/halo-dist#189), not only at `execute`: `interpret` kicks the
fetch off in the background and returns a placeholder `describe`
immediately, then pushes the resolved reading via `host.updateInterpretation`
once it lands, so it shows in the UI before the user presses Enter. One
in-flight fetch is shared by every `interpret` call for the same command
until an `execute` call consumes it (reusing the same reading rather than
fetching twice) and clears it, so the next SOLAR/WEATHER starts fresh. The
raw readings land in the logged event's `data` and the emoji summary line
in its `description`. This superseded the original `note-command`
extension, whose NOTE wrote to the in-progress QSO's notes field instead of
the timeline), and `call-notes` (`//KEY`
expands a Callsign Notes entry whose note — once a leading heading OR emoji
marker (never both) is stripped — is a plain comma list of calls into the
call field via `setCallField` — issue #17; the call field explicitly excludes a field
STARTING with "//" from call stacking, or a note key that's itself a valid
callsign would also read as a stacked call, so the two syntaxes coexist. A key
stacked ALONGSIDE other calls reaches this hook too, but never as a whole-field
command: the call field asks again with just the segment under the cursor
("//1AB") and splices the answer back into that segment, so the hook itself
needs to know nothing about stacks. See
[logging-fields.md](../design/logging-fields.md) § "More than one call in the
field" for the order Enter resolves the two syntaxes in).
Future command hooks (spotting, operator change…) register in the same
category and compete on priority with these.

### `catalog` — advertising commands to the ⌘K dialog

`interpret` answers *"what does this exact text mean?"* — one answer, for
text the user has already typed. The command dialog (⌘K, issue #55) needs the
other direction: *"what commands exist?"*, so it can list them before the
user knows the syntax. That's the optional `catalog(ctx)`, returning one
entry per command:

```ts
{ command: 'NOTE', params: '<text>', describe: 'Add a note to the log',
  category: 'Log annotations', needsOperation: true, expectsParams: true }
```

`command` is both what the palette matches against and what it types into the
field when the entry is chosen, so it has to be something `interpret`
recognizes. `params` is display-only. `describe` may use inline markdown
(`**bold**`, `*italic*`, `` `code` ``), the same as `interpret`'s own
`describe`/`confirm` — the dialog renders it as one ellipsized line rather
than as blocks, so keep it to a single sentence. `needsOperation` drops the row entirely when
no operation is open, instead of letting the user pick it and get
`interpret`'s `error` back. `expectsParams` leaves the field open for typing
rather than running the command immediately — the catalog counterpart of
`CommandInterpretation.expectsParams`, and the reason picking NOTE doesn't
log an empty note. `suggest` opts the entry into the empty-field "Try"
samples shown while the dialog is new; it's opt-in on purpose — the samples
go to users who don't yet know what a command does, so anything destructive,
heavyweight or developer-only must stay out. Absent means listed and
searchable, never volunteered.

Three things differ from `interpret`, all deliberate:

- **Called once and cached**, not per keystroke — dropped when the runtime is
  replaced (an extension enabled/disabled) or the hook context is
  invalidated (locale change, since `describe` is localized by the hook).
- **Matching is host-side**, case-insensitive, at the start of a word in
  `command` or in `keywords` — never mid-word, and `describe` is never
  searched. Every word that should find a command belongs in its
  `keywords`: the aliases it accepts when typed, and plain words for what it
  does. Same rule `interpret`'s own matching follows: the host never
  compiles extension-supplied patterns.
- **List commands, not variants.** `radio-commands` advertises one BAND
  entry, not fifteen; `call-notes` advertises `//`, not every key the user
  has defined.

A hook without `catalog` contributes nothing to the palette's suggestions and
still works fine when its commands are typed in full — that's why it's
optional. `dev-commands` uses `ctx.developerMode` to keep DEVMODE, SEED and
friends out of the list unless developer mode is on (RELOAD, being genuinely
user-facing, is always listed); the commands themselves still run either way.

A command that recognizes its own prefix but needs more typed input before
it can run (e.g. bare "RELOAD", before its target word) returns
`{ expectsParams: true }` instead of `null` or a full result. That switches
the call field to free-text entry — spaces allowed, no callsign character
restriction — and space no longer advances focus to the next field while
it's set; the interpretation is never executed even if Enter is pressed
while it still just says `expectsParams`. The field stays uppercase-only
(all logging input is uppercase unless explicitly mixed-case) unless the
interpretation also says `mixedCase: true` — for commands whose parameter
is free prose (NOTE's text), which lifts the uppercase rule. Return
`mixedCase` on both the bare-prefix result and the complete result, so
continued typing after the command is already complete ("NOTE Hello…")
isn't snapped back to uppercase. `mixedCase` is also what keeps Space a
literal character once a command is *already complete* — `expectsParams`
can't, since it also blocks execution — which is why SEED returns it on
every result despite its parameters not being prose: bare "SEED" must be
executable (default count) yet still extendable to "SEED 15 3H".

## ✅ `template` — rendering on the app's behalf

The Liquid renderer (templates.md) lives in the SDK and runs only inside the
extension runtime. A Dart-side surface that wants a template filled in — a
CW message about to be keyed (docs/design/cat.md § CW keying) — reaches it
through this hook, registered once by the core `templates` extension under
the key `templates`:

```ts
interface TemplateHook {
  render(
    args: { template: string; operation?; qso?; next?; qsoCount?: number },
    ctx,
  ): Promise<{ text: string } | { error: string }>
  // Several templates against one context in one crossing (the keyer
  // area's button labels): one result per template, in order.
  renderMany(
    args: { templates: string[]; operation?; qso?; qsoCount?: number },
    ctx,
  ): Promise<{ results: ({ text: string } | { error: string })[] }>
}
```

`operation` and `qso` are the same objects a `panel` hook's `render` gets —
`next`, the contact up next beside one just logged, is a draft `qso` too —
and the result is built with the same `templateContext`, so a placeholder
means the same thing wherever the app renders it. A template that does not
parse comes back as `error` carrying the renderer's own message — a typo in
a message the operator typed, to show them, not a bridge failure to report.
The app calls them as `ExtensionService.renderTemplate` and `renderTemplates`.
