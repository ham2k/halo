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

import { defineExtension, hooks } from "@ham2k/halo-extension-sdk"
import type { ExportOption, ExportOptionsRequest, ExportRequest, ExportResult, HookContext } from "@ham2k/halo-extension-sdk"

import manifest from "../manifest.json" with { type: "json" }

const ADIF_VERSION = '3.1.5'
const DEFAULT_PROGRAM_ID = 'Ham2K Logger'

function field(name: string, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  const text = String(value)
  return `<${name}:${text.length}>${text} `
}

function slug(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

function filenameFor(operation: Record<string, unknown>, qsos: Record<string, unknown>[]): string {
  const stationCall = String(operation.stationCall ?? 'UNKNOWN')
  const title = String(operation.title ?? '')
  const firstMillis = qsos
    .map((qso) => Number(qso.startAtMillis ?? 0))
    .filter((t) => t > 0)
    .sort((a, b) => a - b)[0]
  const datePart = firstMillis ? fmtADIFDate(firstMillis) : fmtADIFDate(Date.now())
  return [datePart, slug(stationCall), slug(title)].filter((x) => x).join('-') + '.adi'
}

interface AdifField {
  name: string
  value: string
}

/// The QSO's own fields, shared by every ADIF record it produces.
/// `timeOffsetMillis` shifts this record's timestamp off the contact's — see
/// the caller for why.
function baseRowFor(qso: Record<string, unknown>, stationCall: string, timeOffsetMillis: number): string {
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
    row += field('QSO_DATE', fmtADIFDate(startAtMillis + timeOffsetMillis))
    row += field('TIME_ON', fmtADIFTime(startAtMillis + timeOffsetMillis))
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
  return row
}

/// Each `adifFields` hook's contribution, as a list of field sets — one per
/// ADIF record that hook wants written. Almost every hook returns exactly one.
/// An activity whose programs allow several references at once (a POTA n-fer)
/// returns one set per reference: the contact is submitted as one record each,
/// which is also why it counts once per reference toward an activation
/// (docs/design/activities.md §3.2, §4).
///
/// A hook declaring BOTH methods is asked only for its combinations — the same
/// way app-polo asks only its "main handler" — or its plain fields would be
/// written a second time into every record.
async function fieldSetsPerHook(
  qso: Record<string, unknown>,
  operation: Record<string, unknown>,
): Promise<AdifField[][][]> {
  const byHook = new Map<string, AdifField[][]>()

  const combined = await hooks.invokeAll('adifFields', 'fieldCombinationsForOneQSO', { qso, operation })
  for (const entry of combined) {
    if (!entry.ok || !Array.isArray(entry.value)) continue
    const sets = (entry.value as AdifField[][]).filter((set) => Array.isArray(set))
    if (sets.length > 0) byHook.set(entry.key, sets)
  }

  const single = await hooks.invokeAll('adifFields', 'fieldsForOneQSO', { qso, operation })
  for (const entry of single) {
    if (byHook.has(entry.key)) continue
    if (!entry.ok || !Array.isArray(entry.value)) continue
    byHook.set(entry.key, [entry.value as AdifField[]])
  }

  return [...byHook.values()]
}

const ExportHandler = {
  async suggestExportOptions({ operation, qsos }: ExportOptionsRequest, _ctx: HookContext): Promise<ExportOption[]> {
    return [
      {
        exportType: 'adif',
        format: 'adif',
        label: 'ADIF Export',
        filename: filenameFor(operation, qsos),
        icon: 'file-export',
        selectedByDefault: true,
      },
    ]
  },

  async generateExport({ operation, qsos }: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    const stationCall = String(operation.stationCall ?? 'UNKNOWN')
    const title = String(operation.title ?? '')

    const lines: string[] = []
    lines.push(`ADIF export for ${[stationCall, title].filter((x) => x).join(' — ')}`)
    lines.push(field('ADIF_VER', ADIF_VERSION))
    lines.push(field('PROGRAMID', ctx.appName ?? DEFAULT_PROGRAM_ID))
    lines.push(field('CREATED_TIMESTAMP', `${fmtADIFDate(Date.now())} ${fmtADIFTime(Date.now())}`))
    lines.push('<EOH>')
    lines.push('')

    for (const qso of qsos) {
      // Activity extensions contribute their program fields (SIG, POTA_REF…)
      // via in-runtime hook composition — no bridge crossing.
      const perHook = await fieldSetsPerHook(qso, operation)
      // One record per QSO unless a hook expands it. In practice at most one
      // does — you are not activating an n-fer in two programs at once — so the
      // record count is simply the largest any hook asked for.
      const recordCount = Math.max(1, ...perHook.map((sets) => sets.length))

      for (let n = 0; n < recordCount; n++) {
        // Records split out of one contact would otherwise be identical, and a
        // log processor is entitled to read that as a duplicate. app-polo
        // shifts each by a second (`qsonToADIF.js:144`); so do we.
        let row = baseRowFor(qso, stationCall, n * 1000)
        for (const sets of perHook) {
          // A hook with a single set describes the contact rather than one of
          // its records, so it belongs on all of them.
          const set = sets.length === 1 ? sets[0] : sets[n]
          if (!set) continue
          for (const extra of set) row += field(extra.name, extra.value)
        }
        row += '<EOR>'
        lines.push(row)
      }
    }

    return { filename: filenameFor(operation, qsos), mimeType: 'application/octet-stream', content: lines.join('\n') + '\n' }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('export', { hook: ExportHandler, key: 'adif' })
  },
})
