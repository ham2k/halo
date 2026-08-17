// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A REG1TEST/EDI writer, ported from app-polo's `src/tools/qsonToReg1test.js`.
// The IARU Region 1 / RSGB VHF+ contest families submit this format instead
// of Cabrillo. Deliberately contest-agnostic (headers and per-QSO exchange
// fields are passed in), the same shape `simple-contest/src/cabrillo.ts`
// established — `rsgb-vhf-tests` imports this rather than getting its own
// copy.

import { fmtTimestamp } from "@ham2k/lib-format-tools"
import type { JSONValue } from "@ham2k/halo-extension-sdk"

/// REG1TEST's numeric mode codes. CW/SSB/FM/AM/RTTY only — no split-mode
/// codes, matching every REG1TEST contest HaLo ports. USB/LSB both read as
/// SSB: REG1TEST has no sideband distinction, so treating them as two
/// different modes would silently score a whole log's phone contacts as
/// mode 0 depending on which sideband the radio happened to report. The key
/// is `SSTV` — `lib-operation-data`'s `ALL_MODES` string, not app-polo's
/// `SSTY` (a typo there that never matched any logged QSO's mode).
const REG1TEST_MODE: Record<string, number> = {
  CW: 2, SSB: 1, USB: 1, LSB: 1, FM: 6, AM: 5, RTTY: 7, SSTV: 8,
}

/// REG1TEST's `PBand` header names bands by frequency, not HaLo's band
/// string. `70cm` is 432 MHz, not 432 GHz — app-polo's own table has this
/// entry wrong; corrected here rather than replicated. app-polo's table
/// also has no `23cm` entry at all: its `33cm` key holds 23cm's frequency
/// (1.3 GHz) instead. Both bands are real, distinct entries in
/// `lib-operation-data`'s `UHF_BANDS`, so this table gives each its own.
export const REG1TEST_BAND: Record<string, string> = {
  '6m': '50 MHz', '5m': '60 MHz', '4m': '70 MHz', '2m': '145 MHz',
  '70cm': '432 MHz', '33cm': '915 MHz', '23cm': '1.3 GHz', '13cm': '2.3 GHz',
  '9cm': '3.4 GHz', '6cm': '5.7 GHz', '3cm': '10 GHz', '1.25cm': '24 GHz',
  '6mm': '47 GHz', '4mm': '76 GHz', '2.5mm': '120 GHz', '2mm': '150 GHz',
  '1mm': '248 GHz',
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

export interface Reg1testQsoFields {
  sequenceSent?: string
  sequenceReceived?: string
  exchangeReceived?: string
  wwlReceived?: string
}

export interface Reg1testOptions {
  /// `[name, value]` pairs after `[REG1TEST;1]`, in order. A falsy value is
  /// omitted, matching Cabrillo's header convention.
  headers: [string, string | undefined][]
  remarks?: string
  /// The exchange-specific columns for one QSO — everything REG1TEST wants
  /// beyond what this writer computes itself (date/time/call/mode/RSTs).
  qsoFields: (qso: Record<string, JSONValue>) => Reg1testQsoFields
}

export function qsonToReg1test(qsos: Record<string, JSONValue>[], { headers, remarks, qsoFields }: Reg1testOptions): string {
  const realQsos = qsos.filter((qso) => qso.band !== 'event' && qso.deleted !== true)

  const lines: string[] = ['[REG1TEST;1]']
  for (const [name, value] of headers) {
    if (value) lines.push(`${name}=${value}`)
  }

  // `TDate` is mandatory — R1 log robots reject a file without it. Derived
  // from the QSOs actually logged rather than a per-event start/end date:
  // app-polo's own event table hardcodes one exact calendar date per event
  // per year and goes stale every January: this instead stays correct
  // forever, at the cost of reading "the day(s) logged" rather than "the
  // contest's official window" for an operator who logged outside it.
  const dates = realQsos
    .map((qso) => Number(qso.startAtMillis ?? qso.endAtMillis ?? 0))
    .filter((at) => at > 0)
  if (dates.length) {
    const first = fmtTimestamp(Math.min(...dates)).substring(2, 8)
    const last = fmtTimestamp(Math.max(...dates)).substring(2, 8)
    lines.push(`TDate=${first};${last}`)
  }

  if (remarks) lines.push('[Remarks]', remarks)

  lines.push(`[QSORecords;${realQsos.length}]`)

  for (const qso of realQsos) {
    const at = Number(qso.startAtMillis ?? qso.endAtMillis ?? 0)
    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const fields = qsoFields(qso)
    const timestamp = fmtTimestamp(at)

    const columns = [
      timestamp.substring(2, 8),
      timestamp.substring(8, 12),
      str(their.call),
      REG1TEST_MODE[str(qso.mode).toUpperCase()] ?? 0,
      reportFor(qso, 'our'),
      fields.sequenceSent ?? '',
      reportFor(qso, 'their'),
      fields.sequenceReceived ?? '',
      fields.exchangeReceived ?? '',
      fields.wwlReceived ?? '',
    ]
    lines.push(columns.join(';'))
  }

  return lines.join('\n') + '\n'
}

/// A blank RST would break the fixed-column EDI record, unlike Cabrillo's
/// free-text version — same 599/59 fallback cqww/cqwpx/iaru-hf's exporters
/// use for a QSO logged with no typed report.
function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === 'CW' || str(qso.mode) === 'RTTY' ? '599' : '59'
}
