// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ADIF export. Lives in the extension runtime (DESIGN.md §4: export hooks are
// extension territory) and reuses the published ham-js-libs for dates and
// mode/submode mapping. Deliberately minimal compared to app-polo's
// template-driven exporter — activity/contest extensions will contribute their
// own fields via adifFieldsForOneQSO hooks in a later phase.

import { fmtADIFDate, fmtADIFTime } from "@ham2k/lib-format-tools"
import { adifModeAndSubmodeForMode } from "@ham2k/lib-operation-data"

import { defineExtension, hooks } from "@ham2k/polo-sdk"
import type { ExportRequest, ExportResult, HookContext } from "@ham2k/polo-sdk"

const ADIF_VERSION = '3.1.5'
const PROGRAM_ID = 'Ham2K HaLo Next'

function field(name: string, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  const text = String(value)
  return `<${name}:${text.length}>${text} `
}

function slug(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

const ExportHandler = {
  async generateExport({ operation, qsos }: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    const stationCall = String(operation.stationCall ?? 'UNKNOWN')
    const title = String(operation.title ?? '')

    const lines: string[] = []
    lines.push(`ADIF export for ${[stationCall, title].filter((x) => x).join(' — ')}`)
    lines.push(field('ADIF_VER', ADIF_VERSION))
    lines.push(field('PROGRAMID', PROGRAM_ID))
    lines.push(field('CREATED_TIMESTAMP', `${fmtADIFDate(Date.now())} ${fmtADIFTime(Date.now())}`))
    lines.push('<EOH>')
    lines.push('')

    for (const qso of qsos) {
      const our = (qso.our ?? {}) as Record<string, unknown>
      const their = (qso.their ?? {}) as Record<string, unknown>
      // The merged lookup guess (Lookups feature, ham2k/app-halo-dist#8)
      // stays nested under `their.guess` rather than flattened onto
      // `their` itself — fall back to it for fields the operator never
      // manually entered, same convention as app-polo's ADIF exporter.
      const theirGuess = (their.guess ?? {}) as Record<string, unknown>
      const startAtMillis = Number(qso.startAtMillis ?? 0)
      const [mode, submode] = adifModeAndSubmodeForMode(String(qso.mode ?? 'SSB'))
      const freqKHz = Number(qso.freq ?? 0)

      let row = ''
      row += field('CALL', their.call)
      if (startAtMillis > 0) {
        row += field('QSO_DATE', fmtADIFDate(startAtMillis))
        row += field('TIME_ON', fmtADIFTime(startAtMillis))
      }
      row += field('BAND', qso.band)
      if (freqKHz > 0) row += field('FREQ', (freqKHz / 1000).toFixed(6).replace(/0+$/, '').replace(/\.$/, ''))
      row += field('MODE', mode)
      row += field('SUBMODE', submode)
      row += field('RST_SENT', our.sent)
      row += field('RST_RCVD', their.sent)
      row += field('STATION_CALLSIGN', stationCall)
      row += field('NAME', their.name ?? theirGuess.name)
      row += field('QTH', their.city ?? theirGuess.city)
      row += field('STATE', their.state ?? theirGuess.state)
      row += field('COUNTRY', their.country ?? theirGuess.country)
      row += field('GRIDSQUARE', their.grid ?? theirGuess.grid)
      row += field('NOTES', qso.notes)

      // Activity extensions contribute their program fields (SIG, POTA_REF…)
      // via in-runtime hook composition — no bridge crossing.
      const contributions = await hooks.invokeAll('adifFields', 'fieldsForOneQSO', { qso, operation })
      for (const entry of contributions) {
        if (!entry.ok || !Array.isArray(entry.value)) continue
        for (const extra of entry.value as { name: string; value: string }[]) {
          row += field(extra.name, extra.value)
        }
      }

      row += '<EOR>'
      lines.push(row)
    }

    const firstMillis = qsos
      .map((qso) => Number(qso.startAtMillis ?? 0))
      .filter((t) => t > 0)
      .sort((a, b) => a - b)[0]
    const datePart = firstMillis ? fmtADIFDate(firstMillis) : fmtADIFDate(Date.now())
    const filename = [datePart, slug(stationCall), slug(title)].filter((x) => x).join('-') + '.adi'

    return { filename, mimeType: 'application/octet-stream', content: lines.join('\n') + '\n' }
  },
}

defineExtension({
  key: 'adif',
  name: 'ADIF Export',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('export', { hook: ExportHandler, key: 'adif' })
  },
})
