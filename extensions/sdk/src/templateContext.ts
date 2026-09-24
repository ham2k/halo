// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The values a template can name, and the ONE place each of them is spelled.
// docs/extensions/templates.md is this file's reference documentation — an
// operator reads that, so a name added here without a line there is a value
// nobody can find.
//
// Namespaces are app-polo's (`op`, `log`, `qso` — `dataExportOptions.js`
// `templateContextForOneExport`), so a template carried over from PoLo names
// the same things. What it can't carry is polo's syntax: `{{ op.date }}`
// parses identically, `{{#if}}` and `{{>partial}}` do not.
//
// **Timestamps follow one rule**: `…At` fields are ISO-8601 UTC strings, for
// feeding liquid's `date` filter (`{{ op.startAt | date: '%H:%M' }}`), and
// the preformatted `date`/`time` fields are the forms templates ask for often
// enough that making everyone write a format string would be worse. Nothing
// carries a local-time value — a log is kept in UTC, and a filename that
// shifted with the reader's zone would name the wrong day (exportNames.ts).

import type { JSONValue } from "./types.ts"
import { TemplateError, renderTemplate } from "./templates.ts"

/// `2026-07-27`
export function utcDate(millis: number): string {
  return new Date(millis).toISOString().slice(0, 10)
}

/// `20260727` — the filename form. Equivalent to `{{ op.date | compact }}`,
/// and offered as a value because the compact filename defaults would
/// otherwise all carry that filter.
export function utcDateCompact(millis: number): string {
  return utcDate(millis).replace(/-/g, "")
}

/// `1430` — UTC, no separator, as logs and Cabrillo write it.
export function utcTime(millis: number): string {
  return new Date(millis).toISOString().slice(11, 16).replace(":", "")
}

/// `2026-07-27T14:30:00.000Z`, for the `date` filter.
export function utcIso(millis: number): string {
  return new Date(millis).toISOString()
}

/// The date values for one instant, shared by `op` and by the export
/// filenames (which have an instant but no operation).
export function dateValues(millis: number): Record<string, JSONValue> {
  return {
    date: utcDate(millis),
    dateCompact: utcDateCompact(millis),
    time: utcTime(millis),
    at: utcIso(millis),
  }
}

/// The `op` namespace: the operation a template is rendering for.
///
/// `station` is the field as the operator typed it, which may hold several
/// comma-separated callsigns (halo_core's `Operation.stationCalls` splits the
/// same field); `stations` is that list, so a template can name one or all.
/// `startAtMillisMin`/`startAtMillisMax` are COLUMNS on the operation row,
/// not keys in its QSON `data`, and hooks are handed `data` (plus `uuid`) —
/// so they are present only where a caller adds them deliberately. Callers
/// that know the log's instant some other way pass `atMillis` instead: the
/// ADIF export takes it from the first QSO.
///
/// When nothing says when the log happened, the date fields are EMPTY. The
/// tempting fallback is `Date.now()`, and it is the worst of the options: an
/// operator cleaning up yesterday's log would read today's date off the pane
/// with nothing to say it was invented.
export function opValues(operation: Record<string, JSONValue>, extra: { qsoCount?: number; atMillis?: number } = {}): Record<string, JSONValue> {
  const station = String(operation.stationCall ?? "")
  const startMillis = Number(operation.startAtMillisMin ?? operation.startAtMillis ?? 0)
  // The LAST CONTACT'S START, which is as close to an end as the log gets —
  // an operation row records `startAtMillisMax` and nothing else, so the
  // final QSO's own duration is not in it. Named `end…` anyway, as app-polo
  // names it, because it is what an operator means by when they stopped.
  const endMillis = Number(operation.startAtMillisMax ?? 0)
  const atMillis = extra.atMillis && extra.atMillis > 0 ? extra.atMillis : startMillis

  return {
    ...(atMillis > 0 ? dateValues(atMillis) : { date: "", dateCompact: "", time: "", at: "" }),
    station,
    // `call` says the same thing, for symmetry with `qso.call` — the name an
    // operator writing a CW message reaches for first; without it,
    // `{{ op.call }}` renders empty with nothing to say why.
    call: station,
    // Deduped, like halo_core's `Operation.stationCalls`: "N0DEV, N0DEV" is a
    // typo, and a template fanning out over this would otherwise repeat
    // itself once per typo.
    stations: [
      ...new Set(
        station
          .split(",")
          .map((call) => call.trim().toUpperCase())
          .filter((call) => call !== ""),
      ),
    ],
    operator: (operation.operator ?? "") as JSONValue,
    // The generated, ref-derived title ("at US-1234") and the operator's own
    // words, kept apart: an export that withholds private data withholds the
    // second and keeps the first (see the adif hook's preamble).
    title: (operation.title ?? "") as JSONValue,
    userTitle: (operation.userTitle ?? "") as JSONValue,
    grid: (operation.grid ?? "") as JSONValue,
    refs: (operation.refs ?? []) as JSONValue,
    uuid: (operation.uuid ?? "") as JSONValue,
    qsoCount: extra.qsoCount ?? Number(operation.qsoCount ?? 0),
    startDate: startMillis > 0 ? utcDate(startMillis) : "",
    startTime: startMillis > 0 ? utcTime(startMillis) : "",
    startAt: startMillis > 0 ? utcIso(startMillis) : "",
    endDate: endMillis > 0 ? utcDate(endMillis) : "",
    endTime: endMillis > 0 ? utcTime(endMillis) : "",
    endAt: endMillis > 0 ? utcIso(endMillis) : "",
  }
}

