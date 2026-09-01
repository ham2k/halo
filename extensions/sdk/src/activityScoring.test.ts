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
  // An activating operation folds its P2P credit into the activation tally's
  // own label instead of a separate `hunting` tally — the mechanics still
  // land in the scoresheet, which is what this checks.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW', { hunting: ['US-9001', 'US-9002'] })])
  const sheet = result.scoresheet as { huntedRefs: Record<string, number> }
  assert.deepEqual(sheet.huntedRefs, { 'US-9001': 1, 'US-9002': 1 })
  assert.equal(tally(result.operationSummary, 'hunting'), undefined)
})

test("an activating operation's P2P credit folds into the activation label, not a separate tally", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [qso('W1AW', { hunting: ['US-9001', 'US-9002'] })])
  const activation = tally(result.operationSummary, 'activation')!
  assert.equal(activation.label, 'POTA: 2 activation QSOs, 2 ref2ref QSOs')
})

test("without allowsMultipleReferences only the first hunted ref counts", async () => {
  // SOTA has no n-fers: a QSO carrying two summit refs still credits one.
  const operation = operationActivating('sotaActivation', 'W1/AM-001')
  const result = await score(SOTA, operation, [
    qso('W1AW', { hunting: ['W1/AM-002', 'W1/AM-003'], huntingType: 'sota' }),
  ])
  const sheet = result.scoresheet as { huntedRefs: Record<string, number> }
  assert.deepEqual(sheet.huntedRefs, { 'W1/AM-002': 1 })
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

test("a repeat contact spotted at a coarser mode is still a duplicate", async () => {
  // The mode axis is what the spots board leans on hardest: a park spotted as
  // `SSB` after the activator was worked on `USB` would otherwise read as a
  // fresh mode — unstruck on the board, and credited again in the log.
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    qso('W1AW', { uuid: 'q1', mode: 'USB' }),
    qso('W1AW', { uuid: 'q2', mode: 'SSB' }),
  ])
  assert.deepEqual(result.qsoScores.q2.alerts, ['duplicate'])
})

test("a repeat contact on a genuinely different mode still counts again", async () => {
  const operation = operationActivating('potaActivation', 'US-0001')
  const result = await score(POTA, operation, [
    qso('W1AW', { uuid: 'q1', mode: 'FT8' }),
    qso('W1AW', { uuid: 'q2', mode: 'RTTY' }),
  ])
  assert.deepEqual(result.qsoScores.q2.notices, ['newMode'])
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

// --- Rules the hunt-and-activate awards need (A2) ----------------------------

/// WWBOTA: 10 contacts in Slovenia and North Macedonia, 25 everywhere else.
const WWBOTA = {
  label: 'WWBOTA',
  activationType: 'wwbotaActivation',
  huntingType: 'wwbota',
  qsosToActivate: (refs: string[]) =>
    Math.max(...refs.map((r) => (['S5', 'Z3'].includes(r.split(/[/-]/)[1]) ? 10 : 25))),
  uniquePer: ['band', 'day', 'ref'] as const,
  activates: 'once' as const,
}

test("the threshold can depend on which reference is being activated", async () => {
  const slovenian = await score(WWBOTA, operationActivating('wwbotaActivation', 'B/S5-0001'), manyCalls(3))
  assert.equal(tally(slovenian.operationSummary, 'activation')!.summary, '3/10')

  const british = await score(WWBOTA, operationActivating('wwbotaActivation', 'B/G-0001'), manyCalls(3))
  assert.equal(tally(british.operationSummary, 'activation')!.summary, '3/25')
})

test("activating two bunkers at once takes the HARDER threshold", async () => {
  // Clearing the easy one must not declare the hard one done.
  const operation = operationActivating('wwbotaActivation', 'B/S5-0001', 'B/G-0001')
  const result = await score(WWBOTA, operation, manyCalls(12))
  const activation = tally(result.operationSummary, 'activation')!
  assert.equal(activation.summary, '12/25')
  assert.equal(activation.activated, false)
})

test("a fresh reference on a repeat contact earns ref-to-ref but not the activation", async () => {
  // MOTA and SiOTA: "Doesn't count towards activation, but towards Silo 2 Silo
  // award." The operator already worked this station on this band today.
  const MOTA = {
    label: 'MOTA',
    activationType: 'motaActivation',
    huntingType: 'mota',
    qsosToActivate: 10,
    uniquePer: ['band', 'day', 'ref'] as const,
    activates: 'once' as const,
    freshRefRescuesActivation: false,
  }
  const operation = operationActivating('motaActivation', 'X00001')
  const result = await score(MOTA, operation, [
    qso('W1AW', { uuid: 'q1', huntingType: 'mota', hunting: ['X09001'] }),
    qso('W1AW', { uuid: 'q2', huntingType: 'mota', hunting: ['X09002'] }),
  ])

  assert.deepEqual(result.qsoScores.q2.notices, ['newRef'])
  assert.equal(result.qsoScores.q2.dupe, undefined)
  // One contact toward the mill, not two...
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'X00001': 1 })
  // ...but both mills hunted (folded into the activation tally's label, not
  // a separate one).
  const sheet = result.scoresheet as { huntedRefs: Record<string, number> }
  assert.deepEqual(sheet.huntedRefs, { 'X09001': 1, 'X09002': 1 })
})

