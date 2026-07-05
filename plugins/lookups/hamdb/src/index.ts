// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { definePlugin, host } from "@ham2k/polo-sdk"
import type { CallInfo, HookContext, LookupRecord } from "@ham2k/polo-sdk"

const AGENT = 'polo-next-spike'

definePlugin({
  key: 'hamdb',
  name: 'HamDB Callsign Lookups',
  version: '0.0.1',
  description: 'Free callsign lookups for US, Canada and Germany',
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: { lookupCall }, priority: 50 })
  },
})

async function lookupCall({ callInfo }: { callInfo: CallInfo }, _ctx: HookContext): Promise<LookupRecord> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3) return { source: 'hamdb.org', error: 'callsign too short' }

  const response = await host.fetch(`https://api.hamdb.org/${encodeURIComponent(call)}/json/${AGENT}`)
  if (response.status !== 200) {
    return { source: 'hamdb.org', call, error: `HTTP ${response.status}` }
  }

  const data = JSON.parse(response.body)?.hamdb
  if (data?.messages?.status !== 'OK') {
    return { source: 'hamdb.org', call, error: data?.messages?.status ?? 'unknown error' }
  }

  const record = data.callsign ?? {}
  return {
    source: 'hamdb.org',
    call: record.call,
    name: [record.fname, record.name].filter((x: string) => x && x !== 'NOT_FOUND').join(' '),
    city: record.addr2,
    state: record.state,
    country: record.country,
    grid: record.grid,
    lat: parseFloat(record.lat) || undefined,
    lon: parseFloat(record.lon) || undefined,
  }
}
