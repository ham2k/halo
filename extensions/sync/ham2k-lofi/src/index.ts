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
import type { CommandInterpretation, HookContext, JSONValue, SyncPayload, SyncResponse } from "@ham2k/halo-extension-sdk"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

export const DEFAULT_LOFI_SERVER = 'https://lofi.ham2k.net'
const DEFAULT_SECRET = 'no-secret'
// The host stamps HaLo's canonical User-Agent on every host.fetch call (see
// docs/design/network.md), so this extension no longer sets its own.

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('syncTransport', { hook: { sync, getAccountData, linkClient, linkClientWithEmail } })
    registerHook('command', { key: 'ham2k-lofi-syncall', hook: { interpret: syncAllCommand } })
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

// Cached in module state for the life of the runtime; persisted back to
// `host.kv` so a restart doesn't force re-registering as a "new" device.
let cachedToken: string | null = null

async function serverUrl(): Promise<string> {
  const configured = await host.kvGet('server')
  return typeof configured === 'string' && configured ? configured : DEFAULT_LOFI_SERVER
}

async function registerClient(): Promise<string> {
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
    throw new Error(`LoFi registration failed: ${(json.error as string) ?? `HTTP ${response.status}`}`)
  }
  cachedToken = json.token
  await host.kvSet('token', cachedToken)
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

async function sync(payload: SyncPayload, _ctx: HookContext): Promise<SyncResponse> {
  return (await request('POST', 'v1/sync', payload as unknown as JSONValue)) as SyncResponse
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
