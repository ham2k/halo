// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scoring. Ported from web-lofi's day-sectioning/handler-accumulation model
// (`analyzeAndSectionQSOs` + `ReferenceHandlerHook`), but collapsed into a
// single coarse batched hook call (DESIGN.md §4: "score 500 QSOs in one
// call, not 500 calls") — the day-sectioning loop that used to live in the
// React app now runs entirely inside the runtime. `Qsos.watchForOperation`
// on the Dart side already filters deleted rows and orders by
// `startAtMillis`, so unlike web-lofi there's no `deleted`/`event` row
// bookkeeping to do here.
//
// v1 covers three rules: duplicate-contact detection, DXCC entities worked,
// and bands/modes worked. US States and Canadian Provinces rules (web-lofi's
// `USStatesScoringHandler`/`CanadianProvincesScoringHandler`) are deferred —
// see DESIGN.md §11.

import { defineExtension, entityPrefixForCall } from "@ham2k/halo-extension-sdk"
import type {
  DayScoreSummary,
  HookContext,
  JSONValue,
  QsoScoreEntry,
  QsoScoreVerdict,
  ScoreQsosRequest,
  ScoreQsosResult,
  ScoreTally,
} from "@ham2k/halo-extension-sdk"

const DAY_IN_MILLIS = 1000 * 60 * 60 * 24

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

function summarizeQsoCountTally(tally: ScoreTally): ScoreTally {
  return {
    ...tally,
    icon: 'radio',
    label: tally.total === 1 ? '1 QSO' : `${tally.total} QSOs`,
    summary: `${tally.total}`,
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

function summarizeDxccTally(tally: ScoreTally): ScoreTally {
  const entities = (tally.entities as Record<string, number> | undefined) ?? {}
  const count = Object.keys(entities).length
  return {
    ...tally,
    icon: 'earth',
    label: count === 1 ? '1 DXCC Entity' : `${count} DXCC Entities`,
    summary: count >= 5 ? `${count}` : '',
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

function summarizeBandsAndModesTally(tally: ScoreTally): ScoreTally {
  const bandCount = Object.keys((tally.bands as Record<string, number> | undefined) ?? {}).length
  const modeCount = Object.keys((tally.modes as Record<string, number> | undefined) ?? {}).length
  const labelParts: string[] = []
  if (bandCount >= 2) labelParts.push(`${bandCount} Bands`)
  if (modeCount >= 2) labelParts.push(`${modeCount} Modes`)
  return {
    ...tally,
    icon: 'antenna',
    label: labelParts.join(', '),
  }
}

// --- Day-sectioning and accumulation ---------------------------------------

async function scoreQsos(args: ScoreQsosRequest, _ctx: HookContext): Promise<ScoreQsosResult> {
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
    if (qsoCountTally) currentDay.scores.qsoCount = summarizeQsoCountTally(qsoCountTally)
    if (dxccTally) currentDay.scores.dxcc = summarizeDxccTally(dxccTally)
    if (bandsAndModesTally) currentDay.scores.bandsAndModes = summarizeBandsAndModesTally(bandsAndModesTally)
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
  if (operationQsoCountTally) operationSummary.qsoCount = summarizeQsoCountTally(operationQsoCountTally)
  if (dxccTally) operationSummary.dxcc = summarizeDxccTally(dxccTally)
  if (bandsAndModesTally) operationSummary.bandsAndModes = summarizeBandsAndModesTally(bandsAndModesTally)

  return { qsoScores, daySections, operationSummary }
}

defineExtension({
  key: 'scoring',
  name: 'Scoring',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('scoring', { hook: { scoreQsos }, key: 'core' })
  },
})
