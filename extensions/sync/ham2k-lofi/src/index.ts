// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `syncTransport` for Ham2K's LoFi sync server, ported from app-polo's
// Ham2KLoFiSyncExtension.js. Batching and dirty-flag bookkeeping stay in
// Dart (DESIGN.md §4) — this extension only knows how to authenticate as a
// device and move a payload of already-selected records over HTTP.
//
// The host seeds this extension's KV namespace at boot (see
// ExtensionService.setSyncCredentials): `key` (stable per-install device
// id), `call` (operator callsign), and — in builds that define
// HAM2K_LOFI_SECRET — `secret`, the app-attestation value app-polo gets
// from its build config; without it registration sends the same
// 'no-secret' fallback app-polo dev builds use. `token` is deliberately
// NOT seeded: `host.kv` is in-memory per process, so the token written
// below only survives within one run and each launch re-registers,
// matching app-polo's memory-only `GLOBAL.syncLoFiToken`.

import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type {
  CommandCatalogEntry,
  CommandInterpretation,
  HookContext,
  JSONValue,
  SyncPayload,
  SyncResponse,
} from "@ham2k/halo-extension-sdk"

import { tFor } from "./i18n.ts"
import { attachReportContext, buildReportPayload } from "./report.ts"
import type { ReportContext, ReportPayload } from "./report.ts"

import manifest from "../manifest.json" with { type: "json" }

export const DEFAULT_LOFI_SERVER = 'https://lofi.ham2k.net'
const DEFAULT_SECRET = 'no-secret'
// The host stamps HaLo's canonical User-Agent on every host.fetch call (see
// docs/design/network.md), so this extension doesn't set its own.

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('syncTransport', {
      hook: {
        sync,
        getAccountData,
        linkClient,
        linkClientWithEmail,
        ensureClientRegistered,
        fetchWebhookEvents,
        submitReport,
      },
    })
    registerHook('command', { key: 'ham2k-lofi-syncall', hook: { interpret: syncAllCommand, catalog: syncAllCatalog } })
    registerHook('command', { key: 'ham2k-lofi-report', hook: { interpret: reportCommand, catalog: reportCatalog } })
  },
})

// Debug/utility command: wipes local operations/QSOs (backed up first, on
// the Dart side — see SyncEngine.forceFullResync) and re-runs a full
// backfill from the server. Typed into the call field, same as
// radio-commands' band/frequency/mode shortcuts.
async function syncAllCommand({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
  if (input.trim().toUpperCase() !== 'SYNCALL') return null
  const t = tFor(ctx)
  return {
    describe: t('syncAllDescribe'),
    confirm: t('syncAllConfirm'),
    commands: [{ syncAll: {} }],
  }
}

async function syncAllCatalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
  const t = tFor(ctx)
  return [{
    command: 'SYNCALL',
    describe: t('catalogSyncAll'),
    category: t('catalogCategory'),
  }]
}

/// `[^]` rather than `.`, which excludes newlines: a description pasted from
/// an error message can carry a CR (Windows clipboard) or a line separator,
/// and the field's whitespace filter is off while a command takes free text.
/// Without this the whole paste stops matching and the Home bar clears it.
const REPORT_PATTERN = /^REPORT(?:\s+([^]*))?$/i

/// Files a bug report as a real CaBo card — works anywhere, no operation
/// needed. Only hits the network on the `execute: true` call (see
/// CommandHook.interpret's doc); a describe-preview call is free, the same
/// discipline SEED uses for its expensive work.
async function reportCommand(
  { input, operation, execute }: { input: string; operation?: Record<string, JSONValue>; execute?: boolean },
  ctx: HookContext,
): Promise<CommandInterpretation | null> {
  const match = REPORT_PATTERN.exec(input.trim())
  if (!match) return null

  const t = tFor(ctx)
  const text = match[1]?.trim()
  if (!text) return { expectsParams: true, mixedCase: true }

  // The describe states what a report may carry and does NOT quote the typed
  // text back: the dialog renders `describe` as one ellipsized line of
  // markdown (hooks.md), so interpolating the description both truncates this
  // warning away and reformats the user's own prose. The row's title already
  // shows what was typed, verbatim.
  if (!execute) return { mixedCase: true, describe: t('reportDescribe') }

  const filed = await fileReport(
    (context) => buildReportPayload(text, context),
    { operation, needsSyncMessage: t('reportNeedsSync') },
  )
  if (filed.error != null) return { mixedCase: true, error: filed.error }
  const ref = filed.ref
  return { mixedCase: true, confirm: ref ? t('reportConfirmWithRef', { ref }) : t('reportConfirm') }
}

