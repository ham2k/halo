// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA (Parks on the Air) — the archetype activity extension. Registers:
//   ref:pota / ref:potaActivation  — validation + park decoration via API
//   activity                       — declarative logging + operation controls
//   adifFields                     — SIG/POTA_REF contributions for exports
//   spots                          — POTA.app spots source
//   dataFile                       — CSV database download and offline caching
// Ref types follow app-polo's QSON convention: 'pota' for hunting,
// 'potaActivation' for activating.

import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6, distanceOnEarth } from "@ham2k/lib-geo-tools"
import { defineExtension, host, LOCATION_ACCURACY } from "@ham2k/halo-extension-sdk"
import type {
  AnnotatedCallInfo,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  LookupResult,
  Ref,
  Spot,
  SpotEligibility,
  PostResult,
  PostSelfSpotRequest,
  PostOtherSpotRequest,
  DataFileDefinition,
  SuggestArgs,
  ActivitySuggestion,
  LookupRow,
} from "@ham2k/halo-extension-sdk"
import { REFERENCE_REGEX, normalizeReference, entityPrefixForCall, transformsForPrefix, hunterDefaultPrefix, activationDefaultPrefix } from "./refFormatting.ts"

export { REFERENCE_REGEX, transformsForPrefix, hunterDefaultPrefix, activationDefaultPrefix } from "./refFormatting.ts"

const HUNTING_TYPE = 'pota'
const ACTIVATION_TYPE = 'potaActivation'

// POTA references are `{country}-{number}` and a park's `locationDesc` is a
// comma-separated list of `{country}-{state}` areas. In these countries a
// single-area park sits in one meaningful state/province worth surfacing on
// the guess; elsewhere the area code isn't a useful "state", so we skip it.
const COUNTRIES_WHERE_STATES_MATTER = new Set(['US', 'CA', 'AU'])

// Nearby suggestions use a ~150km bounding box (dbLookupSelectByLocation is a
// rectangular query, not a true radius); results are then given a real
// Haversine distance and capped, same trade-off app-polo's own POTA
// suggestions make.
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

interface POTAParkInfo {
  reference: string
  name: string
  grid6: string
  locationDesc: string
  active: number
}

const parkCache = new Map<string, POTAParkInfo | null>()

