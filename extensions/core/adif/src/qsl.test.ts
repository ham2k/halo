// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A whole-log export is the operator's backup. A confirmation or credit it
// leaves out is gone from the log restored from it, and every checklist built
// on that log drops back to worked.

import { test } from "node:test"
import assert from "node:assert/strict"

import { renderRow } from "./fields.ts"
import { qslFields } from "./qsl.ts"

const JULY_5_2021 = Date.UTC(2021, 6, 5)

test("confirmations are written in the fields the importer reads them from", () => {
  const row = renderRow(
    qslFields({
      qsl: {
        lotw: { received: true, receivedOn: JULY_5_2021, sentOn: JULY_5_2021 },
        qsl: { received: true },
        eqsl: { received: true, receivedOn: JULY_5_2021 },
        received: true,
      },
    }),
  )
  assert.equal(row, "<QSL_RCVD:1>Y <LOTW_QSL_RCVD:1>Y <LOTW_QSLRDATE:8>20210705 <LOTW_QSLSDATE:8>20210705 <EQSL_QSL_RCVD:1>Y <EQSL_QSLRDATE:8>20210705 ")
})

test("a contact nothing confirmed writes nothing", () => {
  assert.equal(renderRow(qslFields({})), "")
  assert.equal(renderRow(qslFields({ qsl: { lotw: { received: false } } })), "")
})

test("award credit is written as ADIF's credit list, award by award", () => {
  const row = renderRow(qslFields({ credits: { dxcc: { level: "verified", by: "lotw", awards: ["DXCC", "DXCC_BAND"] } } }))
  assert.equal(row, "<CREDIT_GRANTED:24>DXCC:LOTW,DXCC_BAND:LOTW ")
})

test("a credit that lists no awards is written as its program's award", () => {
  assert.equal(renderRow(qslFields({ credits: { dxcc: { level: "verified", by: "qsl" } } })), "<CREDIT_GRANTED:9>DXCC:CARD ")
})

// POTA's credit has no ADIF award: written under a made-up name it would be a
// claim no ADIF reader can check.
test("a credit with no ADIF award, or one that is not verified, writes nothing", () => {
  assert.equal(renderRow(qslFields({ credits: { "ham2k-pota": { level: "verified", by: "pota" }, dxcc: { level: "confirmed" } } })), "")
})
