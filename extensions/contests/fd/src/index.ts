// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL Field Day — the exchange, the setup, and the two exports.
//
// A near-duplicate of `wfd` by choice, not by accident: see `scorer.ts`.
//
// The exchange is a class and a section, and the section is the case
// `kind: 'options'` was built for (docs/design/contests.md §5.3) — 86 known
// codes with names, searchable, Space to accept the top hit. app-polo hand-rolls
// a suggestions list here; HaLo already has the control.

import {
  contestScorer,
  defineExtension,
} from "@ham2k/halo-extension-sdk"
import type {
  ActivitySuggestion,
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  SuggestArgs,
  TitleSuggestion,
} from "@ham2k/halo-extension-sdk"

// The Cabrillo writer every contest here shares — `@ham2k/lib-qson-cabrillo`
// has no writer, so it was ported into `simple-contest` and imported from
// there. `fd` and `wfd` keep their own copies of everything ELSE, but the
// writer is the codebase's one Cabrillo implementation and forking it per
// contest would be a different decision from separating these two.
import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"

import { ALL_SECTIONS, CALL_AREA_FOR_SECTION, PREFIX_TO_LOCATION } from "./sections.ts"
import { CLAIMED_BONUS_KEYS, CLASS_REGEX, FDScorer, TYPE, refOfType } from "./scorer.ts"
import { nextRunningYear, relevanceFor } from "./schedule.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

/// Every section as a selectable option, with its name — what the operator
/// searches. Built once: the list is static and 86 long.
/// What a search has to contain to offer this event. Matched as "does the
/// alias contain what was typed", so "fd" finds both Field Days — they are both
/// field days, and the date ranking decides which comes first.
const ALIASES = ['FD', 'FIELD DAY', 'FIELDDAY', 'ARRL FIELD DAY', 'ARRL FD', 'ARRL']

/// Precomputed beside the option list: rebuilding both per keystroke costs
/// ~120 allocations and an 86-entry scan to answer a question that only
/// depends on one digit.
const PREFIX_ENTRIES = Object.entries(PREFIX_TO_LOCATION)

const SECTIONS_BY_CALL_AREA: Record<number, string[]> = (() => {
  const byArea: Record<number, string[]> = {}
  for (const [section, area] of Object.entries(CALL_AREA_FOR_SECTION)) {
    if (typeof area === 'number') (byArea[area] ??= []).push(section)
  }
  return byArea
})()

const SECTION_OPTIONS = Object.keys(ALL_SECTIONS)
  .sort()
  .map((code) => ({ code, name: ALL_SECTIONS[code] }))

/// Sections worth floating to the top for this callsign.
///
/// A prefix that names its section outright wins outright — KL7 is Alaska and
/// nothing else. Otherwise the US call area narrows 86 down to a handful.
///
/// GATED ON ENTITY, because a bare digit is not a US call area: VE3ABC and
/// G3ABC both contain a 3, and ranking Delaware first for an Ontario station
/// (whose four real codes then sit below it) is worse than ranking nothing.
/// app-polo gates the same way, returning DX for anything that is not K or VE.
///
/// This only RANKS: §5.3 asks for ranking rather than prefilling here, because
/// a guess from a callsign is wrong often enough to be annoying.
function preferredSections(call: string, entityPrefix: string): string[] {
  const upper = call.toUpperCase()
  for (const prefix of PREFIX_ENTRIES) {
    if (upper.startsWith(prefix[0])) return [prefix[1]]
  }
  // Canada has no single answer — Ontario alone is four sections — so offer
  // none rather than a wrong one. Anything outside K/VE sends DX.
  if (entityPrefix && entityPrefix !== 'K') return []
  const digit = /[0-9]/.exec(upper)
  if (!digit) return []
  return SECTIONS_BY_CALL_AREA[Number(digit[0])] ?? []
}

