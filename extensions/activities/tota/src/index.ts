// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// TOTA (Towers on the Air) — Czech lookout towers.
//
// The one award here whose LIST needs the API key, not just its spots: the
// key is a query parameter on the data-file URL. A build without one has no
// towers at all, which is why this extension was unportable until
// `host.secret('TOTA_API_KEY')` existed.
//
// Because the key rides in a URL, nothing here may log one — see
// `DataFileManager.redactUrlForLog` for the same rule on the core side.

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  host,
  referenceActivity,
} from "@ham2k/halo-extension-sdk"
import type {
  DataFileDefinition,
  HookContext,
  JSONValue,
  PostOtherSpotRequest,
  PostResult,
  PostSelfSpotRequest,
  Ref,
  Spot,
  SpotEligibility,
} from "@ham2k/halo-extension-sdk"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"

import { formEncode } from "../../../shared/gmaSpots.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'tota'
const ACTIVATION_TYPE = 'totaActivation'
const REFERENCE_REGEX = /^[A-Z0-9]+R-[0-9]{4}$/i

const API_BASE = 'https://www.rozhledny.eu/apidata'

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'tota',
  label: 'TOTA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'OKR-0001',
  tFor,
  // One record per hunted tower.
  splitRecordsPerHuntedRef: true,
})

/// Thirteen contacts activate a tower, per UTC day, and the only axis that
/// makes a repeat contact fresh is the tower itself — not band, not mode.
const TOTA_SCORING = {
  label: 'TOTA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 13,
  allowsMultipleReferences: true,
  uniquePer: ['ref'] as const,
  activates: 'daily' as const,
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

interface TOTAApiSpot {
  callsign?: string
  tower_ref?: string
  frequency?: number | string
  mode?: string
  time_utc?: string
  comment?: string
  spotter?: string
}

const SpotsHook = {
  sourceName: 'TOTA',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []
    const key = await host.secret('TOTA_API_KEY')
    // No key, no spots. Nor any towers — see the data file below.
    if (!key) return []

    const response = await host.fetch(`${API_BASE}/cluster.php?key=${encodeURIComponent(key)}`, {
      headers: { Accept: 'application/json' },
    })
    // Deliberately NOT reporting the URL: it carries the key.
    if (response.status !== 200) throw new Error(`TOTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as TOTAApiSpot[]

    return apiSpots.map((spot) => {
      const parsed = typeof spot.frequency === 'string' ? Number.parseFloat(spot.frequency) : spot.frequency
      const freq = parsed && !Number.isNaN(parsed) ? parsed : undefined
      const sourceInfo: Record<string, JSONValue> = {}
      if (spot.comment != null) sourceInfo.comments = spot.comment
      if (spot.spotter != null) sourceInfo.spotter = spot.spotter

      return {
        their: { call: (spot.callsign ?? '').toUpperCase() },
        freq,
        band: freq ? bandForFrequency(freq) : undefined,
        mode: spot.mode?.toUpperCase(),
        refs: spot.tower_ref ? [{ ref: spot.tower_ref, type: HUNTING_TYPE }] : [],
        spot: {
          timeInMillis: Date.parse(spot.time_utc ?? ''),
          source: 'tota',
          // The tower's NAME comes from the local list, which the spots panel
          // resolves from the ref — app-polo looks it up here, but that is a
          // database round trip per spot.
          label: spot.tower_ref ?? '',
          sourceInfo,
        },
      }
    })
  },

  async isSelfSpotEnabled({ operation }: { operation: Record<string, any> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(operation, ACTIVATION_TYPE).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async isOtherSpotEnabled({ qso }: { qso: Record<string, any> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(qso, HUNTING_TYPE).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No TOTA activation on this operation' }
    // One spot per tower, like app-polo: the endpoint takes a single
    // `tower_ref`, so an n-fer is several posts rather than a joined field.
    const call = String(operation.stationCall ?? '').trim()
    if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
    return postSpotsToTOTA(call, refs, freq, mode, comment)
  },

  async postOtherSpot({ qso, comment }: PostOtherSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No TOTA reference on this QSO' }
    const freq = Number(qso.freq)
    if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }
    const their = (qso.their ?? {}) as Record<string, unknown>
    // Guarded like the frequency above: a spot naming no station reaches
    // everybody watching, which is worse than no spot.
    const call = String(their.call ?? '').trim()
    if (!call) return { ok: false, message: 'This QSO has no callsign to spot' }
    return postSpotsToTOTA(
      call,
      refs,
      freq,
      qso.mode ? String(qso.mode) : undefined,
      comment,
    )
  },
}

/// The award's own wording for "you already spotted this", which app-polo
/// matches on and ignores.
const DUPLICATE_SPOT = /Duplicate self-spot/i

/// A POST with a JSON body; only the KEY rides in the query string, which is
/// why no error message here may quote the URL.
async function postSpotsToTOTA(
  call: string,
  refs: Ref[],
  freq: number,
  mode?: string,
  comment?: string,
): Promise<PostResult> {
  const key = await host.secret('TOTA_API_KEY')
  if (!key) return { ok: false, message: 'This build has no TOTA API key' }

  // `formEncode`, not URLSearchParams: QuickJS has no such global.
  const query = formEncode({ key })

  // EVERY tower is attempted, even after one fails — app-polo tracks an `allOk`
  // across the loop rather than returning early. Stopping at the first failure
  // leaves a tower the operator IS activating unspotted, with nothing saying
  // which. Failures are collected and named instead.
  const failures: string[] = []

  for (const ref of refs) {
    try {
      const response = await host.fetch(`${API_BASE}/cluster_selfspot.php?${query}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          callsign: call,
          frequency: freq,
          // Null, not a guess — see WWBOTA. app-polo passes `vfo.mode` through.
          mode: mode || null,
          tower_ref: ref.ref,
          comment: comment ?? '',
        }),
      })
      // A duplicate is not a failure, and app-polo ignores this one by name:
      // re-spotting the same tower is a routine thing to do.
      if (
        response.status !== 200 && response.status !== 201 &&
        !DUPLICATE_SPOT.test(response.body ?? '')
      ) {
        failures.push(`${ref.ref} (HTTP ${response.status})`)
      }
    } catch (e) {
      failures.push(`${ref.ref} (${e instanceof Error ? e.message : String(e)})`)
    }
  }

  if (failures.length === 0) return { ok: true }
  // Named, because "one of your three towers failed" is not actionable. Refs
  // are safe to quote; the URL is not, since it carries the key.
  return { ok: false, message: `TOTA spot failed for ${failures.join(', ')}` }
}