/// The `qso` namespace: one contact.
///
/// `their` and `our` are passed through whole, so `qso.their.guess.name`
/// reaches the lookup's answer — the nesting is the QSON shape, and
/// flattening it here would invent a second vocabulary for the same data.
/// The flat fields alongside them are the ones a template names constantly.
///
/// A contest keeps its serials on ITS OWN ref, under a type only it knows, so
/// `serialSent`/`serialRcvd` are found by field name instead: the first ref
/// carrying `ourSerial` / `theirSerial`. That makes those two names a
/// convention every serial-exchange contest has to keep (contests.md §5.8) —
/// one that names its field anything else logs correctly and keys a blank.
///
/// A draft's `their.call` is the call field as typed, which may be a whole
/// `//` stack or comma list; the panel reads the field at its cursor and
/// hands the answer over as `callField` (halo_widgets'
/// `CallFieldText.templateCalls`), so `call` names the one call Enter logs.
/// A logged contact has no `callField`, and no next anything.
export function qsoValues(qso: Record<string, JSONValue>): Record<string, JSONValue> {
  const their = (qso.their ?? {}) as Record<string, JSONValue>
  const our = (qso.our ?? {}) as Record<string, JSONValue>
  const callField = (qso.callField ?? {}) as Record<string, JSONValue>
  const guess = (their.guess ?? {}) as Record<string, JSONValue>
  const startMillis = Number(qso.startAtMillis ?? 0)
  const serialSent = refField(qso.refs, "ourSerial")

  return {
    // `||`, not `??`: a blank reading still means "no call", and the field
    // as typed is a better answer than keying nothing.
    call: (callField.call || their.call || "") as JSONValue,
    // The panel's split of `call` — a logged contact's call is a full one.
    fullCall: (callField.fullCall ?? their.call ?? "") as JSONValue,
    partial: (callField.partial ?? "") as JSONValue,
    nextCall: (callField.nextCall ?? "") as JSONValue,
    nextPartial: (callField.nextPartial ?? "") as JSONValue,
    their: their as JSONValue,
    our: our as JSONValue,
    band: (qso.band ?? "") as JSONValue,
    mode: (qso.mode ?? "") as JSONValue,
    freq: (qso.freq ?? "") as JSONValue,
    // Named for what an operator calls them, not for QSON's `sent` on both
    // sides — `qso.our.sent` is what WE sent, i.e. the report they received.
    rstSent: (our.sent ?? "") as JSONValue,
    rstRcvd: (their.sent ?? "") as JSONValue,
    // Unpadded, as stored: `001` or `1` is the operator's call, not the
    // contest's, so it is left to the `pad` filter.
    serialSent,
    serialRcvd: refField(qso.refs, "theirSerial"),
    // The short forms are the SENT side: a CW message is what we send, and
    // that is where these get typed.
    rst: (our.sent ?? "") as JSONValue,
    serial: serialSent,
    // What was typed, else what the lookup found — the two places a CW
    // message's "GM BOB" or "NY" would otherwise have to be chained by hand.
    // `name` is the first word only: a lookup's "Robert J Smith" keyed in
    // full is not how anyone greets a station.
    state: firstText(their.state, guess.state),
    name: firstText(their.name, guess.name).split(/\s+/)[0],
    notes: (qso.notes ?? "") as JSONValue,
    refs: (qso.refs ?? []) as JSONValue,
    ...(startMillis > 0 ? dateValues(startMillis) : { date: "", dateCompact: "", time: "", at: "" }),
    startAtMillis: startMillis,
  }
}

/// The first of [values] that is non-blank text, trimmed; "" when none is.
function firstText(...values: (JSONValue | undefined)[]): string {
  for (const value of values) {
    if (typeof value !== "string") continue
    const text = value.trim()
    if (text !== "") return text
  }
  return ""
}

/// The first non-blank `field` among `refs`, as text — our own serial is
/// stored as an integer, a received one as typed (not every sponsor's
/// "serial" is a number).
function refField(refs: JSONValue | undefined, field: string): string {
  if (!Array.isArray(refs)) return ""
  for (const ref of refs) {
    if (ref === null || typeof ref !== "object" || Array.isArray(ref)) continue
    const value = ref[field]
    if (typeof value !== "string" && typeof value !== "number") continue
    const text = String(value).trim()
    if (text !== "") return text
  }
  return ""
}

