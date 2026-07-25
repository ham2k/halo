// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Core scoring: duplicate detection, DXCC entities worked, and bands/modes
// worked. Originally ported from web-lofi's day-sectioning/handler-accumulation
// model; now expressed as a `ContestScorer` (docs/design/contests.md §5.2) so it
// runs as an ordinary peer scorer alongside any contest rather than being the
// one hardcoded scorer. The per-QSO loop, day sectioning and the live path all
// come from the shared harness, which still makes one coarse bridge call
// (DESIGN.md §4: "score 500 QSOs in one call, not 500 calls").
//
// Its three rules are deliberately PRIVATE to the scoresheet. Contests don't
// share a rule vocabulary, so what leaves this module is only a merged per-QSO
// verdict (notices/alerts/points) plus summary tallies whose keys are this
// scorer's own — `qsoCount`, `dxcc`, `bandsAndModes`.
//
// US States and Canadian Provinces rules (web-lofi's USStatesScoringHandler /
// CanadianProvincesScoringHandler) are still deferred — see DESIGN.md §11.
//
// `entityPrefixForCall`, the translator and the scoring harness all come in by
// relative path, not the `@ham2k/halo-extension-sdk` alias, so this module's
// tests can run under plain `node --test` (which can't resolve that
// tsc/esbuild-only bare specifier). `index.ts` keeps the alias for
// `defineExtension` and is the one module the tests don't import.

import { entityPrefixForCall } from "../../../sdk/src/dxcc.ts"
import { createCachedTranslator, createTranslator } from "../../../sdk/src/i18n.ts"
import { contestScorer } from "../../../sdk/src/scoring.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/halo-extension-sdk"

// User-visible tally labels; the per-locale catalogs live in
// i18n/<locale>.json (flat key → string maps). Singular/plural is
// picked with explicit ternaries in the summarize functions (not i18next's
// `count` pluralization, which needs Intl.PluralRules — absent in QuickJS).
import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

type Translator = ReturnType<typeof createTranslator>

/// Translator for this extension's strings, cached per locale — `ctx.locale`
/// only changes when the app's locale setting does.
const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

/// Everything the three rules accumulate. A type alias (not an interface) so it
/// stays assignable to `Scoresheet`; every field is JSON so the core can
/// snapshot it as a checkpoint.
export type CoreScoresheet = {
  /// call → "band|mode" combinations already worked with it (dupe detection).
  workedByCall: Record<string, string[]>
  /// DXCC entity prefix → contacts, and band/mode → contacts.
  entities: Record<string, number>
  bands: Record<string, number>
  modes: Record<string, number>
  qsos: number
  points: number
  duplicates: number
  /// Contacts that brought a band or a mode the operation hadn't worked yet.
  /// Counted rather than derived from `bands`/`modes` above, because a QSO that
  /// is new on BOTH axes still credits once.
  bandModeQsos: number
  /// Reset on each new UTC day — `qsoCount` is a per-day tally, while the
  /// entity and band/mode tallies deliberately carry across the operation.
  dayQsos: number
  dayPoints: number
  dayDuplicates: number
}

