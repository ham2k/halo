# Templates

One templating engine for every place the app turns log data into text: a
panel's document, an export's filename, an ADIF field, a CW message. One
vocabulary too: `{{ op.station }}` means the same thing wherever it appears.

The engine is [Liquid](https://liquidjs.com), `liquidjs`, which the app
carries and every bundle reaches through the SDK's wrapper:

```ts
import { renderTemplate, templateContext, triggersForTemplate } from "@ham2k/extension-sdk"

const text = renderTemplate("{{ op.station }} — {{ op.qsoCount }} QSOs", templateContext({ operation, qsoCount }))
```

Always go through the wrapper rather than constructing a `Liquid` of your
own: it owns the options, and UTC is one of them. Liquid because a template
is **data**. It parses and interprets rather than compiling to code, which
matters for text operators write, copy from each other and edit in
Settings; and it has comparisons and loops built in.

## What a template can name

| Namespace | Panel `render` | Export filename | ADIF fields | CW message |
| --- | --- | --- | --- | --- |
| `app` | ✓ | | ✓ | ✓ |
| `now` | ✓ | ✓ | ✓ | ✓ |
| `op` | ✓ | ✓ | ✓ | ✓ |
| `qso` | when the placement's triggers ask for it | | ✓ | the draft, as far as it is typed; in the thanks after logging, the contact as logged |
| `next` | | | | the thanks after logging only |
| `config` | ✓ | | | |
| `log` | | ✓ | ✓ | |
| `keyer` | | | | ✓, and the keyer area's labels |

A namespace a surface has nothing for is **absent**, not blank, which is what
makes `{% if qso %}` an honest question.

### `app`

`app.name`: the app's name on this platform.

### `now`

An ISO-8601 UTC string, for the `date` filter: `{{ now | date: '%H:%M' }}`.
On a panel it is refreshed on a 30-second tick, so show minutes, not
seconds.

### `op`, the operation

`station` (the field as typed, which may hold several comma-separated
callsigns; `call` is the same value), `stations` (that list, uppercased and
deduplicated), `operator` (who is at the key on this device, empty when
nobody is named), `title` (the generated, reference-derived one),
`userTitle` (the operator's own words), `grid`, `refs`, `uuid`, `qsoCount`,
`date`, `dateCompact`, `time`, `at`, `startDate`, `startTime`, `startAt`,
`endDate`, `endTime`, `endAt`.

`endDate`, `endTime` and `endAt` are the **last contact's start**: an
operation records when its final contact began, not when it ended.

The `start…` and `end…` values, and `op.date`, are empty where the caller
did not supply the span: a panel's render and an export have it; a surface
that does not renders empty rather than inventing today's date.

### `qso`, one contact

`call`, `fullCall`, `partial`, `nextCall`, `nextPartial`, `state`, `name`,
`their`, `our` (both whole, so `qso.their.guess.name` reaches the lookup's
answer), `band`, `mode`, `freq`, `rstSent`, `rstRcvd`, `serialSent`,
`serialRcvd`, `notes`, `date`, `dateCompact`, `time`, `at`, `startAtMillis`,
`refs`, and two short forms for the sent side, `rst` and `serial`, since a
CW message is what we send: `{{ qso.call }} {{ qso.rst | cut }} {{ qso.serial | pad: 3 | cut }}`.

- In a draft, **`call` is one call, read at the cursor**, not the field as
  typed. On a `//` stack it is the call Enter logs, or, when there is none,
  the partial under the cursor, or the nearest one beside it when the cursor
  sits in an empty segment a just-typed `//` opened; in a comma list, where
  Enter logs every call, it is the one the cursor is on. `their.call` stays
  the field as typed. On a stack, `nextCall` is the call the Enter after this
  one would log and `nextPartial` the last entry left in the field once this
  one logs, usually the call still being copied: with `KN2//KI2D//NK2Y//FR`
  and the cursor at the end, `call`, `nextCall` and `nextPartial` are `NK2Y`,
  `KI2D` and `FR`; with the cursor on `KI2D`, they are `KI2D`, `NK2Y` and
  `FR`. Both are empty outside a stack and on a logged contact.
- `call` may be a partial still being copied, right for asking it back
  (`{{ qso.call }}?`) and wrong for answering it. `fullCall` is `call` when
  it reads as a callsign and blank otherwise; `partial` is the reverse;
  exactly one of them is `call`, so a message can branch:
  `{% if qso.fullCall != blank %}…{% elsif qso.partial != blank %}{{ qso.partial }}?{% endif %}`.
  A logged contact's call is always a `fullCall`.
- `state` and `name` are what was typed, else what the lookup found, and
  `name` is only the first word, since `GM {{ qso.name }}` is a greeting.
  The whole name is `qso.their.name` or `qso.their.guess.name`.
- `rstSent` is what we sent. `serialSent` and `serialRcvd` are a contest's
  serials, blank outside one, found by field name on the first ref carrying
  `ourSerial`/`theirSerial`; in a CW message `serialSent` is the number the
  serial field is showing, unpadded (`7`, not `007`): use `pad`.

### `next`, the contact up next

Only in the thanks rendered after a contact logs: the entry the log left,
shaped like a draft's `qso`, with the rest of a `//` stack back in the
field, so `next.call` is the station to answer next or a partial to ask
back. In that same thanks, `qso` is the contact as it was saved, with
whatever an extension's `processQsoBeforeSave` added and the serial it was
logged with.

### `config`, a panel's own form values

Whatever the panel's `form` declared, under the keys it used.

### `log`, one export

`station`, `ref`, `refName`, `refShortName`, `activity`, `handlerName`,
`handlerShortName`, `format`, `exportType`, `modifier`, `extension`,
`compact`.

### `keyer`, the CW messages

`msg1` … `msg8`: the active set's messages, each rendered against the same
context, so one message can include another: `TU {{ keyer.msg1 }}`. A
message is expanded only where a template names it, so a branch not taken
costs nothing, which is what lets a thanks answer the next stacked caller or
ask a partial back and send nothing more when there is neither:
`TU {% if next.fullCall != blank %}{{ next.call }} {{ keyer.msg2 }}{% elsif next.partial != blank %}{{ next.partial }}?{% endif %}`.
An included message renders against the same context (there, the `qso` just
logged, not `next`). A message that reaches itself, directly or through
others, is an error naming the loop (`a message includes itself: F3 → F1 →
F3`), and like any template error keys nothing. A label may name its own
message; only a message being sent is part of the chain.

## Timestamps

- **`…At` values are ISO-8601 UTC strings.** Feed these to the `date`
  filter: `{{ qso.at | date: '%H:%MZ' }}`.
- **`date`, `dateCompact` and `time` are preformatted UTC**: `2026-07-27`,
  `20260727`, `1430`.

Everything is UTC.

## Filters

All of Liquid's own (`date`, `downcase`, `upcase`, `strip`, `default`,
`join`, `size`, `first`, `last`, `round`, `truncate`, `replace`, `map`,
`where`, …), plus six:

| Filter | Does | Example |
| --- | --- | --- |
| `dash` | non-alphanumerics to `-`, collapsed and trimmed, **case preserved** | `N0CALL/P` → `N0CALL-P` |
| `alnum` | strip to alphanumerics | `2026-07-27` → `20260727` |
| `pad: n` | zero-pad on the left to `n` characters (default 3); **blank stays blank** | `7` → `007` |
| `cut: "digits"` | CW cut numbers for the listed digits, from `0`→`T` `1`→`A` `5`→`E` `9`→`N`; default `"09"` | `599` → `5NN`; `{{ 9 \| pad: 3 \| cut }}` → `TTN` |
| `refLabels` | a list of refs to each one's `shortLabel`, else `label`, else `ref`; a ref with none is skipped | `op.refs` → `POTA US-1234`, `KFF-9999` |
| `sentence: "sep", "final"` | joins a list with a different last separator (defaults `", "` and `" & "`); blanks dropped | `A, B & C`, `A & B` |

`pad` leaves a blank alone because a CW message can be keyed before the
serial field has a number, and `000` sent in that gap is a serial the log
will never agree with. Pad before you cut, or the zeros go out uncut.
`dash` keeps case because callsigns and references stop being legible
flattened; `{{ x | downcase | dash }}` is the slug form for free text.

### Fallbacks

`default` chains, taking the first value that is not blank, and the values
above are `""` when there is nothing to say:

```liquid
{{ qso.their.state | default: qso.their.guess.state | default: "none" }}
```

As a tag, compare against `blank` rather than testing the bare value, since
in Liquid only `nil` and `false` are false:

```liquid
{% if qso.their.state != blank %}{{ qso.their.state }}{% else %}none{% endif %}
```

## Traps

- **An empty string is true.** `{% if log.modifier %}` fires on `""`. Ask
  `{% if log.modifier != blank %}`.
- **A raw millisecond timestamp is not a date.** The `date` filter reads a
  number as seconds. Use the `…At` strings.
- **`cut`'s digit list must be quoted.** A bare `0159` is read as the number
  159 before the filter sees it. Write `cut: "09"`.
- **Unknown names are silent.** An unknown variable renders empty and an
  unknown filter passes its value through, so a misspelled `{{ op.stationCall }}`
  looks like missing data rather than a mistake.
- **Literal braces need `{% raw %}`.** Text written before a surface was
  templated can lose a span, since `{{ TODO }}` is a valid reference to a
  variable that does not exist.
- **`{% include %}` throws.** There is no filesystem.
- **Loops are bounded by time.** A render is abandoned after 250 ms with a
  `TemplateError` naming the limit.

## Errors

`renderTemplate` throws `TemplateError`, carrying Liquid's message with the
line and column, and does not fall back. Where the template is the
operator's, show them the message; a panel that answered a typo by deleting
what somebody wrote would be the worse failure.

## Panel triggers

`triggersForTemplate(text)` reports which panel triggers a template needs,
from the namespaces it names: `qso` → `qso` and `lookup`, `qsoCount` →
`qsoLogged`, `op` → `operation`, `now` → `tick:30`. A panel rendering
operator-written text passes these back as the render result's `triggers`
([Panels](panels.md#the-render-results-other-fields)), so each pane pays
only for what its own text asks for. Only `{{ … }}` and `{% … %}` spans are
read, never the prose around them ("Goal: 100 qso today" is a note, not a
request to be woken per keystroke); inside a span it is deliberately
generous, so `{% if qso %}` counts as naming the QSO.

## Where templates are used

| What | Editable by the operator |
| --- | --- |
| Panel documents | in the panel's configuration form |
| Export filenames and titles | Settings → Exports, globally and per export type |
| ADIF `NOTES`, `COMMENT` and `QSLMSG` | Settings → Exports; an empty template suppresses the field |
| CW messages | in the CW Keyer dialog |

`NOTES` and `COMMENT` default to the contact's notes and are withheld when
private data is off. `QSLMSG` defaults to empty for a program's export, and
for the full log to the operation's references as `refLabels | sentence`
names them; a custom QSL message may use the contact's values. Templates
receive no withheld private or lookup values. File titles obey the
private-data choice; filename templates are labels for the operator's own
files. The SDK's `exportFilename` helper is not templated: it supplies the
dates and the name parts, and the templated names come from registered
export types.
