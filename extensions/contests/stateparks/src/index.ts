// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// State park on-the-air events. Ported from app-polo's StateParksExtension.
//
// The seventh contest ported (docs/design/contests.md M5), and the first that is
// FOUR contests: one extension, one event per operation, chosen either from the
// activity search (§5.6's `suggest`, so "ohio" finds it by name) or from the
// setup form's event list. The event key lives in the ref's own `ref` field —
// `{type: 'stateparks', ref: 'OHSP'}` — which is what selects its rules, its
// park list and its exports.
//
// It is also the first contest played THROUGH another activity: points come from
// POTA parks, ours and theirs. See scorer.ts for what that means for scoring,
// and for the divergences from polo it forced.
//
// Two shapes of event, from one code path:
//   * Texas, Florida and Georgia have NO exchange. The parks come from the POTA
//     refs the operator is already logging, so there is no entry-row field at
//     all and nothing to type.
//   * Ohio exchanges a three-letter park abbreviation, which is this milestone's
//     `kind: 'options'` field — 76 codes, searched, Space to accept.

import { qsonToCabrillo } from "@ham2k/lib-qson-cabrillo"
import { adifForExport, contestScorer, defineExtension, exportFilename, segmentsWith, startMillisOf, utcDateCompact } from "@ham2k/extension-sdk"
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

