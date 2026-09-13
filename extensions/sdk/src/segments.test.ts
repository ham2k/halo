// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import { test } from "node:test"
import assert from "node:assert/strict"

import { operationForQso } from "./segments.ts"

const base = { uuid: 'op', refs: [{ type: 'qp', location: 'MORR' }] }
const segments = [
  { fromMillis: -1, operation: base },
  { fromMillis: 1_000, operation: { ...base, refs: [{ type: 'qp', location: 'WRRN' }] } },
  { fromMillis: 2_000, operation: { ...base, refs: [{ type: 'qp', location: 'SUSS' }] } },
]
const county = (op: Record<string, unknown>) => (op.refs as { location: string }[])[0].location

test('a contact takes the last segment that had begun when it was made', () => {
  assert.equal(county(operationForQso(base, { startAtMillis: 500 }, segments)), 'MORR')
  assert.equal(county(operationForQso(base, { startAtMillis: 1_500 }, segments)), 'WRRN')
  assert.equal(county(operationForQso(base, { startAtMillis: 9_000 }, segments)), 'SUSS')
})

test('a contact on the boundary belongs to the segment that starts there, as on the host', () => {
  assert.equal(county(operationForQso(base, { startAtMillis: 2_000 }, segments)), 'SUSS')
})

test('no segments, or no time, means the base operation', () => {
  assert.equal(operationForQso(base, { startAtMillis: 1_500 }), base)
  assert.equal(operationForQso(base, { startAtMillis: 1_500 }, []), base)
  // The fold reads a missing time as the epoch; so does this, so a contact
  // without a time is scored and exported under the same operation.
  assert.equal(county(operationForQso(base, {}, segments)), 'MORR')
})
