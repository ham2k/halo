// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QSO parties — state, provincial and regional — ported from app-polo's
// QSOPartiesExtension (docs/design/contests.md M10).
//
// ONE extension for 49 parties, per §5.6: each party is offered as its own
// suggestion in the activity search ("texas" finds the Texas QSO Party), and
// the party key lives in the ref's own `ref` field — `{type: 'qp', ref: 'NY'}`
// — which selects its rules, its county list and its Cabrillo name. Splitting
// them into 49 bundles would meet the same discovery goal by shipping 49
// copies of one scorer.
//
// The rules are in `scorer.ts`, what an exchange means is in `location.ts`, and
// the parties themselves are data (`parties.ts`). This file is the app-facing
// surface: how a party is found, set up, typed into and exported.
//
// **What a rover does, and why nothing here implements it.** A county changes
// mid-log through SEGMENTS (M6): the operator types BREAK and edits the
// party's location in setup, `refs` is one of the keys a segment restates
// (`segments.dart`), and the scorer is handed the segment-effective ref for
// every QSO. So "stateful rolling-location scoring" is a property of where the
// county is READ from, not a mechanism this extension owns.
//
// The one place that cannot see segments is the EXPORT, which is handed the
// base operation and the whole log (`ExportRequest` carries no segments —
// §5.1 records this as an open shape, first noticed for a VHF rover's grid).
// So the county we were in is stamped onto each QSO as it is saved, and the
// Cabrillo and ADIF read that stamp in preference to the operation's own
// location. A QSO logged before this extension existed, or synced from polo,
// falls back to the operation's — which is what polo does for every QSO.

import { qsonToCabrillo } from "@ham2k/lib-qson-cabrillo"
import {
  adifForExport,
  contestScorer,
  defineExtension,
  exportFilename,
  startMillisOf,
} from "@ham2k/extension-sdk"
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

