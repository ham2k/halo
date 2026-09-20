# Templates

One templating engine for every place HaLo turns log data into text: a
panel's document, an export's filename, an ADIF field. One vocabulary too —
`{{ op.station }}` means the same thing wherever it appears.

The engine is **[Liquid](https://liquidjs.com)** (`liquidjs`), a kernel
shared module wrapped by `sdk/src/templates.ts`. Everything goes through that
wrapper: it owns the option set, and a second engine built elsewhere would
disagree about timezones without anyone noticing.

```ts
import { renderTemplate, templateContext, triggersForTemplate } from "@ham2k/extension-sdk"

const text = renderTemplate("{{ op.station }} — {{ op.qsoCount }} QSOs", templateContext({ operation, qsoCount }))
```

## Why Liquid rather than app-polo's Handlebars

A template is DATA. Liquid parses and interprets; Handlebars compiles
through `new Function`. These templates are written by operators, copied
between operators, and are editable in settings, so the one
that cannot become code is the one to have. Liquid also has comparisons
(`{% if op.qsoCount > 100 %}`) and loops built in, where Handlebars needs a
registered helper for `>` and Mustache cannot compare at all.

Measured in the shipped QuickJS-NG build: 80 KB minified (24 KB gzipped),
6 ms to evaluate at startup, 0.33 ms per parse+render of a small template —
and parsed templates are cached, so repeated renders of one document cost
about 2 µs each.

**Porting from PoLo**: the plain majority of polo's templates —
`{{ op.date }} {{ log.station }} at {{ log.ref }}` — parse unchanged, because
the namespaces are deliberately polo's. The syntax around them does not:
`{{#if}}` is `{% if %}{% endif %}`, `{{#each}}` is `{% for %}{% endfor %}`,
`{{> Partial}}` has no equivalent, and helpers are filters
(`{{ dash x }}` → `{{ x | dash }}`). polo's
`{{#join op.refs separator=", " final=" & "}}{{or shortLabel label key}}{{/join}}`
is `{{ op.refs | refLabels | sentence }}`.

## What a template can name

| namespace | panel `render` | export filename | ADIF fields | CW message |
|---|---|---|---|---|
| `app` | ✓ | — | ✓ | ✓ |
| `now` | ✓ | ✓ | ✓ | ✓ |
| `op` | ✓ | ✓ | ✓ | ✓ |
| `qso` | when the placement's triggers ask for it | — | ✓ | the draft contact, as far as it is typed |
| `config` | ✓ | — | — | — |
| `log` | — | ✓ | ✓ | — |

A namespace a surface has nothing for is **absent**, not blank — which is
what makes `{% if qso %}` an honest question. Registered exports get the operation plus the selected file’s `log` values.
The low-level `exportFilename(parts)` helper still supplies only dates and
filename parts.

### `app`
`app.name` — the platform-appropriate name ("Ham2K Logger" on desktop,
"Ham2K Portable Logger" on mobile).

### `now`
An ISO-8601 UTC string, for the `date` filter: `{{ now | date: '%H:%M' }}`.

### `op` — the operation
`station` (the field as typed, which may hold several comma-separated
callsigns; `call` is the same value, the name `qso.call` has), `stations`
(that list, uppercased and deduped), `operator`,
`title` (the generated, ref-derived one), `userTitle` (the operator's own
words), `grid`, `refs`, `uuid`, `qsoCount`, `date`, `dateCompact`, `time`,
`at`, `startDate`, `startTime`, `startAt`, `endDate`, `endTime`, `endAt`.

`endDate` / `endTime` / `endAt` are the LAST CONTACT'S START — an operation
row records when its final QSO began and not when it ended, so a template
printing `{{ op.startTime }}–{{ op.endTime }}` understates the session by
that contact's length.

### `qso` — one contact
`call`, `their`, `our` (both whole, so `qso.their.guess.name` reaches the
lookup's answer), `band`, `mode`, `freq`, `rstSent`, `rstRcvd`, `serialSent`,
`serialRcvd`, `notes`, `date`, `dateCompact`, `time`, `at`, `startAtMillis`,
`refs` — and two short forms for the sent side, `rst` (= `rstSent`) and
`serial` (= `serialSent`), since a CW message is what we send and that is
where these get typed: `{{ qso.call }} {{ qso.rst | cut }} {{ qso.serial | pad: 3 | cut }}`.

`rstSent` is what WE sent — QSON stores each side's report under its own
`sent`, and these are named for the operator's view of the contact.

`serialSent` / `serialRcvd` are a contest's serial numbers, blank outside
one. A contest keeps them on its own ref, so they are found by field name —
the first ref carrying `ourSerial` / `theirSerial` — which is what lets one
message serve every serial contest (docs/design/contests.md §5.8). In a CW
message `serialSent` is the number the serial field is SHOWING, the one the
QSO will be logged with. It is unpadded (`7`, not `007`): use `pad`.

### `config` — a panel's own form values
Whatever that panel's `form` declared, under the keys it used.

### `log` — one export
`station`, `ref`, `refName`, `refShortName`, `activity`, `handlerName`,
`handlerShortName`, `format`, `exportType`, `modifier`, `extension`,
`compact`.

## Timestamps

Two forms, and the rule is worth learning once:

- **`…At` fields are ISO-8601 UTC strings** — feed these to the `date`
  filter: `{{ qso.at | date: '%H:%MZ' }}`.
- **`date` / `dateCompact` / `time` are preformatted UTC** —
  `2026-07-27`, `20260727`, `1430`.

Everything is UTC. A log is kept in UTC, and a filename that shifted with
the reader's zone would name the wrong day.

**`op`'s dates can be empty.** `startAtMillisMin`/`startAtMillisMax` are
columns on the operation row, not keys in the QSON `data` a hook is handed,
so they arrive only where the caller adds them: the panel host does, and the
ADIF export passes the first QSO's time instead. Where neither happens,
`op.date` and the `start…`/`end…` fields render empty rather than falling
back to today — a pane showing yesterday's log must not print today's date
with nothing to say it was invented.

## Filters

All of Liquid's own (`date`, `downcase`, `upcase`, `strip`, `default`,
`join`, `size`, `first`, `last`, `round`, `truncate`, `replace`, `map`,
`where`, …), plus six:

| filter | does | example |
|---|---|---|
| `dash` | non-alphanumerics → `-`, collapsed and trimmed, **case preserved** | `N0CALL/P` → `N0CALL-P` |
| `alnum` | strip to alphanumerics | `2026-07-27` → `20260727` |
| `pad: n` | zero-pad on the left to `n` characters (default 3); **blank stays blank** | `7` → `007` |
| `cut: "digits"` | CW cut numbers for the listed digits, of `0`→`T` `1`→`A` `5`→`E` `9`→`N`; default `"09"` | `599` → `5NN`, `{{ 9 \| pad: 3 \| cut }}` → `TTN` |
| `refLabels` | a list of refs → each one's `shortLabel`, else `label`, else `ref`; a ref with none of them is skipped — an operation's contest ref HAS a label (`CQ WPX CW`) and is listed | `op.refs` → `POTA US-1234`, `KFF-9999` |
| `sentence: "sep", "final"` | joins a list with a different LAST separator (defaults `", "` and `" & "`); blanks are dropped | `A, B & C`, `A & B` |

`pad` leaves a blank alone because a CW message can be keyed before the
serial field has a number, and `000` sent in that gap is a serial the log
will never agree with. Order matters with `cut`: pad first, or the padding
zeros go out uncut.

`refLabels` exists because `map` reads one field: `map: "shortLabel"` drops a
reference that resolved to nothing, since it carries no labels — an
operation at an unlisted park would print as though it had none. Liquid's own
`array_to_sentence_string` is the near miss for `sentence`: it always writes
the serial comma (`A, B, & C`).

`alnum` is app-polo's `compact` helper under a different name: Liquid already
has a `compact` (it drops nils from an **array**, and `op.refs`/`qso.refs` are
arrays), and `registerFilter` overwrites without warning, so taking that name
would silently break templates written against Liquid's own documentation.

`dash` keeps case because callsigns and references are written in capitals
and stop being legible flattened. For free text, `{{ x | downcase | dash }}`
is the slug form.

## Traps

Each of these was measured against the shipped runtime, not assumed.

**An empty string is TRUE.** In Liquid only `nil` and `false` are falsy, so
`{% if log.modifier %}` fires on `""`. Ask for blankness explicitly:
`{% if log.modifier != blank %}`.

**A raw millisecond timestamp is not a date.** The `date` filter reads a
number as SECONDS, so epoch millis render in the year 58567. Use the `…At`
strings.

**`cut`'s digit list must be quoted.** Liquid reads a bare `0159` as the
number 159 before the filter sees it, so `{{ n | cut: 09 }}` cuts only the
nines — the zero is gone with no error. Write `cut: "09"`.

**Unknown names are silent.** An unknown variable renders empty and an
unknown filter passes its value through. That is deliberate — an operator's
typo costs one line, not the document — but it means a misspelled
`{{ op.stationCall }}` looks like missing data rather than a mistake.

**Text written before templating existed can lose a span.** `{{ TODO }}` in
an old note is a perfectly valid reference to a variable that doesn't exist,
so it renders as nothing at all rather than as an error — the note quietly
comes back a few words shorter. Only clearly broken syntax (`{% if` with no
`{% endif %}`) reports itself; `custom-text` then shows the message with the
operator's own text intact below it, because a pane that answered by
deleting what somebody wrote would be the worse failure.

**Literal braces need `{% raw %}`.** That is also the fix for the case
above: wrap the passage and it renders as typed.

**`{% include %}` throws.** There is no filesystem in the runtime. Partials
would have to be supplied in memory.

**Loops are bounded by time, not by iterations.** A render is abandoned
after 250 ms with a `TemplateError` naming the limit.

## Errors

`renderTemplate` throws `TemplateError`, carrying Liquid's own message with
the line and column. It does not fall back: a broken template is either an
operator's typo, which they can only fix if they are told, or a bug in one
of ours, which tests should catch. Where the template is the operator's,
show them the message — `custom-text` renders it in the pane.

## Panel triggers

`triggersForTemplate(text)` reports which panel triggers a template needs,
derived from the namespaces it names: `qso` → `qso` + `lookup`, `qsoCount` →
`qsoLogged`, `op` → `operation`, `now` → `tick:30`. A panel rendering
operator-written text passes these back as `PanelContent.triggers`
(hooks.md, `panel`), so each pane pays only for what its own text asks for.

Only `{{ … }}` and `{% … %}` spans are read, never the prose around them —
"Goal: 100 qso today" is a note, not a request to be woken per keystroke.
Inside a span it is deliberately generous: `{% if qso %}` counts as naming
the QSO, since a false negative shows stale text with no clue why.

`now` is refreshed on a **30-second** tick, so `{{ now | date: '%H:%M:%S' }}`
will jump rather than count. Show HH:MM.

## Where templates are used today

| what | where | editable |
|---|---|---|
| Panel documents | `custom-text`'s content and tab name | by the operator, in the panel's config form |
| Export filenames and titles | Registered export types and `sdk/src/exportSettings.ts` | Settings → Exports, globally and per type |
| ADIF NOTES / COMMENT / QSLMSG | Export type settings, consumed by `core/adif` | Settings → Exports; empty templates suppress a field |
| CW messages | Radio settings `cwMessage1..8`, keyed on F1-F8 through the radio (docs/design/cat.md § CW keying) — rendered by the `template` hook (hooks.md) | by the operator, in the Station dialog's Messages… dialog |

NOTES and COMMENT default to QSO notes and are withheld when private data
is off. QSLMSG defaults to empty for program exports, and for the whole-log
ADIF to the operation’s references as `refLabels | sentence` names them —
“POTA US-0001 & WWFF KFF-0002”. Custom QSL messages may use contact values.
Templates receive no withheld private or lookup values. File titles obey the
private-data choice; filename templates are labels for the operator’s files.

The `textTemplate` form field provides sample previews and an insertable
reference; see [forms.md](forms.md). Invalid Liquid reports an error rather
than silently replacing the operator’s template with a default.
