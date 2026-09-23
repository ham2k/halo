// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QSO-party scoring, ported from app-polo's QSOPartiesExtension.
//
// The twelfth contest ported (docs/design/contests.md M10) and the first whose
// rules are almost entirely DATA: 49 parties, ~30 option switches, and the same
// scorer for all of them. `parties.ts` is where the files become one shape;
// this is where that shape becomes a score.
//
// Three things make it unlike the eleven before it:
//
//   1. **Our own location is part of the score, and it moves.** A rover's
//      county comes from the segment-effective ref, so `scoreQso` simply reads
//      it per QSO — that is M10's "stateful rolling-location scoring", and
//      segments (M6) are the whole of the mechanism. polo re-reads the single
//      operation ref for every QSO, so changing it rescores the entire log
//      under the new county, and the per-county bonus a rover drives for is
//      awarded against wherever they happened to finish.
//   2. **County lines multiply both ways.** A station on a county line sends
//      two counties, and either end may be on one, so a single contact can be
//      worth up to four QSOs and four multipliers (§5.1's N×M).
//   3. **In-party and out-of-party score by different rules**, and which side
//      you are on is not a setting — it is whether the county you typed is one
//      of the party's own.
//
// What a duplicate is, and the case where this deliberately keeps polo's
// answer: a contact repeats if the same callsign, band, mode, OUR county and
// THEIR county has been logged before — and a pair that overlaps a previous
// contact on any one of its combinations counts as a repeat, not just one
// that overlaps on all of them. That is polo's rule, and it costs a rover on a
// county line a QSO the sponsor might well allow (they moved to a new county,
// but one of their two is the county they were in before). The other reading
// claims contacts a log checker may strike, and an over-claim in a submitted
// file is the worse error of the two.
//
// Fixes to polo's rules, all §8 fix-on-port, all of them cases where its own
// data says one thing and its code does another:
//
//   * `points` written as `DIGI` were never found, because the lookup is by
//     super-mode and the super-mode is `DATA` (`parties.ts`, `pointsForMode`).
//     7QP's 4-point digital contacts scored 1 there.
//   * `dxEntityMultiplierMax` erased every DX multiplier instead of capping it
//     (`location.ts`). Counted properly here, against the entities worked.
//   * The per-band and per-mode multiplier prefix ignored `multsPerBand` and
//     `multsPerMode` whenever `inStateMultsPerBand` was set, and applied
//     `inStateMultsPerBand` to the out-of-state side as well (polo's
//     `qpMultPrefix` tests the same option in all three branches). See
//     `multiplierPrefix`.
//   * `powerMultiplier` is honoured (`entry.ts`), and so is the bonus-station
//     sweep, which polo's NOTES documents and its accumulator never awards.
//
// Two options that are one rule under two names: `countiesAreMultForInState`
// (NEQP) and `countiesCountForInState` (ACQP, CPQP, DEQP) have identical
// descriptions in polo's own NOTES — "in-state stations do not get counties as
// multipliers" — and are read here as the single flag they are. The county
// stays the county in the log and in the Cabrillo either way; only the
// multiplier it contributes becomes the state.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"

import { isMobile, ourLocationText, powerMultiplier, refOfType, str, TYPE } from "./entry.ts"
import {
  allInParty,
  defaultTheirLocation,
  entityPrefixOf,
  ourOwnCodes,
  outOfPartyTables,
  type PartyLocation,
  parseLocations,
  type Standing,
} from "./location.ts"
import { CANADIAN_PROVINCES, US_STATES } from "./locations.ts"
import { isInParty, normalizeCode, partyStates, partyFor, pointsForMode, type QsoParty, scoringModeFor, stateForCounty, WARC_BANDS } from "./parties.ts"

