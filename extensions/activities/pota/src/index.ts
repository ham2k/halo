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

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6, distanceOnEarth } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/polo-sdk"
import type {
  AnnotatedCallInfo,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  LookupResult,
  Ref,
  Spot,
  DataFileDefinition,
  SuggestArgs,
  ActivitySuggestion,
  LookupRow,
} from "@ham2k/polo-sdk"

const HUNTING_TYPE = 'pota'
const ACTIVATION_TYPE = 'potaActivation'
const REFERENCE_REGEX = /^[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

// Loads the bundled BIGCTY data once per runtime activation, so a park's
// DXCC entity (from its numeric entityId) and a caller's own entity (from
// their callsign) resolve without needing a network round trip.
useBuiltinCountryFile()

function entityPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  return annotateFromCountryFile(parseCallsign(call)).entityPrefix
}

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
    _args: { operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: 'pota/hunter',
        label: 'POTA',
        icon: 'pine-tree',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: HUNTING_TYPE,
          placeholder: 'US-1234',
          pattern: REFERENCE_REGEX.source,
        },
      },
    ]
  },

  async operationControls(
    _args: { operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: 'pota/activation',
        label: 'POTA activation',
        icon: 'pine-tree',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: ACTIVATION_TYPE,
          placeholder: 'US-1234',
          pattern: REFERENCE_REGEX.source,
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

    return withDistance.slice(0, MAX_SUGGESTIONS).map(({ row, distance }) => {
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
  },
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

/// A QSO-scoped grid lookup: any POTA park hunted on THIS qso is a more
/// specific ("portable") location than a callsign's registered home QTH —
/// same concept as a `/P` callsign, per ham2k/app-halo-dist#8's worked
/// example. Skips entirely if there's no POTA ref on the qso, if the
/// callInfo already has a grid from a higher-priority source, or if this
/// pass is offline (the network fallback in `fetchPark` needs online).
async function lookupCall(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  if (callInfo.grid) return []
  const refs = refsOfType(qso, HUNTING_TYPE)
  if (refs.length === 0) return []
  if (!ctx.online) return []

  const park = await fetchPark(refs[0].ref!.toUpperCase())
  if (!park?.grid6) return []

  const location = [park.reference, park.locationDesc, park.name].filter((x) => x).join(' ')
  return [{ call: callInfo.call, source: 'pota', scope: 'qso', locationScope: 'portable', grid: park.grid6, location }]
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
