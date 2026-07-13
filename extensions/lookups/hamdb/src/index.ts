// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/polo-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/polo-sdk"

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

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.online) return [] // no offline data source

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

  const [lat, lon] = cleanLocationParams(record.lat, record.lon)
  const result: CallInfoLookup = {
    call: record.call ?? call,
    source: 'hamdb.org',
    scope: 'general',
    locationScope,
    name: [record.fname, record.name].filter((x: string) => x && x !== 'NOT_FOUND').join(' '),
    location: [record.addr2, record.state].filter((x: string) => x).join(', '),
    city: record.addr2,
    state: record.state,
    country: record.country,
    grid: record.grid,
    lat,
    lon,
  }
  return [result]
}