/// The one path to `POST v1/reports`: the sync gate, the context block, and
/// the request. Both surfaces that can file a report go through it, so the
/// refusal and the footer can't drift apart between them.
///
/// [compose] rather than a ready payload, because the context a payload needs
/// is exactly what this function fetches. Never throws — every caller here
/// wants the failure as operator-facing text, and the command surface in
/// particular must not throw (see [reportCommand]'s catch).
async function fileReport(
  compose: (context: ReportContext) => ReportPayload,
  { operation, needsSyncMessage }: { operation?: Record<string, JSONValue>; needsSyncMessage: string },
): Promise<{ ref?: string | null; error?: string }> {
  try {
    // Only the version is required; the callsign merely decorates the card. A
    // bare Promise.all would let its failure destroy a report the operator has
    // already written — at the exact moment things are already going wrong,
    // which is when a report gets filed.
    const [version, settings] = await Promise.all([
      host.getVersionInfo(),
      host.getSettings().catch(() => null),
    ])
    // Checked before request(), which registers this device with the server as
    // a side effect when no token is cached — persisting credentials for an
    // operator who never asked for sync, and then failing anyway, because a
    // client with no account behind it gets a 404 from v1/reports. Refusing on
    // an unreadable settings map is the fail-safe direction: the cost is a
    // report the operator can retry, against a write they never asked for.
    //
    // `syncEnabled` is the same gate the SYNCALL action uses host-side
    // (main.dart's handleCommandAction). It says sync is configured, not that a
    // link succeeded, so a linked-then-revoked account still reaches the 404 —
    // that error is at least about the account rather than a silent side effect.
    if (settings?.syncEnabled !== true) return { error: needsSyncMessage }
    const operatorCall = (typeof settings.operatorCall === 'string' && settings.operatorCall) || null
    const payload = compose({ version, operatorCall, operation })
    const response = await request('POST', 'v1/reports', payload)
    const card = response.card as { ref?: JSONValue } | undefined
    return { ref: typeof card?.ref === 'string' ? card.ref : null }
  } catch (e) {
    // Always an `error` result, never a throw. A command hook that throws is
    // wrapped by the kernel as a not-ok entry, and the host's interpret
    // fan-out keeps only the ok ones — so throwing here would leave the
    // operator staring at an unchanged field with no message at all, which is
    // the worst outcome for the one command whose job is reporting failure.
    return { error: e instanceof Error ? e.message : String(e) }
  }
}

/// Files a report the host composed itself — the equipment editor's radio
/// report, whose title, body and kind are built from what the operator typed
/// and from what only Dart knows about the radio.
///
/// The host owns the wording of the card; this owns the account, the context
/// block and the POST — including the sync refusal, which stays here so both
/// surfaces refuse for the same reason in the same words. Errors come back as
/// `{error}` rather than as a throw, for the same reason [reportCommand]'s do:
/// the caller shows this to an operator who has just written something they
/// want sent.
async function submitReport(
  { title, body, kind }: { title: string; body: string; kind: ReportPayload['kind'] },
  ctx: HookContext,
): Promise<{ ref?: string | null; error?: string }> {
  const t = tFor(ctx)
  // Checked at runtime because the type is erased crossing the bridge — these
  // args arrive from JSON.parse. The server silently downgrades an unknown
  // kind to `bug`, so a typo or a renamed enum on the Dart side would file
  // every report, forever, as a bug that nobody could tell from a real one.
  if (!VALID_REPORT_KINDS.includes(kind)) return { error: `unsupported report kind: ${kind}` }
  return fileReport((context) => attachReportContext({ title, body, kind }, context), {
    needsSyncMessage: t('reportNeedsSync'),
  })
}

