// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One filename scheme for every export, in two forms.
//
// Without this, each hook spells its own filename inline — the activity SDK
// `n0call-at-us-1234.adi`, core ADIF `20260727-n0call-my-op.adi`,
// each contest `CQ-WW-CW-N0CALL.log` — so the same log comes out under
// three unrelated conventions and none of them can be turned off. The
// "Use compact file names" setting (app-polo's `useCompactFileNames`) needs a
// single place to switch, which is what this is.
//
// **Normal** is the readable form, for a person filing a download:
//   `2026-07-27 N0CALL at US-1234.adi`
// **Compact** is the terse form, for uploaders and small screens:
//   `N0CALL@US-1234-20260727.adi`
//
// Both are app-polo's (`dataExportOptions.js` `basePartialTemplates`), and
// like polo's they are TEMPLATES rather than string-building code: the same
// engine and vocabulary as every other operator-facing text in the app
// (templates.ts, docs/extensions/templates.md). Nothing edits them yet, so
// today the only thing that buys is one dialect instead of two — but the
// scheme an operator will want to change is written in the language they will
// change it in, and `exportNames.test.ts` pins every form's output.
//
// The context here is narrower than the panel and ADIF surfaces: these
// templates get `log.*` and the DATE half of `op`, because a filename is
// built from parts rather than from an operation (see [ExportNameParts]).

import type { JSONValue } from "./types"
import { dateValues, logValues } from "./templateContext.ts"
import { oneLine, renderTemplate } from "./templates.ts"
import { isTestOperation } from "./testOperation.ts"

/// The named templates, one per shape a filename can take. Kept as separate
/// named strings rather than one template with branches, so that each is
/// short enough to read — and so overriding one later means replacing one
/// line, which is how app-polo's `basePartialTemplates` is organized too.
///
/// Empty parts are guarded rather than left to collapse: a missing station
/// callsign would otherwise leave a leading `@` or `-`, and collapsing
/// separators after the fact would also eat the ones inside `US-1234`.
///
/// The guard is `!= blank`, not a bare `{% if %}`: in liquid ONLY `nil` and
/// `false` are falsy, so an empty string is TRUE and a bare test would keep
/// every separator it was meant to drop.
type NameShape = "NormalRefName" | "NormalActivityName" | "NormalName" | "CompactRefName" | "CompactActivityName" | "CompactName"

const NAME_TEMPLATES: Record<NameShape, string> = {
  // Date first: chronological order, and it reads as a sentence. Whitespace
  // does collapse here (see [oneLine]), so an absent part just closes up.
  NormalRefName: "{{ op.date }} {{ log.station }} at {{ log.ref }} {{ log.modifier }}",
  NormalActivityName: "{{ op.date }} {{ log.station }} for {{ log.activity }} {{ log.modifier }}",
  NormalName: "{{ op.date }} {{ log.station }} {{ log.modifier }}",

  // Callsign first: these sort together per station, which is the order that
  // matters once a season's uploads share one folder. `dash` preserves case
  // for identifiers (`N0CALL/P` → `N0CALL-P`, `US-1234` unchanged) while
  // free text goes through `downcase | dash`.
  // Each part is slugged into a variable and the SLUG is what's tested: a
  // part that is punctuation only (`!!!`) is not blank but slugs to nothing,
  // and testing the raw value would leave the separator behind — a double
  // dash where the old code's filtered join left none.
  CompactRefName:
    "{% assign s = log.station | dash %}{% assign m = log.modifier | downcase | dash %}" +
    "{% if s != blank %}{{ s }}@{% endif %}{{ log.ref | dash }}-{{ op.dateCompact }}" +
    "{% if m != blank %}-{{ m }}{% endif %}",
  CompactActivityName:
    "{% assign s = log.station | dash %}{% assign a = log.activity | downcase | dash %}" +
    "{% assign m = log.modifier | downcase | dash %}" +
    "{% if s != blank %}{{ s }}-{% endif %}{% if a != blank %}{{ a }}-{% endif %}{{ op.dateCompact }}" +
    "{% if m != blank %}-{{ m }}{% endif %}",
  CompactName:
    "{% assign s = log.station | dash %}{% assign m = log.modifier | downcase | dash %}" +
    "{% if s != blank %}{{ s }}-{% endif %}{{ op.dateCompact }}" +
    "{% if m != blank %}-{{ m }}{% endif %}",
}

/// Characters no filesystem wants, plus the ones that would silently split a
/// path. Applied last, so a caller's `modifier` can't escape the filename.
function sanitize(name: string): string {
  return name.replace(/[/\\:*?"<>|]+/g, "-").replace(/\s+/g, " ").trim()
}

export interface ExportNameParts {
  /// The operating station's callsign. Shown as given in the normal form
  /// (`N0CALL`); in the compact one only its separators change (`N0CALL/P` →
  /// `N0CALL-P`), since a flattened callsign stops being one.
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
/// | `ref` | `2026-07-27 N0CALL at US-1234.adi` | `N0CALL@US-1234-20260727.adi` |
/// | `activity` | `2026-07-27 N0CALL for POTA.adi` | `N0CALL-pota-20260727.adi` |
/// | neither | `2026-07-27 N0CALL Field Day.adi` | `N0CALL-20260727-field-day.adi` |
///
/// A Test Operation (station call ending `/T` or `/TEST`) always gets
/// "Testing" appended to the modifier, so a file generated for one can't be
/// mistaken for a real log even after the modifier's other parts collapse.
export function exportFilename(parts: ExportNameParts): string {
  const millis = parts.startAtMillis && parts.startAtMillis > 0 ? parts.startAtMillis : Date.now()
  const extension = parts.extension.replace(/^\./, "")

  // Typed as a closed union, so a seventh shape can't be added without a
  // template to go with it: an unresolved key would render nothing, and
  // every export in the app would quietly be called `export.adi`.
  const shape: NameShape = `${parts.compact ? "Compact" : "Normal"}${parts.ref ? "Ref" : parts.activity ? "Activity" : ""}Name`

  const modifier = [
    (parts.modifier ?? "").trim(),
    isTestOperation(parts.stationCall) ? "Testing" : "",
  ].filter((part) => part !== "").join(" ")

  const stem = oneLine(
    renderTemplate(NAME_TEMPLATES[shape], {
      op: dateValues(millis),
      log: logValues({
        station: String(parts.stationCall ?? "").trim(),
        ref: parts.ref,
        activity: parts.activity,
        modifier,
        extension,
        compact: parts.compact,
      }),
    }, shape),
  )

  // Every part can be empty — an operation with no station callsign and no
  // title would otherwise produce a filename that is nothing but ".adi",
  // which reads as an extensionless dotfile and hides on Unix.
  return `${sanitize(stem) || "export"}.${extension}`
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
