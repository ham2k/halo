// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ADIF export. Lives in the extension runtime (DESIGN.md §4: export hooks are
// extension territory) and reuses the published ham-js-libs for dates and
// mode/submode mapping. The contact's own fields are written directly, not
// through app-polo's template layer — activity/contest extensions contribute
// their program's fields via `adifFields` hooks. The three FREE-TEXT fields
// are the exception, and are templated: see [TEXT_FIELD_TEMPLATES].

import { fmtADIFDate, fmtADIFTime } from "@ham2k/lib-format-tools"
import { adifModeAndSubmodeForMode } from "@ham2k/lib-operation-data"

import { defineExtension, hooks, qsoValues, renderTemplate, startMillisOf, templateContext } from "@ham2k/extension-sdk"
import type { ExportOption, ExportOptionsRequest, ExportRequest, ExportResult, HookContext, JSONValue } from "@ham2k/extension-sdk"

import manifest from "../manifest.json" with { type: "json" }
import { formatAdifCoordinate } from "./coordinates.ts"
import { filenameFor } from "./filename.ts"

const ADIF_VERSION = '3.1.5'
const DEFAULT_PROGRAM_ID = 'Ham2K Logger'

/// Characters HaLo itself puts into a field, folded back to the ASCII a
/// forty-year-old logging program can read. The typographic quotes come from
/// the lookup layer's `First “Nick” Last` (see normalizeGuess.ts); this table
/// is meant to grow as other Unicode punctuation finds its way in.
///
/// Not a general sanitizer: a correspondent's name in its own script stays as
/// they spell it. lib-format-tools' `sanitizeToISO8859` is the blunter tool —
/// it replaces everything outside Latin-1 with `·`, which would mangle those.
const SUBSTITUTIONS: [RegExp, string][] = [
  [/[“”]/g, '"'],
  [/[‘’]/g, "'"],
]

function sanitizeAdifText(text: string): string {
  return SUBSTITUTIONS.reduce((result, [pattern, replacement]) => result.replace(pattern, replacement), text)
}

/// The other station's coordinate, in the same precedence the app's own model
/// uses (`Qso.theirExactLocation`): an entered pair wins; an ENTERED grid
/// suppresses a guessed pair, because an operator who typed a locator was
/// correcting the lookup and pairing the two would export the address they
/// overrode; only then does the guess answer.
///
/// A pair tagged `locSource: 'prefix'` is no coordinate for this purpose, at
/// either level: it is lib-country-files' DXCC entity centroid, whose `lon`
/// follows cty.dat's west-positive convention, and exporting it would state
/// the mirror image of a country's middle as the station's position. A synced
/// QSO carries that pair on `their` as well as on the guess (see halo_core's
/// `locationFromGuess`).
function theirCoordinate(
  their: Record<string, unknown>,
  theirGuess: Record<string, unknown>,
): { lat: unknown; lon: unknown } | undefined {
  if (their.locSource !== 'prefix' && their.lat != null && their.lon != null) {
    return { lat: their.lat, lon: their.lon }
  }
  if (their.grid != null) return undefined
  if (theirGuess.locSource === 'prefix') return undefined
  return { lat: theirGuess.lat, lon: theirGuess.lon }
}

/// A locator cut back to its 6-character subsquare — the enclosing square, so
/// the result is still a true statement about where the station was, just a
/// coarser one. Shorter locators are already coarse and pass through unchanged.
function coarseGrid(grid: string | undefined): string | undefined {
  return typeof grid === 'string' ? grid.slice(0, 6) : undefined
}

function field(name: string, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  const text = sanitizeAdifText(String(value))
  return `<${name}:${text.length}>${text} `
}

