// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ADIF export. Lives in the extension runtime (DESIGN.md §4: export hooks are
// extension territory) and reuses the published ham-js-libs for dates and
// mode/submode mapping. The contact's own fields are written directly, not
// through app-polo's template layer — activity/contest extensions contribute
// their program's fields via `adifFields` hooks. The three FREE-TEXT fields
// are the exception, and are templated: see [TEXT_FIELD_TEMPLATES].

import { exportQso } from "@ham2k/extension-sdk"
import { fmtADIFDate, fmtADIFTime } from "@ham2k/lib-format-tools"
import { locationToGrid6, locationToGrid8 } from "@ham2k/lib-geo-tools"
import { adifModeAndSubmodeForMode } from "@ham2k/lib-operation-data"

import {
  defineExtension,
  entityForCall,
  expectedSideband,
  hooks,
  oneLine,
  operationForQso,
  qsoValues,
  renderTemplate,
  startMillisOf,
  templateContext,
} from "@ham2k/extension-sdk"
import type { ExportOption, ExportOptionsRequest, ExportRequest, ExportResult, HookContext, JSONValue } from "@ham2k/extension-sdk"

import manifest from "../manifest.json" with { type: "json" }
import { formatAdifCoordinate } from "./coordinates.ts"
import { isGridCenter } from "./grid.ts"
import { adifCounty } from "./county.ts"
import { field, renderRow } from "./fields.ts"
import type { AdifField } from "./fields.ts"
import { filenameFor } from "./filename.ts"

const ADIF_VERSION = '3.1.5'
const DEFAULT_PROGRAM_ID = 'Ham2K Logger'

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
///
/// Neither is a pair that is only the entered grid's own center
/// (`isGridCenter`). The operator typing a locator stated a square, and the
/// square is already going out as `GRIDSQUARE` — writing its middle as
/// `LAT`/`LON` too would publish a point they never claimed, and would take
/// precedence over the square for every reader.
function theirCoordinate(
  their: Record<string, unknown>,
  theirGuess: Record<string, unknown>,
): { lat: unknown; lon: unknown } | undefined {
  if (
    their.locSource !== 'prefix' &&
    their.lat != null &&
    their.lon != null &&
    !isGridCenter(their.lat, their.lon, their.grid)
  ) {
    return { lat: their.lat, lon: their.lon }
  }
  if (their.grid != null) return undefined
  if (theirGuess.locSource === 'prefix') return undefined
  return { lat: theirGuess.lat, lon: theirGuess.lon }
}

/// A locator cut back to [digits] characters — the enclosing square, so the
/// result is still a true statement about where the station was, just a
/// coarser one. Shorter locators are already coarse and pass through
/// unchanged.
function coarseGrid(grid: string | undefined, digits = 6): string | undefined {
  return typeof grid === 'string' ? grid.slice(0, digits) : undefined
}

/// The locator a file states for one end of a contact: derived from the
/// coordinate at [digits] characters where there is a real one, otherwise the
/// stored grid cut back to the same length.
///
/// The same answer `gridForDisplay` gives on screen, and by the same two
/// rules, because a file and a screen must not state the station's position
/// differently. Truncating the stored string would not do it in EITHER
/// direction: an operation adopted from a fix stores its locator at whatever
/// precision was in force then, so a later switch to eight characters would
/// show `FN21rq56` and write `FN21rq` — and a locator that was STATED, with
/// no coordinate to derive from, is a datum in its own right and goes out as
/// written however short [digits] is. On the air a received grid IS the
/// exchange; coarsening what the other station sent is not a claim this app
/// gets to make.
///
/// So [digits] governs only a DERIVED locator. Where a caller needs a
/// ceiling on the answer as well — `MY_GRIDSQUARE` does, because withholding
/// private data must withhold the precision that rides with it — it applies
/// one to the result.
function gridForExport(grid: unknown, lat: unknown, lon: unknown, digits: number): string | undefined {
  const stored = typeof grid === 'string' ? grid : undefined
  if (typeof lat === 'number' && typeof lon === 'number' && !isGridCenter(lat, lon, stored)) {
    return digits >= 8 ? locationToGrid8(lat, lon) : locationToGrid6(lat, lon)
  }
  return stored
}