async function fetchPark(ref: string): Promise<POTAParkInfo | null> {
  const cached = parkCache.get(ref)
  if (cached !== undefined) return cached

  // 1. Try querying the offline local lookups database first
  try {
    const row = await host.dbLookupSelectOne('pota', ref)
    if (row && row.data) {
      const info: POTAParkInfo = {
        reference: row.key,
        name: row.name ?? '',
        grid6: row.data.grid6 ?? '',
        locationDesc: row.data.locationDesc ?? '',
        active: row.flags ?? 1,
      }
      parkCache.set(ref, info)
      return info
    }
  } catch (e) {
    host.log(`Database lookup error for POTA park ${ref}: ${e}`)
  }

  // 2. Fall back to network fetch
  let park: POTAParkInfo | null = null
  try {
    const response = await host.fetch(`https://api.pota.app/park/${encodeURIComponent(ref)}`)
    if (response.status === 200 && response.body && response.body !== 'null') {
      park = JSON.parse(response.body) as POTAParkInfo
    }
  } catch {
    return null // network trouble: report nothing, don't cache
  }
  parkCache.set(ref, park)
  return park
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = (ref.ref ?? '').toUpperCase().trim()
    return { valid: REFERENCE_REGEX.test(normalized), normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<Ref> {
    const reference = (ref.ref ?? '').toUpperCase().trim()
    if (!REFERENCE_REGEX.test(reference)) return { ...ref, ref: reference, name: 'Invalid reference' }

    const park = await fetchPark(reference)
    if (!park?.name) return { ...ref, ref: reference, name: 'Unknown park' }

    return {
      ...ref,
      ref: reference,
      name: park.name,
      grid: park.grid6,
      location: park.locationDesc,
      program: 'POTA',
      label: `POTA ${reference}: ${park.name}`,
      shortLabel: `POTA ${reference}`,
    }
  },
}

const ActivityHook = {
  async loggingControls(
    { operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const prefix = hunterDefaultPrefix(operation, qso)
    return [
      {
        key: 'pota/hunter',
        label: 'POTA',
        icon: 'pine-tree',
        color: '#068541',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: HUNTING_TYPE,
          placeholder: `${prefix}-...`,
          pattern: REFERENCE_REGEX.source,
          transforms: transformsForPrefix(prefix),
        },
      },
    ]
  },

  async operationControls(
    { operation }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const prefix = activationDefaultPrefix(operation)
    return [
      {
        key: 'pota/activation',
        label: 'POTA activation',
        icon: 'pine-tree',
        color: '#068541',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: ACTIVATION_TYPE,
          placeholder: `${prefix}-...`,
          pattern: REFERENCE_REGEX.source,
          transforms: transformsForPrefix(prefix),
        },
      },
    ]
  },

  async suggest({ location, searchTerm, callsign }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
    const rows: LookupRow[] = searchTerm
      ? await host.dbLookupSelectAll('pota', searchTerm)
      : location
        ? await host.dbLookupSelectByLocation('pota', location.lat, location.lon, NEARBY_DELTA)
        : []

    // A name/code search spans every POTA park worldwide, so narrow it to
    // the caller's own DXCC entity when we can tell whose callsign this is
    // — nearby (location-based) results are already geographically scoped
    // by distance and shouldn't also be entity-restricted (a caller near a
    // border may well want a nearby park just across it).
    const callerEntity = searchTerm ? entityPrefixForCall(callsign) : undefined
    const filteredRows = callerEntity ? rows.filter((row) => row.subCategory === callerEntity) : rows

    const withDistance = filteredRows.map((row) => ({
      row,
      distance:
        location && row.lat != null && row.lon != null
          ? (distanceOnEarth(location, { lat: row.lat, lon: row.lon }) ?? undefined)
          : undefined,
    }))
    // Nearby (no search term) results must be ranked by real distance before
    // truncating to MAX_SUGGESTIONS — the DB query's row order isn't a
    // reliable proxy for it, so slicing first can drop a closer entry in
    // favor of a farther one that merely came back earlier.
    if (!searchTerm) {
      withDistance.sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity))
    }

    const suggestions: ActivitySuggestion[] = withDistance.slice(0, MAX_SUGGESTIONS).map(({ row, distance }) => {
      const data = (row.data ?? {}) as Record<string, any>
      return {
        type: ACTIVATION_TYPE,
        ref: row.key,
        name: row.name,
        grid: data.grid6,
        location: data.locationDesc,
        program: 'POTA',
        label: `POTA ${row.key}: ${row.name ?? ''}`,
        shortLabel: `POTA ${row.key}`,
        distance,
        relevance: relevanceForMatch(row, searchTerm),
      }
    })

    // A fully-formed reference (e.g. "US-15000"/"US15000", or the special
    // "-TEST" suffix) is always offered, even when it's missing from — or
    // not yet loaded into — the local lookup table (a brand-new park, or
    // the table hasn't synced yet), so a user who already knows their
    // park's code isn't stuck with "no results". Skipped if a real row for
    // it already made the cut above, so a known park's name/grid still
    // take priority.
    const normalizedSearch = searchTerm ? normalizeReference(searchTerm) : null
    if (normalizedSearch && !suggestions.some((s) => s.ref === normalizedSearch)) {
      const isTestRef = normalizedSearch.endsWith('-TEST')
      const name = isTestRef ? 'Test Park' : 'Unknown Park'
      if (suggestions.length >= MAX_SUGGESTIONS) suggestions.pop()
      suggestions.unshift({
        type: ACTIVATION_TYPE,
        ref: normalizedSearch,
        name,
        program: 'POTA',
        label: `POTA ${normalizedSearch}: ${name}`,
        shortLabel: `POTA ${normalizedSearch}`,
        relevance: 1,
      })
    }

    return suggestions
  },
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

