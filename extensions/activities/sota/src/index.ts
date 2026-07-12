// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA (Summits on the Air) Extension. Registers:
//   ref:sota / ref:sotaActivation  — validation + summit decoration via api2.sota.org.uk API
//   activity                       — SOTA hunting + activation controls
//   adifFields                     — SOTA_REF/MY_SOTA_REF contributions for exports
//   spots                          — SOTAWatch spots source
//   dataFile                       — CSV database download and offline caching

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6, distanceOnEarth } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/polo-sdk"
import type {
  HookContext,
  LoggingControlDescriptor,
  Ref,
  Spot,
  DataFileDefinition,
  SuggestArgs,
  ActivitySuggestion,
  LookupRow,
} from "@ham2k/polo-sdk"

const HUNTING_TYPE = 'sota'
const ACTIVATION_TYPE = 'sotaActivation'
const REFERENCE_REGEX = /^[A-Z0-9]{1,4}\/[A-Z]{2}-[0-9]{3,}$/i

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
    const response = await host.fetch(`https://api2.sota.org.uk/api/summits/${encodeURIComponent(ref)}`)
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

  async decorateRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<Ref> {
    const reference = (ref.ref ?? '').toUpperCase().trim()
    if (!REFERENCE_REGEX.test(reference)) return { ...ref, ref: reference, name: 'Invalid reference' }

    const summit = await fetchSummit(reference)
    if (!summit?.name) return { ...ref, ref: reference, name: 'Unknown summit' }

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
}

const ActivityHook = {
  async loggingControls(
    _args: { operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    return [
      {
        key: 'sota/hunter',
        label: 'SOTA',
        icon: 'image-filter-hdr',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: HUNTING_TYPE,
          placeholder: 'W6/SD-026',
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
        key: 'sota/activation',
        label: 'SOTA activation',
        icon: 'image-filter-hdr',
        order: 10,
        optionType: 'optional',
        input: {
          kind: 'refList',
          refType: ACTIVATION_TYPE,
          placeholder: 'W6/SD-026',
          pattern: REFERENCE_REGEX.source,
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

interface SOTAApiSpot {
  id: number
  timeStamp: string
  comments: string | null
  callsign: string
  associationCode: string
  summitCode: string
  activatorCallsign: string
  activatorName: string
  frequency: string
  mode: string
  summitDetails: string
}

const SpotsHook = {
  sourceName: 'SOTAWatch',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    const response = await host.fetch('https://api2.sota.org.uk/api/spots/100')
    if (response.status !== 200) throw new Error(`SOTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as SOTAApiSpot[]

    // Dedupe activator callsigns, keeping the first (most recent) spot
    const dedupedSpots: SOTAApiSpot[] = []
    const includedCalls = new Set<string>()
    for (const spot of apiSpots) {
      const call = spot.activatorCallsign.toUpperCase()
      if (!includedCalls.has(call)) {
        includedCalls.add(call)
        dedupedSpots.push(spot)
      }
    }

    return dedupedSpots.map((spot) => {
      const freqMHz = parseFloat(spot.frequency)
      const freq = freqMHz ? freqMHz * 1000 : 0
      const ref = `${spot.associationCode}/${spot.summitCode}`.toUpperCase()
      return {
        their: { call: spot.activatorCallsign },
        freq: freq || undefined,
        band: freq ? bandForFrequency(freq) : undefined,
        mode: spot.mode ? spot.mode.toUpperCase() : undefined,
        refs: [{ ref, type: HUNTING_TYPE }],
        spot: {
          timeInMillis: Date.parse(spot.timeStamp.endsWith('Z') ? spot.timeStamp : spot.timeStamp + 'Z'),
          source: 'sota',
          icon: 'image-filter-hdr',
          label: `${ref}: ${spot.summitDetails}`,
          sourceInfo: {
            id: spot.id,
            comments: spot.comments ?? '',
            spotter: spot.callsign,
          },
        },
      }
    })
  },
}

const sotaDataFile: DataFileDefinition = {
  key: 'sota-all-summits',
  name: 'SOTA: All Summits',
  description: 'Database of all SOTA references',
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

defineExtension({
  key: 'sota',
  name: 'Summits on the Air',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: RefHandler, key: 'sota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: RefHandler, key: 'sota' })
    registerHook('activity', { hook: ActivityHook, key: 'sota' })
    registerHook('adifFields', { hook: AdifFieldsHook, key: 'sota' })
    registerHook('spots', { hook: SpotsHook, key: 'sota' })
    registerHook('dataFile', { hook: sotaDataFile, key: 'sota-all-summits' })
  },
})
