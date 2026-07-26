// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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
  /// The running build's edition ('dev' | 'next' | 'prod' — see
  /// packages/halo_build_tools/lib/src/edition.dart), for a hook whose
  /// static configuration must vary per-edition (e.g. SOTA's OAuth client:
  /// each edition's app identity is registered as its own client with
  /// SOTA's Keycloak, ham2k/app-halo-dist#253).
  edition?: string
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
  /// `[]`, which means the operation exists and simply has no QSOs yet. A
  /// whole-log read crossing the bridge: fine for command execution or an
  /// export-sized job, not for per-keystroke paths.
  getQsos?(operationUuid: string): Promise<Record<string, JSONValue>[] | null>
}

export type { CallInfo, CallInfoLookup, AnnotatedCallInfo } from "@ham2k/lib-qson-tools"
import type { CallInfo, CallInfoLookup, AnnotatedCallInfo } from "@ham2k/lib-qson-tools"

/// A lookup hook may return zero or more records for one decoration pass —
/// `[]` to skip (e.g. the field it would provide is already known). A result
/// that supplies a location may tag it with a [LOCATION_ACCURACY] rank via
/// `locAccuracy` (lower = more precise); `mergeLookupIntoGuess` keeps the most
/// accurate location when several same-scope sources offer one.
export type LookupResult = (CallInfoLookup & { locAccuracy?: number })[]

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