export type QpScoresheet = {
  /// The party these totals are for, recorded from the first QSO scored —
  /// `summarizeScore` is handed the BASE operation's ref, and on a segmented
  /// log the party may be named only in a later segment.
  partyKey?: string
  /// Whether WE are inside the party, and what our entry multiplies by. Both
  /// are recorded for the summary, which cannot see a segment's ref.
  weAreInParty?: boolean
  powerMult?: number
  /// Whether we entered as a mobile or rover station. Recorded because the
  /// per-county bonus every party that has it pays to ROVERS only, and
  /// `summarizeScore` cannot see the segment ref that declares it. Once true it
  /// stays true: a rover who parks for an hour is still a rover.
  mobile?: boolean
  /// Multiplier key (band/mode prefix + code) → times claimed. Its SIZE is the
  /// multiplier.
  mults: Record<string, number>
  /// The party's own counties worked, for the checklist the operator reads
  /// while deciding what to chase.
  counties: Record<string, number>
  states: Record<string, number>
  provinces: Record<string, number>
  /// DX entity prefix → contacts, or the single key `DX` where a party counts
  /// every DX station as one multiplier. Every entity WORKED, which is what the
  /// summary lists.
  entities: Record<string, number>
  /// The entities a multiplier was actually CREDITED for — what
  /// `dxEntityMultiplierMax` caps, and never the same as `entities` once a party
  /// is at its limit. Counting the worked ones instead let the second contact
  /// with an over-cap entity through: the entity was already recorded, so the
  /// "already credited, still claimable" exemption fired for a multiplier that
  /// had never been credited at all.
  creditedEntities: Record<string, number>
  rareCounties: Record<string, number>
  /// Bonus key (band/mode prefix + callsign) → the points it paid, once.
  bonuses: Record<string, number>
  /// Bonus station callsign → points, regardless of how many band/mode slots
  /// paid: the sweep counts STATIONS worked, and the summary lists stations.
  bonusStations: Record<string, number>
  /// Our own counties → contacts made from each. What the per-county bonus
  /// counts, and what the summary's "Activating" line lists.
  activatedCounties: Record<string, number>
  /// Callsign → `band|mode|ourCounty` → their counties already credited there.
  worked: Record<string, Record<string, string[]>>
  /// Callsign → the location they last sent, so a second contact with a
  /// station whose exchange went untyped is scored under the county they gave
  /// the first time. polo's `_defaultLocationFor`, folded into the pass.
  lastLocation: Record<string, string>
  bands: Record<string, number>
  modes: Record<string, number>
  /// Band → super-mode (`CW`, `PHONE`, `DATA`) → contacts, for the summary's
  /// band table. The super-mode, not the party's scoring mode: a party that
  /// folds digital into CW for its rules still reports them apart. Optional
  /// because a scoresheet cached by an earlier build has none.
  bandModes?: Record<string, Record<string, number>>
  qsos: number
  points: number
  dupes: number
}

/// The prefix that makes a multiplier key per-band, per-mode, both or neither.
///
/// polo's `qpMultPrefix` tests `inStateMultsPerBand` in all three branches, so
/// a party setting it (HI) could never reach the per-band or per-mode branch,
/// and a party setting the out-of-state twin (NH) got the in-state rule applied
/// to everyone. Read as written here: the two side-specific options widen the
/// per-band rule for the side they name, and nothing else changes.
export function multiplierPrefix(party: QsoParty, { band, mode, weAreInParty }: { band: string; mode: string; weAreInParty: boolean }): string {
  const o = party.options
  const perBand = o.multsPerBand || (o.inStateMultsPerBand && weAreInParty) || (o.outOfStateMultsPerBand && !weAreInParty)
  const perMode = o.multsPerMode
  if (o.multsPerBandMode || (perBand && perMode)) return `${band}:${mode}:`
  if (perBand) return `${band}:`
  if (perMode) return `${mode}:`
  return ""
}

/// The prefix a bonus station's key carries — the same idea for bonuses, which
/// a few parties pay once per band and mode (SC, KY, WI, WV) or once per mode
/// (the Salmon Run).
function bonusPrefix(party: QsoParty, band: string, mode: string): string {
  if (party.options.bonusPerBandMode) return `${band}:${mode}:`
  if (party.options.bonusPerMode) return `${mode}:`
  return ""
}

/// What a bonus station pays US. A party may scale it by which side we are on;
/// ID sets the in-state factor to 0, which is how it says its four bonus
/// stations pay out-of-state entrants only.
function bonusValue(party: QsoParty, call: string, weAreInParty: boolean): number {
  const base = party.bonusStations[call]
  if (base === undefined) return 0
  const factor = weAreInParty ? party.options.bonusStationInStateMult : party.options.bonusStationOutOfStateMult
  return base * (factor ?? 1)
}

