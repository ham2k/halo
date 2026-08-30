// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU Region 1 VHF+ contests. Ported from app-polo's
// Region1VHFContestsExtension.
//
// One extension, eight named events (events.ts) sharing one ref type — the
// event key lives in the ref's own `ref` field, `{type: 'r1-vhf-tests', ref:
// 'R1-VHF-145-SEPTEMBER'}`, exactly as arrl-vhf-tests does for its six.
//
// The exchange has two parts: an auto-allocated `kind: 'serial'` field (our
// number — cqwpx's exact pattern) and a typed 6-character grid, same shape
// arrl-vhf-tests already proved. `their` number has no placeholder to guess:
// there is nothing to know about a number the other station hasn't sent yet.

import { adifForExport, contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/extension-sdk"
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
} from "@ham2k/extension-sdk"

import { EVENTS, eventFor, type R1VhfEvent } from "./events.ts"
import { GRID_PATTERN, guessedGrid, trimmedGrid } from "./exchange.ts"
import { tFor } from "./i18n.ts"
import { REG1TEST_BAND, qsonToReg1test } from "./reg1test.ts"
import { refOfType, serial as serialFor, str } from "./refs.ts"
import { R1VHFScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'r1-vhf-tests'

function eventOn(operation: Record<string, JSONValue> | undefined): R1VhfEvent | undefined {
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
        key: 'r1-vhf-tests/setup',
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

    return [
      {
        key: 'r1-vhf-tests/ourSerial',
        label: t('ourSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'serial', refType: TYPE, field: 'ourSerial', sequence: { key: 'serial' } },
      },
      {
        key: 'r1-vhf-tests/theirSerial',
        label: t('theirSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: { kind: 'text', refType: TYPE, field: 'theirSerial', numeric: true, maxLength: 5 },
      },
      {
        key: 'r1-vhf-tests/grid',
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
  },

  /// Composes the two-part exchange ("042 IO91wo") into `their.exchange`/
  /// `our.exchange` — the columns the QSO list and generic ADIF export read —
  /// same as arrl-vhf-tests' single-part version, joined with a space.
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

    const theirExchange = [theirSerial, theirGrid].filter((x) => x).join(' ')
    const ourExchange = [ourSerial, ourGrid].filter((x) => x).join(' ')

    if (!theirExchange && !gridDecided) return null

    // Written whenever there's a grid to write, decided or guessed — a
    // guessed grid the operator never touched must still reach the ref, or
    // the scorer (which reads only the ref, never the guess) and the
    // REG1TEST export (WWL column) both silently treat the QSO as gridless.
    return {
      refs: theirGrid ? [{ type: TYPE, grid: theirGrid }] : [],
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
    return { url: 'https://www.iaru-r1.org/on-the-air/contests/', label: 'IARU Region 1 contests' }
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
  event: R1VhfEvent,
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
        exportType: 'r1-vhf-tests-reg1test',
        format: 'reg1test',
        label: t('reg1testExport', { contest: manifest.shortName }),
        filename: named('edi'),
        selectedByDefault: true,
        refType: TYPE,
      },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    if (args.exportType !== 'r1-vhf-tests-reg1test' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const event = eventOn(operation)
    if (!event) return { filename: '', mimeType: '', content: '' }

    if (args.exportType === 'r1-vhf-tests-reg1test') {
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
        qsoFields: (qso) => ({
          sequenceSent: serial(qso, 'ourSerial'),
          sequenceReceived: serial(qso, 'theirSerial'),
          wwlReceived: trimmedGrid(str(refOfType(qso, TYPE)?.grid)),
        }),
      })
      return { filename: filenameFor(operation, args.qsos, event, 'edi', args.compactFilenames), mimeType: 'text/plain', content }
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
      filename: filenameFor(operation, args.qsos, event, 'adi', args.compactFilenames),
      mimeType: 'text/plain',
      content,
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
      hook: contestScorer(R1VHFScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
