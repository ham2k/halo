// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA (Summits on the Air) Extension. Registers:
//   ref:sota / ref:sotaActivation  — validation + summit decoration via api-db2.sota.org.uk API
//   activity                       — SOTA hunting + activation controls
//   adifFields                     — SOTA_REF/MY_SOTA_REF contributions for exports
//   adifImport                     — the same fields, plus SIG_INFO, read back
//   spots                          — SOTAWatch spots source + authenticated spot posting
//   account                        — SOTA SSO (OAuth2) login for SOTAwatch spotting
//   dataFile                       — CSV database download and offline caching

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import { locationToGrid6, distanceOnEarth } from "@ham2k/lib-geo-tools"
import { activityAdifImport, activityExportHook, activityScorer, contestScorer, defineExtension, host, LOCATION_ACCURACY } from "@ham2k/halo-extension-sdk"
import type {
  AnnotatedCallInfo,
  FetchOptions,
  FetchResponse,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  LookupResult,
  PostResult,
  PostSelfSpotRequest,
  PostOtherSpotRequest,
  ResultMessage,
  Ref,
  Spot,
  SpotEligibility,
  DataFileDefinition,
  SuggestArgs,
  ActivitySuggestion,
  LookupRow,
  TitleSuggestion,
} from "@ham2k/halo-extension-sdk"
import { REFERENCE_REGEX, TRANSFORMS } from "./refFormatting.ts"
import { suggestOperationTitleForSota } from "./titleSuggestion.ts"
import { tFor } from "./i18n.ts"
import { spotModeFor } from "./spotMode.ts"
import { spotsFromSOTAApi, type SOTAApiSpot } from "./spotMapping.ts"

import manifest from "../manifest.json" with { type: "json" }

export { REFERENCE_REGEX, TRANSFORMS } from "./refFormatting.ts"

const HUNTING_TYPE = 'sota'
const ACTIVATION_TYPE = 'sotaActivation'

/// api-db2 is SOTA's current database API; the api2 host it replaced is on
/// its way out. Spot payloads differ between the two — see `SOTAApiSpot`.
const SOTA_API = 'https://api-db2.sota.org.uk/api'
const SOTA_SUMMITS_API = `${SOTA_API}/summits`

// See POTA's identical note on why this loads at module scope: resolves
// both a summit's association code and a caller's callsign to a DXCC
// entity without a network round trip.
useBuiltinCountryFile()

function entityPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  return annotateFromCountryFile(parseCallsign(call)).entityPrefix
}

// Association codes with no valid-prefix reading, even after the
// trailing-letter fallback below — hand-verified against the real
// summitslist.csv (every SOTA association that doesn't resolve otherwise).
const ASSOCIATION_CODE_OVERRIDES: Record<string, string> = {
  // South Georgia & the South Sandwich Islands: DXCC lists this under the
  // compound prefix "VP8/g" (distinct from the Falkland Islands' plain
  // "VP8", which is what "VP0" would otherwise collide with if simplified).
  VP0: 'VP8/g',
  // UK South Atlantic: SOTA's one "ZD" association actually spans three
  // distinct DXCC entities — Ascension (ZD8), Saint Helena (ZD7), Tristan
  // da Cunha & Gough (ZD9) — that a 2-letter code can't disambiguate.
  // Stored as the literal "ZD" family marker rather than guessing one;
  // `suggest`'s subCategory comparison below treats any caller entity
  // starting with "ZD" as a match for it.
  ZD: 'ZD',
}

// Only ~150-500 distinct association codes exist worldwide, but
// csvToLookupEntry calls this once per summit (~181,000 rows in the real
// summitslist.csv, and again on every RELOAD SOTA/RELOAD ALL) — the same
// code recurs across thousands of summits (e.g. "W6" for all of
// California), so caching by code avoids redoing the parseCallsign/
// annotateFromCountryFile resolution for every row.
const associationEntityCache = new Map<string, string | undefined>()

