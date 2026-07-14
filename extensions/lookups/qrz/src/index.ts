// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QRZ.com XML API lookups. Exercises the parts of the bridge the HamDB
// extension doesn't: credentials from host storage, session state kept across
// calls, and re-login on session expiry.

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/halo-extension-sdk"

const AGENT = 'polo-next-spike'
const API = 'https://xmldata.qrz.com/xml/current/'

defineExtension({
  key: 'qrz',
  name: 'QRZ.com Callsign Lookups',
  version: '0.0.1',
  description: 'Requires a QRZ.com account (paid for full data)',
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: { lookupCall }, priority: 99 })
    registerHook('account', {
      hook: {
        label: 'QRZ.com Callsign Lookups',
        kvKey: 'qrz',
        fields: [
          {
            key: 'username',
            label: 'Login (your callsign)',
            type: 'text',
            postface: "Don't use your email for login."
          },
          {
            key: 'password',
            label: 'Password',
            type: 'secret'
          }
        ],
        async testCredentials(credentials: Record<string, string>): Promise<string> {
          const username = (credentials.username || '').trim().toUpperCase()
          const password = credentials.password
          if (!username || !password) {
            return 'Please provide both username and password.'
          }
          if (username.indexOf('@') >= 0) {
            return "Don't use your email for login."
          }
          try {
            const key = await testLogin(username, password)
            const lookupUrl = `${API}?s=${key};callsign=${encodeURIComponent(username)}`
            const lookupResponse = await host.fetch(lookupUrl)
            const error = tag(lookupResponse.body, 'Error')
            if (error) {
              return `✅ Credentials are correct, but callsign lookup failed: **${error}**`
            }
            const name = [tag(lookupResponse.body, 'fname'), tag(lookupResponse.body, 'name')].filter((x) => x).join(' ')
            const call = tag(lookupResponse.body, 'call') || username
            return `✅ ${call}: ${name}`
          } catch (e) {
            return `Authentication failed: **${(e as Error).message}**`
          }
        }
      }
    })
  },
})

// The QRZ XML payload is flat and unentitled; a tag extractor is all we need.
function tag(xml: string, name: string): string | undefined {
  const match = xml.match(new RegExp(`<${name}[^>]*>([^<]*)</${name}>`, 'i'))
  return match?.[1]?.trim() || undefined
}

async function testLogin(username: string, password: string): Promise<string> {
  const url = `${API}?username=${encodeURIComponent(username)};password=${encodeURIComponent(password)};agent=${AGENT}`
  const response = await host.fetch(url)
  const key = tag(response.body, 'Key')
  if (!key) throw new Error(tag(response.body, 'Error') ?? `HTTP ${response.status}`)
  return key
}

async function login(ctx: HookContext): Promise<string> {
  const username = ctx.account?.credentials?.username
  const password = ctx.account?.credentials?.password
  if (!username || !password) throw new Error('QRZ credentials not configured')

  const key = await testLogin(username, password)
  await host.setAccountSession({ sessionKey: key })
  return key
}

async function fetchCall(call: string, ctx: HookContext): Promise<string> {
  const key = ctx.account?.session?.sessionKey ?? (await login(ctx))
  const response = await host.fetch(`${API}?s=${key};callsign=${encodeURIComponent(call)}`)

  const error = tag(response.body, 'Error')
  if (error && /session|timeout|invalid.*key/i.test(error)) {
    await host.setAccountSession({}) // clear invalid session
    const freshKey = await login(ctx)
    const retry = await host.fetch(`${API}?s=${freshKey};callsign=${encodeURIComponent(call)}`)
    return retry.body
  }
  return response.body
}

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.online) return []

  try {
    let xml = await fetchCall(call, ctx)
    let error = tag(xml, 'Error')
    // The result's own locationScope: the full (possibly-prefixed) call
    // resolved -> inherit whatever locationScope the callInfo already
    // carried (e.g. 'prefixed' for EA3/KI2D). A fallback to baseCall below
    // is explicitly the plain home callsign -> 'qth'.
    let locationScope = callInfo.locationScope ?? 'qth'

    // If not found and the call had modifiers, try the base call
    if (error && /not found/i.test(error) && callInfo.baseCall && callInfo.baseCall !== call) {
      xml = await fetchCall(callInfo.baseCall.toUpperCase(), ctx)
      error = tag(xml, 'Error')
      locationScope = 'qth'
    }
    if (error) return []

    const city = tag(xml, 'addr2')
    const state = tag(xml, 'state')
    const [lat, lon] = cleanLocationParams(tag(xml, 'lat'), tag(xml, 'lon'))
    const result: CallInfoLookup = {
      call: tag(xml, 'call') ?? call,
      source: 'qrz.com',
      scope: 'general',
      locationScope,
      name: [tag(xml, 'fname'), tag(xml, 'name')].filter((x) => x).join(' '),
      location: [city, state].filter((x) => x).join(', '),
      city,
      state,
      country: tag(xml, 'country'),
      grid: tag(xml, 'grid'),
      lat,
      lon,
    }
    return [result]
  } catch (e) {
    host.log(`QRZ lookup failed for ${call}: ${(e as Error).message ?? e}`)
    return []
  }
}