/// The callsign a bonus station is recognized by — the base call, so a rover's
/// `K4TCG/M` still pays.
function baseCallOf(qso: Record<string, JSONValue>): string {
  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const guess = (their.guess as Record<string, JSONValue>) ?? {}
  // Through the same spelling the party's own list was normalized to, so a
  // hand-written slashed zero on either side is the digit it stands for.
  return normalizeCode(str(their.baseCall) || str(guess.baseCall) || str(their.call))
}

/// The DX entity a location stands for — its prefix where each entity
/// multiplies separately, the single key `DX` where they share one.
function entityOf(location: PartyLocation): string {
  return location.multCode.startsWith("DX:") ? location.multCode.slice(3) : "DX"
}

/// The multiplier keys one of their locations contributes, and the tables it
/// belongs in. Split out because `stateCountsForInState` means a single county
/// can be two multipliers at once — the county and the state it is in (CO).
function multipliersFor(
  party: QsoParty,
  location: PartyLocation,
  {
    prefix,
    weAreInParty,
    entityCount,
    worked,
  }: {
    prefix: string
    weAreInParty: boolean
    entityCount: number
    /// Whether this location's entity has already been credited in this log.
    worked: boolean
  },
): { keys: string[]; county?: string; state?: string; province?: string; entity?: string } {
  const code = location.code

  if (isInParty(party, code)) {
    const keys = [`${prefix}${location.multCode}`]
    let claimedState: string | undefined
    // Where the county multiplies as its STATE (`multCode`), that state is what
    // was claimed, and the summary's states table has to say so — otherwise an
    // NEQP entrant works Worcester, scores Massachusetts, and reads a checklist
    // still showing MA as needed.
    if (location.multCode !== code) claimedState = location.multCode
    // An in-party station's own state is a multiplier too, on top of the
    // county it came from — but only where the state is a real state or
    // province, so a multi-state party's made-up prefix never becomes one.
    if (party.options.stateCountsForInState && weAreInParty) {
      const state = stateForCounty(party, code)
      if (US_STATES[state] || CANADIAN_PROVINCES[state]) {
        const key = `${prefix}${state}`
        if (!keys.includes(key)) keys.push(key)
        claimedState ??= state
      }
    }
    const isProvince = claimedState !== undefined && CANADIAN_PROVINCES[claimedState] !== undefined
    return {
      keys,
      county: code,
      state: isProvince ? undefined : claimedState,
      province: isProvince ? claimedState : undefined,
    }
  }

  const tables = outOfPartyTables(party)
  if (tables.us[code] || code === "DC") return { keys: [`${prefix}${code}`], state: code }
  if (tables.canada[code]) return { keys: [`${prefix}${code}`], province: code }

  if (code === "DX") {
    const entity = entityOf(location)
    if (!party.options.dxIsMultiplier && !party.options.dxEntityIsMultiplier) {
      // A valid contact worth points, and no multiplier — most parties.
      return { keys: [], entity }
    }
    const max = party.options.dxEntityMultiplierMax
    // The cap counts entities already claimed — and one we have worked before
    // is always still claimable, or a party at its limit would stop crediting
    // an entity it has already credited. That only shows itself where a party
    // ALSO counts multipliers per band or mode (none of the four capped ones
    // does today), where the second band of an established entity is a new
    // multiplier key.
    if (max !== undefined && entityCount >= max && !worked) return { keys: [], entity }
    return { keys: [`${prefix}${location.multCode}`], entity }
  }

  return { keys: [] }
}

