// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The 49 QSO parties, and one normalized view of them.
//
// `parties/*.json` came from app-polo (`src/extensions/contests/qp/parties/`)
// and are kept as close to verbatim as possible, so the yearly re-sync — dates
// move, county lists and bonus stations change — stays a file copy and a
// legible diff, as `stateparks` does.
//
// **Six files now diverge, and a re-sync must not silently revert them.** SD
// carries `SDQSOP`, the Cabrillo name the registry at contestcalendar.com
// lists, where polo assumes `SD-QSO-PARTY`; a copy of polo's file would rename
// the contest every submitted log declares. BC, NC, NJ, NV and SC still
// carried 2025 dates (NC's END year alone, SC's an impossible 29 February);
// each was re-checked against the sponsor's own rules in September 2026 and
// now carries what they publish, with `status` saying what was verified and
// `lastUpdated` saying when, and NJ and NV gained the rules URL they had none
// of. NEVER take polo's copy of these six without re-reading the sponsor:
// polo's dates are older than these, not newer. (WA diverged the same way
// until polo re-verified it for 2026; the two agree again.) NSARA's dates are still 2025 — its contest page is gone (404) and
// the party is `disabled` in the data anyway.
//
// Everything that reads these files goes through `partyFor`, which is where the
// shapes forty-nine hand-edited files have grown are absorbed:
//
//   * Three spellings of the power table (`powerMultiplier`,
//     `powerMultipliers`, `power`) over two sets of class names
//     (`LP`/`HP` and `LOW`/`HIGH`).
//   * `DIGI` and `DATA` for the same super-mode, in the same `points` map.
//   * Options written as an explicit `null` where the writer meant "no"
//     (bc's `bonusPerBandMode`), and two options whose default is TRUE.
//   * A party with no county list at all, which cannot be operated. None ship
//     that way today — Arizona was the last, and it now carries its counties —
//     but the guard stays, because a party added mid-season starts as a name
//     and a date and is offered the moment it has counties.
//
// Keys polo's own code reads and this does not: `qsoPartyHubName`, `aprsShort`
// (QP-Hub and APRS self-spotting are a non-goal, docs/design/contests.md §2).
//
// Keys NOTHING reads, in polo or here, and which are therefore not in the
// normalized shape: `entry` (per-entrant category tables — polo builds no
// category picker from them; the power classes this port does ask for are
// `POWER_CLASSES` below), `uniqueness`, `bonusPoints`, `specialCalls`,
// `notes`, `internalNotes`, `openQuestions`. `specialCalls` goes with
// `specialCallIsMultiplier`, which is unimplemented here as it is in polo.
//
// Rules polo documents as unimplemented and this port leaves that way, so the
// files can keep carrying them: `_Rover_` and `_QRP_` point overrides (VA, ID),
// `pointMultipliers` for portable and mobile entrants (AR), `SAT` points (NE),
// `inStateExchange`/`outOfStateExchange` (NSARA, itself disabled),
// `specialCallIsMultiplier` (VT), `onlineLookup` (VT),
// `roversAddCountySuffix` (MN), and `qsoPerMode` (NS — a typo for the
// `qsosPerMode` polo's own NOTES describes, and read by nothing in either).
//
// `selfSpotting` (44 files) is not a scoring rule at all: it says whether the
// sponsor permits self-spotting, and QP-Hub and APRS spotting are a non-goal
// here (docs/design/contests.md §2), so nothing reads it.

import { isCanadianProvince, isUsState } from "./locations.ts"

