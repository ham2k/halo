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

export type { CallInfo, CallInfoLookup, AnnotatedCallInfo } from "@ham2k/lib-qson-tools"
import type { CallInfo, CallInfoLookup, AnnotatedCallInfo } from "@ham2k/lib-qson-tools"

/// A lookup hook may return zero or more records for one decoration pass —
/// `[]` to skip (e.g. the field it would provide is already known).
export type LookupResult = CallInfoLookup[]

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
  /// Set when `input` is a recognized command prefix that isn't complete yet
  /// (e.g. "RELOAD" before its target word) — `describe`/`confirm`/`commands`
  /// are omitted. Signals the call field to switch into free-text mode
  /// (spaces and platform-normal capitalization allowed) so the user can keep
  /// typing parameters; it is never executed even if Enter is pressed while
  /// still set.
  expectsParams?: boolean
  describe?: string
  confirm?: string
  commands?: CommandAction[]
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

/// Registered under category `account`. One hook per account; core
/// aggregates every extension's `account` hook via `invokeHookAll` into the
/// account list shown in Settings. Accounts are defined, stored (credentials
/// in secure storage, keyed by `kvKey`), and edited independently of
/// `settingsPanel` — each account gets its own standalone dialog. A
/// `settingsPanel` field can reference an account for display/navigation
/// via `fieldType: 'account'` (see FormField), but does not define or store
/// account data itself.
export interface AccountHook {
  label: string
  /// Defaults to the extension's own key. If overridden (an extension with
  /// more than one account), must equal the extension key or be prefixed
  /// `<extensionKey>_` — e.g. extension `lofi` may use `lofi` or
  /// `lofi_backup`, never bare `backup` or camelCase `lofiBackup`. Keeps
  /// every account keyed under its owning extension's namespace, which is
  /// how storage collisions are prevented and (later) how KV access
  /// control will be scoped.
  kvKey?: string
  fields?: AccountField[]
  oauth2?: OAuth2Config
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
  | 'secret'
  | 'list'
  | 'account'

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
  /// Only used when fieldType === 'list'. `value` is then a
  /// Record<string, any>[], each item matching the shape described by
  /// `itemFields`. Rows render as a summary (from `itemTitle`, templated
  /// against the item's values) with edit/delete; edit/add reuse the same
  /// form renderer recursively, scoped to `itemFields`, in a dialog.
  itemFields?: FormField[]
  itemTitle?: string
  orderable?: boolean
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

export type FormElement = FormField | FormHeader | FormSectionDivider | FormMarkdownBlock | FormActionElement

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