const VALID_REPORT_KINDS: ReportPayload['kind'][] = ['idea', 'task', 'bug']

async function reportCatalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
  const t = tFor(ctx)
  return [{
    command: 'REPORT',
    params: t('catalogReportParams'),
    describe: t('catalogReport'),
    category: t('catalogCategory'),
    expectsParams: true,
  }]
}

// Cached in module state for the life of the runtime; persisted back to
// `host.kv` so a restart doesn't force re-registering as a "new" device.
let cachedToken: string | null = null

// `sync`, `ensureClientRegistered`, and a user-triggered OAuth login
// can all reach `registerClient()` within the same tick on a
// fresh device — sharing one in-flight attempt (rather than each firing its
// own POST /v1/client) is what keeps their `host.kvSet` writes below from
// interleaving into a mismatched token/push_channel/webhook_token trio.
let registrationInFlight: Promise<string> | null = null

async function serverUrl(): Promise<string> {
  const configured = await host.kvGet('server')
  return typeof configured === 'string' && configured ? configured : DEFAULT_LOFI_SERVER
}

async function registerClient(): Promise<string> {
  if (registrationInFlight) return registrationInFlight
  registrationInFlight = doRegisterClient()
  try {
    return await registrationInFlight
  } finally {
    registrationInFlight = null
  }
}

async function doRegisterClient(): Promise<string> {
  const [key, secret, call] = await Promise.all([host.kvGet('key'), host.kvGet('secret'), host.kvGet('call')])
  const server = await serverUrl()

  const response = await host.fetch(`${server}/v1/client`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client: { key, name: 'HaLo Next', secret: secret || DEFAULT_SECRET },
      account: { call: call || undefined },
    }),
  })

  const json = parseJson(response.body)
  if (response.status !== 200 || typeof json.token !== 'string') {
    // A LoFiRequestError, not a plain Error: the server can reject a
    // brand-new registration (e.g. a stored callsign that no longer matches
    // its expected format) same as it can reject any other authenticated
    // request, and callers already know how to treat that class of failure
    // as recoverable rather than a hard failure — see `sync`.
    throw new LoFiRequestError(
      `LoFi registration failed: ${(json.error as string) ?? `HTTP ${response.status}`}`,
      response.status,
    )
  }
  cachedToken = json.token
  await host.kvSet('token', cachedToken)

  // `client` carries push_channel/webhook_client_token alongside uuid/name
  // (Client#as_json on the server) — cached the same way as the token so a
  // caller that only wants the channel/webhook identity (ensureClientRegistered,
  // used regardless of whether QSO sync is enabled — HALO-66) doesn't force a
  // second round trip.
  const client = json.client
  if (client && typeof client === 'object') {
    const pushChannelName = (client as Record<string, JSONValue>).push_channel
    const webhookClientToken = (client as Record<string, JSONValue>).webhook_client_token
    if (typeof pushChannelName === 'string') await host.kvSet('push_channel_name', pushChannelName)
    if (typeof webhookClientToken === 'string') await host.kvSet('webhook_client_token', webhookClientToken)
  }

  return cachedToken
}

/// A non-2xx server reply, kept distinct from plain Errors so linkClient
/// can turn "the server said no" (with its status) into flow data while
/// genuine transport failures keep propagating.
class LoFiRequestError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

/// Authenticated request with the same retry-once-on-401 shape as the RN
/// extension: an expired/invalid token drops just the token (key/secret
/// still identify this device), never the caller's request.
async function request(method: 'GET' | 'POST', path: string, body?: JSONValue): Promise<Record<string, JSONValue>> {
  const server = await serverUrl()
  if (cachedToken == null) {
    const stored = await host.kvGet('token')
    if (typeof stored === 'string') cachedToken = stored
  }

  let retries = 2
  while (retries > 0) {
    retries--
    if (cachedToken == null) await registerClient()

    const response = await host.fetch(`${server}/${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${cachedToken}`,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    })

    if (response.status === 401) {
      cachedToken = null
      await host.kvSet('token', null)
      continue
    }
    const json = parseJson(response.body)
    if (response.status < 200 || response.status >= 300) {
      throw new LoFiRequestError(`LoFi request failed: ${(json.error as string) ?? `HTTP ${response.status}`}`, response.status)
    }
    return json
  }
  throw new Error('LoFi authentication failed')
}