// A SOTA association code (e.g. "W6", "HB9", "VE1") is a bare prefix, not a
// full callsign — `parseCallsign` only extracts prefix info from something
// call-shaped, so a lone prefix parses as empty/unmatched. Appending a
// throwaway suffix gives it a real callsign's shape without changing which
// prefix it resolves to.
function entityPrefixForAssociationCode(code: string | undefined): string | undefined {
  if (!code) return undefined
  if (associationEntityCache.has(code)) return associationEntityCache.get(code)

  const resolved = resolveEntityPrefixForAssociationCode(code)
  associationEntityCache.set(code, resolved)
  return resolved
}

function resolveEntityPrefixForAssociationCode(code: string): string | undefined {
  if (ASSOCIATION_CODE_OVERRIDES[code]) return ASSOCIATION_CODE_OVERRIDES[code]

  const direct = entityPrefixForCall(`${code}1AA`)
  if (direct) return direct

  // Many SOTA sub-associations tack one region-distinguishing letter onto a
  // real ham prefix (Alaska's KLA/KLF/KLS on top of KL, Argentina's LUx on
  // top of LU, Indonesia's YBx on top of YB, …) — not itself a valid
  // prefix, but stripping it usually recovers one.
  return entityPrefixForCall(`${code.slice(0, -1)}1AA`)
}

// "ZD" is a family marker for three DXCC entities at once (see
// ASSOCIATION_CODE_OVERRIDES) — matching it against a caller's own entity
// needs a prefix check, not equality, unlike every other subCategory value.
function subCategoryMatchesCaller(rowSubCategory: string | undefined, callerEntity: string): boolean {
  if (rowSubCategory === callerEntity) return true
  return rowSubCategory === 'ZD' && callerEntity.startsWith('ZD')
}

// See POTA's identical note: bounding-box nearby query, real distance after.
const NEARBY_DELTA = 1.5
const MAX_SUGGESTIONS = 30

function relevanceForMatch(row: LookupRow, searchTerm?: string): number {
  if (!searchTerm) return row.flags ? 1 : 0.6
  const term = searchTerm.toUpperCase()
  const key = row.key.toUpperCase()
  const name = (row.name ?? '').toUpperCase()
  if (key === term) return 1
  if (name.startsWith(term)) return 0.9
  if (key.includes(term)) return 0.85
  if (name.includes(term)) return 0.7
  return 0.6
}

interface SOTASummitInfo {
  summitCode: string
  name: string
  associationName: string
  regionName: string
  locator: string
  points: number
  altM: number
  valid: boolean
}

const summitCache = new Map<string, SOTASummitInfo | null>()

function isValidDateAsOfToday(str: string): boolean {
  if (!str) return false
  if (str === '31/12/2099') return true

  const parts = str.split('/').map(Number)
  if (parts.length !== 3) return false
  const [day, month, year] = parts
  const date = new Date(year, month - 1, day)
  const today = new Date()
  return (today.getTime() - date.getTime()) / (1000 * 60 * 60 * 24) < 14
}

async function fetchSummit(ref: string): Promise<SOTASummitInfo | null> {
  const cached = summitCache.get(ref)
  if (cached !== undefined) return cached

  // 1. Try querying the offline local lookups database first
  try {
    const row = await host.dbLookupSelectOne('sota', ref)
    if (row && row.data) {
      const info: SOTASummitInfo = {
        summitCode: row.key,
        name: row.name ?? '',
        associationName: row.data.association ?? '',
        regionName: row.data.region ?? '',
        locator: row.data.grid ?? '',
        points: row.data.points ?? 0,
        altM: row.data.altitude ?? 0,
        valid: true,
      }
      summitCache.set(ref, info)
      return info
    }
  } catch (e) {
    host.log(`Database lookup error for SOTA summit ${ref}: ${e}`)
  }

  // 2. Fall back to network fetch
  let summit: SOTASummitInfo | null = null
  try {
    // Per segment: a summit reference carries a slash ("W7O/WV-096") that is
    // part of the API's path, and the server 404s on a percent-encoded one.
    const path = ref.split('/').map(encodeURIComponent).join('/')
    const response = await host.fetch(`${SOTA_SUMMITS_API}/${path}`)
    if (response.status === 200 && response.body && response.body !== 'null') {
      summit = JSON.parse(response.body) as SOTASummitInfo
    }
  } catch {
    return null // network trouble: report nothing, don't cache
  }
  summitCache.set(ref, summit)
  return summit
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = (ref.ref ?? '').toUpperCase().trim()
    return { valid: REFERENCE_REGEX.test(normalized), normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const reference = (ref.ref ?? '').toUpperCase().trim()
    if (!REFERENCE_REGEX.test(reference)) return { ...ref, ref: reference, name: t('invalidReference') }

    const summit = await fetchSummit(reference)
    if (!summit?.name) return { ...ref, ref: reference, name: t('unknownSummit') }

    const location = [summit.regionName, summit.associationName].filter((x) => x).join(', ')

    return {
      ...ref,
      ref: reference,
      name: summit.name,
      grid: summit.locator,
      location,
      program: 'SOTA',
      label: `SOTA ${reference}: ${summit.name}`,
      shortLabel: `SOTA ${reference}`,
    }
  },

  async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
    return suggestOperationTitleForSota(ref, ACTIVATION_TYPE)
  },
}

