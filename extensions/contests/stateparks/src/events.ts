// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The four state-park events, and one normalized view of them.
//
// `events/*.json` are app-polo's files VERBATIM (`src/extensions/contests/
// stateparks/states/`), so the yearly re-sync — dates move, park lists grow —
// stays a file copy and a legible diff against polo. Everything that reads
// them goes through `eventFor`, which is where the two data-shape quirks polo
// grew are absorbed:
//
//   * Some keys sit under `options`, others at the top level, for no reason
//     beyond the order they were added. `options.multipliers` and
//     `bonusPoints.perParkActivated` are siblings in intent and cousins in the
//     file.
//   * `parks` is a ref → 1 set for three events and a ref → abbreviation map
//     for Ohio, which also repeats the same pairs in `parkReferences`.
//
// Keys polo's code reads and this does not: `powerMultipliers` (in txsp, read
// by nothing there either — see docs/design/contests.md §8), `questions`,
// `internalNotes`, `disabled`, `secondStart`/`secondEnd` (no shipped event has
// a split period).
//
// Keys polo's code IGNORES and this honours — the band lists. polo applies one
// hard-coded WARC exclusion to every event and never consults the per-event
// `bands`/`excludedBands` the data files carry, so Ohio's 80-10m limit and
// Florida's 160-6m list do nothing there. Both are live here; that is the
// fix-on-port §8 asks for, and it is a real behaviour change: an OHSP contact
// on 160m now scores zero, correctly.

import txsp from "./events/txsp.json" with { type: "json" }
import flsp from "./events/flsp.json" with { type: "json" }
import gasp from "./events/gasp.json" with { type: "json" }
import ohsp from "./events/ohsp.json" with { type: "json" }

/// Every event excludes the WARC bands — they are closed to contests by IARU
/// convention, not by any one sponsor's rules, which is why polo hard-codes the
/// same list for all four. An event may narrow further with `bands`.
export const WARC_BANDS = ['60m', '30m', '17m', '12m']

/// How an event counts multipliers, from `options.multipliers`.
export type MultiplierRule = 'none' | 'stateParksActivated' | 'stateParksActivatedAndHunted'

/// One park in an event's list: its POTA reference, and — where the event runs
/// on abbreviations rather than references — the code operators exchange.
export interface EventPark {
  ref: string
  abbreviation?: string
  name?: string
}

export interface StateParkEvent {
  key: string
  /// Long name, as the sponsor writes it. Not translated: these are proper
  /// names, and an operator searching "Ohio State Parks" wants the one string
  /// the sponsor's own site uses.
  name: string
  /// Short form for titles and the operation row ("OH SP").
  short: string
  url: string
  /// UTC millis, parsed from the file's `start`/`end`.
  startMillis: number
  endMillis: number
  notes?: string
  status?: string
  lastUpdated?: string

  /// Points per super-mode (`PHONE`/`CW`/`DATA`), 1 where unstated.
  points: Record<string, number>
  /// Extra points the FIRST contact with each distinct park earns — Georgia's
  /// `points.distinctStatePark`.
  pointsPerDistinctPark: number
  multipliers: MultiplierRule
  /// The event's own band list, when it has one. Empty means "any band that
  /// isn't excluded".
  validBands: string[]
  /// WARC plus anything the event adds.
  excludedBands: string[]
  /// Callsign → points for working it, once (`bonusStations`).
  bonusStations: Record<string, number>
  /// Points per park WE activate (`bonusPoints.perParkActivated`).
  bonusPointsPerParkActivated: number

  /// True when the exchange is a park abbreviation rather than nothing at all
  /// (`options.exchange === 'parkAbbreviation'`) — Ohio alone, today.
  usesParkAbbreviations: boolean
  /// This event's own Cabrillo (`options.exportCabrillo`). The other three ride
  /// POTA's exports, since their sponsors take a plain ADIF.
  exportsCabrillo: boolean
  /// CONTEST line for that Cabrillo.
  cabrilloName: string

  /// Every park in the event, in file order.
  parks: EventPark[]
  /// POTA reference → park. The lookup both the scorer and the exports run per
  /// QSO, so it is a map and not a scan.
  parkByRef: Record<string, EventPark>
  /// Abbreviation → park, for the events that exchange abbreviations.
  parkByAbbreviation: Record<string, EventPark>
}

/// Shape of the JSON files, loose because they are maintained by hand.
interface RawEvent {
  key: string
  name: string
  short?: string
  url?: string
  start?: string
  end?: string
  notes?: string
  status?: string
  lastUpdated?: string
  cabrilloName?: string
  options?: { multipliers?: string; exchange?: string; exportCabrillo?: boolean }
  points?: Record<string, number>
  bands?: string[]
  excludedBands?: string[]
  bonusStations?: Record<string, number>
  bonusPoints?: { perParkActivated?: number }
  parks?: Record<string, unknown>
  parkAbbreviations?: Record<string, string>
  parkReferences?: Record<string, string>
}

/// `"2026-4-18 00:00Z"` → UTC millis.
///
/// Parsed by hand rather than handed to `Date`. The files use a single-digit
/// month, a space separator and a bare `Z` — a format V8 accepts and the ES
/// spec does not, so `Date.parse` returning NaN in the QuickJS runtime the
/// extensions actually run in would silently date every event to 1970 and
/// rank the whole list wrong. An unparseable value answers 0, which reads as
/// "no date" everywhere below rather than as a date in the past.
export function parseEventTime(value: string | undefined): number {
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})/.exec(value ?? '')
  if (!match) return 0
  return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]))
}

