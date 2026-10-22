// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import type { PanelScene, PanelSceneEvent, PanelSceneEventResult } from "./panelScene.ts"
import type { HookCategoryName } from "./hookCategories.ts"
export type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue }

export interface HookContext {
  online: boolean
  account?: {
    credentials?: Record<string, string>
    session?: Record<string, string>
  }
  developerMode?: boolean
  locale?: string
  // Platform-appropriate app name — "Ham2K Logger" on desktop, "Ham2K
  // Portable Logger" on mobile — for extensions that identify the app to an
  // external service or file (e.g. a spot's "source" field, an ADIF
  // PROGRAMID header).
  appName?: string
  /// The user's distance-units preference ('kilometers' | 'miles') — for
  /// extensions that localize units (e.g. WEATHER's °F vs °C).
  distanceUnits?: string
  /// The characters this operator writes numbers with, already resolved from
  /// their Number Formatting setting — `'.'`/`','` by default, `','`/`'.'`
  /// under comma conventions. For a hook that PARSES what someone typed
  /// (a frequency in a command) or formats a number back to them.
  ///
  /// Never use these on anything machine-facing: ADIF, a spot posted to an
  /// external service and every other wire format take a plain
  /// period-decimal number regardless of what the operator sees.
  ///
  /// On fr, ru, sv and pl `groupingSeparator` is a NARROW NO-BREAK SPACE
  /// (U+202F), not a comma or a period and not a character a keyboard
  /// produces — strip it, but strip an ordinary space too, because that is
  /// what someone actually types. It can also be empty; guard for that
  /// before using it as a delimiter, since `split('')` splits everywhere.
  decimalSeparator?: string
  groupingSeparator?: string
  /// The order the device's region writes a numeric date in — `'mdy'` for
  /// 3/18 in the US, `'dmy'` for 18/3 in most of the world, `'ymd'` where
  /// the year leads (and the month then comes before the day). Resolved
  /// app-side from the device locale, not the app's language: an app in
  /// English on a British device writes 18/3. For a hook that parses a date
  /// someone typed.
  dateOrder?: "mdy" | "dmy" | "ymd"
  /// How many characters the operator's Grid Precision setting shows a
  /// Maidenhead locator with — 6 or 8. A locator's length is a claim about
  /// how well a location is known, so a hook that WRITES one for a human or
  /// for a program (an ADIF MY_GRIDSQUARE, a spot's comment) states the
  /// operator's own claim rather than whatever length the stored string
  /// happens to be. Never truncate a coordinate to it: this governs
  /// locators, not `lat`/`lon`.
  gridPrecision?: number
  /// The running build's edition ('dev' | 'next' | 'prod' — see
  /// packages/halo_build_tools/lib/src/edition.dart), for a hook whose
  /// static configuration must vary per-edition (e.g. SOTA's OAuth client:
  /// each edition's app identity is registered as its own client with
  /// SOTA's Keycloak).
  edition?: string
  /// Keys of every experiment (app/experiments.yaml) currently ON for this
  /// user — for a hook whose own effect must stay invisible until an
  /// experiment gating the surface it belongs to has shipped ungated (e.g.
  /// a `command` hook for a feature still behind `keyer`, checked per-call
  /// rather than at the whole-extension `manifest.experiments` grain, which
  /// would also hide unrelated hooks the same extension registers).
  enabledExperiments?: string[]
  /// The experiment catalog (app/experiments.yaml): every experiment's key,
  /// display name and the aliases the EXP command accepts for it, on or
  /// off. Lets a hook resolve a typed token to the key `enabledExperiments`
  /// lists — the app remains the authority when it flips the state.
  experiments?: { key: string; name: string; aliases: string[] }[]
  /// Fetches one operation's QSON by uuid, with `uuid` folded in — the same
  /// shape hooks receive as an `operation` argument (see `qsonPayloadFor`
  /// on the Dart side). Resolves null when the uuid is unknown. For hooks
  /// that only receive part of the picture (e.g. a `command` hook handed
  /// the operation it's typed into, wanting fresher or fuller data).
  getOperation?(uuid: string): Promise<Record<string, JSONValue> | null>
  /// Fetches every QSO logged in an operation — each entry the QSO's raw
  /// QSON `data` — oldest first, excluding soft-deleted records but
  /// including event markers (`band: 'event'`). Resolves null when the
  /// operation is unknown or the host has no log access — distinct from
  /// `[]`, which means the operation exists and simply has no QSOs yet.
  ///
  /// Every extension reads one copy of the log the runtime keeps, which asks
  /// the host only what changed since the last read — so a call is never
  /// staler than itself, and costs the whole log only the first time. Each
  /// call gets a new array. From extension API 9 its QSOs are the shared
  /// ones, frozen: writing to one throws, so copy what you mean to change.
  /// Under an older `api` each call gets QSOs of its own, as it always did.
  getQsos?(operationUuid: string): Promise<Record<string, JSONValue>[] | null>
  /// Every spot the host has already fetched for [call] (case-insensitive)
  /// that is no older than `maxAgeMinutes` (default 30), newest first.
  ///
  /// Reads the host's cache only — it NEVER triggers a fetch, so it is cheap
  /// enough to call from the per-keystroke lookup pipeline, and it returns
  /// `[]` (not null) whenever the cache is cold or the host keeps no spots.
  /// Age is the spot's own `spot.timeInMillis`, not when it was fetched.
  getSpotsForCall?(call: string, maxAgeMinutes?: number): Promise<Spot[]>
  /// The spots board the host already holds — never a fetch, like
  /// `getSpotsForCall`, so `[]` before the first refresh lands or where the
  /// host keeps no spots. A panel declaring `on: ['spots']` is re-rendered
  /// when the board changes — a refresh, new verdicts, the operator's filters,
  /// the radio's band or mode — which is the moment to call this.
  ///
  /// By default the board is the operator's: what their Spots Panel filters
  /// admit (sources, enabled bands, band and mode — "auto" following the
  /// radio — age and continents), merged and ordered as that panel shows it.
  /// `filter: 'all'` starts instead from every held spot, unmerged, newest
  /// first. The other options narrow either one further.
  ///
  /// Spots come back annotated — worked, our own, scoring notices — when
  /// there is an operation to judge them against: `operationUuid`, or by
  /// default the `operation` the calling hook was handed (a panel's render
  /// args). The verdicts are the ones the app already holds for the
  /// operation open on screen, so another operation's spots — and that one's,
  /// until its first verdicts land — come back unannotated, never as a
  /// guess. `annotate: false` returns them exactly as the sources gave
  /// them.
  /// A malformed or unknown option rejects the promise. Absent on hosts
  /// older than it, so call it as `ctx.getSpots?.()`.
  getSpots?(options?: GetSpotsOptions): Promise<BoardSpot[]>
  /// The most recent non-deleted contacts logged with [call]
  /// (case-insensitive), across every operation, newest first — the raw QSON
  /// `data` for each, same shape `getQsos` returns per-QSO, never event
  /// markers. For a source that answers "who is this station" from the log
  /// itself (`call-history`) rather than a network call. Always `[]` when
  /// there is no match or the host keeps no log access — there is no
  /// "unknown call" to distinguish from "no history".
  ///
  /// [options] narrow the history BEFORE it is ordered and limited, so an
  /// older matching contact still comes back behind newer ones that don't
  /// match. A malformed option rejects the promise, and so does an unknown
  /// one or an include option given no values (`operation: []`). Hosts older
  /// than these options ignore them and answer the unfiltered five, so
  /// re-check on the results whatever the caller relies on — and read an
  /// empty answer there as "none among the latest five", not "none at all".
  getHistoryForCall?(call: string, options?: HistoryForCallOptions): Promise<Record<string, JSONValue>[]>
}

/// Filters for `HookContext.getHistoryForCall`. Every one is optional, and a
/// contact must pass all of those given. A `string | string[]` option matches
/// any of the values listed.
export interface HistoryForCallOptions {
  /// Contacts with a ref of this type (`'cwt'`, `'pota'`), either in their
  /// own `refs` or in their operation's — a hunted park is on the QSO, an
  /// activated one (`potaActivation`) on the operation. Contacts logged by
  /// any extension implementing the activity match.
  refType?: string | string[]
  /// Contacts with a ref, their own or their operation's, whose `ref` starts
  /// with this, ignoring ASCII case (`'fr-'` matches `FR-0001`). With
  /// `refType`, the same ref must pass both:
  /// `{ refType: 'potaActivation', refPrefix: 'FR-' }` is every contact made
  /// activating a French park.
  refPrefix?: string | string[]
  /// Read an operation's refs as they stood when each contact was made. A
  /// `break`/`start` segment can move a log to a second park or end a
  /// contest; without this, every contact is matched against the
  /// operation's base refs. Costs a lookup per contact.
  refsSegmentAware?: boolean
  /// Contacts in these operations (by uuid), or outside them.
  operation?: string | string[]
  excludeOperation?: string | string[]
  /// Whole UTC days, both ends inclusive: an ISO date (`'2026-09-01'`) or
  /// any instant within the day, as an ISO timestamp or epoch millis.
  fromDate?: string
  toDate?: string
  fromDateMillis?: number
  toDateMillis?: number
  /// Exact instants, both ends inclusive: an ISO timestamp (UTC unless it
  /// carries an offset) or epoch millis. Where several bounds are given for
  /// one side, the tightest wins.
  fromTime?: string
  toTime?: string
  fromTimeMillis?: number
  toTimeMillis?: number
  /// Bands as QSON spells them (`'20m'`), case-insensitive.
  band?: string | string[]
  excludeBand?: string | string[]
  /// Modes, case-insensitive. `'SSB'` also matches `USB` and `LSB`;
  /// `'CW'`, `'PHONE'` and `'DATA'` match their whole family; any other
  /// mode matches only itself.
  mode?: string | string[]
  excludeMode?: string | string[]
  /// How many contacts to return: 5 when omitted, never more than 50.
  limit?: number
}

export type { CallInfo, CallInfoLookup, AnnotatedCallInfo, RefInfo } from "@ham2k/lib-qson-tools"
import type { CallInfo, CallInfoLookup, AnnotatedCallInfo, RefInfo } from "@ham2k/lib-qson-tools"

/// A lookup hook may return zero or more records for one decoration pass —
/// `[]` to skip (e.g. the field it would provide is already known). A result
/// that supplies a location may tag it with a [LOCATION_ACCURACY] rank via
/// `locAccuracy` (lower = more precise); `mergeLookupIntoGuess` keeps the most
/// accurate location when several same-scope sources offer one.
///
/// `refs` proposes activity references for the QSO being logged (what
/// `spot-history` mines out of recent spots). They ride the guess to the
/// host, which applies only those whose `type` the QSO doesn't already
/// carry — a lookup never overrides a ref the operator entered.
///
/// `online: true` declares that answering THIS result required an actual
/// network round-trip — set it only on a result a source could not have
/// produced with `ctx.online` false. The host's background lookup queue
/// (`LookupQueueService._hasOnlineLookup`) uses this, generically, to decide
/// whether a QSO already carries a real online answer worth not re-fetching;
/// omit it (the default) for anything answered from local/offline data (a
/// log query, a cached file, recent spots) — a QSO whose only lookups are
/// unmarked is treated as never having reached the network, however many
/// distinct sources contributed to it.
export type LookupResult = (CallInfoLookup & { locAccuracy?: number; refs?: RefInfo[]; online?: boolean })[]

