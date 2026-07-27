// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// State-park event scoring, ported from app-polo's StateParksExtension
// `scoringForQSO` / `accumulateScoreForOperation` / `summarizeScore` into a
// `ContestScorer`.
//
// What these events are, and why this scorer is unlike the six before it: the
// contest is played THROUGH POTA. Points come from the parks — the ones we are
// activating (`potaActivation` refs on the operation) and the ones the station
// we worked is in (`pota` refs on the QSO) — so this is the first scorer that
// reads refs it does not own. It can: the harness hands `scoreQso` the
// segment-effective operation (sdk/src/scoring.ts), so a park added mid-log
// through a segment is seen for exactly the QSOs it covers.
//
// The rules, per event, are data (events.ts). The shape is common to all four:
//   * Points per QSO by super-mode, ×1 per park we are activating, ×1 per NEW
//     park the station is in (a park-to-park pair counts each park).
//   * A station may be worked once per band and mode, and again from a park
//     they hadn't given us on that band and mode.
//   * Multipliers are parks: activated, or activated + hunted, or none.
//   * Bonuses: a listed bonus station, once; and points per park we activate.
//
// DIVERGENCES from polo, per the RFC's fix-on-port decision (§8). Every one of
// these is a live defect there, not a rules disagreement:
//
//   1. `scoring.bonusStations.push(...)` throws — the object is initialised
//      with `bonuses: []` and no `bonusStations` — so working Texas's K5LRK
//      crashes the scorer (StateParksExtension.js:243-281). Bonus stations are
//      credited here, once each.
//   2. The per-park-activated bonus is never awarded. polo guards it on
//      `sp.options.bonusPoints.perParkActivated` while every data file puts
//      `bonusPoints` at the top level, so Texas's and Florida's 100 points per
//      park are dead (`:373-379`).
//   3. `bonusPoints` never reaches the total anyway: polo adds `score.bonus`,
//      a key nothing ever writes (`:389-390`).
//   4. Parks we activate are never counted. polo maps its activation refs to
//      strings and then filters them as if they were still objects
//      (`:228-229`), so `activatedParks` is always empty — which silently
//      turns Georgia's activated-park multiplier into 1 and halves the
//      activated+hunted rule for Texas and Ohio.
//   5. Every POTA activation multiplied a QSO's points, whether or not the park
//      was in the event (`:241`). Only the event's own parks do here.
//   6. Band limits: polo excludes the WARC bands for all four events and never
//      reads the per-event `bands`/`excludedBands` its data files carry, so
//      Ohio's 80-10m rule and Florida's 160-6m rule do nothing there. Honoured
//      here (see events.ts).
//   7. Georgia's 5 points per distinct park (`points.distinctStatePark`) are
//      read by nothing in polo — its own notes call this out as missing.
//      Awarded here to the first contact with each park. This one is a GUESS,
//      not a fix: polo's code cannot settle it and the data only names the
//      number, so "5 points for a park you hadn't worked yet" is a reading of
//      the sponsor's rules that wants a human to confirm it. Every other item
//      here has polo's own data or notes behind it.
//   8. polo's "(N dupes)" counts every zero-scoring QSO, invalid bands
//      included (`:344-347`). Only duplicates are counted here.
//
// Defect 4 has a second half worth stating, because the line range above hides
// it: the SAME string/object mistake is made for the parks it hunts
// (`:231-232`), so for the three events that have no exchange polo credits no
// park on either side — no hunted-park multiplier, and a park-list summary that
// never fills in.
//
// One thing polo does that this CANNOT do, rather than chooses not to: it turns
// a park abbreviation into a `pota` ref on the QSO (`:493-504`), which is how
// its park credit reaches POTA. Cross-extension ref writing is structurally
// refused in HaLo — `qso_patch.dart` drops any patch ref an extension doesn't
// own — so an abbreviation is read straight off our own ref here instead. It is
// the same park either way; what the operator loses is the POTA hunter chip
// filling itself in, which is M9's `georgia-pota` work.
//
//   9. `powerMultipliers` is read by nothing in polo, so a Texas QRP entrant
//      there is scored short of a term the rules give them. Read here, from the
//      power class the setup form now asks for — as a SUMMAND, which is what
//      §6.5.1 makes it despite the name: "total QSO points X (power multiplier +
//      ... worked multiplier + ... activated multiplier) + bonus points".
//
// Not ported, because no shipped event's data uses them: the
// `bonusStationPerMode` / `bonusStationPerBandMode` options.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/halo-extension-sdk"