const ActivityHook = {
  async loggingControls(
    _args: { operation: Record<string, unknown>; qso?: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: 'sota/hunter',
        label: 'SOTA',
        icon: 'image-filter-hdr',
        color: manifest.accentColor,
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: HUNTING_TYPE,
          placeholder: 'W6/SD-...',
          pattern: REFERENCE_REGEX.source,
          transforms: TRANSFORMS,
        },
      },
    ]
  },

  async operationControls(
    _args: { operation: Record<string, unknown>; qso?: Record<string, unknown> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: 'sota/activation',
        label: tFor(ctx)('activationControl'),
        icon: 'image-filter-hdr',
        color: manifest.accentColor,
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: ACTIVATION_TYPE,
          placeholder: 'W6/SD-...',
          pattern: REFERENCE_REGEX.source,
          transforms: TRANSFORMS,
        },
      },
    ]
  },

  async suggest({ location, searchTerm, callsign }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
    const rows: LookupRow[] = searchTerm
      ? await host.dbLookupSelectAll('sota', searchTerm)
      : location
        ? await host.dbLookupSelectByLocation('sota', location.lat, location.lon, NEARBY_DELTA)
        : []

    // See POTA's identical note: entity-restrict name/code search results
    // to the caller's own DXCC entity when known, but never nearby ones.
    const callerEntity = searchTerm ? entityPrefixForCall(callsign) : undefined
    const filteredRows = callerEntity ? rows.filter((row) => subCategoryMatchesCaller(row.subCategory, callerEntity)) : rows

    const withDistance = filteredRows.map((row) => ({
      row,
      distance:
        location && row.lat != null && row.lon != null
          ? (distanceOnEarth(location, { lat: row.lat, lon: row.lon }) ?? undefined)
          : undefined,
    }))
    // See POTA's identical note: nearby (no search term) results must be
    // ranked by real distance before truncating to MAX_SUGGESTIONS.
    if (!searchTerm) {
      withDistance.sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity))
    }

    return withDistance.slice(0, MAX_SUGGESTIONS).map(({ row, distance }) => {
      const data = (row.data ?? {}) as Record<string, any>
      const associationRegion = [data.region, data.association].filter((x) => x).join(', ')

      return {
        type: ACTIVATION_TYPE,
        ref: row.key,
        name: row.name,
        grid: data.grid,
        location: associationRegion,
        program: 'SOTA',
        label: `SOTA ${row.key}: ${row.name ?? ''}`,
        shortLabel: `SOTA ${row.key}`,
        distance,
        relevance: relevanceForMatch(row, searchTerm),
      }
    })
  },
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

/// See POTA's `lookupCall` for the rationale: a summit hunted on this qso is a
/// more specific ("portable") location than a home QTH. A summit is small, so
/// its grid is tagged `ACCURATE` — more precise than a POTA park — and the
/// merge keeps the most accurate same-scope result, so a summit wins over a
/// park on the same qso regardless of order.
async function lookupCall(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const refs = refsOfType(qso, HUNTING_TYPE)
  if (refs.length === 0) return []
  if (!ctx.online) return []

  const summit = await fetchSummit(refs[0].ref!.toUpperCase())
  if (!summit?.locator) return []

  const location = [summit.summitCode, summit.regionName, summit.name].filter((x) => x).join(' ')
  return [{ call: callInfo.call, source: 'sota', scope: 'qso', locationScope: 'portable', grid: summit.locator, location, locAccuracy: LOCATION_ACCURACY.ACCURATE }]
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const fields: { name: string; value: string }[] = []
    const huntingRefs = refsOfType(qso, HUNTING_TYPE)
    const activationRefs = refsOfType(operation, ACTIVATION_TYPE)

    if (huntingRefs.length > 0) {
      fields.push({ name: 'SOTA_REF', value: huntingRefs.map((r) => r.ref).join(',') })
    }
    if (activationRefs.length > 0) {
      fields.push({ name: 'MY_SOTA_REF', value: activationRefs.map((r) => r.ref).join(',') })
    }
    return fields
  },
}