export interface LookupServiceRequest {
  callInfo: CallInfo
  qso: Record<string, JSONValue>
  operation: Record<string, JSONValue>
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
  presentation: 'status' | 'dialog'
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

/// A reference ties a QSO or operation to an activity program entity
/// (a park, a summit, a contest). Same shape as app-polo's QSON refs.
export interface Ref {
  type: string
  ref?: string
  name?: string
  label?: string
  shortLabel?: string
  grid?: string
  location?: string
  program?: string
  [key: string]: JSONValue | undefined
}

/// A fragment of an operation's title/subtitle sentence, contributed by one
/// ref (ham2k/app-halo-dist#174) — `title`/`for`/`at` are alternative ways
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

/// Handles one ref type (registered under category `ref:<type>`).
export interface RefHandlerHook {
  /// Cheap synchronous-ish validation/normalization of user input.
  validateRef?(args: { ref: Ref }, ctx: HookContext): Promise<{ valid: boolean; normalized?: string }>
  /// Enriches a ref with names/locations, possibly via the network.
  decorateRef?(args: { ref: Ref }, ctx: HookContext): Promise<Ref>
  /// Suggests a title/subtitle fragment for the operation this ref is on.
  suggestOperationTitle?(
    args: { ref: Ref; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<TitleSuggestion | null>
}

/// Declarative UI contribution: the core renders these with native widgets
/// from the catalog (DESIGN.md §5). v0 catalog has one input kind.
export interface LoggingControlDescriptor {
  key: string
  label: string
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
  optionType?: 'optional' | 'mandatory'
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
export type InputDescriptor =
  | RefListInputDescriptor
  | TextInputDescriptor
  | OptionsInputDescriptor
  | SerialInputDescriptor
  | FormInputDescriptor

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
  scope?: ('band' | 'mode')[]
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
/// anything else. Like every primary field it takes its turn in the keyboard
/// cycle — Space and Tab both walk it — since the operator has to be able to
/// reach the field to make that correction without leaving the keyboard.
export interface SerialInputDescriptor {
  kind: 'serial'
  refType: string
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
  kind: 'form'
  refType: string
  form: FormDefinition
}

/// A free-form or pattern-constrained exchange field (contest exchanges: a CQ
/// zone, a Field Day class, a name). The typed value round-trips onto a ref of
/// `refType` under the key `field` — the same core-owned path `refList` writes
/// refs through, so no new persistence is involved.
export interface TextInputDescriptor {
  kind: 'text'
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
/// The set is INLINE. §5.3 sketched a registered `optionSet` for large sets;
/// that was deferred at M5, because nothing can currently write rows into the
/// lookups table (the host exposes three READ calls and no writer) and the
/// largest set any real contest puts in one descriptor is a few hundred
/// entries — small next to the QSO log the scoring hooks already ship on every
/// pass.
export interface OptionsInputDescriptor {
  kind: 'options'
  /// Ref type the value is stored on, as `text`.
  refType: string
  /// Key within that ref.
  field: string
  /// The selectable values. `code` is what goes in the log; `name` is matched
  /// against as well as shown, because a full name is often easier to recall
  /// than an abbreviation.
  options: { code: string; name?: string }[]
  /// Which fields the search looks at. Defaults to both.
  matchOn?: ('code' | 'name')[]
  /// Accept a value that isn't in the set. Off by default: for most of these
  /// exchanges an unknown value is a lost multiplier, and the operator can
  /// still fix it while the QSO is in front of them.
  allowFreeform?: boolean
  /// Float likely values to the top of their tier — a QSO party surfacing the
  /// counties of the caller's guessed state. Ranking rather than pre-filling,
  /// because a location guess is wrong often enough to be annoying, and an
  /// exact code the operator typed in full is never displaced by it.
  preferredCodes?: string[]
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
  kind: 'refList'
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

export interface SuggestArgs {
  operation: Record<string, JSONValue>
  /// The operation's own location if set, otherwise the station's default —
  /// resolved by the core before calling, since operations don't always
  /// carry their own location.
  location?: { lat: number; lon: number }
  /// Same fallback rule as `location`: operation's callsign if set, else the
  /// station default.
  callsign?: string
  searchTerm?: string
}

export interface ActivityHook {
  /// Controls shown on the logging panel for this operation. `qso` is the
  /// in-progress QSO (including any `their.guess` data from the callsign
  /// lookup pipeline) — re-supplied whenever that lookup resolves, not on
  /// every keystroke, so extensions can key a dynamic `placeholder`/
  /// `transforms` (e.g. a DXCC-derived reference prefix) off it.
  loggingControls?(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]>
  /// Controls shown in operation settings (e.g. "which park am I activating").
  operationControls?(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]>
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
  processQsoBeforeSave?(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null>
}

/// Contributes extra ADIF fields per QSO (registered under 'adifFields').
export interface AdifFieldsHook {
  fieldsForOneQSO(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<{ name: string; value: string }[]>
}

export interface ExportRequest {
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
  /// Which of this hook's suggested options to generate — required once a
  /// hook offers more than one via `suggestExportOptions`.
  exportType?: string
}

export interface ExportResult {
  filename: string
  mimeType: string
  content: string
}

export interface ExportOptionsRequest {
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
}

/// One selectable export offered by a hook. `exportType` only needs to be
/// unique within the hook that returned it — the core pairs it with the
/// hook's own registration key when routing a later `generateExport` call.
export interface ExportOption {
  exportType: string
  /// Drives the panel's default mimeType/extension guess, e.g. 'adif'.
  format: string
  label: string
  filename?: string
  icon?: string
  priority?: number
  selectedByDefault?: boolean
  /// The ref type this export is responsible for. Set it and the core hands
  /// `generateExport` only the QSOs made while that activity was actually
  /// running — those in segments carrying a ref of this type (§5.1.4).
  ///
  /// A contest that started at a break, or ended at one, otherwise puts the
  /// WHOLE operation into its Cabrillo, including contacts made when it wasn't
  /// running. That is a false claim in a submitted file, and it is the same
  /// mistake the scorer used to make before §5.1.3 gated it.
  ///
  /// Omit it for an export that genuinely covers the whole log, like the full
  /// ADIF. On an unsegmented operation it changes nothing either way.
  refType?: string
}

export interface ExportHook {
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
  for: 'day' | 'operation'
  icon?: string
  label?: string
  summary?: string
  longSummary?: string
  total: number
  [extra: string]: JSONValue | undefined
}

/// One calendar-day bucket (UTC, following app-polo/web-lofi's convention)
/// with that day's accumulated tallies per rule key.
export interface DayScoreSummary {
  day: number
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
  /// `resumeFrom` on the next append.
  scoresheet?: JSONValue
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
}

/// Merged, de-duped notice/alert keys for one candidate QSO — e.g.
/// `{ alerts: ['duplicate'], notices: ['newBand', 'newDXCC'] }`. The app layer
/// maps each key to localized pill text; unknown keys fall back to the key.
export interface QsoScoreNotices {
  notices: string[]
  alerts: string[]
}

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
}

/// Which operations a scorer applies to. `'always'` scores every operation
/// (DXCC, states, bands-and-modes); a `refTypes` list scores only operations
/// carrying one of those refs, so the core can skip a contest entirely rather
/// than invoke it to be told "not mine". Declared at `registerHook` time.
export type ScoringScope = 'always' | { refTypes: string[] }

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
      scope: 'day' | 'operation'
    },
    ctx: HookContext,
  ): Record<string, ScoreTally>
}

export interface CommandAction {
  setVfo?: {
    freq?: number
    band?: string
    mode?: string
  }
  updateQso?: Record<string, JSONValue>
  addQso?: Record<string, JSONValue>
  /// `target` picks what gets spotted: `'self'` (default) spots the
  /// operation itself at the current VFO; `'last'` spots the most recent
  /// logged QSO (SPOTLAST family) regardless of what's being edited.
  sendSpots?: {
    comment?: string
    target?: 'self' | 'last'
  }
  syncAll?: Record<string, never>
  updateSettings?: {
    developerMode?: boolean
  }
  /// Replaces the call field's entire text, cursor at the end — the
  /// call-notes extension's `//KEY` note expansion. The new text runs
  /// through the same change path as typing, so lookups, dupe checks and
  /// comma-list handling all apply to it normally.
  setCallField?: { text: string }
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
  /// Developer-only: re-shows the startup release-notes overlay (DEVSPLASH),
  /// bypassing its normal "once per version" gate — see
  /// `app/lib/main.dart`'s `_ReleaseOverlayGate`.
  devSplash?: Record<string, never>
  /// Developer-only: re-shows the first-run onboarding overlay (DEVONBOARD),
  /// bypassing its callsign-undefined gate — see `app/lib/main.dart`'s
  /// `_OnboardingGate`.
  devOnboard?: Record<string, never>
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
  mixedCase?: boolean
  describe?: string
  confirm?: string
  commands?: CommandAction[]
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
}

/// A batch of dirty records the core wants pushed to the sync server, plus
/// batching/consent metadata. Batch selection and dirty-flag bookkeeping stay
/// in Dart (DESIGN.md §4) — the hook is a dumb transport, never touching the
/// database itself.
export interface SyncPayload {
  operations?: Record<string, JSONValue>[]
  qsos?: Record<string, JSONValue>[]
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
  meta?: Record<string, JSONValue>
  account?: Record<string, JSONValue>
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
  /// gracefully when it's missing.
  linkClient?(args: { email?: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
  linkClientWithEmail(args: { email: string }, ctx: HookContext): Promise<Record<string, JSONValue>>
}

export interface AccountField {
  key: string
  label: string
  type: 'text' | 'email' | 'secret'
  preface?: string
  postface?: string
}

export interface OAuth2Config {
  issuer: string
  clientId: string
  redirectUrl: string
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
  /// A plain config, or a function for a client that varies per build
  /// edition (`ctx.edition`) — e.g. SOTA registers a separate Keycloak
  /// client per edition (ham2k/app-halo-dist#253). Called the same way any
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
  | RefHandlerHook
  | ActivityHook
  | AdifFieldsHook
  | CommandHook
  | SyncTransportHook
  | AccountHook
  | DataFileDefinition
  | FormHook
  | SettingsPanelHook
  | Record<string, unknown>

export interface RegisterHookParams {
  hook: Hook
  key?: string
  priority?: number
}

export interface ActivationApi {
  registerHook(category: string, params: RegisterHookParams): void

  /// Privileged host-call function bound by the kernel to THIS extension's
  /// identity (host-manifest-derived) — identity params (`ns`, `kvKey`,
  /// `extensionKey`) are injected kernel-side and cannot be spoofed. The
  /// SDK captures it at activation; extension code normally never touches
  /// it directly and just uses the `host` API.
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>
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
  enabledByDefault?: boolean
  /// The hook categories this extension registers (`ref:<type>` for ref
  /// handlers). Declarative/informational — the kernel still learns the
  /// actual hooks from registerHook at activation.
  hooks?: string[]
  /// host.fetch allowlist for this extension's bundle.
  domains?: string[]
  allowUserAgentOverride?: boolean
  /// Per-locale overrides for name/description plus extra localized search
  /// keywords, keyed by language code. Localized keywords ADD to the base
  /// `keywords` (both are searchable), they don't replace them.
  translations?: Record<string, { name?: string; description?: string; keywords?: string[] }>
}

export interface ExtensionDefinition extends ExtensionManifest {
  onActivation(api: ActivationApi): void
}

export interface FetchOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  /**
   * Extra request headers. Note: the host stamps HaLo's canonical
   * `User-Agent` on every request and it overrides any you set here, so
   * don't provide your own — unless your extension declares
   * `allowUserAgentOverride` in build.mjs (see docs/design/network.md).
   */
  headers?: Record<string, string>
  body?: string
}

export interface FetchResponse {
  status: number
  body: string
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

export type FetchType = 'csv' | 'json' | 'raw'

export interface DataFileDefinition {
  key: string
  name: Localizable<string>
  description: Localizable<string>
  /// Usually a plain string. A function when the URL depends on something the
  /// extension must ask for — TOTA's list carries its API key as a query
  /// parameter — resolved once per refresh, like `name` and `description`.
  url: Localizable<string>
  maxAgeInDays: number
  fetchType: FetchType

  /// Character encoding of the fetched file. When omitted the host uses the
  /// response's Content-Type charset, defaulting to `'utf-8'`. Set this
  /// (`'latin1'` / `'iso-8859-1'` / `'ascii'`) to OVERRIDE a server that sends
  /// a wrong or missing charset for a non-UTF-8 source (#317).
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
  | 'text'
  | 'multiline'
  | 'email'
  | 'callsign'
  | 'number'
  | 'select'
  | 'radio'
  | 'checkbox'
  | 'secret'
  | 'list'
  | 'multiselect'
  | 'account'

export interface FormFieldOption {
  label: string;
  value: any;
  /// Only used when fieldType === 'multiselect': disclosure tiers.
  /// `common: true` options show upfront; unflagged ones sit behind the
  /// first disclosure step; `uncommon: true` ones behind the second (the
  /// toggle then cycles Show more → Show all → Show fewer; without any
  /// uncommon options it's just Show all / Show fewer).
  common?: boolean;
  uncommon?: boolean;
}

export interface FormField {
  type: 'field'
  fieldType: FormFieldType
  key: string
  label: string
  value?: any
  placeholder?: string
  /// Forces typed input to uppercase (formatter, not just a soft-keyboard
  /// capitalization hint) on the text-like field types. `callsign` fields
  /// are always uppercase without this flag; use it for other logging data
  /// that follows the uppercase-unless-explicitly-mixed-case rule (grids,
  /// states, RSTs) while free-prose fields (names, notes) stay unflagged.
  uppercase?: boolean
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
  /// per-item rows and add/edit/delete (edit/add reuse the same form
  /// renderer recursively, scoped to `itemFields`, in a nested dialog).
  itemFields?: FormField[]
  itemTitle?: string
  orderable?: boolean
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
}

export interface FormHeader {
  type: 'header'
  title: string
  subtitle?: string
  devMode?: boolean
  /// Defaults to the form dialog's usual bold header look. Set to
  /// 'section' to instead match the compact section-divider style used by
  /// the Sync/Accounts/General settings panels — for a settingsPanel
  /// carving its fields into named groups, not for an ad hoc form's own
  /// title.
  style?: 'default' | 'section'
}

export interface FormSectionDivider {
  type: 'divider'
  title?: string
  devMode?: boolean
}

export interface FormMarkdownBlock {
  type: 'markdown'
  text: string
  devMode?: boolean
}

/// A button that invokes a named hook method (e.g. 'testCredentials')
/// against the current form/panel state and shows the returned string as a
/// result banner. Declarative like `NoticeAction` below — core renders and
/// dispatches it, the hook just returns a result.
export interface FormActionElement {
  type: 'action'
  key: string
  label: string
  method: string
  devMode?: boolean
}

/// A row that opens an external URL (rendered as an icon-row-styled tile
/// with an open-in-new icon button). How the URL opens is app policy — the
/// element only declares the destination.
export interface FormLinkElement {
  type: 'link'
  /// Identifies the element (e.g. to search); not a field — links carry no
  /// value and never appear in form state.
  key?: string
  label: string
  url: string
  icon?: string
  description?: string
  devMode?: boolean
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
  onChangeField?(args: { formId?: string; fieldKey: string; value: any; state: Record<string, any> }, ctx: HookContext): Promise<Record<string, any> | null | void>
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
}

/// Same shape as FormField, but validate/transform closures are dropped in
/// favor of a declarative `pattern` — a Tier 1 panel is captured once at
/// registerHook time, so a closure there wouldn't avoid a bridge call the
/// way it does for a live form; `pattern` gets the common cases (required,
/// regex, numeric range) with none. `itemFields` is re-typed to
/// SettingsField[] (not the inherited FormField[]) so the same restriction
/// applies recursively to list items — otherwise a 'list' field's items
/// could smuggle validate/transform closures back in.
export interface SettingsField extends Omit<FormField, 'validate' | 'transform' | 'itemFields'> {
  pattern?: string
  patternError?: string
  itemFields?: SettingsField[]
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
  kind: 'simple'
  /// Defaults to the extension's own key. If overridden (an extension with
  /// more than one panel), must equal the extension key or be prefixed
  /// `<extensionKey>_` — see SettingsPanelDescriptor.key's doc comment.
  key?: string
  title: string
  icon?: string
  order?: number
  fields: (SettingsField | FormActionElement)[]
}

/// Tier 2: for panels whose fields, values, or validation depend on
/// runtime state the engine can't compute itself. Mirrors FormHook, plus
/// panel discovery and a persistence-on-commit hook (onChangeField here is
/// "go persist this," not FormHook's "patch sibling form state").
export interface DynamicSettingsPanel {
  kind: 'dynamic'
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
export type NoticeAction =
  | { label: string; type: 'link'; url: string }
  | { label: string; type: 'dialog'; title?: string; text: string }
  /// Opens the given account's own standalone dialog (Settings → Accounts).
  /// `key` matches the account's `kvKey` (see AccountHook); `subkey` is the
  /// same extension-defined discriminator as FormField.account's.
  | { label: string; type: 'account'; key: string; subkey?: string }

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
