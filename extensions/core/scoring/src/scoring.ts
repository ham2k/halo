// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scoring logic. Ported from web-lofi's day-sectioning/handler-accumulation
// model (`analyzeAndSectionQSOs` + `ReferenceHandlerHook`), but collapsed into
// a single coarse batched hook call (DESIGN.md §4: "score 500 QSOs in one
// call, not 500 calls") — the day-sectioning loop that used to live in the
// React app now runs entirely inside the runtime. `Qsos.watchForOperation` on
// the Dart side already filters deleted rows and orders by `startAtMillis`, so
// unlike web-lofi there's no `deleted`/`event` row bookkeeping to do here.
//
// v1 covers three rules: duplicate-contact detection, DXCC entities worked,
// and bands/modes worked. US States and Canadian Provinces rules (web-lofi's
// `USStatesScoringHandler`/`CanadianProvincesScoringHandler`) are deferred —
// see DESIGN.md §11.
//
// `entityPrefixForCall` comes in by relative path, not the
// `@ham2k/halo-extension-sdk` alias, so this module's `scoreQso.test.ts` can
// run under plain `node --test` (which can't resolve that tsc/esbuild-only bare
// specifier) — the same constraint annotate.ts documents. `index.ts` keeps the
// alias for `defineExtension` and is the one module the tests don't import.

import { entityPrefixForCall } from "../../../sdk/src/dxcc.ts"
// Relative for the same node-resolvability reason as dxcc.ts above.
import { createCachedTranslator, createTranslator } from "../../../sdk/src/i18n.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"
import type {
  DayScoreSummary,
  HookContext,
  JSONValue,
  QsoScoreEntry,
  QsoScoreNotices,
  QsoScoreVerdict,
  ScoreQsoRequest,
  ScoreQsosRequest,
  ScoreQsosResult,
  ScoreTally,
} from "@ham2k/halo-extension-sdk"

const DAY_IN_MILLIS = 1000 * 60 * 60 * 24

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

type QsoJSON = Record<string, JSONValue>

