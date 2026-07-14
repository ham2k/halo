// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from 'node:test'
import assert from 'node:assert/strict'

import { parseCallNotes, combineNotes, expansionValueFor } from './callNotes.ts'

test('parseCallNotes: skips comments and blank lines, splits key from note', () => {
  const body = [
    '# TITLE: Hams of Note',
    '',
    '#== Ham2K =================',
    'KI2D 🤩 Sebastián - Ham2K PoLo Creator',
    'W1AW Hiram Percy Maxim Memorial Station',
  ].join('\n')
  const index = parseCallNotes(body)
  assert.deepEqual(Object.keys(index).sort(), ['KI2D', 'W1AW'])
  assert.equal(index.KI2D[0].note, '🤩 Sebastián - Ham2K PoLo Creator')
  assert.equal(index.W1AW[0].note, 'Hiram Percy Maxim Memorial Station')
})

test('parseCallNotes: keys shorter than 3 chars and note-less lines are dropped', () => {
  const index = parseCallNotes('AB too short a key\nK1ABC\nK2DEF kept')
  assert.deepEqual(Object.keys(index), ['K2DEF'])
})

test('parseCallNotes: repeated keys accumulate in file order, keys uppercase', () => {
  const index = parseCallNotes('vk1ao 🧑‍💻 Alan - Dev Team\nVK1AO 😁 Alan - Elmer')
  assert.equal(index.VK1AO.length, 2)
  assert.equal(index.VK1AO[0].note, '🧑‍💻 Alan - Dev Team')
  assert.equal(index.VK1AO[1].note, '😁 Alan - Elmer')
})

test('combineNotes: first entry supplies the text, all entries contribute unique marker emoji', () => {
  const combined = combineNotes([
    { call: 'VK1AO', note: '🧑‍💻 Alan - Dev Team' },
    { call: 'VK1AO', note: '😁 Alan - Elmer' },
    { call: 'VK1AO', note: '😁 duplicate marker' },
  ])
  assert.equal(combined?.note, '🧑‍💻😁 Alan - Dev Team')
  assert.equal(combined?.emoji, '🧑‍💻')
})

test('combineNotes: marker emojis cap at 4 with a +n overflow', () => {
  const combined = combineNotes(
    ['🤩', '😁', '👷', '🍻', '🎉', '🐶'].map((emoji, i) => ({ call: 'K1ABC', note: `${emoji} note ${i}` })),
  )
  assert.equal(combined?.note, '🤩😁👷🍻+2 note 0')
})

test('combineNotes: a note with no emoji keeps its text and has no marker', () => {
  const combined = combineNotes([{ call: 'K1ABC', note: 'Dan POTA Royalty' }])
  assert.equal(combined?.note, 'Dan POTA Royalty')
  assert.equal(combined?.emoji, undefined)
})

test('combineNotes: a leading accented letter is text, not an emoji marker', () => {
  const combined = combineNotes([{ call: 'K1ABC', note: 'Ángel - friend' }])
  assert.equal(combined?.note, 'Ángel - friend')
  assert.equal(combined?.emoji, undefined)
})

test('combineNotes: empty input combines to null', () => {
  assert.equal(combineNotes([]), null)
  assert.equal(combineNotes(undefined), null)
})

test('expansionValueFor: comma lists of calls are eligible, uppercased', () => {
  assert.equal(expansionValueFor([{ call: 'DAN', note: 'wd4dan,wd4jmm' }]), 'WD4DAN,WD4JMM')
  assert.equal(expansionValueFor([{ call: 'DAN', note: 'WD4DAN, WD4JMM' }]), 'WD4DAN, WD4JMM')
  assert.equal(expansionValueFor([{ call: 'DAN', note: 'WD4DAN' }]), 'WD4DAN')
})

test('expansionValueFor: emoji or free-text spacing disqualifies (issue #17)', () => {
  assert.equal(expansionValueFor([{ call: 'K1ABC', note: '👑 James POTA King' }]), null)
  assert.equal(expansionValueFor([{ call: 'K1ABC', note: 'Dan POTA Royalty' }]), null)
  assert.equal(expansionValueFor([{ call: 'K1ABC', note: '🎉 K1ABC,K2DEF' }]), null)
  assert.equal(expansionValueFor([{ call: 'K1ABC', note: 'WD4DAN,  WD4JMM' }]), null) // two spaces
})

test('expansionValueFor: falls through to the first eligible entry', () => {
  const value = expansionValueFor([
    { call: 'DAN', note: '👑 James POTA King' },
    { call: 'DAN', note: 'WD4DAN,WD4JMM' },
  ])
  assert.equal(value, 'WD4DAN,WD4JMM')
})
