// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NRRL Nasjonal Field Day — the exchange, the setup, and the two exports.
// Norway's national field day, a sibling of `r1-fd` rather than a variant of
// it; `scorer.ts` opens with what actually differs.
//
// One running a year, so the ref's own `ref` field is just the year, the shape
// `fd` uses. That matters more here than usual: NFD shares its weekend with the
// IARU R1 SSB Field Day, so both extensions may sit on ONE operation and score
// it independently (docs/design/contests.md §5.1).

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
import { tFor } from "./i18n.ts"
import { nextRunningYear, relevanceFor } from "./schedule.ts"
import { NFDScorer, TYPE, nfdMode, refOfType } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const RULES_URL = 'https://nrrl.no/tema/field-day/regler-for-nasjonal-fieldday/'

/// What a search has to contain to offer this event. Matched as "does the
/// alias contain what was typed", so "fd" finds every field day and the date
/// ranking decides which comes first.
const ALIASES = ['NFD', 'NRRL', 'NASJONAL FIELD DAY', 'NASJONAL FIELDDAY', 'FIELD DAY', 'FIELDDAY', 'FD', 'NORWAY', 'NORGE']

/// The six main classes. The letter is how many operators, the digit is power
/// — so the class alone states both, and only stations in the same one compete.
const CLASSES = [
  { value: 'A1', labelKey: 'classA1' },
  { value: 'A2', labelKey: 'classA2' },
  { value: 'A3', labelKey: 'classA3' },
  { value: 'B1', labelKey: 'classB1' },
  { value: 'B2', labelKey: 'classB2' },
  { value: 'B3', labelKey: 'classB3' },
]

/// The shelter subcategory, which combines with the class into the entry's full
/// designation ("B2A"). A multi-station entry spread across several takes the
/// most substantial one it uses.
const SHELTERS = [
  { value: 'A', labelKey: 'shelterBuilding' },
  { value: 'B', labelKey: 'shelterCamping' },
  { value: 'C', labelKey: 'shelterTent' },
  { value: 'D', labelKey: 'shelterOutdoor' },
]

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

/// The exchange the other station sent, as it should appear in an export.
///
/// NOT coerced to digits, unlike every other serial-exchange contest here:
/// "ved bruk av digimode (FT-8, FT-4 osv.) logges rapport som er utvekslet
/// (f.eks. lokator og signalstyrke)", so on a digimode QSO this legitimately
/// holds a grid square. Parsing it as a number would blank exactly those.
function theirExchange(qso: Record<string, JSONValue>): string {
  const value = refOfType(qso, TYPE)?.theirSerial
  return typeof value === 'number' ? String(value) : str(value)
}

/// Ours is always a number — the core allocates it.
function ourSerial(qso: Record<string, JSONValue>): string {
  const value = refOfType(qso, TYPE)?.ourSerial
  if (typeof value === 'number') return String(value)
  const digits = str(value)
  return /^\d+$/.test(digits) ? String(parseInt(digits, 10)) : ''
}

/// The entry's full class designation, e.g. "B2A" — class plus shelter, which
/// is how NRRL names it on the summary sheet.
function classDesignation(ref: Record<string, JSONValue> | undefined): string {
  const cls = str(ref?.ourClass).toUpperCase()
  return cls ? `${cls}${str(ref?.ourShelter).toUpperCase()}` : ''
}

