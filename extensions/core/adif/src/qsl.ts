// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Confirmations and award credit, written back in the fields the importer
// (`adif_to_qson.dart`) reads them from, so a log exported and imported again
// keeps what was confirmed and what a sponsor credited.

import { fmtADIFDate } from "@ham2k/lib-format-tools"

import type { AdifField } from "./fields.ts"

/// The ADIF award each chasing program's credit is written as when the
/// credit does not list its own: the importer's `_adifCreditPrograms`, the
/// other way round.
const PROGRAM_AWARDS: Record<string, string> = { dxcc: "DXCC", "ham2k-was": "WAS" }

/// The importer's `_adifCreditMedia`, the other way round.
const CREDIT_MEDIA: Record<string, string> = { lotw: "LOTW", qsl: "CARD", eqsl: "EQSL" }

function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {}
}

function date(value: unknown): string | undefined {
  return typeof value === "number" && value > 0 ? fmtADIFDate(value) : undefined
}

/// Only what QSON records as received is written as received. A service
/// QSON has no standard ADIF field for (Club Log, QRZ) is left out: an
/// `APP_` field names another program's own bookkeeping.
export function qslFields(qso: Record<string, unknown>): AdifField[] {
  const qsl = obj(qso.qsl)
  const paper = obj(qsl.qsl)
  const lotw = obj(qsl.lotw)
  const eqsl = obj(qsl.eqsl)
  return [
    { name: "QSL_RCVD", value: paper.received === true ? "Y" : undefined },
    { name: "QSLRDATE", value: date(paper.receivedOn) },
    { name: "QSLSDATE", value: date(paper.sentOn) },
    { name: "LOTW_QSL_RCVD", value: lotw.received === true ? "Y" : undefined },
    { name: "LOTW_QSLRDATE", value: date(lotw.receivedOn) },
    { name: "LOTW_QSLSDATE", value: date(lotw.sentOn) },
    { name: "EQSL_QSL_RCVD", value: eqsl.received === true ? "Y" : undefined },
    { name: "EQSL_QSLRDATE", value: date(eqsl.receivedOn) },
    { name: "CREDIT_GRANTED", value: creditGranted(obj(qso.credits)) },
  ]
}

/// ADIF's credit list, `DXCC:LOTW,DXCC_BAND:LOTW`: each verified program's
/// awards, by the medium that verified them. A program with no ADIF award is
/// left out — the credit stays in the log, and ADIF has no name for it.
function creditGranted(credits: Record<string, unknown>): string | undefined {
  const entries: string[] = []
  for (const [program, value] of Object.entries(credits)) {
    const credit = obj(value)
    if (credit.level !== "verified") continue
    const listed = Array.isArray(credit.awards) ? credit.awards.filter((award): award is string => typeof award === "string" && award !== "") : []
    const awards = listed.length > 0 ? listed : PROGRAM_AWARDS[program] ? [PROGRAM_AWARDS[program]] : []
    const medium = typeof credit.by === "string" ? CREDIT_MEDIA[credit.by] : undefined
    for (const award of awards) entries.push(medium ? `${award}:${medium}` : award)
  }
  return entries.length > 0 ? entries.join(",") : undefined
}
