// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import test from "node:test"
import assert from "node:assert/strict"

import { activityAdifImport } from "./activityAdifImport.ts"
import type { HookContext } from "./types.ts"

const ctx = {} as HookContext

const pota = activityAdifImport({
  sig: 'POTA',
  huntingType: 'pota',
  activationType: 'potaActivation',
  refField: 'pota_ref',
})

function refsFor(fields: Record<string, string>) {
  return pota.refsForRecords({ records: [{ fields }] }, ctx)
}

test('reads the hunted and activated sides from the SIG pair', async () => {
  const [result] = await refsFor({
    sig: 'POTA',
    sig_info: 'K-1467',
    my_sig: 'POTA',
    my_sig_info: 'K-0001',
  })

  assert.deepEqual(result, {
    refs: [
      { type: 'pota', ref: 'K-1467' },
      { type: 'potaActivation', ref: 'K-0001' },
    ],
  })
})

test('an n-fer stays an n-fer when SIG_INFO names only the primary', () => {
  // SIG_INFO names one park, POTA_REF names both. Preferring SIG_INFO would
  // silently import a two-park contact as a one-park one — and it would still
  // look right. The union can't, because the primary is already in the list.
  return refsFor({
    sig: 'POTA',
    sig_info: 'K-1467',
    pota_ref: 'K-1467,K-9999',
  }).then(([result]) => {
    assert.deepEqual(result?.refs, [
      { type: 'pota', ref: 'K-1467' },
      { type: 'pota', ref: 'K-9999' },
    ])
  })
})

test('takes references from BOTH sources, not whichever it finds first', async () => {
  // Neither field subsumes the other, so a record whose two spellings disagree
  // must yield their union. Reading only the list field would drop K-2222.
  const [result] = await refsFor({
    sig: 'POTA',
    sig_info: 'K-2222',
    pota_ref: 'K-1467',
  })

  assert.deepEqual(result?.refs, [
    { type: 'pota', ref: 'K-1467' },
    { type: 'pota', ref: 'K-2222' },
  ])
})

test('the same reference in both fields lands once, after normalizing', async () => {
  // The union is only safe because it dedupes, and it must dedupe on the
  // NORMALIZED value: 'K-1467' and 'k-1467' are one park and two strings.
  const strict = activityAdifImport({
    sig: 'POTA',
    huntingType: 'pota',
    activationType: 'potaActivation',
    refField: 'pota_ref',
    normalize: (ref) => ref.toUpperCase(),
  })

  const [result] = await strict.refsForRecords(
    { records: [{ fields: { sig: 'POTA', sig_info: 'k-1467', pota_ref: 'K-1467' } }] },
    ctx,
  )

  assert.deepEqual(result?.refs, [{ type: 'pota', ref: 'K-1467' }])
})

test('ignores another program\'s SIG_INFO', async () => {
  // Every reference program writes SIG_INFO. Without the SIG check, a WWFF
  // reference would import as a park.
  const [result] = await refsFor({ sig: 'WWFF', sig_info: 'KFF-1234' })

  assert.equal(result, null)
})

test('the program-specific list field identifies the program on its own', async () => {
  // Some loggers write POTA_REF without a SIG at all.
  const [result] = await refsFor({ pota_ref: 'K-1467' })

  assert.deepEqual(result?.refs, [{ type: 'pota', ref: 'K-1467' }])
})

test('an empty _intl twin does not shadow the real field', async () => {
  // ADIF files carry empty tags routinely, and `??` only skips undefined — so
  // an empty SIG_INFO_INTL would win over a real SIG_INFO and drop every
  // reference in the log.
  const [byInfo] = await refsFor({ sig: 'POTA', sig_info: 'K-1467', sig_info_intl: '' })
  assert.deepEqual(byInfo?.refs, [{ type: 'pota', ref: 'K-1467' }])

  const [bySig] = await refsFor({ sig: 'POTA', sig_intl: '', sig_info: 'K-1467' })
  assert.deepEqual(bySig?.refs, [{ type: 'pota', ref: 'K-1467' }])
})

test('a populated _intl twin is preferred over the plain field', async () => {
  // Guards the fix above from simply ignoring _intl.
  const [result] = await refsFor({ sig_intl: 'POTA', sig_info_intl: 'K-9999', sig_info: 'K-1467' })

  assert.deepEqual(result?.refs, [{ type: 'pota', ref: 'K-9999' }])
})

test('a record with nothing to say returns null, not an empty ref list', async () => {
  const [result] = await refsFor({ call: 'W1AW' })

  assert.equal(result, null)
})

test('results are positional, one per record', async () => {
  // The core matches these back to records by index, so a hook that filtered
  // its empties would silently shift every later record's refs onto the wrong
  // QSO.
  const results = await pota.refsForRecords(
    {
      records: [
        { fields: { pota_ref: 'K-1' } },
        { fields: { call: 'W1AW' } },
        { fields: { pota_ref: 'K-2' } },
      ],
    },
    ctx,
  )

  assert.equal(results.length, 3)
  assert.deepEqual(results[0]?.refs, [{ type: 'pota', ref: 'K-1' }])
  assert.equal(results[1], null)
  assert.deepEqual(results[2]?.refs, [{ type: 'pota', ref: 'K-2' }])
})

test('normalize is applied, and a reference it rejects is dropped', async () => {
  const strict = activityAdifImport({
    sig: 'POTA',
    huntingType: 'pota',
    activationType: 'potaActivation',
    refField: 'pota_ref',
    normalize: (ref) => (ref.toUpperCase().startsWith('K-') ? ref.toUpperCase() : ''),
  })

  const [result] = await strict.refsForRecords({ records: [{ fields: { pota_ref: 'k-1467, nonsense' } }] }, ctx)

  assert.deepEqual(result?.refs, [{ type: 'pota', ref: 'K-1467' }])
})

test('tolerates spaces around the list separator', async () => {
  const [result] = await refsFor({ pota_ref: 'K-1, K-2 ,K-3' })

  assert.deepEqual(result?.refs?.map((r) => r.ref), ['K-1', 'K-2', 'K-3'])
})
