// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SAMPLE — a contest: an exchange to type, and a score to keep.
//
// A contest extension is three things. The `activity` hook contributes the
// setup form and the per-QSO exchange field; the `ref:` handler says what the
// operation's contest reference means; the `scoring` hook keeps the score.
//
// The scorer is the part worth studying. It is a FOLD: the host hands you a
// scoresheet and one QSO, you return the scoresheet with that QSO in it. The
// host owns when it runs — a fresh log, a re-score after an edit, a running
// total while operating — so a scorer that reaches for anything outside its
// arguments gives different answers on the same log.
//
// The rules here are CQ WW's, and real: points by continent, multipliers per
// band, one contact per station per band. What this sample leaves out is
// everything around them — Cabrillo export, the ADIF exchange fields, the
// country-file zone suggestion, and writing a guessed exchange onto the QSO.
// See `docs/hooks.md` §`scoring`, and `contests/cqww` in the app's repository
// for the whole thing.

import { annotateCallAgainstCountryFile, contestScorer, defineExtension } from "@ham2k/extension-sdk"
import type {
  ContestScorer,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  ScoreTally,
} from "@ham2k/extension-sdk"
import { fmtInteger } from "@ham2k/lib-format-tools"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = "k2hrcCqww"

/// CQ WW is an HF contest: the WARC bands are excluded by the rules, not by
/// oversight.
const VALID_BANDS = ["160m", "80m", "40m", "20m", "15m", "10m"]

/// A CQ zone as typed: 1-40, with or without a leading zero. The core anchors
/// and case-folds it, so this is only the body.
const ZONE_PATTERN = "0?(?:[1-9]|[1-3][0-9]|40)"

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return ((container.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === type)
}

/// "05" and "5" are the same multiplier and must not count twice.
function normalizeZone(value: JSONValue | undefined): string {
  const digits = String(value ?? "").trim().replace(/^0+(?=\d)/, "")
  return /^([1-9]|[1-3][0-9]|40)$/.test(digits) ? digits : ""
}

type Scoresheet = {
  /// call → the bands already worked with it. One QSO per station per band.
  workedByCall: Record<string, string[]>
  /// Every `band|Z<zone>` and `band|C<entity>` seen. Multipliers are per band,
  /// so the band is part of the key.
  mults: Record<string, number>
  qsos: number
  points: number
  /// Ours, resolved once: every point below is relative to where we are.
  ourContinent?: string
  ourEntity?: string
}

const CQWWScorer: ContestScorer<Scoresheet> = {
  /// Called once at the start of a fold. Anything derived from the operation
  /// belongs here, not in `scoreQso` — this runs once, that runs per contact.
  startScoresheet({ operation }): Scoresheet {
    const ours = annotateCallAgainstCountryFile(str(operation.stationCall))
    return {
      workedByCall: {},
      mults: {},
      qsos: 0,
      points: 0,
      ourContinent: ours.continent,
      ourEntity: ours.entityPrefix,
    }
  },

  /// Mutates and returns the scoresheet it was given.
  ///
  /// The verdict is as important as the number: `dupe` is what greys the QSO
  /// out in the log, and `alerts` is what tells the operator WHY something
  /// scored nothing. A scorer that silently returns 0 leaves them wondering.
  scoreQso({ scoresheet, qso }) {
    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet, score: { value: 0 } }

    const band = str(qso.band)
    if (!VALID_BANDS.includes(band)) {
      return { scoresheet, score: { value: 0, alerts: ["invalidBand"] } }
    }

    const worked = scoresheet.workedByCall[call] ?? []
    if (worked.includes(band)) {
      return { scoresheet, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    const theirs = annotateCallAgainstCountryFile(call)
    // The exchange the operator typed wins; the country file's answer for the
    // callsign is the fallback, so a QSO logged without one still scores.
    const zone = normalizeZone(refOfType(qso, TYPE)?.theirZone) || normalizeZone(theirs.cqZone)

    // Points: nothing within our own DXCC entity, 1 inside our continent, 2
    // for North America to North America, 3 across continents.
    let points = 3
    if (theirs.entityPrefix && theirs.entityPrefix === scoresheet.ourEntity) points = 0
    else if (theirs.continent && theirs.continent === scoresheet.ourContinent) {
      points = theirs.continent === "NA" ? 2 : 1
    }

    scoresheet.workedByCall[call] = [...worked, band]
    scoresheet.qsos += 1
    scoresheet.points += points

    // Two multipliers per contact, each counted once per band: the zone, and
    // the country. Recorded even when the contact is worth no points — working
    // your own country still gives you the multiplier.
    if (zone) scoresheet.mults[`${band}|Z${zone}`] = 1
    if (theirs.entityPrefix) scoresheet.mults[`${band}|C${theirs.entityPrefix}`] = 1

    return { scoresheet, score: { value: points } }
  },

  /// The score as the operator reads it. `scope` is 'day' or the whole
  /// contest; this sample reports the same totals for both, where the real
  /// extension tracks a separate per-day tally.
  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const mults = Object.keys(scoresheet.mults).length
    return {
      [TYPE]: {
        key: TYPE,
        for: scope,
        icon: manifest.icon,
        total: scoresheet.points * mults,
        points: scoresheet.points,
        mults,
        qsos: scoresheet.qsos,
        label: `${fmtInteger(scoresheet.points)} × ${fmtInteger(mults)}`,
        summary: `${fmtInteger(scoresheet.points * mults)}`,
      },
    }
  },
}