/// Registered under category `lookup`. Called once per decoration pass, in
/// priority order, by the core `lookupService/core` hook's internal
/// sequential fan-out — never directly from Dart. Receives the CallInfo
/// being decorated so far (including its `lookups` and merged `guess`), the
/// full `qso` and `operation` it belongs to (e.g. so a POTA lookup can
/// inspect `qso.refs`), and whether this pass should attempt network calls.
export interface LookupHook {
  lookupCall(
    args: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LookupResult>
}

/// Registered under category `recentContextLookup`. Same interface as
/// [LookupHook], run by the same orchestrator immediately after it — but
/// ONLY when the request sets `recentContext`.
///
/// The distinction is what the answer depends on. A `lookup` hook answers
/// "who is this callsign", which is true whenever it is asked. A
/// `recentContextLookup` hook answers "what is this station doing right
/// now" — from spots, from the last few minutes of the log, from whatever
/// else is live — and that answer is only meaningful for a contact being
/// composed at this moment. Asked about a QSO logged an hour ago, or about
/// every callsign on the spots board, it is not merely useless but wrong,
/// so the orchestrator does not ask at all rather than leaving each hook to
/// recognize a context it cannot see.
export type RecentContextLookupHook = LookupHook

export interface LookupServiceRequest {
  callInfo: CallInfo
  qso: Record<string, JSONValue>
  operation: Record<string, JSONValue>
  /// Whether this call is being composed right now — a callsign typed into
  /// the logging field, or a suggested QSO taken from a spot. Only then are
  /// `recentContextLookup` hooks run. Defaults to false: background
  /// enrichment of saved QSOs, annotating the spots board, and the quick
  /// lookup dialog are all lookups about a call, not about a contact in
  /// progress.
  recentContext?: boolean
}

export interface LookupServiceResult {
  lookups: CallInfoLookup[]
  guess: CallInfo
}

/// Registered under category `lookupService`, key `core` — the single
/// hardcoded orchestrator (mirrors `scoring/core`). Dart calls this ONE
/// hook; it runs the hardcoded callsign-annotation pre-step, fans out to
/// every `lookup` hook in priority order, and merges results according to
/// the locationScope rules internally.
export interface LookupServiceHook {
  lookupCallInfo(args: LookupServiceRequest, ctx: HookContext): Promise<LookupServiceResult>
}

export interface SpotRef {
  type: string
  ref: string
}

export interface Spot {
  their: { call: string }
  freq?: number
  band?: string
  mode?: string
  refs?: SpotRef[]
  /// MDI or FontAwesome ('fa-') icon name, same convention as activity
  /// controls — a source hint the spots board can show (e.g. SOTA's summit
  /// glyph).
  icon?: string
  spot: {
    timeInMillis: number
    source: string
    label?: string
    sourceInfo?: Record<string, JSONValue>
  }
}

/// Options for `HookContext.getSpots`. Every one is optional; a
/// `string | string[]` option matches any of the values listed.
export interface GetSpotsOptions {
  /// `'user'` (the default): what the operator's own Spots Panel filters
  /// admit. `'all'`: every spot the host holds.
  filter?: "user" | "all"
  /// Measured on the spot's own `spot.timeInMillis`; inclusive.
  maxAgeMinutes?: number
  /// Band names as the app spells them (`'20m'`).
  band?: string | string[]
  /// A mode (`'FT8'`), or a family: `'SSB'` also matches `USB`/`LSB`, and
  /// `'Phone'`, `'CW'` and `'Digital'` match their whole super mode.
  mode?: string | string[]
  /// Spot-source hook keys, as in `BoardSpot.hookKey`.
  source?: string | string[]
  /// Default true when there is an operation to judge the spots against.
  annotate?: boolean
  /// The operation whose log the annotations judge against. Defaults to the
  /// calling hook's `operation` argument.
  operationUuid?: string
}

/// What `host.suggestQso` puts into the logging fields: a spot's station and where it was heard.
export interface SuggestedQso {
  their: { call: string }
  /// kHz, as QSON keeps it.
  freq?: number
  band?: string
  mode?: string
  refs?: SpotRef[]
}

/// A spot as the host holds it: what a source returned, plus the key of the
/// source that offered it.
///
/// On the operator's board (`filter: 'user'`), spots are merged as the Spots
/// Panel merges them: one station reported by several sources is one spot,
/// carrying every report's `refs` and one report's `hookKey`, and stations
/// sharing a frequency and references are one spot whose `their.call` lists
/// them comma-joined (`'K1ABC,W2XYZ'`). Split it before looking a call up.
export interface BoardSpot extends Spot {
  hookKey?: string
  /// What the Spots Panel's row shows beside the call: the activity's icon and
  /// tint for the spot's first reference (else the source's `icon`, else a
  /// tower) and the call's note emoji. Absent with `annotate: false`, and on
  /// hosts before extension API 12.
  display?: { icon: string; iconColor?: string; emoji?: string }
  /// Present when the spots were judged against an operation.
  annotations?: SpotAnnotations
}

/// What the Spots Panel shows about a spot, judged against an operation.
export interface SpotAnnotations {
  /// Every operator on the spot is already worked, by every scorer's rules,
  /// and no scorer has anything new to say about them — the panel strikes the
  /// row. Never claimed without a scorer having answered.
  worked: boolean
  /// One of the operators is the operation's own station.
  isSelf: boolean
  /// Scorers' reasons the contact would count anew (`'newBand'`,
  /// `'newDXCC'`…; see `QsoScoreNotices`), across every operator on the spot.
  notices: string[]
}

export interface SpotEligibility {
  enabled: boolean
  /// MDI or FontAwesome ('fa-') icon name for this source's status icon in
  /// the Spotting control's icon row.
  icon?: string
}

export interface PostResult {
  ok: boolean
  /// Plain-text fallback: logged, and what surfaces show when there's no
  /// richer `userMessage`.
  message?: string
  /// Optional richer presentation of the outcome (usually a failure) — the
  /// host presents it in addition to the surface's own success/failure
  /// indication (e.g. the Spotting control's source icons).
  userMessage?: ResultMessage
  /// With `ok: true`: the source deliberately sent nothing — its own rules
  /// declined this spot. The Spotting control leaves its icon neutral rather
  /// than lit, and its chip counts only the sources that did not skip; when
  /// every one did, `message` is what the operator is told. A host that does
  /// not know the field shows it as sent.
  skipped?: boolean
}

/// A user-facing message a hook attaches to a result (see
/// PostResult.userMessage) or presents imperatively via
/// `host.showMessage` (for hooks whose results can't carry one, e.g.
/// lookups). Declarative like NoticeAction — the host renders it:
///   'status' — transient status-bar message (`title`/`text`/`icon`)
///   'dialog' — modal dialog; `text` is markdown; `actions` adds buttons
///              next to the always-present Close (e.g. an `account` action
///              to open the account dialog after an auth failure)
export interface ResultMessage {
  presentation: "status" | "dialog"
  title?: string
  text: string
  /// Status presentation only — same icon convention as status bar items.
  icon?: string
  /// Dialog presentation only.
  actions?: NoticeAction[]
}

export interface PostSelfSpotRequest {
  operation: Record<string, JSONValue>
  freq: number
  mode?: string
  comment?: string
}

export interface PostOtherSpotRequest {
  qso: Record<string, JSONValue>
  comment?: string
  spotterCall?: string
}

export interface SpotsHook {
  sourceName: string
  fetchSpots(args: Record<string, never>, ctx: HookContext): Promise<Spot[]>
  /// Whether this hook can post a spot for the operation itself right now
  /// (e.g. it has a matching activation ref) — checked before showing this
  /// source's icon in the Spotting control, not before every post.
  isSelfSpotEnabled?(args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<SpotEligibility>
  /// Same, but for spotting the station on one already-logged QSO (e.g. it
  /// has a matching hunted ref).
  isOtherSpotEnabled?(args: { qso: Record<string, JSONValue> }, ctx: HookContext): Promise<SpotEligibility>
  postSelfSpot?(args: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult>
  postOtherSpot?(args: PostOtherSpotRequest, ctx: HookContext): Promise<PostResult>
}

/// One line a DX cluster node sent (docs/design/cluster.md). Extension API 10.
export interface ClusterLine {
  /// Increases by one per line for the app's whole session, across
  /// reconnects: ask `host.clusterLines({ after })` with the last one seen
  /// and nothing is missed or repeated.
  seq: number
  /// When it arrived, epoch milliseconds on the app clock.
  at: number
  /// As the node sent it — a `DX de …` spot, an announcement, a prompt.
  text: string
}

export interface ClusterStatus {
  state: "idle" | "connecting" | "connected" | "failed"
  node: { name: string; host: string; port: number }
  /// The call logged in: the operator of the operation in front.
  call?: string
  /// Why the last attempt failed — see `ClusterReply.error`.
  error?: string
  message?: string
  /// The newest line's `seq`; 0 before the first.
  lastSeq: number
}

/// What the node answered a command or a spot with.
export interface ClusterReply {
  ok: boolean
  /// What the node sent between the command and its next prompt, which
  /// includes whatever spots it interleaved meanwhile.
  lines: string[]
  /// `unsupported` (the web build has no sockets), `noCall`, `connectFailed`,
  /// `needsPassword`, `loginFailed`, `disconnected`, `timeout`, `refused`
  /// (the node said no; `message` quotes it), `tooSoon` (spots are spaced a
  /// few seconds apart), `invalidCall`, `invalidFrequency`.
  error?: string
  message?: string
}

export interface ClusterPostSpotRequest {
  /// kHz.
  freq: number
  call: string
  /// Up to 60 characters are sent. Nodes show the first 30 in a `DX de`
  /// line and forward the rest, so what matters most goes first.
  comment?: string
}

/// Lines from the node, for an extension that called
/// `host.clusterSubscribe()`. Registered under the extension's own key (the
/// default): that is the key the host delivers to.
export interface ClusterHook {
  /// The lines since the last batch, oldest first — at most one call a
  /// second, however busy the node.
  onLines(args: { lines: ClusterLine[] }, ctx: HookContext): Promise<void>
}

/// A reference ties a QSO or operation to an activity program entity
/// (a park, a summit, a contest). Same shape as app-polo's QSON refs.
export interface Ref {
  type: string
  ref?: string
  name?: string
  label?: string
  shortLabel?: string
  grid?: string
  /// The entity's own coordinate, when the activity's lookup table has one —
  /// tighter than decoding [grid] (a 6-character Maidenhead square, up to a
  /// few km across). Absent for a program with no per-entry coordinate, or
  /// whose lookup only ever resolved one from `grid` itself.
  lat?: number
  lon?: number
  location?: string
  program?: string

  /// How far from [lat]/[lon] the program lets an activator be, drawn as a
  /// circle on the maps alongside any outline `geojsonUrlForRef` names. Per
  /// reference, not per program: some programs set different distances by
  /// region or by kind of reference. Give whichever unit the program's rules
  /// are written in; meters win when both are set. Drawn only around a
  /// coordinate, never around [grid] — a square's centre can be further from
  /// the reference than the whole radius.
  activationRadiusInMeters?: number
  activationRadiusInFeet?: number

  /// The reference covers more ground than one point can stand for — a long
  /// trail, a park across several states — so [lat]/[lon] are a
  /// representative point rather than where an activator would be. The maps
  /// draw it like any other reference; the app only refuses to place an
  /// operation that has no location of its own there (docs/design/locations.md).
  /// Set it on `suggest` answers and in `decorateRef` alike, and always to a
  /// boolean, so a re-decoration can clear it. `referenceActivity` neither
  /// sets nor clears it.
  largeArea?: boolean

  /// The program has RETIRED this reference — it still exists and still names
  /// itself, but it can no longer be activated. The app marks such a row
  /// rather than hiding it, so an operator who asked for it by name learns why
  /// it is not an ordinary choice.
  ///
  /// A flag, deliberately, and never a marker folded into [name] or [label]:
  /// a suggestion is persisted onto the operation VERBATIM (a reference type
  /// runs no setup form, so nothing re-decorates it on the way in), and those
  /// two fields feed the operation's own title. A localized word appended to
  /// either is a UI string baked into stored data, in whatever language the
  /// operator happened to be running.
  ///
  /// Named for what it MEANS, not for what it disables: the app renders it as
  /// "Retired", and a program wanting to mark a reference unavailable for some
  /// other reason (out of season, not yet valid) needs its own vocabulary
  /// rather than this one, which would state a specific and wrong fact.
  ///
  /// Set it on every decoration, not only when true — a mark left standing is
  /// how a reinstated reference stays "retired" forever.
  retired?: boolean

  /// Which record this reference belongs on, for a producer that cannot put it
  /// there itself.
  ///
  /// QSON keeps an activation on the OPERATION and a hunted reference on the
  /// QSO, but ADIF has no operation — an activation is written onto every
  /// record, and an `adifImport` hook reading one back has only the QSO in
  /// hand. Tagging `for: 'operation'` says where it actually goes, and the
  /// importer moves it.
  ///
  /// Consumed on arrival: once the reference is on the operation, its position
  /// IS the answer, and a marker left behind would be a second source of truth
  /// free to disagree with it. Absent means the QSO, which is where a
  /// reference lives unless something says otherwise.
  ///
  /// **Mirror any change here into lib-qson's `Ref`** — this is the app's copy
  /// of a shared vocabulary.
  for?: "operation" | "qso"

  [key: string]: JSONValue | undefined
}

/// A fragment of an operation's title/subtitle sentence, contributed by one
/// ref — `title`/`for`/`at` are alternative ways
/// to phrase the fragment (the core picks one wording per group and joins
/// with a LOCALIZED "for"/"at", never hardcoded English); `subtitle` is
/// free-form detail shown below the title. Only return one for the ref type
/// that means "this operation is happening AT/FOR this reference" (e.g. an
/// activation, not a hunted ref).
export interface TitleSuggestion {
  title?: string
  for?: string
  at?: string
  subtitle?: string
  /// Breaks ties when multiple refs contribute the same fragment kind —
  /// higher wins. Default 0.
  priority?: number
}

/// Where a reference can be read about on the web — the awarding program's own
/// page for it, or, for a contest, its rules.
export interface RefLink {
  url: string
  /// Names the destination for assistive technology. The core supplies a
  /// generic label when this is absent.
  label?: string
}

/// Handles one ref type (registered under category `ref:<type>`).
export interface RefHandlerHook {
  /// Cheap synchronous-ish validation/normalization of user input.
  validateRef?(args: { ref: Ref }, ctx: HookContext): Promise<{ valid: boolean; normalized?: string }>
  /// Enriches a ref with names/locations, possibly via the network.
  decorateRef?(args: { ref: Ref }, ctx: HookContext): Promise<Ref>
  /// Suggests a title/subtitle fragment for the operation this ref is on.
  suggestOperationTitle?(args: { ref: Ref; operation: Record<string, JSONValue> }, ctx: HookContext): Promise<TitleSuggestion | null>
  /// Where to read about this reference on the web. Built from the reference
  /// code alone — never a network call: the core asks for one link per ref on
  /// the operation every time the list changes, and the answer is not stored.
  linkForRef?(args: { ref: Ref }, ctx: HookContext): Promise<RefLink | null>
  /// Where the outline of this reference's own footprint — a summit's SOTA
  /// activation zone, a park's boundary — can be fetched as GeoJSON. Built
  /// from the reference code alone and never a network call, exactly like
  /// [linkForRef]: the core does the fetching, and caches what comes back.
  /// Return `null` for a reference the program publishes no shape for.
  geojsonUrlForRef?(args: { ref: Ref }, ctx: HookContext): Promise<RefGeojson | null>
}

/// Where a reference's outline can be fetched as GeoJSON, and how long the
/// core may keep what it fetches.
export interface RefGeojson {
  url: string
  /// How many days a fetched shape stays usable offline before the core
  /// re-fetches it. Boundaries move on the scale of surveys, not days.
  /// Default 30.
  maxAgeInDays?: number
  /// How many days the core remembers that this reference has NO shape (the
  /// server answered 403/404). Shorter than [maxAgeInDays], so a newly
  /// surveyed zone appears within a day rather than a month. Default 1.
  missMaxAgeInDays?: number
  /// Who the shapes come from, short enough for the map's one-line credit
  /// under the outlines ("OSM", "sotl.as"). Defaults to the URL's host.
  sourceName?: string
}

/// Declarative UI contribution: the core renders these with native widgets
/// from the catalog (DESIGN.md §5). v0 catalog has one input kind.
export interface LoggingControlDescriptor {
  key: string
  label: string
  /// The same name in fewer characters, for a field the logging row has
  /// squeezed below its own label's width — `QP Loc` where [label] is
  /// `QP Location`.
  ///
  /// The core picks between the two by MEASURING [label] against the width the
  /// field was resolved to, so an extension states what the short form is and
  /// never when to use it. Omitted, a label too wide for its field is
  /// ellipsized (docs/design/logging-fields.md, "a field's label must
  /// never wrap") — which names the field no better than nothing does, so any
  /// control whose label runs past about six characters wants one.
  shortLabel?: string
  /// For a control that renders as a main logging field: Space and Tab pass
  /// over it, and only the arrow keys (or a tap) land on it — for a field the
  /// operator visits to correct rather than fill in, like the serial we send.
  /// Default false (docs/design/logging-fields.md, "Moving between the main
  /// fields").
  skipFocus?: boolean
  /// A Material Design Icons name (e.g. 'pine-tree') or, prefixed with
  /// 'fa-', a FontAwesome6 solid-style name (e.g. 'fa-tree') — same
  /// convention as app-polo's own icon rendering. Falls back to a
  /// placeholder glyph if the name isn't found in either set.
  icon?: string
  /// A '#RRGGBB' hex color the core may use sparingly to accent this
  /// control's icon (e.g. a circle background behind it in the activity
  /// picker, or the icon itself once a reference is entered) — an
  /// unrecognized/missing value just means no accent, never an error.
  color?: string
  order?: number
  /// **Not yet honored by the core.** Declared since the original catalog
  /// sketch (DESIGN.md §5) and set by every shipped extension, but nothing in
  /// Dart reads it: `'mandatory'` neither pins the control past the user's
  /// hidden-controls setting nor gates logging. Every current caller passes
  /// `'optional'`, so no behaviour depends on it — but a contest marking its
  /// exchange mandatory would silently get nothing. Implement it or drop it
  /// before a contest relies on it.
  optionType?: "optional" | "mandatory"
  /// Whether a reference of this type has anything to edit once it's on the
  /// operation. Defaults to FALSE: a plain reference activity (POTA, SOTA)
  /// carries only the code its own `suggest` already resolved, so the core
  /// leaves those rows inert — remove and pick again instead of retyping a
  /// code no lookup would re-check. Set true for a type whose references
  /// carry more than that.
  editable?: boolean

  /// Same meaning as `ActivitySuggestion.allowsMultiple`, for references
  /// typed in by hand rather than picked from a suggestion. Defaults to true.
  allowsMultiple?: boolean
  input: InputDescriptor
}

/// The logging-control input catalog (DESIGN.md §5). A new `kind` is earned by
/// a different *widget*, never by different validation — a pattern-constrained
/// field types and focuses exactly like a free-form one, so `pattern` is a
/// modifier on `text` rather than a kind of its own.
export type InputDescriptor = RefListInputDescriptor | TextInputDescriptor | OptionsInputDescriptor | SerialInputDescriptor | FormInputDescriptor

/// Names a sequence of serial numbers within an operation. Declarative on
/// purpose: there is no `allocate()` to call, because by the time any hook sees
/// a QSO the number is already on it. The core allocates once, at commit,
/// inside the QSO insert — which is what makes "rescoring never renumbers" a
/// structural fact rather than a discipline (docs/design/contests.md §5.8).
export interface SequenceBinding {
  /// Names the sequence within this operation and extension. A contest that
  /// needs one flat run of numbers just uses `'serial'`.
  key: string
  /// Separate sequences per band and/or mode — several VHF contests restart
  /// numbering on each band.
  ///
  /// The core resolves the label AT COMMIT from the committed QSO, not from
  /// this descriptor: the descriptor is a snapshot taken when the callsign
  /// lookup resolved, and the operator may still change band before pressing
  /// Enter. Only the core, at commit, knows which band the QSO actually ended
  /// up on.
  scope?: ("band" | "mode")[]
  /// First number issued (default 1) — the operator can override it in
  /// operation settings when they logged the first hour on paper.
  start?: number
  /// Zero-padding for DISPLAY only ('001'); the value is stored as an integer.
  padTo?: number
}

/// An auto-allocated serial number sent as part of the exchange.
///
/// The operator may still type over it (a correction goes out on the air like
/// anything else), and doing so raises the counter rather than renumbering
/// anything else. A period steps the number up and a comma steps it down.
/// It takes its turn in the Space and Tab cycle unless its control says
/// `skipFocus: true`, which every shipped contest does — the arrow keys still
/// reach it for a correction.
export interface SerialInputDescriptor {
  kind: "serial"
  refType: string
  /// `'ourSerial'`, with the received number beside it as `'theirSerial'`:
  /// templates find a contest's serials by these names (`qso.serialSent`,
  /// docs/extensions/templates.md), so any other name keys a blank.
  field: string
  sequence: SequenceBinding
  /// Default true — an operator has to be able to correct what they actually
  /// sent.
  editable?: boolean
}

/// A whole setup form behind one control, for the enum-shaped configuration an
/// operation needs once (a contest's mode, station type, sent exchange) rather
/// than per QSO. Reuses the existing `FormDefinition` schema and renderer
/// instead of growing this union with select/radio/checkbox kinds — the form
/// schema already has them, and per-QSO exchanges never need them.
///
/// Only valid on `operationControls`. The form's values are read from, and
/// saved back onto, the operation's ref of `refType` — the same core-owned path
/// `refList` writes refs through.
///
/// The definition crosses the bridge as JSON, so it must be static: a
/// `FormDefinition.onChange` closure cannot survive the trip.
export interface FormInputDescriptor {
  kind: "form"
  refType: string
  /// References filed under a type this control does not publish, which it
  /// answers for anyway: `['qp/ny']` on the New York QSO Party, matching the
  /// manifest's own `ref:qp/ny` without the prefix.
  ///
  /// `<type>/<code-prefix>`, the code lower-cased and matched as a PREFIX, and
  /// the longest match across every loaded control wins — so a control naming
  /// one reference beats one that claimed the whole family. Nothing is
  /// rewritten: the form reads from, and saves back onto, whichever reference
  /// it matched, keeping that reference's own `type`.
  ///
  /// For a type that used to hold many events in one extension and became one
  /// extension per event: without it the operations logged then show a row
  /// nothing handles, beside an extension that handles it perfectly well.
  alsoHandles?: string[]
  form: FormDefinition
}

/// A free-form or pattern-constrained exchange field (contest exchanges: a CQ
/// zone, a Field Day class, a name). The typed value round-trips onto a ref of
/// `refType` under the key `field` — the same core-owned path `refList` writes
/// refs through, so no new persistence is involved.
export interface TextInputDescriptor {
  kind: "text"
  /// Ref type the value is stored on, e.g. 'simple-contest'.
  refType: string
  /// Key within that ref, e.g. 'exchange' → `{type: 'simple-contest', exchange: '…'}`.
  field: string
  placeholder?: string
  /// Regex source string. The core anchors it (`^(?:…)$`) and matches
  /// case-insensitively — the same compilation `refList` uses, so one pattern
  /// string means the same thing on either kind. A malformed regex disables
  /// validation rather than throwing. The field tints on a mismatch but still
  /// accepts the value: contest rules don't always anticipate what the other
  /// station actually sends.
  pattern?: string
  /// Same live-reformatting passes `refList` supports (see below).
  transforms?: { pattern: string; replacement: string; flags?: string }[]
  /// Numeric keyboard and digits-only filtering (CQ zone, serial).
  numeric?: boolean
  /// Force typed input to uppercase — **the default**, matching every other
  /// logging field and the uppercase-unless-explicitly-mixed-case convention
  /// (`FormField.uppercase` documents the same rule). Set `false` for genuinely
  /// mixed-case exchange data, such as NAQP's operator name.
  uppercase?: boolean
  /// The extra key the mobile numbers row offers after its digits while this
  /// field has focus: one character, such as "-" or "/" (a longer value is
  /// ignored). Without it, or on a host that predates it, the row offers the
  /// operator's decimal separator.
  numbersRowKey?: string
  maxLength?: number
  /// Pre-filled into the field and flagged as a guess: the core writes it only
  /// while the field is empty or still holds a previous suggestion, so a
  /// callsign lookup that resolves late can never clobber operator input.
  /// Use `placeholder` instead for a hint that must never become a value.
  suggestedValue?: string
}

/// A typed exchange that searches a KNOWN SET — QSO-party counties, park
/// abbreviations, sections (docs/design/contests.md §5.3).
///
/// It is a `text` field in every other respect: same primary-field row, same
/// focus cycling, same save and edit round-trip, same suggestion and
/// explicit-blank rules. What it adds is a ranked suggestion line and Space to
/// accept the top hit — Space still advances afterwards, because that is what
/// an operator's hands expect on every field.
///
/// The set is INLINE. A registered `optionSet` for large sets (sketched in
/// §5.3) is deferred: nothing can currently write rows into the
/// lookups table (the host exposes three READ calls and no writer) and the
/// largest set any real contest puts in one descriptor is a few hundred
/// entries — small next to the QSO log the scoring hooks already ship on every
/// pass.
export interface OptionsInputDescriptor {
  kind: "options"
  /// Ref type the value is stored on, as `text`.
  refType: string
  /// Key within that ref.
  field: string
  /// The selectable values. `code` is what goes in the log; `name` is matched
  /// against as well as shown, because a full name is often easier to recall
  /// than an abbreviation.
  options: { code: string; name?: string }[]
  /// Which fields the search looks at. Defaults to both.
  matchOn?: ("code" | "name")[]
  /// Accept a value that isn't in the set. Off by default: for most of these
  /// exchanges an unknown value is a lost multiplier, and the operator can
  /// still fix it while the QSO is in front of them.
  allowFreeform?: boolean
  /// Float likely values to the top of their tier — a QSO party surfacing the
  /// counties of the caller's guessed state. Ranking rather than pre-filling,
  /// because a location guess is wrong often enough to be annoying, and an
  /// exact code the operator typed in full is never displaced by it.
  preferredCodes?: string[]
  /// Several values in one field, separated by [separator] — a QSO party's
  /// county line, `ORDES/JEF`. Every token is matched, validated and shown
  /// against the same option set; the suggestion line and the SPACE shortcut
  /// act on the token the cursor is in, so accepting one never rewrites the
  /// ones already typed.
  ///
  /// The separator has to be a character the field accepts: `numeric` and any
  /// `pattern` still apply to the whole field, so a numeric multi-value field
  /// would strip a `/` as it was typed.
  ///
  /// `inheritPrefix` lets a later value borrow the first one's opening
  /// characters — the multi-state QSO parties let `ORDES/JEF` stand for
  /// `ORDES/ORJEF`. It is applied when MATCHING and VALIDATING, never by
  /// rewriting the field: which of the two a half-typed `IDA` is (Idaho county,
  /// or the first letters of `IDIDA`) cannot be known until the operator stops
  /// typing, so a field that rewrote as you typed would corrupt one of them.
  multiValue?: { separator: string; inheritPrefix?: number }
  /// Hold the suggestion line back until this many characters are typed.
  ///
  /// SPACE never acts on less than one character either way: with no minimum, an
  /// empty field's suggestion list is the whole set, and Space — which an operator
  /// presses to leave a field they were never given a value for — would otherwise
  /// accept whichever option happened to be declared first. Space also only
  /// accepts a suggestion the typed text is a PREFIX of; a substring hit is shown
  /// but never swapped in.
  minCharsForSuggestions?: number
  placeholder?: string
  /// As `text` — uppercase is the default.
  uppercase?: boolean
  /// As `text`.
  numbersRowKey?: string
  maxLength?: number
  suggestedValue?: string
  /// The same three modifiers `text` takes, honoured identically here because the
  /// core builds both kinds from one code path: an anchored, case-insensitive
  /// `pattern`, live-reformatting `transforms`, and a numeric keyboard. A
  /// `pattern` tints in ADDITION to the set check, so a contest whose codes have a
  /// shape can say so as well as list them.
  pattern?: string
  transforms?: { pattern: string; replacement: string; flags?: string }[]
  numeric?: boolean
}

export interface RefListInputDescriptor {
  kind: "refList"
  refType: string
  placeholder?: string
  /// Regex source string; the core pre-validates input before accepting a chip.
  pattern?: string
  /// Ordered live-reformatting passes, applied to the raw text on every
  /// keystroke by the core's native input widget (no extension round-trip
  /// while typing). Each is a regex `pattern` (source string) + `replacement`
  /// using braced `${1}`/`${2}`… group placeholders (NOT bare `$1`/`$2` — a
  /// replacement can concatenate a group directly against a literal that
  /// starts with a digit, e.g. a DXCC prefix like "3D2", and bare `$13`
  /// would misparse as group 13), run like a global find/replace — mirrors
  /// app-polo's per-keystroke `textTransformer` chains (e.g. turning
  /// "US1234" into "US-1234"), but declared once per `loggingControls`/
  /// `operationControls` call instead of executed in the runtime per keypress.
  transforms?: { pattern: string; replacement: string; flags?: string }[]
  /// As `TextInputDescriptor.numbersRowKey`, except that a reference field
  /// offers "-" without it, since nearly every program's codes join a prefix
  /// to digits with one. Declare another character for codes that don't.
  numbersRowKey?: string
}

/// A candidate activity/reference offered to the user while adding an
/// activity — same shape as `Ref` plus ranking info. `distance` is km from
/// the `location` given in `SuggestArgs` (omitted if either side lacks a
/// location); `relevance` is an extension-defined 0..1 match quality (search
/// term match, popularity, etc — higher is better). The core sorts combined
/// results across all extensions by `distance / relevance` ascending (a
/// more relevant hit effectively counts as closer), so extensions should
/// return both as consistently comparable as possible.
export interface ActivitySuggestion extends Ref {
  distance?: number
  relevance?: number
  /// Whether an operation may carry more than one reference of this type at
  /// a time. Defaults to FALSE — selecting a reference REPLACES the
  /// operation's existing one of that type. Set true for a type that
  /// genuinely stacks (POTA n-fers, multiple hunted refs). Declare the same
  /// value on the type's `LoggingControlDescriptor` so manually-typed
  /// references behave the same.
  allowsMultiple?: boolean
}

/// A box on the map in degrees. `west` greater than `east` means the box
/// crosses the antimeridian.
export interface MapBounds {
  south: number
  west: number
  north: number
  east: number
}

export interface SuggestArgs {
  operation: Record<string, JSONValue>
  /// The operation's own location if set, otherwise the station's default —
  /// resolved by the core before calling, since operations don't always
  /// carry their own location. When the operator pans the results map, the
  /// map's new centre instead: answer "what is near here" all the same.
  location?: { lat: number; lon: number }
  /// Same fallback rule as `location`: operation's callsign if set, else the
  /// station default.
  callsign?: string
  searchTerm?: string
  /// The map's viewport, when the operator panned the Activities results map:
  /// answer with every reference inside it rather than the nearest few, so
  /// the whole view fills in. Arrives with `location` at its centre and no
  /// `searchTerm`. `nearbyLookupRows` reads either case.
  bounds?: MapBounds
  /// True when THIS extension alone was asked — the operator tapped its row in
  /// "Activity Types", or typed its key as a scope (`cwt:`). The nearby list
  /// and a bare scope both arrive with no `searchTerm`, and they are different
  /// questions: an extension that keeps itself out of the nearby list (a
  /// date-gated contest) still has to answer when it is the one being asked.
  scoped?: boolean
}

export interface ActivityHook {
  /// Controls shown on the logging panel for this operation. `qso` is the
  /// in-progress QSO (including any `their.guess` data from the callsign
  /// lookup pipeline) — re-supplied whenever that lookup resolves, not on
  /// every keystroke, so extensions can key a dynamic `placeholder`/
  /// `transforms` (e.g. a DXCC-derived reference prefix) off it.
  loggingControls?(args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
  /// Controls shown in operation settings (e.g. "which park am I activating").
  operationControls?(args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
  /// Candidate activities for the "add activity" search/suggestions list —
  /// nearby references when `searchTerm` is empty, name/code matches when set.
  suggest?(args: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]>

  /// Last chance to shape a QSO before it is written, so an extension can
  /// project data it owns into the generic QSON fields the rest of the app
  /// reads. A contest keeps its exchange on its own ref — `theirZone`,
  /// `theirSerial`, `theirExchange` — which nothing generic knows how to
  /// read; mirroring it into `their.exchange` is what puts it in the QSO
  /// row's exchange column and in a plain ADIF export.
  ///
  /// Returns a PATCH to merge, not a mutated QSO: hooks are JSON in, JSON out
  /// and never hold app state. The patch merges shallowly, except `our` and
  /// `their`, which merge one level deep — so `{their: {exchange: 'ZN14'}}`
  /// sets that one field and leaves `their.call` alone. Return null to do
  /// nothing, which is what an operation not running your activity should do.
  ///
  /// Only called when the operation carries a ref of a type you contribute
  /// controls for, so ordinary non-contest logging costs no bridge crossing.
  ///
  /// NOT visible here: a serial the CORE allocates at commit
  /// (docs/design/contests.md §5.8). In the normal single-QSO path the number
  /// is already on the ref by now, because the panel writes the number it
  /// displayed; but for the second and later calls of a call list it is issued
  /// after this hook has run, so don't derive anything that must hold for
  /// every QSO from it.
  ///
  /// `operation` is the SEGMENT-EFFECTIVE one for this contact — on a
  /// segmented log, the operation as it stood when the contact was made, not
  /// as it stands now — so an edit of an old contact projects what was true
  /// then, and nothing here needs to stamp a value to protect it from a
  /// later re-run.
  processQsoBeforeSave?(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null>
}

/// Contributes extra ADIF fields per QSO (registered under 'adifFields').
///
/// A field NAME is written once per record: the first to carry a value wins and
/// the rest are dropped. Hooks come first — the export's own program, then the
/// ones it lists in `includeFieldsFrom` — and the contact's own fields fill
/// whatever no hook answered. A hook cannot claim the fields that identify the
/// contact (CALL, QSO_DATE, TIME_ON, QSO_DATE_OFF, TIME_OFF, BAND, FREQ, MODE,
/// SUBMODE, STATION_CALLSIGN, OPERATOR); an answer naming one is dropped.
///
/// The full ADIF export asks this hook only about a contact whose operation or
/// own refs carry a reference this extension claims, through a `ref:<type>` or
/// `ref:<type>/<code>` hook, as precisely as any other extension does — unless
/// the manifest sets
/// `adifFieldsScope: "always"` (docs/extensions/hooks.md). A program's own
/// export asks it by name, whatever the contact carries.
export interface AdifFieldsHook {
  /// `operation` is the SEGMENT-EFFECTIVE one for this contact — the core
  /// ADIF generator resolves it from `ExportRequest.segments` before asking —
  /// so a rover's county or a contest's setup is what was true when the
  /// contact was made.
  ///
  /// `mainHandler` is true when the file is this extension's own export — the
  /// one place a program can write what only its own submission asks for.
  fieldsForOneQSO(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue>; mainHandler?: boolean },
    ctx: HookContext,
  ): Promise<{ name: string; value: string }[]>
}

/// One imported ADIF record's contribution from one hook.
///
/// An object rather than a bare `Ref[]` so that the other things an importer
/// might eventually owe a QSO — a contest serial out of `STX`/`SRX`, an
/// exchange — are an additive change here rather than a breaking one.
export interface AdifImportResult {
  refs?: Ref[]
}

/// Turns imported ADIF fields back into QSON references (registered under
/// 'adifImport'). The mirror of `adifFields`: an extension that knows how to
/// WRITE its program's fields is the only thing that knows how to read them.
///
/// The core maps universal ADIF only and produces NO refs at all, so an
/// import with no `adifImport` hook registered yields ref-less QSOs — this is
/// the whole ref vocabulary on import, not a refinement of a core guess.
///
/// **Batched, unlike every other per-QSO hook.** `adifFields` runs inside the
/// runtime where a per-QSO call is free; this one is driven from Dart, and a
/// bridge crossing per QSO would make a ten-thousand-contact import
/// unusable. One call carries a slice of the file.
///
/// Return one entry per record, positionally — `null` for a record this hook
/// has nothing to say about. A returned array of the wrong length is
/// discarded whole, since there is no safe way to guess which records its
/// entries meant.
export interface AdifImportHook {
  refsForRecords(args: { records: { fields: Record<string, string> }[] }, ctx: HookContext): Promise<(AdifImportResult | null)[]>
}

/// Settings shared by every extension offering the same registered export type.
export interface ExportSettings {
  includePrivateData?: boolean
  includeLookupData?: boolean
  customTemplates?: boolean
  filenameTemplate?: string
  compactFilenameTemplate?: string
  titleTemplate?: string
  adifNotesTemplate?: string
  adifCommentTemplate?: string
  adifQslMessageTemplate?: string
}

/// Global filename/title defaults are independent for reference and other activities.
export interface GlobalExportSettings extends ExportSettings {
  referenceFilenameTemplate?: string
  referenceCompactFilenameTemplate?: string
  referenceTitleTemplate?: string
  otherFilenameTemplate?: string
  otherCompactFilenameTemplate?: string
  otherTitleTemplate?: string
}

export interface ExportTypeDefinition {
  /// Global settings identity. Prefer `<activationType>-<format>` so another
  /// extension serving the same activity can reuse it.
  exportType: string
  label: string
  format: string
  activationType?: string
  templateCategory?: "reference" | "other"
  defaults?: ExportSettings
  /// Illustrative operation/log values used by the template editor.
  templateSample?: Record<string, JSONValue>
}

export interface ExportRequest {
  exportSettings?: ExportSettings
  /// Metadata of the selected file for templates, preserved through delegation.
  exportData?: Record<string, JSONValue>
  exportTitle?: string
  includeLookupData?: boolean
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
  /// Present only when the operation has segments — the same payload
  /// `ScoreQsosRequest` carries, so a file can say what was true for EACH
  /// contact (a rover's county, the call at the key) the way the scorer does.
  /// `operationForQso` resolves one contact's operation from it.
  segments?: OperationSegmentPayload[]
  /// The operation's event rows — `break`, `start`, notes — as stored, for a
  /// file that writes the log's timeline. Never in [qsos], which holds
  /// contacts alone. Present only when there are any.
  events?: Record<string, JSONValue>[]
  /// Stable kind of export, as returned by `suggestExportOptions`.
  exportType?: string
  /// Selected option identity, passed back unchanged. Defaults to exportType
  /// when the option omits exportKey.
  exportKey?: string
  /// The user's "Use compact file names" setting. Pass it straight to
  /// `exportFilename` rather than branching on it: see exportNames.ts.
  compactFilenames?: boolean
  /// Whether this file may carry the operator's private notes about the
  /// stations they worked — names, towns, gridsquares, QSO notes. False for
  /// almost every export: a file uploaded to a program's servers should
  /// carry the contact, not the operator's own notes about who they met.
  ///
  /// A hook that DELEGATES to another (the contests and activity exports all
  /// call the core `adif` generator) must forward this, or the delegate will
  /// default to withholding and the user's setting will silently not apply.
  includePrivateData?: boolean
  /// The extension whose export this file IS — app-polo's "main handler"
  /// (`qsonToADIF`'s `handler`). A file submitted to one program is that
  /// program's log: the core `adif` generator asks THAT extension's
  /// `adifFields` hook for the program fields and no one else's, the way polo
  /// asks only its main handler. Activate a park that is also a lighthouse
  /// and each file claims its own reference; ask every hook and both
  /// programs' `MY_SIG`/`MY_SIG_INFO` pairs land in every record, leaving the
  /// receiving program to guess which is its.
  ///
  /// A hook that DELEGATES the ADIF build must name itself here, since the
  /// delegate cannot know who called it.
  ///
  /// Omitted, every `adifFields` hook contributes — polo's `includeOtherRefs`,
  /// which only its full ADIF export sets. That is the export claiming no
  /// program: the complete copy the operator keeps.
  mainHandler?: string
  /// Other extensions' `adifFields` hooks this file wants anyway, by key —
  /// polo's `includeOtherRefs` narrowed from "everyone" to a named list.
  ///
  /// For what DESCRIBES the contact rather than claiming it: POTA takes
  /// `satellites`, because a park worked through a bird is still a park
  /// activation and POTA's uploader reads `PROP_MODE`/`SAT_NAME`. It is the
  /// main handler's judgement about what its own program accepts, so the
  /// listing lives with the export, not with the extension being listed.
  ///
  /// Unlike `mainHandler`, a key here that no hook answers is not an error:
  /// the operator may simply have that extension turned off, and this file is
  /// still the program's log without it.
  ///
  /// Ignored without a `mainHandler` — that export already has every hook.
  includeFieldsFrom?: string[]
  /// What OPERATOR says on a record whose contact names no operator of its
  /// own. Omitted, the record carries none, and the core writes OPERATOR only
  /// where it says something STATION_CALLSIGN doesn't. Set, every record
  /// carries one: the contact's own operator if it has one — even when that
  /// repeats the station call — or else the station call (`'station'`) or its
  /// base call (`'base'`: "KI2D" for "VE3/KI2D/P"), for a program whose
  /// uploader credits the operator by OPERATOR on every record.
  ///
  /// The file's own setting rather than an `adifFields` answer, because
  /// OPERATOR identifies the contact and hooks cannot write it.
  operatorFallback?: OperatorFallback
}

export type OperatorFallback = "base" | "station"

export interface ExportResult {
  filename: string
  mimeType: string
  content: string
}

export interface ExportOptionsRequest {
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
  /// The user's "Use compact file names" setting, so the `filename` a hook
  /// offers here is the one the panel shows AND the one that gets written.
  compactFilenames?: boolean
}

/// One selectable export offered by a hook. The core routes generation by
/// the hook registration key and passes back both exportType and exportKey.
export interface ExportOption {
  /// Number of contacts after hook-specific filtering; otherwise derived by
  /// the host from refType and station scope.
  qsoCount?: number
  /// File-specific template values under `log` (ref, refName, activity, modifier…).
  templateData?: Record<string, JSONValue>
  /// Stable export kind, shared by instances such as individual park logs.
  exportType: string
  /// Unique option identity within this hook, e.g. "pota-adif:US-1234".
  /// Omit when this hook offers only one option of this exportType; the core
  /// then uses exportType as the key. Keep it stable across option reloads.
  exportKey?: string
  /// Drives the panel's default mimeType/extension guess, e.g. 'adif'.
  format: string
  label: string
  /// What the file will be called. The panel shows this, and the core writes
  /// the file under it — a name offered here WINS over the one
  /// `generateExport` returns, so the two can't disagree in front of the
  /// user. Build it with `exportFilename` so the compact-names setting
  /// applies. Omit it only if the name genuinely can't be known until the
  /// content exists.
  filename?: string
  /// Icon for the panel row, by name (see `resolveIconName`). Omit it and an
  /// export that names a `refType` inherits its activity's icon, exactly as
  /// `color` below inherits the accent — a contest's files are the contest's
  /// without saying so. Set it only for an export that belongs to no activity
  /// or wants a glyph of its own; a name that doesn't resolve falls back to
  /// the activity's too.
  icon?: string
  /// Accent color for the panel row's icon, as `#RRGGBB`. Omit it and an
  /// export that names a `refType` inherits its activity's accent (POTA's
  /// green), while one that names none gets the app's own. Set it only to say
  /// something the activity can't — the whole-log ADIF uses a neutral grey
  /// precisely because it belongs to no activity.
  color?: string
  /// Declares that this export carries EVERYTHING, including private data,
  /// whatever the user's setting says — for the whole-log backup, whose
  /// entire purpose is to be complete. Every other export respects the
  /// setting.
  alwaysIncludePrivateData?: boolean
  priority?: number
  selectedByDefault?: boolean
  /// The ref type this export is responsible for. Set it and the core hands
  /// `generateExport` only the QSOs made while that activity was actually
  /// running — those in segments carrying a ref of this type (§5.1.4).
  ///
  /// A contest that started at a break, or ended at one, otherwise puts the
  /// WHOLE operation into its Cabrillo, including contacts made when it wasn't
  /// running. That is a false claim in a submitted file — the same mistake
  /// §5.1.3 gates in the scorer.
  ///
  /// Omit it for an export that genuinely covers the whole log, like the full
  /// ADIF. On an unsegmented operation it changes nothing either way.
  refType?: string
  /// The one reference of `refType` this export claims — one park's file
  /// among several. The core then hands `generateExport` only the QSOs from
  /// segments carrying THAT reference, so a park activated after a break
  /// doesn't claim the contacts made at the one before it (§5.1.4). Omit it
  /// for an export covering every reference of the type, like a contest's.
  ref?: string
}

export interface ExportHook {
  /// Registered independently of any operation, for the export settings UI.
  getExportTypes?(args: Record<string, never>, ctx: HookContext): Promise<ExportTypeDefinition[]>
  /// Lists the export(s) this hook offers for the given operation/qsos, for
  /// the Exports Panel to show as selectable options. A hook that omits
  /// this never appears in the panel.
  suggestExportOptions?(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult>
}

/// Per-QSO verdict from one scoring rule (dupe check, DXCC entity worked,
/// band/mode worked, etc). `value` is the point contribution (usually 0 or 1);
/// `dupe`/`notices`/`alerts` drive UI badges on the QSO row.
export interface QsoScoreVerdict {
  value: number
  dupe?: boolean
  notices?: string[]
  alerts?: string[]
  [extra: string]: JSONValue | undefined
}

/// One scorer's verdict for one QSO. A scorer's internal *rules* (core's
/// dupe/dxcc/bands split, a contest's points-and-mults logic) stay private to
/// its scoresheet — contests don't share a rule vocabulary, so only notices,
/// alerts and points cross this boundary.
///
/// `qsos.score_cache` holds one of these per active scorer, keyed by scorer:
/// `{core: {...}, cqww: {...}}`.
export type QsoScoreEntry = Record<string, QsoScoreVerdict>

/// One rule's running tally, either for a calendar day or the whole
/// operation. Shape is rule-specific beyond the common summary fields.
export interface ScoreTally {
  key: string
  for: "day" | "operation"
  icon?: string
  label?: string
  summary?: string
  longSummary?: string
  /// `longSummary` is a strikethrough checklist grid — every code in a fixed
  /// set, `**~~worked~~**` for the ones already had — rather than prose. The
  /// information panel renders this shape as a monospace grid with worked
  /// codes at full strength and the rest dimmed, so any scorer with a
  /// fixed-set checklist of its own (a contest's multiplier list, an
  /// activity's award grid) can opt into the same treatment core's own
  /// states-and-provinces checklist uses — set true, not the display detail.
  grid?: boolean
  total: number
  [extra: string]: JSONValue | undefined
}

/// One calendar-day bucket (UTC, following app-polo/web-lofi's convention)
/// with that day's accumulated tallies per rule key.
export interface DayScoreSummary {
  day: number
  /// Contacts this pass folded on the day. On a pass resumed from a checkpoint
  /// that is the tail's share of the day, not the day's total — the tallies in
  /// `scores` continue the checkpoint; this count does not.
  count: number
  scores: Record<string, ScoreTally>
}

/// One stretch of a log and the operation that was true for it — the core's
/// resolution of `break`/`start` segment overrides (docs/design/contests.md
/// §5.1.3), sent so the harness can hand each QSO its own operation.
export interface OperationSegmentPayload {
  /// When this segment takes over. A QSO at exactly this instant belongs to it.
  fromMillis: number
  /// The FULL operation for this stretch, already resolved — base operation
  /// with this segment's override applied. Not a diff.
  operation: Record<string, JSONValue>
}

export interface ScoreQsosRequest {
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
  /// Present only when the operation actually has segments. The harness uses
  /// it to give `scoreQso` the segment-effective operation for each QSO; a
  /// scorer written against `operation` alone needs no change.
  segments?: OperationSegmentPayload[]
  /// The operation ref that selected this scorer (§5.1) — carries its setup
  /// (contest identifier, sent exchange, mode). Absent for `scope: 'always'`
  /// scorers like `core`.
  ref?: Record<string, JSONValue>
  /// A scoresheet checkpoint from an earlier pass. When present, `qsos` is only
  /// the tail to replay from that point rather than the whole log, so appending
  /// a QSO doesn't re-fold the operation.
  resumeFrom?: JSONValue
  /// The day `resumeFrom` ends on — `ScoreQsosResult.scoresheetDay` from the
  /// pass that produced it. Without it the first contact of the tail reads as
  /// a new day whatever its time, and a scorer that resets per-day state on
  /// that flag resets it mid-day.
  resumeDay?: number
  /// The host's name for the checkpoint this pass resumes from. Beside
  /// `resumeFrom`, the harness files the sheet under it; alone, the harness
  /// resumes from the sheet it already holds under that name, and throws
  /// `resume-missing` when it holds none — the host then sends the sheet.
  resumeKey?: string
  /// The host's name for the checkpoint this pass PRODUCES. The harness keeps
  /// the end sheet under it, so the live paths can name it instead of sending
  /// it back across the bridge on every keystroke.
  checkpointKey?: string
}

export interface ScoreQsosResult {
  /// Keyed by QSO uuid — this scorer's verdict for each. The core nests these
  /// under the scorer's key before writing `qsos.score_cache`.
  qsoScores: Record<string, QsoScoreVerdict>
  daySections: DayScoreSummary[]
  /// Cumulative tallies across the whole operation (last day section's
  /// running totals) — cached on the operation, not any one QSO.
  operationSummary: Record<string, ScoreTally>
  /// End-of-pass scoresheet, cached by the core and handed back as
  /// `resumeFrom` on the next append and on the live paths.
  scoresheet?: JSONValue
  /// True when the harness kept the end sheet under `checkpointKey`. The host
  /// names a checkpoint only to a harness that has said this; one built on an
  /// SDK without the cache never does, and keeps receiving the sheet.
  checkpointHeld?: true
  /// The day (UTC midnight, millis) the pass ended on, to hand back as
  /// `resumeDay` beside `scoresheet`. Absent when the pass folded nothing.
  scoresheetDay?: number
}

/// Scores a single in-progress (not-yet-logged) QSO for the logging panel's
/// live call-info line — the callsign being typed, before Enter. Distinct from
/// the batched `scoreQsos`: this returns only the display notices/alerts for
/// one candidate, scored against the rest of the operation's log (read via
/// `ctx.getQsos`). `excludeUuid` drops the record being edited so it can't
/// flag itself as its own duplicate.
export interface ScoreQsoRequest {
  /// The operation as it stands NOW — the last segment, not the base — because
  /// the candidate is being logged now. The host selects scorers from this same
  /// shape, so a contest that ended at a break is never invoked here.
  operation: Record<string, JSONValue>
  qso: Record<string, JSONValue>
  excludeUuid?: string
  ref?: Record<string, JSONValue>
  /// Present only when the operation has segments, and only used for the
  /// rebuild from the log: the history the candidate is judged against is
  /// scored under each QSO's own segment. Without it a contest's dupe check
  /// counts contacts made before it started.
  segments?: OperationSegmentPayload[]
  /// Same checkpoint as `ScoreQsosRequest.resumeFrom`: the cached
  /// end-of-log scoresheet, so the candidate can be scored against it directly
  /// instead of re-folding the whole log on every keystroke.
  resumeFrom?: JSONValue
  /// As `ScoreQsosRequest.resumeDay`: the day `resumeFrom` ends on.
  resumeDay?: number
  /// With a checkpoint: the contacts logged SINCE it, replayed onto it before
  /// the candidate is scored — the second or two between a contact and the
  /// rescore that folds it, which is exactly when the next call is being
  /// typed. Only contacts the checkpoint has not seen belong here; a
  /// checkpoint cannot un-fold a contact, so an edit or a delete means no
  /// checkpoint at all. Ignored without one.
  qsos?: Record<string, JSONValue>[]
  /// As `ScoreQsosRequest.resumeKey`: the checkpoint's name. Alone, it stands
  /// for `resumeFrom`; the harness throws `resume-missing` when it holds no
  /// such checkpoint.
  resumeKey?: string
}

/// Merged, de-duped notice/alert keys for one candidate QSO — e.g.
/// `{ alerts: ['duplicate'], notices: ['newBand', 'newDXCC'] }`. The app layer
/// maps each key to localized pill text; unknown keys fall back to the key.
export interface QsoScoreNotices {
  notices: string[]
  alerts: string[]
  /// Whether this scorer's duplicate test ran, and what it concluded. Omitted
  /// means it never ran — an early return on an invalid band or a missing
  /// exchange — and the host then leaves the core scorer's own dupe rule
  /// standing, since nobody else has ruled (docs/design/contests.md §5.1).
  dupe?: boolean
  /// From `scoreQso` only: the checkpoint the request named is held, as
  /// `ScoreQsosResult.checkpointHeld`.
  checkpointHeld?: true
}

/// Scores MANY not-yet-logged candidates in one call — the Spots Panel, which
/// annotates every spot on screen against the operation's log (worked already?
/// new band? new multiplier?). Same judgement as `scoreQso`, batched for the
/// same reason `scoreQsos` exists: a few hundred spots must not mean a few
/// hundred bridge crossings.
///
/// Each candidate is judged against the log ALONE, never against the others —
/// two spots for the same unworked call are both "not worked", and neither
/// makes the other a duplicate.
export interface ScoreCandidatesRequest {
  /// The operation as it stands NOW, exactly as `ScoreQsoRequest.operation`.
  operation: Record<string, JSONValue>
  /// The candidates, each with a caller-chosen `key` the results come back
  /// under. Candidates have no uuid — a spot is not a record — so the key is
  /// whatever the caller can match up afterwards.
  candidates: { key: string; qso: Record<string, JSONValue> }[]
  ref?: Record<string, JSONValue>
  segments?: OperationSegmentPayload[]
  /// The cached end-of-log scoresheet, as `ScoreQsoRequest.resumeFrom`.
  resumeFrom?: JSONValue
  /// As `ScoreQsoRequest.resumeDay`.
  resumeDay?: number
  /// As `ScoreQsoRequest.qsos`: the tail since the checkpoint.
  qsos?: Record<string, JSONValue>[]
  /// As `ScoreQsoRequest.resumeKey`.
  resumeKey?: string
}

/// Keyed by `ScoreCandidatesRequest.candidates[].key`. Every candidate comes
/// back, including ones with nothing to report — a scorer answers for what it
/// was asked about, and dropping the quiet ones would make "this scorer had no
/// opinion" indistinguishable from "this scorer never ran" at the hook
/// boundary. Whether a caller keeps the empty entries is its own business:
/// the host merges across scorers and drops them, since a merged empty verdict
/// carries nothing either way.
/// One entry is not a candidate's: `$checkpointHeld: true`, present when the
/// request named a checkpoint the harness holds — as `checkpointHeld` on the
/// other answers. A caller's key never starts with `$`.
export type ScoreCandidatesResult = Record<string, QsoScoreNotices> & { $checkpointHeld?: true }

/// Registered under category `scoring`. One coarse batched call scores an
/// entire operation's QSOs at once (DESIGN.md §4: "score 500 QSOs in one
/// call, not 500 calls") — day-sectioning and accumulation both happen here,
/// inside the runtime, not orchestrated call-by-call from Dart. `scoreQso`
/// is the live single-candidate path used while typing a callsign.
///
/// Authors don't normally implement this directly: write a `ContestScorer` and
/// wrap it with `contestScorer()`, which supplies the loop, the day
/// checkpoints, resume, and the live path.
export interface ScoringHook {
  scoreQsos(args: ScoreQsosRequest, ctx: HookContext): Promise<ScoreQsosResult>
  scoreQso?(args: ScoreQsoRequest, ctx: HookContext): Promise<QsoScoreNotices>
  scoreCandidates?(args: ScoreCandidatesRequest, ctx: HookContext): Promise<ScoreCandidatesResult>
}

/// Which operations a scorer applies to. `'always'` scores every operation
/// (DXCC, states, bands-and-modes); a `refTypes` list scores only operations
/// carrying one of those refs, so the core can skip a contest entirely rather
/// than invoke it to be told "not mine". Declared at `registerHook` time.
///
/// `huntingRefTypes` additionally selects the scorer for an operation that
/// never names it, when a ref of one of those types appears in the LOG or in
/// the work being scored — the ordinary chaser, whose operation activates
/// nothing (docs/design/activities.md §4).
///
/// It is a SEPARATE list from `refTypes` on purpose, and a contest declares
/// none. A contest's ref type rides its QSOs as exchange data (`{type: 'cqww',
/// theirZone}`), so a rule reading "any ref type in the log" would resurrect a
/// contest that a `break` has already ended, or one removed from the operation
/// outright — the opposite of what segments exist for. Only a program that is
/// genuinely HUNTED contact by contact belongs here.
export type ScoringScope = "always" | { refTypes: string[]; huntingRefTypes?: string[] }

/// A scorer's running record while it works through a log: worked calls, mult
/// sets, running points. Opaque to the core and owned by the scorer, so it must
/// be JSON-serializable (sets → arrays) — the core snapshots it as a checkpoint.
export type Scoresheet = JSONValue

/// The contract a contest implements. Three pure functions, named for the
/// scoring process; the core owns the loop, the checkpointing and the live
/// path, so caching and incremental rescoring are written once here rather than
/// re-derived in every contest.
export interface ContestScorer<S extends Scoresheet = Scoresheet> {
  /// A blank scoresheet. `ref` carries this contest's setup off the operation.
  startScoresheet(args: { operation: Record<string, JSONValue>; ref?: Record<string, JSONValue> }, ctx: HookContext): S

  /// Score ONE QSO against the scoresheet so far. No I/O. This single function
  /// serves the full pass, an append, a mid-log replay AND the live in-progress
  /// QSO — for the live case the returned scoresheet is discarded.
  ///
  /// **May mutate `scoresheet` and return it.** Copying the accumulated state
  /// per QSO is quadratic: measured on a 5,000-QSO contest log it cost 289ms
  /// versus 18ms for 1,000 — 5x the QSOs for 16x the time, all of it spreading
  /// the worked-call map. The harness takes one defensive copy of any resume
  /// checkpoint it is handed, so a scorer that mutates can never corrupt a
  /// cached scoresheet, and the fold stays linear.
  ///
  /// `operation` is the segment-effective operation for this QSO once segments
  /// land, so a rover's current grid is simply what the scorer reads.
  scoreQso(
    args: {
      scoresheet: S
      qso: Record<string, JSONValue>
      operation: Record<string, JSONValue>
      ref?: Record<string, JSONValue>
      /// True when this QSO opens a new UTC day. The harness computes day
      /// boundaries anyway (for sectioning), so it reports them rather than
      /// every scorer re-deriving the same rollover — reset day-scoped
      /// counters here. False for the live candidate.
      isNewDay: boolean
    },
    ctx: HookContext,
  ): { scoresheet: S; score: QsoScoreVerdict }

  /// Render the scoresheet into display tallies. The tally keys are the
  /// scorer's own — nothing outside interprets them.
  summarizeScore(
    args: {
      scoresheet: S
      operation: Record<string, JSONValue>
      ref?: Record<string, JSONValue>
      scope: "day" | "operation"
    },
    ctx: HookContext,
  ): Record<string, ScoreTally>
}

/// What a program says of itself — plain data on its `chasing` hook, read
/// across every extension in one call without invoking anything
/// (docs/design/claims.md §2).
export interface ChasingProgram {
  label: string
  icon?: string
  color?: string
  /// Raise it whenever the same contacts would claim something different —
  /// a rule changed, a reference list was corrected. The app keeps no claim
  /// from an older version.
  version: number
  /// `annual` and `event` programs put an `edition` on every claim; a
  /// `lifetime` program leaves it out. An `annual` program names each
  /// edition by the contact's UTC year (`'2026'`): the year is how the app
  /// tells which checklist is the current one.
  editions: "lifetime" | "annual" | "event"
  /// Scoring notices this program's verdicts stand in for (`newDXCC` for
  /// DXCC): wherever the program judges a call or a spot, the app shows its
  /// verdict and drops the scorer's notice, rather than two pills saying
  /// "new" about different checklists.
  supersedes?: string[]
  /// What one reference of the checklist is called where a notice names it
  /// ("New POTA Park"). The program's `label` when left out.
  refLabel?: string
  /// The kinds of file `importClaims` reads — a sponsor's export, each its own
  /// batch. Listed as data so the app can offer an importer for a file by its
  /// extension before calling anything.
  imports?: ChasingImporter[]
}

/// One kind of file a program imports claims from.
export interface ChasingImporter {
  /// Names the batch: importing a file of the same kind again replaces every
  /// claim the last one gave.
  key: string
  label: string
  /// File extensions it reads, without the dot (`["csv"]`).
  extensions: string[]
}

/// One record of an imported file: a claim no contact in the log stands
/// behind. A sponsor's export is the sponsor's word for the slot, so the
/// level is whatever the sponsor's records say — `verified` for a credited
/// reference.
export interface ImportedClaim extends QsoClaim {
  /// When the slot was earned, in epoch millis, if the file says.
  at?: number
  /// The contact the record describes, if the file says, for matching it to
  /// a contact in the log. Not yet read by the app (claims.md §9).
  match?: { theirCall?: string; startAtMillis?: number; band?: string; mode?: string }
}

/// worked: a contact counts toward the slot. confirmed: that contact has a QSL
/// the program accepts. verified: the sponsor credited that contact to the
/// award (`qso.credits.<program>`).
export type ClaimLevel = "worked" | "confirmed" | "verified"

/// One line of a program's checklist that a contact fills. The slot it fills
/// is `(program, holder, edition, ref, band, mode)`; the app keeps the best
/// claim per slot — a higher level, then the earlier contact.
export interface QsoClaim {
  /// Who can claim it, in the program's own terms: a call, a call per entity
  /// (`KI2D@291`), a call at a place (`KI2D@FN21`). Opaque to the app.
  holder: string
  ref: string
  /// The band this claim is for, or null for any band.
  band: string | null
  /// The program's own mode grouping (`CW`, `PHONE`, `FT8`…), or null for any
  /// mode. The app never maps modes for a program.
  mode: string | null
  /// For `annual` and `event` programs, which one (`'2026'`).
  edition?: string
  level: ClaimLevel
  /// What lifted it above worked: `lotw`, `qsl`, the sponsor's key…
  by?: string
  label?: string
  /// The ref is inferred — from the callsign, a lookup — not reported by the
  /// other station. Shown as "probably".
  guess?: boolean
}

/// One filled slot, as the app hands a holder's checklist back to the program.
export interface ClaimSlot {
  ref: string
  band: string | null
  mode: string | null
  level: ClaimLevel
  label?: string
}

/// What a program's checklist reads as, for one holder and edition. A
/// `ScoreTally` without the scoring period it does not have.
export type ClaimsTally = Omit<ScoreTally, "for">

/// The `chasing` hook: one registration per program, keyed by the program's
/// key (docs/design/claims.md).
export interface ChasingHook {
  program: ChasingProgram

  /// What each contact claims, keyed by its `uuid`. A pure function of each
  /// contact and the extension's own reference data: it never reads the log,
  /// which is what lets the app ask it about a spot, or about a contact on a
  /// device that holds only part of the log. One contact usually claims
  /// several slots — one per granularity the program tracks. A contact's
  /// `our` carries the place it was made from (`grid`, `lat`/`lon`): its own,
  /// else its operation's, for a program whose holder is a call at a place.
  claimsForQsos(args: { qsos: Record<string, JSONValue>[] }, ctx: HookContext): Promise<Record<string, QsoClaim[]>> | Record<string, QsoClaim[]>

  /// The holders a station claims as, so the app knows whose checklist to
  /// show. `station` carries its place (`grid`, `lat`/`lon`) when it has one,
  /// as a contact's `our` does.
  holdersFor(args: { station: { call: string } & Record<string, JSONValue> }, ctx: HookContext): Promise<string[]> | string[]

  summarizeClaims(
    args: { holder: string; edition?: string; slots: ClaimSlot[] },
    ctx: HookContext,
  ): Promise<Record<string, ClaimsTally>> | Record<string, ClaimsTally>

  /// What a file of one of `program.imports` claims, for `station` — the
  /// station the operator is chasing as, since an export rarely says whose
  /// it is, with its place as `holdersFor` gets it. `skipped` counts the records it could not read. Answering no
  /// claims leaves the last import of that kind as it was.
  importClaims?(
    args: { importer: string; file: { name: string; text: string }; station: { call: string } & Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<{ claims: ImportedClaim[]; skipped?: number }> | { claims: ImportedClaim[]; skipped?: number }
}

export interface CommandAction {
  setVfo?: {
    freq?: number
    band?: string
    mode?: string
  }
  /// Pushes a wattage straight to `CatService.setPower` (and the manual
  /// fallback setting) — unlike `setVfo` this has no QSO-scoped widget state
  /// of its own to update, so the app dispatches it the same way as
  /// `updateSetting` rather than through the logging panel's local fields.
  setPower?: { watts: number }
  /// Sets radio1's CW keyer speed through `CatService.setKeyerSpeed`. The
  /// app answers with an error when no connected radio can key CW, so the
  /// hook's own `confirm` is only shown for a speed that actually left the
  /// app. Dispatched like `setPower`.
  setKeyerSpeed?: { wpm: number }
  /// KEYER / MACROS: brings up the logging panel's keyer area (its message
  /// buttons, speed pill and queue). Dispatched like `setPower`; the app
  /// answers with an error when no connected radio can key CW.
  showKeyer?: Record<string, never>
  /// ESM / RUN / SP: Enter Sends Messages on or off, and Run versus Search &
  /// Pounce — an absent field is left as it is. Dispatched like `setPower`;
  /// the app answers with an error when no connected radio can key.
  setEnterSends?: { on?: boolean; running?: boolean }
  updateQso?: Record<string, JSONValue>
  addQso?: Record<string, JSONValue>
  /// `target` picks what gets spotted: `'self'` (default) spots the
  /// operation itself at the current VFO; `'last'` spots the most recent
  /// logged QSO (SPOTLAST family) regardless of what's being edited.
  sendSpots?: {
    comment?: string
    target?: "self" | "last"
  }
  /// RESPOT: auto-respotting every `minutes` — the self-spot just taken at the
  /// current VFO, or one sent now when there is none to repeat — or `off`
  /// to stop it, as `minutes` of 0 or less does too. The app holds `minutes`
  /// between 5 and 60; without it, the operator's own auto-respot interval
  /// (their Spotting settings) applies. Panel-only, like `sendSpots`;
  /// the app answers with an error when the spot it would repeat can't be
  /// sent.
  autoRespot?: { minutes?: number; off?: boolean }
  syncAll?: Record<string, never>
  /// PURGETESTS (`test-ops-commands`): app-side lists Test Operations, asks
  /// for confirmation, then purges each — see `HaLoServices.purgeOperation`.
  /// The bare `{}` here just carries the intent through the same
  /// dispatch path every other action uses.
  purgeTests?: Record<string, never>
  updateSettings?: {
    developerMode?: boolean
  }
  /// Writes one setting, named by the `key` a `host.searchSettings` match
  /// reported and carrying the `newValue` it coerced. The app re-resolves the
  /// key before writing — a setting can stop existing between the preview and
  /// Enter (a dev-mode toggle, an extension restart) — and reports nothing on
  /// success, so the command's own `confirm` is the user's only feedback.
  updateSetting?: { key: string; value: JSONValue }
  /// Opens the settings dialog around exactly [keys]. What SET/SHOW/HIDE do
  /// when a value can't be typed on one line (multiselect, account, secret),
  /// when no value was given, or when the query matched several settings
  /// equally well — in which case every tied candidate is listed.
  openSettings?: { keys: string[]; title?: string }
  /// OPER / POSITION (`operation-commands`): edits the OPEN operation. The
  /// two go to different places: the operator is the operation's own shared
  /// data — stored per position when this device is in one — while the
  /// position, the `n` in the `/OP<n>` this device's self-spots carry, is
  /// DEVICE-LOCAL and must not be shared with the other devices logging the
  /// same operation. An empty string clears either. The logging panel
  /// supplies the operation's `uuid`, since only it knows which one is open.
  ///
  /// An export hook reads the operator back as `operation.operatorCall` (or
  /// `operation.local.operatorCall`); the app resolves it for this device's
  /// position first, so a hook never has to know which seat it is in.
  updateOperation?: { operatorCall?: string; multiIdentifier?: string }
  /// START / BREAK / STOP / ROVERQTH (`operation-commands`): marks a segment
  /// boundary on the OPEN operation (docs/design/contests.md §5.1.3). `start`
  /// is REFUSED when the log already has one, rather than moving it; `break`
  /// first adds the missing
  /// `start` at the top of the log, so the contacts already made keep what
  /// was true for them; `stop` moves an existing stop row to now rather than
  /// adding a second. `setLocation` (ROVERQTH) then opens the operation's
  /// Location screen, and what it returns becomes the operation's and the
  /// new segment's. The app supplies the operation's `uuid`.
  markSegment?: { kind: "start" | "break" | "stop"; setLocation?: boolean }
  /// FIND / SEARCH / JUMP / GOTO (`operation-commands`): opens the logging
  /// panel's Find bar over its QSO list, on `query` when one is given — read
  /// the way the bar reads what is typed into it: digits alone a QSO number,
  /// a trailing period an exact callsign, anything else part of one
  /// (docs/design/logging-fields.md § Find in the log). Panel-only, like
  /// `sendSpots`: the command reports `needsOperation` without one.
  findInLog?: { query?: string }
  /// GO (`navigation-commands`): takes the operator somewhere in the app.
  /// `operations`, `maps`, `logs` and `chase` are Home's own destinations,
  /// and leave whatever operation is open to reach them; anything else names
  /// a Settings panel (`settings`, `profiles`, `station`, `sync`, `peers`,
  /// `accounts`, `extensions`, `developer`, `help`, `about`), opened over
  /// what is on screen. A destination this app has turned off (an
  /// experiment, developer mode) is refused as an error rather than opening
  /// something else.
  navigate?: { to: string }
  /// Replaces the call field's entire text, cursor at the end — the
  /// call-notes extension's `//KEY` note expansion. The new text runs
  /// through the same change path as typing, so lookups, dupe checks and
  /// comma-list handling all apply to it normally.
  setCallField?: { text: string }
  /// The new contact's time (`time-commands`): `now: true` returns to live
  /// time; otherwise the fields apply in order to the contact's current
  /// time — its manual time, or now — and the result is set as if typed
  /// into the Time control (docs/design/logging-fields.md § Manual time
  /// entry). `deltaMillis` moves it, by at most a century;
  /// `hour`/`minute`/`second` replace those given, and the seconds become 0
  /// when an hour or minute comes without them; `month`/`day` replace the
  /// date, keeping the year, and `day` needs `month`. All UTC. An action
  /// with none of these, or a value out of range (hour 0–23, month 1–12…),
  /// is refused as an error, never rolled over. The app owns the clock, so
  /// a hook never reads "now" to build one of these.
  setTime?: {
    now?: boolean
    deltaMillis?: number
    hour?: number
    minute?: number
    second?: number
    month?: number
    day?: number
  }
  /// Forces a fresh fetch+reprocess of `dataFile`s (see RELOAD), bypassing
  /// ETag caching — a manual reload is usually because our own mapping
  /// logic changed, not the source data. `target` is `'ALL'` or a
  /// case-insensitive match against a data file's `category` (e.g. `'POTA'`).
  reloadDataFiles?: { target: string }
  /// Developer-only: posts a notice via `host.statusBar.showNotice` (see
  /// `dev-commands`'s DEVNOTICE). Dispatched by the app, not the extension
  /// itself, so it goes through the same confirm/preview flow as any other
  /// command action.
  devNotice?: { key?: string; icon?: string; title?: string; text: string }
  /// Developer-only: posts a transient status message (DEVSTATUS). `key`
  /// lets the caller post more than one at once (e.g. a fresh key per call)
  /// instead of always replacing the same status item.
  devStatus?: { key?: string; icon?: string; title?: string; text?: string }
  /// Developer-only: posts a progress bar (DEVPROGRESS); omit `percent` for
  /// an indeterminate bar.
  devProgress?: { icon?: string; title?: string; percent?: number }
  /// Developer-only: churns the status bar the way a data-file sync does —
  /// several items appearing, ticking and clearing (DEVHAMMER). Exists to
  /// make that churn reproducible on demand, because it is what provokes the
  /// web engine into blurring the focused text field. `seconds` bounds the
  /// run; the app waits a beat before the first item so a tester can get a
  /// field focused and type INTO the churn.
  devHammer?: { seconds?: number }
  /// Developer-only: re-shows the startup release-notes overlay (DEVSPLASH),
  /// bypassing its normal "once per version" gate — see
  /// `app/lib/main.dart`'s `_ReleaseOverlayGate`.
  devSplash?: Record<string, never>
  /// Developer-only: re-shows the first-run onboarding overlay (DEVONBOARD),
  /// bypassing its callsign-undefined gate — see `app/lib/main.dart`'s
  /// `_OnboardingGate`.
  devOnboard?: Record<string, never>
  /// Developer-only: re-shows the tester-notes overlay (DEVTESTER),
  /// bypassing its edition and last-seen-build gates — see
  /// `app/lib/main.dart`'s `_TesterOverlayGate`.
  devTester?: Record<string, never>
  /// Developer-only: reopens the app in a standalone, phone-sized popup
  /// window (DEVPOPUP) — web only.
  devPopup?: Record<string, never>
  /// Developer-only: moves the app clock (DEVTT — see docs/design/time.md).
  /// `deltaMillis` is CUMULATIVE from wherever the clock already reads, and
  /// `speed` is virtual seconds per real second; `reset: true` returns to real
  /// time. The app enforces the gates and reports the resulting time, because
  /// neither the sync account nor the clock's current reading is visible from
  /// inside the sandbox.
  devTimeTravel?: { reset?: boolean; deltaMillis?: number; speed?: number }
  /// Runs the logging benchmark (DEVBENCH) against a throwaway Test Operation
  /// and reports what each phase cost as the log grew. Declared here like every
  /// other action so a misspelled key is a typecheck error rather than a
  /// dispatch that silently does nothing — the index signature below would
  /// otherwise accept it. Developer mode is re-checked app-side.
  devBench?: { qsoCount?: number }
  /// Starts recording every byte to and from the equipment (DEVLOGCAT), or
  /// stops and sends the recording. The app owns the recording and reports
  /// where it is.
  devLogCat?: Record<string, never>
  /// Shows or hides the maps' zoom and viewport-size box (DEVMAPINFO). The
  /// app owns the setting and reports which way it went.
  devMapInfo?: Record<string, never>
  /// Shows or hides the extension engine's idle share in the status bar
  /// (DEVIDLE). The app owns the setting and reports which way it went.
  devIdle?: Record<string, never>
  /// Toggles an experimental feature (EXP command). The app resolves
  /// `token` against `app/experiments.yaml`'s keys and aliases and flips
  /// that experiment's persisted state; an unknown token reports an error
  /// message instead. Resolution happens app-side because the catalog and
  /// the stored state both live there.
  toggleExperiment?: { token: string }
  [actionName: string]: unknown
}

export interface CommandInterpretation {
  /// Set when `input` is a recognized command prefix that isn't complete yet
  /// (e.g. "RELOAD" before its target word) — `describe`/`confirm`/`commands`
  /// are omitted. Signals the call field to switch into free-text mode
  /// (spaces and platform-normal capitalization allowed) so the user can keep
  /// typing parameters; it is never executed even if Enter is pressed while
  /// still set.
  ///
  /// Withholding execution is honored everywhere. The free-text switch is the
  /// logging panel's call field only: the ⌘K and Quick Lookup bars decide
  /// spaces and case by position instead, because an interpretation cannot
  /// arrive in time to rule on a keystroke there — a rule that waits for one
  /// eats the space in "NOTE hello" typed at speed. Those two fields accept
  /// any character regardless, so there is nothing for them to switch.
  expectsParams?: boolean
  /// Set when the input IS a recognized command but can't run in the
  /// current context — e.g. an operation-scoped command (SEED, NOTE, SPOT)
  /// typed into the home screen's quick search, where no operation is open.
  /// The UI presents it as an error message; the interpretation is never
  /// executed and the typed input is left in place. Mutually exclusive with
  /// `describe`/`confirm`/`commands`.
  error?: string
  /// Set when the command's parameter is free prose (e.g. NOTE's text), so
  /// the call field should allow mixed-case input while this interpretation
  /// is current. Without it the field keeps its uppercase-only rule even in
  /// `expectsParams` free-text mode — all logging input is uppercase unless
  /// explicitly mixed-case. Return it on BOTH the bare-prefix
  /// (`expectsParams`) result and the complete result, or the field snaps
  /// back to uppercasing while the parameter is still being typed.
  ///
  /// The logging panel's call field only — see [expectsParams]. The other two
  /// fields uppercase the command word and leave everything past it as typed,
  /// so a prose parameter arrives verbatim from them whether or not this is
  /// set, and setting it changes nothing there.
  mixedCase?: boolean
  describe?: string
  confirm?: string
  commands?: CommandAction[]
  /// True when every `addQso` in `commands` already carries all the lookup
  /// data it's going to get (e.g. SEED's own offline-only pass) and should
  /// NOT be handed to the background online lookup queue after being added.
  /// Ignored when `commands` has no `addQso` entries.
  skipOnlineLookup?: boolean
}

/// What to look up with `host.searchSettings`.
export interface SearchSettingsParams {
  /// Everything the operator typed after the command word, whole. Where the
  /// setting's name ends and its value begins is decided app-side, because
  /// only the catalog can tell `SET AVOID ZERO BEAT N` (a four-word name and a
  /// value) from `SET THEME DARK` (a one-word name and a value) — they have
  /// the same shape. The name is matched against each setting's key, aliases,
  /// label and description, and the value is coerced against that setting's
  /// own type: booleans take Y/YES/ON/TRUE and their opposites, selects match
  /// an option by value or by label.
  args: string
  /// Which command is asking. `'show'`/`'hide'` search only settings that
  /// name a visibility toggle (`showGridField`, `hideFoo`), take no value at
  /// all (every word is part of the name), and answer with the value the verb
  /// implies, inverted for a `hide…` setting.
  kind?: "set" | "show" | "hide"
}

/// One setting a search could have meant.
export interface SettingsSearchCandidate {
  key: string
  label: string
  /// The settings section it lives under, so a match can say where it is.
  section: string
}

/// What `host.searchSettings` answers.
///
/// Everything user-facing here is already localized by the app: `label`,
/// `section`, and the two value strings, which are formatted for READING
/// (`"On"`, a select option's own label) rather than for storage. A `secret`
/// setting's value is never echoed at all — `valueLabel` says only whether one
/// is set.
export interface SettingsSearchResult {
  /// False when nothing matched. Every other field but [query] is then absent
  /// — this is the normal state of a half-typed command, not an error.
  found: boolean
  /// The part of `args` the app read as the setting's NAME. Quote this back to
  /// the user rather than `args`, which would include the value too.
  query?: string
  key?: string
  label?: string
  section?: string
  fieldType?: string
  /// The setting's CURRENT value, formatted for display.
  valueLabel?: string
  /// The setting's CURRENT value, raw — for a hook that has to READ it (one
  /// that toggles, say) rather than show it. Comparing [valueLabel] to decide
  /// that would work in one language and no others.
  ///
  /// BOOLEANS ONLY, and absent for everything else. This crosses the bridge
  /// to any extension that registers a `command` hook, and a secret's
  /// plaintext must not: `valueLabel` says "Set"/"Not set" for those on
  /// purpose. Read `valueLabel` for anything that is not a toggle.
  value?: boolean
  /// Whether a value can be typed on one line at all. False for multiselect,
  /// account and secret settings, which have to be edited in the dialog.
  simple?: boolean
  /// True when another setting matched just as well, so the query doesn't
  /// actually name one thing. Preview the best match by all means, but running
  /// the command should open a picker instead of guessing.
  ambiguous?: boolean
  /// The ranked matches, best first — what a picker lists.
  candidates?: SettingsSearchCandidate[]
  /// The coerced value to write, present only when one was asked for and it
  /// parsed. Pass it straight to the `updateSetting` action.
  newValue?: JSONValue
  /// [newValue], formatted for display.
  newValueLabel?: string
  /// True when [newValue] is what the setting already holds — worth saying so
  /// rather than reporting a change that didn't happen.
  unchanged?: boolean
  /// Present when a value was typed but doesn't fit the setting: a localized
  /// description of what would (`"on or off"`, `"one of: Light, Dark"`).
  expects?: string
}

/// One command a hook advertises to the command dialog (⌘K), so the palette
/// can list what's available before the user knows the exact syntax. Purely
/// descriptive: selecting an entry types its [command] into the field, and
/// it's `interpret` — never this — that decides what the text actually does.
export interface CommandCatalogEntry {
  /// The command as the user would type it, uppercase, without parameters:
  /// "SEED", "NOTE", "RELOAD", "20M". This is both what's matched against
  /// the typed text and what's inserted when the entry is chosen, so it must
  /// be something `interpret` recognizes.
  command: string
  /// One line describing what the command does, shown beside it. Already
  /// localized — build it with the hook context's `t`, same as `describe`.
  describe: string
  /// Optional parameter syntax shown after [command], e.g. "<text>" for NOTE
  /// or "[count]" for SEED. Display only; never matched or inserted.
  params?: string
  /// Groups entries under a heading in the palette. Defaults to the
  /// extension's own name when omitted.
  category?: string
  /// True when the command needs an open operation (SEED, NOTE, SPOT). With
  /// no operation open the palette drops the entry entirely rather than
  /// letting the user pick it and get `interpret`'s `error` back.
  needsOperation?: boolean
  /// True when the command only has something to act on while this device
  /// holds test data — a Test Operation, or a test contact belonging to no
  /// operation (PURGETESTS). Without any the palette drops the entry, as for
  /// [needsOperation]; typing the command still runs it.
  needsTestData?: boolean
  /// Other words the palette finds this entry by: the aliases the command
  /// accepts when typed in full (END for STOP, MACROS for KEYER) and plain
  /// words for what it does (POWER for 5W, CAT for GO STATION). Matched at
  /// the start of a word, like [command]. [describe] is never searched — its
  /// prose matches whatever its words happen to start with ("dev" finding
  /// POSITION by "this device's"), so every word that should find an entry
  /// belongs here.
  keywords?: string[]
  /// True when choosing the entry should leave the field open for typing
  /// instead of running the command straight away — the catalog counterpart
  /// of [CommandInterpretation.expectsParams], for commands whose bare form
  /// isn't useful on its own (NOTE, EXP).
  expectsParams?: boolean
  /// True to let the empty-field "Try" samples offer this command. Opt-in on
  /// purpose: the samples go to users who don't know what a command does yet,
  /// so anything destructive, heavyweight (SYNCALL) or developer-only must
  /// stay out — absent means listed and searchable in the palette, but never
  /// volunteered.
  suggest?: boolean
}

/// Registered under category `command`. `interpret` does its own matching
/// (returns null for no match) so the core can fan out to every registered
/// command via invokeHookAll and apply the first non-null result in
/// priority order, without the host needing to compile extension-supplied
/// regex source itself.
///
/// A hook whose complete interpretation needs a network fetch (SOLAR,
/// WEATHER) doesn't have to block the returned Promise on it: return
/// quickly with a `describe` like "Fetching…", kick the fetch off in the
/// background, and call `host.updateInterpretation(input, ...)` once it
/// resolves. This runs even on a describe-preview call (no `execute`), so
/// the fetched result can show in the UI before the user ever presses
/// Enter — see `host.updateInterpretation`'s doc.
export interface CommandHook {
  interpret(
    args: {
      input: string
      operation?: Record<string, JSONValue>
      qso?: Record<string, JSONValue>
      /// True only when the host is about to actually RUN this command
      /// (Enter/Space on a complete interpretation) and needs `commands` to
      /// reflect real work. False/undefined for the live describe-preview
      /// call fired on the call field's typing debounce — which reruns on
      /// every keystroke pause, so a hook whose `commands` are expensive to
      /// compute (e.g. dev-commands' SEED, which reads the whole log and
      /// looks up every generated call) should skip that work and return a
      /// cheap `describe`-only result when this is falsy. Hooks whose
      /// `commands` are always cheap can ignore this entirely.
      execute?: boolean
    },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null>

  /// Every command this hook offers, for the command dialog's browsable
  /// list. Optional — a hook without it simply contributes nothing to the
  /// palette's suggestions, and its commands still work when typed in full.
  ///
  /// Called once and cached by the host (re-read when extensions are
  /// enabled/disabled or the locale changes), NOT per keystroke: matching the
  /// typed text against the returned entries happens host-side, on plain
  /// strings, so the host never compiles extension-supplied regex — the same
  /// rule `interpret`'s own matching follows.
  ///
  /// Return the commands themselves, not their variants: "20M" and "40M" are
  /// one BAND entry, not fifteen band entries.
  catalog?(ctx: HookContext): Promise<CommandCatalogEntry[]>
}

/// A batch of dirty records the core wants pushed to the sync server, plus
/// batching/consent metadata. Batch selection and dirty-flag bookkeeping stay
/// in Dart (DESIGN.md §4) — the hook is a dumb transport, never touching the
/// database itself.
export interface SyncPayload {
  operations?: Record<string, JSONValue>[]
  qsos?: Record<string, JSONValue>[]
  /// Chasing claims (docs/design/claims.md), sent only to a server whose
  /// reply carried `meta.flags.claims`.
  claims?: Record<string, JSONValue>[]
  meta?: Record<string, JSONValue>
}

/// The server's response: any records it wants merged in locally, tuning
/// knobs for the next round, and the account this device is currently
/// linked to. `error`/`error_status` mark a rejected round instead (same
/// shape as `linkClient`'s error data) — specifically a 422 rejecting a
/// brand-new client's account details, which is part of the sync flow, not
/// a transport failure, so the engine retries rather than treating it as
/// one. Any other status is a genuine failure and still throws.
export interface SyncResponse {
  operations?: Record<string, JSONValue>[]
  qsos?: Record<string, JSONValue>[]
  claims?: Record<string, JSONValue>[]
  meta?: Record<string, JSONValue>
  account?: Record<string, JSONValue>
  /// A transport that can receive a 2xx it didn't earn (a proxy or error
  /// page in front of the real server) uses this to tell a genuine reply
  /// from garbage before the engine marks the batch synced.
  success?: boolean
  error?: string
  error_status?: number
}

/// Registered under category `syncTransport`. Handles authentication and
/// the actual network calls; the core owns the sync loop, batching, and
/// dirty flags so sync keeps working even if the JS runtime is wedged.
export interface SyncTransportHook {
  sync(payload: SyncPayload, ctx: HookContext): Promise<SyncResponse>
  getAccountData(args: Record<string, never>, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// Requests a link permission: with an email, a pending permission on
  /// that account (immediately active when this client already has one —
  /// account switching); with no email, a blank permission for QR-code
  /// linking. Server rejections come back as `{ error, error_status }`
  /// data rather than a thrown error. Optional so transports written
  /// against the pre-linking contract keep compiling — the host degrades
  /// gracefully when it's missing. It must NOT mail anything: the core
  /// shows the challenge code on screen and offers the email as a separate
  /// choice, so a transport that mails here sends one nobody asked for —
  /// and another on every renewal, since an expiring code re-requests
  /// through this same call.
  linkClient?(args: { email?: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// The same request, made because the operator asked for the confirmation
  /// by email instead of reading the code off this device. The only call in
  /// this contract that mails.
  linkClientWithEmail(args: { email: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// Sets the account's email address — a change, or the first claim on an
  /// anonymous account. The address starts out pending and is confirmed by
  /// following a link the server mails; [resendAccountEmail] sends that
  /// again. Both return `{ error, error_status }` data for a rejection the
  /// operator caused (address taken, nothing pending) rather than throwing.
  /// Optional, so transports predating this contract keep compiling.
  setAccountEmail?(args: { email: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  resendAccountEmail?(args: Record<string, never>, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// The confirming side of linking, where [linkClient] is the requesting
  /// side: find the pending request a challenge code or a `link_client` deep
  /// link refers to, then grant it. `challenge_token` is required to approve
  /// an orphaned (QR) permission — it is what binds that permission to this
  /// account — and ignored for one already raised against it by email.
  /// Rejections arrive as `{ error, error_status }` data: an expired or
  /// mistyped code is an ordinary outcome of the flow, not a fault.
  /// Optional, so transports predating this contract keep compiling.
  findLinkRequest?(args: { challenge_token: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  findLinkRequestByClient?(args: { client: string; challenge_token: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  approveLinkRequest?(args: { client: string; challenge_token?: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// Ensures this device is registered with the sync server, independent of
  /// whether the operator has QSO sync enabled — registration establishes
  /// device identity and the realtime push channel, it does not push any log
  /// data. Returns the Pusher channel to subscribe to and the signed token
  /// used to build the `state` param for a webhook-relayed OAuth flow
  /// (HALO-65/66). Optional so transports predating this contract keep
  /// compiling.
  ensureClientRegistered?(args: { refreshWebhookToken?: boolean }, ctx: HookContext): Promise<{ push_channel_name: string; webhook_client_token: string }>
  /// Fetches this device's pending webhook events (HALO-65) — the poll
  /// fallback, and how the app retrieves the actual payload after a Pusher
  /// `webhook_event` ping (which intentionally carries only an id, never the
  /// sensitive payload — see HALO-65's design note).
  fetchWebhookEvents?(args: Record<string, never>, ctx: HookContext): Promise<{ webhook_events: Record<string, JSONValue>[] }>
  /// Files a report the HOST composed — title, body and kind already written,
  /// because the surface raising it (the equipment editor's radio report)
  /// knows things about the subject the extension cannot ask for. The
  /// transport adds who/where/what-build and owns the account gate, so a
  /// report refused for want of an account is refused in one place.
  /// Failures arrive as `{ error }` rather than as a throw: the caller is
  /// showing this to an operator who has just written something they want
  /// sent. Optional so transports predating this contract keep compiling.
  submitReport?(args: { title: string; body: string; kind: "idea" | "task" | "bug" }, ctx: HookContext): Promise<{ ref?: string | null; error?: string }>
  /// Sends ONE export file to Ham2K's File Stash, into the group `groupUuid`
  /// names (the host mints it — the sandbox has no uuid source — and sends a
  /// batch file by file under it). `{ uploaded: true }` or `{ error }`, never
  /// a throw; `fatal` marks any failure but the server refusing that one
  /// file (no account, sync off, no answer), so the host stops rather than
  /// fail every remaining file the same way. Optional so transports
  /// predating the stash keep compiling.
  uploadStashFile?(
    args: { file: { filename: string; content: string; mimeType?: string; format?: string }; groupUuid: string; groupTitle?: string },
    ctx: HookContext,
  ): Promise<{ uploaded?: boolean; error?: string; fatal?: boolean }>
  /// The account's most recent stash files, newest first, as the server's
  /// `{ stash_files: [...] }` — or `{ error }`.
  listStashFiles?(args: { limit?: number }, ctx: HookContext): Promise<Record<string, JSONValue>>
  /// Mails the account's address a link to its stash: `{ ok: true }` or
  /// `{ error }`.
  emailStashLink?(args: Record<string, never>, ctx: HookContext): Promise<Record<string, JSONValue>>
}

export interface AccountField {
  key: string
  label: string
  type: "text" | "email" | "secret"
  preface?: string
  postface?: string
}

export interface OAuth2Config {
  issuer: string
  clientId: string
  /// The native custom-scheme redirect (`com.ham2k.*.auth://…`), used where
  /// the OS delivers it as a deep link: macOS, iOS and Android. NOT Windows —
  /// it registers the schemes but takes the relay deliberately (see
  /// `oauthUsesWebhookRelay` in app/lib/views/oauth_browser_login.dart).
  redirectUrl: string
  /// The LoFi webhook-relay callback (HALO-65/66), used instead of
  /// [redirectUrl] on Web, Linux and Windows. Optional so an OAuth2 hook that
  /// only supports the native flow keeps compiling — but omitting it means
  /// those three platforms cannot start this login at all, since the host
  /// resolves the redirect to null there and has nothing to send.
  webhookRedirectUrl?: string
  scopes: string[]
}

/// Registered under category `account`. One hook per account; core
/// aggregates every extension's `account` hook via `invokeHookAll` into the
/// account list shown in Settings. Accounts are defined, stored (credentials
/// in secure storage, keyed by `kvKey`), and edited independently of
/// `settingsPanel` — each account gets its own standalone dialog. A
/// `settingsPanel` field can reference an account for display/navigation
/// via `fieldType: 'account'` (see FormField), but does not define or store
/// account data itself.
/// A definition member that may be localized: a plain value, or a function
/// of ctx (called like any other hook method — `fn(args, ctx)`, `args`
/// always `{}`) that resolves it, e.g. from `ctx.locale` via the SDK's
/// `createTranslator`. Same convention as [AccountHook.oauth2].
export type Localizable<T> = T | ((args: Record<string, never>, ctx: HookContext) => T | Promise<T>)

export interface AccountHook {
  label: Localizable<string>
  /// Short one-liner shown under the label in the Accounts list (e.g.
  /// "Callsign lookups").
  description?: Localizable<string>
  /// Defaults to the extension's own key. If overridden (an extension with
  /// more than one account), must equal the extension key or be prefixed
  /// `<extensionKey>_` — e.g. extension `lofi` may use `lofi` or
  /// `lofi_backup`, never bare `backup` or camelCase `lofiBackup`. Keeps
  /// every account keyed under its owning extension's namespace, which is
  /// how storage collisions are prevented and (later) how KV access
  /// control will be scoped.
  kvKey?: string
  fields?: Localizable<AccountField[]>
  /// A plain config, or a function for a config that varies per build
  /// edition (`ctx.edition`) — e.g. SOTA registers one Keycloak client with a
  /// separate redirect URL per edition. Called the same way any
  /// other hook method is (`fn(args, ctx)`, `args` always `{}`) — see
  /// docs/extensions/hooks.md's `account` section.
  oauth2?: OAuth2Config | ((args: Record<string, never>, ctx: HookContext) => OAuth2Config | Promise<OAuth2Config>)
  /// Whether this account's stored credentials and session sync across the
  /// user's Apple devices via iCloud Keychain (`kSecAttrSynchronizable`).
  /// Defaults to `false` — device-local. Set `true` ONLY for account-level
  /// logins that are legitimately the same on every device (e.g. a QRZ.com
  /// username/password). NEVER set it for per-device identifiers or bearer
  /// tokens (e.g. a sync client/device key), where each install must stay
  /// distinct. No effect on non-Apple platforms. Note: flipping this on an
  /// account that already has stored credentials makes the old (non-synced)
  /// entry invisible — those credentials must be re-entered once.
  synchronizable?: boolean
  testCredentials(credentials: Record<string, string>, ctx: HookContext): Promise<string>
}

export type Hook =
  | LookupHook
  | LookupServiceHook
  | SpotsHook
  | ExportHook
  | ScoringHook
  | ChasingHook
  | RefHandlerHook
  | ActivityHook
  | AdifFieldsHook
  | AdifImportHook
  | CommandHook
  | SyncTransportHook
  | AccountHook
  | DataFileDefinition
  | FormHook
  | SettingsPanelHook
  | PanelHook
  | Record<string, unknown>

export interface RegisterHookParams {
  hook: Hook
  key?: string
  priority?: number
}

export interface ActivationApi {
  registerHook(category: HookCategoryName, params: RegisterHookParams): void

  /// Privileged host-call function bound by the kernel to THIS extension's
  /// identity (host-manifest-derived) — identity params (`ns`, `kvKey`,
  /// `extensionKey`) are injected kernel-side and cannot be spoofed. The
  /// SDK captures it at activation; extension code normally never touches
  /// it directly and just uses the `host` API.
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>

  /// This extension's timers, bound by the kernel like [hostCall]. The SDK
  /// captures them at activation; extension code uses `host.setTimeout` and
  /// friends, or plain `setTimeout`, which the build points at those.
  /// Absent on an app older than extension API 3.
  timers?: {
    set(callback: unknown, delay: unknown, repeat: boolean, args: unknown[]): number
    clear(id: unknown): void
  }
}

/// Where, when and for whom an extension is relevant
/// (docs/extensions/distribution.md). Relevance ranks, it does not gate:
/// nothing is hidden for failing to match.
///
/// The four GEOGRAPHIC keys are allowlists over the OPERATOR's own callsign:
/// a missing or empty key does not gate; the values within one key are ORed,
/// the keys themselves ANDed. Case is the matcher's job — `entities` and
/// `continents` compare uppercased, `countries` lowercased, `ituRegions` as
/// integers — so an author writes whatever reads well. There are no negation
/// keys, and a manifest with no `relevance` at all is worldwide.
///
/// That geographic half mirrors the geo filters of HaLo's notices
/// (app/lib/services/notices.dart) key for key and rule for rule: two engines
/// with different rule sets would drift, and an author who learned one would
/// misread the other. `dates` and `interests` have no counterpart there and
/// take no part in that match — they answer WHEN and TO WHOM, which orders a
/// list rather than deciding membership of one.
export interface ExtensionRelevance {
  /// DXCC entity prefixes as the country file names them: `K`, `VE`, `CE`.
  entities?: string[]
  /// ISO 3166-1 alpha-2 codes: `us`, `cl`.
  countries?: string[]
  /// One of `AF AS EU NA OC SA AN`.
  continents?: string[]
  /// `1`, `2` or `3`.
  ituRegions?: number[]
  /// The UTC days this extension's events START, as `YYYY-MM-DD`:
  /// `["2026-09-19", "2027-09-18"]`. Start days, not spans — a reader asking
  /// "is this soon" needs no more, and the extension's own code remains the
  /// only place that knows when an event opens and closes to the minute.
  ///
  /// An event on a fixed calendar lists the occurrences it knows about; one
  /// that runs to a weekly rule lists none, because a list that must be
  /// right every week is a list that goes stale. An absent or empty `dates`
  /// therefore says nothing about timing — never "never".
  dates?: string[]
  /// What an operator has to be into for this to matter, drawn from the
  /// fixed vocabulary in `extensions/tools/h2kext.mjs`
  /// (`RELEVANCE_INTERESTS`): a mode (`cw`, `phone`, `digital`), a band
  /// group (`hf`, `vhf`, `uhf`, `microwave`), or a style (`satellite`,
  /// `portable`, `qrp`).
  ///
  /// Only for an extension DEDICATED to one. A contest that permits CW is
  /// not a `cw` extension; the CWops CWT, which is CW and nothing else, is.
  /// Listing what an extension merely allows makes every interest match
  /// everything, which is the same as listing none.
  interests?: string[]
}

/// A settings section an extension may place its panel in without review —
/// the key of one of the app's own settings groups. The first six are where
/// a panel usually belongs, by the extension's main purpose; the other four
/// suit one that tunes something the app already has a section for (`radio`
/// is CAT Control, `map` is Maps). See docs/extensions/settings.md.
export type SettingsSection = "activities" | "hunting" | "contests" | "lookups" | "spotting" | "dashboard" | "logging" | "radio" | "map" | "exports"

/// Where an extension's settings panels appear in the app's Settings — the
/// manifest's `settings`. The catalog reads manifests and never runs a
/// bundle, so this is what it reviews, and the app holds every panel to it:
/// what a panel's own `section`/`sidebar` ask for and the manifest does not
/// declare, it does not get. See docs/extensions/settings.md, "Where an
/// extension's settings go".
export interface ExtensionSettingsPlacement {
  /// The section the extension's panels show in, as one row each that opens
  /// the panel in a dialog. One of [SettingsSection] needs no review;
  /// any other key, or none at all for an extension with a `settingsPanel`
  /// (a category of its own), is held for an admin.
  section?: SettingsSection | (string & {})
  /// An entry in Settings' sidebar too, for a panel that is a category of
  /// its own; one placed in a section never has one. Reviewed.
  sidebar?: boolean
  /// Fields flagged `common: true` also shown in Common Preferences.
  /// Reviewed; without it the flag is ignored.
  common?: boolean
}

/// The static, public identity of an extension — everything about it that
/// can be known without running its code. Lives in the package's
/// manifest.json (single source: extensions import it and spread it into
/// defineExtension, and build.mjs reads it to produce index.json for the
/// Dart host, which must list even DISABLED extensions whose bundles never
/// evaluate).
export interface ExtensionManifest {
  key: string
  name: string
  shortName?: string
  version: string
  description?: string
  /// MDI icon name shown in the Extensions panel (and mirrored by the
  /// extension's own controls).
  icon?: string
  /// The extension's brand accent as a #RRGGBB hex string (e.g. POTA's
  /// green) — informational for hosts that want to tint extension UI.
  accentColor?: string
  /// Extra search terms for the Extensions panel beyond name/description.
  keywords?: string[]
  /// Panel grouping ('activity', 'lookup', …). Absent means core: always
  /// enabled, never listed in the panel.
  category?: string
  /// Whether a BUILT-IN extension starts out on, for the app that ships it.
  /// Meaningless for a distributed bundle — an operator who installs one
  /// wants it — and the packer refuses a manifest that carries it.
  enabledByDefault?: boolean
  /// The hook categories this extension registers (`ref:<type>` for ref
  /// handlers). Declarative/informational — the kernel still learns the
  /// actual hooks from registerHook at activation.
  hooks?: string[]
  /// `"always"`: the full ADIF export asks this extension's `adifFields` about
  /// EVERY contact. Left out, it is asked only about contacts carrying a
  /// reference this extension answers for — which is what keeps one program's
  /// fields out of every other log. A manifest that lists `adifFields` needs a
  /// `ref:` type or this; the packer refuses one with neither. Read by the
  /// kernel from the definition, so the manifest has to be spread into it.
  adifFieldsScope?: "always"
  /// host.fetch allowlist for this extension's bundle.
  domains?: string[]
  /// host.webSocket allowlist — a separate grant from `domains`, same entry
  /// shape, plus `"local"` for any local-network address (loopback, private
  /// ranges, `.local` names). `wss://` to any listed host; plain `ws://` only
  /// to a local-network one.
  webSockets?: string[]
  allowUserAgentOverride?: boolean
  /// Declares this extension's bundle may call `host.getLocation()` — the
  /// device's raw GPS coordinates. Off by default, same allowlist shape as
  /// `domains`: the host refuses the call for any extension that doesn't
  /// set this.
  requiresLocation?: boolean
  /// Declares this extension's bundle may read the operator's radios —
  /// `host.listRadios()`, `host.readRadio()`, and a scene's `spectrum`
  /// control. Off by default; the host refuses the call for any extension
  /// that sets neither this nor `requiresRadioWrite`.
  requiresRadioRead?: boolean
  /// Declares this extension's bundle may command the operator's radios —
  /// `host.setRadio()`, `host.setRadioConnection()`,
  /// `host.setRadioSpectrum()` — and transmit with them: `host.sendRadioCw()`,
  /// `host.playRadioVoice()`, `host.setRadioPtt()` and
  /// `host.stopRadioTransmit()`. Implies `requiresRadioRead`, since a command
  /// answers with the radio's state.
  requiresRadioWrite?: boolean
  /// Declares this extension's bundle may send the operator's radios any
  /// command in their own protocol — `host.sendRadioRaw()`. Nothing about the
  /// command is checked: it may transmit or change any setting, and the
  /// install screen says so. Implies `requiresRadioWrite`. Extension API 11.
  requiresRadioRaw?: boolean
  /// Declares this extension's bundle may read the app's DX cluster
  /// connection — `host.clusterStatus()`, `host.clusterLines()`,
  /// `host.clusterSubscribe()` and the `cluster` hook's `onLines`. Each of
  /// these logs the operator in to the node the operator picked. Extension
  /// API 10.
  requiresClusterRead?: boolean
  /// Also `host.clusterPostSpot()`: spots posted in the operator's name.
  /// Implies `requiresClusterRead`.
  requiresClusterSpot?: boolean
  /// Also `host.clusterSend()`: any command, in the operator's name.
  /// Implies `requiresClusterSpot`.
  requiresClusterCommand?: boolean
  /// Experiment keys (app/experiments.yaml) gating this extension: unless
  /// EVERY listed experiment is enabled, the extension is hidden from the
  /// Extensions panel and its bundle never loads. The user's enable/disable
  /// choice is kept while hidden, so it comes back when the experiment does.
  experiments?: string[]
  /// Where, when and for whom this extension is relevant — see
  /// [ExtensionRelevance]. Relevance, not access: the catalog and the
  /// Extensions panel rank by it, and nothing hides an extension over it.
  relevance?: ExtensionRelevance
  /// Where this extension's settings panels go — see
  /// [ExtensionSettingsPlacement]. Needed by any extension that registers a
  /// `settingsPanel`.
  settings?: ExtensionSettingsPlacement
  /// Per-locale overrides for name/description plus extra localized search
  /// keywords, keyed by language code. Localized keywords ADD to the base
  /// `keywords` (both are searchable), they don't replace them.
  translations?: Record<string, { name?: string; description?: string; keywords?: string[] }>
}

export interface ExtensionDefinition extends ExtensionManifest {
  onActivation(api: ActivationApi): void
  /// The app came back into view — a desktop window restored, a browser tab
  /// selected again, a phone app back in the foreground. The app does not
  /// pause timers while hidden (though iOS and a hidden browser tab may), so
  /// this is for work worth doing only while someone can see it. Called only
  /// on a change, after activation.
  onShow?(): void | Promise<void>
  /// The app went out of view. Also called as activation completes if the
  /// app is hidden by then, so an extension always learns the state it
  /// starts in; never called for one whose activation failed.
  onHide?(): void | Promise<void>
}

export interface FetchOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE"
  /**
   * Extra request headers. Note: the host stamps HaLo's canonical
   * `User-Agent` on every request and it overrides any you set here, so
   * don't provide your own — unless your extension declares
   * `allowUserAgentOverride` in build.mjs (see docs/design/network.md).
   */
  headers?: Record<string, string>
  body?: string
  /**
   * Give up on this request after `timeout` milliseconds, instead of the
   * host's default allowance. Clamped DOWNWARD only — asking for longer than
   * the default changes nothing — and it bounds the whole request, headers
   * and body alike.
   *
   * For a request whose answer is optional: a cache-validation probe, an
   * enrichment worth having but not worth waiting for. It matters because a
   * hook fan-out shares ONE budget across every extension in the category,
   * so a request that stalls costs the other extensions their results too
   * (see `invokeHookAll`'s `partialOnTimeout`). This is how a hook says
   * "not worth waiting the default for" rather than spending everyone's time.
   */
  timeout?: number
}

export interface FetchResponse {
  status: number
  body: string
}

export interface WebSocketOptions {
  /// Subprotocols to offer in the handshake; the server's pick is
  /// `ExtensionWebSocket.protocol` once open.
  protocols?: string[]
}

export interface WebSocketCloseEvent {
  code: number
  reason: string
  wasClean: boolean
}

/// A browser-shaped WebSocket, carried by the host. Binary frames arrive as
/// an `ArrayBuffer` (a browser's `binaryType = "arraybuffer"`). Callbacks run
/// outside any hook call, so there is no `ctx`, and a failure to connect — a
/// refused host included — arrives as `onerror` then `onclose`, never as a
/// throw.
export interface ExtensionWebSocket {
  readonly url: string
  /// 0 connecting, 1 open, 2 closing, 3 closed — as the browser's.
  readonly readyState: 0 | 1 | 2 | 3
  readonly protocol: string
  onopen: (() => void) | null
  onmessage: ((event: { data: string | ArrayBuffer }) => void) | null
  onerror: ((event: { message: string }) => void) | null
  onclose: ((event: WebSocketCloseEvent) => void) | null
  /// Throws unless the socket is open, and for a frame over 1 MiB (UTF-16
  /// code units of text, or bytes).
  send(data: string | ArrayBuffer | ArrayBufferView): void
  /// `code` is 1000 or 3000-4999; `reason` at most 123 UTF-8 bytes.
  close(code?: number, reason?: string): void
}

/// The device's current GPS fix, as returned by `host.getLocation()`.
export interface DeviceLocation {
  latitude: number
  longitude: number
}

/// Build identity, as returned by `host.getVersionInfo()` — for commands
/// (REPORT) that need to say exactly what build they ran on.
export interface VersionInfo {
  /// `web`/`macos`/`ios`/`android`/`windows`/`linux`/`fuchsia`.
  platform: string
  /// `dev`/`next`/`prod` — see `config/version.dart`'s `Edition`.
  edition: string
  /// The public version on its own, e.g. `26.8.1`.
  version: string
  /// The display name, e.g. `August '26 ALPHA patch 1 (Dev Edition)` — built
  /// from the stage label and the edition qualifier, NOT from [version].
  versionName: string
  /// Null on Dev, where the compiled-in build number is the last release's
  /// rather than the running build's. Report [gitSha] instead of inventing
  /// one: a build number that names a build nobody is running misdirects
  /// whoever reads it.
  buildNumber: number | null
  /// Short git SHA the build was cut from. Empty for local/dev builds.
  gitSha: string
}

export interface LookupRow {
  category: string
  subCategory?: string
  key: string
  name?: string
  data?: any
  lat?: number
  lon?: number
  flags?: number
}

export interface LookupEntry {
  subCategory?: string
  key: string
  name?: string
  lat?: number
  lon?: number
  flags?: number
  data?: Record<string, unknown>
}

export interface CsvOptions {
  hasHeaders?: boolean
  skipRows?: number
  delimiter?: string
}

export interface JsonOptions {
  rootPath?: string
}

export type FetchType = "csv" | "json" | "raw"

export interface DataFileDefinition {
  key: string
  name: Localizable<string>
  description: Localizable<string>
  /// Usually a plain string. A function when the URL depends on something the
  /// extension must ask for — TOTA's list carries its API key as a query
  /// parameter — resolved once per refresh, like `name` and `description`.
  ///
  /// `n1mm-history:<stem>` names an N1MM call history file instead, by the
  /// stem its versions share (`n1mm-history:CWOPS` for `CWOPS_4002.txt`): the
  /// host downloads the newest one, and only when its name changes. Use it
  /// with `fetchType: 'raw'`; see docs/extensions/hooks.md's `dataFile`.
  /// Extension API 11.
  url: Localizable<string>
  maxAgeInDays: number
  fetchType: FetchType

  /// Character encoding of the fetched file. When omitted the host uses the
  /// response's Content-Type charset, defaulting to `'utf-8'`. Set this
  /// (`'latin1'` / `'iso-8859-1'` / `'ascii'`) to OVERRIDE a server that sends
  /// a wrong or missing charset for a non-UTF-8 source.
  encoding?: string

  category?: string
  csvOptions?: CsvOptions
  csvToLookupEntry?: (row: string[] | Record<string, string>) => LookupEntry | null
  jsonOptions?: JsonOptions
  jsonToLookupEntry?: (entry: Record<string, any>) => LookupEntry | null

  rawToJSONData?: (args: { body: string; url: string; options: Record<string, any> }) => Promise<any>
  onLoadRawData?: (data: any) => void
  onRemoveRawData?: () => Promise<void>
}

export type FormFieldType =
  "text" | "multiline" | "textTemplate" | "email" | "callsign" | "number" | "select" | "radio" | "checkbox" | "secret" | "list" | "multiselect" | "account"

export interface FormFieldOption {
  label: string
  value: any
  /// Only used when fieldType === 'multiselect': disclosure tiers.
  /// `common: true` options show upfront; unflagged ones sit behind the
  /// first disclosure step; `uncommon: true` ones behind the second (the
  /// toggle then cycles Show more → Show all → Show fewer; without any
  /// uncommon options it's just Show all / Show fewer).
  common?: boolean
  uncommon?: boolean
}

export interface FormField {
  type: "field"
  fieldType: FormFieldType
  key: string
  label: string
  value?: any
  placeholder?: string
  /// Text-template editor vocabulary: filenames/titles or per-QSO ADIF fields.
  templateContext?: "export" | "adif" | "text"
  /// Sample inputs for the preview (operation, qso, log).
  templateSample?: Record<string, JSONValue>
  /// Forces typed input to uppercase (formatter, not just a soft-keyboard
  /// capitalization hint) on the text-like field types. `callsign` fields
  /// are always uppercase without this flag; use it for other logging data
  /// that follows the uppercase-unless-explicitly-mixed-case rule (grids,
  /// states, RSTs) while free-prose fields (names, notes) stay unflagged.
  uppercase?: boolean
  /// Only used when fieldType === 'secret' in a settings list: what the row
  /// says while a value is stored ("Password on file for K3LR"), in place of
  /// the fixed mask. A host that predates this shows the mask.
  storedText?: string
  /// Only used when fieldType === 'text': the codes this field takes, offered
  /// as the operator types (matched on code and name, like a `kind: 'options'`
  /// logging control) and checked on the way out — a value that is not one of
  /// them is flagged beside the field. Flagged, not refused: Save still writes
  /// it. A host that predates this renders the plain text field, and so does a
  /// settings list (or a field with an `icon`), which edits text in a row
  /// dialog of its own.
  ///
  /// `standalone` marks a code that is only valid as the WHOLE value, never as
  /// one of a `multiValue` list — a state beside a county on a QSO party
  /// county line. It is not suggested once the field holds a separator, and
  /// is flagged there.
  suggestions?: { code: string; name?: string; standalone?: boolean }[]
  /// Only used with `suggestions`: the field holds several codes joined by
  /// `separator` (a QSO party county line, `ALB/SCH`), each suggested and
  /// checked on its own. `inheritPrefix` as on a logging control's multiValue.
  multiValue?: { separator: string; inheritPrefix?: number }
  /// Only used with `suggestions`: live-reformatting passes applied as the
  /// operator types, as on a logging control — a county line typed with a
  /// comma becomes the slash its `multiValue` separator is.
  transforms?: { pattern: string; replacement: string; flags?: string }[]
  /// The choices for 'select', 'radio', and 'multiselect'. Either inline
  /// options, or the `$`-prefixed name of a system list (e.g.
  /// `"$core.bands"`) — a named vocabulary the app resolves before
  /// rendering; see docs/extensions/settings.md's "System lists".
  options?: FormFieldOption[] | string
  validate?: (value: any, state: Record<string, any>) => string | null | undefined | Promise<string | null | undefined>
  transform?: (value: any, state: Record<string, any>) => any | Promise<any>
  /// Only used when fieldType === 'list'. `value` is then a
  /// Record<string, any>[], each item matching the shape described by
  /// `itemFields`. The field renders as a single row summarizing the items
  /// (comma-separated `itemTitle`s); tapping opens an editor dialog with
  /// per-item rows and Add (edit/add reuse the same form renderer
  /// recursively, scoped to `itemFields`, in a nested dialog, whose footer
  /// holds Delete, confirmed, for an item that exists) — unless `inline` opts out of
  /// that, see below.
  itemFields?: FormField[]
  /// `${key}` placeholders substituted from each item's own fields — e.g.
  /// `"${name}"`. NOT `{{key}}` (Mustache-style double braces), which the
  /// renderer does not recognize and would show literally, unsubstituted.
  itemTitle?: string
  orderable?: boolean
  /// Only used when fieldType === 'list'. The key of an on/off value in each
  /// item, set from a switch at the end of the item's row — leave it out of
  /// `itemFields`. An item without the key reads as on, so a new item is on
  /// until switched off. An app that predates this shows no switch.
  itemSwitch?: string
  /// Only used when fieldType === 'list'. Renders the item rows (with a
  /// reorder handle per row, and an Add row) directly in the
  /// panel instead of behind a single summary row that opens an editor
  /// dialog — for a list that's the main content of its own section rather
  /// than one field among several. Tapping a row (or Add) still opens the
  /// `itemFields` editor dialog; only the extra list-editor dialog wrapping
  /// reorder/add is skipped.
  inline?: boolean
  /// Only used when fieldType === 'list'. Singular noun for one item (e.g.
  /// "custom note file"), used in the Add/Edit dialog titles and the Add
  /// button instead of `label` — which names the list as a whole (typically
  /// plural) and would otherwise read as "Add custom note files" for a
  /// dialog that adds exactly one. Defaults to `label` when omitted.
  itemLabel?: string
  /// Only used when fieldType === 'multiselect': the selection the editor's
  /// Defaults button restores. Omit it and no Defaults button is offered.
  defaultValue?: any[]
  /// Only used when fieldType === 'account'. A read-only reference into the
  /// separate `account` hook system (see AccountHook) — renders a
  /// connection-status row (Connected as X / Not Connected) with a
  /// Manage/Connect button that opens that account's own standalone dialog.
  /// Does not define or store account data itself. `key` matches the
  /// account's `kvKey`; `subkey` is an opaque, extension-defined
  /// discriminator only needed when one extension exposes more than one
  /// account-like entity under the same key.
  account?: { key: string; subkey?: string }
  /// Hidden unless the app's developer mode is on; when shown, rendered in
  /// the same orange "dev mode" accent app-polo uses (label/icon/subtitle
  /// tinted, no badge or border). For settings that only matter for
  /// debugging/development, not end users.
  devMode?: boolean
  /// Opts this field into the compact list-row layout used by the Sync/
  /// Accounts settings panels: a leading icon, bold `label`, optional
  /// `description` below it, and a compact version of the field's own
  /// control on the trailing side — instead of the default standalone
  /// Material input. Icon names follow the same convention as
  /// SettingsPanelDescriptor.icon (an MDI name resolved via
  /// resolveIconName). Only meaningful for fieldType 'select', 'checkbox',
  /// and the plain text-like types (text/multiline/email/callsign/number/
  /// secret) — 'list', 'radio', and 'account' ignore it and keep their
  /// existing rendering, since a multi-option or multi-row control doesn't
  /// have an obvious compact form.
  icon?: string
  /// Freeform text shown under `label` when `icon` is set — typically a
  /// description of what the current value means (e.g. "Always in Light
  /// Mode"), recomputed by the extension each time `getDefinition` runs so
  /// it can reflect the field's current value. Ignored when `icon` isn't
  /// set.
  description?: string
  /// Show this field only while a sibling field holds one of these values.
  /// `equals` may be a single value or a list meaning "any of"; naming a field
  /// that doesn't exist reads as null, so the element simply stays hidden.
  ///
  /// This is how a form varies with itself. A closure can't do it — the
  /// definition that crosses the bridge is static JSON — and recomputing the
  /// whole descriptor can't reach a dialog that is already open. IARU HF is
  /// the motivating case: its sent exchange is an ITU zone, a society
  /// abbreviation, or an IARU office, chosen by the station type in the same
  /// form (docs/design/contests.md §5.4.1).
  ///
  /// A hidden field is still initialized and still submitted, so switching a
  /// discriminator away and back preserves what was already typed. Read the
  /// value you want by the discriminator, never by "whichever is non-empty".
  visibleWhen?: { field: string; equals: any }
  /// Only meaningful within a settingsPanel (ignored in ad hoc forms) — see
  /// docs/extensions/settings.md's "Common Preferences and environment
  /// gating". Also shows this field on the app's Common Preferences
  /// quick-access panel, in addition to the full settings list. Unrelated
  /// to FormFieldOption.common/uncommon above (a multiselect option's own
  /// disclosure tier) — different scope, an option inside one field vs.
  /// the field itself.
  common?: boolean
  /// Only meaningful within a settingsPanel. Restricts which platform(s)
  /// show this field at all — Common Preferences and the full settings
  /// list alike, not just one view of it. One or more platform tokens
  /// (`ios`, `android`, `macos`, `windows`, `linux`, `web`) as a
  /// comma-separated string or array. Every token unprefixed: show ONLY on
  /// the listed platforms. Every token `-`-prefixed: show on every
  /// platform EXCEPT the listed ones. Mixing the two forms is invalid —
  /// treated as if `environment` were absent. Omit for "every platform".
  environment?: string | string[]
  /// Only meaningful within a settingsPanel. Opts this field into a
  /// target-scoped settings modal elsewhere in the app (e.g. the logging
  /// view's tune-icon dialog uses `target: 'logging'`) — see
  /// docs/extensions/settings.md's "Settings targets". A single target key,
  /// or a list when the field should surface under more than one. A
  /// `'<target>-extended'` target (e.g. `'logging-extended'`) is the same
  /// idea, but starts hidden behind that modal's own "show more settings"
  /// disclosure — for a field related to the target but niche enough it
  /// shouldn't clutter the default view. Omitting `target` doesn't hide the
  /// field from anywhere it already appears (the Settings panel, Common
  /// Settings) — it just means no target-scoped modal picks it up.
  target?: string | string[]
  /// Only meaningful within a `kind: 'dynamic'` settingsPanel. After this
  /// field commits, the app restarts the extension runtime — for a Tier 2
  /// field whose value is only consulted at `onActivation` (e.g. a list of
  /// URLs to register as `dataFile` hooks), since there's no other way for
  /// a value read via `host.getSettings()` mid-runtime to reach code that
  /// only runs once, at activation. Don't set this on a field an extension
  /// hook can simply re-read on its next invocation (most Tier 2 fields
  /// don't need it) — a restart is disruptive, reserved for the fields that
  /// genuinely require one.
  restartOnChange?: boolean
}

export interface FormHeader {
  type: "header"
  title: string
  subtitle?: string
  devMode?: boolean
  /// Defaults to the form dialog's usual bold header look. Set to
  /// 'section' to instead match the compact section-divider style used by
  /// the Sync/Accounts/General settings panels — for a settingsPanel
  /// carving its fields into named groups, not for an ad hoc form's own
  /// title.
  /// 'category' is the FILLED band — for a heading that is the top level of
  /// its surface rather than a section inside one (the station equipment
  /// editor's). A settingsPanel is already inside a category, so its own
  /// headings take 'section'.
  style?: "default" | "section" | "category"
  /// Settings-panel-only; see FormField.environment. Not `common` — a
  /// header is chrome for the rows under it, and the Common Preferences
  /// section shows flagged rows with no bands at all, so there is nothing
  /// for a header to opt into there.
  environment?: string | string[]
}

export interface FormSectionDivider {
  type: "divider"
  title?: string
  devMode?: boolean
  /// Settings-panel-only; see FormField.environment.
  environment?: string | string[]
}

export interface FormMarkdownBlock {
  type: "markdown"
  text: string
  devMode?: boolean
  /// Settings-panel-only; see FormField.environment.
  environment?: string | string[]
  /// Starts collapsed behind a tappable `title` header instead of always
  /// showing `text` — for supplementary help/reference material (e.g. "How
  /// to build your own X") that would otherwise clutter the panel for
  /// everyone who doesn't need it. Requires `title`, since a collapsed block
  /// needs something to show. Omit for the default: `text` always visible.
  collapsible?: boolean
  /// The tappable header shown when `collapsible` is set; ignored otherwise.
  title?: string
}

/// A button that invokes a named hook method (e.g. 'testCredentials')
/// against the current form/panel state and shows the returned string as a
/// result banner. Declarative like `NoticeAction` below — core renders and
/// dispatches it, the hook just returns a result.
export interface FormActionElement {
  /// Row presentation opens a secondary surface; the default is a button.
  style?: "row"
  icon?: string
  type: "action"
  key: string
  label: string
  method: string
  devMode?: boolean
  /// Settings-panel-only; see FormField.common.
  common?: boolean
  /// Settings-panel-only; see FormField.environment.
  environment?: string | string[]
  /// Settings-panel-only; see FormField.target.
  target?: string | string[]
}

/// A row that opens an external URL (rendered as an icon-row-styled tile
/// with an open-in-new icon button). How the URL opens is app policy — the
/// element only declares the destination.
///
/// Only `http:`, `https:` and `mailto:` are opened; any other scheme is
/// ignored. Ask if you need one that isn't on that list.
export interface FormLinkElement {
  type: "link"
  /// Identifies the element (e.g. to search); not a field — links carry no
  /// value and never appear in form state.
  key?: string
  label: string
  url: string
  icon?: string
  description?: string
  devMode?: boolean
  /// Settings-panel-only; see FormField.common.
  common?: boolean
  /// Settings-panel-only; see FormField.environment.
  environment?: string | string[]
}

export type FormElement = FormField | FormHeader | FormSectionDivider | FormMarkdownBlock | FormActionElement | FormLinkElement

export interface FormDefinition {
  title?: string
  subtitle?: string
  elements: FormElement[]
  onChange?: (fieldKey: string, value: any, state: Record<string, any>) => Promise<Record<string, any> | void> | Record<string, any> | void
}

export interface FormHook {
  getDefinition(args: { formId?: string }, ctx: HookContext): Promise<FormDefinition>
  validateField?(args: { formId?: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<string | null>
  transformField?(args: { formId?: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<any>
  onChangeField?(
    args: { formId?: string; fieldKey: string; value: any; state: Record<string, any> },
    ctx: HookContext,
  ): Promise<Record<string, any> | null | void>
}

export interface SettingsPanelDescriptor {
  /// Must equal the extension's own key, or be prefixed `<extensionKey>_`
  /// — e.g. extension `pota` may return panels keyed `pota` and
  /// `pota_spots`, never bare `spots` or camelCase `potaSpots`. Same rule
  /// as SimpleSettingsPanel.key/DynamicSettingsPanel.key below; it applies
  /// here too since a Tier 2 panel with multiple entries needs the same
  /// per-panel key uniqueness/namespacing.
  key: string
  title: string
  icon?: string
  order?: number
  /// Defaults to true. Set false to keep this panel out of the app's
  /// top-level settings navigation (the sidebar list of panels).
  /// Independent of [dataFilesSection] below — this only controls the
  /// top-level nav, not where else (if anywhere) the panel surfaces.
  ///
  /// For an extension the app did not ship, the entry also needs the
  /// manifest's `settings.sidebar: true`, which the catalog reviews; without
  /// it this reads as false (docs/extensions/settings.md).
  sidebar?: boolean

  /// Defaults false. Set true to also show this panel as a row in the Data
  /// Files screen's own "Extensions" section
  /// (app/lib/views/settings/data_files_panel.dart's `_dataFileScopedPanels`) — for a
  /// data-file-management panel (e.g. enabling/disabling individual note
  /// sources) that belongs there instead of, or in addition to, the
  /// top-level nav. Leave this false for anything not actually about
  /// managing data files; `section` places a panel inside one of the app's
  /// other settings sections. Independent of `sidebar`, deliberately:
  /// inferring it from `sidebar: false` would sweep any sidebar-opt-out
  /// panel into Data Files whether or not that made sense for it.
  dataFilesSection?: boolean

  /// The key of one of the app's own settings sections (`'spotting'`, the
  /// Spotting section) to show this panel inside, as a single row that
  /// opens it in a dialog — in place of a section of its own in Settings
  /// and an entry in the sidebar, whatever `sidebar` says. For a panel that
  /// is one part of something the app already has a section for, such as a
  /// spot source's destinations under Spotting. An app without that section
  /// — an older one, or a key it does not know — shows the panel as it would
  /// without this, so setting it needs no newer API level.
  ///
  /// Declare the same section in the manifest's `settings.section`: the app
  /// places an extension's panels by its manifest, and reads this only for
  /// one whose manifest names none — and then only a [SettingsSection]. An
  /// app older than the manifest field reads this alone.
  section?: string
}

/// Same shape as FormField, but validate/transform closures are dropped in
/// favor of a declarative `pattern` — a Tier 1 panel is captured once at
/// registerHook time, so a closure there wouldn't avoid a bridge call the
/// way it does for a live form; `pattern` gets the common cases (required,
/// regex, numeric range) with none. `itemFields` is re-typed to
/// SettingsField[] (not the inherited FormField[]) so the same restriction
/// applies recursively to list items — otherwise a 'list' field's items
/// could smuggle validate/transform closures back in.
export interface SettingsField extends Omit<FormField, "validate" | "transform" | "itemFields"> {
  pattern?: string
  patternError?: string
  itemFields?: SettingsField[]
  /// Extra names this setting answers to in the Settings search box and in
  /// the SET/SHOW/HIDE commands, alongside its key, label and description —
  /// for a setting whose real name is a poor thing to type. See
  /// docs/extensions/settings.md. Matched case- and punctuation-insensitively,
  /// so declaring spacing or case variants of a name that already matches buys
  /// nothing.
  /// A single string is accepted as well as a list.
  aliases?: string | string[]
}

/// Tier 1: declarative settings, registered once at activation. The engine
/// owns persistence (kv, or FlutterSecureStorage for fieldType 'secret')
/// and declarative validation — no bridge call per keystroke. `fields` may
/// include a `FormActionElement` (e.g. a "Clear Cache" or "Re-sync Now"
/// button unrelated to any account) — its `method` is resolved against an
/// extra, undeclared property on this same object (the SDK's `Hook` union
/// includes `Record<string, unknown>`, so TS permits it without a cast).
/// Account credentials/testCredentials are not part of this schema at all —
/// see AccountHook.
export interface SimpleSettingsPanel {
  kind: "simple"
  /// Defaults to the extension's own key. If overridden (an extension with
  /// more than one panel), must equal the extension key or be prefixed
  /// `<extensionKey>_` — see SettingsPanelDescriptor.key's doc comment.
  key?: string
  title: string
  icon?: string
  order?: number
  /// See SettingsPanelDescriptor.sidebar's doc comment.
  sidebar?: boolean
  /// See SettingsPanelDescriptor.dataFilesSection's doc comment.
  dataFilesSection?: boolean
  /// See SettingsPanelDescriptor.section's doc comment.
  section?: string
  fields: (SettingsField | FormActionElement)[]
}

/// Tier 2: for panels whose fields, values, or validation depend on
/// runtime state the engine can't compute itself. Mirrors FormHook, plus
/// panel discovery and a persistence-on-commit hook (onChangeField here is
/// "go persist this," not FormHook's "patch sibling form state").
export interface DynamicSettingsPanel {
  kind: "dynamic"
  /// Same naming rule as SimpleSettingsPanel.key — only actually used as a
  /// panel key when `getPanels` is omitted (single-panel case); when
  /// `getPanels` is present, each returned SettingsPanelDescriptor.key
  /// governs instead.
  key?: string
  getPanels?(args: Record<string, never>, ctx: HookContext): Promise<SettingsPanelDescriptor[]>
  getDefinition(args: { panelKey: string }, ctx: HookContext): Promise<FormDefinition>
  validateField?(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<string | null>
  transformField?(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<any>
  onChangeField(args: { panelKey: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<void>
}

/// Registered under category 'settingsPanel'. Core discriminates by the
/// required `kind` tag, not by shape. Complementary to AccountHook (see
/// its doc comment) rather than a replacement for it — a settings panel
/// can reference an account via `fieldType: 'account'` but never defines
/// or stores account data.
export type SettingsPanelHook = SimpleSettingsPanel | DynamicSettingsPanel

/// An action button on a status bar notice. Declarative, not a callback —
/// the core renders and handles these itself (`link` opens a URL, `dialog`
/// shows a markdown dialog), matching the same "extensions describe UI as
/// data" convention as `ActivityHook`.
///
/// A `link` opens only `http:`, `https:` or `mailto:`; any other scheme is
/// ignored. Ask if you need one that isn't on that list.
export type NoticeAction =
  | { label: string; type: "link"; url: string }
  | { label: string; type: "dialog"; title?: string; text: string }
  /// Opens the given account's own standalone dialog (Settings → Accounts).
  /// `key` matches the account's `kvKey` (see AccountHook); `subkey` is the
  /// same extension-defined discriminator as FormField.account's.
  | { label: string; type: "account"; key: string; subkey?: string }

export interface StatusBarMessageParams {
  key: string
  icon?: string
  title?: string
  text?: string
}

export interface StatusBarProgressParams {
  key: string
  icon?: string
  title?: string
  text?: string
  /// Omit for an indeterminate progress bar; otherwise 0.0-1.0.
  value?: number
}

export interface StatusBarNoticeParams {
  key: string
  icon?: string
  title?: string
  text: string
  actions?: NoticeAction[]
}

/// What a panel asks to be re-rendered on. The host debounces and only
/// renders panels that are actually on screen, but the trigger list is what
/// keeps a panel out of the per-keystroke path entirely: without one, every
/// visible extension panel would cross the bridge for every callsign
/// keystroke.
///
///   'operation'  the operation's own data changed (activities, title, refs)
///   'qso'        the in-progress QSO changed (throttled, not per keystroke)
///   'qsoLogged'  a QSO was logged, deleted or edited
///   'lookup'     a callsign lookup resolved
///   'spots'      the spots board changed (see HookContext.getSpots)
///   'tick:<n>'   every <n> seconds while the panel is visible (min 1)
///
/// A panel with no triggers renders once when it appears, and again only
/// when its own config form changes — right for a panel showing static
/// reference material.
export type PanelTrigger = "operation" | "qso" | "qsoLogged" | "lookup" | "spots" | `tick:${number}`

/// One panel an extension contributes. Several may come from one extension,
/// each with its own identity and config form; the host addresses them as
/// `ext:<hookKey>:<key>`, where hookKey is the key this hook was registered
/// under (they are the same string unless you registered under another).
export interface PanelDescriptor {
  /// Unique within the extension. Becomes part of the panel's persisted
  /// layout id, so renaming it drops the panel out of saved arrangements.
  key: string
  /// The tab label, and the name in the Layout Setup sheet.
  title: string
  /// One line, shown where the operator is choosing panels to add.
  description?: string
  /// MDI icon name, matching the rest of the extension's controls.
  icon?: string
  /// A still image for the Layout Setup sheet: an SVG document, or a `data:`
  /// URI. Not a URL — the sheet must render offline and without a fetch.
  preview?: string
  on?: PanelTrigger[]
  /// Whether an operator may place more than one of this panel in a layout.
  /// Default false — most panels are one thing, and two copies of a map
  /// would be a mistake to offer. Set it for a panel whose content is the
  /// operator's OWN (a note, a scratchpad), where two is the point.
  ///
  /// Each placement gets its own config, so `args.config` differs per pane
  /// with nothing to do on your side. Give each one a `title` in the render
  /// result, or every tab reads the same.
  multiple?: boolean
  /// The panel's own configuration, in the same declarative field schema a
  /// SimpleSettingsPanel uses and rendered by the same core form renderer.
  /// Values are host-persisted per panel and handed back in
  /// `PanelRenderArgs.config`.
  form?: SettingsField[]
}

/** Resolved host typography; sizes are logical pixels, not the app Font Scale. */
export interface PanelTypography {
  fontFamily: string | null
  fontFamilyFallback: string[]
  fontSize: number
  /** OS text scaling at this exact role size (the scaler may be nonlinear). */
  scaledFontSize: number
  fontWeight: number
  lineHeight: number
  letterSpacing: number
}

/** Current placement environment. Never multiply coordinates by devicePixelRatio. */
export interface PanelEnvironment {
  version: 1
  width: number
  height: number
  safeInsets: { left: number; top: number; right: number; bottom: number }
  brightness: "light" | "dark"
  colors: Record<
    | "surface"
    | "surfaceContainer"
    | "onSurface"
    | "onSurfaceVariant"
    | "accent"
    | "primary"
    | "onPrimary"
    | "secondary"
    | "outline"
    | "outlineVariant"
    | "error"
    | "onError",
    string
  >
  typography: Record<"body" | "label" | "title" | "display" | "mono", PanelTypography>
  locale: string
  textDirection: "ltr" | "rtl"
  devicePixelRatio: number
  reducedMotion: boolean
  highContrast: boolean
}

/** A local CAT radio. Values are reported readings, never manual VFO fallbacks. */
export interface PanelRadioState {
  id: string | null
  name: string | null
  /** Physical device shared by logical radios, when the host exposes more than one receiver. */
  deviceId?: string
  /** Receiver identity within the device. Keys are opaque; labels are for display. */
  channel?: { key: string; label: string }
  status: "disconnected" | "connecting" | "connected" | "disconnecting" | "error"
  stale: boolean
  problem: string | null
  frequencyHz: number | null
  mode: string | null
  powerWatts: number | null
  transmitting: boolean | null
  meters: Partial<Record<"signalDbm" | "powerOut" | "swr" | "alc" | "supplyVolts", number>>
  canTune: boolean
  /** The model's rated output ceiling, where the app knows it (extension API 7). */
  maxWatts?: number | null
  /**
   * The radio's antenna tuner as it reports it, or null for a radio without one, or whose driver
   * cannot read it (extension API 7).
   */
  tuner?: "inline" | "bypassed" | "tuning" | "failed" | null
  /**
   * Whether the radio starts a tune apart from putting its tuner in line — `setRadio`'s `startTune`.
   * False on a FlexRadio, whose in line already is the tune, and wherever `tuner` is null
   * (extension API 9).
   */
  canStartTune?: boolean
  /**
   * The receive filter's edges in Hz from the tuned frequency, as the radio shows them — `100`…`2800`
   * in USB, `-2800`…`-100` in LSB, around zero in CW — or null where its driver cannot read it
   * (extension API 7).
   */
  passband?: { lowHz: number; highHz: number } | null
  /**
   * The radio's own antenna ports, by the radio's names, and which it uses — or null where its driver
   * cannot read them. `separate`: it picks receive and transmit antennas independently, as a FlexRadio
   * does; otherwise one port serves both (extension API 7).
   */
  antennas?: { rxPorts: string[]; txPorts: string[]; rx: string | null; tx: string | null; separate: boolean } | null
  /** The modes `setRadio` accepts for this radio, in the radio's order (extension API 7). */
  modes?: string[]
  /**
   * What the app keys with, while this is the logging radio, connected, and the app's keying
   * is on; null otherwise (extension API 7).
   */
  keying?: PanelRadioKeying | null
  /**
   * The last transmission the radio finished since the app started: its average SWR over the readings taken with
   * RF out (null when there were none), and when it ended in real milliseconds — compare it with
   * `clock.realNowMillis` (extension API 7).
   */
  lastTransmission?: { swrAverage: number | null; endedAtMillis: number } | null
  /**
   * The radio's scope: absent on an app without a panadapter, and null
   * for a radio without one. The sweeps are never sent — a `spectrum` scene control draws them.
   */
  spectrum?: PanelRadioSpectrum | null
}
export type PanelRadioSpectrumSpeed = "slow" | "mid" | "fast"
export interface PanelRadioSpectrum {
  /** Why nothing can be drawn, in the operator's language, or null. */
  problem: string | null
  mode: "center" | "fixed" | null
  /** Half the width shown while centered — what the radio's menu shows as ±. */
  spanHz: number | null
  /** The edges while fixed. */
  lowHz: number | null
  highHz: number | null
  refLevelDb: number | null
  speed: PanelRadioSpectrumSpeed | null
  /** What `setRadioSpectrum` accepts. A span between two is snapped to the nearer. */
  spansHz: number[]
  refMinDb: number
  refMaxDb: number
  refStepDb: number
  modes: ("center" | "fixed")[]
  speeds: PanelRadioSpectrumSpeed[]
}
export interface PanelRadioSpectrumSet {
  /** Reject if this identity no longer matches the selected radio. */
  id: string
  selection?: string
  mode?: "center" | "fixed"
  spanHz?: number
  refLevelDb?: number
  speed?: PanelRadioSpectrumSpeed
}
/** The logging radio's keying: the designated key, radio1's voice memories and its PTT. */
export interface PanelRadioKeying {
  canKeyCw: boolean
  cwSending: boolean
  /** The key's own report, clamping included; null before it has said. */
  keyerSpeedWpm: number | null
  keyerSpeedRange: { min: number; max: number } | null
  canPtt: boolean
  /** Whether the app's PTT latch is holding the transmitter. */
  ptt: boolean
  /** Empty when the radio plays none. `number` is what `playRadioVoice` takes. */
  voiceMemories: { number: number; label: string }[]
}
/** A radio identity and selection, as every command carries. */
export interface PanelRadioTarget {
  /** Reject if this identity no longer matches the selected radio. */
  id: string
  /** Pin a local radio by ID; omitted means follow the designated radio. */
  selection?: string
}
export interface PanelRadioSet extends PanelRadioTarget {
  frequencyHz?: number
  /**
   * The frequency comes from an on-screen dial turning, not a typed or clicked target: on the
   * logging radio, the app's Smart VFO Snap settles it like the radio's own knob (extension API 7).
   */
  dial?: boolean
  /** One of the radio's `modes`. */
  mode?: string
  /** Up to `maxWatts` where the radio states one. On the logging radio this is the power the next QSO logs. */
  powerWatts?: number
  /** The logging radio's keyer; refused as `unsupported` where `keying.canKeyCw` is false. */
  keyerSpeedWpm?: number
  /**
   * Puts the antenna tuner in line or bypasses it; refused as `unsupported` where `tuner` is null.
   * On a FlexRadio, in line is a TUNE — a carrier on the air — since its tuner has no other way in.
   */
  tunerInline?: boolean
  /**
   * Starts a tune — a carrier on the air until the tuner settles. Only for an operator's explicit
   * press. Goes alone: with any other setting in the same call it is `invalid`; `unsupported` where
   * `canStartTune` is false (extension API 9). Not a keying call: it reaches the radio the panel
   * shows, with keying on or off. `host.stopRadioTransmit()` ends a tune the app started.
   */
  startTune?: true
  /**
   * The receive filter, as `passband` reports it; refused as `unsupported` where that is null. A
   * radio that sets only a width from a table takes the nearest, keeping its own shift — read the
   * result back from `passband`.
   */
  passband?: { lowHz: number; highHz: number }
  /** Ports from `antennas`; refused as `unsupported` where that is null. Without `separate`, either names the one port. */
  antenna?: { rx?: string; tx?: string }
}
/** @deprecated `setRadio`'s argument through extension API 6. */
export type PanelRadioTune = PanelRadioSet
/**
 * Commands in the radio's own protocol — exactly one of `text` or `bytes`, up to 4096 bytes
 * (extension API 11). Where the app's driver keeps one question on the wire (CI-V, Yaesu binary,
 * HRD, Commander, flrig) each command waits its turn in that queue, and on a FlexRadio is numbered
 * like the driver's own; the reply is then the answers to these commands alone. Elsewhere the bytes
 * are written as given. See hooks.md for what each protocol takes.
 */
export interface PanelRadioRaw extends PanelRadioTarget {
  /** Sent as UTF-8: Kenwood, Yaesu and Elecraft ASCII, rigctld, N3FJP, SmartSDR, HRD, Commander, flrig. */
  text?: string
  /** Each 0…255: Icom CI-V, Yaesu's binary protocol. */
  bytes?: number[]
  /**
   * How long to wait for the reply, up to 2000 ms; omitted or 0, the call answers once the commands
   * are handed to the driver. Where they are written as given, the reply is everything the radio
   * sent in that time — the answers to the app's own polls included.
   */
  replyMs?: number
  /** Ends the reply early, just after the first occurrence of this text or these bytes. Needs `replyMs`. */
  until?: string | number[]
}
export interface PanelRadioRawResult extends PanelRadioResult {
  /** What came back within `replyMs`, possibly nothing, at most 64 KiB; absent without `replyMs`. `text` is it as UTF-8. */
  reply?: { text: string; bytes: number[] }
}
export interface PanelRadioResult {
  /** Accepted by the host; confirmation still comes from reported state. */
  accepted: boolean
  /**
   * `stopped`: a scope change while no display has the scope running — nothing was sent.
   * `busy`: eight raw commands to this radio are already waiting (extension API 11).
   * `unsupported`: this radio, or the app's keying, cannot do it — keying calls on a radio that
   * is not the logging radio, or with the app's keying off.
   */
  reason?: "changed" | "disconnected" | "transmitting" | "invalid" | "stopped" | "unsupported" | "busy"
  state: PanelRadioState | null
}
/** @deprecated `PanelRadioResult`'s name through extension API 6. */
export type PanelRadioTuneResult = PanelRadioResult

/// The context a panel renders against. Deliberately NOT the whole log: an
/// operation's QSOs are fetched on demand through `ctx.getQsos`, which the
/// panel is free to call — a render triggered by 'qsoLogged' is exactly the
/// place for it, and a per-keystroke one is not.
export interface PanelRenderArgs {
  /** Present on environment-capable hosts. Changes automatically request a throttled render of a `scene` panel. */
  environment?: PanelEnvironment
  /** Display time follows developer time travel; real time is for network retry/cache budgets. */
  clock?: { nowMillis: number; realNowMillis: number }
  /** Stable placement identity, supplied by scene-capable hosts. */
  instanceId?: string
  panelKey: string
  operation: Record<string, JSONValue>
  /// The QSO being entered right now, including `their.guess` from the
  /// callsign lookup. Absent when there is no logging panel in the view, and
  /// absent unless some panel in the arrangement declared 'qso' OR 'lookup'
  /// — producing it costs the host work on the typing path, so it is not
  /// produced for nobody, but a resolved guess lives in here and nowhere
  /// else, so declaring 'lookup' is enough to be sent it. Do not add 'qso'
  /// just to receive this: that buys per-pause renders you did not want.
  /// Present with an empty `their.call` before anything is typed: the band
  /// and mode are the radio's, and are real either way.
  qso?: Record<string, JSONValue>
  /// How many real QSOs the operation holds (event markers excluded), so a
  /// panel can show a count without reading the log.
  qsoCount: number
  /// This panel's own config values, keyed by field.
  config: Record<string, JSONValue>
  /// What caused this render — the trigger name, or 'initial'.
  reason: string
}

/// A panel's content, rendered natively by the core: markdown through the
/// app's own typography, SVG as a vector image, HTML in a sandboxed web
/// view. Prefer markdown — it inherits the app's theme, font scale and
/// density for free, costs no web view, and is the only kind that renders
/// everywhere: `html` needs a web view that can actually hold it to the
/// sandbox, which rules out Linux, Windows without the WebView2 runtime, and
/// the web build (see `panel` in docs/extensions/hooks.md).
/// `title` overrides the tab label for this rendering. Optional, and only
/// worth setting on a `multiple` panel — otherwise the descriptor's title
/// already names it, and three panes reading the same thing is exactly what
/// this exists to avoid. Blank is ignored rather than producing a nameless
/// tab.
///
/// `triggers` re-renders THIS placement on the named signals, added to
/// whatever the descriptor declared and taking the same values
/// (`PanelDescriptor.triggers`, including `tick:<seconds>`). A descriptor's
/// triggers are paid by every placement of that panel; these are not — which
/// is what lets a panel rendering OPERATOR-written text ask for only what
/// that text turned out to need (`triggersForTemplate`). Unknown names are
/// dropped with a line in the console.
///
/// The declaration lands after the render that carried it, so the first
/// render of a panel that asks for `qso` is answered without one; it is woken
/// by the next change to the draft.
export type PanelContent =
  | { kind: "scene"; scene: PanelScene; title?: string; triggers?: string[] }
  /**
   * @deprecated The same kind as `scene`, under its name through SDK 0.9. Apps before extension
   * API 5 know only `svgScene`; `scene` needs `"api": 5`, as do native controls, `strings` and `layout`.
   */
  | { kind: "svgScene"; scene: PanelScene; title?: string; triggers?: string[] }
  | { kind: "markdown"; content: string; title?: string; triggers?: string[] }
  | { kind: "svg"; content: string; title?: string; triggers?: string[] }
  | { kind: "html"; content: string; title?: string; triggers?: string[] }

/// Registered under category 'panel'. Same two-call shape as
/// `settingsPanel`'s dynamic tier: discovery once, then content on demand.
export interface PanelHook {
  getPanels(args: Record<string, never>, ctx: HookContext): Promise<PanelDescriptor[]>
  render(args: PanelRenderArgs, ctx: HookContext): Promise<PanelContent>
  onEvent?(args: PanelRenderArgs & { event: PanelSceneEvent }, ctx: HookContext): Promise<PanelSceneEventResult>
}