import sevenqp from "./parties/7qp.json" with { type: "json" }
import acqp from "./parties/acqp.json" with { type: "json" }
import al from "./parties/al.json" with { type: "json" }
import ar from "./parties/ar.json" with { type: "json" }
import az from "./parties/az.json" with { type: "json" }
import bc from "./parties/bc.json" with { type: "json" }
import ca from "./parties/ca.json" with { type: "json" }
import co from "./parties/co.json" with { type: "json" }
import cpqp from "./parties/cpqp.json" with { type: "json" }
import de from "./parties/de.json" with { type: "json" }
import fl from "./parties/fl.json" with { type: "json" }
import ga from "./parties/ga.json" with { type: "json" }
import hi from "./parties/hi.json" with { type: "json" }
import ia from "./parties/ia.json" with { type: "json" }
import id from "./parties/id.json" with { type: "json" }
import il from "./parties/il.json" with { type: "json" }
import indiana from "./parties/in.json" with { type: "json" }
import ks from "./parties/ks.json" with { type: "json" }
import ky from "./parties/ky.json" with { type: "json" }
import la from "./parties/la.json" with { type: "json" }
import md from "./parties/md.json" with { type: "json" }
import me from "./parties/me.json" with { type: "json" }
import mi from "./parties/mi.json" with { type: "json" }
import mn from "./parties/mn.json" with { type: "json" }
import mo from "./parties/mo.json" with { type: "json" }
import ms from "./parties/ms.json" with { type: "json" }
import nc from "./parties/nc.json" with { type: "json" }
import nd from "./parties/nd.json" with { type: "json" }
import ne from "./parties/ne.json" with { type: "json" }
import neqp from "./parties/neqp.json" with { type: "json" }
import nh from "./parties/nh.json" with { type: "json" }
import nj from "./parties/nj.json" with { type: "json" }
import nm from "./parties/nm.json" with { type: "json" }
import ns from "./parties/ns.json" with { type: "json" }
import nv from "./parties/nv.json" with { type: "json" }
import ny from "./parties/ny.json" with { type: "json" }
import oh from "./parties/oh.json" with { type: "json" }
import ok from "./parties/ok.json" with { type: "json" }
import on from "./parties/on.json" with { type: "json" }
import pa from "./parties/pa.json" with { type: "json" }
import qc from "./parties/qc.json" with { type: "json" }
import sc from "./parties/sc.json" with { type: "json" }
import sd from "./parties/sd.json" with { type: "json" }
import tn from "./parties/tn.json" with { type: "json" }
import tx from "./parties/tx.json" with { type: "json" }
import va from "./parties/va.json" with { type: "json" }
import vt from "./parties/vt.json" with { type: "json" }
import wa from "./parties/wa.json" with { type: "json" }
import wi from "./parties/wi.json" with { type: "json" }
import wv from "./parties/wv.json" with { type: "json" }

const RAW_PARTIES: RawParty[] = [
  sevenqp,
  acqp,
  al,
  ar,
  az,
  bc,
  ca,
  co,
  cpqp,
  de,
  fl,
  ga,
  hi,
  ia,
  id,
  il,
  indiana,
  ks,
  ky,
  la,
  md,
  me,
  mi,
  mn,
  mo,
  ms,
  nc,
  nd,
  ne,
  neqp,
  nh,
  nj,
  nm,
  ns,
  nv,
  ny,
  oh,
  ok,
  on,
  pa,
  qc,
  sc,
  sd,
  tn,
  tx,
  va,
  vt,
  wa,
  wi,
  wv,
]

/// One party's file, as it sits on disk. Everything is optional because the
/// files are hand-maintained and several are placeholders whose only content is
/// a name and next year's dates.
type RawParty = Record<string, unknown>

/// Which national county/section vocabulary a party belongs to — `K` for the US
/// parties, `VE` for the Canadian ones. Decides which of the two tables an
/// out-of-area location is looked up in, and which one an in-state station
/// sweeps.
export type PartyEntity = "K" | "VE"