function parseJson(body: string): Record<string, JSONValue> {
  try {
    return JSON.parse(body) as Record<string, JSONValue>
  } catch {
    return {}
  }
}

// A 422 here is a rejected registration, not a bug: the server refusing a
// brand-new client's account details (e.g. a stored callsign that no longer
// matches its expected format) is part of the periodic sync flow, and
// SyncEngine treats an `error`-shaped response as recoverable — same
// convention `linkClient` already uses below. Any other status (500, 429, a
// real outage, ...) is a genuine failure and must keep propagating so it
// still reaches onError/crash reporting.
async function sync(payload: SyncPayload, _ctx: HookContext): Promise<SyncResponse> {
  try {
    return (await request('POST', 'v1/sync', payload as unknown as JSONValue)) as SyncResponse
  } catch (e) {
    if (e instanceof LoFiRequestError && e.status === 422) return { error: e.message, error_status: e.status }
    throw e
  }
}

async function getAccountData(_args: Record<string, never>, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  return request('GET', 'v1/accounts')
}

/// Requests a link permission from the server (app-polo's `linkClient` /
/// `prepareBlankPermission`). With an email, a pending permission on that
/// account — the response's `permission.challenge_token` is the code the
/// user confirms from a device already linked to it (or `status: 'active'`
/// right away when this client already holds a permission there, which is
/// how quick account switching works). With no email, a blank "orphaned"
/// permission whose client uuid + challenge_token get encoded into a QR
/// code for an already-linked device to scan and approve. Server rejections
/// are part of the UI flow here (404 = "no account with that email"), so
/// they come back as `{ error, error_status }` data instead of a thrown
/// error — only genuine transport failures still throw.
async function linkClient({ email }: { email?: string }, _ctx: HookContext): Promise<Record<string, JSONValue>> {
  try {
    return await request('POST', 'v1/client/permissions', email ? { email } : {})
  } catch (e) {
    if (e instanceof LoFiRequestError) return { error: e.message, error_status: e.status }
    throw e
  }
}

async function linkClientWithEmail(
  { email }: { email: string },
  _ctx: HookContext,
): Promise<Record<string, JSONValue>> {
  return request('POST', 'v1/client/permissions', { email, send_email: true })
}

/// Registers this device with the sync server if it hasn't been already —
/// independent of whether QSO sync is enabled (unlike `sync`/`getAccountData`,
/// this never touches log data, so the host calls it regardless of
/// `settings.syncEnabled`; see HALO-66). Returns the Pusher channel to
/// subscribe to and the signed token used to build the `state` param for a
/// webhook-relayed OAuth flow (HALO-65).
async function ensureClientRegistered(
  _args: Record<string, never>,
  _ctx: HookContext,
): Promise<{ push_channel_name: string; webhook_client_token: string }> {
  const read = () => Promise.all([host.kvGet('push_channel_name'), host.kvGet('webhook_client_token')])
  let [pushChannelName, webhookClientToken] = await read()
  if (typeof pushChannelName !== 'string' || typeof webhookClientToken !== 'string') {
    await registerClient()
    ;[pushChannelName, webhookClientToken] = await read()
  }
  if (typeof pushChannelName !== 'string' || typeof webhookClientToken !== 'string') {
    throw new Error('LoFi registration did not return a push channel/webhook token')
  }
  return { push_channel_name: pushChannelName, webhook_client_token: webhookClientToken }
}

/// Fetches this device's pending webhook events (HALO-65) — the poll
/// fallback, and how the app retrieves the actual payload after a Pusher
/// `webhook_event` ping, which intentionally carries only an id.
async function fetchWebhookEvents(
  _args: Record<string, never>,
  _ctx: HookContext,
): Promise<{ webhook_events: Record<string, JSONValue>[] }> {
  const response = await request('GET', 'v1/client/webhooks')
  const events = response.webhook_events
  return { webhook_events: Array.isArray(events) ? (events as Record<string, JSONValue>[]) : [] }
}