/// ADIF's three free-text fields, as templates over the standard vocabulary
/// (docs/extensions/templates.md) — the same engine that names the file.
/// app-polo templates exactly these three (`ADIFNotesTemplate`,
/// `ADIFCommentTemplate`, `ADIFQslMsgTemplate`).
///
/// COMMENT and QSLMSG are EMPTY and so write nothing. polo defaults COMMENT
/// to the notes and QSLMSG to the operation's references; both stay empty
/// here until there is a settings screen to edit them in, because a default
/// nobody can see is a default nobody can turn off — and these end up in
/// files submitted to a program's servers.
///
/// Whatever fills them has to respect the private/public split below:
/// `notes` is the operator's own words about the station they worked, so it
/// belongs only in a field this export withholds when `includePrivateData`
/// is false. NOTES is such a field; COMMENT and QSLMSG are not.
const TEXT_FIELD_TEMPLATES: { name: string; template: string; private: boolean }[] = [
  { name: 'NOTES', template: '{{ qso.notes }}', private: true },
  { name: 'COMMENT', template: '', private: false },
  { name: 'QSLMSG', template: '', private: false },
]

interface AdifField {
  name: string
  value: string
}

/// The QSO's own fields, shared by every ADIF record it produces.
/// `timeOffsetMillis` shifts this record's timestamp off the contact's — see
/// the caller for why.
///
/// `includePrivateData` separates what the operator NOTED about the station
/// they worked from what the contact itself was. Withheld by default: a file
/// uploaded to a program's servers should carry the QSO, not the operator's
/// own notes about who they met. Same set app-polo gates
/// (`qsonToADIF.js:217-232`) — including the gridsquare, which is a location
/// the other operator did not necessarily publish.
function baseRowFor(
  qso: Record<string, unknown>,
  operation: Record<string, unknown>,
  stationCall: string,
  timeOffsetMillis: number,
  includePrivateData: boolean,
  /// The export's `op`/`log`/`app` values, built once for the whole file —
  /// only `qso` changes per contact, and rebuilding the rest ten thousand
  /// times would be the expensive half of a large export.
  exportContext: Record<string, unknown>,
): string {
  const our = (qso.our ?? {}) as Record<string, unknown>
  const their = (qso.their ?? {}) as Record<string, unknown>
  // The merged lookup guess
  // stays nested under `their.guess` rather than flattened onto
  // `their` itself — fall back to it for fields the operator never
  // manually entered, same convention as app-polo's ADIF exporter.
  const theirGuess = (their.guess ?? {}) as Record<string, unknown>
  const startAtMillis = Number(qso.startAtMillis ?? 0)
  const [mode, submode] = adifModeAndSubmodeForMode(String(qso.mode ?? 'SSB'))
  const freqKHz = Number(qso.freq ?? 0)

  let row = ''
  row += field('CALL', their.call)
  if (startAtMillis > 0) {
    row += field('QSO_DATE', fmtADIFDate(startAtMillis + timeOffsetMillis))
    row += field('TIME_ON', fmtADIFTime(startAtMillis + timeOffsetMillis))
  }
  row += field('BAND', qso.band)
  if (freqKHz > 0) row += field('FREQ', (freqKHz / 1000).toFixed(6).replace(/0+$/, '').replace(/\.$/, ''))
  row += field('MODE', mode)
  row += field('SUBMODE', submode)
  row += field('RST_SENT', our.sent)
  row += field('RST_RCVD', their.sent)
  row += field('STATION_CALLSIGN', stationCall)
  // Only when it says something STATION_CALLSIGN doesn't: a single operator
  // running their own call would otherwise write their call twice into every
  // record. A deliberate divergence from app-polo, which writes OPERATOR on
  // every record (`qsonToADIF.js`, falling back to the station call).
  //
  // Case-insensitive and trimmed: the dialog and the OPER command uppercase
  // what they store, but a WSJT-X or N1MM capture keeps whatever the datagram
  // spelled, and `ki2d` against a station running `KI2D` is the same operator.
  const operatorCall = String(our.operatorCall ?? '').trim()
  if (operatorCall && operatorCall.toUpperCase() !== stationCall.trim().toUpperCase()) {
    row += field('OPERATOR', operatorCall)
  }
  if (includePrivateData) {
    row += field('NAME', their.name ?? theirGuess.name)
    row += field('QTH', their.city ?? theirGuess.city)
  }
  // STATE and COUNTRY stay: awards are claimed on them, and both are
  // implied by the callsign anyway. app-polo draws the line in the same
  // place.
  row += field('STATE', their.state ?? theirGuess.state)
  row += field('COUNTRY', their.country ?? theirGuess.country)
  // Our own location always goes out, at SIX characters — the field award
  // programs read, and a ~9 x 5 km square, which is what an operator has always
  // put on the air. The finer forms below ride `includePrivateData`, so the
  // stored locator is truncated here rather than written as-is: an operation
  // set from a GPS fix stores eight characters, and shipping those ungated
  // would state the operator's position to a few hundred metres through the
  // very switch that withholds the coordinate they came from.
  //
  // A QSO's own `our.grid` wins over the operation's throughout: QSON allows
  // the station to move mid-operation, and the contact records where it was
  // actually made from.
  const ourGrid = (our.grid ?? operation.grid) as string | undefined
  row += field('MY_GRIDSQUARE', includePrivateData ? ourGrid : coarseGrid(ourGrid))

  if (includePrivateData) {
    // ADIF names no field for a multi-station operating position, so this is
    // ours (`adif_to_qson.dart` reads it back). Private: which of a station's
    // positions made the contact is its internal layout, not something the
    // contact itself says, and no program asks for it.
    row += field('APP_HAM2K_POSITION', our.multiIdentifier)
    row += field('GRIDSQUARE', their.grid ?? theirGuess.grid)
    // Coordinates ride with the gridsquare, and for the same reason: where the
    // other operator is, to a few hundred metres, is not something the contact
    // itself says. Ours goes out under the same switch — a log uploaded to a
    // program's servers would otherwise publish the operator's own address.
    const theirs = theirCoordinate(their, theirGuess)
    row += field('LAT', formatAdifCoordinate(theirs?.lat, 'lat'))
    row += field('LON', formatAdifCoordinate(theirs?.lon, 'lon'))
    row += field('MY_LAT', formatAdifCoordinate(our.lat ?? operation.lat, 'lat'))
    row += field('MY_LON', formatAdifCoordinate(our.lon ?? operation.lon, 'lon'))
  }

  // Built once, on the first field that will actually render — `qsoValues`
  // formats four dates and copies the contact, per RECORD, and with private
  // data off every template below is skipped, which is the common case for
  // an upload.
  let textContext: Record<string, unknown> | undefined
  for (const textField of TEXT_FIELD_TEMPLATES) {
    if (textField.template === '') continue
    if (textField.private && !includePrivateData) continue
    textContext ??= { ...exportContext, qso: qsoValues(qso as Record<string, JSONValue>) }
    // Not caught: these templates are ours, so a throw here is a bug in one
    // of them and belongs in front of whoever changed it. An operator's own
    // template reaching this table is a later feature, and the settings
    // screen that accepts it is where a typo has to be reported.
    row += field(textField.name, renderTemplate(textField.template, textContext, `ADIF ${textField.name}`))
  }
  return row
}

