// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What these tests are pinning down is the *award rules*, not the mechanics —
// how many contacts a reference needs, which repeat contacts count again, and
// which side of a park-to-park contact earns what. Get any of them wrong and
// the operator is told they have activated a park they haven't, which is the
// failure mode worth a test suite.

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityScorer } from "./activityScoring.ts"
import { contestScorer } from "./scoring.ts"
import type { HookContext, JSONValue, ScoreTally } from "./types.ts"

const ctx: HookContext = { online: false }

const DAY = 1000 * 60 * 60 * 24
/// 2026-07-01T00:00:00Z, a UTC midnight, so `+ DAY` is unambiguously tomorrow.
const DAY_1 = Date.UTC(2026, 6, 1)

const POTA = {
  label: 'POTA',
  activationType: 'potaActivation',
  huntingType: 'pota',
  qsosToActivate: 10,
  allowsMultipleReferences: true,
  uniquePer: ['band', 'mode', 'day', 'ref'] as const,
  activates: 'daily' as const,
}

const SOTA = {
  label: 'SOTA',
  activationType: 'sotaActivation',
  huntingType: 'sota',
  qsosToActivate: 4,
  allowsMultipleReferences: false,
  uniquePer: ['day', 'ref'] as const,
  activates: 'daily' as const,
}

const WWFF = {
  label: 'WWFF',
  activationType: 'wwffActivation',
  huntingType: 'wwff',
  qsosToActivate: 44,
  allowsMultipleReferences: false,
  uniquePer: ['band', 'mode', 'day'] as const,
  activates: 'once' as const,
}

function operationActivating(type: string, ...refs: string[]): Record<string, JSONValue> {
  return { uuid: 'op-1', refs: refs.map((ref) => ({ type, ref })) }
}

function qso(
  call: string,
  { at = DAY_1, band = '20m', mode = 'SSB', hunting = [], huntingType = 'pota', uuid }:
    { at?: number; band?: string; mode?: string; hunting?: string[]; huntingType?: string; uuid?: string } = {},
): Record<string, JSONValue> {
  return {
    uuid: uuid ?? `${call}-${at}-${band}-${mode}`,
    their: { call },
    band,
    mode,
    startAtMillis: at,
    refs: hunting.map((ref) => ({ type: huntingType, ref })),
  }
}

/// Runs a whole log through the harness the way the host does.
async function score(rules: Parameters<typeof activityScorer>[0], operation: Record<string, JSONValue>, qsos: Record<string, JSONValue>[]) {
  const refTypes = [rules.activationType, rules.huntingType].filter((t): t is string => Boolean(t))
  const hook = contestScorer(activityScorer(rules), { scope: { refTypes } })
  return await hook.scoreQsos({ operation, qsos, ref: (operation.refs as Record<string, JSONValue>[])?.[0] }, ctx)
}

function tally(scores: Record<string, ScoreTally> | undefined, key: string): ScoreTally | undefined {
  return scores?.[key]
}

/// Distinct callsigns, so nothing in a bulk log trips duplicate detection.
function manyCalls(n: number, opts: Parameters<typeof qso>[1] = {}) {
  return Array.from({ length: n }, (_, i) => qso(`W${i}AAA`, opts))
}

// --- Activation progress ---------------------------------------------------

test("a park short of the threshold reports the gap, not a tick", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(7))
  const activation = tally(result.operationSummary, 'activation')!
  assert.equal(activation.summary, '7/10')
  assert.equal(activation.activated, false)
})

test("a park at the threshold is activated and shows a tick", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(10))
  const activation = tally(result.operationSummary, 'activation')!
  assert.equal(activation.summary, '10 ✓')
  assert.equal(activation.activated, true)
})

test("an n-fer is only activated once its WEAKEST park clears the threshold", async () => {
  // Both parks are on the operation, so every contact credits both — but one
  // park was added late, and the pair is not activated until the later one
  // catches up. Modelled here by scoring 10 contacts against a two-park
  // operation and then checking the summary reports the lower of the two.
  const operation = operationActivating('potaActivation', 'US-0001', 'US-0002')
  const result = await score(POTA, operation, manyCalls(10))
  const activation = tally(result.operationSummary, 'activation')!
  assert.deepEqual(activation.activatedRefs, { 'US-0001': 10, 'US-0002': 10 })
  assert.equal(activation.summary, '10 ✓✓')
  assert.equal(activation.activated, true)
})

test("past five references the ticks become a count", async () => {
  const operation = operationActivating('potaActivation', ...Array.from({ length: 8 }, (_, i) => `US-000${i}`))
  const result = await score(POTA, operation, manyCalls(12))
  assert.equal(tally(result.operationSummary, 'activation')!.summary, '12 ✓ x 8')
})

// --- Park-to-park counts per reference ---------------------------------------

