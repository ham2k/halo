// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTA (Summits on the Air) Extension. Registers:
//   ref:sota / ref:sotaActivation  — validation + summit decoration via api2.sota.org.uk API
//   activity                       — SOTA hunting + activation controls
//   adifFields                     — SOTA_REF/MY_SOTA_REF contributions for exports
//   spots                          — SOTAWatch spots source
//   dataFile                       — CSV database download and offline caching

import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"
import { defineExtension, host } from "@ham2k/polo-sdk"
import type {
  HookContext,
  LoggingControlDescriptor,
  Ref,
  Spot,
  DataFileDefinition,
} from "@ham2k/polo-sdk"

const HUNTING_TYPE = 'sota'
const ACTIVATION_TYPE = 'sotaActivation'
const REFERENCE_REGEX = /^[A-Z0-9]{1,4}\/[A-Z]{2}-[0-9]{3,}$/i

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

    return {
      subCategory: r.AssociationName ? r.AssociationName.split('/')[0] : undefined,
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