/// One side's county as ADIF's `CNTY`, from the record that holds it.
///
/// [claimedState] is what this record's `STATE`/`MY_STATE` says. A county
/// carrying a state of its own that has been overruled describes somewhere the
/// record does not claim to have been, and writing it under either state makes
/// the record contradict itself — so it is dropped instead.
function countyFor(source: Record<string, unknown>, claimedState: unknown): string | undefined {
  const own = source.state
  if (typeof own === 'string' && typeof claimedState === 'string' && own.trim() !== '') {
    if (own.trim().toUpperCase() !== claimedState.trim().toUpperCase()) return undefined
  }
  return adifCounty(source.county, claimedState)
}

/// ADIF frequencies are MHz to six decimals (Hz), with the trailing zeroes
/// trimmed; QSON keeps kHz.
function formatAdifFreq(freqKHz: number): string {
  return (freqKHz / 1000).toFixed(6).replace(/0+$/, '').replace(/\.$/, '')
}

/// ADIF's three free-text fields, as templates over the standard vocabulary
/// (docs/extensions/templates.md) — the same engine that names the file.
/// app-polo templates exactly these three (`ADIFNotesTemplate`,
/// `ADIFCommentTemplate`, `ADIFQslMsgTemplate`).
///
/// NOTES and COMMENT are app-polo's defaults verbatim (`basePartialTemplates`:
/// `ADIFNotes`, `ADIFComment`). QSLMSG writes the same field from the same
/// source and deliberately not the same text: polo joins each ref's decorated
/// `shortLabel`/`label`, and a ref crosses into this runtime as the raw QSON
/// `{type, ref}` it is stored as, with no label on it. The reference itself is
/// what a card needs to name anyway.
///
/// `multiline` is ADIF's own type split: NOTES is a MultilineString and keeps
/// the operator's line breaks; COMMENT and QSLMSG are Strings, which exclude
/// them, so a two-line note written into COMMENT verbatim is a field a strict
/// reader rejects.
///
/// Export settings can replace these defaults; invalid templates report
/// their errors in the editor before they can be saved.
///
/// `private` is the whole of the split: COMMENT says what NOTES says, so it
/// is withheld on the same switch — a file uploaded to a program's servers
/// must not carry the operator's own words about who they met through a field
/// whose name happens to be different. polo reaches the same result by
/// blanking `qso.notes` in the template context.
///
/// QSLMSG is the operation's references — what goes on the card, and public
/// by construction: `op.refs` is the operation's own claim, `compact` drops
/// the entries that carry no reference (a contest's, say).
///
/// `wholeLogOnly` is the other axis, and QSLMSG is the only field on it:
/// `op.refs` is EVERY program the operation claimed, so a file submitted to
/// one of them would carry the others' references in a free-text field — the
/// leak [fieldSetsPerHook] exists to prevent, arriving through the one part of
/// a record it does not govern. Such a file already states its own reference
/// in MY_SIG_INFO, so it loses nothing.
const TEXT_FIELD_TEMPLATES: {
  name: string
  template: string
  private: boolean
  wholeLogOnly: boolean
  multiline: boolean
  /// Whether the template reads the CONTACT. One that doesn't renders once for
  /// the file — QSLMSG names the operation's references and says the same
  /// thing on every record, and a whole-log export of 38k contacts would
  /// otherwise run 38k liquid renders for one string, each of them first
  /// building a per-QSO context it has no use for.
  ///
  /// That makes QSLMSG the one field here that is NOT segment-aware: a rover
  /// who activated a second park at a break gets the operation's current refs
  /// on every record, the earlier contacts included. `op.refs` is the
  /// operation's own claim and an export hook is handed one operation, so
  /// saying otherwise needs the refs to reach the template per contact, which
  /// is a different shape than a QSL message.
  usesQso: boolean
}[] = [
  { name: 'NOTES', template: '{{ qso.notes }}', private: true, wholeLogOnly: false, multiline: true, usesQso: true },
  {
    name: 'COMMENT',
    template: '{{ qso.notes }}',
    private: true,
    wholeLogOnly: false,
    multiline: false,
    usesQso: true,
  },
  {
    name: 'QSLMSG',
    template: '{{ op.refs | map: "ref" | compact | join: ", " }}',
    private: false,
    wholeLogOnly: true,
    multiline: false,
    usesQso: false,
  },
]