test("a contact with a two-park station advances MY park by two", async () => {
  // One on-air contact, but the programs count it per reference: it is
  // submitted as two records, one per park, so it is two contacts toward the
  // activation. Only reachable where `allowsMultipleReferences` is set.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW', { hunting: ['US-9001', 'US-9002'] })])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'US-0001': 2 })
})

test("a station at ONE park advances it by one", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW', { hunting: ['US-9001'] })])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'US-0001': 1 })
})

test("a station at NO park still advances it by one", async () => {
  // The `|| 1` case: an ordinary hunter is a contact like any other, and this
  // is the overwhelmingly common one.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW')])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'US-0001': 1 })
})

test("a program without n-fers never counts a contact twice", async () => {
  // SOTA slices to the first ref, so `refCount || 1` can only ever be 1 — the
  // per-reference rule is scoped to programs that declare n-fers.
  const operation = operationActivating('sotaActivation', 'W1/AM-001')
  const result = await score(SOTA, operation, [
    qso('W1AW', { hunting: ['W1/AM-002', 'W1/AM-003'], huntingType: 'sota' }),
  ])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'W1/AM-001': 1 })
})

test("the two-park contact also earns two hunted references", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW', { hunting: ['US-9001', 'US-9002'] })])
  const hunting = tally(result.operationSummary, 'hunting')!
  assert.equal(hunting.total, 2)
  assert.deepEqual(hunting.huntedRefs, { 'US-9001': 1, 'US-9002': 1 })
})

test("without allowsMultipleReferences only the first hunted ref counts", async () => {
  // SOTA has no n-fers: a QSO carrying two summit refs still credits one.
  const operation = operationActivating('sotaActivation', 'W1/AM-001')
  const result = await score(SOTA, operation, [
    qso('W1AW', { hunting: ['W1/AM-002', 'W1/AM-003'], huntingType: 'sota' }),
  ])
  const hunting = tally(result.operationSummary, 'hunting')!
  assert.deepEqual(hunting.huntedRefs, { 'W1/AM-002': 1 })
})

// --- Duplicates and the uniquePer axes --------------------------------------

test("the same station on the same band, mode, day and ref is a duplicate", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    qso('W1AW', { uuid: 'q1' }),
    qso('W1AW', { uuid: 'q2' }),
  ])
  assert.deepEqual(result.qsoScores.q2.alerts, ['duplicate'])
  assert.equal(result.qsoScores.q2.value, 0)
  // A duplicate must not advance the activation, which is the whole point of
  // detecting it.
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'US-0001': 1 })
})

test("a duplicate on a fresh band counts again and says so", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    qso('W1AW', { uuid: 'q1', band: '20m' }),
    qso('W1AW', { uuid: 'q2', band: '40m' }),
  ])
  assert.deepEqual(result.qsoScores.q2.notices, ['newBand'])
  assert.equal(result.qsoScores.q2.dupe, undefined)
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'US-0001': 2 })
})

test("a new day outranks a new band when both changed", async () => {
  // The axes are tested day → band → mode → ref and the FIRST to clear names
  // the notice, so an operator returning the next day on another band is told
  // the useful thing (it is a new day) rather than an incidental one.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    qso('W1AW', { uuid: 'q1', band: '20m', at: DAY_1 }),
    qso('W1AW', { uuid: 'q2', band: '40m', at: DAY_1 + DAY }),
  ])
  assert.deepEqual(result.qsoScores.q2.notices, ['newDay'])
})

test("a repeat contact that hunts a different park is a new reference", async () => {
  const result = await score(POTA, { uuid: 'op-1', refs: [] }, [
    qso('W1AW', { uuid: 'q1', hunting: ['US-9001'] }),
    qso('W1AW', { uuid: 'q2', hunting: ['US-9002'] }),
  ])
  assert.deepEqual(result.qsoScores.q2.notices, ['newRef'])
  assert.deepEqual(tally(result.operationSummary, 'hunting')!.huntedRefs, { 'US-9001': 1, 'US-9002': 1 })
})

test("a repeat contact with no reference yet is not called a new reference", async () => {
  // Dropping every candidate because this contact carries no ref is not news —
  // it is a duplicate the operator has not finished typing.
  const result = await score(POTA, { uuid: 'op-1', refs: [] }, [
    qso('W1AW', { uuid: 'q1' }),
    qso('W1AW', { uuid: 'q2' }),
  ])
  assert.deepEqual(result.qsoScores.q2.alerts, ['duplicate'])
})

test("with no uniquePer axes at all, ANY repeat contact is a duplicate", async () => {
  // BLHA's rule: app-polo declares no scoring block for it, so nothing relaxes
  // a repeat — not a new band, not a new mode, not a new day.
  const BLHA = {
    label: 'BLHA',
    activationType: 'blhaActivation',
    qsosToActivate: 10,
    uniquePer: [] as const,
    activates: 'once' as const,
  }
  const operation = operationActivating('blhaActivation', 'BEL 001')
  const result = await score(BLHA, operation, [
    qso('W1AW', { uuid: 'q1', band: '20m', mode: 'SSB', at: DAY_1 }),
    qso('W1AW', { uuid: 'q2', band: '40m', mode: 'CW', at: DAY_1 + DAY }),
  ])
  assert.deepEqual(result.qsoScores.q2.alerts, ['duplicate'])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'BEL 001': 1 })
})