/// The ONLY list in the port that needs a key, which is why `url` is a function
/// rather than a string: it is resolved once per refresh, after asking for the
/// key. Without one the request goes out bare and the award refuses it — the
/// honest failure, since there is no anonymous tower list to fall back to.
///
/// The resolved URL carries a secret, which is why the core redacts query
/// strings before logging a fetch (`DataFileManager.redactUrlForLog`).
const totaDataFile: DataFileDefinition = {
  key: 'tota-all-towers',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: async () => {
    const key = await host.secret('TOTA_API_KEY')
    return key ? `${API_BASE}/tower.php?key=${encodeURIComponent(key)}` : `${API_BASE}/tower.php`
  },
  maxAgeInDays: 30,
  fetchType: 'json',
  category: 'tota',
  jsonToLookupEntry: (entry: Record<string, any>) => {
    const ref = String(entry?.ref ?? '').trim().toUpperCase()
    if (!ref) return null

    const lat = typeof entry?.lat === 'number' ? entry.lat : undefined
    const lon = typeof entry?.lon === 'number' ? entry.lon : undefined

    return {
      // The country part of the reference (`OKR` of `OKR-0001`).
      subCategory: ref.split('-')[0],
      key: ref,
      name: entry?.name,
      lat,
      lon,
      flags: 1,
      data: {
        ...entry,
        ref,
        grid: lat != null && lon != null ? locationToGrid6(lat, lon) : undefined,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'tota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'tota' })
    registerHook('activity', { hook: activityHook, key: 'tota' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'tota' })
    registerHook('spots', { hook: SpotsHook, key: 'tota' })
    registerHook('dataFile', { hook: totaDataFile, key: 'tota-all-towers' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(TOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE] },
      }),
      key: 'tota',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'tota', label: 'TOTA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'tota',
    })
  },
})