const ActivityHook = {
  async operationControls(
    _args: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    return [
      {
        key: 'fd/setup',
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
              // The RUNNING this setup is for, and the ref's identity.
              //
              // `ref` is the one core-owned key a setup form legitimately sets
              // (`stateparks` does the same). Without it the form writes
              // `ref: null` while `suggest` writes the year — so the picker's
              // duplicate guard, which compares type+ref, never matches, and
              // adding from the search REPLACES a configured setup with a bare
              // ref, silently losing class, section, power and every bonus.
              {
                type: 'field',
                fieldType: 'text',
                key: 'ref',
                label: t('runningLabel'),
                value: String(nextRunningYear(Date.now())),
              },
              // `ourClass`/`ourSection`, not `class`/`location`: a form field key
              // IS a key on the ref, and the QSO ref uses `class`/`location` for
              // what the OTHER station sent. Sharing the names would have our
              // setup and their exchange overwrite each other.
              {
                type: 'field',
                fieldType: 'text',
                key: 'ourClass',
                label: t('ourClassLabel'),
                placeholder: t('ourClassPlaceholder'),
                uppercase: true,
              },
              {
                type: 'field',
                fieldType: 'text',
                key: 'ourSection',
                label: t('ourSectionLabel'),
                placeholder: t('ourSectionPlaceholder'),
                uppercase: true,
              },
              {
                type: 'field',
                fieldType: 'select',
                key: 'ourPower',
                label: t('ourPowerLabel'),
                options: [
                  { value: '5W', label: t('powerQrp') },
                  { value: '100W', label: t('powerQro') },
                  { value: '500W', label: t('powerHigh') },
                ],
              },
              {
                type: 'field',
                fieldType: 'select',
                key: 'ourPowerSource',
                label: t('ourPowerSourceLabel'),
                options: [
                  { value: 'BATTERIES', label: t('powerBatteries') },
                  { value: 'GENERATOR', label: t('powerGenerator') },
                ],
              },

              { type: 'header', title: t('bonusesHeader') },
              // HaLo totals these; it does not submit them. Worth saying, because
              // a score that already counts them reads as though it has.
              { type: 'markdown', text: t('bonusesNote') },
              {
                type: 'field',
                fieldType: 'number',
                key: 'bonusTransmitters',
                label: t('bonusTransmitters'),
              },
              {
                type: 'field',
                fieldType: 'checkbox',
                key: 'bonusEmergencyPower',
                label: t('bonusEmergencyPower'),
              },
              {
                type: 'field',
                fieldType: 'number',
                key: 'bonusNTSMessages',
                label: t('bonusNTSMessages'),
              },
              {
                type: 'field',
                fieldType: 'number',
                key: 'bonusGotaQsos',
                label: t('bonusGotaQsos'),
              },
              {
                type: 'field',
                fieldType: 'number',
                key: 'bonusYouthParticipants',
                label: t('bonusYouthParticipants'),
              },
              ...CLAIMED_BONUS_KEYS.map((key: string) => ({
                type: 'field' as const,
                fieldType: 'checkbox' as const,
                key,
                label: t(key),
              })),
              { type: 'markdown', text: t('rulesLink') },
            ],
          },
        },
      },
    ]
  },


  /// Offered in the activity search by NAME and by NEARNESS.
  ///
  /// The date is a rule rather than a data file (`schedule.ts`), so this needs
  /// no download and is right for any year. `relevance` only ORDERS the list,
  /// and only against other suggestions with no location — the picker sorts
  /// anything with a distance first, so a park 40km away still outranks a
  /// contest six months out.
  ///
  /// Typing "field day" finds BOTH events; whichever is nearer sorts first,
  /// which in June is one and in January the other.
  async suggest({ searchTerm }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
    const t = tFor(ctx)
    const term = (searchTerm ?? '').trim().toUpperCase()
    if (term && !ALIASES.some((alias) => alias.includes(term))) return []

    const now = Date.now()
    // ONE source for which running this is — the label, the ref and the ranking
    // all read it. Deriving it separately in here lets the suggestion
    // advertise next year's running while ranking it as if it were on the air.
    const year = nextRunningYear(now)

    return [
      {
        type: TYPE,
        // The YEAR of the running. The picker's duplicate guard compares
        // type+ref, and the setup form writes the same key, so both add-paths
        // produce a ref the core recognises as the same activity.
        ref: String(year),
        // A suggestion is persisted VERBATIM and never runs through
        // `decorateRef`, so everything the operation row reads has to be
        // here. No `name`: the row leads with `label`, and the second line
        // is for the exchange once the operator configures one.
        program: 'Contest',
        label: `${t('activityLabel')} ${year}`,
        // Must match what `decorateRef` composes: the same running added by
        // tapping this suggestion and by the setup form has to read the same
        // on every surface.
        shortLabel: `FD ${year}`,
        relevance: relevanceFor(now),
      },
    ]
  },

  /// Writes the exchange onto the QSO as data of record.
  ///
  /// Every other contest here implements this, and the log's exchange column
  /// reads `their.exchange` — without it a Field Day log shows nothing for what
  /// each station sent, which is exactly what an operator scrolls back to check.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null

    const qsoRef = refOfType(args.qso, TYPE)
    const exchange = [str(qsoRef?.class), str(qsoRef?.location)].filter((part) => part).join(' ')
    if (!exchange) return null

    const their = ((args.qso.their as Record<string, JSONValue>) ?? {})
    return { their: { ...their, exchange } as unknown as JSONValue }
  },

  /// Two fields per QSO, both writing to the same ref, which the core folds
  /// together — the shape `naqp` established.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing. The core already refuses a primary field
    // to an activity the operation isn't running; this saves the work.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    const their = (args.qso?.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    // The country the callsign belongs to, as the lookup resolved it.
    const entityPrefix = str(their.entityPrefix) || str((their.guess as Record<string, JSONValue>)?.entityPrefix)

    return [
      {
        key: 'fd/class',
        label: t('theirClassLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'class',
          placeholder: t('ourClassPlaceholder'),
          uppercase: true,
          // Tints when it isn't a class. `PC` is part of the pattern rather than
          // an exception to it — a station asking you to copy the bulletin sends
          // `PC1A`, and refusing that would refuse a legal exchange.
          pattern: CLASS_REGEX.source,
        },
      },
      {
        key: 'fd/section',
        label: t('theirSectionLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: 'options',
          refType: TYPE,
          field: 'location',
          options: SECTION_OPTIONS,
          preferredCodes: preferredSections(call, entityPrefix),
          // `MX` and `DX` are legal to receive and are not in the list, so an
          // unknown value has to be acceptable. They score; they just aren't
          // sections.
          allowFreeform: true,
          uppercase: true,
          minCharsForSuggestions: 1,
        },
      },
    ]
  },
}