/// The rule switches, all resolved to a value: reading `options.multsPerBand`
/// off the raw file means every call site repeats the same `?? false`, and the
/// two files that write an explicit `null` (bc's `bonusPerBandMode`) would
/// answer differently from the forty-seven that omit it.
export interface PartyOptions {
  entity: PartyEntity
  /// Stations may operate from two counties at once, so one QSO can count for
  /// both — the N×M rule this milestone exists for. Only affects what the
  /// exchange field ACCEPTS; the scorer multiplies whatever it is given.
  countyLine: boolean
  /// DC is scored as Maryland. Per polo's NOTES: rules saying "50 states" with
  /// no mention of DC mean true; rules naming DC explicitly mean false.
  dcCountsAsMaryland: boolean
  /// A US or Canadian station outside the party sends its ARRL/RAC SECTION, not
  /// its state or province (PA). Strict: a state is valid only where a section
  /// shares its abbreviation, because the sponsor's checker reads the same list
  /// — so `dcCountsAsMaryland` and `alaskaAndHawaiiAreDX` have nothing to say
  /// under it (`MDC` and `PAC` are sections of their own).
  sectionsForOutOfState: boolean
  /// An in-state station counts its OWN state as a multiplier as well as the
  /// county the contact came from.
  stateCountsForInState: boolean
  /// In-state stations get counties as multipliers. Default true; ACQP, CPQP
  /// and DEQP say false, and there the state is the multiplier instead.
  countiesCountForInState: boolean
  /// Counties are multipliers at all for an in-state station. NEQP alone says
  /// false: there an in-state contact multiplies by STATE, and the county is
  /// only an exchange.
  countiesAreMultForInState: boolean
  /// Alaska and Hawaii count as DX rather than as US states. Carried by NEQP
  /// alone, which sets it FALSE — no shipped party turns it on.
  alaskaAndHawaiiAreDX: boolean
  /// Our own county is a multiplier for us, without working anyone in it. Some
  /// sponsors set a minimum QSO count for this; that variation is not ported,
  /// as it is not in polo either.
  selfCountsForCounty: boolean
  /// As `selfCountsForCounty`, but only while operating mobile or rover (TN).
  selfMobileCountsForCounty: boolean
  /// Every DX station together is worth ONE multiplier, `DX`.
  dxIsMultiplier: boolean
  /// Each DX entity prefix is its own multiplier. Beats `dxIsMultiplier` where
  /// both are set.
  dxEntityIsMultiplier: boolean
  /// Caps how many DX entities may be claimed (7QP, NH, WA: 10; IL: 5).
  dxEntityMultiplierMax?: number
  /// Caps the multipliers an in-state entrant's score counts (CA: 58 of the
  /// 63 it can work). Every one worked is still recorded and struck off.
  inStateMultiplierMax?: number
  /// A DX station's logged location is its entity prefix rather than the plain
  /// string `DX`.
  dxLocationIsPrefix: boolean
  multsPerBandMode: boolean
  multsPerBand: boolean
  multsPerMode: boolean
  /// Per-band multipliers for the in-state side only (HI), and for the
  /// out-of-state side only (NH).
  inStateMultsPerBand: boolean
  outOfStateMultsPerBand: boolean
  bonusPerBandMode: boolean
  bonusPerMode: boolean
  /// Bonus points are added AFTER the multiplier rather than before it.
  bonusPostMultiplier: boolean
  /// Scales a bonus station's points for an in-state (out-of-state) entrant.
  /// ID sets the in-state one to 0, which is how a party says "the bonus
  /// stations pay out-of-state entrants only".
  bonusStationInStateMult?: number
  bonusStationOutOfStateMult?: number
  /// In-state to out-of-state contacts are worth double (SC).
  inStateToOutOfStatePointsDouble: boolean
  /// Digital and CW are one mode for per-mode multipliers, dupes and points.
  dataAndCWCountAsSameMode: boolean
  /// Points for a contact with a station OUTSIDE the party, where the sponsor
  /// prices the two sides differently — Maine pays 2 for a contact with a Maine
  /// station and 1 for anyone else. Undefined everywhere else, where the mode
  /// alone sets the price.
  pointsWhenTheyAreOutOfParty?: number
  /// Rover suffixes are stripped from callsigns in the Cabrillo (ID).
  removeCountySuffixes: boolean
  /// What this party calls its subdivisions — CPQP's are Districts.
  labelForCounties: string
}

/// The one-time bonuses, all zero unless a party names them.
export interface PartyBonus {
  /// Points for each county we ACTIVATE — a rover's reward for driving.
  perActivatedCounty: number
  /// QSOs needed from a county before it counts as activated.
  perActivatedCountyMinimumCount: number
  /// Only mobile and rover entrants earn it (every party that has it).
  perActivatedCountyRoverOnly: boolean
  /// Points for working every rare county (NC).
  rareCountySweep: number
  rareCountySweepMinimumCount: number
  /// Points for working every bonus station (ID).
  bonusStationSweep: number
  bonusStationSweepMinimumCount: number
}