/// The inverse of the hook above. SOTA's own exports carry only
/// SOTA_REF/MY_SOTA_REF — no SIG at all — but plenty of other logging software
/// writes the summit as SIG/SIG_INFO, so both spellings are read back.
///
/// `REFERENCE_REGEX` is what keeps another program's SIG_INFO from importing
/// as a summit that doesn't exist: every reference program writes that field.
const AdifImportHook = activityAdifImport({
  sig: 'SOTA',
  huntingType: HUNTING_TYPE,
  activationType: ACTIVATION_TYPE,
  refField: 'sota_ref',
  // Case and whitespace only. A summit that fails REFERENCE_REGEX is imported
  // as written rather than dropped: both paths into this hook have already
  // established the reference is SOTA's — `SOTA_REF` by its field name, and
  // `SIG_INFO` by the SIG check — so a pattern failure means malformed, not
  // somebody else's, and the operator can still fix what they can still see.
  normalize: (ref) => ref.toUpperCase().trim(),
})

// --- SOTA SSO (OAuth2 via Keycloak) -----------------------------------------
//
// The host runs the whole PKCE flow itself (see `_doOAuth` in
// app/lib/views/settings_view.dart) and stores the resulting accessToken/
// refreshToken/idToken as this account's credentials. Refreshed tokens go
// into the account *session* (the one credential store extensions can
// write), so `currentTokens` overlays session over credentials.

const SOTA_SSO_REALM = 'https://sso.sota.org.uk/auth/realms/SOTA'

// SOTA granted HaLo a separate Keycloak client per build edition
// — each edition is its own app identity
// (com.ham2k.logger.dev/.next/.prod), so each needs its own registered
// native redirect URL. HaLo's OAuth webview intercepts that redirect itself
// (see `_doOAuth` above) on every platform capable of it — an unset/
// unrecognized edition falls back to `dev`, the same default
// `packages/halo_build_tools`' Edition uses for an unset HALO_EDITION define.
const SOTA_OAUTH2_BY_EDITION: Record<string, { clientId: string; redirectUrl: string }> = {
  prod: { clientId: 'com.ham2k.logger.prod', redirectUrl: 'com.ham2k.logger.prod.auth://sota' },
  next: { clientId: 'com.ham2k.logger.next', redirectUrl: 'com.ham2k.logger.next.auth://sota' },
  dev: { clientId: 'com.ham2k.logger.dev', redirectUrl: 'com.ham2k.logger.dev.auth://sota' },
}

// Web and Linux can't catch that custom-scheme redirect at all (no
// `flutter_inappwebview` on Linux; a non-http(s) scheme a browser tab
// navigates to just fails) — those two platforms go through LoFi's
// webhook-relay callback instead (HALO-65/66), one fixed URL shared by
// every edition and every client, registered with SOTA as a literal exact
// string, no wildcard: https://lofi.ham2k.net/v1/webhooks/client/oauth. The
// host (`_doOAuth`, settings_view.dart) picks which of `redirectUrl` /
// `webhookRedirectUrl` to actually use per `oauthUsesWebhookRelay()|
// (oauth_relay_login.dart) — the client is told apart via the OAuth `state`
// param in that case, not the URL (state is the only thing every compliant
// provider is required to echo back unmodified, which is what makes it
// portable — see HALO-65's design note for why this isn't a per-client URL).
//
// SOTA-local rather than exported from the `ham2k-lofi` sync extension
// (which owns the matching `DEFAULT_LOFI_SERVER`): extensions have no
// established cross-package import mechanism today, and SOTA is the only
// OAuth2 hook in the repo, so there's nothing yet for a shared export to
// serve. If a second OAuth-based extension shows up, that's the point to
// hoist this — until then, both sides just have to be kept in sync by hand
// if LoFi's webhook endpoint URL ever moves.
const SOTA_OAUTH_WEBHOOK_REDIRECT_URL = 'https://lofi.ham2k.net/v1/webhooks/client/oauth'