const RefHandler = {
  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const own = [str((ref as Record<string, JSONValue>).ourClass), str((ref as Record<string, JSONValue>).ourSection)]
      .filter((part) => part)
      .join(' ')
    const year = str((ref as Record<string, JSONValue>).ref)
    // Display keys split the event from the exchange (contests.md §5.4):
    // `label` names the event in full, `shortLabel` names the SAME event
    // abbreviated, for the cramped surfaces that show only it —
    // the information panel's heading and the location screen's tile — and
    // `name` for the row's second line, which is where the exchange belongs.
    // A `shortLabel` of "3A ENY" leaves those surfaces with no clue which
    // contest they are showing.
    return {
      ...ref,
      // Every other contest sets this here, and the QSO list needs it: it is
      // the signal that survives the extension being switched off, when there
      // is no control left to infer a contest from. A ref built by the setup
      // form never passes through `suggest`, so without this it has none.
      program: 'Contest',
      name: own || undefined,
      label: [t('activityLabel'), year].filter((part) => part).join(' '),
      shortLabel: ['FD', year].filter((part) => part).join(' '),
    }
  },

  async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
    const own = [str((ref as Record<string, JSONValue>).ourClass), str((ref as Record<string, JSONValue>).ourSection)]
      .filter((part) => part)
      .join(' ')
    return { for: 'FD', subtitle: own || undefined }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    // Keyed off the OPERATION, not the QSO: every contact made during a Field
    // Day operation is a Field Day contact, whether or not the operator got an
    // exchange down for it. app-polo writes these even when FD is not the main
    // handler for the QSO, and HaLo fans `adifFields` out to every hook anyway.
    if (!refOfType(operation, TYPE)) return []

    const qsoRef = refOfType(qso, TYPE)
    const fields = [{ name: 'CONTEST_ID', value: 'ARRL-FIELD-DAY' }]
    const theirClass = str(qsoRef?.class).toUpperCase()
    const theirSection = str(qsoRef?.location).toUpperCase()
    if (theirClass) fields.push({ name: 'CLASS', value: theirClass })
    if (theirSection) fields.push({ name: 'ARRL_SECT', value: theirSection })
    return fields
  },
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    if (!refOfType(args.operation, TYPE)) return []
    const t = tFor(ctx)
    return [
      { exportType: 'contest-adif', format: 'adif', label: t('adifExport'), selectedByDefault: true, refType: TYPE },
      { exportType: 'cabrillo', format: 'cabrillo', label: t('cabrilloExport'), selectedByDefault: true, refType: TYPE },
    ]
  },

  async generateExport(args: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    // Only the two offered above — a hook answering for an exportType it never
    // offered makes the ADIF delegation recurse into itself.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const ourCall = str(operation.stationCall)
    const ourClass = str(opRef?.ourClass).toUpperCase()
    const ourSection = str(opRef?.ourSection).toUpperCase()
    const stamp = `FD-${ourCall || 'log'}`.replace(/[^A-Za-z0-9_-]+/g, '-')

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          // The registered CABRILLO name, which is not the ADIF CONTEST_ID
          // used above — a checker does not recognise 'ARRL-FIELD-DAY' here.
          ['CONTEST', 'ARRL-FD'],
          ['CALLSIGN', ourCall],
          ['LOCATION', ourSection],
          ['NAME', ''],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => {
          const qsoRef = refOfType(qso, TYPE)
          return [
            ourCall || '-',
            ourClass || '-',
            ourSection || '-',
            str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
            str(qsoRef?.class).toUpperCase() || '-',
            str(qsoRef?.location).toUpperCase() || '-',
          ]
        },
      })
      return { filename: `${stamp}.log`, mimeType: 'text/plain', content }
    }

    const { hooks } = await import("@ham2k/halo-extension-sdk")
    // invokeOne, NOT invokeAll: the fan-out includes this contest's own
    // `generateExport`, which would take this same branch and delegate again.
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
      hook: contestScorer(FDScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
