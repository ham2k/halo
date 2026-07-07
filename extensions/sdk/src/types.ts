// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

export type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue }

export interface HookContext {
  online: boolean
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

export interface ActivityHook {
  /// Controls shown on the logging panel for this operation.
  loggingControls?(args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
  /// Controls shown in operation settings (e.g. "which park am I activating").
  operationControls?(args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]>
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

/// A field-change command triggered from the call field (space-activated).
/// Deliberately a closed set of fields — commands mutate only through this
/// whitelist, never arbitrary state (DESIGN.md §4). `action` is the same
/// discipline applied to named side effects instead of field changes — a
/// closed set of core-recognized actions (currently just `'syncAll'`, the
/// `SYNCALL` debug command), not an arbitrary string the core has to trust.
export interface CommandResult {
  freq?: number
  band?: string
  mode?: string
  action?: 'syncAll'
}

/// Registered under category `command`. `tryCommand` does its own matching
/// (returns null for no match) so the core can fan out to every registered
/// command via invokeHookAll and apply the first non-null result in
/// priority order, without the host needing to compile extension-supplied
/// regex source itself.
export interface CommandHook {
  tryCommand(args: { input: string }, ctx: HookContext): Promise<CommandResult | null>
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

export type Hook =
  | LookupHook
  | SpotsHook
  | ExportHook
  | RefHandlerHook
  | ActivityHook
  | AdifFieldsHook
  | CommandHook
  | SyncTransportHook
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