/// A party, normalized. `parties/*.json` are app-polo's files verbatim; this is
/// the only shape the rest of the extension sees.
export interface QsoParty {
  /// Uppercase, and the value carried in the ref's own `ref` field —
  /// `{type: 'qp', ref: 'NY'}` — which is what selects these rules.
  key: string
  name: string
  /// `NYQP`, `7QP`, `NEQP` — the sponsor's short name where they have one, and
  /// the state key with `QP` appended where they don't.
  short: string
  url?: string
  /// The `CONTEST:` line a submitted Cabrillo must carry. Absent for a party
  /// whose file has no name for it, in which case no Cabrillo is offered.
  cabrilloName?: string
  startMillis: number
  endMillis: number
  /// A second operating period — 14 parties run Saturday and Sunday sessions
  /// with a break overnight. Display and ranking only: HaLo gates a contest by
  /// SEGMENT, not by the clock (docs/design/contests.md §5.1.3).
  secondStartMillis?: number
  secondEndMillis?: number
  status?: string
  lastUpdated?: string
  /// Whether this party can be operated at all. False for a placeholder file
  /// with no counties, and for one marked `disabled` (NSARA). An unsupported
  /// party is not offered in the activity search, and scores nothing.
  supported: boolean
  /// County abbreviation → name, in the file's own order (which is
  /// alphabetical by name, and is what the summary table prints).
  counties: Record<string, string>
  /// The neighbouring parties' counties 7QP's entrants also work. Valid
  /// exchange values and shown in the picker; NOT this party's own counties,
  /// so they are never in-state and never sweep the county table.
  otherCounties: Record<string, string>
  /// County → state, for the multi-state parties (7QP, ACQP, CPQP) whose
  /// abbreviations don't carry it. Elsewhere a county longer than four
  /// characters carries its state in its first two.
  countyToState: Record<string, string>
  /// Super-mode → points. `DIGI` in a file means `DATA`; see `pointsForMode`.
  points: Record<string, number>
  /// Callsign → the points working it pays, once.
  bonusStations: Record<string, number>
  /// County → the ARRL section it lies in, where an in-state entrant earns that
  /// section as a multiplier on top of the county (PA's `EPA`/`WPA`, rule 12.d).
  /// The file lists it the other way round, section → counties, which is how
  /// a sponsor's map reads.
  countySections: Record<string, string>
  /// County → the factor a QSO with it is multiplied by (NC).
  rareCountyMultipliers: Record<string, number>
  /// Power class → score multiplier. Three files spell the same idea three
  /// ways (`powerMultiplier`, `powerMultipliers`, `power`) with two sets of
  /// class names; all of them normalize to `QRP`/`LOW`/`HIGH` here.
  powerMultipliers: Record<PowerClass, number>
  bonus: PartyBonus
  options: PartyOptions
  /// The classes this party publishes, and so the questions its setup form
  /// asks. Empty lists for an axis the sponsor does not classify by.
  entryClasses: EntryClasses
  /// What the entry row asks for besides the location. `number` is a serial
  /// each way (CA, VA); `name` is the operator's name (MN).
  exchange: { number: boolean; name: boolean }
}

export type PowerClass = "QRP" | "LOW" | "HIGH"

export const POWER_CLASSES: PowerClass[] = ["QRP", "LOW", "HIGH"]

/// The entry classes a party publishes, as Cabrillo's own vocabulary.
///
/// Forty-seven sponsors describe their classes in forty-seven ways, and a
/// survey of all of them says the DIFFERENCES are which classes are offered and
/// what a watt limit is — not what the classes are called. Every one maps onto a
/// `CATEGORY-` line, which is the point of capturing them: this is what a
/// submitted Cabrillo has to declare, and for six parties the power class is a
/// score multiplier as well.
///
/// So the vocabulary is shared and the SUBSET is the party's, in its own file
/// under `entryClasses` — a party names the classes it publishes and nothing
/// else, and an axis it does not publish is a question this app does not ask.
///
/// `operator` and `transmitter` are one axis here and two in Cabrillo:
/// "Multi-Single" is `CATEGORY-OPERATOR: MULTI-OP` with
/// `CATEGORY-TRANSMITTER: ONE`. They are joined because that is how sponsors
/// publish them, and split again on the way out (`cabrilloCategories`).
export type OperatorClass = "SINGLE-OP" | "SINGLE-OP-ASSISTED" | "MULTI-ONE" | "MULTI-TWO" | "MULTI-UNLIMITED"

export type StationClass = "FIXED" | "MOBILE" | "PORTABLE" | "ROVER" | "EXPEDITION" | "COUNTY-LINE" | "SCHOOL" | "CLUB" | "EOC"

export type ModeClass = "CW" | "PHONE" | "DIGITAL" | "MIXED"

export type OverlayClass = "ROOKIE" | "YOUTH" | "YL" | "NOVICE-TECH" | "NEW-CONTESTER" | "TB-WIRES" | "POTA"

export const OPERATOR_CLASSES: OperatorClass[] = ["SINGLE-OP", "SINGLE-OP-ASSISTED", "MULTI-ONE", "MULTI-TWO", "MULTI-UNLIMITED"]
export const STATION_CLASSES: StationClass[] = ["FIXED", "MOBILE", "PORTABLE", "ROVER", "EXPEDITION", "COUNTY-LINE", "SCHOOL", "CLUB", "EOC"]
export const MODE_CLASSES: ModeClass[] = ["CW", "PHONE", "DIGITAL", "MIXED"]
export const OVERLAY_CLASSES: OverlayClass[] = ["ROOKIE", "YOUTH", "YL", "NOVICE-TECH", "NEW-CONTESTER", "TB-WIRES", "POTA"]

/// The station classes that are ON THE MOVE — what a party means by "mobile or
/// rover" where it pays a bonus for the counties an entrant activates, and what
/// the old `mobile` flag on a ref stood for.
export const ROVING_STATION_CLASSES: StationClass[] = ["MOBILE", "ROVER"]