/// Each `adifFields` hook's contribution, as a list of field sets — one per
/// ADIF record that hook wants written. Almost every hook returns exactly one.
/// An activity whose programs allow several references at once (a POTA n-fer)
/// returns one set per reference: the contact is submitted as one record each,
/// which is also why it counts once per reference toward an activation
/// (docs/design/activities.md §3.2, §4).
///
/// A hook declaring BOTH methods is asked only for its combinations — the same
/// way app-polo asks only its "main handler" — or its plain fields would be
/// written a second time into every record.
///
/// [mainHandler] is the extension whose export this file is: named, it is the
/// only hook asked — plus whatever it listed in [includeFieldsFrom] — because a
/// file submitted to one program is that program's log
/// (`ExportRequest.mainHandler`). Unnamed — the full ADIF export, which claims
/// no program — every hook contributes, which is polo's `includeOtherRefs`.
///
/// The hooks are asked in that order, the main handler first, which is the
/// order their fields land in a record — except where an included hook answers
/// `fieldCombinationsForOneQSO` and the main handler only answers the plain
/// method, since combinations are collected first. No current pairing does.
async function fieldSetsPerHook(
  qso: Record<string, unknown>,
  operation: Record<string, unknown>,
  mainHandler?: string,
  includeFieldsFrom?: string[],
): Promise<AdifField[][][]> {
  const byHook = new Map<string, AdifField[][]>()
  const keys = mainHandler ? [mainHandler, ...(includeFieldsFrom ?? [])] : undefined
  const invoke = async (method: string) =>
    keys
      ? (await Promise.all(keys.map((key) => hooks.invokeOne('adifFields', key, method, { qso, operation })))).flat()
      : hooks.invokeAll('adifFields', method, { qso, operation })

  const combined = await invoke('fieldCombinationsForOneQSO')
  for (const entry of combined) {
    if (!entry.ok || !Array.isArray(entry.value)) continue
    const sets = (entry.value as AdifField[][]).filter((set) => Array.isArray(set))
    if (sets.length > 0) byHook.set(entry.key, sets)
  }

  const single = await invoke('fieldsForOneQSO')
  for (const entry of single) {
    if (byHook.has(entry.key)) continue
    if (!entry.ok || !Array.isArray(entry.value)) continue
    byHook.set(entry.key, [entry.value as AdifField[]])
  }

  // Nothing below applies to the full ADIF export, which asks everyone and
  // takes what it gets — one activity's broken hook must not cost the operator
  // the whole-log backup. A file that claims ONE program is the strict case.
  if (keys) {
    const asked = [...combined, ...single]
    // A handler with no `adifFields` registration answers NEITHER method — the
    // records above are filtered to hooks that implement the method, so an
    // entry means the hook ran. Without its fields the file goes out with no
    // MY_SIG, no MY_POTA_REF, no CONTEST_ID: submittable-looking and claiming
    // nothing, the same failure `activityExportHook.generateExport` refuses a
    // stale reference for, reached by a key misspelled or renamed on one of
    // the two registrations that have to agree.
    //
    // Only the MAIN handler, though: a `includeFieldsFrom` key that answers
    // nothing at all is an extension the operator turned off, and the file is
    // still the program's log without it.
    if (mainHandler && !asked.some((entry) => entry.key === mainHandler)) {
      throw new Error(`adif: no adifFields hook registered for main handler '${mainHandler}'`)
    }
    // Whoever it was, a hook that ANSWERED and then threw is a bug, not a
    // setting — and the collecting loops above skip it in silence, so the file
    // would lose those fields and say so nowhere. It is the likelier road to
    // an empty claim than a misspelled key, since a hook reading its data
    // through the host fails on a bad day rather than on a bad build; and for
    // a listed hook it is the difference between POTA's file recording a
    // satellite contact and recording it as terrestrial. A hook that runs and
    // finds nothing to say answers `ok` with an empty list, and is none of
    // this — as is a hook that doesn't implement the method at all, which
    // answers not at all.
    const broken = asked.find((entry) => !entry.ok || !Array.isArray(entry.value))
    if (broken) {
      const why = broken.ok ? 'returned no field list' : `failed: ${broken.error ?? 'unknown error'}`
      throw new Error(`adif: the '${broken.key}' adifFields hook ${why}`)
    }
  }

  return [...byHook.values()]
}

