// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/halo-extension-sdk"

const AGENT = 'polo-next-spike'

defineExtension({
  key: 'hamdb',
  name: 'HamDB Callsign Lookups',
  version: '0.0.1',
  description: 'Free callsign lookups for US, Canada and Germany',
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: { lookupCall }, priority: 50 })
  },
})

async function fetchCall(call: string): Promise<Record<string, any> | null> {
  // A call containing indicators (e.g. "KI2D/P") may 404, time out, or come
  // back as something that isn't valid JSON — none of that should prevent
  // the baseCall fallback below from still being tried.
  try {
    const response = await host.fetch(`https://api.hamdb.org/${encodeURIComponent(call)}/json/${AGENT}`)
    if (response.status !== 200) return null
    const data = JSON.parse(response.body)?.hamdb
    if (data?.messages?.status !== 'OK') return null
    return data.callsign ?? {}
  } catch (e) {
    host.log(`HamDB lookup failed for ${call}: ${(e as Error).message ?? e}`)
    return null
  }
}

/** A non-empty string field (a resolved value, not a blank/absent one). */
const has = (v: unknown): boolean => typeof v === 'string' && v.trim() !== ''

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.online) return [] // no offline data source

  // Skip the network round-trip when the running guess already carries what
  // HamDB could still contribute. On a portable QSO (a POTA/SOTA ref or /P call
  // owns the location) HamDB's coarse grid AND its city are both scope-locked
  // out, so a name is all it could add — skip once we have that. Otherwise
  // require a name AND a city: HamDB's own grids are unreliable, so a grid
  // alone isn't the signal, but a city (from a higher-priority source, e.g.
  // QRZ) is. Only this source knows which of its fields are worth a hit.
  const isPortable = callInfo.locationScope === 'portable'
  if (has(callInfo.name) && (isPortable || has(callInfo.city))) return []

  // HamDB's API doesn't understand indicators (e.g. "/P", "/M") — it only
  // recognizes the plain registered callsign. The full (possibly indicated
  // or prefixed) call is tried first, inheriting whatever locationScope the
  // callInfo already carries; falling back to baseCall means we're really
  // reporting the operator's home QTH, so that fallback is hardcoded 'qth'.
  let record = await fetchCall(call)
  let locationScope: CallInfoLookup['locationScope'] = callInfo.locationScope ?? 'qth'
  if (!record && callInfo.baseCall && callInfo.baseCall !== call) {
    record = await fetchCall(callInfo.baseCall.toUpperCase())
    locationScope = 'qth'
  }
  if (!record) return []

  // HamDB reports missing fields as the literal string "NOT_FOUND" — on
  // ANY field, not just names (common for Canadian/German records with no
  // grid). Passed through, it reaches the UI and ADIF exports, and a
  // "NOT_FOUND" grid used to crash the merge pipeline and silently discard
  // this whole result, valid name and city included.
  const real = (value: unknown): string | undefined =>
    typeof value === 'string' && value !== '' && value !== 'NOT_FOUND' ? value : undefined

  const city = real(record.addr2)
  const state = real(record.state)
  const [lat, lon] = cleanLocationParams(real(record.lat), real(record.lon))
  const result: CallInfoLookup = {
    call: real(record.call) ?? call,
    source: 'hamdb.org',
    scope: 'general',
    locationScope,
    name: [real(record.fname), real(record.name)].filter(Boolean).join(' '),
    location: [city, state].filter(Boolean).join(', '),
    city,
    state,
    country: real(record.country),
    grid: real(record.grid),
    lat,
    lon,
  }
  return [result]
}