export interface EntryClasses {
  operator: OperatorClass[]
  power: PowerClass[]
  /// What the sponsor says each power class means — "100 watts", ">150 watts",
  /// "5 watts CW or 10 watts phone". Shown beside the choice, because the class
  /// names are shared and the watts are not: 21 parties split at 100 W, 12 at
  /// 150 W, and four define QRP by mode.
  powerLimits: Partial<Record<PowerClass, string>>
  station: StationClass[]
  mode: ModeClass[]
  overlay: OverlayClass[]
}

/// Bands closed to contests by IARU convention — the same list every other
/// contest in this tree excludes, and polo's for this one.
export const WARC_BANDS = ["60m", "30m", "17m", "12m"]

function str(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined
}

function bool(value: unknown): boolean {
  return value === true
}

function num(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined
}

function mapOf(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {}
  const out: Record<string, string> = {}
  for (const [code, name] of Object.entries(value as Record<string, unknown>)) {
    const key = normalizeCode(code)
    out[key] = typeof name === "string" && name ? name : key
  }
  return out
}

function countySectionsOf(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {}
  const out: Record<string, string> = {}
  for (const [section, counties] of Object.entries(value as Record<string, unknown>)) {
    if (!Array.isArray(counties)) continue
    for (const county of counties) if (typeof county === "string") out[normalizeCode(county)] = normalizeCode(section)
  }
  return out
}

function numbersOf(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object") return {}
  const out: Record<string, number> = {}
  for (const [code, points] of Object.entries(value as Record<string, unknown>)) {
    const n = num(points)
    if (n !== undefined) out[normalizeCode(code)] = n
  }
  return out
}

/// A code as everything else spells it.
///
/// `Ø` is the slashed zero hams write by hand, and `mo.json` keys its two
/// bonus stations `WØMA` and `KØGQ`. A logged callsign carries a digit zero, so
/// the lookup never matched and Missouri's two 100-point bonuses could not be
/// claimed at all. Normalized here rather than in the file, which stays
/// byte-identical to polo's for the yearly re-sync.
export function normalizeCode(code: string): string {
  return code.toUpperCase().replace(/[ØÖ]/g, "0")
}

/// `2026-5-2 13:00Z` → millis. The files are hand-written and inconsistent:
/// months and days may be unpadded, and the trailing Z is sometimes lowercase.
/// Anything else answers 0, which reads downstream as "no date" rather than as
/// 1970 (`daysUntil`, `hasAlreadyRun`).
export function parsePartyTime(value: unknown): number {
  const text = str(value)
  if (!text) return 0
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?\s*Z?$/i.exec(text)
  if (!match) return 0
  const [, year, month, day, hour, minute, second] = match
  const millis = Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second ?? 0))
  // `Date.UTC` rolls an impossible day forward rather than refusing it, and the
  // files carry one: `sc.json` ends on `2025-2-29`, a date 2025 does not have,
  // which would otherwise be shown to the operator as 1 March — a period the
  // sponsor never published. Read back and compare, so a typo in next year's
  // re-sync reads as "no date" instead of as a plausible wrong one.
  const at = new Date(millis)
  if (at.getUTCFullYear() !== Number(year) || at.getUTCMonth() !== Number(month) - 1 || at.getUTCDate() !== Number(day)) {
    return 0
  }
  return millis
}

/// A URL with its internal whitespace removed. `qc.json` carries
/// `https: //quebecqsoparty.org/`, which reaches the information panel as a
/// link that cannot open.
function sanitizeUrl(value: unknown): string | undefined {
  const text = str(value)
  if (!text) return undefined
  const cleaned = text.replace(/\s+/g, "")
  return cleaned.startsWith("http") ? cleaned : undefined
}

/// `NYQP` from `NY`, `7QP` and `NEQP` from themselves.
function shortFor(raw: RawParty, key: string): string {
  return str(raw.short) ?? (key.endsWith("QP") ? key : `${key}QP`)
}

/// The power table, from whichever of the three keys a file happens to use, on
/// whichever of the two class vocabularies it happens to use.
///
/// `LP`/`HP` and `LOW`/`HIGH` are the same two classes — four files say one and
/// two say the other — and a QRP entry means the same thing in both. Reading
/// them apart would leave DE's `LP: 2` invisible while KY's `LOW: 2` worked,
/// for no reason an operator could ever see.
function powerMultipliersOf(raw: RawParty): Record<PowerClass, number> {
  const table = numbersOf(raw.powerMultiplier ?? raw.powerMultipliers ?? raw.power)
  const out = {} as Record<PowerClass, number>
  const qrp = table.QRP
  const low = table.LOW ?? table.LP
  const high = table.HIGH ?? table.HP
  if (qrp !== undefined) out.QRP = qrp
  if (low !== undefined) out.LOW = low
  if (high !== undefined) out.HIGH = high
  return out
}

