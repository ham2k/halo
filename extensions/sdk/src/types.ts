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
}

export interface CallInfo {
  call: string
  baseCall?: string
}

export interface LookupRecord {
  source: string
  call?: string
  name?: string
  city?: string
  state?: string
  country?: string
  grid?: string
  lat?: number
  lon?: number
  image?: string
  error?: string
}

export interface LookupHook {
  lookupCall(args: { callInfo: CallInfo }, ctx: HookContext): Promise<LookupRecord>
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
  spot: {
    timeInMillis: number
    source: string
    label?: string
    sourceInfo?: Record<string, JSONValue>
  }
}

export interface SpotsHook {
  sourceName: string
  fetchSpots(args: Record<string, never>, ctx: HookContext): Promise<Spot[]>
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

/// Handles one ref type (registered under category `ref:<type>`).
export interface RefHandlerHook {
  /// Cheap synchronous-ish validation/normalization of user input.
  validateRef?(args: { ref: Ref }, ctx: HookContext): Promise<{ valid: boolean; normalized?: string }>
  /// Enriches a ref with names/locations, possibly via the network.
  decorateRef?(args: { ref: Ref }, ctx: HookContext): Promise<Ref>
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
  order?: number
  optionType?: 'optional' | 'mandatory'
  input: RefListInputDescriptor
}

export interface RefListInputDescriptor {
  kind: 'refList'
  refType: string
  placeholder?: string
  /// Regex source string; the core pre-validates input before accepting a chip.
  pattern?: string
}

/// A candidate activity/reference offered to the user while adding an
/// activity — same shape as `Ref` plus ranking info. `distance` is km from
/// the `location` given in `SuggestArgs` (omitted if either side lacks a
/// location); `relevance` is an extension-defined 0..1 match quality (search
/// term match, popularity, etc). The core sorts combined results across all
/// extensions by `distance * relevance` (lower is better), so extensions
/// should return both as consistently comparable as possible.
export interface ActivitySuggestion extends Ref {
  distance?: number
  relevance?: number
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
  /// Controls shown on the logging panel for this operation.
  loggingControls?(args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
  /// Controls shown in operation settings (e.g. "which park am I activating").
  operationControls?(args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
  /// Candidate activities for the "add activity" search/suggestions list —
  /// nearby references when `searchTerm` is empty, name/code matches when set.
  suggest?(args: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]>
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
}

export interface ExportResult {
  filename: string
  mimeType: string
  content: string
}

export interface ExportHook {
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

/// All rules' verdicts for one QSO, keyed by rule key (e.g. 'dupe', 'dxcc',
/// 'bandsAndModes'). Cached verbatim into `qsos.score_cache`.
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

export interface ScoreQsosRequest {
  operation: Record<string, JSONValue>
  qsos: Record<string, JSONValue>[]
}

export interface ScoreQsosResult {
  /// Keyed by QSO uuid — written verbatim into that QSO's `score_cache` column.
  qsoScores: Record<string, QsoScoreEntry>
  daySections: DayScoreSummary[]
  /// Cumulative tallies across the whole operation (last day section's
  /// running totals) — cached on the operation, not any one QSO.
  operationSummary: Record<string, ScoreTally>
}

/// Registered under category `scoring`. One coarse batched call scores an
/// entire operation's QSOs at once (DESIGN.md §4: "score 500 QSOs in one
/// call, not 500 calls") — day-sectioning and accumulation both happen here,
/// inside the runtime, not orchestrated call-by-call from Dart.
export interface ScoringHook {
  scoreQsos(args: ScoreQsosRequest, ctx: HookContext): Promise<ScoreQsosResult>
}

export interface CommandAction {
  setVfo?: {
    freq?: number
    band?: string
    mode?: string
  }
  updateQso?: Record<string, JSONValue>
  addQso?: Record<string, JSONValue>
  sendSpots?: {
    comment?: string
  }
  syncAll?: Record<string, never>
  updateSettings?: {
    developerMode?: boolean
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
  devNotice?: { icon?: string; title?: string; text: string }
  /// Developer-only: posts a transient status message (DEVSTATUS). `key`
  /// lets the caller post more than one at once (e.g. a fresh key per call)
  /// instead of always replacing the same status item.
  devStatus?: { key?: string; icon?: string; title?: string; text?: string }
  /// Developer-only: posts a progress bar (DEVPROGRESS); omit `percent` for
  /// an indeterminate bar.
  devProgress?: { icon?: string; title?: string; percent?: number }
  [actionName: string]: unknown
}

export interface CommandInterpretation {
  describe: string
  confirm: string
  commands: CommandAction[]
}

/// Registered under category `command`. `interpret` does its own matching
/// (returns null for no match) so the core can fan out to every registered
/// command via invokeHookAll and apply the first non-null result in
/// priority order, without the host needing to compile extension-supplied
/// regex source itself.
export interface CommandHook {
  interpret(
    args: { input: string; operation?: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
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
/// linked to.
export interface SyncResponse {
  operations?: Record<string, JSONValue>[]
  qsos?: Record<string, JSONValue>[]
  meta?: Record<string, JSONValue>
  account?: Record<string, JSONValue>
}

/// Registered under category `syncTransport`. Handles authentication and
/// the actual network calls; the core owns the sync loop, batching, and
/// dirty flags so sync keeps working even if the JS runtime is wedged.
export interface SyncTransportHook {
  sync(payload: SyncPayload, ctx: HookContext): Promise<SyncResponse>
  getAccountData(args: Record<string, never>, ctx: HookContext): Promise<Record<string, JSONValue>>
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

export interface AccountHook {
  label: string
  kvKey?: string // defaults to the extension key
  fields?: AccountField[]
  oauth2?: OAuth2Config
  testCredentials(credentials: Record<string, string>, ctx: HookContext): Promise<string>
}

export type Hook =
  | LookupHook
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
  | Record<string, unknown>

export interface RegisterHookParams {
  hook: Hook
  key?: string
  priority?: number
}

export interface ActivationApi {
  registerHook(category: string, params: RegisterHookParams): void
}

export interface ExtensionDefinition {
  key: string
  name: string
  version: string
  description?: string
  onActivation(api: ActivationApi): void
}

export interface FetchOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
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
  name: string
  description: string
  url: string
  maxAgeInDays: number
  fetchType: FetchType

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

export interface FormFieldOption {
  label: string;
  value: any;
}

export interface FormField {
  type: 'field'
  fieldType: FormFieldType
  key: string
  label: string
  value?: any
  placeholder?: string
  options?: FormFieldOption[]
  validate?: (value: any, state: Record<string, any>) => string | null | undefined | Promise<string | null | undefined>
  transform?: (value: any, state: Record<string, any>) => any | Promise<any>
}

export interface FormHeader {
  type: 'header'
  title: string
  subtitle?: string
}

export interface FormSectionDivider {
  type: 'divider'
  title?: string
}

export interface FormMarkdownBlock {
  type: 'markdown'
  text: string
}

export type FormElement = FormField | FormHeader | FormSectionDivider | FormMarkdownBlock

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

/// An action button on a status bar notice. Declarative, not a callback —
/// the core renders and handles these itself (`link` opens a URL, `dialog`
/// shows a markdown dialog), matching the same "extensions describe UI as
/// data" convention as `ActivityHook`.
export type NoticeAction =
  | { label: string; type: 'link'; url: string }
  | { label: string; type: 'dialog'; title?: string; text: string }

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
