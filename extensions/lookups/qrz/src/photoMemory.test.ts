// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/halo-extension-sdk"

import {
  PHOTO_MEMORY_LIMIT,
  PHOTO_MEMORY_TTL_MS,
  forgetNoPhoto,
  hasNoPhoto,
  historySaysNoPhoto,
  rememberNoPhoto,
} from "./photoMemory.ts"

const NOW = 1_700_000_000_000

test("a call nothing was recorded about is worth asking QRZ for", () => {
  assert.equal(hasNoPhoto({}, 'KI2D', NOW), false)
})

test("a call QRZ said it has no picture of is not asked again", () => {
  const memory = rememberNoPhoto({}, 'KI2D', NOW)
  assert.equal(hasNoPhoto(memory, 'KI2D', NOW + 1000), true)
})

test("callsigns match regardless of case", () => {
  const memory = rememberNoPhoto({}, 'ki2d', NOW)
  assert.equal(hasNoPhoto(memory, 'KI2D', NOW), true)
})

test("the answer goes stale, so a photo added later is still found", () => {
  const memory = rememberNoPhoto({}, 'KI2D', NOW)
  assert.equal(hasNoPhoto(memory, 'KI2D', NOW + PHOTO_MEMORY_TTL_MS - 1), true)
  assert.equal(hasNoPhoto(memory, 'KI2D', NOW + PHOTO_MEMORY_TTL_MS), false)
})

test("a stamp from the future is expired, not freshest", () => {
  // Developer time travel writes one — the sandbox's `Date` IS the app clock.
  // Read as freshest, it would suppress that call's photo until real time
  // caught up, with nothing on screen to say why.
  const travelled = rememberNoPhoto({}, 'KI2D', NOW + PHOTO_MEMORY_TTL_MS * 12)
  assert.equal(hasNoPhoto(travelled, 'KI2D', NOW), false)
})

test("a picture that turned up forgets the call, and says whether anything changed", () => {
  const memory = rememberNoPhoto({}, 'KI2D', NOW)
  assert.equal(hasNoPhoto(forgetNoPhoto(memory, 'KI2D'), 'KI2D', NOW), false)
  // The SAME object back when there was nothing to forget: the caller writes
  // to KV only when the map actually changed, and every lookup of a call with
  // a photo lands here.
  assert.equal(forgetNoPhoto(memory, 'W1AW'), memory)
})

test("the cache is bounded, and drops the oldest rather than the newest", () => {
  let memory: Record<string, number> = {}
  for (let i = 0; i < PHOTO_MEMORY_LIMIT; i++) memory = rememberNoPhoto(memory, `K${i}AAA`, NOW + i)
  memory = rememberNoPhoto(memory, 'W1AW', NOW + PHOTO_MEMORY_LIMIT)

  // Read from after the last write: every stamp above is in this map's own
  // future relative to NOW, and a future stamp is deliberately not believed.
  const later = NOW + PHOTO_MEMORY_LIMIT
  assert.equal(Object.keys(memory).length, PHOTO_MEMORY_LIMIT)
  assert.equal(hasNoPhoto(memory, 'W1AW', later), true, 'the call just written must survive')
  assert.equal(hasNoPhoto(memory, 'K0AAA', later), false, 'the oldest is the one dropped')
  assert.equal(hasNoPhoto(memory, `K${PHOTO_MEMORY_LIMIT - 1}AAA`, later), true)
})

// --- the durable half: what the log itself remembers ---

/// A past QSO as `ctx.getHistoryForCall` hands it over: the whole record.
function pastQso(lookups: Record<string, unknown>[], startAtMillis = NOW): Record<string, JSONValue> {
  return { their: { call: 'KI2D', lookups }, startAtMillis } as unknown as Record<string, JSONValue>
}

test("a past QSO whose QRZ record carried no picture is the remembered answer", () => {
  assert.equal(historySaysNoPhoto([pastQso([{ source: 'qrz.com', name: 'Sebastián' }])], NOW), true)
})

test("a past QSO whose QRZ record HAD a picture is not", () => {
  assert.equal(
    historySaysNoPhoto([pastQso([{ source: 'qrz.com', image: 'https://qrz.test/ki2d.jpg' }])], NOW),
    false,
  )
})

test("never asked is not the same as no picture", () => {
  // A QSO logged offline, or before a QRZ account was configured, carries no
  // QRZ record at all. Reading that as "no photo" would suppress the lookup
  // that finally finds one — permanently, for the calls worked longest.
  assert.equal(historySaysNoPhoto([pastQso([{ source: 'call-history', name: 'Sebastián' }])], NOW), false)
  assert.equal(historySaysNoPhoto([pastQso([])], NOW), false)
  assert.equal(historySaysNoPhoto([], NOW), false)
})

test("an empty image string is no picture, not a picture", () => {
  assert.equal(historySaysNoPhoto([pastQso([{ source: 'qrz.com', image: '   ' }])], NOW), true)
})

test("the newest QSO carrying a QRZ record answers, not an older one", () => {
  // History arrives newest first. An older lookup saying "no photo" must not
  // outvote a newer one that found one.
  const history = [
    pastQso([{ source: 'qrz.com', image: 'https://qrz.test/ki2d.jpg' }]),
    pastQso([{ source: 'qrz.com' }]),
  ]
  assert.equal(historySaysNoPhoto(history, NOW), false)
})

test("QSOs with no QRZ record are skipped over to reach one that has it", () => {
  const history = [pastQso([{ source: 'call-notes' }]), pastQso([{ source: 'qrz.com' }])]
  assert.equal(historySaysNoPhoto(history, NOW), true)
})

test("an answer old enough to have gone stale is asked again", () => {
  const stale = pastQso([{ source: 'qrz.com' }], NOW - PHOTO_MEMORY_TTL_MS)
  assert.equal(historySaysNoPhoto([stale], NOW), false)
})

test("a QSO stamped in the future is not believed either", () => {
  // Same reason the session map clamps: developer time travel logs one.
  const travelled = pastQso([{ source: 'qrz.com' }], NOW + PHOTO_MEMORY_TTL_MS)
  assert.equal(historySaysNoPhoto([travelled], NOW), false)
})

test("a QSO with no time at all is not trusted to have aged", () => {
  const undated = { their: { call: 'KI2D', lookups: [{ source: 'qrz.com' }] } } as unknown as Record<string, JSONValue>
  assert.equal(historySaysNoPhoto([undated], NOW), false)
})