function normalize(raw: RawEvent): StateParkEvent {
  const abbreviations = raw.parkAbbreviations ?? {}
  const references = raw.parkReferences ?? {}
  const usesParkAbbreviations = Object.keys(abbreviations).length > 0

  // Ohio's `parkAbbreviations` is the authoritative order (alphabetical by
  // abbreviation, which is the order the sponsor publishes and the operator
  // reads); the other three have only `parks`.
  const parks: EventPark[] = usesParkAbbreviations
    ? Object.keys(abbreviations).map((abbreviation) => ({
      abbreviation,
      ref: references[abbreviation] ?? '',
      name: abbreviations[abbreviation],
    }))
    : Object.keys(raw.parks ?? {}).map((ref) => ({ ref }))

  const parkByRef: Record<string, EventPark> = {}
  const parkByAbbreviation: Record<string, EventPark> = {}
  for (const park of parks) {
    if (park.ref) parkByRef[park.ref] = park
    if (park.abbreviation) parkByAbbreviation[park.abbreviation] = park
  }

  const points = { ...(raw.points ?? {}) }
  // `distinctStatePark` shares the `points` map with the per-mode values but is
  // not a mode, so it is lifted out — otherwise a QSO in a mode nobody named
  // could match it.
  const pointsPerDistinctPark = points.distinctStatePark ?? 0
  delete points.distinctStatePark

  const bonusStations: Record<string, number> = {}
  for (const [call, value] of Object.entries(raw.bonusStations ?? {})) {
    bonusStations[call.toUpperCase()] = value
  }

  return {
    key: raw.key,
    name: raw.name,
    short: raw.short ?? raw.key,
    url: raw.url ?? '',
    startMillis: parseEventTime(raw.start),
    endMillis: parseEventTime(raw.end),
    notes: raw.notes,
    status: raw.status,
    lastUpdated: raw.lastUpdated,

    points,
    pointsPerDistinctPark,
    multipliers: (raw.options?.multipliers as MultiplierRule) ?? 'none',
    validBands: raw.bands ?? [],
    excludedBands: [...WARC_BANDS, ...(raw.excludedBands ?? [])],
    bonusStations,
    bonusPointsPerParkActivated: raw.bonusPoints?.perParkActivated ?? 0,

    usesParkAbbreviations,
    exportsCabrillo: raw.options?.exportCabrillo === true,
    // Sponsors name their own Cabrillo contest; `<KEY>OTA` is what the three
    // whose sponsors don't take a Cabrillo would use if they started to.
    cabrilloName: raw.cabrilloName ?? `${raw.key}OTA`,

    parks,
    parkByRef,
    parkByAbbreviation,
  }
}

/// Every event, in the order the files are listed — which is the order polo's
/// `all-events.js` lists them and has no meaning beyond that. Callers rank for
/// themselves (see `daysUntil`).
export const EVENTS: StateParkEvent[] = [txsp, flsp, gasp, ohsp].map((raw) => normalize(raw as RawEvent))

const EVENTS_BY_KEY: Record<string, StateParkEvent> = {}
for (const event of EVENTS) EVENTS_BY_KEY[event.key] = event

/// The event a ref names, or undefined. Ref values are the event key (`OHSP`),
/// so this is also the validity test for one.
export function eventFor(key: string | undefined): StateParkEvent | undefined {
  return key ? EVENTS_BY_KEY[key.toUpperCase()] : undefined
}

/// Whole days from [nowMillis] to the event's start — negative once it has
/// begun.
///
/// These events recur annually, so an event more than two weeks past is read as
/// next year's rather than as one long gone: polo's own dropdown does this, and
/// without it the list an operator sees in June is ordered by how far into the
/// past each event is. Approximated with 365 days deliberately — the sponsors
/// move these to a particular weekend anyway, so the file's date is authoritative
/// the moment it is updated and this only has to order a list.
export function daysUntil(event: StateParkEvent, nowMillis: number): number {
  if (!event.startMillis) return 365
  const days = Math.ceil((event.startMillis - nowMillis) / (24 * 60 * 60 * 1000))
  return days < -14 ? days + 365 : days
}

/// Whether [event]'s dates are in the past rather than describing its next
/// running.
///
/// `daysUntil` rolls an event more than two weeks past into next year so a list
/// orders by what is coming — but the file still holds THIS year's dates, so a
/// label saying "in 266 days" next to a period three months gone reads as a bug.
/// Anything the operator sees says "already happened" instead, until the data
/// file is updated for the next running.
export function hasAlreadyRun(event: StateParkEvent, nowMillis: number): boolean {
  return event.endMillis > 0 && event.endMillis < nowMillis - 14 * 24 * 60 * 60 * 1000
}

/// Whether [band] counts for [event] — its own list if it has one, minus the
/// excluded ones either way.
export function bandCounts(event: StateParkEvent, band: string): boolean {
  if (!band) return false
  if (event.excludedBands.includes(band)) return false
  return event.validBands.length === 0 || event.validBands.includes(band)
}
