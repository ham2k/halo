# Integrations

An integration connects an operation to something outside the app: a log
service that takes each contact as it is logged, an online scoreboard, a
program elsewhere on the network. The operator switches it on in the
operations they want it in, and from then on it is told what changes in
each one's log. It has nothing on screen of its own. [How hooks work](hooks.md)
covers registration, keys and `ctx`.

An integration and an [assistant](assistants.md) are called the same way.
Pick an integration when the operator decides per operation, and when what
you do is read the log and send it on. Pick an assistant to watch every
operation, the draft included, and act on the app.

## `integration`

**For:** sending an operation's contacts, or what is made of them, to a
service or program outside the app, in the operations the operator switched
it on in.

**Called:** `getIntegrations` on every runtime start; `observe` once per
open operation it is on in, each time one of its triggers fires, and with
`open` as such an operation opens, as the operator switches it on, and
after every runtime restart; `describe`, when you have it, as the
Integrations dialog of an operation it is on in shows it. Extension API 29.

```ts
interface IntegrationHook {
  getIntegrations(args: {}, ctx): Promise<IntegrationDescriptor[]>
  observe(args: IntegrationObserveArgs, ctx): Promise<void>
  describe?(args: IntegrationDescribeArgs, ctx): Promise<string | null>
}
// IntegrationDescriptor:   { key, title, description?, icon?, on?, form? }
// IntegrationObserveArgs:  { integrationKey, operation, qsoCount, config, reasons, clock, changes }
// IntegrationChanges:      { logged: QSO[], updated: QSO[], deleted: string[] }
// IntegrationDescribeArgs: { integrationKey, operation, config }
```

**`getIntegrations`** lists what you offer. The operator finds each one in
an operation's **Integrations** dialog, beside the contacts other programs
sent and Import ADIF: a switch for this operation, titled with its `title`,
and beside it, when you declare a `form`, a button that opens its fields.
The same fields are under **Settings › Integrations**, in a band named after
your extension.

- **The switch is per operation, on this device.** Every integration starts
  off, in every operation. Switching it on in one operation turns it on
  nowhere else, and does not travel with the operation to the operator's
  other devices. A contact synced from another device joins the log here
  like any other, so an operation logged on several devices needs it on in
  only one of them.
- **The settings are the same in every operation.** The app keeps them
  under `integration:<hook key>:<key>`, so renaming a `key` loses them.
  Credentials belong in an [account](accounts.md), not in the `form`.
- An integration registered without `integration` in the manifest's `hooks`
  is never called. An extension that is mostly integrations takes
  `"category": "integration"`, which lists it under Integrations in the
  Extensions panel. Installing one asks for nothing beyond its grants:
  switching it on in an operation is the operator's consent to what it does
  there.

**`describe`** says, in one line under the integration's name, what it does
in the operation the dialog is open on: `"Report CQ WW SSB score every 3
minutes"`, or why it has nothing to do there. It is asked only where the
integration is on, since switching it on is what hands it the operation;
where it is off, the dialog shows its `description`. It is handed the
`operation` and the integration's `config`, and asked again as either
changes; a longer answer is cut at two lines. Return null, or leave the
method out, to keep the descriptor's `description`, which is also what
Settings shows, with no operation to speak of. Answer from what you are
handed: the dialog shows the `description` until you answer, and keeps it
when an answer takes longer than two seconds.

**`observe`** is called about one operation at a time. With two open where
it is on, a change in one is a call about that one; a tick is a call about
each.

- `operation` is the operation's data with its `uuid`,
  `startAtMillisMin`/`startAtMillisMax` and `operatorCall`, as an
  assistant is handed it. `ctx.getQsos(operation.uuid)` reads its log.
- `changes` holds the contacts that changed in the log since your previous
  call about this operation: `logged`, the contacts that joined it, and
  `updated`, those already in it whose content changed, each as
  `ctx.getQsos` hands it; `deleted`, the `uuid` of each that left it.
  Event markers are never among them.
