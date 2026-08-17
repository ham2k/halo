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
  ///
  /// A function when the threshold depends on WHICH reference is being
  /// activated — it is handed the activated reference codes and returns the
  /// bar for the operation. WWBOTA asks 10 contacts in Slovenia and North
  /// Macedonia and 25 everywhere else; ZLOTA asks between 1 and 4 depending on
  /// the kind of place. Both take the HIGHEST bar among the references being
  /// activated at once, which is what app-polo does and the only safe reading:
  /// clearing the easier one first must not declare the harder one done.
  qsosToActivate?: number | ((activatedRefs: string[]) => number)

  /// Whether the award has an activation threshold at all.
  ///
  /// MOTA has duplicate rules but no accumulator in app-polo: it tells the
  /// operator a contact is a repeat and never counts mills toward anything.
  /// Set false and no activation tally is reported — inventing a threshold the
  /// award doesn't have would be worse than showing none. Defaults to true.
  tracksActivation?: boolean

  /// Whether a hunted reference this station hasn't given before rescues the
  /// ACTIVATION credit on a contact that is otherwise a repeat.
  ///
  /// It always earns the reference-to-reference credit. What differs is
  /// whether it also counts toward the activation: WWBOTA says yes, MOTA and
  /// SiOTA say no — "Doesn't count towards activation, but towards Silo 2 Silo
  /// award", in SiOTA's own words. Defaults to true, which is what a program
  /// with no opinion (and every A1 award) gets.
  freshRefRescuesActivation?: boolean
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

  /// Singular/plural noun for one reference of this program's own kind —
  /// POTA's is 'park'/'parks', SOTA's 'summit'/'summits' — used in the
  /// hunting-only summary ("2 parks hunted"). Defaults to the generic
  /// 'reference'/'references'.
  ///
  /// A function, not a bare string, because the word is the program's own
  /// vocabulary and needs translating — this module's catalog has no way to
  /// know what a given activity calls its reference, so the activity resolves
  /// it through its OWN translator (the same `ctx` this module already
  /// receives) rather than handing over an untranslatable English literal.
  refNoun?: string | ((ctx: HookContext) => string)
  refNounPlural?: string | ((ctx: HookContext) => string)
  /// The QSO-noun for a reference-to-reference contact made while activating
  /// — POTA calls this "P2P" (park-to-park), SOTA "S2S". Defaults to the
  /// generic 'ref2ref'. Same translation rule as [refNoun].
  p2pLabel?: string | ((ctx: HookContext) => string)
}