function optionsOf(raw: RawParty): PartyOptions {
  const o = (raw.options && typeof raw.options === "object" ? raw.options : {}) as Record<string, unknown>
  return {
    entity: str(o.entity)?.toUpperCase() === "VE" ? "VE" : "K",
    countyLine: bool(o.countyLine),
    dcCountsAsMaryland: bool(o.dcCountsAsMaryland),
    sectionsForOutOfState: bool(o.sectionsForOutOfState),
    stateCountsForInState: bool(o.stateCountsForInState),
    // These two default TRUE — the ordinary case is that counties are
    // multipliers, and only four files say otherwise.
    countiesCountForInState: o.countiesCountForInState !== false,
    countiesAreMultForInState: o.countiesAreMultForInState !== false,
    alaskaAndHawaiiAreDX: bool(o.alaskaAndHawaiiAreDX),
    selfCountsForCounty: bool(o.selfCountsForCounty),
    selfMobileCountsForCounty: bool(o.selfMobileCountsForCounty),
    dxIsMultiplier: bool(o.dxIsMultiplier),
    dxEntityIsMultiplier: bool(o.dxEntityIsMultiplier),
    dxEntityMultiplierMax: num(o.dxEntityMultiplierMax),
    inStateMultiplierMax: num(o.inStateMultiplierMax),
    dxLocationIsPrefix: bool(o.dxLocationIsPrefix),
    multsPerBandMode: bool(o.multsPerBandMode),
    multsPerBand: bool(o.multsPerBand),
    multsPerMode: bool(o.multsPerMode),
    inStateMultsPerBand: bool(o.inStateMultsPerBand),
    outOfStateMultsPerBand: bool(o.outOfStateMultsPerBand),
    bonusPerBandMode: bool(o.bonusPerBandMode),
    bonusPerMode: bool(o.bonusPerMode),
    bonusPostMultiplier: bool(o.bonusPostMultiplier),
    bonusStationInStateMult: num(o.bonusStationInStateMult),
    bonusStationOutOfStateMult: num(o.bonusStationOutOfStateMult),
    inStateToOutOfStatePointsDouble: bool(o.inStateToOutOfStatePointsDouble),
    dataAndCWCountAsSameMode: bool(o.dataAndCWCountAsSameMode),
    pointsWhenTheyAreOutOfParty: num(o.pointsWhenTheyAreOutOfParty),
    removeCountySuffixes: bool(o.removeCountySuffixes),
    labelForCounties: str(o.labelForCounties) ?? "Counties",
  }
}

function bonusOf(raw: RawParty): PartyBonus {
  const b = (raw.bonus && typeof raw.bonus === "object" ? raw.bonus : {}) as Record<string, unknown>
  return {
    perActivatedCounty: num(b.perActivatedCounty) ?? 0,
    perActivatedCountyMinimumCount: num(b.perActivatedCountyMinimumCount) ?? 1,
    perActivatedCountyRoverOnly: bool(b.perActivatedCountyRoverOnly),
    rareCountySweep: num(b.rareCountySweep) ?? 0,
    rareCountySweepMinimumCount: num(b.rareCountySweepMinimumCount) ?? 0,
    bonusStationSweep: num(b.bonusStationSweep) ?? 0,
    bonusStationSweepMinimumCount: num(b.bonusStationSweepMinimumCount) ?? 0,
  }
}

/// What the entry row asks for. A file states this as a list of field names,
/// and only four do; everything else exchanges a location alone.
///
/// `inStateExchange`/`outOfStateExchange` (NSARA) are NOT read: they name
/// `TheirNumber`/`OurNumber`, a one-way serial that neither polo nor this
/// implements, and that party is disabled in the data anyway.
function exchangeOf(raw: RawParty): { number: boolean; name: boolean } {
  const fields = Array.isArray(raw.exchange) ? raw.exchange.filter((f): f is string => typeof f === "string") : []
  return {
    number: fields.includes("Number"),
    name: fields.some((field) => field.startsWith("Name")),
  }
}