/// A QSO-scoped grid lookup: any POTA park hunted on THIS qso is a more
/// specific ("portable") location than a callsign's registered home QTH —
/// same concept as a `/P` callsign, per ham2k/app-halo-dist#8's worked
/// example. Returns the park's grid tagged `REASONABLE` accuracy (a park can
/// be large, so its single-point grid may be off by a few grids); the merge
/// keeps whichever same-scope result is most accurate, so this no longer has
/// to bail when a grid already exists — a more precise SOTA summit on the same
/// qso still wins (ham2k/app-halo-dist#185). Skips when there's no POTA ref or
/// this pass is offline (the network fallback in `fetchPark` needs online).
async function lookupCall(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const refs = refsOfType(qso, HUNTING_TYPE)
  if (refs.length === 0) return []
  if (!ctx.online) return []

  const park = await fetchPark(refs[0].ref!.toUpperCase())
  if (!park?.grid6) return []

  // In state-relevant countries, a park whose locationDesc names exactly one
  // area sits in a single state — surface it (the area's second, post-`-`
  // part) both on the guess and in the location text.
  const country = park.reference.split('-')[0]
  const areas = park.locationDesc.split(',').map((a) => a.trim()).filter((a) => a)
  let state: string | undefined
  if (COUNTRIES_WHERE_STATES_MATTER.has(country) && areas.length === 1) {
    const s = areas[0].split('-')[1]
    if (s) state = s
  }

  const namePart = park.name ? `: ${park.name}` : ''
  const location = state ? `${park.reference}, ${state}${namePart}` : `${park.reference}${namePart}`

  const result: LookupResult[number] = {
    call: callInfo.call,
    source: 'pota',
    scope: 'qso',
    locationScope: 'portable',
    grid: park.grid6,
    location,
    locAccuracy: LOCATION_ACCURACY.REASONABLE,
  }
  if (state) result.state = state
  return [result]
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const fields: { name: string; value: string }[] = []
    const huntingRefs = refsOfType(qso, HUNTING_TYPE)
    const activationRefs = refsOfType(operation, ACTIVATION_TYPE)

    // A park-to-park boundary activation logs several Ref entries of the
    // same type — SIG_INFO/MY_SIG_INFO take only the primary (first) one,
    // POTA_REF/MY_POTA_REF list them all.
    if (huntingRefs.length > 0) {
      fields.push({ name: 'SIG', value: 'POTA' })
      fields.push({ name: 'SIG_INFO', value: huntingRefs[0].ref! })
      fields.push({ name: 'POTA_REF', value: huntingRefs.map((r) => r.ref).join(',') })
    }
    if (activationRefs.length > 0) {
      fields.push({ name: 'MY_SIG', value: 'POTA' })
      fields.push({ name: 'MY_SIG_INFO', value: activationRefs[0].ref! })
      fields.push({ name: 'MY_POTA_REF', value: activationRefs.map((r) => r.ref).join(',') })
    }
    return fields
  },
}

interface POTAApiSpot {
  spotId: number
  activator: string
  frequency: string
  mode: string
  reference: string
  name: string
  locationDesc: string
  spotTime: string
  spotter: string
  comments: string
  source: string
  count: number
}

