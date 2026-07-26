// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Activity scoring: the rules an "on the air" reference program is scored by —
// how many contacts a reference still needs before it counts as activated,
// which repeat contacts are duplicates rather than fresh credit, and how many
// references a hunter has worked.
//
// This is a `ContestScorer` FACTORY, not a second harness. `contestScorer` in
// scoring.ts already owns the fold, the checkpointing, day sectioning, the live
// candidate and segment resolution, so an activity registers exactly the way a
// contest does and inherits all of it:
//
//   registerHook('scoring', {
//     hook: contestScorer(activityScorer(POTA_RULES), {
//       scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE] },
//     }),
//     key: 'pota',
//   })
//
// Ported from app-polo's `src/extensions/shared/activityScoring.js`, rules
// intact. Two departures in HOW, not what, documented at their sites:
// activation refs are read off the operation rather than taken from the
// harness's singular `ref` (`activationRefsOf`), and duplicate detection folds
// a running scoresheet instead of re-scanning the whole log per QSO
// (`DUPE RECORDS`).
//
// Types, the translator and `contestScorer` come in by relative path, not the
// `@ham2k/halo-extension-sdk` alias, so this module's tests can run under plain
// `node --test` — the same constraint dxcc.ts and core/scoring document.

import { createCachedTranslator, createTranslator } from "./i18n.ts"
import type { ContestScorer, HookContext, JSONValue, QsoScoreVerdict, ScoreTally } from "./types.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"

import en from "./i18n/activityScoring.en.json" with { type: "json" }
import es from "./i18n/activityScoring.es.json" with { type: "json" }

type Translator = ReturnType<typeof createTranslator>

const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

const DAY_IN_MILLIS = 1000 * 60 * 60 * 24

/// The axes on which a repeat contact with the same station counts again
/// instead of being a duplicate. Applied in the fixed order day → band → mode →
/// ref, which is app-polo's order and is what decides WHICH notice a fresh
/// contact gets when several axes changed at once.
export type UniqueAxis = 'day' | 'band' | 'mode' | 'ref'

export interface ActivityScoringRules {
  /// Short program name, used as the tally label — 'POTA', 'WWFF'.
  label: string
  /// MDI icon name for the tally rows.
  icon?: string
  /// The ref type an OPERATION carries while activating ('potaActivation').
  activationType: string
  /// The ref type a QSO carries for a reference being hunted ('pota'). Omit it
  /// for a program with no hunting side at all — several of the castle and
  /// lighthouse awards only recognise activations, and app-polo expresses that
  /// by simply leaving `huntingType` off its Info.
  huntingType?: string
  /// Contacts one reference needs before it counts as activated. POTA is 10,
  /// SOTA 4, WWFF 44.
  qsosToActivate?: number
  /// Whether ONE contact can credit several hunted references — POTA n-fers do,
  /// SOTA does not (only the first ref on the QSO counts).
  allowsMultipleReferences?: boolean
  /// Which axes make a repeat contact fresh again. Empty means any repeat
  /// contact with the same station is a duplicate. `readonly` so an activity
  /// can write its rules as an `as const` literal.
  uniquePer?: readonly UniqueAxis[]
  /// `'daily'` — a reference is activated per UTC day (POTA, SOTA), so the day
  /// tally reports that day alone. `'once'` — the count accrues across the
  /// whole operation (WWFF's 44 contacts may span days), so the day tally
  /// reports the running total. Defaults to `'daily'`.
  activates?: 'daily' | 'once'
}

/// Everything the rules accumulate. A type alias, not an interface, so it stays
/// assignable to `Scoresheet` (interfaces get no implicit index signature);
/// every field is JSON so the core can snapshot it as a checkpoint.
export type ActivityScoresheet = {
  /// call → one packed record per prior contact with it (see `packContact`).
  /// This is what replaces app-polo's per-QSO `filterNearDupes` scan.
  workedByCall: Record<string, string[]>
  /// Reference code → contacts credited to activating it.
  activatedRefs: Record<string, number>
  /// Reference code → contacts credited to hunting it.
  huntedRefs: Record<string, number>
  activatedQsos: number
  huntedQsos: number
  duplicates: number
  /// Day-scoped mirrors of the four above, reset on each new UTC day when
  /// `activates: 'daily'`.
  dayActivatedRefs: Record<string, number>
  dayHuntedRefs: Record<string, number>
  dayActivatedQsos: number
  dayHuntedQsos: number
  dayDuplicates: number
}

