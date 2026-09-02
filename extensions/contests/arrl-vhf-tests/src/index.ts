// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL VHF+ contests. Ported from app-polo's ARRLVHFContestsExtension.
//
// One extension, six named events (events.ts) sharing one ref type — the
// event key lives in the ref's own `ref` field, `{type: 'arrl-vhf-tests', ref:
// 'ARRL-222'}`, exactly as `stateparks` does for its four sponsors (§5.6).
//
// What it exercises that no other ported contest does: a typed GRID exchange
// (`kind: 'text'` with a Maidenhead-shape `pattern` — see exchange.ts for why
// this doesn't need a `grid` kind of its own) and great-circle distance
// scoring. "Our" grid is `operation.grid`, a plain operation field a rover
// changes per stint via a `break`/`start` segment override — already-shipped
// infra (docs/design/contests.md's segments model), not something this
// extension tracks itself.

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

import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"
import { EVENTS, eventFor, type VhfEvent } from "./events.ts"
import { gridPatternFor, guessedGrid, trimmedGrid } from "./exchange.ts"
import { tFor } from "./i18n.ts"
import { ARRLVHFScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'arrl-vhf-tests'

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

function eventOn(operation: Record<string, JSONValue> | undefined): VhfEvent | undefined {
  return eventFor(str(refOfType(operation ?? {}, TYPE)?.ref))
}

const ActivityHook = {
  /// One suggestion per event, so an operator finds "222 MHz" by name instead
  /// of enabling an extension and hunting through a dropdown (§5.6).
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

  /// The event picker — a `form`, not the `options` kind, per the same
  /// operation-settings rule `stateparks` documents: `activities_view.dart`
  /// renders only `refList` and `form` for operation controls.
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
        // The event key IS the ref's identity, so this writes `ref` — the one
        // core-owned key a setup form legitimately sets.
        key: 'ref',
        label: t('eventLabel'),
        value: currentKey || options[0]?.value,
        options,
      },
    ]

    return [
      {
        key: 'arrl-vhf-tests/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'form', refType: TYPE, form: { title: t('setupLabel'), elements } },
      },
    ]
  },

  /// The grid square the other station sends — the whole exchange. Off-event,
  /// contributes nothing: the core already refuses a primary field to an
  /// activity the operation isn't running, but skipping here also saves
  /// resolving a guess per refresh.
  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const event = eventOn(operation)
    if (!event) return []

    const t = tFor(ctx)
    const guess = guessedGrid((qso?.their as Record<string, JSONValue>) ?? {}, event)

    return [
      {
        key: 'arrl-vhf-tests/grid',
        label: t('gridLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'grid',
          maxLength: event.gridChars,
          pattern: gridPatternFor(event),
          placeholder: guess || undefined,
          suggestedValue: guess || undefined,
        },
      },
    ]
  },

  /// Mirrors the grid into `their.exchange`, the column the QSO list and
  /// generic exports read, and folds a full 6-character lookup grid
  /// down to what this event's exchange actually asks for.
  async processQsoBeforeSave(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    const event = eventOn(operation)
    if (!event) return null

    const qsoRef = refOfType(qso, TYPE)
    // PRESENCE, not truthiness — a present, empty `grid` is the operator
    // deliberately clearing what they'd typed, and has to survive as that
    // decision rather than be re-guessed on the next save (§5.4).
    const decided = qsoRef !== undefined && 'grid' in qsoRef
    const grid = decided
      ? trimmedGrid(str(qsoRef.grid), event)
      : guessedGrid((qso.their as Record<string, JSONValue>) ?? {}, event)

    // Our sent exchange is the operation's grid, the same on every QSO, so
    // it is not projected into `our.exchange` — the QSO row would repeat it
    // on every line; the exports read `operation.grid` directly.
    if (!grid) return decided ? { their: { exchange: '' } } : null

    return {
      refs: [{ type: TYPE, grid }],
      their: { exchange: grid },
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
    const grid = trimmedGrid(str(operation.grid), event)
    return { for: event.short, subtitle: grid ? tFor(ctx)('ourExchangeSubtitle', { grid }) : undefined }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    const event = eventFor(ref.ref)
    return event ? { url: event.rules, label: event.name } : null
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const event = eventOn(operation)
    if (!event) return []

    const ourGrid = trimmedGrid(str(operation.grid), event)
    const theirGrid = trimmedGrid(str(refOfType(qso, TYPE)?.grid), event)

    const fields: { name: string; value: string }[] = [
      { name: 'CONTEST_ID', value: event.cabrilloName ?? event.key },
    ]
    if (ourGrid) fields.push({ name: 'STX_STRING', value: ourGrid })
    if (theirGrid) fields.push({ name: 'SRX_STRING', value: theirGrid })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === 'CW' ? '599' : '59'
}

function contestTag(event: VhfEvent): string {
  return event.cabrilloName ?? event.key
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  event: VhfEvent,
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: contestTag(event),
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
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const event = eventOn(operation)
    if (!event) return { filename: '', mimeType: '', content: '' }
    const ourCall = str(operation.stationCall)
    const ourGrid = trimmedGrid(str(operation.grid), event)

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', contestTag(event)],
          ['CALLSIGN', ourCall],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', ourGrid],
        ],
        qsoParts: (qso) => {
          const theirGrid = trimmedGrid(str(refOfType(qso, TYPE)?.grid), event)
          return [
            ourCall || '-',
            reportFor(qso, 'our'),
            ourGrid || '-',
            str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
            reportFor(qso, 'their'),
            theirGrid || '-',
          ]
        },
      })
      return { filename: filenameFor(operation, args.qsos, event, 'log', args.compactFilenames), mimeType: 'text/plain', content }
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
      hook: contestScorer(ARRLVHFScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