function str(value: JSONValue | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

export const CoreScorer: ContestScorer<CoreScoresheet> = {
  startScoresheet(): CoreScoresheet {
    return {
      workedByCall: {}, entities: {}, bands: {}, modes: {},
      qsos: 0, points: 0, duplicates: 0, bandModeQsos: 0,
      dayQsos: 0, dayPoints: 0, dayDuplicates: 0,
    }
  },

  // Mutates and returns the scoresheet it's given, which the contract
  // explicitly allows: spreading the worked-call map per QSO made a full pass
  // quadratic (289ms for 5,000 QSOs against 18ms for 1,000). The harness copies
  // any resume checkpoint at its boundary, so nothing cached is ever aliased.
  scoreQso({ scoresheet, qso, isNewDay }) {
    const base = scoresheet
    if (isNewDay) {
      base.dayQsos = 0
      base.dayPoints = 0
      base.dayDuplicates = 0
    }

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band) ?? ''
    const mode = str(qso.mode) ?? ''
    const bandMode = `${band}|${mode}`
    const prior = base.workedByCall[call] ?? []

    // --- Rule 1: duplicate contacts ---------------------------------------
    const isDupe = prior.includes(bandMode)

    const notices = new Set<string>()
    const alerts = new Set<string>()
    if (isDupe) {
      alerts.add('duplicate')
    } else if (prior.length > 0) {
      // Worked before, but not on this combination — worth calling out.
      if (!prior.some((combo) => combo.endsWith(`|${mode}`))) notices.add('newMode')
      if (!prior.some((combo) => combo.startsWith(`${band}|`))) notices.add('newBand')
    }

    // --- Rule 2: DXCC entities worked --------------------------------------
    const entityPrefix = entityPrefixForCall(call)
    if (entityPrefix && base.entities[entityPrefix] === undefined) notices.add('newDXCC')

    // --- Rule 3: bands and modes worked ------------------------------------
    // Operation-level, unlike rule 1's per-call check: the operation's first
    // 40m contact is a new band even when that station is new too. Read BEFORE
    // recording below, or the QSO would mask itself.
    const isNewBand = Boolean(band) && base.bands[band] === undefined
    const isNewMode = Boolean(mode) && base.modes[mode] === undefined
    if (isNewBand) notices.add('newBand')
    if (isNewMode) notices.add('newMode')
    // Credits once for a QSO that is new on either axis — a first 15m contact
    // counts even when its mode was already worked.
    const broughtBandOrMode = isNewBand || isNewMode

    // A dupe is by definition neither a new band, a new mode, nor a new
    // entity — it contributes nothing, so it carries only its alert.
    if (isDupe) notices.clear()

    const score: QsoScoreVerdict = { value: isDupe ? 0 : 1 }
    if (isDupe) score.dupe = true
    if (notices.size > 0) score.notices = [...notices]
    if (alerts.size > 0) score.alerts = [...alerts]

    const points = score.value
    if (!isDupe) {
      if (prior.length > 0) prior.push(bandMode)
      else base.workedByCall[call] = [bandMode]
    }
    if (entityPrefix) base.entities[entityPrefix] = (base.entities[entityPrefix] ?? 0) + 1
    if (band) base.bands[band] = (base.bands[band] ?? 0) + 1
    if (mode) base.modes[mode] = (base.modes[mode] ?? 0) + 1
    base.qsos += 1
    base.points += points
    base.duplicates += isDupe ? 1 : 0
    base.bandModeQsos += broughtBandOrMode ? 1 : 0
    base.dayQsos += 1
    base.dayPoints += points
    base.dayDuplicates += isDupe ? 1 : 0

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }, ctx): Record<string, ScoreTally> {
    const t = tFor(ctx)
    return {
      qsoCount: summarizeQsoCount(scoresheet, scope === 'day', t),
      dxcc: summarizeDxcc(scoresheet, t),
      bandsAndModes: summarizeBandsAndModes(scoresheet, t),
    }
  },
}

/// Per-day, matching web-lofi: the QSO count restarts each calendar day while
/// the entity and band/mode tallies below carry across the whole operation.
function summarizeQsoCount(sheet: CoreScoresheet, isDay: boolean, t: Translator): ScoreTally {
  const total = isDay ? sheet.dayPoints : sheet.points
  return {
    key: 'qsoCount',
    for: isDay ? 'day' : 'operation',
    icon: 'radio',
    total,
    count: isDay ? sheet.dayQsos : sheet.qsos,
    duplicates: isDay ? sheet.dayDuplicates : sheet.duplicates,
    label: total === 1 ? t('oneQso') : t('manyQsos', { formatted: fmtInteger(total) }),
    summary: fmtInteger(total),
  }
}

function summarizeDxcc(sheet: CoreScoresheet, t: Translator): ScoreTally {
  const count = Object.keys(sheet.entities).length
  return {
    key: 'dxcc',
    for: 'operation',
    icon: 'earth',
    total: count,
    entities: sheet.entities,
    label: count === 1 ? t('oneDxccEntity') : t('manyDxccEntities', { formatted: fmtInteger(count) }),
    // Below five entities the number is noise next to the QSO count.
    summary: count >= 5 ? fmtInteger(count) : '',
  }
}

function summarizeBandsAndModes(sheet: CoreScoresheet, t: Translator): ScoreTally {
  const bandCount = Object.keys(sheet.bands).length
  const modeCount = Object.keys(sheet.modes).length
  const parts: string[] = []
  if (bandCount >= 2) parts.push(t('bands', { n: bandCount }))
  if (modeCount >= 2) parts.push(t('modes', { n: modeCount }))
  return {
    key: 'bandsAndModes',
    for: 'operation',
    icon: 'antenna',
    // Contacts that brought something new, not `bandCount + modeCount` — a QSO
    // new on both axes credits once.
    total: sheet.bandModeQsos,
    bands: sheet.bands,
    modes: sheet.modes,
    label: parts.join(', '),
  }
}

/// The registrable hook. `scope: 'always'` — core scoring applies to every
/// operation, contest or not, and keeps running alongside any contest scorer.
export const coreScoringHook = contestScorer(CoreScorer, { scope: 'always' })

/// Named exports so tests (and any caller) can drive either path directly.
export const scoreQsos = coreScoringHook.scoreQsos
export const scoreQso = coreScoringHook.scoreQso!