/// What one export knows about itself, for the `log` namespace: which file
/// this is, which program it is for, which reference it claims. Every field
/// is optional because the surfaces differ — a filename knows its extension,
/// an ADIF field knows its format, neither knows the other's.
export interface LogValues {
  station?: string
  ref?: string
  refName?: string
  refShortName?: string
  /// A program or contest tag used when there is no single reference: `POTA`,
  /// `CQ-WW-CW`.
  activity?: string
  handlerName?: string
  handlerShortName?: string
  format?: string
  exportType?: string
  /// Free-form tail: an operation title, a mode, `Full`.
  modifier?: string
  extension?: string
  /// The user's "Use compact file names" setting, so a template can branch on
  /// it the way the built-in defaults do.
  compact?: boolean
}

export function logValues(values: LogValues): Record<string, JSONValue> {
  return {
    station: values.station ?? "",
    ref: values.ref ?? "",
    refName: values.refName ?? "",
    refShortName: values.refShortName ?? "",
    activity: values.activity ?? "",
    handlerName: values.handlerName ?? "",
    handlerShortName: values.handlerShortName ?? "",
    format: values.format ?? "",
    exportType: values.exportType ?? "",
    modifier: values.modifier ?? "",
    extension: values.extension ?? "",
    compact: values.compact === true,
  }
}

export interface TemplateContextArgs {
  operation?: Record<string, JSONValue>
  qso?: Record<string, JSONValue>
  /// The count the surface was handed, when it knows better than the
  /// operation record does — a panel is told the live one.
  qsoCount?: number
  /// A panel instance's own form values, under `config`.
  config?: Record<string, JSONValue>
  log?: LogValues
  /// `ctx.appName` — platform-appropriate ("Ham2K Logger" on desktop,
  /// "Ham2K Portable Logger" on mobile), so a template that signs its output
  /// names the app the operator is actually running.
  appName?: string
  /// When the log this render is about happened, for the `op` date fields —
  /// see [opValues]. Without it they fall back to the operation's own
  /// `startAtMillisMin`, and are empty if that isn't in the payload either.
  atMillis?: number
  /// The keyer's messages, for `keyer.msg1`…`keyer.msgN` — and which of
  /// them is being rendered, if one is, so it can't include itself. See
  /// [keyerValues].
  keyer?: { messages: string[]; current?: number }
  /// Overrides "now", for tests.
  nowMillis?: number
}

/// Assembles the context for one render. A namespace the surface has nothing
/// for is LEFT OUT rather than filled with blanks: liquid renders an unknown
/// variable as empty either way, and `{% if qso %}` is then the honest way to
/// ask "is there a QSO here at all", which a stub object would answer wrong.
export function templateContext(args: TemplateContextArgs): Record<string, unknown> {
  const nowMillis = args.nowMillis ?? Date.now()
  const context: Record<string, unknown> = {
    app: { name: args.appName ?? "" },
    now: utcIso(nowMillis),
    ...(args.operation ? { op: opValues(args.operation, { qsoCount: args.qsoCount, atMillis: args.atMillis }) } : {}),
    ...(args.qso ? { qso: qsoValues(args.qso) } : {}),
    ...(args.log ? { log: logValues(args.log) } : {}),
    ...(args.config ? { config: args.config } : {}),
  }
  if (args.keyer) context.keyer = keyerValues(context, args.keyer.messages ?? [], args.keyer.current ? [args.keyer.current] : [])
  return context
}

/// The `keyer` namespace: `msgN` is message N RENDERED against the same
/// context — `{{ keyer.msg1 }}` keys the CQ, not its braces — and only when
/// a template names it, so a message that includes nothing renders nothing
/// else.
///
/// [chain] is the messages already being expanded, outermost first. Naming
/// one of them again is an error spelling out the loop ("F3 → F1 → F3"),
/// never an empty string: a message that silently dropped part of itself
/// would go out on the air looking fine to the operator, and a loop is a
/// typo they can only fix if they are told where it is. The chain is what
/// bounds the recursion — there are only so many messages to expand before
/// one repeats.
function keyerValues(base: Record<string, unknown>, messages: string[], chain: number[]): Record<string, unknown> {
  const keyer: Record<string, unknown> = {}
  messages.forEach((template, i) => {
    const n = i + 1
    Object.defineProperty(keyer, `msg${n}`, {
      enumerable: true,
      get() {
        const path = [...chain, n]
        if (chain.includes(n)) throw new TemplateError(`a message includes itself: ${path.map((k) => `F${k}`).join(" → ")}`)
        return renderTemplate(template ?? "", { ...base, keyer: keyerValues(base, messages, path) })
      },
    })
  })
  return keyer
}