export const QsoPartyScorer: ContestScorer<QpScoresheet> = {
  startScoresheet(): QpScoresheet {
    return {
      mults: {},
      counties: {},
      states: {},
      provinces: {},
      entities: {},
      creditedEntities: {},
      rareCounties: {},
      bonuses: {},
      bonusStations: {},
      activatedCounties: {},
      worked: {},
      lastLocation: {},
      bands: {},
      modes: {},
      bandModes: {},
      qsos: 0,
      points: 0,
      dupes: 0,
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  // `isNewDay` is deliberately not read: a party is one period, and nothing
  // in its score resets at midnight (see `summarizeScore`).
  scoreQso({ scoresheet: sheet, qso, operation, ref }) {
    // A ref naming a party this build doesn't have, or one whose file is a
    // placeholder with no counties: 0 points and a visible alert, rather than
    // scoring against a county list that isn't theirs.
    const party = partyFor(ref?.ref)
    if (!party?.supported) return { scoresheet: sheet, score: { value: 0, alerts: ["unknownEvent"] } }
    sheet.partyKey ??= party.key

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call).toUpperCase()
    if (!call) return { scoresheet: sheet, score: { value: 0 } }

    const band = str(qso.band)
    if (!band || WARC_BANDS.includes(band)) {
      return { scoresheet: sheet, score: { value: 0, alerts: ["invalidBand"] } }
    }

    // A QSO with no mode keeps the per-QSO default rather than being judged:
    // `superModeForMode('')` answers `DATA`, which would price an import that
    // lost its MODE column as a digital contact.
    const rawMode = str(qso.mode)
    const superMode = rawMode ? superModeForMode(rawMode) : ""
    const mode = scoringModeFor(party, superMode)

    // OUR side, from the segment-effective ref: this is what a rover changes.
    const ourLocations = parseLocations(party, ourLocationText(operation, ref as Record<string, unknown>))
    if (ourLocations.length === 0) {
      // Nothing can be scored until the operator says where they are — every
      // QSO is worth our-counties × theirs, and ours is zero.
      return { scoresheet: sheet, score: { value: 0, alerts: ["ourLocation"] } }
    }
    const weAreInParty = allInParty(ourLocations)
    // An operator inside the party who typed their STATE where their county
    // belongs — `NY` in NYQP. It resolves cleanly, so nothing else objects, and
    // the whole log is then scored under out-of-state rules: different
    // multiplier keys, no own-county multiplier, no activated-county bonus. The
    // contact still counts for what it is worth; the operator is told, on every
    // QSO, that the setup needs a county.
    const ourStates = weAreInParty ? undefined : ourOwnCodes(party)
    const typedOurState = ourStates !== undefined && ourLocations.some((location) => ourStates.has(location.code))
    sheet.weAreInParty ??= weAreInParty
    // The first DECLARED multiplier wins, not the first QSO's answer: `??=`
    // would latch the 1 that stands for "no class declared".
    if (!sheet.powerMult || sheet.powerMult === 1) {
      sheet.powerMult = powerMultiplier(party, operation, ref as Record<string, unknown>)
    }
    if (isMobile(operation, ref as Record<string, unknown>, party)) sheet.mobile = true

    // THEIR side. An exchange left blank falls back to what this station sent
    // us earlier, then to what their callsign says — a DX station's exchange
    // is its entity, and no party asks them to type it.
    const entityPrefix = entityPrefixOf(qso)
    const qsoRef = refOfType(qso as Record<string, unknown>)
    const typed = str(qsoRef?.location).trim()
    const fallback = sheet.lastLocation[call] ?? defaultTheirLocation(party, qso)
    // `received` is what the operator COPIED, and only that. A fallback is not
    // an exchange anyone gave us: `defaultTheirLocation` deliberately answers
    // an in-party station's own state, because refusing a contact that plainly
    // happened is the worse reading — while the same code TYPED is a mis-copy
    // to be fixed.
    const received = typed !== ""
    const standing: Standing = { weAreInParty, theyAreInParty: false }
    let theirLocations = parseLocations(party, typed || fallback, { entityPrefix, standing, received })
    standing.theyAreInParty = allInParty(theirLocations)
    if (standing.theyAreInParty) {
      // Resolution depends on both sides' standing (a party where an in-party
      // pair multiplies by state), so once theirs is known it is resolved
      // again — cheap, and the only way the two ends agree.
      theirLocations = parseLocations(party, typed || fallback, { entityPrefix, standing, received })
    }
    const theyAreInParty = standing.theyAreInParty

    if (theirLocations.length === 0) {
      return {
        scoresheet: sheet,
        score: { value: 0, alerts: [typed ? "invalidExchange" : "missingExchange"] },
      }
    }

    // The party is between its own people and everyone else: two out-of-party
    // stations working each other is not a contest QSO at all.
    if (!weAreInParty && !theyAreInParty) {
      return { scoresheet: sheet, score: { value: 0, alerts: ["invalidExchange"] } }
    }

    // Every pairing of our counties with theirs is its own contact — the N×M a
    // county line earns.
    const perContact =
      !theyAreInParty && party.options.pointsWhenTheyAreOutOfParty !== undefined ? party.options.pointsWhenTheyAreOutOfParty : pointsForMode(party, superMode)
    let value = perContact * ourLocations.length * theirLocations.length
    if (party.options.inStateToOutOfStatePointsDouble && weAreInParty && !theyAreInParty) value *= 2

    const notices: string[] = []
    const rareCounties: string[] = []
    for (const location of theirLocations) {
      const rare = party.rareCountyMultipliers[location.code]
      if (rare) {
        rareCounties.push(location.code)
        value *= rare
      }
    }
    if (rareCounties.length > 0) notices.push("rareCounty")

    // Duplicates, against the pairs already credited. A slot is one band, one
    // mode and one of OUR counties, so a rover who drives into the next county
    // may work the same station again.
    const bySlot = (sheet.worked[call] ??= {})
    const slots = Object.keys(bySlot)
    const workedBefore = slots.length > 0
    const pairs: { slot: string; code: string }[] = []
    for (const ours of ourLocations) {
      for (const theirs of theirLocations) pairs.push({ slot: `${band}|${mode}|${ours.code}`, code: theirs.code })
    }
    const repeat = pairs.some(({ slot, code }) => (bySlot[slot] ?? []).includes(code))

    sheet.lastLocation[call] = theirLocations.map((location) => location.code).join("/")

    if (repeat) {
      sheet.dupes += 1
      return { scoresheet: sheet, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    if (workedBefore) {
      if (!slots.some((slot) => slot.startsWith(`${band}|`))) notices.push("newBand")
      if (!slots.some((slot) => slot.split("|")[1] === mode)) notices.push("newMode")
    }

    const prefix = multiplierPrefix(party, { band, mode, weAreInParty })

    // Our own county can be a multiplier without working anyone in it (NC, VA;
    // TN for a rover only). Claimed on every QSO rather than once, so that a
    // party counting multipliers per band claims it on each band we operate.
    const selfCounts =
      party.options.selfCountsForCounty || (party.options.selfMobileCountsForCounty && isMobile(operation, ref as Record<string, unknown>, party))
    if (selfCounts) {
      for (const ours of ourLocations) {
        if (!ours.inParty) continue
        // Our own county joins the counties table as well as the multiplier
        // set, so the summary's checklist shows it struck. A deliberate call:
        // that checklist is a chase list, and a county we are sitting in and
        // already claiming needs no chasing — showing it as still wanted would
        // send an operator hunting a multiplier they have.
        sheet.counties[ours.code] ??= 0
        sheet.mults[`${prefix}${ours.code}`] ??= 0
        sheet.mults[`${prefix}${ours.code}`] += 1
      }
    }

    let newMult = false
    for (const location of theirLocations) {
      const { keys, county, state, province, entity } = multipliersFor(party, location, {
        prefix,
        weAreInParty,
        entityCount: Object.keys(sheet.creditedEntities).length,
        worked: sheet.creditedEntities[entityOf(location)] !== undefined,
      })
      for (const key of keys) {
        if (sheet.mults[key] === undefined) {
          newMult = true
          sheet.mults[key] = 0
        }
        sheet.mults[key] += 1
      }
      if (county !== undefined) sheet.counties[county] = (sheet.counties[county] ?? 0) + 1
      if (state !== undefined) sheet.states[state] = (sheet.states[state] ?? 0) + 1
      if (province !== undefined) sheet.provinces[province] = (sheet.provinces[province] ?? 0) + 1
      if (entity !== undefined) {
        sheet.entities[entity] = (sheet.entities[entity] ?? 0) + 1
        // Credited only when this location actually produced a multiplier key.
        if (keys.length > 0) sheet.creditedEntities[entity] = (sheet.creditedEntities[entity] ?? 0) + 1
      }
    }
    if (newMult) notices.push("newMult")

    // A bonus station pays once per bonus slot; later contacts with it are
    // ordinary QSOs.
    const baseCall = baseCallOf(qso)
    const bonus = bonusValue(party, baseCall, weAreInParty)
    if (bonus > 0) {
      const key = `${bonusPrefix(party, band, mode)}${baseCall}`
      if (sheet.bonuses[key] === undefined) {
        sheet.bonuses[key] = bonus
        sheet.bonusStations[baseCall] = (sheet.bonusStations[baseCall] ?? 0) + bonus
        notices.push("bonusStation")
      }
    }

    for (const { slot, code } of pairs) (bySlot[slot] ??= []).push(code)
    for (const county of rareCounties) sheet.rareCounties[county] = (sheet.rareCounties[county] ?? 0) + 1
    for (const ours of ourLocations) {
      if (ours.inParty) sheet.activatedCounties[ours.code] = (sheet.activatedCounties[ours.code] ?? 0) + 1
    }
    sheet.bands[band] = (sheet.bands[band] ?? 0) + 1
    if (mode) sheet.modes[mode] = (sheet.modes[mode] ?? 0) + 1
    if (superMode) {
      const byMode = ((sheet.bandModes ??= {})[band] ??= {})
      byMode[superMode] = (byMode[superMode] ?? 0) + 1
    }
    sheet.qsos += 1
    sheet.points += value

    const score: QsoScoreVerdict = { value, band }
    if (notices.length > 0) score.notices = notices
    if (typedOurState) score.alerts = ["ourLocation"]
    return { scoresheet: sheet, score }
  },

  summarizeScore({ scoresheet: sheet, ref, scope }): Record<string, ScoreTally> {
    const party = partyFor(sheet.partyKey) ?? partyFor(ref?.ref)

    const workedMults = Object.keys(sheet.mults).length
    const max = sheet.weAreInParty ? party?.options.inStateMultiplierMax : undefined
    const mult = Math.min(workedMults, max ?? workedMults) || 1
    const points = sheet.points
    const bonusPoints = party ? oneTimeBonuses(party, sheet) : 0
    const power = sheet.powerMult ?? 1

    // A party that adds its bonus after the multiplier says so; the rest fold
    // it in before.
    const total = Math.round(party?.options.bonusPostMultiplier ? points * mult * power + bonusPoints : (points + bonusPoints) * mult * power)

    // A QSO party is ONE period, however many UTC days it straddles — the
    // sponsors publish one total, and the multipliers and bonuses are won
    // across the whole log. So a day is never scored on its own: its tally
    // is the party's running total as of that day's close (the harness
    // hands over the sheet as it stood then), which on the last day IS the
    // final score. The detail stays with the operation tally; a day shows
    // the number alone.
    const isDay = scope === "day"

    const arithmetic = arithmeticFor({ points, mult, bonusPoints, power })
    return {
      [TYPE]: {
        key: TYPE,
        for: scope,
        icon: "star",
        total,
        points,
        mults: mult,
        qsos: sheet.qsos,
        // The label is the section's TITLE in the information panel, and the
        // short `summary` is not shown beside a tally that has a
        // `longSummary` — so the event's name and its total go here, and the
        // arithmetic behind the total opens the detail.
        // A day carries the number alone in the score column, so its title is
        // the event's name alone — the total would otherwise read twice.
        label: isDay ? (party?.short ?? "QSO Party") : `${party?.short ?? "QSO Party"}: ${fmtInteger(total)}`,
        summary: `${fmtInteger(total)}`,
        longSummary: isDay ? "" : party ? [arithmetic, longSummaryFor(party, sheet, bonusPoints)].join("\n\n") : arithmetic,
        grid: true,
      },
    }
  },
}

/// One band's line of the summary table: every mode the party can be worked
/// in, zeros included — an unworked mode is what an operator scanning the
/// table is looking for — then the band's contacts.
function modeBreakdown(byMode: Record<string, number>, total: number): string {
  const cells = [
    ["CW", "CW"],
    ["PHONE", "SSB"],
    ["DATA", "Digital"],
  ].map(([superMode, name]) => `${fmtInteger(byMode[superMode] ?? 0)} ${name}`)
  return `${cells.join(", ")}, **${fmtInteger(total)} total**`
}

/// Longest wavelength first — the order a band table reads in — rather than
/// the alphabetical one `sort()` gives, which puts 160m between 15m and 20m.
function byWavelength(a: string, b: string): number {
  const meters = (band: string) => {
    const match = /^([\d.]+)(m|cm|mm)$/.exec(band)
    if (!match) return -1
    const n = Number(match[1])
    return match[2] === "m" ? n : match[2] === "cm" ? n / 100 : n / 1000
  }
  return meters(b) - meters(a) || a.localeCompare(b)
}

/// The bonuses that are won once for the whole log rather than per QSO: the
/// stations, the sweeps, and the counties a rover activated.
function oneTimeBonuses(party: QsoParty, sheet: QpScoresheet): number {
  let total = Object.values(sheet.bonuses).reduce((sum, points) => sum + points, 0)

  if (party.bonus.rareCountySweep > 0) {
    const needed = party.bonus.rareCountySweepMinimumCount || Object.keys(party.rareCountyMultipliers).length
    if (needed > 0 && Object.keys(sheet.rareCounties).length >= needed) {
      total += party.bonus.rareCountySweep
    }
  }

  // The bonus-station sweep, which polo's NOTES documents and its accumulator
  // never pays — ID's four `K7x` stations are worth 100 more together.
  if (party.bonus.bonusStationSweep > 0) {
    const needed = party.bonus.bonusStationSweepMinimumCount || Object.keys(party.bonusStations).length
    if (needed > 0 && Object.keys(sheet.bonusStations).length >= needed) {
      total += party.bonus.bonusStationSweep
    }
  }

  // Every party that pays per activated county pays it to rovers only, so an
  // entry that never declared itself mobile claims none of them — a fixed
  // station operating from its own county would otherwise collect the bonus a
  // rover drove all day for.
  if (party.bonus.perActivatedCounty > 0 && (!party.bonus.perActivatedCountyRoverOnly || sheet.mobile)) {
    total += activatedCounties(party, sheet).length * party.bonus.perActivatedCounty
  }

  return total
}

/// The counties that count as activated: ours, with enough contacts from each.
function activatedCounties(party: QsoParty, sheet: QpScoresheet): string[] {
  const minimum = party.bonus.perActivatedCountyMinimumCount || 1
  return Object.entries(sheet.activatedCounties)
    .filter(([, qsos]) => qsos >= minimum)
    .map(([county]) => county)
}

/// How the total came about — `points × mults`, the bonus, the power factor.
function arithmeticFor({ points, mult, bonusPoints, power }: { points: number; mult: number; bonusPoints: number; power: number }): string {
  const parts = [`${fmtInteger(points)} × ${fmtInteger(mult)}`]
  if (bonusPoints > 0) parts.push(`+ ${fmtInteger(bonusPoints)}`)
  // Only shown when it is doing something: every party but six has no power
  // table at all, and an entrant who declared no class multiplies by 1.
  if (power !== 1) parts.push(`× ${power}`)
  return parts.join(" ")
}

/// The tables an operator reads while operating: which counties are still out
/// there, which states and provinces are missing, and which bonus stations are
/// unworked. `**~~STRUCK~~**` is the core's own checklist convention
/// (`grid: true`).
function longSummaryFor(party: QsoParty, sheet: QpScoresheet, bonusPoints: number): string {
  const parts: string[] = []
  const worked = (table: Record<string, number>, code: string) => (table[code] !== undefined ? `**~~${code}~~**` : code)

  const activated = activatedCounties(party, sheet)
  if (activated.length > 0 && party.bonus.perActivatedCounty > 0 && (!party.bonus.perActivatedCountyRoverOnly || sheet.mobile)) {
    parts.push(`**Activated:** ${activated.map((county) => `${county} (${fmtInteger(sheet.activatedCounties[county])})`).join(" • ")}`)
  }

  const countyCodes = Object.keys(party.counties)
  const countiesWorked = countyCodes.filter((code) => sheet.counties[code] !== undefined).length
  parts.push(`### ${fmtInteger(countiesWorked)} of ${fmtInteger(countyCodes.length)} ${party.short} ${party.options.labelForCounties}`)
  parts.push(countyCodes.map((code) => worked(sheet.counties, code)).join(" "))

  if (Object.keys(party.rareCountyMultipliers).length > 0) {
    const rare = Object.keys(party.rareCountyMultipliers).sort()
    const swept = party.bonus.rareCountySweep > 0 && Object.keys(sheet.rareCounties).length >= (party.bonus.rareCountySweepMinimumCount || rare.length)
    parts.push(
      `### ${fmtInteger(Object.keys(sheet.rareCounties).length)} Rare ${party.options.labelForCounties}${swept ? ` • **Sweep! +${fmtInteger(party.bonus.rareCountySweep)}**` : ""}`,
    )
    parts.push(rare.map((code) => worked(sheet.rareCounties, code)).join(" "))
  }

  // The states-and-provinces sweep belongs to the party's own entrants: an
  // out-of-party station's multipliers are its counties, and printing fifty
  // states they can never claim reads as fifty missing ones.
  if (sheet.weAreInParty) {
    const sections = party.options.sectionsForOutOfState
    const tables = outOfPartyTables(party)
    // A code inside the party is one nobody can send us, so it is no part of a
    // chase list — PAQP's own `EPA` and `WPA`, and the party's own state
    // everywhere else. Shown anyway once it HAS been counted: the heading reads
    // `sheet.states` while the list reads the party's table, and a code held by
    // one and hidden by the other prints a count above nothing struck. An
    // in-party station's own state reaches the sheet exactly that way, from a
    // contact whose exchange was never copied (`defaultTheirLocation`).
    //
    // Unless the party's own ground is a multiplier by another route: NEQP
    // scores an in-party contact by STATE and CO counts its own alongside the
    // county, so there those codes are exactly what the list exists to show as
    // still needed. A chase list answers "what is left", and hiding the six
    // New England states until they are worked answers "what is done".
    const o = party.options
    const ownGroundMultiplies = o.stateCountsForInState || !(o.countiesAreMultForInState && o.countiesCountForInState)
    const ours = ownGroundMultiplies ? new Set<string>() : ourOwnCodes(party)
    const chaseable = (table: Record<string, number>, codes: string[]) => codes.filter((code) => !ours.has(code) || table[code] !== undefined)

    parts.push(`### ${fmtInteger(Object.keys(sheet.states).length)} ${sections ? "ARRL Sections" : "US States"}`)
    const states = chaseable(sheet.states, Object.keys(tables.us))
    if (!sections && !party.options.dcCountsAsMaryland) states.push("DC")
    parts.push(states.map((code) => worked(sheet.states, code)).join(" "))

    parts.push(`### ${fmtInteger(Object.keys(sheet.provinces).length)} ${sections ? "RAC Sections" : "Canadian Provinces"}`)
    parts.push(
      chaseable(sheet.provinces, Object.keys(tables.canada))
        .map((code) => worked(sheet.provinces, code))
        .join(" "),
    )

    if (party.options.dxEntityIsMultiplier || party.options.dxIsMultiplier) {
      const entities = Object.keys(sheet.entities).sort()
      const max = party.options.dxEntityMultiplierMax
      // Against the cap, the count has to be the CREDITED one: a 7QP entrant
      // who works twelve entities is credited ten, and "12 of 10" is the one
      // number on this line that cannot be right.
      const claimed = max ? Object.keys(sheet.creditedEntities).length : entities.length
      parts.push(`### ${fmtInteger(claimed)}${max ? ` of ${fmtInteger(max)}` : ""} DX ${party.options.dxEntityIsMultiplier ? "Entities" : "Multiplier"}`)
      if (entities.length > 0) parts.push(entities.map((code) => `**~~${code}~~**`).join(" "))
    }
  }

  const bonusCalls = Object.keys(party.bonusStations)
  if (bonusCalls.length > 0) {
    parts.push(
      `### ${fmtInteger(Object.keys(sheet.bonusStations).length)} of ${fmtInteger(bonusCalls.length)} Bonus Stations${bonusPoints > 0 ? ` • ${fmtInteger(bonusPoints)} pts` : ""}`,
    )
    parts.push(bonusCalls.map((code) => worked(sheet.bonusStations, code)).join(" "))
  }

  const bands = Object.keys(sheet.bands).sort(byWavelength)
  if (bands.length > 0) {
    parts.push(`### ${fmtInteger(sheet.qsos)} QSOs`)
    const byMode = sheet.bandModes ?? {}
    const all: Record<string, number> = {}
    for (const band of bands) {
      for (const [superMode, count] of Object.entries(byMode[band] ?? {})) all[superMode] = (all[superMode] ?? 0) + count
    }
    parts.push(
      [
        ...bands.map((band) => `**${band}**: ${modeBreakdown(byMode[band] ?? {}, sheet.bands[band])}`),
        ...(bands.length > 1 ? [`**All bands**: ${modeBreakdown(all, sheet.qsos)}`] : []),
      ].join("\n"),
    )
  }
  if (sheet.dupes > 0) parts.push(`${fmtInteger(sheet.dupes)} duplicate${sheet.dupes === 1 ? "" : "s"}`)

  return parts.join("\n\n")
}
