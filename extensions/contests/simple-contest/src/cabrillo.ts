// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Cabrillo 3.0 writer, ported from app-polo's `src/tools/qsonToCabrillo.js`.
//
// NOTE: `@ham2k/lib-qson-cabrillo` only goes the other way — it exports
// `cabrilloToQSON` (an importer) and no writer — so the generation side lives
// here. It is deliberately contest-agnostic (headers and per-QSO exchange
// columns are passed in) so it can move to a shared module once a second
// contest needs it, rather than being copied.

import { fmtCabrilloDate, fmtCabrilloTime } from "@ham2k/lib-format-tools"
import type { JSONValue } from "@ham2k/halo-extension-sdk"

/// VHF+ Cabrillo logs name their band rather than a kHz frequency; HF logs use
/// kHz. Values match app-polo's table, including the entries it flags as
/// non-standard.
const DEFAULT_FREQUENCIES_PER_BAND: Record<string, string> = {
  '160m': '1800', '80m': '3500', '60m': '5332', '40m': '7000', '30m': '10100',
  '20m': '14000', '17m': '18068', '15m': '21000', '12m': '24890', '10m': '28000',
  '6m': '50', '4m': '70', '2m': '144', '70cm': '432', '33cm': '902',
  '23cm': '1.2G', '13cm': '2.3G', '9cm': '3.4G', '6cm': '5.7G', '3cm': '10G',
  '1.25cm': '24G', '6mm': '47G', '4mm': '75G', '2.5mm': '122G', '2mm': '134G',
  '1mm': '241G', submm: 'LIGHT',
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

export function cabrilloFreq(qso: Record<string, JSONValue>): string {
  const freq = Number(qso.freq)
  if (freq) {
    return freq < 50000 ? `${Math.round(freq)}` : (DEFAULT_FREQUENCIES_PER_BAND[str(qso.band)] ?? '0')
  }
  return DEFAULT_FREQUENCIES_PER_BAND[str(qso.band)] ?? '0'
}

/// Cabrillo collapses every phone mode to PH and everything non-CW/phone to DG.
export function cabrilloMode(qso: Record<string, JSONValue>): string {
  switch (str(qso.mode)) {
    case 'SSB': case 'USB': case 'LSB': case 'AM': case 'FM': return 'PH'
    case 'CW': return 'CW'
    default: return 'DG'
  }
}

export interface CabrilloOptions {
  /// `[name, value]` pairs emitted after START-OF-LOG; empty values are dropped.
  headers: [string, string | undefined][]
  /// The exchange columns for one QSO, after frequency/mode/date/time — e.g.
  /// `[ourCall, ourRst, ourExchange, theirCall, theirRst, theirExchange]`.
  qsoParts: (qso: Record<string, JSONValue>) => string[]
  createdBy?: string
}

export function qsonToCabrillo(
  qsos: Record<string, JSONValue>[],
  { headers, qsoParts, createdBy = 'Ham2K Logger' }: CabrilloOptions,
): string {
  const lines: string[] = ['START-OF-LOG: 3.0', `CREATED-BY: ${createdBy}`]

  for (const [name, value] of headers) {
    if (value) lines.push(`${name}: ${value}`)
  }

  for (const qso of qsos) {
    // Event rows (breaks/starts) and deleted records aren't contacts.
    if (qso.band === 'event' || qso.deleted === true) continue
    const at = Number(qso.startAtMillis ?? qso.endAtMillis ?? 0)
    const columns = [
      cabrilloFreq(qso).padEnd(5, ' '),
      cabrilloMode(qso).padEnd(2, ' '),
      fmtCabrilloDate(at).padEnd(10, ' '),
      fmtCabrilloTime(at).padEnd(4, ' '),
      qsoParts(qso).join(' '),
    ]
    lines.push(`QSO: ${columns.join(' ')}`)
  }

  lines.push('END-OF-LOG:')
  return lines.join('\n') + '\n'
}
