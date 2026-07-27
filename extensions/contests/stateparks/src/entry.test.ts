// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The classes we declare about our own station. What is being pinned here is
// that neither reader will accept an answer THIS event never asked for: a setup
// form field that has been hidden still submits, so an operation switched from
// one event to another carries the previous one's answers on its ref — and those
// must not reach a score or a submitted log.

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/halo-extension-sdk"
import { cabrilloPower, configuredCategory, configuredOurPower, powerMultiplier } from "./entry.ts"
import { eventFor } from "./events.ts"

const TXSP = eventFor('TXSP')!
const OHSP = eventFor('OHSP')!
const GASP = eventFor('GASP')!

/// An operation whose stateparks ref carries [extra].
function operationWith(extra: Record<string, JSONValue>): Record<string, JSONValue> {
  return { uuid: 'op', refs: [{ type: 'stateparks', ref: 'TXSP', ...extra }] }
}

test('a power class is ours only if the event publishes it', () => {
  assert.equal(configuredOurPower(TXSP, operationWith({ ourPower: 'QRP' })), 'QRP')
  // Whatever case it was stored in.
  assert.equal(configuredOurPower(TXSP, operationWith({ ourPower: 'qrp' })), 'QRP')
  assert.equal(configuredOurPower(TXSP, operationWith({})), '')

  // Ohio's two classes don't include QRP, so Texas's answer left behind on the
  // ref is not one Ohio can be told about.
  assert.equal(configuredOurPower(OHSP, operationWith({ ourPower: 'QRP' })), '')
  assert.equal(configuredOurPower(OHSP, operationWith({ ourPower: 'HP' })), 'HP')
  // Georgia is asked nothing at all, so nothing is ever its answer.
  assert.equal(configuredOurPower(GASP, operationWith({ ourPower: 'LP' })), '')
})

test('the power multiplier is the event’s own number, and 0 when unanswered', () => {
  assert.equal(powerMultiplier(TXSP, operationWith({ ourPower: 'QRP' })), 3)
  assert.equal(powerMultiplier(TXSP, operationWith({ ourPower: 'LP' })), 2)
  assert.equal(powerMultiplier(TXSP, operationWith({ ourPower: 'HP' })), 1)
  // Zero, not one: an operator who never answered must not be handed a
  // multiplier the sponsor would not award them.
  assert.equal(powerMultiplier(TXSP, operationWith({})), 0)
  assert.equal(powerMultiplier(OHSP, operationWith({ ourPower: 'HP' })), 0, 'Ohio awards none')
})

test('an entry category is read back through the event too', () => {
  assert.equal(configuredCategory(OHSP, operationWith({ ourCategory: 'MSH' }))?.value, 'MSH')
  assert.equal(configuredCategory(OHSP, operationWith({ ourCategory: 'msh' }))?.transmitter, 'SINGLE')
  // MPO is single-transmitter by its own definition, and names no power.
  assert.equal(configuredCategory(OHSP, operationWith({ ourCategory: 'MPO' }))?.transmitter, 'SINGLE')
  assert.equal(configuredCategory(OHSP, operationWith({ ourCategory: 'MPO' }))?.power, undefined)
  assert.equal(configuredCategory(OHSP, operationWith({ ourCategory: 'SLX' })), undefined)
  // Texas has no categories, so Ohio's cannot leak into its exports.
  assert.equal(configuredCategory(TXSP, operationWith({ ourCategory: 'MSH' })), undefined)
})

test('CATEGORY-POWER comes from the category where the category names one', () => {
  // Six of Ohio's nine codes ARE a power class; the entry is what the sponsor
  // scores, so it wins over the field.
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'SL', ourPower: 'HP' })), 'LOW')
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'MMH' })), 'HIGH')
  // The three that don't fall back to the class we declared.
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'MPO', ourPower: 'HP' })), 'HIGH')
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'OUT', ourPower: 'LP' })), 'LOW')
  // A QRP left behind by Texas is not one of Ohio's two classes, so it claims
  // nothing here either — the header is dropped rather than guessed at LOW.
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'MPO', ourPower: 'QRP' })), '')
  // Nothing declared, nothing claimed — the writer drops an empty header.
  assert.equal(cabrilloPower(OHSP, operationWith({ ourCategory: 'INOH' })), '')
  assert.equal(cabrilloPower(OHSP, operationWith({})), '')
})

test('a scorer reads the ref it was handed, not the operation around it', () => {
  // A segmented log scores against the SEGMENT's ref, which is what `ownRef`
  // is — the same rule `configuredOurPark` follows, and the only source
  // `decorateRef` has.
  const ref: Record<string, JSONValue> = { type: 'stateparks', ref: 'TXSP', ourPower: 'LP' }
  assert.equal(powerMultiplier(TXSP, operationWith({ ourPower: 'QRP' }), ref), 2)
  assert.equal(configuredOurPower(TXSP, undefined, ref), 'LP')
})