import {
  cabrilloCategories,
  cabrilloRowsFor,
  RESOLVED_MARKER,
  resolvedExchanges,
  SEGMENTED_MARKER,
  theirLocationForFile,
  exchangeInheritPrefix,
  exchangeOptionsFor,
  exchangeTransforms,
  fallbackTheirLocation,
  hasSegments,
  ourLocationForQso,
  preferredCodesFor,
} from "./exchange.ts"
import {
  ourEmail,
  ourLocationText,
  ourModeClass,
  ourName,
  ourOperatorClass,
  ourOverlayClass,
  ourPowerClass,
  ourStationClass,
  refOfType,
  str,
  TYPE,
} from "./entry.ts"
import { tFor } from "./i18n.ts"
import {
  allInParty,
  COUNTY_LINE_SEPARATOR,
  entityPrefixOf,
  guessedStateOf,
  nameForLocation,
  parseLocations,
  splitLocations,
} from "./location.ts"
import { CANADIAN_PROVINCES, US_STATES } from "./locations.ts"
import {
  daysUntil,
  hasAlreadyRun,
  partyFor,
  type QsoParty,
  ROVING_STATION_CLASSES,
  setupOrderOf,
  SUPPORTED_PARTIES,
} from "./parties.ts"
import { QsoPartyScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

type Translator = (key: string, args?: Record<string, JSONValue>) => string

/// The party an operation is running, from its own ref.
function partyOn(operation: Record<string, JSONValue> | undefined): QsoParty | undefined {
  return partyFor(refOfType(operation as Record<string, unknown> | undefined)?.ref)
}

/// What the activity row shows beneath a party's name: the party, and the day
/// it runs.
///
/// The date is the point of the line — an operator scanning a list of 47
/// parties is choosing by when, and "New York QSO Party" alone says nothing
/// about whether it is this weekend or last February. Written as the sponsor's
/// own UTC date, for the reason `fmtUtcDay` gives: it is compared against a
/// rule book, not against the operator's calendar.
///
/// Used by BOTH `suggest` and `decorateRef`, which have to agree: a suggestion
/// is persisted verbatim without ever calling `decorateRef`, so a subtitle
/// composed differently in the two places would have the same operation read
/// differently depending on how its party was added.
function partySubtitle(party: QsoParty): string {
  return party.startMillis ? `${party.name} • ${fmtUtcDate(party.startMillis)}` : party.name
}

/// `New York QSO Party 2026` — the year matters in a label, since the same
/// party comes round every autumn.
///
/// The year is the one the party's own FILE names, not the year the label
/// happens to be rendered in: an operation run in October 2026 would otherwise
/// have its activity row relabelled 2027 the moment the calendar turned, which
/// is a claim about the log that nothing in the log supports.
function partyLabel(party: QsoParty): string {
  const year = new Date(party.startMillis || Date.now()).getUTCFullYear()
  return `${party.name} ${year}`
}

const ActivityHook = {
  /// One suggestion per party, so an operator finds "Salmon Run" or "Texas" by
  /// name instead of enabling an extension and hunting through a list of 49.
  ///
  /// Everything the app displays is carried HERE: the suggestion path persists
  /// what this returns verbatim and never calls `decorateRef`, so a ref added
  /// by tapping a suggestion would otherwise reach the activities row with
  /// nothing but a two-letter code.
  async suggest({ searchTerm }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
    const term = (searchTerm ?? '').trim().toUpperCase()
    const now = Date.now()

    return SUPPORTED_PARTIES
      .filter((party) => !term
        || party.key.includes(term)
        || party.short.toUpperCase().includes(term)
        || party.name.toUpperCase().includes(term))
      .map((party) => ({
        type: TYPE,
        ref: party.key,
        name: partySubtitle(party),
        program: 'Contest',
        label: partyLabel(party),
        shortLabel: party.short,
        // Nearer parties rank higher — running now, this weekend, next month.
        // These recur annually, so a party whose file still holds last year's
        // dates ranks as though it were a year away rather than negative.
        relevance: relevanceOf(party, now),
      }))
  },

  /// Which party, where we are operating from, and the claims a submitted log
  /// has to carry.
  ///
  /// A `form`, not the `options` field the entry row uses: operation settings
  /// render `refList` and `form` and silently drop every other kind
  /// (`activities_view.dart`), and the form schema has no searchable single
  /// select. The location is therefore a plain text field — which a county
  /// LINE needs anyway, since it is two counties and a separator rather than
  /// one choice from a list.
  async operationControls(
    { operation }: { operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx) as Translator
    const now = Date.now()
    const party = partyOn(operation)
    const ref = refOfType(operation as Record<string, unknown>)

    // Soonest first — ranked by the same function `suggest` uses, or the two
    // disagree about what "next" means. Sorting on `daysUntil` alone is not
    // that: a party whose file still holds last year's dates has a NEGATIVE
    // count, so the staler the file the higher it sorted, and the first option
    // — which is also the default for a fresh setup — was whichever party was
    // furthest out of date.
    const byNearest = [...SUPPORTED_PARTIES].sort((a, b) => setupOrderOf(a, now) - setupOrderOf(b, now))
    const options = byNearest.map((candidate) => ({
      value: candidate.key,
      label: `${candidate.name} — ${whenLabel(t, candidate, now)}`,
    }))
    // A party key we don't know — a log from a newer build, or one added to
    // polo first. Offered as itself so the select can render it and Save
    // cannot silently replace it with the default below.
    const currentKey = str(ref?.ref).toUpperCase()
    if (currentKey && !partyFor(currentKey)) {
      options.unshift({ value: currentKey, label: `${currentKey} — ${t('unknownPartyOption')}` })
    }

    const elements: FormElement[] = [
      {
        type: 'field',
        fieldType: 'select',
        // The party key IS the ref's identity (§5.6), so this field writes
        // `ref` — the one core-owned key a setup form legitimately sets, and
        // the reason this control is a form rather than a reference list.
        key: 'ref',
        label: t('partyLabel'),
        // A default, because this form is also how a party is FIRST chosen:
        // without one a straight Save on a fresh setup writes `ref: null`, an
        // activity row naming no party and a scorer with nothing to score.
        value: currentKey || options[0]?.value,
        options,
      },
    ]

    if (party) {
      elements.push({
        type: 'field',
        fieldType: 'text',
        key: 'location',
        label: t('ourLocationLabel', { county: party.options.labelForCounty }),
        value: ourLocationText(undefined, ref),
        placeholder: Object.keys(party.counties)[0],
      })
      if (party.options.countyLine) {
        const [first, second] = Object.keys(party.counties)
        elements.push({
          type: 'markdown',
          text: t('ourLocationLineHelp', { example: `${first}${COUNTY_LINE_SEPARATOR}${second ?? first}` }),
        })
      }
      if (party.exchange.name) {
        elements.push({
          type: 'field',
          fieldType: 'text',
          key: 'ourName',
          label: t('ourNameLabel'),
          value: ourName(undefined, ref),
        })
      }
      // The classes THIS party publishes, and only those: an axis a sponsor
      // does not classify by is a question with no answer, and the operator
      // should not be made to look at it (§5.4's own rule for setup forms).
      for (const element of entryClassElements(t, party, ref)) elements.push(element)

      elements.push({
        type: 'field',
        fieldType: 'email',
        key: 'email',
        label: t('ourEmailLabel'),
        value: ourEmail(undefined, ref),
      })
    }

    elements.push({ type: 'markdown', text: infoMarkdown(t, party) })

    return [
      {
        key: 'qp/setup',
        label: t('activityLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: 'form',
          refType: TYPE,
          form: { title: party ? party.short : t('setupLabel'), elements },
        },
      },
    ]
  },

  /// The exchange: what they send us. A location always; a serial for the two
  /// parties that number their contacts, and a name for the one that trades
  /// them.
  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const party = partyOn(operation)
    if (!party) return []
    const t = tFor(ctx) as Translator
    const controls: LoggingControlDescriptor[] = []

    if (party.exchange.number) {
      controls.push({
        key: 'qp/ourSerial',
        label: t('ourSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: 'serial', refType: TYPE, field: 'ourSerial', sequence: { key: 'serial' } },
      })
      controls.push({
        key: 'qp/theirSerial',
        label: t('theirSerialLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: { kind: 'text', refType: TYPE, field: 'theirSerial', numeric: true, maxLength: 5 },
      })
    }

    if (party.exchange.name) {
      controls.push({
        key: 'qp/theirName',
        label: t('theirNameLabel'),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 30,
        input: { kind: 'text', refType: TYPE, field: 'theirName', maxLength: 12 },
      })
    }

    const guessedState = qso ? guessedStateOf(qso as Record<string, unknown>) : ''
    const options = exchangeOptionsFor(party, qso)
    controls.push({
      key: 'qp/location',
      label: t('theirLocationLabel', { county: party.options.labelForCounty }),
      icon: manifest.icon,
      color: manifest.accentColor,
      order: 40,
      input: {
        kind: 'options',
        refType: TYPE,
        field: 'location',
        options,
        // Hold the line back until the second character: a county code is three
        // or five, and on one character every callsign lookup would paint a
        // slice of the whole county list.
        minCharsForSuggestions: 2,
        // A county line is two codes and a separator, so the field is longer
        // than any one of them — and DX entity prefixes can be four.
        maxLength: party.options.countyLine ? 13 : 6,
        // Ranking, not pre-filling: a lookup's state is right often enough to
        // be worth floating that state's counties to the top, and wrong often
        // enough that writing one in would be worse than useless (§5.3).
        preferredCodes: preferredCodesFor(party, guessedState),
        ...(party.options.countyLine
          ? {
            multiValue: {
              separator: COUNTY_LINE_SEPARATOR,
              ...(exchangeInheritPrefix(party) ? { inheritPrefix: exchangeInheritPrefix(party) } : {}),
            },
            transforms: exchangeTransforms(party),
          }
          : {}),
        // A station in no known entity may still send something we don't have
        // a list for — a party's own file may be a year behind the county
        // splits — and for DX stations the list is empty, so the value is
        // whatever the operator heard.
        allowFreeform: options.length === 0,
      },
    })

    return controls
  },

  /// Mirrors the exchange into `their.exchange` (the column the QSO list shows,
  /// and the only generic field anything outside this extension reads), and
  /// stamps the county WE were in onto the contact — see the note about
  /// exports and segments at the top of this file.
  async processQsoBeforeSave(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    const party = partyOn(operation)
    if (!party) return null

    const qsoRef = refOfType(qso as Record<string, unknown>)
    const location = str(qsoRef?.location).trim().toUpperCase()
    const serial = str(qsoRef?.theirSerial).trim()
    const name = str(qsoRef?.theirName).trim().toUpperCase()
    const ours = ourLocationText(operation as Record<string, unknown>)

    const exchange = [serial, name, location].filter((part) => part).join(' ')

    // PRESENCE, not truthiness — the rule `stateparks` and `naqp` both follow.
    // `their.exchange` is one field shared by every activity on the operation,
    // and `mergeQsoPatch` merges `their` one level deep, so projecting an empty
    // string unconditionally wrote `''` over whatever a co-active contest had
    // just put there. A QSO party run alongside a state-park event — the exact
    // overlap `stateparks` exists for — lost the park abbreviation from the QSO
    // row and the plain ADIF, depending on which hook merged last.
    //
    // A DX contact makes it every time: no party asks a DX station to send
    // anything, so `exchange` is empty for all of them.
    const decided = qsoRef !== undefined
      && ['location', 'theirSerial', 'theirName'].some((field) => field in qsoRef)

    // Written ONCE, and never revised — this hook runs on every edit as well as
    // on the first save, so stamping unconditionally moved an old contact's
    // county to wherever the operator happens to be now. A rover who fixes a
    // callsign typo an hour later would have had that contact's Cabrillo line
    // claim the county they had driven to, against a scoreboard still counting
    // the one they made it from.
    const alreadyStamped = str(qsoRef?.ourLocation).trim()

    const ourExchange = [
      str(qsoRef?.ourSerial),
      ourName(operation as Record<string, unknown>),
      alreadyStamped || ours,
    ].filter((part) => part).join(' ')

    const patch: Record<string, JSONValue> = {}
    // Only where there is something to record: an operation whose location has
    // not been set yet would otherwise put an empty ref on every contact, and
    // the export's fallback to the operation's own county already covers a
    // contact that carries no stamp.
    if (ours && !alreadyStamped) patch.refs = [{ type: TYPE, ourLocation: ours }]
    // A deliberate blank still projects, so clearing an exchange on an edit
    // clears the QSO row's column too — but only where this extension owns the
    // field's contents.
    if (exchange || decided) patch.their = { exchange }
    // What WE sent, for the same reason polo writes it: an operator reading an
    // old contact wants to see both halves of the exchange.
    if (ourExchange) patch.our = { exchange: ourExchange }

    // Nothing to say, said as nothing: a hook that answers with a patch it did
    // not mean is a hook that overwrites its neighbours.
    return Object.keys(patch).length > 0 ? patch : null
  },
}

/// One select per axis the party publishes — its entry classes, in Cabrillo's
/// shared vocabulary (`parties.ts`).
///
/// NOTHING is defaulted. Every one of these is a claim about how we operated:
/// it goes into the submitted log's `CATEGORY-` lines, and for six parties the
/// power class multiplies the score. A guess would either misstate the entry to
/// a checker or invent a multiplier the sponsor would not award — so an
/// unanswered question stays unanswered, and both readers treat it as no claim.
function entryClassElements(
  t: Translator,
  party: QsoParty,
  ref: Record<string, unknown> | undefined,
): FormElement[] {
  const elements: FormElement[] = []
  const classes = party.entryClasses

  const select = (
    key: string,
    label: string,
    value: string | undefined,
    options: { value: string; label: string }[],
  ) => {
    if (options.length === 0) return
    elements.push({
      type: 'field',
      fieldType: 'select',
      key,
      label,
      value: value ?? '',
      // "Not declared" first, and the value a fresh setup keeps.
      options: [{ value: '', label: t('classNone') }, ...options],
    })
  }

  select('operator', t('operatorLabel'), ourOperatorClass(party, undefined, ref),
    classes.operator.map((code) => ({ value: code, label: t(`operator${code}`) })))

  select('power', t('ourPowerLabel'), ourPowerClass(undefined, ref, party),
    classes.power.map((code) => {
      // The watts are the party's own, and the multiplier is shown where there
      // is one, because that is the operator's reason to care.
      const limit = classes.powerLimits[code]
      const mult = party.powerMultipliers[code]
      const detail = [limit, mult !== undefined && mult !== 1 ? `×${mult}` : ''].filter((x) => x).join(' • ')
      return { value: code, label: detail ? `${t(`power${code}`)} — ${detail}` : t(`power${code}`) }
    }))

  select('station', t('stationLabel'), ourStationClass(party, undefined, ref),
    classes.station.map((code) => ({ value: code, label: t(`station${code}`) })))

  select('mode', t('modeLabel'), ourModeClass(party, undefined, ref),
    classes.mode.map((code) => ({ value: code, label: t(`mode${code}`) })))

  select('overlay', t('overlayLabel'), ourOverlayClass(party, undefined, ref),
    classes.overlay.map((code) => ({ value: code, label: t(`overlay${code}`) })))

  // Said once, next to the station class that makes it true, rather than as a
  // standing instruction: a rover's county changes through segments.
  if (classes.station.some((code) => ROVING_STATION_CLASSES.includes(code))) {
    elements.push({ type: 'markdown', text: t('mobileHelp') })
  }

  return elements
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = (ref.ref ?? '').toUpperCase().trim()
    return { valid: partyFor(normalized)?.supported === true, normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const party = partyFor(ref.ref)
    if (!party) return { ...ref, program: 'Contest', label: tFor(ctx)('unconfigured') }

    const location = str((ref as Record<string, JSONValue>).location).toUpperCase()
    return {
      ...ref,
      ref: party.key,
      program: 'Contest',
      label: partyLabel(party),
      shortLabel: location ? `${party.short}: ${location}` : party.short,
      // `name` is the activity row's subtitle, and BOTH paths that create this
      // ref have to agree on it — `suggest` writes the ref verbatim without
      // ever calling this hook.
      name: partySubtitle(party),
    }
  },

  /// "KI2D for NYQP", with the county beneath it.
  async suggestOperationTitle(
    { ref, operation }: { ref: Ref; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<TitleSuggestion | null> {
    const party = partyFor(ref.ref)
    if (!party) return { for: manifest.shortName }

    const location = ourLocationText(operation as Record<string, unknown>, ref as Record<string, unknown>)
    return {
      for: party.short,
      subtitle: location
        ? splitLocations(location).map((code) => nameForLocation(party, code)).join(' / ')
        : undefined,
    }
  },

  /// The sponsor's own rules — a reference here names a contest, not a place,
  /// so what there is to read about it is the rules it is run under.
  async linkForRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    const party = partyFor(ref.ref)
    return party?.url ? { url: party.url, label: party.name } : null
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const party = partyOn(operation)
    if (!party) return []

    const qsoRef = refOfType(qso as Record<string, unknown>)
    // `adifFields` is asked one QSO at a time and never sees the log, so it
    // cannot tell a segmented operation from an unsegmented one — the Cabrillo
    // can, and does. Our OWN export tells it (`generateExport` marks the
    // operation it hands over), so the two files agree; the core's whole-log
    // ADIF has no such marker and takes the stamp, which is right for a rover
    // and stale for a county corrected mid-log on an unsegmented one. That is
    // the gap HALO-531 closes by giving exports their segments.
    const segmented = refOfType(operation as Record<string, unknown>)?.[SEGMENTED_MARKER] !== false
    const ours = ourLocationForQso(qso, operation, { segmented })
    const weAreInParty = allInParty(parseLocations(party, ours))
    const theirs = str(qsoRef?.location).toUpperCase()
    const ourSerial = str(qsoRef?.ourSerial)
    const theirSerial = str(qsoRef?.theirSerial)
    const theirName = str(qsoRef?.theirName)
    const ourOwnName = ourName(operation as Record<string, unknown>)

    // `CONTEST_ID` is the sponsor's published contest name — the same
    // vocabulary the Cabrillo's `CONTEST:` line uses, which is what ADIF's own
    // contest list is built from, and what polo writes here.
    const fields = [{ name: 'CONTEST_ID', value: party.cabrilloName ?? party.short }]

    // The exchange as SENT, in the order it was sent: serial, name, location.
    const sent = [ourSerial, ourOwnName, ours].filter((part) => part).join(' ')
    // Through the same resolution the Cabrillo takes, so the two files cannot
    // disagree about the same contact — the thirteen parties that log a DX
    // station by its prefix used to get `DL` here and `DX` there. Our own
    // export also hands over what it resolved for the whole log, which is the
    // only way this hook can know what a station sent on an earlier band.
    const resolved = refOfType(operation as Record<string, unknown>)?.[RESOLVED_MARKER] as
      | Record<string, string>
      | undefined
    const theirsForFile = resolved?.[str(qso.uuid)]
      ?? theirLocationForFile(party, qso, { weAreInParty })
    const received = [theirSerial, theirName, theirsForFile].filter((part) => part).join(' ')
    if (sent) fields.push({ name: 'STX_STRING', value: sent })
    if (received) fields.push({ name: 'SRX_STRING', value: received })
    if (ourSerial) fields.push({ name: 'STX', value: ourSerial })
    if (theirSerial) fields.push({ name: 'SRX', value: theirSerial })
    if (ourOwnName) fields.push({ name: 'MY_NAME', value: ourOwnName })
    if (theirName) fields.push({ name: 'NAME', value: theirName })

    return fields
  },
}

function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  extension: string,
  compact?: boolean,
): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: partyOn(operation)?.short ?? manifest.shortName,
    startAtMillis: startMillisOf(operation, qsos),
    extension,
    compact,
  })
}