/// The registered client for an edition, from the build's secrets when it has
/// them and from the table above otherwise.
///
/// These are PUBLIC identifiers — a Keycloak public client id and the redirect
/// it is registered against — not credentials. They live in the secrets store
/// because that is where per-build configuration lives, so a re-registration
/// no longer needs a code change. The table stays as the fallback so a fresh
/// checkout can still log in to SOTAWatch, which is the whole feature.
async function sotaOAuth2Config(
  edition: string | undefined,
): Promise<{ issuer: string; clientId: string; redirectUrl: string; webhookRedirectUrl: string; scopes: string[] }> {
  const name = (edition ?? 'dev').toUpperCase()
  const fallback = SOTA_OAUTH2_BY_EDITION[edition ?? 'dev'] ?? SOTA_OAUTH2_BY_EDITION.dev
  const [clientId, redirectUrl] = await Promise.all([
    host.secret(`SOTA_OAUTH_CLIENT_ID_${name}`),
    host.secret(`SOTA_OAUTH_REDIRECT_${name}`),
  ])
  return {
    issuer: SOTA_SSO_REALM,
    clientId: clientId || fallback.clientId,
    redirectUrl: redirectUrl || fallback.redirectUrl,
    webhookRedirectUrl: SOTA_OAUTH_WEBHOOK_REDIRECT_URL,
    scopes: ['openid'],
  }
}

const SOTA_SPOTS_API = `${SOTA_API}/spots`

interface SOTATokens {
  accessToken?: string
  refreshToken?: string
  idToken?: string
}

function currentTokens(ctx: HookContext): SOTATokens {
  return { ...(ctx.account?.credentials ?? {}), ...(ctx.account?.session ?? {}) }
}