const ActivityHook = {
  /// Offered in the activity search by NAME and by NEARNESS. The date is a rule
  /// rather than a data file (`schedule.ts`), so this needs no download and is
  /// right for any year.
  async suggest({ searchTerm }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
    const t = tFor(ctx)
    const term = (searchTerm ?? '').trim().toUpperCase()
    if (term && !ALIASES.some((alias) => alias.includes(term))) return []

    const now = Date.now()
    // ONE source for which running this is — the label, the ref and the ranking
    // all read it.
    const year = nextRunningYear(now)

    return [
      {
        type: TYPE,
        // The picker's duplicate guard compares type+ref, and the setup form
        // writes the same key, so both add-paths produce a ref the core
        // recognises as the same activity.
        ref: String(year),
        // A suggestion is persisted VERBATIM and never runs through
        // `decorateRef`, so everything the operation row reads has to be here.
        program: 'Contest',
        name: t('activityDescription'),
        label: `${t('activityLabel')} ${year}`,
        shortLabel: `NFD ${year}`,
        relevance: relevanceFor(now),
      },
    ]
  },

  async operationControls(
    { operation }: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const currentYear = str(refOfType(operation, TYPE)?.ref)

    const elements: FormElement[] = [
      // The RUNNING this setup is for, and the ref's identity.
      //
      // `ref` is the one core-owned key a setup form legitimately sets. Without
      // it the form writes `ref: null` while `suggest` writes the year — so the
      // picker's duplicate guard never matches, and adding from the search
      // REPLACES a configured setup with a bare ref, silently losing the class
      // and every bonus.
      {
        type: 'field',
        fieldType: 'text',
        key: 'ref',
        label: t('runningLabel'),
        value: currentYear || String(nextRunningYear(Date.now())),
      },
      {
        type: 'field',
        fieldType: 'select',
        key: 'ourClass',
        label: t('classLabel'),
        options: CLASSES.map((c) => ({ value: c.value, label: t(c.labelKey) })),
      },
      {
        type: 'field',
        fieldType: 'select',
        key: 'ourShelter',
        label: t('shelterLabel'),
        options: SHELTERS.map((s) => ({ value: s.value, label: t(s.labelKey) })),
      },

      { type: 'header', title: t('bonusesHeader') },
      // HaLo totals these; it does not submit them, and NRRL adjudicates every
      // one against documentation on the summary sheet. Worth saying, because a
      // score that already counts them reads as though they were granted.
      { type: 'markdown', text: t('bonusesNote') },
      {
        type: 'field',
        fieldType: 'number',
        key: 'bonusRecruits1h',
        label: t('bonusRecruits1h'),
      },
      {
        type: 'field',
        fieldType: 'number',
        key: 'bonusRecruits6h',
        label: t('bonusRecruits6h'),
      },
      { type: 'field', fieldType: 'checkbox', key: 'bonusPublicActivity', label: t('bonusPublicActivity') },
      { type: 'field', fieldType: 'checkbox', key: 'bonusOrienteering', label: t('bonusOrienteering') },
      // Counts of OUTLETS, not of articles: each newspaper, radio channel and
      // TV channel is worth 10,000 once, however often it covered the event.
      { type: 'field', fieldType: 'number', key: 'bonusNewspapers', label: t('bonusNewspapers') },
      { type: 'field', fieldType: 'number', key: 'bonusRadioChannels', label: t('bonusRadioChannels') },
      { type: 'field', fieldType: 'number', key: 'bonusTvChannels', label: t('bonusTvChannels') },
      { type: 'field', fieldType: 'checkbox', key: 'bonusYoutubeVideo', label: t('bonusYoutubeVideo') },
      { type: 'field', fieldType: 'number', key: 'bonusYoutubeLikes', label: t('bonusYoutubeLikes') },
      { type: 'field', fieldType: 'checkbox', key: 'bonusLocation', label: t('bonusLocation') },
      { type: 'field', fieldType: 'checkbox', key: 'bonusReport', label: t('bonusReport') },
      { type: 'markdown', text: t('rulesLink', { url: RULES_URL }) },
    ]

    return [
      {
        key: 'nrrl-nfd/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'form', refType: TYPE, form: { title: t('setupLabel'), elements } },
      },
    ]
  },

  /// Two fields per QSO: the number we send and what they send back.
  ///
  /// Ours is a `serial` input — the extension names the sequence and the core
  /// fills the field. One flat series: "hver sender kan ha sin egen serie,
  /// uavhengig av bånd og mode", so no per-band or per-mode `scope`.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing — saves the work on every refresh; the
    // core refuses the primary field to an activity the operation isn't running
    // anyway.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    return [
      {
        key: 'nrrl-nfd/ourSerial',
        label: t('ourSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'serial',
          refType: TYPE,
          field: 'ourSerial',
          // "serienummer som starter med 001" — padded for display only; the
          // value stays an integer.
          sequence: { key: 'serial', padTo: 3 },
        },
      },
      {
        key: 'nrrl-nfd/theirSerial',
        label: t('theirSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'theirSerial',
          // Deliberately NOT `numeric`, unlike every other serial contest here:
          // a digimode QSO logs the exchange that actually passed, which is a
          // locator and a report rather than a serial. Six characters fits both
          // a long serial and a grid square.
          maxLength: 6,
          uppercase: true,
        },
      },
    ]
  },

  /// Mirrors the exchange this contest keeps on its own ref into the generic
  /// `their.exchange` — nothing outside this extension knows to look inside a
  /// contest ref, so without this the QSO row's exchange column and a plain
  /// ADIF export both come up empty. Only ever a projection: the ref stays the
  /// source of truth.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null
    const qsoRef = refOfType(args.qso, TYPE)
    const exchange = theirExchange(args.qso)
    // A field the operator EMPTIED is present-but-blank rather than absent.
    // Returning null there would leave the previous save's `their.exchange`
    // showing, so a cleared exchange has to project the blank.
    if (!exchange) return qsoRef && 'theirSerial' in qsoRef ? { their: { exchange: '' } } : null
    return { their: { exchange } }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? '').trim() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const year = str(ref.ref as JSONValue)
    const designation = classDesignation(ref as Record<string, JSONValue>)
    // Display keys split the event from the exchange (contests.md §5.4):
    // `label` names the event in full, `shortLabel` the same event abbreviated
    // for the cramped surfaces, and `name` the row's second line — which is
    // where the entry's own class belongs.
    return {
      ...ref,
      program: 'Contest',
      name: designation || t('activityDescription'),
      label: [t('activityLabel'), year].filter((part) => part).join(' '),
      shortLabel: ['NFD', year].filter((part) => part).join(' '),
    }
  },

  async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
    const designation = classDesignation(ref as Record<string, JSONValue>)
    return { for: 'NFD', subtitle: designation || undefined }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: RULES_URL, label: 'NRRL Nasjonal Field Day' }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    if (!refOfType(operation, TYPE)) return []

    const fields: { name: string; value: string }[] = [
      { name: 'CONTEST_ID', value: 'NRRL-NFD' },
    ]
    const sent = ourSerial(qso)
    const received = theirExchange(qso)
    if (sent) fields.push({ name: 'STX', value: sent })
    // STX is the numeric serial field; the received side may be a locator on a
    // digimode QSO, so it goes in the string one.
    if (received) fields.push({ name: 'SRX_STRING', value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return nfdMode(str(qso.mode)) === 'SSB' ? '59' : '599'
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: 'NRRL-NFD',
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

  async generateExport(args: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes offered above — a hook that answers for an
    // exportType it never offered makes the ADIF delegation recurse into
    // itself.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const ourCall = str(operation.stationCall)

    if (args.exportType === 'cabrillo') {
      const cls = str(opRef?.ourClass).toUpperCase()
      const designation = classDesignation(opRef)
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          // NFD has no REGISTERED Cabrillo contest name — NRRL asks for "en ren
          // Cabrillo-fil" and reads it with their own Field Day Manager — so
          // this is a descriptive identifier rather than one a checker knows.
          ['CONTEST', 'NRRL-NFD'],
          ['CALLSIGN', ourCall],
          // Only the parts of the class that Cabrillo has fields for: the
          // letter is how many operators, the digit is the power bracket.
          ['CATEGORY-OPERATOR', cls.startsWith('A') ? 'MULTI-OP' : cls.startsWith('B') ? 'SINGLE-OP' : ''],
          ['CATEGORY-POWER', cls.endsWith('1') ? 'HIGH' : cls.endsWith('2') ? 'LOW' : cls.endsWith('3') ? 'QRP' : ''],
          // Always: NFD is portable-only, mains power forbidden.
          ['CATEGORY-STATION', 'PORTABLE'],
          ['CATEGORY-MODE', 'MIXED'],
          ['LOCATION', str(operation.grid)],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
          // The shelter subcategory has no Cabrillo field at all, so the full
          // NFD designation goes here — which is what NRRL's own contest
          // guidance suggests for the A–D class.
          ['SOAPBOX', designation ? `NFD class ${designation}` : ''],
        ],
        qsoParts: (qso) => [
          ourCall || '-',
          reportFor(qso, 'our'),
          ourSerial(qso) || '0',
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
          reportFor(qso, 'their'),
          theirExchange(qso) || '0',
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
      // extension's `adifFields` hook and no other's.
      mainHandler: TYPE,
    })
    return {
      filename: filenameFor(operation, args.qsos, 'adi', args.compactFilenames),
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
      hook: contestScorer(NFDScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
