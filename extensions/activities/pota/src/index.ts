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

const HUNTING_TYPE = 'pota'
const ACTIVATION_TYPE = 'potaActivation'
const REFERENCE_REGEX = /^[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

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

    return {
      subCategory: r.entityId,
      key: ref,
      name,
      lat,
      lon,
      flags: active ? 1 : 0,
      data: {
        reference: ref,
        dxccCode: parseInt(r.entityId, 10) || 0,
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
    registerHook('dataFile', { hook: potaDataFile, key: 'pota-all-parks' })
  },
})