/// The `entryClasses` block, filtered to the vocabulary this build knows.
///
/// A class this version has never heard of is DROPPED rather than passed
/// through: everything downstream — the form's options, the Cabrillo
/// `CATEGORY-` lines — is keyed on these, and an unknown one would reach a
/// submitted log as a category no checker recognizes.
function entryClassesOf(raw: RawParty): EntryClasses {
  const block = (raw.entryClasses && typeof raw.entryClasses === "object" ? raw.entryClasses : {}) as Record<string, unknown>

  const listOf = <T extends string>(value: unknown, known: readonly T[]): T[] => {
    if (!Array.isArray(value)) return []
    const wanted = new Set(value.filter((v): v is string => typeof v === "string").map((v) => v.toUpperCase()))
    // In the shared vocabulary's own order, not the file's, so every party's
    // form reads the same way down the list.
    return known.filter((code) => wanted.has(code))
  }

  const limits: Partial<Record<PowerClass, string>> = {}
  const rawLimits = (block.powerLimits && typeof block.powerLimits === "object" ? block.powerLimits : {}) as Record<string, unknown>
  for (const power of POWER_CLASSES) {
    const limit = str(rawLimits[power])
    if (limit) limits[power] = limit
  }

  return {
    operator: listOf(block.operator, OPERATOR_CLASSES),
    power: listOf(block.power, POWER_CLASSES),
    powerLimits: limits,
    station: listOf(block.station, STATION_CLASSES),
    mode: listOf(block.mode, MODE_CLASSES),
    overlay: listOf(block.overlay, OVERLAY_CLASSES),
  }
}

function normalizeParty(raw: RawParty): QsoParty {
  const key = (str(raw.key) ?? "").toUpperCase()
  const counties = mapOf(raw.counties)
  const rareCountyMultipliers = numbersOf(raw.rareCountyQSOMultiplier)

  return {
    key,
    name: str(raw.name) ?? key,
    short: shortFor(raw, key),
    url: sanitizeUrl(raw.url),
    cabrilloName: str(raw.cabrilloName),
    startMillis: parsePartyTime(raw.start),
    endMillis: parsePartyTime(raw.end),
    secondStartMillis: parsePartyTime(raw.secondStart) || undefined,
    secondEndMillis: parsePartyTime(raw.secondEnd) || undefined,
    status: str(raw.status),
    lastUpdated: str(raw.lastUpdated),
    // A party with no counties has no exchange to check, no multiplier to
    // award and no in-state side. Offering one would produce an operation that
    // scores every contact zero without ever saying why. NSARA is the only
    // party that ships unsupported, and it is `disabled` rather than empty.
    supported: !bool(raw.disabled) && Object.keys(counties).length > 0,
    counties,
    otherCounties: mapOf(raw.otherQPCounties),
    countyToState: (() => {
      const table = mapOf(raw.countyToState)
      return Object.fromEntries(Object.entries(table).map(([county, state]) => [county, state.toUpperCase()]))
    })(),
    points: numbersOf(raw.points),
    bonusStations: numbersOf(raw.bonusStations),
    countySections: countySectionsOf(raw.countySections),
    rareCountyMultipliers,
    powerMultipliers: powerMultipliersOf(raw),
    bonus: bonusOf(raw),
    options: optionsOf(raw),
    entryClasses: entryClassesOf(raw),
    exchange: exchangeOf(raw),
  }
}

/// Every party, in the order `parties/` lists them.
export const PARTIES: QsoParty[] = RAW_PARTIES.map(normalizeParty)

const PARTIES_BY_KEY: Record<string, QsoParty> = Object.fromEntries(PARTIES.map((party) => [party.key, party]))

/// The parties an operator may actually run — the ones with a county list, and
/// not disabled.
export const SUPPORTED_PARTIES: QsoParty[] = PARTIES.filter((party) => party.supported)

/// The party [key] names, whatever its case, or undefined for one this build
/// doesn't have.
export function partyFor(key: unknown): QsoParty | undefined {
  const wanted = typeof key === "string" ? key.trim().toUpperCase() : ""
  return wanted ? PARTIES_BY_KEY[wanted] : undefined
}

/// Points for a contact in [superMode].
///
/// `DIGI` is `DATA` under another name: five files write one and eight the
/// other, and nothing in polo reconciles them — so 7QP's `DIGI: 4` silently
/// paid the fallback point there. Reconciled here (§8's fix-on-port), which
/// makes a digital contact worth what the sponsor publishes.
///
/// An unlisted mode is worth one point rather than nothing: no party lists
/// every mode it allows, and zeroing a contact is a rules claim this port has
/// no source for.
export function pointsForMode(party: QsoParty, superMode: string): number {
  const mode = superMode.toUpperCase()
  if (mode === "DATA") return party.points.DATA ?? party.points.DIGI ?? 1
  return party.points[mode] ?? 1
}

/// The mode a party SCORES a contact in [superMode] as. Three parties count
/// digital and CW as one mode, which decides dupes, per-mode multipliers and
/// per-mode bonuses alike — so it is applied once, here, rather than at each
/// of those three sites.
export function scoringModeFor(party: QsoParty, superMode: string): string {
  const mode = superMode.toUpperCase()
  if (party.options.dataAndCWCountAsSameMode && mode === "DATA") return "CW"
  return mode
}

