// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL International DX Contest. Ported from app-polo's ARRLDXExtension.
//
// The dynamic side of the input catalog in action: this contest's single
// exchange field is a state/province OR a power level depending on which side
// of the contest we're on — different label, different validation, same
// control. `loggingControls` gets the operation, so the descriptor is just
// computed per call; nothing in the core is needed to support it.

import { adifForExport, contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/extension-sdk"
import type {
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  RefLink,
} from "@ham2k/extension-sdk"

import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"
import { tFor } from "./i18n.ts"
import { ARRLDXScorer, POWER_PATTERN, isWveCall, weAreWve } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'arrl-dx'

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

const ActivityHook = {
  async operationControls(
    args: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const ref = refOfType(args.operation, TYPE)
    const ours = weAreWve(args.operation, ref)

    return [
      {
        key: 'arrl-dx/setup',
        // See CQ WW: the Activity Types list names the contest family.
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
                options: [{ value: 'CW', label: 'CW' }, { value: 'Phone', label: 'Phone' }],
              },
              {
                type: 'field',
                fieldType: 'radio',
                key: 'stationType',
                label: t('stationTypeLabel'),
                // Pre-answered from our own callsign; the operator only has to
                // touch it when they're operating from somewhere unexpected.
                options: [
                  { value: 'wve', label: t('stationTypeWve') },
                  { value: 'dx', label: t('stationTypeDx') },
                ],
              },
              {
                type: 'field',
                fieldType: 'text',
                key: 'exchange',
                // What we send is the other half of the asymmetry: a W/VE
                // station sends its state, a DX station sends its power.
                label: ours ? t('ourStateLabel') : t('ourPowerLabel'),
                placeholder: ours ? t('ourStatePlaceholder') : t('ourPowerPlaceholder'),
                uppercase: true,
              },
            ],
          },
        },
      },
    ]
  },

  /// One field, two meanings. We receive power from a DX station and a
  /// state/province from a W/VE one — so both the label and the validation
  /// follow whichever side we're on.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing. This is an OPTIMIZATION, not the rule:
    // the core already refuses a primary field to any activity the operation
    // isn't running (halo_widgets' `_textControls`), so forgetting this guard
    // is invisible to the operator. What it saves is the work below, run per
    // keystroke-triggered refresh in the JS isolate,
    // multiplied by every contest extension the user happens to have enabled.
    const ref = refOfType(args.operation, TYPE)
    if (!ref) return []

    const t = tFor(ctx)
    const ours = weAreWve(args.operation, ref)

    const their = ((args.qso?.their as Record<string, JSONValue>) ?? {})
    const guess = (their.guess as Record<string, JSONValue>) ?? {}
    // Only worth hinting the state side: nothing can predict a power level.
    const stateHint = str(their.state) || str(guess.state)

    return [
      {
        key: 'arrl-dx/exchange',
        label: ours ? t('theirPowerLabel') : t('theirStateLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'theirExchange',
          // A W/VE station receives power, which is validated; a DX station
          // receives a state or province, which is not — the sections and
          // abbreviations in use are broader than a pattern should presume.
          // No informational placeholder: nothing can guess a power level, and
          // the state hint only shows when the lookup actually produced one.
          ...(ours
            ? { pattern: POWER_PATTERN, maxLength: 4 }
            : { placeholder: stateHint || undefined, maxLength: 4 }),
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
    // their state/province or power, whichever side we are on
    const qsoRef = refOfType(args.qso, TYPE)
    const exchange = str(qsoRef?.theirExchange)
    // A field the operator EMPTIED is present-but-blank rather than absent (see
    // `_refsWithTextValues`). Returning null there would leave the previous
    // save's `their.exchange` showing in the QSO row and in a plain ADIF export,
    // so a cleared exchange has to project the blank.
    if (!exchange) return qsoRef && 'theirExchange' in qsoRef ? { their: { exchange: '' } } : null
    return { their: { exchange } }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? '').trim() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const r = ref as Record<string, JSONValue>
    const mode = str(r.mode)
    const label = mode ? `ARRL DX ${mode}` : tFor(ctx)('unconfigured')
    const sent = str(r.exchange)
    return { ...ref, program: 'Contest', label, shortLabel: label, name: sent || tFor(ctx)('notConfigured') }
  },

  /// Same reasoning as CQ WW: what we send goes in the subtitle. For ARRL DX
  /// that's our state/province or our power, depending on which side we're on.
  async suggestOperationTitle(
    { ref }: { ref: Ref; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ) {
    const r = ref as Record<string, JSONValue>
    const mode = str(r.mode)
    const sent = str(r.exchange)
    return {
      for: ['ARRL DX', mode].filter((x) => x).join(' '),
      subtitle: sent || undefined,
    }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: 'https://www.arrl.org/arrl-dx', label: 'ARRL DX' }
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
      { name: 'CONTEST_ID', value: mode === 'Phone' ? 'ARRL-DX-SSB' : mode ? `ARRL-DX-${mode}` : 'ARRL-DX' },
    ]
    const sent = str(opRef.exchange)
    const received = str(refOfType(qso, TYPE)?.theirExchange)
    if (sent) fields.push({ name: 'STX_STRING', value: sent })
    if (received) fields.push({ name: 'SRX_STRING', value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === 'CW' || str(qso.mode) === 'RTTY' ? '599' : '59'
}

/// The contest's own name for this operation's file — the mode is part of the
/// identity here, since ARRL DX CW and ARRL DX Phone are separate contests
/// with separate submissions.
function contestTag(operation: Record<string, JSONValue>): string {
  const mode = str(refOfType(operation, TYPE)?.mode)
  return `ARRL-DX-${mode || 'DX'}`
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: contestTag(operation),
    startAtMillis: startMillisOf(operation, qsos),
    extension,
    compact,
  })
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    if (!refOfType(args.operation, TYPE)) return []
    const t = tFor(ctx)
    const named = (extension: string) =>
      filenameFor(args.operation, args.qsos ?? [], extension, args.compactFilenames)
    return [
      {
        exportType: 'contest-adif',
        format: 'adif',
        label: t('adifExport', { contest: manifest.shortName }),
        filename: named('adi'),
        selectedByDefault: true,
        refType: TYPE,
      },
      {
        exportType: 'cabrillo',
        format: 'cabrillo',
        label: t('cabrilloExport', { contest: manifest.shortName }),
        filename: named('log'),
        selectedByDefault: true,
        refType: TYPE,
      },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes `suggestExportOptions` above offers. Belt and
    // braces alongside `adifForExport`'s keyed delegation: a hook that answers for an
    // exportType it never offered makes the ADIF delegation recurse into
    // itself.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const mode = str(opRef?.mode)
    const ourCall = str(operation.stationCall)

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', mode === 'Phone' ? 'ARRL-DX-SSB' : mode ? `ARRL-DX-${mode}` : 'ARRL-DX'],
          ['CALLSIGN', ourCall],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => [
          ourCall || '-',
          reportFor(qso, 'our'),
          str(opRef?.exchange) || '-',
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
          reportFor(qso, 'their'),
          str(refOfType(qso, TYPE)?.theirExchange) || '-',
        ],
      })
      return {
        filename: filenameFor(operation, args.qsos, 'log', args.compactFilenames),
        mimeType: 'text/plain',
        content,
      }
    }

    const content = await adifForExport({
      operation: args.operation,
      qsos: args.qsos,
      includePrivateData: args.includePrivateData,
      // This file is the CONTEST's log, so the core exporter asks this
      // extension's `adifFields` hook and no other's — app-polo's main
      // handler (see `ExportRequest.mainHandler`).
      mainHandler: TYPE,
    })
    return {
      filename: filenameFor(operation, args.qsos, 'adi', args.compactFilenames),
      mimeType: 'text/plain',
      content,
    }
  },
}

export { isWveCall }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('activity', { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook('adifFields', { hook: AdifFieldsHook, key: TYPE })
    registerHook('export', { hook: ExportHook, key: TYPE })
    registerHook('scoring', {
      hook: contestScorer(ARRLDXScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
