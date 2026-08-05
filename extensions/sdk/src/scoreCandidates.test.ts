// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `scoreCandidates` is what the Spots Panel asks to find out which spots are
// already worked. What these tests pin down is that batching the question does
// not change the answer: a scorer is allowed to mutate the scoresheet it is
// handed (the contract that keeps the batch fold linear), so scoring N
// candidates in a row against one sheet is a trap — the first candidate would
// enter the log and every candidate after it would be judged against a
// contact that was never made.

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityScorer } from "./activityScoring.ts"
import { contestScorer } from "./scoring.ts"
import type { HookContext, JSONValue } from "./types.ts"

const DAY = 1000 * 60 * 60 * 24
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

const potaRef: Record<string, JSONValue> = { type: 'pota', ref: 'US-0001' }
const operation: Record<string, JSONValue> = { uuid: 'op-1', refs: [potaRef] }

function qso(
  call: string,
  { at = DAY_1, band = '20m', mode = 'SSB', ref = 'US-0001' }:
    { at?: number; band?: string; mode?: string; ref?: string } = {},
): Record<string, JSONValue> {
  return {
    uuid: `${call}-${at}-${band}-${mode}`,
    their: { call },
    band,
    mode,
    startAtMillis: at,
    refs: [{ type: 'pota', ref }],
  }
}

/// A candidate is a spot: the same shape as a QSO, minus the uuid, timestamped
/// now because that is when it would be worked.
function candidate(key: string, call: string, opts: Parameters<typeof qso>[1] = {}) {
  const { uuid: _uuid, ...rest } = qso(call, { at: DAY_1 + 3600_000, ...opts })
  return { key, qso: rest as Record<string, JSONValue> }
}

/// The host's view: a log it can read back, and the hook it invokes.
function hookOver(log: Record<string, JSONValue>[]) {
  const ctx: HookContext = { online: false, getQsos: async () => log }
  const hook = contestScorer(activityScorer(POTA), { scope: { refTypes: ['potaActivation', 'pota'] } })
  return { hook, ctx }
}

test("a candidate already in the log comes back as a duplicate", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA')])
  const result = await hook.scoreCandidates!(
    { operation, candidates: [candidate('a', 'W1AAA')], ref: potaRef },
    ctx,
  )
  assert.deepEqual(result.a.alerts, ['duplicate'])
})

test("an unworked candidate reports nothing", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA')])
  const result = await hook.scoreCandidates!(
    { operation, candidates: [candidate('b', 'W2BBB')], ref: potaRef },
    ctx,
  )
  assert.deepEqual(result.b.alerts, [])
  assert.deepEqual(result.b.notices, [])
})

// The mutation trap. Both spots are the same unworked station on the same
// band — two sources spotting one operator, which is the ordinary case on a
// busy park. Score them against a shared scoresheet and the first one enters
// it, so the second reads as a contact the operator never made and its row is
// struck through. Anyone "optimizing away" the per-candidate copy fails here.
test("one candidate never makes another a duplicate", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA')])
  const result = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('first', 'W2BBB'), candidate('second', 'W2BBB')],
      ref: potaRef,
    },
    ctx,
  )
  assert.deepEqual(result.first.alerts, [])
  assert.deepEqual(result.second.alerts, [], 'the first candidate leaked into the second\'s scoresheet')
})

// Same trap from the other side: a real duplicate must stay a duplicate no
// matter where it sits in the batch, so the copy has to be per candidate
// rather than taken once before the loop.
test("candidate order does not change any verdict", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA')])
  const forwards = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('dupe', 'W1AAA'), candidate('new', 'W2BBB')],
      ref: potaRef,
    },
    ctx,
  )
  const backwards = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('new', 'W2BBB'), candidate('dupe', 'W1AAA')],
      ref: potaRef,
    },
    ctx,
  )
  assert.deepEqual(forwards, backwards)
  assert.deepEqual(forwards.dupe.alerts, ['duplicate'])
  assert.deepEqual(forwards.new.alerts, [])
})