test("WWBOTA is the exception: a fresh bunker does advance the activation", async () => {
  const operation = operationActivating('wwbotaActivation', 'B/G-0001')
  const result = await score(WWBOTA, operation, [
    qso('W1AW', { uuid: 'q1', huntingType: 'wwbota', hunting: ['B/G-9001'] }),
    qso('W1AW', { uuid: 'q2', huntingType: 'wwbota', hunting: ['B/G-9002'] }),
  ])
  assert.deepEqual(result.qsoScores.q2.notices, ['newRef'])
  assert.deepEqual(tally(result.operationSummary, 'activation')!.activatedRefs, { 'B/G-0001': 2 })
})

// --- What the operator reads ------------------------------------------------

test("the label is singular for one contact", async () => {
  // Explicit ternaries, because i18next's `count` pluralization needs
  // Intl.PluralRules and QuickJS has none — so this is the only thing keeping
  // the panel from reading "1 QSOs".
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(1))
  assert.equal(tally(result.operationSummary, 'activation')!.label, 'POTA: 1 activation QSO')
})

test("the label is plural for more than one", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(2))
  assert.equal(tally(result.operationSummary, 'activation')!.label, 'POTA: 2 activation QSOs')
})

test("a hunting-only operation reads as references hunted, by default wording", async () => {
  // No activation ref at all — nothing to fold the P2P line into, so this is
  // its own tally with the generic default noun (a program can override it,
  // see the next test).
  const result = await score(POTA, { uuid: 'op-1', refs: [] }, [
    qso('W1AW', { hunting: ['US-9001'] }),
    qso('K1ABC', { hunting: ['US-9002'] }),
  ])
  assert.equal(tally(result.operationSummary, 'hunting')!.label, 'POTA: 2 references hunted')
})

test("refNoun/refNounPlural/p2pLabel customize the wording", async () => {
  const POTA_WITH_NOUNS = { ...POTA, refNoun: 'park', refNounPlural: 'parks', p2pLabel: 'P2P' }

  const huntingOnly = await score(POTA_WITH_NOUNS, { uuid: 'op-1', refs: [] }, [
    qso('W1AW', { hunting: ['US-9001'] }),
  ])
  assert.equal(tally(huntingOnly.operationSummary, 'hunting')!.label, 'POTA: 1 park hunted')

  const operation = operationActivating('potaActivation', 'US-0001')
  const activating = await score(POTA_WITH_NOUNS, operation, [
    qso('W1AW', { hunting: ['US-9001', 'US-9002'] }),
  ])
  assert.equal(
    tally(activating.operationSummary, 'activation')!.label,
    'POTA: 2 activation QSOs, 2 P2P QSOs',
  )
})

test("a function-valued refNoun/p2pLabel resolves through the activity's OWN ctx, not a fixed string", async () => {
  // This is how a real activity supplies its noun (extensions/activities/pota
  // resolves 'park'/'P2P' through its own translator) — a raw string would be
  // untranslatable, so the resolver must actually call the function with the
  // ctx it was handed, not just accept the plain-string branch tested above.
  const seenCtx: HookContext[] = []
  const POTA_WITH_FN_NOUNS = {
    ...POTA,
    refNoun: (c: HookContext) => { seenCtx.push(c); return c.locale === 'es' ? 'parque' : 'park' },
    refNounPlural: (c: HookContext) => (c.locale === 'es' ? 'parques' : 'parks'),
    p2pLabel: () => 'P2P',
  }

  const esCtx: HookContext = { online: false, locale: 'es' }
  const refTypes = [POTA_WITH_FN_NOUNS.activationType, POTA_WITH_FN_NOUNS.huntingType]
  const hook = contestScorer(activityScorer(POTA_WITH_FN_NOUNS), { scope: { refTypes } })
  const result = await hook.scoreQsos(
    { operation: { uuid: 'op-1', refs: [] }, qsos: [qso('W1AW', { hunting: ['US-9001'] })] },
    esCtx,
  )

  assert.equal(tally(result.operationSummary, 'hunting')!.label, 'POTA: 1 parque cazado')
  assert.equal(seenCtx[0]?.locale, 'es')
})