/// One free-text template, rendered. Shared by the per-record loop and the
/// once-per-file one so the two cannot disagree about line handling.
///
/// Not caught: these templates are ours, so a throw here is a bug in one of
/// them and belongs in front of whoever changed it. An operator's own template
/// reaching this table is a later feature, and the settings screen that
/// accepts it is where a typo has to be reported.
function renderTextField(
  textField: (typeof TEXT_FIELD_TEMPLATES)[number],
  context: Record<string, unknown>,
): AdifField {
  const rendered = renderTemplate(textField.template, context, `ADIF ${textField.name}`)
  return { name: textField.name, value: textField.multiline ? rendered : oneLine(rendered) }
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
function baseFieldsFor(
  qso: Record<string, unknown>,
  operation: Record<string, unknown>,
  stationCall: string,
  timeOffsetMillis: number,
  includePrivateData: boolean,
  /// How many characters our own locator is written with — the operator's
  /// Grid Precision setting, capped at six wherever private data is withheld
  /// (see MY_GRIDSQUARE below).
  /// How many characters a DERIVED locator is written with — the operator's
  /// Grid Precision. `MY_GRIDSQUARE` caps its own answer at this too, and at
  /// six wherever private data is withheld (see there).
  gridDigits: number,
  /// The export's `op`/`log`/`app` values, built once for the whole file —
  /// only `qso` changes per contact, and rebuilding the rest ten thousand
  /// times would be the expensive half of a large export.
  exportContext: Record<string, unknown>,
  /// Our own station's DXCC entity, also resolved once for the whole file:
  /// it follows from the station callsign, and this file is one station's.
  ourEntity: ReturnType<typeof entityForCall>,
  /// The free-text templates this file writes — [TEXT_FIELD_TEMPLATES] with
  /// the ones this file withholds already removed, since what it withholds is
  /// a property of the file and not of the contact.
  textFields: typeof TEXT_FIELD_TEMPLATES,
  /// The free-text fields that say the same thing on every record, rendered
  /// once for the whole file.
  constantTextFields: AdifField[],
): AdifField[] {
  const our = (qso.our ?? {}) as Record<string, unknown>
  const their = (qso.their ?? {}) as Record<string, unknown>
  // The merged lookup guess
  // stays nested under `their.guess` rather than flattened onto
  // `their` itself — fall back to it for fields the operator never
  // manually entered, same convention as app-polo's ADIF exporter.
  const theirGuess = (their.guess ?? {}) as Record<string, unknown>
  const startAtMillis = Number(qso.startAtMillis ?? 0)
  const endAtMillis = Number(qso.endAtMillis ?? 0)
  const [mode, submode] = adifModeAndSubmodeForMode(String(qso.mode ?? 'SSB'))
  const freqKHz = Number(qso.freq ?? 0)
  // Read once: `STATE` writes it, and the county below is qualified by it.
  const theirState = their.state ?? theirGuess.state

  const fields: AdifField[] = []
  const add = (name: string, value: unknown) => fields.push({ name, value })
  add('CALL', their.call)
  if (startAtMillis > 0) {
    add('QSO_DATE', fmtADIFDate(startAtMillis + timeOffsetMillis))
    add('TIME_ON', fmtADIFTime(startAtMillis + timeOffsetMillis))
    // Only a contact that recorded an end, and only one that ends after it
    // began: QSON defaults `endAtMillis` to the start where nothing measured a
    // duration, and TIME_OFF equal to TIME_ON tells a reader the contact took
    // no time rather than that nobody timed it. QSO_DATE_OFF rides along only
    // when the contact crossed midnight, which is the case it exists for.
    if (endAtMillis > startAtMillis) {
      add('TIME_OFF', fmtADIFTime(endAtMillis + timeOffsetMillis))
      const dateOff = fmtADIFDate(endAtMillis + timeOffsetMillis)
      if (dateOff !== fmtADIFDate(startAtMillis + timeOffsetMillis)) add('QSO_DATE_OFF', dateOff)
    }
  }
  add('BAND', qso.band)
  if (freqKHz > 0) add('FREQ', formatAdifFreq(freqKHz))
  add('MODE', mode)
  // ADIF spells voice SSB as MODE=SSB with SUBMODE=USB/LSB, and which sideband
  // you run belongs to where you are — a file that states it on every phone
  // contact is stating the obvious, and readers that show the submode then
  // report a single-mode log as two modes.
  //
  // Dropped only on a POSITIVE match with the sideband that place runs, never
  // merely because nothing contradicts it. "Nothing contradicts it" is also
  // true of a contact stating neither a frequency nor a band, and there
  // nothing can re-derive what was dropped, so the sideband would leave the
  // log for good. Every other submode (FT4 under MFSK) is unconditional:
  // those name the emission, and dropping one loses which mode was worked.
  const sidebandSubmode = submode === 'USB' || submode === 'LSB'
  const bandsSideband = expectedSideband({
    freqKHz: freqKHz > 0 ? freqKHz : undefined,
    band: qso.band == null ? undefined : String(qso.band),
  })
  add('SUBMODE', sidebandSubmode && submode === bandsSideband ? undefined : submode)
  add('RST_SENT', our.sent)
  add('RST_RCVD', their.sent)
  add('STATION_CALLSIGN', stationCall)
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
    add('OPERATOR', operatorCall)
  }
  add('TX_PWR', qso.power)
  add('RX_PWR', their.power ?? theirGuess.power)
  // A split contact's receive side, which QSON records on `their` — the
  // frequency we LISTENED on. Only when it differs from the transmit
  // frequency, which is how `adif_to_qson.dart` decides it is a split in the
  // first place; writing FREQ_RX equal to FREQ says "split" about a contact
  // that wasn't one.
  //
  // BAND_RX has an owner elsewhere: `activities/satellites` writes the
  // transponder's downlink band, and AO-7 answers on 10m from one transponder
  // and 2m from the other. Base fields are written first and a name goes to
  // the first value that fills it ([renderRow]), so on an imported satellite
  // log the measured receive frequency decides and the transponder table does
  // not. That is the right answer for a contact that recorded what it actually
  // heard — but it is the opposite of who owns the field, so a satellite log
  // whose FREQ_RX is wrong now says so twice.
  const theirFreqKHz = Number(their.freq ?? 0)
  if (theirFreqKHz > 0 && theirFreqKHz !== freqKHz) {
    add('FREQ_RX', formatAdifFreq(theirFreqKHz))
    add('BAND_RX', their.band)
  }
  if (includePrivateData) {
    add('NAME', their.name ?? theirGuess.name)
    add('QTH', their.city ?? theirGuess.city)
    add('EMAIL', their.email ?? theirGuess.email)
  }
  // STATE and COUNTRY stay: awards are claimed on them, and both are
  // implied by the callsign anyway. app-polo draws the line in the same
  // place — and the entity fields below say no more than COUNTRY already
  // does, in the numeric and zone forms the award programs actually read.
  add('STATE', theirState)
  add('COUNTRY', their.country ?? theirGuess.country)
  // The county is on this side of the line rather than with the town above,
  // a deliberate divergence from app-polo, which gates it. In a QSO party the
  // county IS the exchange — the other station said it on the air, and a file
  // that withholds it claims nothing the event scores on.
  //
  // County and state are read from ONE source, and that source's state has to
  // be the one the record CLAIMS. An operator correcting a bad lookup's state
  // leaves its county behind: qualify it with the correction and the file says
  // Hartford County, Ontario; qualify it with the guess and STATE and CNTY
  // name two different primary subdivisions. Neither is a true statement about
  // the contact, so a county whose own state has been overruled is not
  // exported at all.
  add('CNTY', countyFor(their.county != null ? their : theirGuess, theirState))
  add('DXCC', their.dxccCode ?? theirGuess.dxccCode)
  // Whatever the log HOLDS, never a zone worked out here: an export states
  // what the app knows about a contact, and resolving a callsign is the lookup
  // layer's job, done once when the contact is logged. A guess made at export
  // time would also be a different answer from the one the operator saw.
  add('CQZ', their.cqZone ?? theirGuess.cqZone)
  add('ITUZ', their.ituZone ?? theirGuess.ituZone)
  add('CONT', their.continent ?? theirGuess.continent)
  add('REGION', their.regionCode ?? theirGuess.regionCode)
  // No PFX. ADIF's is the contacted station's WPX PREFIX — `W1` for W1AW —
  // and QSON's `entityPrefix` is its DXCC entity's, `K`. Writing one as the
  // other reads back correctly through our own importer and hands a contest
  // robot the wrong multiplier. Exporting it needs a WPX prefix worked out
  // where the contact is logged, not a near-miss substituted here.
  // Our own location always goes out, at the operator's own Grid Precision —
  // the claim they make everywhere else in the app, so a file and a screen
  // never state the station's position differently. Derived from the stored
  // COORDINATE where there is one rather than cut from the stored string,
  // which was written at whatever precision was in force when the location
  // was set ([gridForExport]).
  //
  // Six is the ceiling wherever private data is withheld, whatever the
  // setting: eight characters is a ~700 x 460 m square, and shipping that
  // ungated would state the operator's position to a few hundred metres
  // through the very switch that withholds the coordinate it came from. Six
  // is also what the field award programs read, and what an operator has
  // always put on the air.
  //
  // A QSO's own `our.grid` wins over the operation's throughout: QSON allows
  // the station to move mid-operation, and the contact records where it was
  // actually made from.
  // ONE source for the whole group, never a field at a time. A grid and a
  // coordinate are two statements about one place, and a contact that names a
  // location at all replaces BOTH (`OperationLocationScreen`) — so coalescing
  // them apart pairs a contact's own grid, or a segment's, with whatever
  // coordinate the base operation last held. A rover exports MY_GRIDSQUARE in
  // California beside MY_LAT/MY_LON in Nevada, and locations.md's rule says
  // the coordinate wins, so the record reads as a place the operator never
  // claimed.
  const ourLocation = our.grid != null || our.lat != null || our.lon != null ? our : operation
  const ourGrid = ourLocation.grid as string | undefined
  const ourDigits = includePrivateData ? gridDigits : 6
  // Capped as well as derived, unlike the worked station's below: a stored
  // locator finer than the ceiling (an operation set from a fix before the
  // setting was turned down, or read back out of an ADIF file) would
  // otherwise ship the position the switch is withholding the coordinate for.
  add('MY_GRIDSQUARE', coarseGrid(gridForExport(ourGrid, ourLocation.lat, ourLocation.lon, ourDigits), ourDigits))

  // Our own side of what the `their` fields say about theirs. [ourEntity] is
  // the FALLBACK: an operation stores no entity data, so these three are
  // resolved from the station callsign, which settles an entity outright. A
  // contact that CARRIES one outranks that — an ADIF import writes
  // `our.entityName`/`dxccCode`/`continent` (`adif_to_qson.dart`), and a log
  // made from Hawaii under a mainland call says 110 where the callsign says
  // 291. Re-deriving would answer the wrong entity through the very round trip
  // these fields exist to keep whole.
  const ourState = our.state ?? operation.state
  add('MY_STATE', ourState)
  add('MY_COUNTRY', our.entityName ?? our.country ?? ourEntity.entityName)
  add('MY_DXCC', our.dxccCode ?? ourEntity.dxccCode)
  add('MY_CONT', our.continent ?? ourEntity.continent)
  add('MY_REGION', our.regionCode)
  // The zones are NOT derived: a callsign says which entity a station is in,
  // never which zone of one. Only the contact answers — an ADIF import writes
  // `our.cqZone`/`ituZone`, and nothing else does yet — and a contact that
  // does not leaves them for an extension's `adifFields` hook, which can take
  // them because a name this record never writes is a name still free to claim
  // ([renderRow]).
  add('MY_CQ_ZONE', our.cqZone)
  add('MY_ITU_ZONE', our.ituZone)
  // The station's own equipment, which QSON records per contact because an
  // operator swaps antennas mid-operation. Not private: what was on the air
  // is what the contact was made with.
  add('MY_RIG', our.rig)
  add('MY_ANTENNA', our.antenna)
  // Public for the same reason theirs is, and on the same terms: one source
  // for the pair, since `segmentOverrideKeys` carries `state` and `county`
  // separately and a segment that moved to a new county must not be read
  // beside an operation that never left its state.
  add('MY_CNTY', countyFor(our.county != null ? our : operation, ourState))

  if (includePrivateData) {
    // ADIF names no field for a multi-station operating position, so this is
    // ours (`adif_to_qson.dart` reads it back). Private: which of a station's
    // positions made the contact is its internal layout, not something the
    // contact itself says, and no program asks for it.
    add('APP_HAM2K_POSITION', our.multiIdentifier)
    // Coordinates ride with the gridsquare, and for the same reason: where the
    // other operator is, to a few hundred metres, is not something the contact
    // itself says. Ours goes out under the same switch — a log uploaded to a
    // program's servers would otherwise publish the operator's own address.
    const theirs = theirCoordinate(their, theirGuess)
    // Their square, derived from that same coordinate where there is one, at
    // the operator's own Grid Precision — the claim every screen in the app
    // makes about this station, so a file cannot state a different one. The
    // stored string alone would not do it: a lookup's coordinate is filed
    // beside a six-character grid whatever precision is in force. No ceiling
    // here as there is on MY_GRIDSQUARE, in either sense — this block already
    // rides `includePrivateData`, which is the gate that ceiling stands in
    // for, and a grid the other station SENT is their exchange, not ours to
    // coarsen to our own display preference.
    add('GRIDSQUARE', gridForExport(their.grid ?? theirGuess.grid, theirs?.lat, theirs?.lon, gridDigits))
    add('LAT', formatAdifCoordinate(theirs?.lat, 'lat'))
    add('LON', formatAdifCoordinate(theirs?.lon, 'lon'))
    // Our own side, under the same rule as [theirCoordinate]: a pair that is
    // only the stated grid's center says nothing `MY_GRIDSQUARE` did not, and
    // a reader would take it as the finer of the two.
    const ourStatedSquare = isGridCenter(ourLocation.lat, ourLocation.lon, ourGrid)
    add('MY_LAT', ourStatedSquare ? undefined : formatAdifCoordinate(ourLocation.lat, 'lat'))
    add('MY_LON', ourStatedSquare ? undefined : formatAdifCoordinate(ourLocation.lon, 'lon'))
  }

  // Built once per record, on the first field that will actually render —
  // `qsoValues` formats four dates and copies the contact, and a record whose
  // templates are all withheld must not pay for it.
  let textContext: Record<string, unknown> | undefined
  for (const textField of textFields) {
    textContext ??= { ...exportContext, qso: qsoValues(exportQso(qso as Record<string, JSONValue>, { includePrivateData })) }
    fields.push(renderTextField(textField, textContext))
  }
  // Last, keeping the order the table declares.
  fields.push(...constantTextFields)
  return fields
}