/// Trades a refresh token for fresh tokens and persists them in the account
/// session. Tries the session's (most recent) refresh token first, then the
/// original login's — a stale session left over from a re-login would
/// otherwise lock the account out until the user disconnects.
///
/// `persistSession: false` keeps everything in memory — for tokens the user
/// hasn't saved yet (the account dialog's Test before Save), where writing
/// a session would effectively connect an account behind their back.
async function refreshTokens(ctx: HookContext, { persistSession = true } = {}): Promise<SOTATokens | null> {
  const session = ctx.account?.session ?? {}
  const credentials = ctx.account?.credentials ?? {}
  const candidates = [...new Set([session.refreshToken, credentials.refreshToken])].filter((x) => x) as string[]

  let definitivelyRejected = false
  for (const refreshToken of candidates) {
    try {
      const response = await host.fetch(`${SOTA_SSO_REALM}/protocol/openid-connect/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: [
          'grant_type=refresh_token',
          `client_id=${encodeURIComponent((await sotaOAuth2Config(ctx.edition)).clientId)}`,
          `refresh_token=${encodeURIComponent(refreshToken)}`,
        ].join('&'),
      })
      if (response.status !== 200) {
        // 4xx is Keycloak rejecting the grant (expired/revoked); anything
        // else could be transient, so it doesn't justify clearing state.
        if (response.status >= 400 && response.status < 500) definitivelyRejected = true
        continue
      }
      const data = JSON.parse(response.body) as Record<string, string>
      const tokens: Record<string, string> = {}
      if (data.access_token) tokens.accessToken = data.access_token
      if (data.refresh_token) tokens.refreshToken = data.refresh_token
      if (data.id_token) tokens.idToken = data.id_token
      if (!tokens.accessToken) continue
      if (persistSession) await host.setAccountSession(tokens)
      return tokens
    } catch (e) {
      host.log(`SOTA token refresh failed: ${e}`)
    }
  }
  // Drop a session whose tokens Keycloak has definitively rejected (same as
  // QRZ clearing an invalid sessionKey) so later calls don't keep retrying
  // dead tokens on every spot attempt.
  if (persistSession && definitivelyRejected && Object.keys(session).length > 0) {
    try {
      await host.setAccountSession({})
    } catch (e) {
      host.log(`SOTA session clear failed: ${e}`)
    }
  }
  return null
}

/// `host.fetch` with the SOTA bearer/id_token headers, retrying once through
/// a token refresh when the API rejects the current access token. Returns
/// null when there's no logged-in account at all.
async function authorizedFetch(
  url: string,
  options: FetchOptions,
  ctx: HookContext,
  { persistSession = true } = {},
): Promise<FetchResponse | null> {
  let tokens = currentTokens(ctx)
  if (!tokens.accessToken) {
    const refreshed = await refreshTokens(ctx, { persistSession })
    if (!refreshed) return null
    tokens = { ...tokens, ...refreshed }
  }

  const doFetch = (t: SOTATokens) =>
    host.fetch(url, {
      ...options,
      headers: {
        ...(options.headers ?? {}),
        Authorization: `bearer ${t.accessToken}`,
        // Required by the spots API; omitted rather than sent empty when a
        // token response didn't include one.
        ...(t.idToken ? { id_token: t.idToken } : {}),
      },
    })

  let response = await doFetch(tokens)
  // Same statuses app-polo treats as an expired token (the API has been
  // seen returning 500 for auth failures).
  if (response.status === 401 || response.status === 403 || response.status === 500) {
    const refreshed = await refreshTokens(ctx, { persistSession })
    if (refreshed) {
      response = await doFetch({ ...tokens, ...refreshed })
    }
  }
  return response
}

const AccountHook = {
  label: 'SOTAWatch',
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('accountDescription'),
  kvKey: 'sota',
  oauth2: (_args: Record<string, never>, ctx: HookContext) => sotaOAuth2Config(ctx.edition),

  async testCredentials(credentials: Record<string, string>, ctx: HookContext): Promise<string> {
    try {
      // The account dialog may be testing tokens that haven't been saved
      // yet — the credentials it passes take precedence over the stored
      // account (and carry no session, so no stale overlay applies). A test
      // of unsaved tokens must also never persist a session: the user
      // hasn't pressed Save.
      const testingUnsaved = credentials && Object.keys(credentials).length > 0
      const testCtx = testingUnsaved ? { ...ctx, account: { credentials } } : ctx
      const response = await authorizedFetch(
        `${SOTA_SSO_REALM}/account`,
        { headers: { Accept: 'application/json' } },
        testCtx,
        { persistSession: !testingUnsaved },
      )
      if (!response) return tFor(ctx)('notLoggedIn')
      if (response.status !== 200) return tFor(ctx)('ssoHttpError', { status: response.status })
      const account = JSON.parse(response.body) as Record<string, any>
      const callsign = account?.attributes?.Callsign?.[0] ?? account?.username
      return `✅ **${callsign ?? 'unknown'}**`
    } catch (e) {
      return tFor(ctx)('accountCheckError', { error: e instanceof Error ? e.message : String(e) })
    }
  },
}

/// Shown when a spot post fails for lack of a working login — the account
/// action button opens the SOTAWatch account dialog directly. Built per
/// call so the dialog follows the active locale.
function reconnectMessage(ctx: HookContext): ResultMessage {
  const t = tFor(ctx)
  return {
    presentation: 'dialog',
    title: t('reconnectTitle'),
    text: t('reconnectText'),
    actions: [{ label: t('reconnectAction'), type: 'account', key: 'sota' }],
  }
}

async function postSpotToSOTA(
  { activatorCallsign, freq, mode, comment, ref, ctx }:
  { activatorCallsign: string; freq: number; mode?: string; comment?: string; ref: Ref; ctx: HookContext },
): Promise<PostResult> {
  if (!activatorCallsign) return { ok: false, message: 'No station callsign to spot' }
  const [associationCode, summitCode] = String(ref.ref).split('/', 2)

  const body = {
    associationCode,
    summitCode,
    activatorCallsign,
    frequency: (freq / 1000).toFixed(6), // kHz -> MHz, as a string
    mode: spotModeFor(mode),
    // Tags spots posted through HaLo.
    comments: comment ? `${comment} [H2K]` : '[H2K]',
    // 'TEST' spots are accepted by the API but hidden from SOTAWatch users —
    // a comment mentioning "test" posts one, so a first try doesn't summon
    // real chasers.
    type: (comment ?? '').match(/QRT/i) ? 'QRT' : (comment ?? '').match(/\bTEST\b/i) ? 'TEST' : 'NORMAL',
  }

  try {
    const response = await authorizedFetch(SOTA_SPOTS_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body),
    }, ctx)
    if (!response) {
      return { ok: false, message: 'Log in to your SOTA account in Settings to post SOTAwatch spots', userMessage: reconnectMessage(ctx) }
    }
    if (response.status === 401 || response.status === 403) {
      return { ok: false, message: 'SOTA account logged out. Please log in again in Settings', userMessage: reconnectMessage(ctx) }
    }
    if (response.status !== 200 && response.status !== 201) {
      return { ok: false, message: `SOTA API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

/// `-1` asks for the last hour rather than a count of spots. An activator
/// spotted longer ago than that has almost certainly moved or packed up, so
/// a wider window costs bandwidth to deliver rows a chaser can't use.
const SOTA_SPOTS_WINDOW = '-1/all/all/'

const SOTA_EPOCH_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/// The epoch request is an optimisation, so it gets an optimisation's
/// patience: long enough that a healthy server always answers, short enough
/// that an unhealthy one is written off well inside the fan-out's budget.
const SOTA_EPOCH_TIMEOUT = 3000

/// The epoch UUID SOTAwatch last reported, and the spots it mapped to. The
/// UUID changes whenever any spot does, so an unchanged one means the cached
/// list is still exactly current and the spots request can be skipped
/// entirely — `SpotsService` polls every two minutes for as long as an
/// operation is open, and most of those ticks find nothing new.
let lastSpotsEpoch: string | undefined
let lastSpots: Spot[] = []

const SpotsHook = {
  sourceName: 'SOTAWatch',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    // The epoch endpoint answers with a bare UUID as text/plain — not JSON,
    // so nothing to parse. Its failure must not fail the fetch it exists to
    // save: without the catch, one refused request here empties the board for
    // the cycle even though the spots endpoint is answering fine.
    //
    // A catch cannot bound a request that STALLS rather than fails, and this
    // one is serialized ahead of the spots fetch, inside a budget every spot
    // source shares. Hence the explicit timeout: skipping the saving costs
    // one extra fetch, while waiting the host's default 15s for a probe would
    // cost every source its spots for the cycle.
    let epoch: string | undefined
    try {
      const epochResponse = await host.fetch(`${SOTA_SPOTS_API}/epoch`, { timeout: SOTA_EPOCH_TIMEOUT })
      const body = epochResponse.status === 200 ? epochResponse.body.trim() : ''
      // Only a UUID counts. A captive portal or proxy answering 200 with a
      // constant page would otherwise pin the epoch to it and short-circuit
      // every later poll — the spots request never runs, so nothing throws
      // and the board silently freezes rather than reporting an error.
      // Failing the check just costs the saving.
      if (SOTA_EPOCH_REGEX.test(body)) epoch = body
    } catch (e) {
      // Logged, because the only symptom is one extra full spots fetch every
      // couple of minutes — invisible. A timeout too tight for a marginal
      // field link would silently disable the saving this cache exists for,
      // for the whole session, with nothing to say so.
      host.log(`SOTA epoch probe failed, fetching spots anyway: ${e}`)
      epoch = undefined
    }
    if (epoch && epoch === lastSpotsEpoch) return lastSpots

    const response = await host.fetch(`${SOTA_SPOTS_API}/${SOTA_SPOTS_WINDOW}`)
    if (response.status !== 200) throw new Error(`SOTA API returned HTTP ${response.status}`)
    const spots = spotsFromSOTAApi(JSON.parse(response.body) as SOTAApiSpot[])

    lastSpotsEpoch = epoch
    lastSpots = spots
    return spots
  },

  async isSelfSpotEnabled({ operation }: { operation: Record<string, JSONValue> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(operation, ACTIVATION_TYPE).length > 0 ? { enabled: true, icon: 'image-filter-hdr' } : { enabled: false }
  },

  async isOtherSpotEnabled({ qso }: { qso: Record<string, JSONValue> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(qso, HUNTING_TYPE).length > 0 ? { enabled: true, icon: 'image-filter-hdr' } : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No SOTA activation on this operation' }
    if (!freq) return { ok: false, message: 'No frequency to spot' }
    return postSpotToSOTA({
      activatorCallsign: String(operation.stationCall ?? ''),
      freq,
      mode,
      comment,
      ref: refs[0],
      ctx,
    })
  },

  async postOtherSpot({ qso, comment }: PostOtherSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No SOTA reference on this QSO' }
    const freq = Number(qso.freq)
    if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }
    const their = (qso.their ?? {}) as Record<string, JSONValue>
    return postSpotToSOTA({
      activatorCallsign: String(their.call ?? ''),
      freq,
      mode: qso.mode ? String(qso.mode) : undefined,
      comment,
      ref: refs[0],
      ctx,
    })
  },
}

const sotaDataFile: DataFileDefinition = {
  key: 'sota-all-summits',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://www.sotadata.org.uk/summitslist.csv',
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'sota',
  csvOptions: {
    hasHeaders: true,
    skipRows: 1,
    delimiter: ',',
  },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    if (!r.SummitCode || !isValidDateAsOfToday(r.ValidTo)) {
      return null
    }
    const lat = parseFloat(r.Latitude) || 0
    const lon = parseFloat(r.Longitude) || 0
    const ref = r.SummitCode.toUpperCase()
    const name = r.SummitName
    const altitude = parseInt(r.AltM, 10) || 0
    const points = parseInt(r.Points, 10) || 0
    // SOTA association codes (the part of the reference before the "/",
    // e.g. "W6" in "W6/SD-026") are themselves valid ham-radio prefixes —
    // resolving one to its DXCC entity the same way POTA's numeric entityId
    // does, so `suggest` can filter on subCategory consistently across
    // activities.
    const dxccPrefix = entityPrefixForAssociationCode(ref.split('/')[0])

    return {
      subCategory: dxccPrefix,
      key: ref,
      name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name,
        grid: locationToGrid6(lat, lon),
        altitude,
        points,
        region: r.RegionName,
        association: r.AssociationName,
        dxccPrefix,
        active: true,
        lat,
        lon,
      },
    }
  },
}

/// SOTA's award rules (docs/design/activities.md §4). Four contacts qualify a
/// summit for points, and a chaser may only claim a given summit once per UTC
/// day — so day and summit are the axes that make a repeat contact fresh, while
/// band and mode are not. There are no n-fers: one summit at a time, and a QSO
/// credits only its first summit ref.
const SOTA_SCORING = {
  label: 'SOTA',
  icon: 'image-filter-hdr',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 4,
  allowsMultipleReferences: false,
  uniquePer: ['day', 'ref'] as const,
  activates: 'daily' as const,
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: RefHandler, key: 'sota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: RefHandler, key: 'sota' })
    registerHook('activity', { hook: ActivityHook, key: 'sota' })
    registerHook('adifFields', { hook: AdifFieldsHook, key: 'sota' })
    registerHook('adifImport', { hook: AdifImportHook, key: 'sota' })
    registerHook('spots', { hook: SpotsHook, key: 'sota' })
    registerHook('account', { hook: AccountHook, key: 'sota' })
    // Priority 100 — see POTA's identical comment: must run before QRZ (99)
    // / HamDB (50) so the summit's grid is resolved before a home-QTH
    // lookup can set callInfo.grid and trip this hook's early-return guard.
    registerHook('lookup', { hook: { lookupCall }, key: 'sota', priority: 100 })
    registerHook('dataFile', { hook: sotaDataFile, key: 'sota-all-summits' })
    // Ref-scoped, not 'always' — see POTA's identical comment for why, and for
    // what a hunting-only operation loses by it.
    registerHook('scoring', {
      hook: contestScorer(activityScorer(SOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'sota',
    })
    // SOTA has no n-fers, so this is always a single option — but it is still
    // the summit-scoped log rather than the whole operation's, which is what a
    // summit sat between two breaks needs.
    registerHook('export', {
      hook: activityExportHook({
        key: 'sota',
        label: 'SOTA',
        activationType: ACTIVATION_TYPE,
        icon: 'image-filter-hdr',
      }),
      key: 'sota',
    })
  },
})