const ActivityHook = {
  /// What the operator fills in when adding this contest to an operation.
  async operationControls(
    _args: { operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: "k2hrc-cqww/setup",
        label: "CQ WW DX (sample)",
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: "form",
          // Naming the ref type is what makes the form's values land on a ref
          // of that type on the operation — which is then what the scorer's
          // `scope` matches, and what the handler below decorates.
          refType: TYPE,
          form: {
            title: "CQ WW DX",
            elements: [
              {
                type: "field",
                fieldType: "radio",
                key: "mode",
                label: "Mode",
                // Separate contests on separate weekends, not a filter.
                options: [
                  { value: "CW", label: "CW" },
                  { value: "SSB", label: "SSB" },
                  { value: "RTTY", label: "RTTY" },
                ],
              },
              { type: "field", fieldType: "text", key: "zone", label: "Our CQ zone", placeholder: "8" },
            ],
          },
        },
      },
    ]
  },

  /// The one field typed per QSO.
  ///
  /// Contributed only while this operation is actually running the contest.
  /// The core would refuse it anyway, so this guard is an optimization, not
  /// the rule — but it runs on the typing path, once per enabled contest
  /// extension, which is why it is worth having.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    if (!refOfType(args.operation, TYPE)) return []

    const their = (args.qso?.their as Record<string, JSONValue>) ?? {}
    const guess = (their.guess as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    const suggested =
      normalizeZone(guess.cqZone) || (call ? normalizeZone(annotateCallAgainstCountryFile(call).cqZone) : "")

    return [
      {
        key: "k2hrc-cqww/zone",
        label: "Zone",
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: "text",
          refType: TYPE,
          field: "theirZone",
          numeric: true,
          maxLength: 3,
          pattern: ZONE_PATTERN,
          // The guessed zone for THIS callsign, never a format hint like
          // "1-40" — a hint reads as a real value at a glance.
          placeholder: suggested || undefined,
          // Filled in for the operator, but never over what they typed.
          suggestedValue: suggested || undefined,
        },
      },
    ]
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? "").trim() }
  },

  /// A contest reference names an event, not a place, so what it decorates to
  /// is the contest and the exchange we are sending.
  async decorateRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<Ref> {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const zone = normalizeZone((ref as Record<string, JSONValue>).zone)
    const label = mode ? `CQ WW ${mode}` : "CQ WW DX"
    return {
      ...ref,
      program: "Contest",
      label,
      shortLabel: label,
      name: zone ? `Zone ${zone}` : "Not configured",
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("activity", { hook: ActivityHook, key: manifest.key })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: manifest.key })
    // `scope` is what keeps this scorer out of every operation that is not
    // running this contest.
    registerHook("scoring", {
      hook: contestScorer(CQWWScorer, { scope: { refTypes: [TYPE] } }),
      key: manifest.key,
    })
  },
})