- On `open`, all three are empty. Nothing logged while the operation was
  closed, or while your integration was off, is handed to you: read the log
  with `ctx.getQsos` if you need to catch up.
- `changes` is a best effort. A contact edited and edited back between two
  calls may not appear, and a restart of the runtime starts again from
  `open`. Where every contact must arrive, catch up on `open`: read the log,
  and send what the service you talk to does not hold yet.
- `config` is the integration's own settings.
- `reasons` lists every trigger that fired since the last call, or `open`
  for the first call about an operation, `config` after the operator edits
  its settings.
- `clock` carries `nowMillis` (the app clock) and `realNowMillis`.

Return nothing. What an integration says goes through the host:

| To | Call | Page |
| --- | --- | --- |
| Send a contact, a score, a status to a service | `host.fetch`, to a host in the manifest's `domains` | [The host API](host.md#hostfetchurl-options) |
| Put a line under the call info | `host.fyi.post`, `host.fyi.clear` | [The host API](host.md#hostfyi) |
| Raise a notice: a sign-in that failed, a service that refused | `host.statusBar.showNotice` | [The host API](host.md#hoststatusbar) |
| Show what it sent, a score, a status | a `panel` registered beside it | [Panels](panels.md) |

An integration does not change the operator's settings, layouts or the
contact being composed, and does not mark spots. Where an extension needs
those, they belong to an [assistant](assistants.md) beside the integration.

### Triggers

`on` takes the [panel triggers](panels.md#triggers) other than the draft's:
`operation`, `qsoLogged`, `spots`, `radio` and `equipment` (both with
`requiresRadioRead`), and `tick:<seconds>`. They fire as an assistant's do:
with no pane placed or in front, and while the app is hidden too, as far as
the platform lets the app run. `qso` and `lookup` never fire for an
integration.

- **`qsoLogged` is the one that fills `changes`.** A call for any other
  reason carries whatever changed since the previous call too, but
  declaring only `tick:180` hands you every change in batches three minutes
  apart.
- **A tick is a call about every open operation it is on in**, aimed at the
  same wall-clock boundaries a panel's are. With none open, nothing is
  called.
- **Without `on`, an integration is called once per operation**, as it
  opens, and again only when its settings change.

The calls about one operation are paced as an assistant's are: one at a
time, at least 750 ms of idle between one finishing and the next starting,
and everything that fired meanwhile folded into the next call's `reasons`
and `changes`.

### Failure

A call that throws is reported against your key and costs that call; the
next trigger calls again, and its `changes` start after the failed call's,
so what the failed call was handed is not handed again. One that runs past
five seconds is abandoned the same way: the app stops waiting for it, but
your code runs on, beside the next call. Several failures in a row reach the
operator through the app's error reporting. A service that is down is an
expected condition: keep what you could not send and try it again on the
next call, rather than throw, and send it in one request rather than one
per contact.

### Example

```ts
import type { IntegrationHook, JSONValue } from "@ham2k/extension-sdk"
import { host } from "@ham2k/extension-sdk"

// What the service has not taken yet. In memory: a runtime restart empties it.
const unsent: Record<string, JSONValue>[] = []

const LogMirror: IntegrationHook = {
  async getIntegrations() {
    return [{ key: "mirror", title: "Log mirror", description: "Sends each contact as you log it", icon: "cloud-upload", on: ["qsoLogged"] }]
  },
  async observe({ changes }) {
    unsent.push(...changes.logged)
    const batch = unsent.splice(0)
    if (batch.length === 0) return
    try {
      const { status } = await host.fetch("https://log.example.org/qsos", { method: "POST", body: JSON.stringify(batch), timeout: 4000 })
      if (status < 300) return
    } catch {
      // Unreachable: the batch waits for the next call.
    }
    unsent.unshift(...batch)
  },
}
```

`k2hrc-tally` in the SDK's samples is a whole extension: it keeps a tally of
what `changes` reports on the FYI line.
