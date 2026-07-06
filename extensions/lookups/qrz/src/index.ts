// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QRZ.com XML API lookups. Exercises the parts of the bridge the HamDB
// extension doesn't: credentials from host storage, session state kept across
// calls, and re-login on session expiry.

import { defineExtension, host } from "@ham2k/polo-sdk"
import type { CallInfo, HookContext, LookupRecord } from "@ham2k/polo-sdk"

const AGENT = 'polo-next-spike'
const API = 'https://xmldata.qrz.com/xml/current/'

let sessionKey: string | null = null

defineExtension({
  key: 'qrz',
  name: 'QRZ.com Callsign Lookups',
  version: '0.0.1',
  description: 'Requires a QRZ.com account (paid for full data)',
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: { lookupCall }, priority: 99 })
  },
})

// The QRZ XML payload is flat and unentitled; a tag extractor is all we need.
function tag(xml: string, name: string): string | undefined {
  const match = xml.match(new RegExp(`<${name}[^>]*>([^<]*)</${name}>`, 'i'))
  return match?.[1]?.trim() || undefined
}

async function login(): Promise<string> {
  const username = await host.kvGet('username')
  const password = await host.kvGet('password')
  if (!username || !password) throw new Error('QRZ credentials not configured')

  const url = `${API}?username=${encodeURIComponent(String(username))};password=${encodeURIComponent(String(password))};agent=${AGENT}`
  const response = await host.fetch(url)
  const key = tag(response.body, 'Key')
  if (!key) throw new Error(`QRZ login failed: ${tag(response.body, 'Error') ?? `HTTP ${response.status}`}`)
  sessionKey = key
  return key
}

async function fetchCall(call: string): Promise<string> {
  const key = sessionKey ?? (await login())
  const response = await host.fetch(`${API}?s=${key};callsign=${encodeURIComponent(call)}`)

  const error = tag(response.body, 'Error')
  if (error && /session|timeout|invalid.*key/i.test(error)) {
    sessionKey = null
    const freshKey = await login()
    const retry = await host.fetch(`${API}?s=${freshKey};callsign=${encodeURIComponent(call)}`)
    return retry.body
  }
  return response.body
}

async function lookupCall({ callInfo }: { callInfo: CallInfo }, _ctx: HookContext): Promise<LookupRecord> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3) return { source: 'qrz.com', error: 'callsign too short' }

  try {
    let xml = await fetchCall(call)
    let error = tag(xml, 'Error')

    // If not found and the call had modifiers, try the base call
    if (error && /not found/i.test(error) && callInfo.baseCall && callInfo.baseCall !== call) {
      xml = await fetchCall(callInfo.baseCall.toUpperCase())
      error = tag(xml, 'Error')
    }
    if (error) return { source: 'qrz.com', call, error: `QRZ: ${error}` }

    return {
      source: 'qrz.com',
      call: tag(xml, 'call'),
      name: [tag(xml, 'fname'), tag(xml, 'name')].filter((x) => x).join(' '),
      city: tag(xml, 'addr2'),
      state: tag(xml, 'state'),
      country: tag(xml, 'country'),
      grid: tag(xml, 'grid'),
      lat: parseCoordinate(tag(xml, 'lat')),
      lon: parseCoordinate(tag(xml, 'lon')),
      image: tag(xml, 'image'),
    }
  } catch (e) {
    return { source: 'qrz.com', call, error: String((e as Error).message ?? e) }
  }
}

// `parseFloat(x) || undefined` would discard a legitimate 0° (equator or
// prime meridian) since `0 || undefined` evaluates to undefined.
function parseCoordinate(value: string | undefined): number | undefined {
  const parsed = parseFloat(value ?? '')
  return Number.isFinite(parsed) ? parsed : undefined
}
