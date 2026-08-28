// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CQ World Wide DX Contest. Ported from app-polo's CQWWExtension.
//
// What it exercises that simple-contest doesn't: a validated numeric
// exchange, and per-band
// multipliers accumulated from two different axes (zone and country).

import { contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/halo-extension-sdk"
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
} from "@ham2k/halo-extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"
import { tFor } from "./i18n.ts"
import { CQWWScorer, ZONE_PATTERN, normalizeZone } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'cqww'

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// Our own zone: whatever was set at setup, else the country file's answer for
/// our station call — right for the great majority of operators, and better
/// than exporting an empty exchange.
function ourZone(operation: Record<string, JSONValue>): string {
  const configured = normalizeZone(refOfType(operation, TYPE)?.zone)
  if (configured) return configured
  return normalizeZone(annotateCallAgainstCountryFile(str(operation.stationCall)).cqZone)
}

const ActivityHook = {
  async operationControls(
    _args: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    return [
      {
        key: 'cqww/setup',
        // Named for the contest family — this is what the Activity Types list
        // shows, where "Setup" would read as a settings screen rather than the
        // thing you're adding to the operation.
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
                // CQ WW runs these as separate contests on separate weekends.
                options: [{ value: 'CW', label: 'CW' }, { value: 'SSB', label: 'SSB' }, { value: 'RTTY', label: 'RTTY' }],
              },
              {
                type: 'field',
                fieldType: 'text',
                key: 'zone',
                label: t('ourZoneLabel'),
                placeholder: t('ourZonePlaceholder'),
              },
            ],
          },
        },
      },
    ]
  },

  /// The one field typed per QSO. The country file resolves a zone for most
  /// callsigns offline, so it's offered as a suggestion the operator can
  /// correct — a station may be operating away from its callsign's zone.
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

    const their = ((args.qso?.their as Record<string, JSONValue>) ?? {})
    const guess = (their.guess as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    const suggested =
      normalizeZone(guess.cqZone) || (call ? normalizeZone(annotateCallAgainstCountryFile(call).cqZone) : '')

    return [
      {
        key: 'cqww/zone',
        label: tFor(ctx)('zoneLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'theirZone',
          numeric: true,
          maxLength: 3,
          pattern: ZONE_PATTERN,
          // Only ever the guessed zone for THIS callsign — never a format
          // hint like "1-40", which reads as a real value at a glance.
          placeholder: suggested || undefined,
          // Filled in for the operator, but never over something they typed.
          suggestedValue: suggested || undefined,
        },
      },
    ]
  },

  /// Records the zone they sent, and mirrors it where the rest of the app can
  /// see it.
  ///
  /// When the operator typed nothing, the country file's zone for that call is
  /// written onto the ref as DATA OF RECORD (docs/design/contests.md §8). The
  /// scorer already falls back to the same value, so without this a QSO could
  /// earn a zone multiplier and then export a dash — the log disagreeing with
  /// its own score. The logging control's `suggestedValue` fills this in
  /// whenever a lookup resolves; this covers the QSOs where none did.
  ///
  /// `their.exchange` is the projection on top: nothing outside this extension
  /// knows to look inside a contest ref, so without it the QSO row's exchange
  /// column and a plain (non-contest) ADIF export both come up empty.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null

    const their = ((args.qso.their as Record<string, JSONValue>) ?? {})
    const guess = (their.guess as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    const qsoRef = refOfType(args.qso, TYPE)

    // PRESENCE of the field, not its truthiness. The core writes `theirZone: ''`
    // when the operator empties the field on purpose, and drops the key
    // entirely when it was simply never filled in — so a present key, blank or
    // not, is a decision, and guessing over it would put back what they just
    // removed.
    const exchange = qsoRef && 'theirZone' in qsoRef
      ? normalizeZone(qsoRef.theirZone)
      : normalizeZone(guess.cqZone) || (call ? normalizeZone(annotateCallAgainstCountryFile(call).cqZone) : '')

    // A deliberate blank still projects, so clearing an exchange on an edit
    // clears the QSO row's column too instead of leaving the old value there.
    if (!exchange) {
      return qsoRef && 'theirZone' in qsoRef ? { their: { exchange: '' } } : null
    }

    return {
      // Field-wise into our own ref; the core allows this extension no other.
      refs: [{ type: TYPE, theirZone: exchange }],
      their: { exchange },
    }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? '').trim() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const label = mode ? `CQ WW ${mode}` : tFor(ctx)('unconfigured')
    const zone = normalizeZone((ref as Record<string, JSONValue>).zone)
    const t = tFor(ctx)
    // `ourZoneSubtitle`, not a hardcoded `Zone ${zone}`: the two halves of
    // this line have to speak the same language, and the key already exists
    // for `suggestOperationTitle`.
    return { ...ref, program: 'Contest', label, shortLabel: label, name: zone ? t('ourZoneSubtitle', { zone }) : t('notConfigured') }
  },

  /// "KI2D for CQWW CW" with "Zone 8" beneath it: the sent exchange is the one
  /// thing an operator re-reads constantly during a contest, so it goes in the
  /// subtitle rather than being buried in setup.
  async suggestOperationTitle(
    { ref, operation }: { ref: Ref; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ) {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const zone = ourZone(operation)
    return {
      for: ['CQWW', mode].filter((x) => x).join(' '),
      subtitle: zone ? tFor(ctx)('ourZoneSubtitle', { zone }) : undefined,
    }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: 'https://www.cqww.com/rules.htm', label: 'CQ WW' }
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
      { name: 'CONTEST_ID', value: mode ? `CQ-WW-${mode}` : 'CQ-WW' },
    ]
    const sent = ourZone(operation)
    const received = normalizeZone(refOfType(qso, TYPE)?.theirZone)
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

/// The contest's own name for this operation's file — the mode is part of
/// the identity here, since CQ WW CW and CQ WW SSB are separate contests
/// with separate submissions.
function contestTag(operation: Record<string, JSONValue>): string {
  const mode = str(refOfType(operation, TYPE)?.mode)
  return `CQ-WW-${mode || 'DX'}`
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
    // braces alongside the keyed `invokeOne` below: a hook that answers for an
    // exportType it never offered makes the ADIF delegation recurse into
    // itself.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const mode = str(refOfType(operation, TYPE)?.mode)
    const ourCall = str(operation.stationCall)
    const sentZone = ourZone(operation)

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', mode ? `CQ-WW-${mode}` : 'CQ-WW'],
          ['CALLSIGN', ourCall],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => [
          ourCall || '-',
          reportFor(qso, 'our'),
          sentZone || '-',
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
          reportFor(qso, 'their'),
          normalizeZone(refOfType(qso, TYPE)?.theirZone) || '-',
        ],
      })
      return {
        filename: filenameFor(operation, args.qsos, 'log', args.compactFilenames),
        mimeType: 'text/plain',
        content,
      }
    }

    const { hooks } = await import("@ham2k/halo-extension-sdk")
    // invokeOne, NOT invokeAll: the fan-out includes this contest's own
    // `generateExport`, which would take the same ADIF branch and delegate
    // again — unbounded recursion.
    const entries = await hooks.invokeOne('export', 'adif', 'generateExport', {
      operation: args.operation,
      qsos: args.qsos,
      exportType: 'adif',
      // Forwarded, or the delegate defaults to withholding and the user's
      // "include private info" setting silently does nothing here.
      includePrivateData: args.includePrivateData,
    })
    const adif = entries.find((e) => e.ok)
    return {
      filename: filenameFor(operation, args.qsos, 'adi', args.compactFilenames),
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
      hook: contestScorer(CQWWScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