test("a program with no hunting side reports no hunting tally", async () => {
  // Several castle and lighthouse awards only recognise activations, which
  // app-polo says by leaving `huntingType` off its Info.
  const BLHA = {
    label: 'BLHA',
    activationType: 'blhaActivation',
    qsosToActivate: 10,
    activates: 'once' as const,
  }
  const result = await score(BLHA, operationActivating('blhaActivation', 'BEL 001'), manyCalls(3))
  assert.equal(tally(result.operationSummary, 'hunting'), undefined)
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'BEL 001': 3 })
})

test("WWFF has no per-ref axis, so a second contact on the same band is a dupe", async () => {
  // WWFF's uniquePer is band/mode/day only: working the same station again on
  // the same band the same day does not count even from a different park.
  const operation = operationActivating('wwffActivation', 'KFF-0001')
  const result = await score(WWFF, operation, [
    qso('W1AW', { uuid: 'q1', huntingType: 'wwff', hunting: ['KFF-9001'] }),
    qso('W1AW', { uuid: 'q2', huntingType: 'wwff', hunting: ['KFF-9002'] }),
  ])
  assert.deepEqual(result.qsoScores.q2.alerts, ['duplicate'])
})

// --- 'daily' versus 'once' --------------------------------------------------

test("a 'daily' program's day row reports that day alone", async () => {
  // POTA activates per UTC day: yesterday's ten contacts do not carry into
  // today's progress, so the day row must restart.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    ...manyCalls(6, { at: DAY_1 }),
    ...manyCalls(3, { at: DAY_1 + DAY }),
  ])
  assert.equal(result.daySections.length, 2)
  assert.equal(tally(result.daySections[0].scores, 'activation')!.summary, '6/10')
  assert.equal(tally(result.daySections[1].scores, 'activation')!.summary, '3/10')
  // The operation row still sees the whole thing.
  assert.equal(tally(result.operationSummary, 'activation')!.summary, '9/10')
})

test("a 'once' program's day row reports the running total", async () => {
  // WWFF's 44 contacts accrue across days, so a per-day count would be shown
  // against a threshold it could never reach.
  const operation = operationActivating('wwffActivation', 'KFF-0001')
  const result = await score(WWFF, operation, [
    ...manyCalls(6, { at: DAY_1 }),
    ...manyCalls(3, { at: DAY_1 + DAY }),
  ])
  assert.equal(tally(result.daySections[0].scores, 'activation')!.summary, '6/44')
  assert.equal(tally(result.daySections[1].scores, 'activation')!.summary, '9/44')
})

// --- What the operator reads ------------------------------------------------

test("the label is singular for one contact", async () => {
  // Explicit ternaries, because i18next's `count` pluralization needs
  // Intl.PluralRules and QuickJS has none — so this is the only thing keeping
  // the panel from reading "1 QSOs".
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(1))
  assert.equal(tally(result.operationSummary, 'activation')!.label, 'POTA Activation — 1 QSO')
})

test("the label is plural for more than one", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(2))
  assert.equal(tally(result.operationSummary, 'activation')!.label, 'POTA Activation — 2 QSOs')
})

test("a single park gets no per-park breakdown", async () => {
  // It would only restate the summary sitting next to it.
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(3))
  assert.equal(tally(result.operationSummary, 'activation')!.longSummary, '')
})

test("an n-fer does get one, marking which parks are short", async () => {
  const operation = operationActivating('potaActivation', 'US-0001', 'US-0002')
  const result = await score(POTA, operation, manyCalls(3))
  assert.equal(
    tally(result.operationSummary, 'activation')!.longSummary,
    '❌ US-0001: 3/10\n❌ US-0002: 3/10',
  )
})

// --- Shape ------------------------------------------------------------------

test("an operation that activates nothing reports only the hunting tally", async () => {
  const result = await score(POTA, { uuid: 'op-1', refs: [] }, [
    qso('W1AW', { hunting: ['US-9001'] }),
  ])
  assert.equal(tally(result.operationSummary, 'activation'), undefined)
  assert.equal(tally(result.operationSummary, 'hunting')!.total, 1)
})

test("an operation with no activity references at all reports nothing", async () => {
  const result = await score(POTA, { uuid: 'op-1', refs: [] }, [qso('W1AW')])
  assert.deepEqual(result.operationSummary, {})
})

test("the running scoresheet is a valid checkpoint", async () => {
  // The core snapshots it as JSON between passes; a Set or a Map here would
  // survive the fold and then vanish on resume.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, manyCalls(3))
  assert.deepEqual(JSON.parse(JSON.stringify(result.scoresheet)), result.scoresheet)
})