const SpotsHook = {
  sourceName: 'POTA.app',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    const response = await host.fetch('https://api.pota.app/spot/activator')
    if (response.status !== 200) throw new Error(`POTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as POTAApiSpot[]

    return apiSpots
      .filter((spot) => !spot.comments?.match(/QRT/i))
      .map((spot) => {
        const freq = parseFloat(spot.frequency)
        return {
          their: { call: spot.activator },
          freq: freq || undefined,
          band: freq ? bandForFrequency(freq) : undefined,
          mode: spot.mode,
          refs: [{ ref: spot.reference, type: HUNTING_TYPE }],
          spot: {
            timeInMillis: Date.parse(spot.spotTime + 'Z'),
            source: 'pota',
            label: `${spot.reference}: ${[simplifyStates(spot.locationDesc), spot.name].filter((x) => x).join(' • ')}`,
            sourceInfo: {
              source: spot.source,
              id: spot.spotId,
              comments: spot.comments,
              spotter: spot.spotter,
              count: spot.count,
            },
          },
        }
      })
  },

  async isSelfSpotEnabled({ operation }: { operation: Record<string, JSONValue> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(operation, ACTIVATION_TYPE).length > 0 ? { enabled: true, icon: 'pine-tree' } : { enabled: false }
  },

  async isOtherSpotEnabled({ qso }: { qso: Record<string, JSONValue> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(qso, HUNTING_TYPE).length > 0 ? { enabled: true, icon: 'pine-tree' } : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No POTA activation on this operation' }
    const call = String(operation.stationCall ?? '')
    return postSpotToPOTA({ call, spotter: call, freq, mode, refs, comment, appName: ctx.appName })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No POTA reference on this QSO' }
    const freq = Number(qso.freq)
    if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }
    const their = (qso.their ?? {}) as Record<string, JSONValue>
    const our = (qso.our ?? {}) as Record<string, JSONValue>
    return postSpotToPOTA({
      call: String(their.call ?? ''),
      spotter: String(our.call ?? spotterCall ?? ''),
      freq,
      mode: qso.mode ? String(qso.mode) : undefined,
      refs,
      comment,
      appName: ctx.appName,
    })
  },
}

/// Posts directly to the POTA API — no authentication required (unlike
/// SOTA's spot API, which needs a logged-in account app-halo doesn't have
/// yet). Ported from app-polo's POTAPostSpotAPI.js.
async function postSpotToPOTA(
  { call, spotter, freq, mode, refs, comment, appName }: { call: string; spotter: string; freq: number; mode?: string; refs: Ref[]; comment?: string; appName?: string },
): Promise<PostResult> {
  const refComment = refs.length > 1 ? `${refs.length}-fer: ${refs.map((r) => r.ref).join(' ')}` : ''
  try {
    const response = await host.fetch('https://api.pota.app/spot', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        activator: call,
        spotter,
        frequency: freq,
        reference: refs[0].ref,
        mode: mode ?? 'SSB',
        source: appName ?? 'Ham2K Logger',
        comments: [comment, refComment].filter((x) => x).join(' '),
      }),
    })
    if (response.status !== 200) {
      return { ok: false, message: `POTA API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

function simplifyStates(locationDesc: string): string {
  if (!locationDesc) return ''
  const states = locationDesc.split(',')
  const oneState = states[0].split('-', 2)[1]?.trim()
  return states.length > 1 ? `${oneState}+${states.length - 1}` : (oneState ?? '')
}

const potaDataFile: DataFileDefinition = {
  key: 'pota-all-parks',
  name: 'POTA: All Parks',
  description: 'Database of all POTA references',
  url: 'https://pota.app/all_parks_ext.csv',
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'pota',
  csvOptions: {
    hasHeaders: true,
    delimiter: ',',
  },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    if (!r.reference || !r.entityId) {
      return null
    }
    const lat = parseFloat(r.latitude) || 0
    const lon = parseFloat(r.longitude) || 0
    const active = r.active === '1'
    const ref = r.reference.toUpperCase()
    const name = r.name
    const dxccCode = parseInt(r.entityId, 10) || 0
    // Consistent with SOTA's subCategory (see its own comment): the DXCC
    // entity prefix, not the raw numeric entityId, so `suggest` can filter
    // by it the same way regardless of which activity is being searched.
    const dxccPrefix = DXCC_BY_CODE[dxccCode]?.entityPrefix

    return {
      subCategory: dxccPrefix,
      key: ref,
      name,
      lat,
      lon,
      flags: active ? 1 : 0,
      data: {
        reference: ref,
        dxccCode,
        dxccPrefix,
        name,
        active,
        grid6: r.grid || locationToGrid6(lat, lon),
        latitude: lat,
        longitude: lon,
        locationDesc: r.locationDesc || '',
      },
    }
  },
}

defineExtension({
  key: 'pota',
  name: 'Parks on the Air',
  shortName: 'POTA',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: RefHandler, key: 'pota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: RefHandler, key: 'pota' })
    registerHook('activity', { hook: ActivityHook, key: 'pota' })
    registerHook('adifFields', { hook: AdifFieldsHook, key: 'pota' })
    registerHook('spots', { hook: SpotsHook, key: 'pota' })
    // Priority 100 — higher than QRZ (99) / HamDB (50), so the POTA park's
    // grid is resolved BEFORE a home-QTH lookup can set callInfo.grid; the
    // `if (callInfo.grid) return []` guard below would otherwise skip this
    // hook once a lower-priority qth-scope grid was already merged in.
    registerHook('lookup', { hook: { lookupCall }, key: 'pota', priority: 100 })
    registerHook('dataFile', { hook: potaDataFile, key: 'pota-all-parks' })
  },
})