/// The station's own ARRL section, written AFTER every hook's fields rather
/// than with the rest of the contact's.
///
/// `renderRow` keeps the first field of a given name, and the contact's own
/// fields are pushed ahead of any hook's — the right rule everywhere else,
/// and the wrong one here. Field Day and Winter Field Day both answer
/// `ARRL_SECT` from the section the other station SENT (their `location` on
/// the contest ref), and that is what a contest submission has to carry: it
/// is what went over the air, checked against the log at the other end. The
/// value in `their.arrlSection` is an attribute of the station, entered in
/// the More pane or supplied by a lookup, and a submission carrying it in
/// place of the exchange is wrong in a way nothing downstream can catch.
///
/// So it goes last and fills the gap only when no contest claimed the field.
function stationSectionFieldsFor(qso: Record<string, unknown>): AdifField[] {
  const their = (qso.their ?? {}) as Record<string, unknown>
  const theirGuess = (their.guess ?? {}) as Record<string, unknown>
  return [{ name: 'ARRL_SECT', value: their.arrlSection ?? theirGuess.arrlSection }]
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
/// A NAMED handler's sets come back in the order it asked, itself first — the
/// order their fields land in a record, and so, since a field name is written
/// once ([renderRow]), the order that decides a collision. That holds whichever
/// METHOD each hook answered: stateparks names `pota` in `includeFieldsFrom`,
/// and pota answers combinations where the contest answers plain fields, so
/// returning the combinations first would put the included hook ahead of the
/// file's own program.
///
/// The FULL export has no such order to restore. `invokeAll` answers in hook
/// priority order per method, but the two methods are two calls and a hook
/// answers only one of them, so the combination-answering hooks come first as a
/// group and nothing here can interleave them by priority. Which of two
/// programs keeps a shared MY_SIG is therefore not a decision anyone made — see
/// the file's own note on what that export cannot represent.
async function fieldSetsPerHook(
  qso: Record<string, unknown>,
  operation: Record<string, unknown>,
  mainHandler?: string,
  includeFieldsFrom?: string[],
): Promise<AdifField[][][]> {
  const byHook = new Map<string, AdifField[][]>()
  // A handler that also lists itself is asked once: the map below would collapse
  // the second answer anyway, but not before running the hook a second time.
  const keys = mainHandler ? [...new Set([mainHandler, ...(includeFieldsFrom ?? [])])] : undefined
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

  return (keys ? keys.filter((key) => byHook.has(key)) : [...byHook.keys()]).map((key) => byHook.get(key)!)
}

const ExportHandler = {
  async getExportTypes() {
    return [{ exportType: 'adif', format: 'adif', label: 'Full ADIF Export', defaults: {
      includePrivateData: true,
      adifQslMessageTemplate: '{{ op.refs | map: "ref" | compact | join: ", " }}',
    } }]
  },
  async suggestExportOptions(
    { operation, qsos, compactFilenames }: ExportOptionsRequest,
    _ctx: HookContext,
  ): Promise<ExportOption[]> {
    return [
      {
        exportType: 'adif',
        templateData: { modifier: [String(operation.title ?? ''), 'Full'].filter(Boolean).join(' ') },
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
        // Legacy hosts include private data in whole-log backups. Hosts with
        // registered export settings use the operator’s per-type preference.
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
    { operation, qsos, segments, compactFilenames, includePrivateData, includeLookupData, exportSettings, exportData, exportTitle, mainHandler, includeFieldsFrom }: ExportRequest,
    ctx: HookContext,
  ): Promise<ExportResult> {
    if (includeLookupData === false) qsos = qsos.map((qso) => exportQso(qso, { includeLookupData: false }))
    const stationCall = String(operation.stationCall ?? 'UNKNOWN')
    const title = String(operation.title ?? '')
    // Once for the file: an ADIF export is one station's log, and a segmented
    // operation that changed call produces one file per call (the caller has
    // already picked which).
    const ourEntity = entityForCall(stationCall)
    // Decided once, for the file: what a template is withheld for is a
    // property of the export, not of the contact it would have been written on.
    const configured = TEXT_FIELD_TEMPLATES.map((field) => {
      const key = ({ NOTES: 'adifNotesTemplate', COMMENT: 'adifCommentTemplate', QSLMSG: 'adifQslMessageTemplate' } as const)[field.name as 'NOTES' | 'COMMENT' | 'QSLMSG']
      const custom = exportSettings?.[key]
      return typeof custom === 'string'
        ? { ...field, template: custom, wholeLogOnly: false, usesQso: true }
        : field
    })
    const writable = configured.filter(
      (textField) =>
        textField.template !== '' &&
        (includePrivateData === true || !textField.private) &&
        (mainHandler == null || !textField.wholeLogOnly),
    )
    const textFields = writable.filter((textField) => textField.usesQso)

    const lines: string[] = []
    // The operation's TITLE is the operator's own words — "Dad's memorial
    // activation" — so it belongs to the same private set as the per-QSO
    // notes below, and app-polo gates it identically
    // (`qsonToADIF.js:58`, `operation.userTitle && privateData`). Without
    // this the switch would strip every field a program might read while
    // still shipping the one line the operator wrote themselves.
    const preamble = exportTitle != null ? [exportTitle] : includePrivateData === true ? [stationCall, title] : [stationCall]
    lines.push(`ADIF export for ${preamble.filter((x) => x).join(' — ')}`)
    lines.push(field('ADIF_VER', ADIF_VERSION))
    lines.push(field('PROGRAMID', ctx.appName ?? DEFAULT_PROGRAM_ID))
    lines.push(field('CREATED_TIMESTAMP', `${fmtADIFDate(Date.now())} ${fmtADIFTime(Date.now())}`))
    lines.push('<EOH>')
    lines.push('')

    const exportContext = templateContext({
      operation: includePrivateData === true ? operation : { ...operation, title: '', userTitle: '', userNotes: '', grid: String(operation.grid ?? '').slice(0, 6) },
      qsoCount: qsos.length,
      appName: ctx.appName,
      // The operation's row columns don't cross the bridge, so the log's own
      // day comes from its first contact — the same instant the filename
      // uses, so a file and the fields inside it cannot disagree about when
      // the operation was.
      atMillis: startMillisOf(operation, qsos),
      log: { station: stationCall, format: 'adif', exportType: 'adif', extension: 'adi', compact: compactFilenames, ...exportData },
    })

    // The contact-independent half, rendered once now that `exportContext`
    // exists rather than once per record.
    const constantTextFields = writable
      .filter((textField) => !textField.usesQso)
      .map((textField) => renderTextField(textField, exportContext))

    for (const qso of qsos) {
      // The program fields (SIG, POTA_REF…) come from an `adifFields` hook via
      // in-runtime hook composition — no bridge crossing. Which hooks, see
      // [fieldSetsPerHook]: this export's own alone, or every one of them when
      // the file claims no program.
      //
      // Against the operation as it stood when THIS contact was made: a
      // rover's county or a contest's setup lives on a ref the segments
      // restate, and a hook handed the base operation would write the last
      // county onto every record of the log.
      const perHook = await fieldSetsPerHook(qso, operationForQso(operation, qso, segments), mainHandler, includeFieldsFrom)
      // One record per QSO unless a hook expands it. In practice at most one
      // does — you are not activating an n-fer in two programs at once — so the
      // record count is simply the largest any hook asked for.
      const recordCount = Math.max(1, ...perHook.map((sets) => sets.length))

      for (let n = 0; n < recordCount; n++) {
        // Records split out of one contact would otherwise be identical, and a
        // log processor is entitled to read that as a duplicate. app-polo
        // shifts each by a second (`qsonToADIF.js:144`); so do we.
        const fields = baseFieldsFor(
          qso,
          operation,
          stationCall,
          n * 1000,
          includePrivateData === true,
          ctx.gridPrecision ?? 6,
          exportContext,
          ourEntity,
          textFields,
          constantTextFields,
        )
        for (const sets of perHook) {
          // A hook with a single set describes the contact rather than one of
          // its records, so it belongs on all of them.
          const set = sets.length === 1 ? sets[0] : sets[n]
          if (!set) continue
          fields.push(...set)
        }
        fields.push(...stationSectionFieldsFor(qso as Record<string, unknown>))
        // Assembled and then rendered, rather than appended field by field, so
        // that two hooks naming the same field — an operation activating a park
        // and a summit both answer MY_SIG — write it once ([renderRow]).
        lines.push(renderRow(fields) + '<EOR>')
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