const ExportHook = {
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    const party = partyOn(args.operation)
    if (!party) return []
    const t = tFor(ctx) as Translator
    const named = (extension: string) =>
      filenameFor(args.operation, args.qsos ?? [], extension, args.compactFilenames)

    const options: ExportOption[] = [{
      exportType: 'contest-adif',
      format: 'adif',
      label: t('adifExport', { contest: party.short }),
      filename: named('adi'),
      selectedByDefault: true,
      refType: TYPE,
    }]

    // A party whose file names no contest cannot produce a submittable
    // Cabrillo: the `CONTEST:` line is what tells a checker which contest the
    // file is for, and inventing one would produce a file that looks
    // submittable and is not.
    if (party.cabrilloName) {
      options.push({
        exportType: 'cabrillo',
        format: 'cabrillo',
        label: t('cabrilloExport', { contest: party.short }),
        filename: named('log'),
        selectedByDefault: true,
        refType: TYPE,
      })
    }

    return options
  },

  async generateExport(args: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    const party = partyOn(args.operation)
    if (!party) return { filename: '', mimeType: '', content: '' }
    // Only the two exportTypes offered above: a hook answering for an
    // exportType it never offered makes the ADIF delegation recurse.
    if (args.exportType !== 'cabrillo' && args.exportType !== 'contest-adif') {
      return { filename: '', mimeType: '', content: '' }
    }

    const operation = args.operation
    const ourCall = str(operation.stationCall)
    const segmented = hasSegments(args.qsos)
    const lastLocation: Record<string, string> = {}

    if (args.exportType === 'cabrillo') {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ['CONTEST', party.cabrilloName],
          ['CALLSIGN', ourCall],
          ['LOCATION', splitLocations(ourLocationText(operation as Record<string, unknown>)).join(COUNTY_LINE_SEPARATOR)],
          ...cabrilloCategories(party, operation),
          ['EMAIL', ourEmail(operation as Record<string, unknown>)],
          ['OPERATORS', str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ['GRID-LOCATOR', str(operation.grid)],
        ],
        // The same memory the scorer folds: a station worked again on another
        // band without retyping the exchange is scored under the county they
        // gave the first time, so the file has to say the same.
        qsoParts: (qso) => cabrilloRowsFor(party, qso, operation, ourCall, { segmented, lastLocation }),
      })
      return {
        filename: filenameFor(operation, args.qsos, 'log', args.compactFilenames),
        mimeType: 'text/plain',
        content,
      }
    }

    const content = await adifForExport({
      // Marked so `adifFields` reads the county the same way the Cabrillo does
      // — see SEGMENTED_MARKER. A copy, never the stored operation.
      operation: {
        ...args.operation,
        refs: ((args.operation.refs as Record<string, JSONValue>[] | undefined) ?? []).map((r) =>
          r?.type === TYPE
            ? {
              ...r,
              [SEGMENTED_MARKER]: segmented,
              [RESOLVED_MARKER]: resolvedExchanges(party, args.operation, args.qsos, { segmented }),
            }
            : r),
      },
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

/// How near a party is, 0..1 — the search's ranking, which the setup list's
/// own order agrees with (`orderOf`).
///
/// Whatever is nearest ranks highest; a party whose published dates have all
/// passed is a file waiting for next year's update, and ranks as though it were
/// a year off rather than as "running now".
function relevanceOf(party: QsoParty, nowMillis: number): number {
  if (hasAlreadyRun(party, nowMillis)) return 1 / (1 + 365 / 60)
  const days = daysUntil(party, nowMillis)
  if (days <= 0) return 1
  // Halves roughly every two months, so this weekend clearly beats next month
  // and the far end of the year doesn't crowd anything out.
  return 1 / (1 + days / 60)
}

/// "already happened", "this weekend", "in 12 days" — polo's own vocabulary for
/// its party dropdown.
function whenLabel(t: Translator, party: QsoParty, nowMillis: number): string {
  if (hasAlreadyRun(party, nowMillis)) return t('whenAlreadyHappened')
  const days = daysUntil(party, nowMillis)
  if (days < -1) return t('whenLastWeekend')
  if (days <= 1) return t('whenThisWeekend')
  return t('whenInDays', { days })
}

function infoMarkdown(t: Translator, party: QsoParty | undefined): string {
  if (!party) return t('pickAParty')

  const lines: string[] = []
  if (party.url) lines.push(`[${party.url}](${party.url})`)
  lines.push(t('period', { period: `${fmtUtcDay(party.startMillis)} — ${fmtUtcDay(party.endMillis)}` }))
  // The second session is shown in full rather than folded into the first: a
  // party that runs Saturday afternoon and Sunday morning has a gap in the
  // middle, and one range spanning it would claim hours the sponsor does not
  // score.
  if (party.secondStartMillis && party.secondEndMillis) {
    lines.push(t('secondPeriod', { period: `${fmtUtcDay(party.secondStartMillis)} — ${fmtUtcDay(party.secondEndMillis)}` }))
  }
  // `status` and `lastUpdated` describe the DATA, which is what an operator
  // needs to judge how far to trust the dates and the county list. The files'
  // `notes` are NOT shown: they describe polo's own implementation.
  if (party.status) lines.push(t('status', { status: party.status }))
  if (party.lastUpdated) lines.push(t('lastUpdated', { lastUpdated: party.lastUpdated }))
  return lines.join('\n\n')
}

/// `2026-10-17`. Written out rather than localized: these are the sponsor's UTC
/// contest dates, and an operator comparing them against a rule book wants them
/// in the same form the rule book uses.
function fmtUtcDate(millis: number): string {
  if (!millis) return '—'
  const at = new Date(millis)
  const pad = (value: number) => `${value}`.padStart(2, '0')
  return `${at.getUTCFullYear()}-${pad(at.getUTCMonth() + 1)}-${pad(at.getUTCDate())}`
}

/// `2026-10-17 14:00Z` — the same date with the hour the party opens, for the
/// information panel, where the exact hour is what an operator is checking.
function fmtUtcDay(millis: number): string {
  if (!millis) return '—'
  const at = new Date(millis)
  const pad = (value: number) => `${value}`.padStart(2, '0')
  return `${fmtUtcDate(millis)} ${pad(at.getUTCHours())}:${pad(at.getUTCMinutes())}Z`
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
      hook: contestScorer(QsoPartyScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
