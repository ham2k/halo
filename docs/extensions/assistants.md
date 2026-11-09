# Assistants

An assistant watches what the operator does in every open operation and
answers through the host: a line on the FYI line, a notice, an annotation on
a band, a command to the radio. It has nothing on screen of its own, so it
keeps watching whatever the operator has placed, and whichever tab is in
front. A coach is the usual shape: it notices the rate dropping, a needed
multiplier on the band, a contact logged without its exchange, and says so.
[How hooks work](hooks.md) covers registration, keys and `ctx`.

## `assistant`

**For:** reacting to the operator's activity whether or not any panel is
showing.

**Called:** `getAssistants` on every runtime start; `observe` once per open
operation each time one of its triggers fires, and with `open` as each
operation opens, as the operator switches the assistant on, and after every
runtime restart.

```ts
interface AssistantHook {
  getAssistants(args: {}, ctx): Promise<AssistantDescriptor[]>
  observe(args: ObserveArgs, ctx): Promise<void>
}
// AssistantDescriptor: { key, title, description?, icon?, on?, form?, enabledByDefault? }
// ObserveArgs:        { assistantKey, operation, qso?, qsoCount, config, reasons, clock }
```

**`getAssistants`** lists what you offer. The operator finds them under
**Settings › Application Preferences › Assistants**, in a band named after
your extension: a switch for each assistant, titled with its `title`, and
under one that is on, the fields of its `form`. A header in the `form` stays
inside that band. Each starts on unless `enabledByDefault` is `false`. The
app keeps the switch and the settings under `assistant:<hook key>:<key>`, so
renaming a `key` loses both.

**Installing one is a matter of trust.** An extension whose manifest lists
`assistant` in its `hooks` installs behind a warning, ahead of its grants:
it watches everything the operator does and acts unasked, so they should
install it only from a source they trust. An update that adds the hook asks
again, even under Update all. An assistant registered without `assistant`
in the manifest's `hooks` is never called.

**`observe`** is called about one operation at a time. With two open, a
change in one is a call about that one; a tick is a call about each.

- `operation` is the operation's data with its `uuid`,
  `startAtMillisMin`/`startAtMillisMax` and `operatorCall`, as a panel is
  handed it. `ctx.getQsos(operation.uuid)` reads its log.
- `qso` is the draft being composed in it, present when you declare `qso` or
  `lookup` and the logging panel has produced one.
- `config` is the assistant's own settings.
- `reasons` lists every trigger that fired since the last call, or `open`
  for the first call about an operation, `config` after the operator edits
  its settings.
- `clock` carries `nowMillis` (the app clock) and `realNowMillis`.

Return nothing. Everything an assistant says goes through the host:

| To | Call | Page |
| --- | --- | --- |
| Put a line under the call info | `host.fyi.post`, `host.fyi.clear` | [The host API](host.md#hostfyi) |
| Raise a notice | `host.statusBar.showNotice` | [The host API](host.md#hoststatusbar) |
| Mark a stretch of a band | `host.bandAnnotations.put` | [Spots](spots.md#bandannotations) |
| Mark, pick or hide spots | `host.spots.mark`, `host.spots.unmark` | [Spots](spots.md#spots) |
| Add spots of its own | `host.spots.put`, with a `spots` hook | [Spots](spots.md#spots) |
| Fill in or change the contact being logged | `host.updateDraft`, with `requiresDraftWrite` | [The host API](host.md#hostupdatedraftpatch--replace-operationuuid-) |
| Tune or set the radio | `host.setRadio` | [Radio control](radio.md) |
| Show a running summary | a `panel` registered beside it | [Panels](panels.md) |

### Triggers

`on` takes the [panel triggers](panels.md#triggers): `operation`,
`qsoLogged`, `qso`, `lookup`, `spots`, `radio` (with `requiresRadioRead`)
and `tick:<seconds>`. They fire on the same changes, with three differences:

- **Nothing pauses them.** No pane has to be placed or in front. They fire
  while the app is hidden too, as far as the platform lets the app run.
- **A tick is a call about every open operation**, aimed at the same
  wall-clock boundaries a panel's are. With no operation open, nothing is
  called; set a timer from `onActivation` for work that needs none.
- **Without `on`, an assistant is called once per operation**, as it opens,
  and again only when its settings change.

The calls about one operation are paced as a panel's renders are: one at a
time, at least 750 ms of idle between one finishing and the next starting,
and everything that fired meanwhile folded into the next call's `reasons`.
The call reads the newest state, not the state that woke it.

**What each trigger costs.** `qso` and `lookup` make the app produce the
draft on every pause in typing, for every open operation, from the moment
one assistant that is on declares either. `spots` is a call on every board
refresh. Declare the least that tells you what you need: a coach reacting to
logged contacts wants `qsoLogged`, not `qso`.

### Failure

A call that throws is reported against your key and costs that call;
the next trigger calls again. One that runs past five seconds is abandoned
the same way. Several failures in a row reach the operator through the app's
error reporting. Return early for an expected condition: no rate yet, nothing
configured.

### Example

```ts
import type { AssistantHook } from "@ham2k/extension-sdk"
import { host } from "@ham2k/extension-sdk"

const RateCoach: AssistantHook = {
  async getAssistants() {
    return [{ key: "rate", title: "Rate coach", description: "Says when the rate drops", icon: "speedometer", on: ["qsoLogged", "tick:60"] }]
  },
  async observe({ operation }, ctx) {
    const qsos = (await ctx.getQsos?.(operation.uuid as string)) ?? []
    const lastTen = qsos.filter((q) => q.startAtMillis > Date.now() - 600_000).length
    if (lastTen >= 3) return await host.fyi.clear("rate")
    await host.fyi.post({ key: "rate", category: "info", icon: "speedometer-slow", text: `${lastTen} QSOs in the last 10 minutes` })
  },
}
```

`k2hrc-coach` in the SDK's samples is the whole extension.