test("a single park still gets its own progress line", async () => {
  // The operation-info panel's per-day rows show this line instead of a
  // `summary` badge beside the label, so a single-park operation needs one
  // too — not just the n-fer case.
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), manyCalls(3))
  assert.equal(tally(result.operationSummary, 'activation')!.longSummary, '❌ US-0001: 3/10')
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

// --- Saying so, rather than staying silent ---------------------------------
//
// The host runs core scoring (call+band+mode dupes, DXCC, bands) under every
// operation, and lets its worked-before verdict stand for any QSO no other
// scorer has RULED on (docs/design/contests.md §5.1). Silence therefore has to
// mean "no opinion" and nothing else: where this scorer has decided a contact
// counts, it has to say so, or core calls that contact a duplicate over the top
// of the credit just awarded.

test("a contact worked before that this scorer CREDITS says so with dupe: false", async () => {
  // Worked at a park this morning; he has packed up, and this contact carries
  // no reference. The ref axis keeps no candidate, and there is no `newRef` to
  // report either — the one path where this scorer credits a QSO while having
  // no notice to describe it with. Silent, the host reads that as no opinion
  // and lets core call the contact a duplicate.
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), [
    qso('W1AW', { hunting: ['US-1234'] }),
    qso('W1AW', { at: DAY_1 + 3600_000, uuid: 'bare' }),
  ])
  const verdict = result.qsoScores['bare']
  assert.equal(verdict.dupe, false)
  assert.equal(verdict.notices, undefined)
  assert.ok(verdict.value > 0, 'the contact is credited, which is why core must not strike it')
})

test("a duplicate says so too", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), [
    qso('W1AW'),
    qso('W1AW', { at: DAY_1 + 3600_000, uuid: 'again' }),
  ])
  assert.equal(result.qsoScores['again'].dupe, true)
  assert.deepEqual(result.qsoScores['again'].alerts, ['duplicate'])
})

// A station this scorer has never seen is NOT a station it can clear: it folds
// only the segments it was running for, so an unknown call may well have been
// worked in a stretch it skipped. Core holds the whole log, so silence here
// hands the question to the scorer that can answer it.
// The ordinary chaser: the operation activates nothing, so a bare repeat
// contact earns this scorer zero. A ruling there would strip core's duplicate
// — the only warning that operator gets — off a contact nobody credited.
test("a contact this scorer credits nothing for makes no claim about it", async () => {
  const result = await score(POTA, {'refs': []}, [
    qso('W1AW', { hunting: ['US-1234'] }),
    qso('W1AW', { at: DAY_1 + 3600_000, uuid: 'bare' }),
  ]);
  const verdict = result.qsoScores['bare']
  assert.equal(verdict.value, 0)
  assert.equal(verdict.dupe, undefined, 'silence hands the question to the scorer holding the whole log')
})

// SiOTA and MOTA hold that a repeat contact does not advance an activation
// even when it hands over a silo the station had not given before. A contact
// bringing no reference at all is worth less than that, so this scorer has
// nothing to say about it and core's duplicate rule is left standing.
test("a program where a fresh ref does not rescue activation rules on nothing", async () => {
  const SIOTA = { ...POTA, freshRefRescuesActivation: false }
  const result = await score(SIOTA, operationActivating('potaActivation', 'US-0001'), [
    qso('W1AW', { hunting: ['US-1234'] }),
    qso('W1AW', { at: DAY_1 + 3600_000, uuid: 'bare' }),
  ])
  assert.equal(result.qsoScores['bare'].dupe, undefined)
})

test("a first contact stays silent rather than claiming not-a-duplicate", async () => {
  const result = await score(POTA, operationActivating('potaActivation', 'US-0001'), [
    qso('W1AW', { uuid: 'first' }),
  ])
  assert.equal(result.qsoScores['first'].dupe, undefined)
})

test("the live paths carry the ruling, not just the batch", async () => {
  const hook = contestScorer(activityScorer(POTA), { scope: { refTypes: ['potaActivation', 'pota'] } })
  const operation = operationActivating('potaActivation', 'US-0001')
  const args = {
    operation,
    ref: (operation.refs as Record<string, JSONValue>[])[0],
    resumeFrom: undefined as unknown as JSONValue,
  }
  // Cold cache with no log reachable: nothing worked, so nothing to rule on.
  const fresh = await hook.scoreQso!({ ...args, qso: qso('W1AW') }, ctx)
  assert.equal(fresh.dupe, undefined)

  // Resuming from a sheet that already holds the station, contacted at a park.
  const priorSheet = (await score(POTA, operation, [qso('W1AW', { hunting: ['US-1234'] })])).scoresheet
  const known = await hook.scoreQso!({ ...args, resumeFrom: priorSheet, qso: qso('W1AW', { uuid: 'bare' }) }, ctx)
  assert.equal(known.dupe, false, 'a live verdict says the dupe test ran, as the batch one does')
})
