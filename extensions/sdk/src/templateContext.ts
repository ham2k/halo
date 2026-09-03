// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
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

import type { JSONValue } from "./types"

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
export function opValues(
  operation: Record<string, JSONValue>,
  extra: { qsoCount?: number; atMillis?: number } = {},
): Record<string, JSONValue> {
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
export function qsoValues(qso: Record<string, JSONValue>): Record<string, JSONValue> {
  const their = (qso.their ?? {}) as Record<string, JSONValue>
  const our = (qso.our ?? {}) as Record<string, JSONValue>
  const startMillis = Number(qso.startAtMillis ?? 0)

  return {
    call: (their.call ?? "") as JSONValue,
    their: their as JSONValue,
    our: our as JSONValue,
    band: (qso.band ?? "") as JSONValue,
    mode: (qso.mode ?? "") as JSONValue,
    freq: (qso.freq ?? "") as JSONValue,
    // Named for what an operator calls them, not for QSON's `sent` on both
    // sides — `qso.our.sent` is what WE sent, i.e. the report they received.
    rstSent: (our.sent ?? "") as JSONValue,
    rstRcvd: (their.sent ?? "") as JSONValue,
    notes: (qso.notes ?? "") as JSONValue,
    refs: (qso.refs ?? []) as JSONValue,
    ...(startMillis > 0 ? dateValues(startMillis) : { date: "", dateCompact: "", time: "", at: "" }),
    startAtMillis: startMillis,
  }
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
  /// Overrides "now", for tests.
  nowMillis?: number
}

/// Assembles the context for one render. A namespace the surface has nothing
/// for is LEFT OUT rather than filled with blanks: liquid renders an unknown
/// variable as empty either way, and `{% if qso %}` is then the honest way to
/// ask "is there a QSO here at all", which a stub object would answer wrong.
export function templateContext(args: TemplateContextArgs): Record<string, unknown> {
  const nowMillis = args.nowMillis ?? Date.now()
  return {
    app: { name: args.appName ?? "" },
    now: utcIso(nowMillis),
    ...(args.operation
      ? { op: opValues(args.operation, { qsoCount: args.qsoCount, atMillis: args.atMillis }) }
      : {}),
    ...(args.qso ? { qso: qsoValues(args.qso) } : {}),
    ...(args.log ? { log: logValues(args.log) } : {}),
    ...(args.config ? { config: args.config } : {}),
  }
}
