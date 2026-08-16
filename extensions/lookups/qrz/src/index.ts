// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QRZ.com XML API lookups. Exercises the parts of the bridge the Ham2K Lookup
// Service extension doesn't: credentials from host storage, session state
// kept across calls, and re-login on session expiry.

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/halo-extension-sdk"

// User-visible strings live in i18n.ts / i18n/<locale>.json. The account
// definition members follow the locale by being functions of ctx — see the
// kernel's account getDefinition path.
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const AGENT = 'polo-next-spike'
const API = 'https://xmldata.qrz.com/xml/current/'

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: { lookupCall }, priority: 99 })
    registerHook('account', {
      hook: {
        label: 'QRZ.com',
        description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('accountDescription'),
        kvKey: 'qrz',
        // A QRZ.com login is the same on every device, so sync it across the
        // user's Apple devices via iCloud Keychain. Contrast the LoFi sync
        // device key, which is per-install and must stay device-local.
        synchronizable: true,
        fields: (_args: Record<string, never>, ctx: HookContext) => {
          const t = tFor(ctx)
          return [
            {
              key: 'username',
              label: t('usernameLabel'),
              type: 'text',
              postface: t('noEmailLogin')
            },
            {
              key: 'password',
              label: t('passwordLabel'),
              type: 'secret'
            }
          ]
        },
        async testCredentials(credentials: Record<string, string>, ctx: HookContext): Promise<string> {
          const t = tFor(ctx)
          const username = (credentials.username || '').trim().toUpperCase()
          const password = credentials.password
          if (!username || !password) {
            return t('missingCredentials')
          }
          if (username.indexOf('@') >= 0) {
            return t('noEmailLogin')
          }
          try {
            const key = await testLogin(username, password)
            const lookupUrl = `${API}?s=${key};callsign=${encodeURIComponent(username)}`
            const lookupResponse = await host.fetch(lookupUrl)
            const error = tag(lookupResponse.body, 'Error')
            if (error) {
              return t('lookupFailed', { error })
            }
            const name = [tag(lookupResponse.body, 'fname'), tag(lookupResponse.body, 'name')].filter((x) => x).join(' ')
            const call = tag(lookupResponse.body, 'call') || username
            return `✅ ${call}: ${name}`
          } catch (e) {
            return t('authFailed', { message: (e as Error).message })
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

/** A non-empty string field (a resolved value, not a blank/absent one). */
const has = (v: unknown): boolean => typeof v === 'string' && v.trim() !== ''

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.online) return []

  // Skip the network round-trip when the running guess already carries the
  // data QRZ could still contribute. On a portable QSO (a POTA/SOTA ref or /P
  // call owns the location) the merge scope-locks QRZ's grid out, so a name is
  // all it could add — skip once we have that. Otherwise it takes both a name
  // and a grid to make the call redundant. Only this source knows which of its
  // fields are worth a network hit.
  const isPortable = callInfo.locationScope === 'portable'
  if (has(callInfo.name) && (isPortable || has(callInfo.grid))) return []

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
    // `image` rides along as an extra field CallInfoLookup's fixed shape
    // doesn't declare (same widening pattern as annotate.ts's `flag`) — QRZ's
    // profile/QSL-card photo URL, shown in the call-info detail panel.
    const result: CallInfoLookup & { image?: string } = {
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
      image: tag(xml, 'image'),
    }
    return [result]
  } catch (e) {
    host.log(`QRZ lookup failed for ${call}: ${(e as Error).message ?? e}`)
    return []
  }
}
