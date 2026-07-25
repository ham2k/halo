// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CQ WPX Contest. Ported from app-polo's CQWPXExtension.
//
// The third contest ported (docs/design/contests.md M3), chosen for the one
// thing the first two didn't have: a SERIAL NUMBER exchange. In app-polo the
// sent number is state on the operation ref, bumped by a dispatch after each
// save — which leaks a number whenever a half-composed QSO is wiped, and hands
// the same number to two QSOs if a spot is tapped mid-entry. Here the extension
// only DECLARES the sequence; the core allocates from it inside the QSO insert
// (docs/design/contests.md §5.8), so neither failure is reachable.

import { contestScorer, defineExtension } from "@ham2k/halo-extension-sdk"
import type {
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
} from "@ham2k/halo-extension-sdk"

import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"
import { tFor } from "./i18n.ts"
import { CQWPXScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'cqwpx'

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// A serial as it should appear in an export: whatever is on the ref, as digits.
function serial(qso: Record<string, JSONValue>, field: string): string {
  const value = refOfType(qso, TYPE)?.[field]
  if (typeof value === 'number') return String(value)
  const digits = str(value).trim()
  return /^\d+$/.test(digits) ? String(parseInt(digits, 10)) : ''
}

const ActivityHook = {
  async operationControls(
    _args: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    return [
      {
        key: 'cqwpx/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'form',
          refType: TYPE,
          form: {
            title: t('setupLabel'),
            elements: [
              {
                type: 'field',
                fieldType: 'radio',
                key: 'mode',
                label: t('modeLabel'),
                // CQ WPX runs these as separate contests on separate weekends.
                options: [{ value: 'CW', label: 'CW' }, { value: 'SSB', label: 'SSB' }, { value: 'RTTY', label: 'RTTY' }],
              },
            ],
          },
        },
      },
    ]
  },

  /// Two fields per QSO: the number we send and the number they send.
  ///
  /// Ours is a `serial` input — the extension names the sequence and the core
  /// fills the field, so nothing here tracks a counter. It is deliberately NOT
  /// scoped per band: WPX numbers a single series for the whole entry.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing. This is an OPTIMIZATION, not the rule:
    // the core already refuses a primary field to any activity the operation
    // isn't running (halo_widgets' `_textControls`), so forgetting this guard
    // is invisible to the operator. What it saves is the work below — a country
    // -file annotation per keystroke-triggered refresh, in the JS isolate,
    // multiplied by every contest extension the user happens to have enabled.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    return [
      {
        key: 'cqwpx/ourSerial',
        label: t('ourSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'serial',
          refType: TYPE,
          field: 'ourSerial',
          sequence: { key: 'serial' },
        },
      },
      {
        key: 'cqwpx/theirSerial',
        label: t('theirSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'theirSerial',
          numeric: true,
          maxLength: 5,
          // No placeholder: there is nothing to guess about the number another
          // station is about to send.
        },
      },
    ]
  },

  /// Mirrors the exchange this contest keeps on its own ref into the generic
  /// `their.exchange`. Nothing outside this extension knows to look inside a
  /// contest ref, so without this the QSO row's exchange column and a plain
  /// (non-contest) ADIF export both come up empty on a contest log.
  ///
  /// Only ever a projection: the ref stays the source of truth, and the patch
  /// touches exactly one field.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null
    // the serial they sent
    const exchange = serial(args.qso, 'theirSerial')
    if (!exchange) return null
    return { their: { exchange } }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? '').trim() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const label = mode ? `CQ WPX ${mode}` : tFor(ctx)('unconfigured')
    return { ...ref, program: 'Contest', label, shortLabel: label }
  },

  /// "KI2D for CQWPX CW", subtitled with what the exchange is — unlike CQ WW's
  /// zone there is no fixed value to show, since the number changes every QSO.
  async suggestOperationTitle({ ref }: { ref: Ref }, ctx: HookContext) {
    const mode = str((ref as Record<string, JSONValue>).mode)
    return {
      for: ['CQWPX', mode].filter((x) => x).join(' '),
      subtitle: tFor(ctx)('serialSubtitle'),
    }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const opRef = refOfType(operation, TYPE)
    if (!opRef) return []
    const mode = str(opRef.mode)

    const fields: { name: string; value: string }[] = [
      { name: 'CONTEST_ID', value: mode ? `CQ-WPX-${mode}` : 'CQ-WPX' },
    ]
    const sent = serial(qso, 'ourSerial')
    const received = serial(qso, 'theirSerial')
    if (sent) fields.push({ name: 'STX', value: sent })
    if (received) fields.push({ name: 'SRX', value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === 'CW' || str(qso.mode) === 'RTTY' ? '599' : '59'
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    if (!refOfType(args.operation, TYPE)) return []
    const t = tFor(ctx)
    return [
      { exportType: 'contest-adif', format: 'adif', label: t('adifExport'), selectedByDefault: true },
      { exportType: 'cabrillo', format: 'cabrillo', label: t('cabrilloExport'), selectedByDefault: true },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes `suggestExportOptions` above offers. Belt and
    // braces alongside the keyed `invokeOne` below: a hook that answers for an
    // exportType it never offered is how the ADIF delegation recursed into
    // itself in the first place.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const mode = str(refOfType(operation, TYPE)?.mode)
    const ourCall = str(operation.stationCall)
    const stamp = `CQ-WPX-${mode || 'DX'}-${ourCall || 'log'}`.replace(/[^A-Za-z0-9_-]+/g, '-')

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', mode ? `CQ-WPX-${mode}` : 'CQ-WPX'],
          ['CALLSIGN', ourCall],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => [
          ourCall || '-',
          reportFor(qso, 'our'),
          serial(qso, 'ourSerial') || '0',
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
          reportFor(qso, 'their'),
          serial(qso, 'theirSerial') || '0',
        ],
      })
      return { filename: `${stamp}.log`, mimeType: 'text/plain', content }
    }

    const { hooks } = await import("@ham2k/halo-extension-sdk")
    // invokeOne, NOT invokeAll: the fan-out includes this contest's own
    // `generateExport`, which would take the same ADIF branch and delegate
    // again — unbounded recursion that only surfaced as a 30s export timeout.
    const entries = await hooks.invokeOne('export', 'adif', 'generateExport', {
      operation: args.operation,
      qsos: args.qsos,
      exportType: 'adif',
    })
    const adif = entries.find((e) => e.ok)
    return {
      filename: `${stamp}.adi`,
      mimeType: 'text/plain',
      content: ((adif?.value as ExportResult | undefined)?.content) ?? '',
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('activity', { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook('adifFields', { hook: AdifFieldsHook, key: TYPE })
    registerHook('export', { hook: ExportHook, key: TYPE })
    registerHook('scoring', {
      hook: contestScorer(CQWPXScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