function str(value: JSONValue | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

// --- Duplicate-contact detection ----------------------------------------

function scoreDupe(qso: QsoJSON, workedByCall: Map<string, Set<string>>): QsoScoreVerdict {
  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const call = str(their.call)
  if (!call) return { value: 0 }

  const band = str(qso.band) ?? ''
  const mode = str(qso.mode) ?? ''
  const bandMode = `${band}|${mode}`

  const priorCombos = workedByCall.get(call)
  let verdict: QsoScoreVerdict

  if (priorCombos?.has(bandMode)) {
    verdict = { value: 0, dupe: true, alerts: ['duplicate'] }
  } else {
    const notices: string[] = []
    if (priorCombos && priorCombos.size > 0) {
      const sameBand = [...priorCombos].some((combo) => combo.startsWith(`${band}|`))
      const sameMode = [...priorCombos].some((combo) => combo.endsWith(`|${mode}`))
      if (!sameMode) notices.push('newMode')
      if (!sameBand) notices.push('newBand')
    }
    verdict = { value: 1, notices }
  }

  if (priorCombos) priorCombos.add(bandMode)
  else workedByCall.set(call, new Set([bandMode]))

  return verdict
}

function accumulateQsoCountTally(tally: ScoreTally | undefined, verdict: QsoScoreVerdict): ScoreTally {
  const count = (Number(tally?.count) || 0) + 1
  const duplicates = (Number(tally?.duplicates) || 0) + (verdict.dupe ? 1 : 0)
  const total = (tally?.total ?? 0) + (verdict.dupe ? 0 : verdict.value)
  return { key: 'qsoCount', for: 'day', total, count, duplicates }
}

function summarizeQsoCountTally(tally: ScoreTally, t: Translator): ScoreTally {
  return {
    ...tally,
    icon: 'radio',
    label: tally.total === 1 ? t('oneQso') : t('manyQsos', { formatted: fmtInteger(tally.total) }),
    summary: fmtInteger(tally.total),
  }
}

// --- DXCC entities worked -------------------------------------------------

function scoreDxcc(qso: QsoJSON, workedEntities: Set<string>): QsoScoreVerdict {
  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const entityPrefix = entityPrefixForCall(str(their.call))
  if (!entityPrefix) return { value: 0 }

  if (workedEntities.has(entityPrefix)) {
    return { value: 0, alerts: ['workedBefore'], entityPrefix }
  }
  workedEntities.add(entityPrefix)
  return { value: 1, entityPrefix }
}

function accumulateDxccTally(tally: ScoreTally | undefined, verdict: QsoScoreVerdict): ScoreTally {
  const entities = { ...((tally?.entities as Record<string, number> | undefined) ?? {}) }
  const prefix = verdict.entityPrefix as string | undefined
  if (prefix) entities[prefix] = (entities[prefix] ?? 0) + 1
  const total = (tally?.total ?? 0) + (verdict.value ?? 0)
  return { key: 'dxcc', for: 'operation', total, entities }
}

function summarizeDxccTally(tally: ScoreTally, t: Translator): ScoreTally {
  const entities = (tally.entities as Record<string, number> | undefined) ?? {}
  const count = Object.keys(entities).length
  return {
    ...tally,
    icon: 'earth',
    label: count === 1 ? t('oneDxccEntity') : t('manyDxccEntities', { formatted: fmtInteger(count) }),
    summary: count >= 5 ? fmtInteger(count) : '',
  }
}

// --- Bands and modes worked -----------------------------------------------

function scoreBandsAndModes(qso: QsoJSON, workedBands: Set<string>, workedModes: Set<string>): QsoScoreVerdict {
  const band = str(qso.band)
  const mode = str(qso.mode)
  const isNewBand = Boolean(band) && !workedBands.has(band as string)
  const isNewMode = Boolean(mode) && !workedModes.has(mode as string)

  if (band) workedBands.add(band)
  if (mode) workedModes.add(mode)

  return isNewBand || isNewMode ? { value: 1, band, mode } : { value: 0, alerts: ['workedBefore'], band, mode }
}

function accumulateBandsAndModesTally(tally: ScoreTally | undefined, verdict: QsoScoreVerdict): ScoreTally {
  const bands = { ...((tally?.bands as Record<string, number> | undefined) ?? {}) }
  const modes = { ...((tally?.modes as Record<string, number> | undefined) ?? {}) }
  const band = verdict.band as string | undefined
  const mode = verdict.mode as string | undefined
  if (band) bands[band] = (bands[band] ?? 0) + 1
  if (mode) modes[mode] = (modes[mode] ?? 0) + 1
  const total = (tally?.total ?? 0) + (verdict.value ?? 0)
  return { key: 'bandsAndModes', for: 'operation', total, bands, modes }
}

function summarizeBandsAndModesTally(tally: ScoreTally, t: Translator): ScoreTally {
  const bandCount = Object.keys((tally.bands as Record<string, number> | undefined) ?? {}).length
  const modeCount = Object.keys((tally.modes as Record<string, number> | undefined) ?? {}).length
  const labelParts: string[] = []
  if (bandCount >= 2) labelParts.push(t('bands', { n: bandCount }))
  if (modeCount >= 2) labelParts.push(t('modes', { n: modeCount }))
  return {
    ...tally,
    icon: 'antenna',
    label: labelParts.join(', '),
  }
}

// --- Day-sectioning and accumulation ---------------------------------------

export async function scoreQsos(args: ScoreQsosRequest, ctx: HookContext): Promise<ScoreQsosResult> {
  const t = tFor(ctx)
  const sorted = [...args.qsos].sort((a, b) => Number(a.startAtMillis ?? 0) - Number(b.startAtMillis ?? 0))

  const workedByCall = new Map<string, Set<string>>()
  const workedEntities = new Set<string>()
  const workedBands = new Set<string>()
  const workedModes = new Set<string>()

  const qsoScores: Record<string, QsoScoreEntry> = {}
  const daySections: DayScoreSummary[] = []

  let currentDay: DayScoreSummary | undefined
  let qsoCountTally: ScoreTally | undefined // resets every day
  let operationQsoCountTally: ScoreTally | undefined // carries over, like dxcc/bandsAndModes below
  let dxccTally: ScoreTally | undefined
  let bandsAndModesTally: ScoreTally | undefined

  const snapshotCurrentDay = () => {
    if (!currentDay) return
    if (qsoCountTally) currentDay.scores.qsoCount = summarizeQsoCountTally(qsoCountTally, t)
    if (dxccTally) currentDay.scores.dxcc = summarizeDxccTally(dxccTally, t)
    if (bandsAndModesTally) currentDay.scores.bandsAndModes = summarizeBandsAndModesTally(bandsAndModesTally, t)
  }

  for (const qso of sorted) {
    const startAtMillis = Number(qso.startAtMillis ?? 0)
    const day = startAtMillis - (startAtMillis % DAY_IN_MILLIS)

    if (!currentDay || currentDay.day !== day) {
      snapshotCurrentDay()
      currentDay = { day, count: 0, scores: {} }
      daySections.push(currentDay)
      qsoCountTally = undefined // resets every day; dxcc/bandsAndModes carry over
    }
    currentDay.count += 1

    const dupeVerdict = scoreDupe(qso, workedByCall)
    const dxccVerdict = scoreDxcc(qso, workedEntities)
    const bandsAndModesVerdict = scoreBandsAndModes(qso, workedBands, workedModes)

    qsoCountTally = accumulateQsoCountTally(qsoCountTally, dupeVerdict)
    operationQsoCountTally = accumulateQsoCountTally(operationQsoCountTally, dupeVerdict)
    dxccTally = accumulateDxccTally(dxccTally, dxccVerdict)
    bandsAndModesTally = accumulateBandsAndModesTally(bandsAndModesTally, bandsAndModesVerdict)

    const uuid = str(qso.uuid)
    if (uuid) {
      qsoScores[uuid] = { dupe: dupeVerdict, dxcc: dxccVerdict, bandsAndModes: bandsAndModesVerdict }
    }
  }
  snapshotCurrentDay()

  const operationSummary: Record<string, ScoreTally> = {}
  if (operationQsoCountTally) operationSummary.qsoCount = summarizeQsoCountTally(operationQsoCountTally, t)
  if (dxccTally) operationSummary.dxcc = summarizeDxccTally(dxccTally, t)
  if (bandsAndModesTally) operationSummary.bandsAndModes = summarizeBandsAndModesTally(bandsAndModesTally, t)

  return { qsoScores, daySections, operationSummary }
}

// --- Live single-QSO scoring (call-info line) ------------------------------
//
// Scores the callsign currently being typed — before it's logged — so the
// logging panel can show "Dupe!", "New Band", "New DXCC" etc. live. Rebuilds
// the worked-state from the operation's log (via `ctx.getQsos`) and scores the
// candidate against it, reusing the same per-QSO verdict functions as the
// batch. Called debounced from the Dart side, so the whole-log read is fine
// (it's not on the per-keystroke path). Returns only display notices/alerts;
// nothing is recorded.

export async function scoreQso(args: ScoreQsoRequest, ctx: HookContext): Promise<QsoScoreNotices> {
  const notices = new Set<string>()
  const alerts = new Set<string>()

  const candidate = (args.qso ?? {}) as QsoJSON
  const their = (candidate.their as Record<string, JSONValue>) ?? {}
  const call = str(their.call)
  if (!call) return { notices: [], alerts: [] }

  const operationUuid = str((args.operation ?? {}).uuid)
  const log = operationUuid ? (await ctx.getQsos?.(operationUuid)) ?? [] : []
  const excludeUuid = str(args.excludeUuid)

  // Rebuild the worked-state from the rest of the log — same accumulation the
  // batch does, minus event markers and the record being edited.
  const workedByCall = new Map<string, Set<string>>()
  const workedEntities = new Set<string>()
  const workedBands = new Set<string>()
  const workedModes = new Set<string>()
  for (const qso of log) {
    const row = qso as QsoJSON
    if (str(row.band) === 'event') continue
    if (excludeUuid && str(row.uuid) === excludeUuid) continue
    scoreDupe(row, workedByCall)
    scoreDxcc(row, workedEntities)
    scoreBandsAndModes(row, workedBands, workedModes)
  }

  // Operation-level new band/mode must be read BEFORE scoreBandsAndModes below
  // records the candidate's own band/mode into the worked sets.
  const candidateBand = str(candidate.band)
  const candidateMode = str(candidate.mode)
  const opNewBand = Boolean(candidateBand) && !workedBands.has(candidateBand as string)
  const opNewMode = Boolean(candidateMode) && !workedModes.has(candidateMode as string)

  // The verdict functions read the worked sets, then add the candidate — the
  // post-add mutation is harmless since the sets are discarded after this call.
  const dupeVerdict = scoreDupe(candidate, workedByCall)
  const dxccVerdict = scoreDxcc(candidate, workedEntities)

  if (dupeVerdict.dupe) alerts.add('duplicate')
  for (const notice of dupeVerdict.notices ?? []) notices.add(notice) // call-level newBand/newMode
  if (dxccVerdict.value === 1 && dxccVerdict.entityPrefix) notices.add('newDXCC')
  if (opNewBand) notices.add('newBand')
  if (opNewMode) notices.add('newMode')

  return { notices: [...notices], alerts: [...alerts] }
}