/// The states and provinces this party's own counties sit in — one for most,
/// eight for 7QP, four for ACQP.
///
/// Read to catch an in-party operator who typed their STATE where their county
/// belongs: `NY` in the New York QSO Party resolves cleanly to the state, and
/// no party's county codes collide with a state code, so the value is valid and
/// the entry is silently scored under out-of-state rules.
const PARTY_STATES = new WeakMap<QsoParty, Set<string>>()

export function partyStates(party: QsoParty): Set<string> {
  // Memoized: this walks every county (470 for the largest party) and the
  // answer never changes, while the caller is on the per-QSO path that a full
  // rescore and every live-scoring keystroke run.
  const cached = PARTY_STATES.get(party)
  if (cached) return cached
  const states = new Set(Object.keys(party.counties).map((county) => stateForCounty(party, county)))
  PARTY_STATES.set(party, states)
  return states
}

/// Whether [location] is one of this party's own counties — the test for
/// "in-state", for us and for them alike.
export function isInParty(party: QsoParty, location: string): boolean {
  return party.counties[location.toUpperCase()] !== undefined
}

/// The state a county belongs to.
///
/// The multi-state parties carry a `countyToState` table; elsewhere a county
/// abbreviation longer than four characters carries its state in its first two
/// (`ORDES` is Oregon's Deschutes), and everything shorter belongs to the party
/// whose key IS its state.
///
/// That prefix rule is for parties that SPAN states, where a code has to say
/// which one. A party whose key is itself a state or province spans nothing, so
/// for its OWN counties the key is the answer and a long code is just a long
/// code: a file keyed by county NAMES would otherwise read `Cape Breton` as
/// California, and claim four American states as Nova Scotia's ground. The one
/// file shaped that way ships disabled, so this states the rule rather than
/// fixing a live symptom.
///
/// Own counties only, and the distinction is the whole of it. `otherCounties`
/// — a neighbouring party's, which `stateOfCode` also asks about — carries ITS
/// state in its prefix whatever this key says, and Indiana accepts 327 of them
/// from parties running the same weekend. Answering `IN` for `CTCAP` drops the
/// prefill of an exchange the operator logged last year, and accepts a stored
/// `ORDES` for an Indiana station as though it were theirs.
export function stateForCounty(party: QsoParty, county: string): string {
  const code = county.toUpperCase()
  const mapped = party.countyToState[code]
  if (mapped) return mapped
  if (party.counties[code] !== undefined && (isUsState(party.key) || isCanadianProvince(party.key))) return party.key
  return code.length > 4 ? code.slice(0, 2) : party.key
}

/// Days until this party next runs, or a negative count once it has started.
/// A party with no date at all sorts to the far end of the year.
export function daysUntil(party: QsoParty, nowMillis: number): number {
  if (!party.startMillis) return 365
  return Math.ceil((party.startMillis - nowMillis) / (24 * 60 * 60 * 1000))
}

/// Where a party sits in the setup list — smaller is higher.
///
/// A party that has not run yet is ordered by how soon it will; one whose file
/// is out of date is ordered by how RECENTLY it ran, and always below the
/// upcoming ones.
///
/// The stale half needs its own rule rather than falling through to
/// `daysUntil`, which is NEGATIVE there and would sort the most out-of-date
/// file to the top — the bug this list was fixed for. That is not a corner
/// case: for a few weeks each year, between the last party running and the
/// files being re-synced, EVERY party is stale and the tiebreak is the whole
/// ordering. Lives here, next to the dates it reads, because that is where it
/// can be tested against a fixed clock.
export function setupOrderOf(party: QsoParty, nowMillis: number): number {
  const days = daysUntil(party, nowMillis)
  // A large constant, not `Infinity`: the two halves have to stay ordered
  // WITHIN themselves as well as against each other.
  return hasAlreadyRun(party, nowMillis) ? -days : days - 1e6
}

/// Whether this party's published dates are all in the past — the file is
/// waiting for next year's update. Uses the LAST period it names, so a party
/// between its Saturday and Sunday sessions is still running.
export function hasAlreadyRun(party: QsoParty, nowMillis: number): boolean {
  // Falls back to the START where a file's end date is missing or impossible
  // (`parsePartyTime`): a party that began in 2025 has run, whatever its end
  // date says, and without this a single bad date would float a year-old file
  // to the top of the setup list as though it were still to come.
  const last = party.secondEndMillis || party.endMillis || party.startMillis
  return last > 0 && last < nowMillis
}
