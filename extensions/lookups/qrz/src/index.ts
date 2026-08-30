// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QRZ.com XML API lookups. Exercises the parts of the bridge the Ham2K Lookup
// Service extension doesn't: credentials from host storage, session state
// kept across calls, and re-login on session expiry.

import { cleanLocationParams } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/extension-sdk"
import type { AnnotatedCallInfo, CallInfoLookup, HookContext, JSONValue, LookupResult } from "@ham2k/extension-sdk"

// User-visible strings live in i18n.ts / i18n/<locale>.json. The account
// definition members follow the locale by being functions of ctx — see the
// kernel's account getDefinition path.
import { tFor } from "./i18n.ts"
import {
  forgetNoPhoto,
  hasNoPhoto,
  historySaysNoPhoto,
  rememberNoPhoto,
  type PhotoMemory,
} from "./photoMemory.ts"

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

/// Calls QRZ has already answered about without a picture, this session. In
/// front of [historySaysNoPhoto]'s read of the log, which is where the answer
/// actually persists — module state, so it starts empty on every host restart
/// and the log re-supplies it.
let photoMemory: PhotoMemory = {}

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.online) return []

  // Skip the network round-trip when the running guess already carries
  // everything QRZ could still contribute. On a portable QSO (a POTA/SOTA ref
  // or /P call owns the location) the merge scope-locks QRZ's grid out, so a
  // name is all it could add there; otherwise it takes both a name and a grid.
  //
  // The photo is the third thing, and the one no other source carries: nothing
  // else emits `image`, and each run seeds from the bare callsign, so the
  // guess in hand can never answer for it however complete it looks. What
  // answers instead is QRZ's own past answer about this call — held for the
  // session, and read back off the log beyond it. Without that, the only
  // correct behaviour is to ask every time, since a name and a grid say
  // nothing about whether this station has a picture.
  const isPortable = callInfo.locationScope === 'portable'
  if (has(callInfo.name) && (isPortable || has(callInfo.grid))) {
    const now = Date.now()
    if (hasNoPhoto(photoMemory, call, now)) return []
    // The log's own answer, and a DB read rather than a network one. Only
    // reached when the guess is otherwise complete, which is the same state
    // that means a past QSO answered for it — so this is not an extra read on
    // the calls that have never been worked.
    const history = ctx.getHistoryForCall ? await ctx.getHistoryForCall(call) : null
    if (history && historySaysNoPhoto(history, now)) {
      photoMemory = rememberNoPhoto(photoMemory, call, now)
      return []
    }
  }

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
    // Bad credentials, a session the retry above could not renew, a
    // subscription QRZ wants for this record: the outcomes where an empty
    // call-info panel means something IS wrong, and the only ones worth a line.
    if (error) {
      host.log(`QRZ lookup for ${call} answered with an error: ${error}`)
      return []
    }

    const fname = tag(xml, 'fname')
    // QRZ profiles routinely repeat the first name as the nickname; "Robert
    // “Robert” Smith" is noise, not information.
    const nick = tag(xml, 'nickname')
    const nickname = nick && nick.toLowerCase() !== (fname ?? '').toLowerCase() ? nick : undefined
    const city = tag(xml, 'addr2')
    const state = tag(xml, 'state')
    const [lat, lon] = cleanLocationParams(tag(xml, 'lat'), tag(xml, 'lon'))
    // `image` rides along as an extra field CallInfoLookup's fixed shape
    // doesn't declare (same widening pattern as annotate.ts's `flag`) — QRZ's
    // profile/QSL-card photo URL, shown in the call-info detail panel.
    const result: CallInfoLookup & { image?: string; online?: boolean } = {
      call: tag(xml, 'call') ?? call,
      source: 'qrz.com',
      scope: 'general',
      // Reaching here means the fetch above succeeded — every non-empty
      // result from this hook required the network (the `!ctx.online` guard
      // above is the only other exit). The background lookup queue reads
      // this generically, without knowing 'qrz.com' by name.
      online: true,
      locationScope,
      // First “Nickname” Last — the nickname is what the operator actually
      // goes by on the air, and QRZ is the only source that reports one.
      name: [fname, nickname && `“${nickname}”`, tag(xml, 'name')].filter((x) => x).join(' '),
      location: [city, state].filter((x) => x).join(', '),
      city,
      state,
      country: tag(xml, 'country'),
      grid: tag(xml, 'grid'),
      lat,
      lon,
      image: tag(xml, 'image'),
    }
    // Only the negative half is remembered, and only on an answer we actually
    // got: an error above returned already, so reaching here means QRZ spoke.
    // A call that HAS a picture is deliberately not cached — re-asking is what
    // keeps a changed profile picture from being frozen, and the URL is on the
    // QSO for Call History to carry forward meanwhile.
    photoMemory = result.image
      ? forgetNoPhoto(photoMemory, call)
      : rememberNoPhoto(photoMemory, call, Date.now())
    return [result]
  } catch (e) {
    host.log(`QRZ lookup failed for ${call}: ${(e as Error).message ?? e}`)
    return []
  }
}