import { cabrilloPower, configuredCategory, configuredOurPower } from "./entry.ts"
import { daysUntil, EVENTS, eventFor, hasAlreadyRun, type StateParkEvent } from "./events.ts"
import { tFor } from "./i18n.ts"
import {
  configuredOurPark,
  ourParkAbbreviation,
  refOfType,
  theirParkAbbreviation,
  theirParkWasDecided,
} from "./parks.ts"
import { StateParksScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = 'stateparks'

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// The event an operation is running, from its own ref.
function eventOn(operation: Record<string, JSONValue> | undefined): StateParkEvent | undefined {
  return eventFor(str(refOfType(operation, TYPE)?.ref))
}

/// `Texas State Parks Event 2026` — the year matters in a title, since the same
/// event comes round every April.
function eventLabel(event: StateParkEvent, atMillis: number): string {
  const year = new Date(atMillis || event.startMillis || Date.now()).getUTCFullYear()
  return `${event.name} ${year}`
}

const ActivityHook = {
  /// One suggestion per event, so an operator finds "Ohio State Parks" by name
  /// instead of enabling an extension and hunting through a dropdown (§5.6).
  ///
  /// Everything the app displays is carried HERE. The suggestion path does not
  /// call `decorateRef` — it persists what this returns, verbatim — so a ref
  /// added by tapping a suggestion would otherwise reach the activities row and
  /// the information panel with nothing but its event code.
  async suggest({ searchTerm }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
    const term = (searchTerm ?? '').trim().toUpperCase()
    const now = Date.now()

    return EVENTS
      .filter((event) => !term
        || event.key.includes(term)
        || event.name.toUpperCase().includes(term)
        || event.short.toUpperCase().includes(term)
        || event.short.replace(/\s+/g, '').toUpperCase().includes(term))
      .map((event) => {
        const days = daysUntil(event, now)
        return {
          type: TYPE,
          ref: event.key,
          name: event.name,
          program: 'Contest',
          label: eventLabel(event, now),
          shortLabel: event.short,
          // Nearer events rank higher — running now, this weekend, next month.
          // These recur annually, so `daysUntil` never answers "300 days ago".
          //
          // Only ORDERS this list, and only against other suggestions that have
          // no location: the picker sorts everything with a distance ahead of
          // everything without one (activity_suggestions.dart), so a park 40km
          // away still comes first. An event is found by typing its name.
          relevance: relevanceForDays(days),
        }
      })
  },

  /// The event picker and, for the events that exchange abbreviations, which
  /// park we are working from.
  ///
  /// A `form`, not the `options` field this milestone added: operation settings
  /// render `refList` and `form` and silently drop every other kind
  /// (activities_view.dart), and the form schema has no searchable single
  /// select. 76 parks in a `select` is a long list to scroll — acceptable
  /// because it is answered once per operation, and usually not at all, since
  /// the POTA activation already says which park this is.
  async operationControls(
    { operation }: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const now = Date.now()
    const event = eventOn(operation)

    // Soonest first, so the event an operator is most likely setting up is the
    // one at the top — the same ordering `suggest` gets from `relevance`, which
    // this list has to agree with or the two disagree about what "next" means.
    const byNearest = [...EVENTS].sort((a, b) => daysUntil(a, now) - daysUntil(b, now))
    const options = byNearest.map((candidate) => ({
      value: candidate.key,
      label: `${candidate.name} — ${whenLabel(t, candidate, now)}`,
    }))
    // An event key we don't know — a log from a newer build, or next year's event
    // added to polo first. Offered as itself so the select can render it and Save
    // cannot silently replace it with the default below.
    const currentKey = str(refOfType(operation, TYPE)?.ref)
    if (currentKey && !eventFor(currentKey)) {
      options.unshift({ value: currentKey, label: `${currentKey} — ${t('unknownEventOption')}` })
    }

    const elements: FormElement[] = [
      {
        type: 'field',
        fieldType: 'select',
        // The event key IS the ref's identity (§5.6), so this field writes
        // `ref` — the one core-owned key a setup form legitimately sets, and the
        // reason this control is a form rather than a plain reference list.
        key: 'ref',
        label: t('eventLabel'),
        // A default, because this form is also how an event is FIRST chosen: the
        // renderer prefers the value already on the ref, and without one a
        // straight Save on a fresh setup writes `ref: null` — an activity row
        // naming no event, and a scorer with nothing to score.
        value: currentKey || options[0]?.value,
        options,
      },
    ]

    if (event?.usesParkAbbreviations) {
      elements.push({
        type: 'field',
        fieldType: 'select',
        key: 'ourPark',
        label: t('ourParkLabel'),
        // Only a DEFAULT: the renderer prefers the value already on the ref, so
        // this fills in the park the operator is activating without ever
        // overwriting a choice they made. Computed when the sheet opens, so a
        // POTA activation added in the same sitting won't be seen — the form
        // has no way to be told, and the operator can still pick from the list.
        value: ourParkAbbreviation(event, operation) || undefined,
        options: event.parks.map((park) => ({
          value: park.abbreviation ?? park.ref,
          label: `${park.abbreviation} — ${park.name ?? park.ref}`,
        })),
      })
    }

    // The classes we DECLARE — asked only where the answer reaches something we
    // produce, which is Texas's score and Ohio's Cabrillo (events.ts).
    if (event) {
      for (const element of entryElements(t, event, operation)) elements.push(element)
    }

    elements.push({ type: 'markdown', text: infoMarkdown(t, event) })

    return [
      {
        key: 'stateparks/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'form',
          refType: TYPE,
          form: { title: event ? event.short : t('setupLabel'), elements },
        },
      },
    ]
  },

  /// The park abbreviation the station we're working sends — Ohio only. The
  /// other three events read their parks off the POTA refs already being
  /// logged, so they contribute no entry-row field at all.
  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const event = eventOn(operation)
    if (!event?.usesParkAbbreviations) return []

    // A park already hunted on this QSO says which park they are in, so offer
    // it — the operator logged `US-1958` and the exchange is `HOC`. The core's
    // suggestion rule means a typed value always wins, and unlike polo's
    // display-only default, an accepted suggestion is genuinely saved.
    const suggested = qso ? theirParkAbbreviation(event, qso) : ''

    return [
      {
        key: 'stateparks/park',
        label: tFor(ctx)('theirParkLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'options',
          refType: TYPE,
          field: 'park',
          options: event.parks.map((park) => ({ code: park.abbreviation ?? park.ref, name: park.name })),
          // A code is three letters; hold the line back until the second, or
          // every callsign lookup paints a third of the park list.
          minCharsForSuggestions: 2,
          maxLength: 4,
          suggestedValue: suggested || undefined,
        },
      },
    ]
  },

  /// Mirrors the park into `their.exchange`, which is the column the QSO list
  /// shows and the only generic field anything outside this extension reads.
  async processQsoBeforeSave(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    const event = eventOn(operation)
    if (!event) return null

    // PRESENCE, not truthiness — `theirParkWasDecided`/`theirParkAbbreviation`
    // own that rule, so the save path, the ADIF and the Cabrillo cannot
    // disagree about whether a blank field was a decision (§5.4).
    const decided = theirParkWasDecided(qso)
    const park = theirParkAbbreviation(event, qso)

    if (!park) {
      // A deliberate blank still projects, so clearing an exchange on an edit
      // clears the QSO row's column too.
      return decided ? { their: { exchange: '' } } : null
    }

    return {
      refs: [{ type: TYPE, park }],
      their: { exchange: park },
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

    // Read through the event, so a `ourPark` left behind by a previous event —
    // a hidden `visibleWhen` field still submits, so switching Ohio to Texas
    // keeps Ohio's park on the ref — cannot label a Texas operation `TX SP: ADA`.
    const ourPark = configuredOurPark(event, undefined, ref as Record<string, JSONValue>)
    return {
      ...ref,
      ref: event.key,
      program: 'Contest',
      label: eventLabel(event, Date.now()),
      shortLabel: ourPark ? `${event.short}: ${ourPark}` : event.short,
      // `name` is the activity row's subtitle, and BOTH paths that create this
      // ref have to agree on it: `suggest` writes the ref verbatim without ever
      // calling this hook, so a park name here and an event name there would
      // have the same operation read differently depending on how it was added.
      name: event.parkByAbbreviation[ourPark]?.name ?? event.name,
    }
  },

  /// "KI2D for OH SP" with the park beneath it.
  async suggestOperationTitle(
    { ref, operation }: { ref: Ref; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<TitleSuggestion | null> {
    const event = eventFor(ref.ref)
    if (!event) return { for: manifest.shortName }

    const ourPark = ourParkAbbreviation(event, operation)
    return {
      for: event.short,
      subtitle: event.parkByAbbreviation[ourPark]?.name ?? (ourPark || undefined),
    }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    const event = eventFor(ref.ref)
    return event?.url ? { url: event.url, label: event.name } : null
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const event = eventOn(operation)
    if (!event) return []

    // The bare event key, NOT the Cabrillo name: ADIF's CONTEST_ID and
    // Cabrillo's CONTEST are different vocabularies, and polo keeps them apart
    // for the same reason ('OHSP' vs 'OHSPOTA').
    const fields = [{ name: 'CONTEST_ID', value: event.key }]

    // What belongs to this contest is the exchange; the park references are
    // POTA's fields (SIG/POTA_REF) and are contributed by that extension.
    // These reach only the FULL ADIF export now — this extension writes
    // Ohio's Cabrillo and nothing else (`ExportHook`), and a program file
    // carries one handler's fields — and that export asks every hook, so the
    // parks are alongside these in the one file they both reach.
    if (event.usesParkAbbreviations) {
      const ours = ourParkAbbreviation(event, operation)
      const theirs = theirParkAbbreviation(event, qso)
      if (ours) fields.push({ name: 'STX_STRING', value: ours })
      if (theirs) fields.push({ name: 'SRX_STRING', value: theirs })
    }
    return fields
  },
}

/// The contest's own name for this operation's file — the event key, since the
/// four events are four separate submissions. Falls back to the extension's
/// short name, so an operation whose ref names an event we don't know still
/// gets a filename to show in the export list.
function contestTag(operation: Record<string, JSONValue>): string {
  return eventOn(operation)?.key ?? manifest.shortName
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

/// The ref type POTA puts on an operation while activating a park — the parks
/// these two sponsors name in the filename and score the activation of.
const POTA_ACTIVATION = 'potaActivation'

/// Namespaces this hook's per-park exportType, and separates it from the ref.
/// Split by prefix LENGTH, never by searching for the colon: a reference can
/// contain one.
const SPONSOR_ADIF = 'stateparks-adif'
const SEPARATOR = ':'

/// The parks this operation is activating, in the order they were added — one
/// file each.
function parksActivated(operation: Record<string, JSONValue>): string[] {
  return (((operation.refs as Record<string, JSONValue>[] | undefined) ?? [])
    .filter((r) => r?.type === POTA_ACTIVATION && typeof r.ref === 'string' && r.ref)
    .map((r) => r.ref as string))
}

/// `W1RCP@US-2195-20260418.adi` — Georgia §7.2.1's example verbatim, and
/// within what Texas accepts ("extra text after the park number").
///
/// Built here rather than through `exportFilename`'s compact form, which
/// happens to render the same shape today: that form is the operator's
/// preference and is on its way to being a template they can edit, while this
/// one is a sponsor's requirement and has to survive them changing it. The
/// slash of a portable callsign becomes a dash, as it must in any filename.
function sponsorFilename(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  ref: string,
): string {
  const call = str(operation.stationCall).toUpperCase().replace(/\//g, '-') || 'UNKNOWN'
  // An operation with no contacts has no date of its own, and the name still
  // has to have one — `exportFilename` falls back the same way.
  const millis = startMillisOf(operation, qsos) ?? Date.now()
  return `${call}@${ref}-${utcDateCompact(millis)}.adi`
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    const event = eventOn(args.operation)
    if (!event) return []
    const t = tFor(ctx)

    // Each sponsor gets the one file it asked for, and nothing else.
    //
    // Ohio takes a Cabrillo and says so three times over — "No ADIF, no CSV,
    // no Text files - send in a standard Cabrillo file only"
    // (OSPOTA-Rules-2026-Rev-1.pdf) — under the CONTEST name they publish,
    // which is `cabrilloName`, not the event key.
    if (event.exportsCabrillo) {
      return [{
        exportType: 'cabrillo',
        format: 'cabrillo',
        label: t('cabrilloExport', { contest: contestTag(args.operation) }),
        filename: filenameFor(args.operation, args.qsos ?? [], 'log', args.compactFilenames),
        selectedByDefault: true,
        refType: TYPE,
      }]
    }

    // Texas and Georgia dictate the filename their uploaders read the park
    // from, which is what makes this file ours to write rather than POTA's
    // (events.ts, `NAMED_PARK_ADIF`) — one per park, since the name carries
    // exactly one. Florida's ADIF is POTA's own export under any name, so it
    // is not offered here.
    if (!event.requiresNamedParkAdif) return []

    return parksActivated(args.operation).map((ref) => ({
      exportType: `${SPONSOR_ADIF}${SEPARATOR}${ref}`,
      format: 'adif',
      label: t('sponsorAdifExport', { contest: contestTag(args.operation), ref }),
      filename: sponsorFilename(args.operation, args.qsos ?? [], ref),
      selectedByDefault: true,
      // The PARK's segments, not the event's: this file claims one park, and
      // the sponsor scores the activation, so it covers the stretch that park
      // was being activated — the same slice POTA's own export takes.
      refType: POTA_ACTIVATION,
      // Above POTA's own per-park export, which under compact file names
      // produces this very filename. The panel generates in list order and the
      // core renames the SECOND file of a colliding pair, so being first is
      // what keeps the name the sponsor demands on the file that has to have
      // it.
      priority: 1,
    }))
  },

  async generateExport(args: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    const exportType = str(args.exportType)
    const event = eventOn(args.operation)
    if (!event) return { filename: '', mimeType: '', content: '' }

    if (exportType.startsWith(`${SPONSOR_ADIF}${SEPARATOR}`)) {
      return await sponsorAdif(args, exportType.slice(SPONSOR_ADIF.length + SEPARATOR.length))
    }
    if (exportType !== 'cabrillo') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const ourCall = str(operation.stationCall)

    // Ohio's own layout: no signal reports, and a park column each side. The
    // other three events' sponsors take an ADIF, and polo's non-Ohio Cabrillo
    // row is unreachable code there, so it isn't ported.
    const ours = ourParkAbbreviation(event, operation) || NOT_IN_A_PARK
    const category = configuredCategory(event, operation)
    const content = qsonToCabrillo(args.qsos, {
      // In the sponsor's own order, from their sample log
      // (https://ospota.org/Files/OSPOTA_Sample-rev2.log): the checker is
      // automated, and these four CATEGORY lines are what tells it which
      // entry it is scoring. Empty values are dropped by the writer, so an
      // operator who never opened the category field submits what polo does.
      //
      // `CATEGORY-MODE` is fixed: the sponsor's sample has MIXED written in
      // rather than a placeholder, and their categories don't split by mode.
      // CLUB-NAME is in that sample too and is NOT emitted — their rules never
      // mention a club, so there is no field to fill it from.
      headers: [
        ['CONTEST', event.cabrilloName],
        ['CALLSIGN', ourCall],
        ['LOCATION', ours],
        ['CATEGORY-OPERATOR', category?.value],
        ['CATEGORY-TRANSMITTER', category?.transmitter],
        ['CATEGORY-POWER', cabrilloPower(event, operation)],
        ['CATEGORY-MODE', 'MIXED'],
        ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
        ['GRID-LOCATOR', str(operation.grid)],
      ],
      qsoParts: (qso) => [
        (ourCall || '-').padEnd(18, ' '),
        ours.padEnd(12, ' '),
        (str(((qso.their as Record<string, JSONValue>) ?? {}).call) || '-').padEnd(17, ' '),
        theirCabrilloLocation(event, qso).padEnd(12, ' '),
      ],
    })
    return {
      filename: filenameFor(operation, args.qsos, 'log', args.compactFilenames),
      mimeType: 'text/plain',
      content,
    }
  },
}

/// One park's file for a sponsor that named it. The contest is the main
/// handler — `CONTEST_ID` and the exchange are ours — and POTA rides along,
/// because `SIG_INFO`/`MY_SIG_INFO` are exactly what these uploaders read the
/// parks from (Texas requires both; Georgia §7.2.1 requires `SIG_INFO` for
/// in-state park-to-park).
async function sponsorAdif(args: ExportRequest, wanted: string): Promise<ExportResult> {
  // Listed off the operation's refs and generated from them again a moment
  // later: remove the park in between and filtering to nothing would produce a
  // valid ADIF claiming no park at all, which is worse than failing because it
  // looks submittable. Same staleness `activityExportHook` guards.
  if (!parksActivated(args.operation).includes(wanted)) {
    throw new Error(`stateparks: operation has no ${POTA_ACTIVATION} reference '${wanted}'`)
  }

  // The file names ONE park, so that is the only one the record fields may
  // name: the operation POTA's hook sees carries just this activation — on
  // every segment too, since the generator hands the hook each contact's own.
  const claimOnly = (operation: Record<string, JSONValue>): Record<string, JSONValue> => ({
    ...operation,
    refs: ((operation.refs as Record<string, JSONValue>[] | undefined) ?? []).filter(
      (r) => r?.type !== POTA_ACTIVATION || r?.ref === wanted,
    ) as unknown as JSONValue,
  })

  const content = await adifForExport({
    operation: claimOnly(args.operation),
    qsos: args.qsos,
    segments: segmentsWith(args.segments, claimOnly),
    includePrivateData: args.includePrivateData,
    mainHandler: TYPE,
    includeFieldsFrom: ['pota'],
  })
  return {
    filename: sponsorFilename(args.operation, args.qsos, wanted),
    mimeType: 'text/plain',
    content,
  }
}

/// The power class and entry category fields, for the events that publish them.
///
/// Neither is defaulted. A power class is a claim about how we operated, and a
/// guess at one either invents a multiplier Texas would not award or puts a
/// wrong `CATEGORY-POWER` in front of Ohio's log checker — so unanswered stays
/// unanswered, and both readers treat it as "no claim" (entry.ts).
function entryElements(
  t: (key: string, args?: Record<string, JSONValue>) => string,
  event: StateParkEvent,
  operation: Record<string, JSONValue>,
): FormElement[] {
  const elements: FormElement[] = []

  if (event.powerClasses.length > 0) {
    elements.push({
      type: 'field',
      fieldType: 'select',
      key: 'ourPower',
      label: t('ourPowerLabel'),
      value: configuredOurPower(event, operation) || undefined,
      options: event.powerClasses.map((power) => ({
        value: power.value,
        label: `${t(`power${power.value}`)} — ${power.watts}`,
      })),
    })
  }

  if (event.categories.length > 0) {
    elements.push({
      type: 'field',
      fieldType: 'select',
      key: 'ourCategory',
      label: t('ourCategoryLabel'),
      value: configuredCategory(event, operation)?.value,
      options: event.categories.map((category) => ({
        value: category.value,
        label: `${category.value} — ${category.description}`,
      })),
    })
  }

  return elements
}

/// What Ohio's sponsor expects in a location column for a station that wasn't in
/// a park — their own instruction, per polo.
const NOT_IN_A_PARK = 'NOT'

/// The other station's Cabrillo location: their park, else their state, else DX.
function theirCabrilloLocation(event: StateParkEvent, qso: Record<string, JSONValue>): string {
  const park = theirParkAbbreviation(event, qso)
  if (event.parkByAbbreviation[park]) return park

  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const guess = (their.guess as Record<string, JSONValue>) ?? {}
  const entity = str(their.entityPrefix) || str(guess.entityPrefix)
  if (entity !== 'K') return 'DX'
  return str(their.state) || str(guess.state) || NOT_IN_A_PARK
}

/// Relevance for an event [days] away. Whatever is nearest ranks highest, with
/// an event that has already started (negative days) treated as nearest of all.
function relevanceForDays(days: number): number {
  if (days <= 0) return 1
  // Halves roughly every two months, so this weekend clearly beats next month
  // and the far end of the year doesn't crowd out anything.
  return 1 / (1 + days / 60)
}

/// "already happened", "this weekend", "in 12 days" — polo's own vocabulary for
/// its event dropdown, minus the gap it has at exactly two days ago, where none
/// of its four branches matched and the label read "(undefined)".
///
/// An event whose dates are months past says so, rather than "in 266 days": the
/// number would be next year's running, while the period shown right beneath it
/// is this year's, and the pair reads as a bug rather than as a data file waiting
/// to be updated.
function whenLabel(
  t: (key: string, args?: Record<string, JSONValue>) => string,
  event: StateParkEvent,
  nowMillis: number,
): string {
  if (hasAlreadyRun(event, nowMillis)) return t('whenAlreadyHappened')
  const days = daysUntil(event, nowMillis)
  if (days < -1) return t('whenLastWeekend')
  if (days <= 1) return t('whenThisWeekend')
  return t('whenInDays', { days })
}

function infoMarkdown(t: (key: string, args?: Record<string, JSONValue>) => string, event: StateParkEvent | undefined): string {
  if (!event) return t('pickAnEvent')

  const lines = [t('checkPota')]
  if (event.url) lines.push(`[${event.url}](${event.url})`)
  lines.push(t('period', { period: `${fmtUtcDay(event.startMillis)} — ${fmtUtcDay(event.endMillis)}` }))
  // `notes` is NOT shown. In the data files it describes polo's own
  // implementation ("Scoring is not accurate. Missing points for distinct state
  // parks") — which this port implements, so relaying it would tell an operator
  // their score is missing something it just awarded them. `status` and
  // `lastUpdated` describe the DATA, which is what an operator needs to judge
  // how much to trust the dates and the park list.
  if (event.status) lines.push(t('status', { status: event.status }))
  if (event.lastUpdated) lines.push(t('lastUpdated', { lastUpdated: event.lastUpdated }))
  return lines.join('\n\n')
}

/// `2026-04-18 12:00Z`. Written out rather than localized: these are the
/// sponsor's UTC contest hours, and an operator comparing them against a rule
/// book wants them in the same form the rule book uses.
function fmtUtcDay(millis: number): string {
  if (!millis) return '—'
  const at = new Date(millis)
  const pad = (value: number) => `${value}`.padStart(2, '0')
  return `${at.getUTCFullYear()}-${pad(at.getUTCMonth() + 1)}-${pad(at.getUTCDate())} ${pad(at.getUTCHours())}:${pad(at.getUTCMinutes())}Z`
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('activity', { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook('adifFields', { hook: AdifFieldsHook, key: TYPE })
    registerHook('export', { hook: ExportHook, key: TYPE })
    // Keyed to the ref TYPE, which is what the information panel matches its
    // per-contest heading against.
    registerHook('scoring', {
      hook: contestScorer(StateParksScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