import { powerMultiplier } from "./entry.ts"
import { bandCounts, eventFor, type StateParkEvent } from "./events.ts"
import { ourParkRefs, refOfType, theirParkAbbreviation, theirParkRefs } from "./parks.ts"

/// QSOs a park needs before it counts as ACTIVATED — POTA's own threshold, and
/// the one polo uses. A park worked from for an hour is a park activated; a
/// park worked from for three QSOs is not, and neither its multiplier nor its
/// bonus is claimable.
export const QSOS_TO_ACTIVATE = 10

export type StateParksScoresheet = {
  /// The event these totals are for, recorded from the first QSO scored.
  ///
  /// `summarizeScore` needs the event's multiplier rule and park list, and the
  /// ref it is handed is the BASE operation's — a segmented log whose event ref
  /// arrives only in a later segment would summarize against no event at all
  /// (sdk/src/scoring.ts: the batch pass passes `args.ref` to `summarizeScore`
  /// while `scoreQso` gets the segment's). Everything the summary needs is
  /// therefore accumulated here as the fold goes, which is the same reason NAQP's
  /// summary ignores `operation` and `ref` entirely.
  eventKey?: string
  /// What our power class adds to the multiplier sum, recorded from the first
  /// QSO scored for the same reason `eventKey` is: `summarizeScore` is handed
  /// the BASE operation's ref, and on a segmented log the event — and so the
  /// power class declared alongside it — may arrive only in a later segment.
  powerMult?: number
  /// call → `band|SUPERMODE` → the parks already credited in that slot. `''`
  /// stands for a contact from no park in the event, so an ordinary QSO still
  /// occupies the slot and a second one is a duplicate.
  worked: Record<string, Record<string, string[]>>
  /// Our own park refs → QSOs made from each. Counted because a park is only
  /// activated at `QSOS_TO_ACTIVATE`.
  activated: Record<string, number>
  /// Their park refs → QSOs worked in each.
  hunted: Record<string, number>
  /// Bonus station call → the points it paid, once.
  bonusStations: Record<string, number>
  bands: Record<string, number>
  modes: Record<string, number>
  qsos: number
  points: number
  dupes: number
  dayQsos: number
  dayPoints: number
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// Which parks a QSO is worth comes from `parks.ts`, shared with the hooks that
/// export the log: the number scored has to be the number submitted, and when
/// the scorer and the Cabrillo writer resolved this separately they disagreed
/// (see that module's header).

export const StateParksScorer: ContestScorer<StateParksScoresheet> = {
  startScoresheet(): StateParksScoresheet {
    return {
      worked: {}, activated: {}, hunted: {}, bonusStations: {},
      bands: {}, modes: {},
      qsos: 0, points: 0, dupes: 0, dayQsos: 0, dayPoints: 0,
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  scoreQso({ scoresheet: sheet, qso, operation, ref, isNewDay }) {
    if (isNewDay) {
      sheet.dayQsos = 0
      sheet.dayPoints = 0
    }

    // A ref naming an event this build doesn't know — a log synced from a newer
    // app, or next year's event added to polo first. Scoring it against another
    // event's park list would be worse than declining to: 0 points and a
    // visible alert is honest, and the QSO itself is untouched.
    const event = eventFor(str(ref?.ref))
    if (!event) return { scoresheet: sheet, score: { value: 0, alerts: ['unknownEvent'] } }
    sheet.eventKey ??= event.key
    // The first DECLARED class wins, not the first QSO's answer: `??=` would
    // treat the 0 that stands for "no class declared" as an answer and latch it,
    // so a class arriving in a later segment — the very case this is recorded
    // for — could never fill it in.
    if (!sheet.powerMult) sheet.powerMult = powerMultiplier(event, operation, ref)

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: sheet, score: { value: 0 } }

    // A QSO with NO band is rejected here, while one with no mode below keeps
    // its point — deliberately, and not the same question. A missing mode leaves
    // the points ambiguous; a missing band leaves the QSO unverifiable against
    // any of these events' rules, and two of the four publish a band list a log
    // checker will hold the operator to. Saying `invalidBand` out loud is how an
    // import that lost its BAND column becomes visible instead of scoring.
    const band = str(qso.band)
    if (!bandCounts(event, band)) {
      return { scoresheet: sheet, score: { value: 0, alerts: ['invalidBand'] } }
    }

    // A QSO with no mode keeps the per-QSO default rather than being judged:
    // `superModeForMode('')` answers `DATA`, which would quietly price an
    // ADIF import missing MODE as a digital contact.
    const mode = str(qso.mode)
    const superMode = mode ? superModeForMode(mode) : ''
    // No event lists points for every mode it allows — Ohio names PHONE and CW
    // only — so an unlisted mode is worth the base point rather than nothing.
    // polo's fallback, kept deliberately: zeroing a digital contact is a rules
    // claim this port has no source for.
    const modePoints = event.points[superMode] ?? 1

    const ourParks = ourParkRefs(event, operation, ref)
    const theirParks = theirParkRefs(event, qso)

    // `''` when they were in no park in the event: the slot is still occupied,
    // so a second plain contact on the same band and mode is a duplicate.
    const claims = theirParks.length > 0 ? theirParks : ['']
    const slot = `${band}|${superMode}`
    const bySlot = (sheet.worked[call] ??= {})
    const credited = bySlot[slot]
    // A slot that has been credited ANYTHING is closed to a parkless claim: once
    // a station has been worked on this band and mode, the only thing that earns
    // another contact is a park they hadn't given us. Filtering only against
    // `credited` let `''` through as though "no park" were a park the slot was
    // still missing, so a park contact followed by a parkless one — the same
    // operator having left the park, or the hunter chip simply not logged that
    // time — scored twice.
    const fresh = credited ? claims.filter((park) => park && !credited.includes(park)) : claims

    if (credited && fresh.length === 0) {
      sheet.dupes += 1
      return { scoresheet: sheet, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    const slots = Object.keys(bySlot)
    const workedBefore = slots.length > 0
    const sameBand = slots.some((key) => key.startsWith(`${band}|`))
    const sameMode = slots.some((key) => key.endsWith(`|${superMode}`))

    const freshParks = fresh.filter((park) => park)
    // Parks new to the whole log, not just to this slot — what earns Georgia's
    // per-park points and what the operator wants told about.
    const newParks = freshParks.filter((park) => sheet.hunted[park] === undefined)

    // Each park we activate multiplies, and so does each park of theirs we
    // hadn't had on this band and mode: a park-to-park pair is a contact for
    // every combination of the two.
    let value = modePoints * (ourParks.length || 1) * (freshParks.length || 1)
    value += newParks.length * event.pointsPerDistinctPark

    const notices: string[] = []
    if (workedBefore && !sameBand) notices.push('newBand')
    if (workedBefore && !sameMode) notices.push('newMode')
    if (newParks.length > 0) notices.push('newPark')

    // Bonus stations pay once, and only the first contact says so — the rest
    // are ordinary QSOs with that station.
    const baseCall = (str(their.baseCall) || str(((their.guess as Record<string, JSONValue>) ?? {}).baseCall) || call).toUpperCase()
    const bonus = event.bonusStations[baseCall]
    if (bonus !== undefined && sheet.bonusStations[baseCall] === undefined) {
      sheet.bonusStations[baseCall] = bonus
      notices.push('bonusStation')
    }

    bySlot[slot] = credited ? [...credited, ...fresh] : [...fresh]
    for (const park of theirParks) sheet.hunted[park] = (sheet.hunted[park] ?? 0) + 1
    for (const park of ourParks) sheet.activated[park] = (sheet.activated[park] ?? 0) + 1
    if (band) sheet.bands[band] = (sheet.bands[band] ?? 0) + 1
    if (superMode) sheet.modes[superMode] = (sheet.modes[superMode] ?? 0) + 1
    sheet.qsos += 1
    sheet.points += value
    sheet.dayQsos += 1
    sheet.dayPoints += value

    const score: QsoScoreVerdict = { value, band }
    if (notices.length > 0) score.notices = notices
    // An event whose exchange IS a park abbreviation and got nothing usable is
    // a park going unclaimed — a multiplier for two of the four events, and a
    // typo the operator can still fix while the QSO is in front of them.
    if (event.usesParkAbbreviations && theirParks.length === 0) {
      score.alerts = [theirParkAbbreviation(event, qso) ? 'invalidExchange' : 'missingExchange']
    }

    return { scoresheet: sheet, score }
  },

  summarizeScore({ scoresheet: sheet, ref, scope }): Record<string, ScoreTally> {
    // The scoresheet's own record first: it was written from the ref each QSO
    // was actually scored against, while `ref` here is the base operation's.
    const event = eventFor(sheet.eventKey) ?? eventFor(str(ref?.ref))
    const isDay = scope === 'day'

    const activated = Object.values(sheet.activated).filter((qsos) => qsos >= QSOS_TO_ACTIVATE).length
    const hunted = Object.keys(sheet.hunted).length
    const parkMult = event?.multipliers === 'stateParksActivatedAndHunted'
      ? activated + hunted
      : event?.multipliers === 'stateParksActivated'
        ? activated
        : 0
    // The power class ADDS to the park multipliers rather than scaling them
    // (events.ts), and is 0 for the three events that publish no such term and
    // for a class the operator never declared. `|| 1` is the floor either way:
    // a log with no parks yet is still worth its points.
    const mult = (parkMult + (sheet.powerMult ?? 0)) || 1

    const bonusPoints = Object.values(sheet.bonusStations).reduce((sum, points) => sum + points, 0)
      + activated * (event?.bonusPointsPerParkActivated ?? 0)

    const points = isDay ? sheet.dayPoints : sheet.points
    // Multipliers and bonuses are won across the whole event, so a day's figure
    // is its own points against the running multiplier — the same reading NAQP
    // takes of the same question. Bonuses are left out of it entirely rather
    // than counted again on every day.
    const total = isDay ? points * mult : points * mult + bonusPoints

    return {
      stateparks: {
        key: 'stateparks',
        for: scope,
        icon: 'flag-checkered',
        total,
        points,
        mults: mult,
        qsos: isDay ? sheet.dayQsos : sheet.qsos,
        label: bonusPoints > 0 && !isDay
          ? `${fmtInteger(points)} × ${fmtInteger(mult)} + ${fmtInteger(bonusPoints)}`
          : `${fmtInteger(points)} × ${fmtInteger(mult)}`,
        summary: `${fmtInteger(total)}`,
        longSummary: event ? longSummaryFor(event, sheet, { activated, hunted, bonusPoints }) : '',
      },
    }
  },
}

/// The tables a state-park operator actually reads while operating: which of
/// the event's parks are in the log, which bonus stations are still out there,
/// and the per-band split.
function longSummaryFor(
  event: StateParkEvent,
  sheet: StateParksScoresheet,
  totals: { activated: number; hunted: number; bonusPoints: number },
): string {
  const parts: string[] = []

  if (totals.activated > 0 || Object.keys(sheet.activated).length > 0) {
    const ours = Object.entries(sheet.activated)
      .map(([park, qsos]) => `${labelFor(event, park)} (${fmtInteger(qsos)})`)
      .join(' • ')
    parts.push(`**Activating:** ${ours}`)
  }

  if (Object.keys(event.bonusStations).length > 0) {
    const stations = Object.keys(event.bonusStations)
      .map((call) => (sheet.bonusStations[call] !== undefined ? `**~~${call}~~**` : call))
      .join(' ')
    parts.push(`### Bonus stations\n${stations}`)
  }

  const parkList = event.parks
    .map((park) => {
      const label = park.abbreviation ?? park.ref
      return sheet.hunted[park.ref] !== undefined ? `**~~${label}~~**` : label
    })
    .join(' ')
  parts.push(`### ${fmtInteger(totals.hunted)} of ${fmtInteger(event.parks.length)} parks worked\n${parkList}`)

  const bands = Object.keys(sheet.bands).sort()
  if (bands.length > 0) {
    parts.push(bands.map((band) => `**${band}**: ${fmtInteger(sheet.bands[band])} QSOs`).join('\n'))
  }

  return parts.join('\n\n')
}

/// A park's abbreviation where the event has them, else its POTA reference.
function labelFor(event: StateParkEvent, ref: string): string {
  return event.parkByRef[ref]?.abbreviation ?? ref
}
