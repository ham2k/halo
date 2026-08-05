// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LLOTA (Lakes and Lagoons on the Air). Shaped like POTA: ten contacts per UTC
// day, several lakes activated at once, and one contact crediting several
// hunted lakes — so it SPLITS a multi-lake contact into one record per lake.
//
// The list is public; the spot feed and spot posting go through an API key
// (`host.secret('LLOTA_API_KEY')`), so a build without one keeps the
// references and simply offers no spots.

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

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'llota'
const ACTIVATION_TYPE = 'llotaActivation'
const REFERENCE_REGEX = /^LL[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

const API_BASE = 'https://llota.app/api/public'

/// Ten contacts per UTC day, n-fers allowed, and a repeat contact counts again
/// on a new day, band, mode or lake.
const LLOTA_SCORING = {
  label: 'LLOTA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 10,
  allowsMultipleReferences: true,
  uniquePer: ['band', 'mode', 'day', 'ref'] as const,
  activates: 'daily' as const,
}

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'llota',
  label: 'LLOTA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'LLUS-0001',
  tFor,
  // One record per hunted lake, like POTA.
  splitRecordsPerHuntedRef: true,
  adifRefField: 'LLOTA',
  // Derived from the scorer's own rule, not a separate flag — the UI control
  // and the scorer can't disagree about whether this award allows n-fers.
  allowsMultiple: LLOTA_SCORING.allowsMultipleReferences,
})

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

interface LLOTAApiSpot {
  id?: number
  callsign?: string
  reference?: string
  reference_name?: string
  frequency?: number
  band?: string
  mode?: string
  updated_at?: string
  spotter?: string
  comments?: string
  history?: { comment?: string }[]
}

async function apiHeaders(): Promise<Record<string, string> | null> {
  const key = await host.secret('LLOTA_API_KEY')
  if (!key) return null
  return { 'X-API-Key': key, Accept: 'application/json' }
}

const SpotsHook = {
  sourceName: 'LLOTA',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []
    const headers = await apiHeaders()
    // No key, no spots — the references still work, which is most of what the
    // extension is for.
    if (!headers) return []

    const response = await host.fetch(`${API_BASE}/spots`, { headers })
    if (response.status !== 200) throw new Error(`LLOTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as LLOTAApiSpot[]

    // app-polo drops spots whose comments say QRT rather than showing an
    // operator who has packed up.
    return apiSpots
      .filter((spot) => !/QRT/i.test(spot.comments ?? ''))
      .map((spot) => {
        const freq = spot.frequency
        const sourceInfo: Record<string, JSONValue> = {}
        if (spot.id != null) sourceInfo.id = spot.id
        if (spot.spotter != null) sourceInfo.spotter = spot.spotter
        const comments = (spot.history ?? []).map((h) => h.comment).filter((c) => c) as string[]
        if (comments.length > 0) sourceInfo.comments = comments

        return {
          their: { call: (spot.callsign ?? '').toUpperCase() },
          freq,
          band: freq ? bandForFrequency(freq) : spot.band,
          mode: spot.mode?.toUpperCase(),
          refs: spot.reference ? [{ ref: spot.reference, type: HUNTING_TYPE }] : [],
          spot: {
            timeInMillis: Date.parse(spot.updated_at ?? ''),
            source: 'llota',
            label: [spot.reference, spot.reference_name].filter((x) => x).join(': '),
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

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No LLOTA activation on this operation' }
    const call = String(operation.stationCall ?? '').trim()
    if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
    return postSpotToLLOTA({ call, refs, freq, mode, comment, operatorCall: call, appName: ctx.appName })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No LLOTA reference on this QSO' }
    const freq = Number(qso.freq)
    if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }
    const their = (qso.their ?? {}) as Record<string, unknown>
    const our = (qso.our ?? {}) as Record<string, unknown>
    // Trimmed and `||`-chained rather than `??`-chained: the core hands over an
    // EMPTY STRING as readily as it omits a key, and `'' ?? fallback` is `''` —
    // so a `??` chain silently loses the operator's own callsign instead of
    // falling back to it. Same rule as gmaSpots' `firstNonEmpty`.
    const call = String(their.call ?? '').trim()
    if (!call) return { ok: false, message: 'This QSO has no callsign to spot' }
    return postSpotToLLOTA({
      call,
      refs,
      freq,
      mode: qso.mode ? String(qso.mode) : undefined,
      comment,
      operatorCall: String(our.call ?? '').trim() || String(spotterCall ?? '').trim() || undefined,
      appName: ctx.appName,
    })
  },
}

/// Posts to `spots/spot` — NOT the `spots` collection the feed reads. The
/// endpoint takes one lake, so an n-fer names the rest in the comment the way
/// app-polo does.
async function postSpotToLLOTA(
  { call, refs, freq, mode, comment, operatorCall, appName }: {
    call: string
    refs: Ref[]
    freq: number
    mode?: string
    comment?: string
    operatorCall?: string
    appName?: string
  },
): Promise<PostResult> {
  const headers = await apiHeaders()
  if (!headers) return { ok: false, message: 'This build has no LLOTA API key' }

  const nfer = refs.length > 1 ? `${refs.length}-fer: ${refs.map((r) => r.ref).join(' ')}` : ''

  try {
    const response = await host.fetch(`${API_BASE}/spots/spot`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        callsign: call,
        // The award's own field name for who is doing the spotting.
        operator_callsign: operatorCall ?? '',
        frequency: freq,
        reference: refs[0].ref,
        // The ONLY one of the three that really does default: app-polo's
        // `LLOTAPostSpotAPI.js` writes `mode ?? 'SSB'` here, where WWFF and
        // TOTA pass the mode straight through. Same-looking line, opposite
        // verdict — don't make these three consistent.
        mode: mode ?? 'SSB',
        source: appName ?? 'Ham2K Logger',
        comments: [comment, nfer].filter((x) => x).join(' '),
      }),
    })
    if (response.status > 299) {
      return { ok: false, message: `LLOTA API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

/// The `version=lite` list is public — no key — so references work on any
/// build. A bare top-level array, hence no root path.
const llotaDataFile: DataFileDefinition = {
  key: 'llota-all-references',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: `${API_BASE}/references?version=lite`,
  maxAgeInDays: 30,
  fetchType: 'json',
  category: 'llota',
  jsonToLookupEntry: (entry: Record<string, any>) => {
    const ref = String(entry?.reference_code ?? '').trim().toUpperCase()
    if (!ref) return null

    const lat = typeof entry?.latitude === 'number' ? entry.latitude : undefined
    const lon = typeof entry?.longitude === 'number' ? entry.longitude : undefined

    return {
      // The country part of the reference (`LLUS` of `LLUS-0001`), which is how
      // an operator narrows a search to their own.
      subCategory: ref.split('-')[0],
      key: ref,
      name: entry?.name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: entry?.name,
        location: ref.split('-')[0],
        grid: lat != null && lon != null ? locationToGrid6(lat, lon) : undefined,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'llota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'llota' })
    registerHook('activity', { hook: activityHook, key: 'llota' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'llota' })
    registerHook('spots', { hook: SpotsHook, key: 'llota' })
    registerHook('dataFile', { hook: llotaDataFile, key: 'llota-all-references' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(LLOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'llota',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'llota', label: 'LLOTA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'llota',
    })
  },
})
