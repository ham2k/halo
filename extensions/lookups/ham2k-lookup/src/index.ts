// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/extension-sdk"

import manifest from "../manifest.json" with { type: "json" }

// The service only covers a handful of national license databases so far;
// this maps its ISO-3166 alpha-2 codes to the full names CallInfo.country
// carries (QRZ/HamDB both report full names).
const COUNTRY_NAMES: Record<string, string> = {
  US: "United States",
  CA: "Canada",
  DE: "Germany",
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // Below QRZ (99): a QRZ account, when configured, is the more complete
    // and up-to-date source, so this fills gaps QRZ leaves rather than
    // pre-empting it.
    registerHook('lookup', { hook: { lookupCall }, priority: 10 })
  },
})

async function fetchCall(call: string): Promise<Record<string, any> | null> {
  // A call containing indicators (e.g. "KI2D/P") 404s — none of that should
  // prevent the baseCall fallback below from still being tried.
  try {
    const response = await host.fetch(`https://services.ham2k.net/lookups/calls/${encodeURIComponent(call)}.json`)
    if (response.status !== 200) return null
    const data = JSON.parse(response.body)
    if (!data || typeof data !== 'object' || data.error) return null
    return data
  } catch (e) {
    host.log(`Ham2K Lookup Service lookup failed for ${call}: ${(e as Error).message ?? e}`)
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

  // The service doesn't report grid/lat/lon today, but may start to — so,
  // unlike HamDB's equivalent check, skipping the round-trip also requires a
  // grid already on the guess, not just a name (+ city/portable scope).
  const isPortable = callInfo.locationScope === 'portable'
  if (has(callInfo.name) && has(callInfo.grid) && (isPortable || has(callInfo.city))) return []

  // The service doesn't understand indicators (e.g. "/P", "/M") — only the
  // plain registered callsign. The full (possibly indicated) call is tried
  // first, inheriting whatever locationScope the callInfo already carries;
  // falling back to baseCall means we're really reporting the operator's
  // home QTH, so that fallback is hardcoded 'qth'.
  let record = await fetchCall(call)
  let locationScope: CallInfoLookup['locationScope'] = callInfo.locationScope ?? 'qth'
  if (!record && callInfo.baseCall && callInfo.baseCall !== call) {
    record = await fetchCall(callInfo.baseCall.toUpperCase())
    locationScope = 'qth'
  }
  if (!record) return []

  const real = (value: unknown): string | undefined => (typeof value === 'string' && value !== '' ? value : undefined)

  const city = real(record.city)
  const state = real(record.state)
  const county = real(record.county)
  const countryCode = real(record.country)
  const [lat, lon] = cleanLocationParams(real(record.lat), real(record.lon))
  const result: CallInfoLookup & { online?: boolean } = {
    call: real(record.call) ?? call,
    source: 'services.ham2k.net',
    scope: 'general',
    // Every non-empty result requires the network (the `!ctx.online` guard
    // above is the only other exit) — read generically by the background
    // lookup queue, without knowing this source by name.
    online: true,
    locationScope,
    name: real(record.name),
    location: [city, state].filter(Boolean).join(', '),
    city,
    state,
    county,
    country: countryCode ? (COUNTRY_NAMES[countryCode] ?? countryCode) : undefined,
    grid: real(record.grid),
    lat,
    lon,
  }
  return [result]
}