/// Resolves a rule field that may be the activity's own translator function
/// (see [ActivityScoringRules.refNoun]) or a plain string, falling back to
/// this module's own generic wording when the activity declares neither.
function resolveRuleText(
  value: string | ((ctx: HookContext) => string) | undefined,
  ctx: HookContext,
  fallback: string,
): string {
  return typeof value === 'function' ? value(ctx) : (value ?? fallback)
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
  /// The bar for the references actually being activated. Resolved at summary
  /// time rather than up front, because a per-reference rule can't know it
  /// until it knows which references those are.
  function thresholdFor(activatedRefs: string[]): number {
    const rule = rules.qsosToActivate ?? 10
    return typeof rule === 'function' ? rule(activatedRefs) : rule
  }
  const freshRefRescuesActivation = rules.freshRefRescuesActivation ?? true
  const tracksActivation = rules.tracksActivation ?? true
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

      // A contact that is only fresh because it hands over a reference this
      // station hasn't given before. It earns the reference-to-reference
      // credit, but for MOTA and SiOTA it does NOT advance the activation —
      // the operator already worked this station on this band and day.
      const freshRefOnly = verdict === 'ref' && !freshRefRescuesActivation
      const activationCredit = freshRefOnly ? 0 : activationValue

      const score: QsoScoreVerdict = { value: isDupe ? 0 : activationCredit + huntingValue }
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

      // Adding zero still records the reference, so a park whose every contact
      // so far was a repeat still shows in the summary — at 0, which is the
      // truth, rather than vanishing.
      for (const ref of activationRefs) {
        sheet.activatedRefs[ref] = (sheet.activatedRefs[ref] ?? 0) + activationCredit
        sheet.dayActivatedRefs[ref] = (sheet.dayActivatedRefs[ref] ?? 0) + activationCredit
      }
      sheet.activatedQsos += activationCredit
      sheet.dayActivatedQsos += activationCredit
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
      const huntedRefs = perDay ? scoresheet.dayHuntedRefs : scoresheet.huntedRefs
      const huntedQsos = perDay ? scoresheet.dayHuntedQsos : scoresheet.huntedQsos

      if (tracksActivation && Object.keys(activatedRefs).length > 0) {
        // The reference-to-reference credit (POTA's P2P) folds into this
        // line rather than getting a tally of its own — an activating
        // operation reads as one program summary, not two.
        tallies.activation = summarizeActivation(
          activatedRefs,
          perDay ? scoresheet.dayActivatedQsos : scoresheet.activatedQsos,
          perDay ? scoresheet.dayDuplicates : scoresheet.duplicates,
          huntedQsos,
          scope,
          thresholdFor(Object.keys(activatedRefs)),
          rules,
          t,
          ctx,
        )
      } else if (Object.keys(huntedRefs).length > 0) {
        // Only for an operation that never activates anything of its own —
        // otherwise the line above already carries this credit.
        tallies.hunting = summarizeHunting(huntedRefs, huntedQsos, scope, rules, t, ctx)
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
  huntedQsos: number,
  scope: 'day' | 'operation',
  qsosToActivate: number,
  rules: ActivityScoringRules,
  t: Translator,
  ctx: HookContext,
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

  // One line per reference, even for a single park: the operation-info
  // panel's per-day rows show this instead of `summary` (InformationPanel
  // never renders both for the same tally), so a single-park operation still
  // needs its own progress line there.
  const detail = refKeys.map((key) =>
    activatedRefs[key] >= qsosToActivate
      ? `✅ **${key}: ${fmtInteger(activatedRefs[key])}**`
      : `❌ ${key}: ${fmtInteger(activatedRefs[key])}/${fmtInteger(qsosToActivate)}`,
  )

  // "POTA: 47 activation QSOs, 2 P2P QSOs" — singular/plural by explicit
  // ternary, not i18next's `count` pluralization, which needs
  // Intl.PluralRules, absent in QuickJS (core/scoring says the same).
  const parts = [
    qsos === 1 ? t('activationQsoOne') : t('activationQsoMany', { formatted: fmtInteger(qsos) }),
  ]
  if (huntedQsos > 0) {
    const p2p = resolveRuleText(rules.p2pLabel, ctx, t('ref2ref'))
    parts.push(
      huntedQsos === 1
        ? t('p2pQsoOne', { label: p2p })
        : t('p2pQsoMany', { label: p2p, formatted: fmtInteger(huntedQsos) }),
    )
  }

  return {
    key: 'activation',
    for: scope,
    icon: rules.icon,
    total: qsos,
    activated,
    activatedRefs,
    duplicates,
    label: `${rules.label}: ${parts.join(', ')}`,
    summary,
    longSummary: detail.join('\n'),
  }
}

/// The hunter's tally, for an operation with no activation of its own to
/// fold this into. Counts REFERENCES, not contacts: one contact with a
/// station in three parks is three references hunted, which is what the
/// award programs count.
///
/// No `summary`: the count is already spelled out in `label` ("2 parks
/// hunted"), and hunted refs are shown individually as ref icons on each QSO
/// row — a `summary` would make this tally show up as its own badge in the
/// day-header's compact summary, duplicating both.
function summarizeHunting(
  huntedRefs: Record<string, number>,
  qsos: number,
  scope: 'day' | 'operation',
  rules: ActivityScoringRules,
  t: Translator,
  ctx: HookContext,
): ScoreTally {
  const count = Object.keys(huntedRefs).length
  // The noun ("park"/"parks") is the activity's own translated vocabulary;
  // the sentence wrapping it ("N ___ hunted") is this module's own, so it
  // stays translatable even when an activity supplies no noun of its own.
  const noun = count === 1
    ? resolveRuleText(rules.refNoun, ctx, t('reference'))
    : resolveRuleText(rules.refNounPlural, ctx, t('referencesPlural'))
  return {
    key: 'hunting',
    for: scope,
    icon: rules.icon,
    total: count,
    huntedRefs,
    huntedQsos: qsos,
    label: `${rules.label}: ${count === 1 ? t('huntedOne', { noun }) : t('huntedMany', { noun, formatted: fmtInteger(count) })}`,
  }
}