const ExportHandler = {
  async suggestExportOptions(
    { operation, qsos, compactFilenames }: ExportOptionsRequest,
    _ctx: HookContext,
  ): Promise<ExportOption[]> {
    return [
      {
        exportType: 'adif',
        format: 'adif',
        // "Full", because this is the whole log — the one export that claims
        // no activity and slices nothing. The activity and contest exports
        // above it in the list each cover one reference.
        label: 'Full ADIF Export',
        filename: filenameFor(operation, qsos, compactFilenames),
        icon: 'file-export',
        // Neutral grey, because this export belongs to no activity — the
        // coloured rows above it each claim one, and the whole log claims
        // none.
        color: '#9E9E9E',
        // The whole-log backup is complete by definition — it is the copy the
        // operator keeps, not one they upload, so the private-data setting
        // does not apply to it.
        alwaysIncludePrivateData: true,
        selectedByDefault: true,
        // Sorts BELOW every activity's and contest's own export (all
        // priority 0), because those are the ones an operator came here to
        // submit; the whole-log ADIF is the backup they take as well. Same
        // value app-polo gives it. The dev-mode QSON dump stays last at -100.
        priority: -1,
      },
    ]
  },

  async generateExport(
    { operation, qsos, compactFilenames, includePrivateData, mainHandler, includeFieldsFrom }: ExportRequest,
    ctx: HookContext,
  ): Promise<ExportResult> {
    const stationCall = String(operation.stationCall ?? 'UNKNOWN')
    const title = String(operation.title ?? '')

    const lines: string[] = []
    // The operation's TITLE is the operator's own words — "Dad's memorial
    // activation" — so it belongs to the same private set as the per-QSO
    // notes below, and app-polo gates it identically
    // (`qsonToADIF.js:58`, `operation.userTitle && privateData`). Without
    // this the switch would strip every field a program might read while
    // still shipping the one line the operator wrote themselves.
    const preamble = includePrivateData === true ? [stationCall, title] : [stationCall]
    lines.push(`ADIF export for ${preamble.filter((x) => x).join(' — ')}`)
    lines.push(field('ADIF_VER', ADIF_VERSION))
    lines.push(field('PROGRAMID', ctx.appName ?? DEFAULT_PROGRAM_ID))
    lines.push(field('CREATED_TIMESTAMP', `${fmtADIFDate(Date.now())} ${fmtADIFTime(Date.now())}`))
    lines.push('<EOH>')
    lines.push('')

    const exportContext = templateContext({
      operation,
      qsoCount: qsos.length,
      appName: ctx.appName,
      // The operation's row columns don't cross the bridge, so the log's own
      // day comes from its first contact — the same instant the filename
      // uses, so a file and the fields inside it cannot disagree about when
      // the operation was.
      atMillis: startMillisOf(operation, qsos),
      log: { station: stationCall, format: 'adif', exportType: 'adif', extension: 'adi', compact: compactFilenames },
    })

    for (const qso of qsos) {
      // The program fields (SIG, POTA_REF…) come from an `adifFields` hook via
      // in-runtime hook composition — no bridge crossing. Which hooks, see
      // [fieldSetsPerHook]: this export's own alone, or every one of them when
      // the file claims no program.
      const perHook = await fieldSetsPerHook(qso, operation, mainHandler, includeFieldsFrom)
      // One record per QSO unless a hook expands it. In practice at most one
      // does — you are not activating an n-fer in two programs at once — so the
      // record count is simply the largest any hook asked for.
      const recordCount = Math.max(1, ...perHook.map((sets) => sets.length))

      for (let n = 0; n < recordCount; n++) {
        // Records split out of one contact would otherwise be identical, and a
        // log processor is entitled to read that as a duplicate. app-polo
        // shifts each by a second (`qsonToADIF.js:144`); so do we.
        let row = baseRowFor(qso, operation, stationCall, n * 1000, includePrivateData === true, exportContext)
        for (const sets of perHook) {
          // A hook with a single set describes the contact rather than one of
          // its records, so it belongs on all of them.
          const set = sets.length === 1 ? sets[0] : sets[n]
          if (!set) continue
          for (const extra of set) row += field(extra.name, extra.value)
        }
        row += '<EOR>'
        lines.push(row)
      }
    }

    return {
      filename: filenameFor(operation, qsos, compactFilenames),
      mimeType: 'application/octet-stream',
      content: lines.join('\n') + '\n',
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('export', { hook: ExportHandler, key: 'adif' })
  },
})