function str(value: JSONValue | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

/// Refs of one type carried by a QSO or an operation, in the order stored.
function refsOfType(container: Record<string, JSONValue>, type: string): string[] {
  const refs = (container.refs as Record<string, JSONValue>[] | undefined) ?? []
  return refs
    .filter((r) => r && r.type === type && typeof r.ref === 'string' && r.ref.length > 0)
    .map((r) => r.ref as string)
}

// --- DUPE RECORDS ----------------------------------------------------------
// One prior contact, packed into a string so a checkpoint stays small (the
// harness JSON round-trips it once per call). The same shape core/scoring uses
// for `workedByCall`, widened from `band|mode` to the four axes `uniquePer` can
// test. Days are stored as a day NUMBER, not millis, so the field is short.

function packContact(day: number, band: string, mode: string, refs: string[]): string {
  return `${day}|${band}|${mode}|${[...refs].sort().join(',')}`
}

interface Contact {
  day: number
  band: string
  mode: string
  refs: string[]
}

function unpackContact(packed: string): Contact {
  const [day, band, mode, refs] = packed.split('|')
  return {
    day: Number(day),
    band,
    mode,
    refs: refs ? refs.split(',') : [],
  }
}

export function activityScorer(rules: ActivityScoringRules): ContestScorer<ActivityScoresheet> {
  const qsosToActivate = rules.qsosToActivate ?? 10
  const allowsMultiple = rules.allowsMultipleReferences ?? false
  const activatesDaily = (rules.activates ?? 'daily') === 'daily'
  const unique = new Set<UniqueAxis>(rules.uniquePer ?? [])

  /// The references this operation is activating.
  ///
  /// Read off the OPERATION rather than taken from the harness's `ref`, which
  /// resolves a single ref (`refs.find(...)`) — right for a contest, which has
  /// one, but a POTA n-fer activates several parks at once and every one of
  /// them earns credit for every contact. app-polo reaches the same place from
  /// the other side, pushing one scoring handler per operation ref that all
  /// share one score object keyed by ref type
  /// (`src/extensions/scoring/index.js:139`).
  function activationRefsOf(operation: Record<string, JSONValue>): string[] {
    return refsOfType(operation, rules.activationType)
  }

  /// The references this contact hunted. Without `allowsMultipleReferences`
  /// only the first counts, matching app-polo. Always empty for a program with
  /// no hunting side, which then scores one per contact and reports no hunting
  /// tally at all.
  function huntedRefsOf(qso: Record<string, JSONValue>): string[] {
    if (!rules.huntingType) return []
    const refs = refsOfType(qso, rules.huntingType)
    return allowsMultiple ? refs : refs.slice(0, 1)
  }

  /// app-polo's near-dupe rules, run against the folded scoresheet instead of
  /// the log. Filters run in a FIXED order and the first one to empty the
  /// candidate list names the notice — so a contact that is new on both day and
  /// band reports `newDay`, not both.
  ///
  /// Returns the notice, or `'duplicate'` when candidates survive every enabled
  /// filter. `undefined` means this station has not been worked before at all.
  function judge(priors: string[], now: Contact): 'duplicate' | UniqueAxis | undefined {
    if (priors.length === 0) return undefined

    let candidates = priors.map(unpackContact)
    let notice: UniqueAxis | undefined

    if (unique.has('day')) {
      candidates = candidates.filter((c) => c.day === now.day)
      if (candidates.length === 0) notice ??= 'day'
    }
    if (unique.has('band')) {
      candidates = candidates.filter((c) => c.band === now.band)
      if (candidates.length === 0) notice ??= 'band'
    }
    if (unique.has('mode')) {
      candidates = candidates.filter((c) => c.mode === now.mode)
      if (candidates.length === 0) notice ??= 'mode'
    }
    if (unique.has('ref')) {
      // A prior stays a duplicate when it shares a hunted reference with this
      // contact, or when neither carries one at all.
      candidates = candidates.filter(
        (c) =>
          (c.refs.length === 0 && now.refs.length === 0) ||
          c.refs.some((r) => now.refs.includes(r)),
      )
      // Unlike the other axes, a fresh reference is only news when there IS
      // one — dropping every candidate because this contact has no reference
      // yet is not a new reference.
      if (candidates.length === 0 && now.refs.length > 0) notice ??= 'ref'
    }

    if (notice) return notice
    return candidates.length > 0 ? 'duplicate' : undefined
  }

  const NOTICE_KEYS: Record<UniqueAxis, string> = {
    day: 'newDay',
    band: 'newBand',
    mode: 'newMode',
    ref: 'newRef',
  }

  return {
    startScoresheet(): ActivityScoresheet {
      return {
        workedByCall: {},
        activatedRefs: {}, huntedRefs: {},
        activatedQsos: 0, huntedQsos: 0, duplicates: 0,
        dayActivatedRefs: {}, dayHuntedRefs: {},
        dayActivatedQsos: 0, dayHuntedQsos: 0, dayDuplicates: 0,
      }
    },

    // Mutates and returns the scoresheet it is handed, which the contract
    // allows and core/scoring measured the case for: copying accumulated state
    // per QSO makes a full pass quadratic. The harness copies any resume
    // checkpoint at its boundary, so nothing cached is ever aliased.
    scoreQso({ scoresheet, qso, operation, isNewDay }) {
      const sheet = scoresheet
      if (isNewDay && activatesDaily) {
        sheet.dayActivatedRefs = {}
        sheet.dayHuntedRefs = {}
        sheet.dayActivatedQsos = 0
        sheet.dayHuntedQsos = 0
        sheet.dayDuplicates = 0
      }

      const their = (qso.their as Record<string, JSONValue>) ?? {}
      const call = str(their.call)
      if (!call) return { scoresheet: sheet, score: { value: 0 } }

      const activationRefs = activationRefsOf(operation)
      const huntedRefs = huntedRefsOf(qso)

      // --- ACTIVATION CREDIT ---------------------------------------------
      // A contact advances each activated reference by ONE — except a
      // park-to-park contact with a station declaring several references, which
      // advances it by one PER REFERENCE. That is the programs' own convention,
      // not an accident of arithmetic: a single on-air contact with a two-park
      // station is submitted as two records, one per reference, and counts as
      // two contacts toward the activation. A station at one reference, or at
      // none at all, is one contact — which is what the `|| 1` says.
      //
      // Only `allowsMultipleReferences` programs can reach a count above one;
      // elsewhere `huntedRefsOf` has already sliced to at most one reference.
      const activationValue = activationRefs.length > 0 ? (huntedRefs.length || 1) : 0
      // The hunting side is per-reference too: working a station in three parks
      // earns three park credits.
      const huntingValue = huntedRefs.length

      const day = Math.floor(Number(qso.startAtMillis ?? 0) / DAY_IN_MILLIS)
      const band = str(qso.band) ?? ''
      const mode = str(qso.mode) ?? ''
      const now: Contact = { day, band, mode, refs: huntedRefs }

      const priors = sheet.workedByCall[call] ?? []
      const verdict = judge(priors, now)
      const isDupe = verdict === 'duplicate'

      const score: QsoScoreVerdict = { value: isDupe ? 0 : activationValue + huntingValue }
      if (isDupe) {
        score.dupe = true
        score.alerts = ['duplicate']
      } else if (verdict) {
        score.notices = [NOTICE_KEYS[verdict]]
      }

      const packed = packContact(day, band, mode, huntedRefs)
      if (priors.length > 0) priors.push(packed)
      else sheet.workedByCall[call] = [packed]

      if (isDupe) {
        sheet.duplicates += 1
        sheet.dayDuplicates += 1
        return { scoresheet: sheet, score }
      }

      for (const ref of activationRefs) {
        sheet.activatedRefs[ref] = (sheet.activatedRefs[ref] ?? 0) + activationValue
        sheet.dayActivatedRefs[ref] = (sheet.dayActivatedRefs[ref] ?? 0) + activationValue
      }
      sheet.activatedQsos += activationValue
      sheet.dayActivatedQsos += activationValue
      for (const ref of huntedRefs) {
        sheet.huntedRefs[ref] = (sheet.huntedRefs[ref] ?? 0) + 1
        sheet.dayHuntedRefs[ref] = (sheet.dayHuntedRefs[ref] ?? 0) + 1
      }
      sheet.huntedQsos += huntingValue
      sheet.dayHuntedQsos += huntingValue

      return { scoresheet: sheet, score }
    },

    summarizeScore({ scoresheet, scope }, ctx): Record<string, ScoreTally> {
      const t = tFor(ctx)
      // A `'once'` program's day row reports the running total rather than that
      // day alone: its 44 contacts accrue across days, so a per-day count would
      // never reach the threshold it is shown against. This is app-polo's
      // choice of accumulator per activity, expressed as a rule rather than as
      // which function got registered.
      const perDay = scope === 'day' && activatesDaily

      const tallies: Record<string, ScoreTally> = {}
      const activatedRefs = perDay ? scoresheet.dayActivatedRefs : scoresheet.activatedRefs
      if (Object.keys(activatedRefs).length > 0) {
        tallies.activation = summarizeActivation(
          activatedRefs,
          perDay ? scoresheet.dayActivatedQsos : scoresheet.activatedQsos,
          perDay ? scoresheet.dayDuplicates : scoresheet.duplicates,
          scope,
          qsosToActivate,
          rules,
          t,
        )
      }

      const huntedRefs = perDay ? scoresheet.dayHuntedRefs : scoresheet.huntedRefs
      if (Object.keys(huntedRefs).length > 0) {
        tallies.hunting = summarizeHunting(
          huntedRefs,
          perDay ? scoresheet.dayHuntedQsos : scoresheet.huntedQsos,
          scope,
          rules,
          t,
        )
      }

      return tallies
    },
  }
}

/// The activator's progress: how far the WEAKEST reference still is from the
/// threshold, since an n-fer is only fully activated once every reference
/// clears it.
function summarizeActivation(
  activatedRefs: Record<string, number>,
  qsos: number,
  duplicates: number,
  scope: 'day' | 'operation',
  qsosToActivate: number,
  rules: ActivityScoringRules,
  t: Translator,
): ScoreTally {
  const refKeys = Object.keys(activatedRefs).sort()
  const lowest = Math.min(...refKeys.map((key) => activatedRefs[key]))
  const activated = lowest >= qsosToActivate

  // Below the threshold the operator wants the gap ("7/10"); above it, the
  // count plus a tick per reference cleared. Past five references the ticks
  // stop being countable at a glance and become "✓ x 8".
  let summary: string
  if (!activated) summary = `${fmtInteger(lowest)}/${fmtInteger(qsosToActivate)}`
  else if (refKeys.length < 6) summary = `${fmtInteger(lowest)} ${'✓'.repeat(refKeys.length)}`
  else summary = `${fmtInteger(lowest)} ✓ x ${fmtInteger(refKeys.length)}`

  // Only worth breaking out per reference when there IS more than one: for a
  // single park the row would just restate the summary beside it.
  const detail = refKeys.length > 1
    ? refKeys.map((key) =>
        activatedRefs[key] >= qsosToActivate
          ? `✅ **${key}: ${fmtInteger(activatedRefs[key])}**`
          : `❌ ${key}: ${fmtInteger(activatedRefs[key])}/${fmtInteger(qsosToActivate)}`,
      )
    : []

  return {
    key: 'activation',
    for: scope,
    icon: rules.icon,
    total: qsos,
    activated,
    activatedRefs,
    duplicates,
    // Singular/plural by explicit ternary, not i18next's `count` pluralization,
    // which needs Intl.PluralRules — absent in QuickJS (core/scoring says the
    // same).
    label: qsos === 1
      ? t('activatingOne', { program: rules.label })
      : t('activatingMany', { program: rules.label, formatted: fmtInteger(qsos) }),
    summary,
    longSummary: detail.join('\n'),
  }
}

/// The hunter's tally. Counts REFERENCES, not contacts: one contact with a
/// station in three parks is three references hunted, which is what the award
/// programs count.
function summarizeHunting(
  huntedRefs: Record<string, number>,
  qsos: number,
  scope: 'day' | 'operation',
  rules: ActivityScoringRules,
  t: Translator,
): ScoreTally {
  const count = Object.keys(huntedRefs).length
  return {
    key: 'hunting',
    for: scope,
    icon: rules.icon,
    total: count,
    huntedRefs,
    huntedQsos: qsos,
    label:
      count === 1
        ? t('huntedOne', { program: rules.label })
        : t('huntedMany', { program: rules.label, formatted: fmtInteger(count) }),
    summary: fmtInteger(count),
  }
}
