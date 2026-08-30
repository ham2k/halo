// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CWops CWT — the weekly one-hour mini-tests. Net-new here: app-polo has no
// CWT extension to port from.
//
// What it does that no other contest here does: a reference names an
// OCCURRENCE rather than an event (`{type: 'cwt', ref: '2026-08-26-1300'}`),
// because four separate contests run every week and each is entered and scored
// on its own. schedule.ts computes them from the sponsor's published rule.
//
// And, following from that, it is the only contest that stays OUT of the
// picker's unprompted list most of the time. A weekly event that always
// offered itself would sit at the top of that list six days out of seven; it
// appears three hours before a session and until an hour after it ends
// (`sessionAtHand`). Searching for it, or scoping the picker to this extension
// — a `SuggestArgs.scoped` call — still offers the next four sessions on any
// day, so setting one up in advance is never blocked.

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
import {
  NUMBER_PATTERN,
  firstName,
  guessedName,
  guessedQth,
  normalizeNumber,
  ourExchange,
} from "./exchange.ts"
import {
  type CwtSession,
  relevanceFor,
  sessionAtHand,
  sessionDateLabel,
  sessionFor,
  sessionShortLabel,
  sessionsFrom,
} from "./schedule.ts"
import { CWTScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'cwt'

/// The ADIF `Contest_ID` enumeration's own name for this event — "CWOPS-CWT |
/// CWops Mini-CWT Test". A plain `CWOPS` is not in the list (that is the
/// sponsor, not the contest), and an importer would not recognize the file.
const CONTEST_TAG = 'CWOPS-CWT'

/// How many sessions a search or a scoped picker offers.
const SESSIONS_OFFERED = 4

/// What a search has to be a prefix of to offer this contest. Matched as "does
/// the alias contain what was typed", the same rule `fd` uses.
const ALIASES = ['CWT', 'CWOPS', 'CWOPS CWT', 'MINI-TEST', 'MINITEST']

/// The classes CWops asks operators to report, and the `CATEGORY-POWER` value
/// each becomes in a Cabrillo header.
const POWER_CLASSES: { value: string; cabrillo: string; watts: string }[] = [
  { value: 'QRP', cabrillo: 'QRP', watts: '≤5W' },
  { value: 'LP', cabrillo: 'LOW', watts: '≤100W' },
  { value: 'HP', cabrillo: 'HIGH', watts: '>100W' },
]

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

function sessionOn(operation: Record<string, JSONValue> | undefined): CwtSession | undefined {
  return sessionFor(str(refOfType(operation ?? {}, TYPE)?.ref))
}

/// One picker row for a session. A suggestion is persisted VERBATIM and never
/// runs through `decorateRef`, so everything the operation row reads has to be
/// here — including `name`, the row's second line.
function suggestionFor(session: CwtSession, nowMillis: number, ctx: HookContext): ActivitySuggestion {
  return {
    type: TYPE,
    ref: session.key,
    name: `${sessionDateLabel(session)} · ${tFor(ctx)('sessionDescription')}`,
    program: 'Contest',
    label: sessionShortLabel(session),
    shortLabel: sessionShortLabel(session),
    relevance: relevanceFor(session, nowMillis),
  }
}

const ActivityHook = {
  /// The date rule, and the whole point of this extension's shape — see the
  /// file header.
  async suggest({ searchTerm, scoped }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
    const term = (searchTerm ?? '').trim().toUpperCase()
    const namesThisContest = !term || ALIASES.some((alias) => alias.includes(term))
    // Not ours, and nobody asked us in particular.
    if (!namesThisContest && !scoped) return []

    const now = Date.now()
    // Asked for BY NAME, or asked of this extension alone: the operator is
    // looking for a CWT, so the answer is which ones are coming up. Only the
    // unprompted list is gated on the day.
    if (term || scoped) {
      const sessions = sessionsFrom(now, SESSIONS_OFFERED)
      // Within a scope the rows are labelled "CWT 1300z", so `cwt: 1300` is an
      // operator narrowing the list, not one asking a question this extension
      // can't answer — it filters the sessions rather than emptying the panel.
      const matching = namesThisContest
        ? sessions
        : sessions.filter((session) => `${session.key} ${sessionShortLabel(session)}`.toUpperCase().includes(term))
      return matching.map((session) => suggestionFor(session, now, ctx))
    }

    const session = sessionAtHand(now)
    return session ? [suggestionFor(session, now, ctx)] : []
  },

  /// The setup form — a `form`, not `options`: `activities_view.dart` renders
  /// only `refList` and `form` for operation controls.
  async operationControls(
    { operation }: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const currentKey = str(refOfType(operation, TYPE)?.ref)
    const options = sessionsFrom(Date.now(), SESSIONS_OFFERED)
      .map((session) => ({ value: session.key, label: sessionDateLabel(session) }))
    // An operation opened weeks later names a session that has long since
    // dropped off the list; its own reference still has to be selectable, or
    // saving the form would silently move the log to another session.
    if (currentKey && !options.some((option) => option.value === currentKey)) {
      const known = sessionFor(currentKey)
      options.unshift({ value: currentKey, label: known ? sessionDateLabel(known) : currentKey })
    }

    const elements: FormElement[] = [
      {
        type: 'field',
        fieldType: 'select',
        // The session key IS the ref's identity, so this writes `ref` — the one
        // core-owned key a setup form legitimately sets.
        key: 'ref',
        label: t('sessionLabel'),
        value: currentKey || options[0]?.value,
        options,
      },
      // `ourName`/`ourNumber`, not `name`/`number`: a form field key IS a key
      // on the ref, and `name` is the slot `decorateRef` writes the activity
      // row's subtitle into.
      {
        type: 'field',
        fieldType: 'text',
        key: 'ourName',
        label: t('ourNameLabel'),
        placeholder: t('ourNamePlaceholder'),
        uppercase: true,
      },
      {
        type: 'field',
        fieldType: 'text',
        key: 'ourNumber',
        label: t('ourNumberLabel'),
        placeholder: t('ourNumberPlaceholder'),
        uppercase: true,
      },
      {
        type: 'field',
        fieldType: 'radio',
        key: 'power',
        label: t('powerLabel'),
        options: POWER_CLASSES.map((power) => ({ value: power.value, label: `${power.value} (${power.watts})` })),
      },
      { type: 'markdown', text: t('rulesLink') },
    ]

    return [
      {
        key: 'cwt/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'form', refType: TYPE, form: { title: t('setupLabel'), elements } },
      },
    ]
  },

  /// The two halves of the exchange. Off-contest, contribute nothing — an
  /// optimization, not the rule: the core already refuses a primary field to
  /// an activity the operation isn't running.
  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    if (!refOfType(operation, TYPE)) return []

    const t = tFor(ctx)
    const their = ((qso?.their as Record<string, JSONValue>) ?? {})
    const name = guessedName(their)
    const qth = guessedQth(their)

    return [
      {
        key: 'cwt/name',
        label: t('nameLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'name',
          maxLength: 12,
          uppercase: true,
          placeholder: name || undefined,
          suggestedValue: name || undefined,
        },
      },
      {
        key: 'cwt/number',
        label: t('numberLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: 'text',
          refType: TYPE,
          field: 'number',
          maxLength: 6,
          uppercase: true,
          pattern: NUMBER_PATTERN,
          // A HINT, never a suggested value — see `guessedQth`. Most CWT
          // participants are members sending a number, and pre-filling a state
          // would stamp the wrong exchange onto the majority of contacts.
          placeholder: qth || undefined,
        },
      },
    ]
  },

  /// Records what was received, and mirrors it where the rest of the app can
  /// see it (docs/design/contests.md §8).
  async processQsoBeforeSave(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(operation, TYPE)) return null

    const their = ((qso.their as Record<string, JSONValue>) ?? {})
    const qsoRef = refOfType(qso, TYPE)

    // PRESENCE of each field, not its truthiness. The core writes `field: ''`
    // when the operator empties one on purpose and drops the key entirely when
    // it was never filled in — so a present key, blank or not, is a decision,
    // and guessing over it would put back what they just removed.
    const nameDecided = qsoRef !== undefined && 'name' in qsoRef
    const numberDecided = qsoRef !== undefined && 'number' in qsoRef
    const name = nameDecided ? firstName(qsoRef.name) : guessedName(their)
    // The number is never guessed — only what the operator typed is recorded.
    const number = numberDecided ? normalizeNumber(qsoRef.number) : ''

    if (!name && !number) {
      // A deliberate blank still projects, so clearing an exchange on an edit
      // clears the QSO row's column too instead of leaving the old value there.
      return nameDecided || numberDecided ? { their: { exchange: '' } } : null
    }

    // Only the halves that carry something or that the operator already
    // decided: an object literal would stamp `number: ''` onto every QSO, which
    // the presence rule above then reads back forever as "emptied on purpose".
    const refPatch: Record<string, JSONValue> = { type: TYPE }
    if (name || nameDecided) refPatch.name = name
    if (number || numberDecided) refPatch.number = number

    return {
      refs: [refPatch],
      their: { exchange: [name, number].filter((x) => x).join(' ') },
    }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = (ref.ref ?? '').trim()
    return { valid: sessionFor(normalized) !== undefined, normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const session = sessionFor(ref.ref)
    if (!session) return { ...ref, program: 'Contest', label: t('unconfigured') }
    const { name, number } = ourExchange(ref as Record<string, JSONValue>)
    return {
      ...ref,
      ref: session.key,
      program: 'Contest',
      label: sessionShortLabel(session),
      shortLabel: sessionShortLabel(session),
      // The row's second line SAYS when the exchange is still missing. A
      // suggestion tapped and then cancelled leaves a reference that names a
      // real session and nothing else, and a row reading like a configured
      // contest is how an operator reaches the Cabrillo with every sent
      // exchange exported as a dash.
      name: [sessionDateLabel(session), [name, number].filter((x) => x).join(' ') || t('notConfigured')].join(' · '),
    }
  },

  /// "KI2D for CWT 1300z" with "SEB 1234" beneath it: the sent exchange is the
  /// one thing an operator re-reads constantly during a contest.
  async suggestOperationTitle(
    { ref }: { ref: Ref; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<TitleSuggestion | null> {
    const session = sessionFor(ref.ref)
    const { name, number } = ourExchange(ref as Record<string, JSONValue>)
    return {
      for: session ? sessionShortLabel(session) : manifest.shortName,
      subtitle: name || number ? tFor(ctx)('ourExchangeSubtitle', { name, number }) : undefined,
    }
  },

  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: 'https://cwops.org/cwops-tests/', label: 'CWops CWT' }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const opRef = refOfType(operation, TYPE)
    if (!opRef) return []

    const fields: { name: string; value: string }[] = [{ name: 'CONTEST_ID', value: CONTEST_TAG }]
    const ours = ourExchange(opRef)
    const qsoRef = refOfType(qso, TYPE)
    const sent = [ours.name, ours.number].filter((x) => x).join(' ')
    const received = [firstName(qsoRef?.name), normalizeNumber(qsoRef?.number)].filter((x) => x).join(' ')
    if (sent) fields.push({ name: 'STX_STRING', value: sent })
    if (received) fields.push({ name: 'SRX_STRING', value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: 'our' | 'their'): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  return str(sideData.sent) || '599'
}

/// This operation's own name for its files — the session, since two CWTs a day
/// are two separate entries and their files must not collide. Not
/// [CONTEST_TAG], which names the contest and so is the same for all of them.
function filenameActivity(operation: Record<string, JSONValue>): string {
  const session = sessionOn(operation)
  return session ? `CWT-${session.key}` : 'CWT'
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: filenameActivity(operation),
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
    // Only the two exportTypes offered above. Belt and braces alongside the
    // keyed delegation in `adifForExport`: a hook answering for an exportType it never
    // offered makes the ADIF delegation recurse into itself.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const ourCall = str(operation.stationCall)
    const ours = ourExchange(opRef)

    if (args.exportType === 'cabrillo') {
      const power = POWER_CLASSES.find((entry) => entry.value === str(opRef?.power))
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', CONTEST_TAG],
          ['CALLSIGN', ourCall],
          ['CATEGORY-POWER', power?.cabrillo ?? ''],
          ['NAME', ours.name],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        qsoParts: (qso) => {
          const qsoRef = refOfType(qso, TYPE)
          return [
            ourCall || '-',
            reportFor(qso, 'our'),
            [ours.name, ours.number].filter((x) => x).join(' ') || '-',
            str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-',
            reportFor(qso, 'their'),
            [firstName(qsoRef?.name), normalizeNumber(qsoRef?.number)].filter((x) => x).join(' ') || '-',
          ]
        },
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

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('activity', { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook('adifFields', { hook: AdifFieldsHook, key: TYPE })
    registerHook('export', { hook: ExportHook, key: TYPE })
    registerHook('scoring', {
      hook: contestScorer(CWTScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
