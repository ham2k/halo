// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// RSGB VHF+ contests. Ported from app-polo's RSGBVHFContestsExtension.
//
// 124 named events (events.ts) sharing one ref type, same shape
// r1-vhf-tests already proved — a two-part exchange (auto-allocated serial +
// 6-character grid) plus, for the five "Backpackers" events, a third
// district field (`hasDistrictExchange`) that also unlocks scorer.ts's
// grid/district/DXCC bonuses. `reg1test.ts` is r1-vhf-tests' writer, not a
// copy — both extensions submit the same format.
//
// Deliberately not ported: the class/section (`PSect`) picker polo's setup
// form shows. It narrows which RSGB_CLASSES code is valid for a given event
// and writes a REG1TEST header field competition software reads for
// category — real, but not required for a working export, and the
// ~50-entry class table plus its per-event `classes` restriction is its own
// increment on top of the exchange/scoring/writer core this port proves.

import { contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/halo-extension-sdk"
import type {
  ActivitySuggestion,
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  FormElement,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  RefLink,
  SuggestArgs,
  TitleSuggestion,
} from "@ham2k/halo-extension-sdk"

import { EVENTS, eventFor, hasDistrictExchange, type RsgbVhfEvent } from "./events.ts"
import { GRID_PATTERN, guessedGrid, trimmedGrid } from "./exchange.ts"
import { tFor } from "./i18n.ts"
import { REG1TEST_BAND, qsonToReg1test } from "../../r1-vhf-tests/src/reg1test.ts"
import { refOfType, serial as serialFor, str } from "../../r1-vhf-tests/src/refs.ts"
import { RSGBVHFScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'rsgb-vhf-tests'

function eventOn(operation: Record<string, JSONValue> | undefined): RsgbVhfEvent | undefined {
  return eventFor(str(refOfType(operation ?? {}, TYPE)?.ref))
}

function serial(qso: Record<string, JSONValue>, field: string): string {
  return serialFor(qso, TYPE, field)
}

const ActivityHook = {
  async suggest({ searchTerm }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
    const term = (searchTerm ?? '').trim().toUpperCase()
    return EVENTS
      .filter((event) => !term
        || event.key.includes(term)
        || event.name.toUpperCase().includes(term)
        || event.short.toUpperCase().includes(term))
      .map((event) => ({
        type: TYPE,
        ref: event.key,
        name: event.name,
        program: 'Contest',
        label: event.name,
        shortLabel: event.short,
      }))
  },

  async operationControls(
    { operation }: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const currentKey = str(refOfType(operation, TYPE)?.ref)
    const options = EVENTS.map((event) => ({ value: event.key, label: event.name }))
    if (currentKey && !eventFor(currentKey)) {
      options.unshift({ value: currentKey, label: currentKey })
    }

    const elements: FormElement[] = [
      {
        type: 'field',
        fieldType: 'select',
        key: 'ref',
        label: t('eventLabel'),
        value: currentKey || options[0]?.value,
        options,
      },
    ]

    return [
      {
        key: 'rsgb-vhf-tests/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'form', refType: TYPE, form: { title: t('setupLabel'), elements } },
      },
    ]
  },

  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const event = eventOn(operation)
    if (!event) return []

    const t = tFor(ctx)
    const guess = guessedGrid((qso?.their as Record<string, JSONValue>) ?? {})

    const controls: LoggingControlDescriptor[] = [
      {
        key: 'rsgb-vhf-tests/ourSerial',
        label: t('ourSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'serial', refType: TYPE, field: 'ourSerial', sequence: { key: 'serial' } },
      },
      {
        key: 'rsgb-vhf-tests/theirSerial',
        label: t('theirSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: { kind: 'text', refType: TYPE, field: 'theirSerial', numeric: true, maxLength: 5 },
      },
      {
        key: 'rsgb-vhf-tests/grid',
        label: t('gridLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 30,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'grid',
          maxLength: 6,
          pattern: GRID_PATTERN,
          placeholder: guess || undefined,
          suggestedValue: guess || undefined,
        },
      },
    ]

    if (hasDistrictExchange(event)) {
      controls.push({
        key: 'rsgb-vhf-tests/district',
        label: t('districtLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 40,
        input: { kind: 'text', refType: TYPE, field: 'location', maxLength: 2 },
      })
    }

    return controls
  },

  /// Composes the exchange ("042 IO91wo" or, with a district, "042 IO91wo
  /// AB") into `their.exchange`/`our.exchange` — same as r1-vhf-tests.
  async processQsoBeforeSave(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    const event = eventOn(operation)
    if (!event) return null

    const qsoRef = refOfType(qso, TYPE)
    const gridDecided = qsoRef !== undefined && 'grid' in qsoRef
    const theirGrid = gridDecided
      ? trimmedGrid(str(qsoRef.grid))
      : guessedGrid((qso.their as Record<string, JSONValue>) ?? {})
    const ourGrid = trimmedGrid(str(operation.grid))
    const theirSerial = serial(qso, 'theirSerial')
    const ourSerial = serial(qso, 'ourSerial')
    const district = hasDistrictExchange(event) ? str(qsoRef?.location).toUpperCase() : ''

    const theirExchange = [theirSerial, theirGrid, district].filter((x) => x).join(' ')
    const ourExchange = [ourSerial, ourGrid].filter((x) => x).join(' ')

    if (!theirExchange && !gridDecided) return null

    // Written whenever there's a grid to write, decided or guessed — a
    // guessed grid the operator never touched must still reach the ref, or
    // the scorer (which reads only the ref, never the guess) and the
    // REG1TEST export (WWL column) both silently treat the QSO as gridless.
    return {
      refs: theirGrid ? [{ type: TYPE, grid: theirGrid, ...(district ? { location: district } : {}) }] : [],
      their: { exchange: theirExchange },
      our: { exchange: ourExchange },
    }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = (ref.ref ?? '').toUpperCase().trim()
    return { valid: eventFor(normalized) !== undefined, normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const event = eventFor(ref.ref)
    if (!event) return { ...ref, program: 'Contest', label: tFor(ctx)('unconfigured') }
    return { ...ref, ref: event.key, program: 'Contest', label: event.name, shortLabel: event.short, name: event.name }
  },

  async suggestOperationTitle(
    { ref, operation }: { ref: Ref; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<TitleSuggestion | null> {
    const event = eventFor(ref.ref)
    if (!event) return { for: manifest.shortName }
    const grid = trimmedGrid(str(operation.grid))
    return { for: event.short, subtitle: grid ? tFor(ctx)('ourExchangeSubtitle', { grid }) : undefined }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: 'https://www.rsgbcc.org/vhf/', label: 'RSGB VHF contests' }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const event = eventOn(operation)
    if (!event) return []

    const fields: { name: string; value: string }[] = [{ name: 'CONTEST_ID', value: event.key }]
    const our = str(((qso.our as Record<string, JSONValue>) ?? {}).exchange)
    const their = str(((qso.their as Record<string, JSONValue>) ?? {}).exchange)
    if (our) fields.push({ name: 'STX_STRING', value: our })
    if (their) fields.push({ name: 'SRX_STRING', value: their })
    return fields
  },
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  event: RsgbVhfEvent,
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: event.key,
    startAtMillis: startMillisOf(operation, qsos),
    extension,
    compact,
  })
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    const event = eventOn(args.operation)
    if (!event) return []
    const t = tFor(ctx)
    const named = (extension: string) => filenameFor(args.operation, args.qsos ?? [], event, extension, args.compactFilenames)
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
        exportType: 'rsgb-vhf-tests-reg1test',
        format: 'reg1test',
        label: t('reg1testExport', { contest: manifest.shortName }),
        filename: named('edi'),
        selectedByDefault: true,
        refType: TYPE,
      },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    if (args.exportType !== 'rsgb-vhf-tests-reg1test' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const event = eventOn(operation)
    if (!event) return { filename: '', mimeType: '', content: '' }

    if (args.exportType === 'rsgb-vhf-tests-reg1test') {
      const ourCall = str(operation.stationCall)
      const ourGrid = trimmedGrid(str(operation.grid))
      const content = qsonToReg1test(args.qsos, {
        headers: [
          ['PCall', ourCall],
          ['RCall', str(operation.operatorCall) || ourCall],
          ['PWWLo', ourGrid],
          ['PBand', event.bands.length === 1 ? REG1TEST_BAND[event.bands[0]] : undefined],
        ],
        remarks: str(operation.notes) || undefined,
        qsoFields: (qso) => {
          const qsoRef = refOfType(qso, TYPE)
          return {
            sequenceSent: serial(qso, 'ourSerial'),
            sequenceReceived: serial(qso, 'theirSerial'),
            exchangeReceived: hasDistrictExchange(event) ? str(qsoRef?.location).toUpperCase() : undefined,
            wwlReceived: trimmedGrid(str(qsoRef?.grid)),
          }
        },
      })
      return { filename: filenameFor(operation, args.qsos, event, 'edi', args.compactFilenames), mimeType: 'text/plain', content }
    }

    const { hooks } = await import("@ham2k/halo-extension-sdk")
    // invokeOne, NOT invokeAll: the fan-out includes this contest's own
    // `generateExport`, which would take the same ADIF branch and delegate
    // again — unbounded recursion.
    const entries = await hooks.invokeOne('export', 'adif', 'generateExport', {
      operation: args.operation,
      qsos: args.qsos,
      exportType: 'adif',
      includePrivateData: args.includePrivateData,
    })
    const adif = entries.find((e) => e.ok)
    return {
      filename: filenameFor(operation, args.qsos, event, 'adi', args.compactFilenames),
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
      hook: contestScorer(RSGBVHFScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