// The uuid is how the cold path reaches the log, and there is nothing sane to
// do without one — so a candidate is judged against nothing and comes back
// clean. Silent by design, and the reason the Dart side folds the uuid in
// rather than trusting an operation map to carry it: an operation's `data`
// does not, and the symptom is not an error but a spot list where no station
// is ever a duplicate.
test("an operation with no uuid scores against an empty log", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA')])
  const anonymous: Record<string, JSONValue> = { refs: [potaRef] }
  const result = await hook.scoreCandidates!(
    { operation: anonymous, candidates: [candidate('a', 'W1AAA')], ref: potaRef },
    ctx,
  )
  assert.deepEqual(result.a.alerts, [], 'a log it cannot read is a log with nothing in it')
})

// POTA counts a station again on a new band, so a spot for a station worked
// only on 20m is a contact worth making — accented, not struck.
test("a station worked on another band reports newBand, not duplicate", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA', { band: '20m' })])
  const result = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('c', 'W1AAA', { band: '40m' })],
      ref: potaRef,
    },
    ctx,
  )
  assert.deepEqual(result.c.alerts, [])
  assert.deepEqual(result.c.notices, ['newBand'])
})

// The reason `spotCandidateQso` stamps `startAtMillis` with the current time:
// POTA's day axis buckets by `floor(startAtMillis / DAY)`, so a candidate
// timestamped yesterday is a fresh contact rather than a duplicate. The panel
// must not hand over a candidate with no timestamp, which would land on the
// epoch and make every worked station read as newDay.
test("the candidate's own timestamp decides the day axis", async () => {
  const { hook, ctx } = hookOver([qso('W1AAA', { at: DAY_1 })])
  const result = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('today', 'W1AAA', { at: DAY_1 }), candidate('tomorrow', 'W1AAA', { at: DAY_1 + DAY })],
      ref: potaRef,
    },
    ctx,
  )
  assert.deepEqual(result.today.alerts, ['duplicate'])
  assert.deepEqual(result.tomorrow.notices, ['newDay'])
})

// The cached end-of-log scoresheet is the caller's, held across refreshes.
// Scoring a batch against it must leave it untouched, or the next refresh
// judges every spot against a log that includes the spots themselves.
test("a resumeFrom checkpoint survives the batch unchanged", async () => {
  const { hook, ctx } = hookOver([])
  const pass = await hook.scoreQsos(
    { operation, qsos: [qso('W1AAA')], ref: potaRef },
    ctx,
  )
  const checkpoint = pass.scoresheet!
  const before = JSON.stringify(checkpoint)

  const result = await hook.scoreCandidates!(
    {
      operation,
      candidates: [candidate('x', 'W2BBB'), candidate('y', 'W3CCC')],
      ref: potaRef,
      resumeFrom: checkpoint,
    },
    ctx,
  )
  assert.deepEqual(result.x.alerts, [])
  assert.equal(JSON.stringify(checkpoint), before, 'the cached scoresheet was mutated')
})

// The operator worked a station at one park, then edited the QSO to name a
// DIFFERENT park. POTA counts that station again at a new reference, so its
// spot is a contact worth making — the activity scorer must say `newRef`, not
// `duplicate`. (The core scorer, which knows nothing about references, still
// calls it a duplicate on call+band+mode; reconciling the two is the host's
// job, not this scorer's.)
test("a station worked at another reference reports newRef, not duplicate", async () => {
  const { hook, ctx } = hookOver([qso('WC1N', { ref: 'US-9999' })])
  const result = await hook.scoreCandidates!(
    { operation, candidates: [candidate('wc1n', 'WC1N', { ref: 'US-0001' })], ref: potaRef },
    ctx,
  )
  assert.deepEqual(result.wc1n.alerts, [], 'a different park is not a duplicate')
  assert.deepEqual(result.wc1n.notices, ['newRef'])
})
