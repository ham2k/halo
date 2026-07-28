// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One filename scheme for every export, in two forms.
//
// Before this, each hook spelled its own filename inline — the activity SDK
// said `n0call-at-us-1234.adi`, core ADIF said `20260727-n0call-my-op.adi`,
// each contest said `CQ-WW-CW-N0CALL.log` — so the same log came out under
// three unrelated conventions and none of them could be turned off. The
// "Use compact file names" setting (app-polo's `useCompactFileNames`) needs a
// single place to switch, which is what this is.
//
// **Normal** is the readable form, for a person filing a download:
//   `2026-07-27 N0CALL at US-1234.adi`
// **Compact** is the terse form, for uploaders and small screens:
//   `N0CALL@us-1234-20260727.adi`
//
// Both are app-polo's (`dataExportOptions.js` `basePartialTemplates`), minus
// the Handlebars: HaLo's hooks build a filename from named parts, so a
// template engine would only buy per-user editing, which nothing asks for.

import type { JSONValue } from "./types"

/// Lowercase, alphanumeric, dash-separated, for FREE TEXT — an operation
/// title, a program name: `Field Day 2026` → `field-day-2026`.
function slug(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
}

/// Dash-separated but case-preserving, for IDENTIFIERS — callsigns and
/// references, which the hobby writes in capitals and which stay legible in
/// a compact name precisely because they aren't flattened:
/// `N0CALL/P` → `N0CALL-P`, `US-1234` → `US-1234`. app-polo does the same
/// (`{{log.station}}@…{{log.ref}}`, neither passed through `downcase`).
function token(text: string): string {
  return text.replace(/[^A-Za-z0-9-]+/g, "-").replace(/^-+|-+$/g, "")
}

/// `2026-07-27` in UTC — the date the log is *about*, so it must not shift
/// with the reader's timezone.
function isoDate(millis: number): string {
  return new Date(millis).toISOString().slice(0, 10)
}

/// `20260727` — the same date with the separators taken out.
function compactDate(millis: number): string {
  return isoDate(millis).replace(/-/g, "")
}

/// Characters no filesystem wants, plus the ones that would silently split a
/// path. Applied last, so a caller's `modifier` can't escape the filename.
function sanitize(name: string): string {
  return name.replace(/[/\\:*?"<>|]+/g, "-").replace(/\s+/g, " ").trim()
}

export interface ExportNameParts {
  /// The operating station's callsign. Shown as given in the normal form
  /// (`N0CALL`), slugged in the compact one.
  stationCall?: JSONValue
  /// The reference this file claims, e.g. `US-1234`. Produces the "at" form.
  ref?: string
  /// A short program or contest tag used when there is no single reference,
  /// e.g. `POTA` or `CQ-WW-CW`. Produces the "for" form.
  activity?: string
  /// Free-form tail: an operation title, a mode, `Full`. Dropped when empty.
  modifier?: string
  /// When the log starts, in epoch milliseconds. Defaults to now — an
  /// operation with no QSOs has no date of its own to use.
  startAtMillis?: number
  /// Filename extension, without the leading dot: `adi`, `log`, `edi`.
  extension: string
  /// Whether to build the compact form. Comes from the user's
  /// "Use compact file names" setting, handed to the hook in its request.
  compact?: boolean
}

/// Builds the filename for one export.
///
/// Callers pass whichever parts they have; the shape follows from them, so a
/// hook never has to know which form is in force:
///
/// | parts | normal | compact |
/// |---|---|---|
/// | `ref` | `2026-07-27 N0CALL at US-1234.adi` | `N0CALL@us-1234-20260727.adi` |
/// | `activity` | `2026-07-27 N0CALL for POTA.adi` | `N0CALL-pota-20260727.adi` |
/// | neither | `2026-07-27 N0CALL Field Day.adi` | `n0call-20260727-field-day.adi` |
export function exportFilename(parts: ExportNameParts): string {
  const millis = parts.startAtMillis && parts.startAtMillis > 0 ? parts.startAtMillis : Date.now()
  const call = String(parts.stationCall ?? "").trim()
  const modifier = (parts.modifier ?? "").trim()
  const extension = parts.extension.replace(/^\./, "")

  let stem: string
  if (parts.compact) {
    // Callsign first: these sort together per station, which is the order
    // that matters once a season's uploads share one folder.
    const station = token(call)
    const date = compactDate(millis)
    if (parts.ref) {
      stem = [`${station ? `${station}@` : ""}${token(parts.ref)}`, date, slug(modifier)].filter((x) => x).join("-")
    } else {
      stem = [station, slug(parts.activity ?? ""), date, slug(modifier)].filter((x) => x).join("-")
    }
  } else {
    // Date first: chronological order, and it reads as a sentence.
    const date = isoDate(millis)
    if (parts.ref) {
      stem = [date, call, "at", parts.ref, modifier].filter((x) => x).join(" ")
    } else if (parts.activity) {
      stem = [date, call, "for", parts.activity, modifier].filter((x) => x).join(" ")
    } else {
      stem = [date, call, modifier].filter((x) => x).join(" ")
    }
  }

  // Every part can be empty — an operation with no station callsign and no
  // title would otherwise produce a filename that is nothing but ".adi",
  // which reads as an extensionless dotfile and hides on Unix.
  if (!stem) stem = "export"

  return `${sanitize(stem)}.${extension}`
}

/// The first QSO's start time, for [exportFilename]'s `startAtMillis`. Falls
/// back to the operation's own start, then to nothing (meaning "now") — an
/// export offered for an operation before its first contact still needs a
/// name, and the panel shows that name before any file exists.
export function startMillisOf(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[] = [],
): number | undefined {
  const earliest = qsos
    .map((qso) => Number(qso.startAtMillis ?? 0))
    .filter((millis) => millis > 0)
    .sort((a, b) => a - b)[0]
  if (earliest) return earliest
  const operationStart = Number(operation.startAtMillisMin ?? operation.startAtMillis ?? 0)
  return operationStart > 0 ? operationStart : undefined
}
