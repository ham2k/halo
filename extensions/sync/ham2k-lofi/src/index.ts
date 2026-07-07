// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `syncTransport` for Ham2K's LoFi sync server, ported from app-polo's
// Ham2KLoFiSyncExtension.js. Batching and dirty-flag bookkeeping stay in
// Dart (DESIGN.md §4) — this extension only knows how to authenticate as a
// device and move a payload of already-selected records over HTTP.
//
// Device identity (`key`/`secret`) and the last cached `token`/`server` are
// seeded into this extension's KV namespace by the host at boot (mirrors
// how the QRZ extension gets its credentials) since `host.kv` here is an
// in-memory-per-process store, not itself durable across app restarts.

import { defineExtension, host } from "@ham2k/polo-sdk"
import type { CommandResult, HookContext, JSONValue, SyncPayload, SyncResponse } from "@ham2k/polo-sdk"

export const DEFAULT_LOFI_SERVER = 'https://lofi.ham2k.net'
const DEFAULT_SECRET = 'no-secret'
const USER_AGENT = 'Ham2K HaLo Next/0.1.0'

defineExtension({
  key: 'ham2k-lofi',
  name: 'Ham2K Log Filer Sync',
  version: '0.1.0',
  description: 'Cloud backup and sync for Ham2K apps',
  onActivation({ registerHook }) {
    registerHook('syncTransport', { hook: { sync, getAccountData, linkClientWithEmail } })
    registerHook('command', { key: 'ham2k-lofi-syncall', hook: { tryCommand: syncAllCommand } })
  },
})

// Debug/utility command: wipes local operations/QSOs (backed up first, on
// the Dart side — see SyncEngine.forceFullResync) and re-runs a full
// backfill from the server. Typed into the call field, same as
// radio-commands' band/frequency/mode shortcuts.
async function syncAllCommand({ input }: { input: string }, _ctx: HookContext): Promise<CommandResult | null> {
  if (input.trim().toUpperCase() !== 'SYNCALL') return null
  return { action: 'syncAll' }
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
    headers: { 'User-Agent': USER_AGENT, 'Content-Type': 'application/json' },
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
        'User-Agent': USER_AGENT,
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
      throw new Error(`LoFi request failed: ${(json.error as string) ?? `HTTP ${response.status}`}`)
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

async function linkClientWithEmail(
  { email }: { email: string },
  _ctx: HookContext,
): Promise<Record<string, JSONValue>> {
  return request('POST', 'v1/client/permissions', { email, send_email: true })
}
