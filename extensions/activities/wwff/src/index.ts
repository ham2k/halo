// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WWFF (World Wide Flora & Fauna). 44 contacts activate a park, and they may be
// accrued across several visits — hence `activates: 'once'`, unlike POTA's
// per-day activation.
//
// The list is public; the spot feed and spot posting go through an API key
// (`host.secret('WWFF_API_KEY')`), so a build without one keeps the
// references and simply offers no spots.

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  host,
  huntingExportHook,
  referenceActivity,
} from "@ham2k/extension-sdk"
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
} from "@ham2k/extension-sdk"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'wwff'
const ACTIVATION_TYPE = 'wwffActivation'
const REFERENCE_REGEX = /^[A-Z0-9]+FF-[0-9]{4,5}$/i

const SPOTS_URL = 'https://spots.wwff.co/static/spots.json'
const SPOT_POST_URL = 'https://spots.wwff.co/api/spots/add'

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'wwff',
  label: 'WWFF',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'KFF-0001',
  tFor,
  linkUrl: (reference: string) => `https://wwff.co/directory/?showRef=${encodeURIComponent(reference)}`,
  // app-polo registers no combinations for WWFF: one record, references joined.
  splitRecordsPerHuntedRef: false,
  adifRefField: 'WWFF',
})

/// 44 contacts, accrued across visits rather than per day, and a repeat contact
/// counts again on a new band, mode or day.
const WWFF_SCORING = {
  label: 'WWFF',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 44,
  allowsMultipleReferences: false,
  uniquePer: ['band', 'mode', 'day'] as const,
  activates: 'once' as const,
  refNoun: (ctx: HookContext) => tFor(ctx)('park'),
  refNounPlural: (ctx: HookContext) => tFor(ctx)('parksPlural'),
  p2pLabel: (ctx: HookContext) => tFor(ctx)('p2p'),
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

interface WWFFApiSpot {
  activator?: string
  reference?: string
  frequency_khz?: number
  mode?: string
  /// Seconds since the epoch, not milliseconds.
  spot_time?: number
  remarks?: string
  spotter?: string
}

/// The API key rides as a header on every call to the award's own endpoints.
/// Null when the build has none, in which case there is nothing to send and the
/// caller says so rather than trying.
async function apiHeaders(): Promise<Record<string, string> | null> {
  const key = await host.secret('WWFF_API_KEY')
  if (!key) return null
  return { 'X-API-Key': key, Accept: 'application/json' }
}

const SpotsHook = {
  sourceName: 'WWFF',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []
    const headers = await apiHeaders()
    // No key, no spots — the references still work offline, which is most of
    // what the extension is for.
    if (!headers) return []

    const response = await host.fetch(SPOTS_URL, { headers })
    if (response.status !== 200) throw new Error(`WWFF API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as WWFFApiSpot[]

    return apiSpots.map((spot) => {
      const freq = spot.frequency_khz != null ? Number(spot.frequency_khz) : undefined
      const sourceInfo: Record<string, JSONValue> = {}
      if (spot.remarks != null) sourceInfo.comments = spot.remarks
      if (spot.spotter != null) sourceInfo.spotter = spot.spotter.toUpperCase()

      return {
        their: { call: (spot.activator ?? '').toUpperCase() },
        freq,
        band: freq ? bandForFrequency(freq) : undefined,
        mode: spot.mode?.toUpperCase(),
        refs: spot.reference ? [{ ref: spot.reference, type: HUNTING_TYPE }] : [],
        spot: {
          // Seconds, unlike every other feed here.
          timeInMillis: (spot.spot_time ?? 0) * 1000,
          source: 'wwff',
          label: spot.reference ?? '',
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
    if (refs.length === 0) return { ok: false, message: 'No WWFF activation on this operation' }
    const call = String(operation.stationCall ?? '').trim()
    if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
    return postSpotToWWFF({
      call,
      ref: refs[0].ref!,
      freq,
      mode,
      comment,
      spotterCall: call,
    })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No WWFF reference on this QSO' }
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
    return postSpotToWWFF({
      call,
      ref: refs[0].ref!,
      freq,
      mode: qso.mode ? String(qso.mode) : undefined,
      comment,
      spotterCall: String(our.call ?? '').trim() || String(spotterCall ?? '').trim() || undefined,
    })
  },
}

/// The award's own wording for "you already spotted this", which app-polo
/// matches on and ignores.
const DUPLICATE_SPOT = /Duplicate spot detected/i

/// One reference per spot — the endpoint takes a single park.
async function postSpotToWWFF(
  { call, ref, freq, mode, comment, spotterCall }: {
    call: string
    ref: string
    freq: number
    mode?: string
    comment?: string
    spotterCall?: string
  },
): Promise<PostResult> {
  const headers = await apiHeaders()
  if (!headers) return { ok: false, message: 'This build has no WWFF API key' }

  try {
    const response = await host.fetch(SPOT_POST_URL, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        activator: call,
        reference: ref,
        frequency_khz: freq,
        // Null, not a guess: the feed would rather know the mode is unknown
        // than be told SSB. app-polo passes `vfo.mode` straight through.
        mode: mode || null,
        remarks: comment ?? '',
        ...(spotterCall ? { spotter: spotterCall } : {}),
      }),
    })
    if (response.status !== 200 && response.status !== 201) {
      // Not a failure, and app-polo says so explicitly: re-spotting is routine
      // — a new comment, back after a break — and the award answers "already
      // done". Reporting it paints a red error over a spot that is fine.
      if (DUPLICATE_SPOT.test(response.body ?? '')) return { ok: true }
      return { ok: false, message: `WWFF API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

/// The directory is public — no key — so the references work on any build.
const wwffDataFile: DataFileDefinition = {
  key: 'wwff-all-parks',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://wwff.co/wwff-data/wwff_directory.csv',
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'wwff',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    // The directory keeps retired parks and marks them.
    if ((r.status ?? '').trim() !== 'active') return null

    const ref = (r.reference ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.latitude)
    const parsedLon = Number.parseFloat(r.longitude)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon

    const published = (r.iaruLocator ?? '').trim()
    const grid = published
      ? published.replace(/[A-Z]{2}$/, (x) => x.toLowerCase())
      : lat != null && lon != null
        ? locationToGrid6(lat, lon)
        : undefined

    // The DXCC entity prefix rather than the raw numeric id, so `suggest` can
    // narrow by it the same way it does for POTA and SOTA.
    const dxccCode = Number.parseInt(r.dxccEnum, 10)
    const entityPrefix = DXCC_BY_CODE[dxccCode]?.entityPrefix

    return {
      subCategory: entityPrefix,
      key: ref,
      name: r.name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: r.name,
        dxccCode: Number.isNaN(dxccCode) ? undefined : dxccCode,
        entityPrefix,
        grid,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'wwff' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'wwff' })
    registerHook('activity', { hook: activityHook, key: 'wwff' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'wwff' })
    registerHook('adifImport', { hook: adifImportHook, key: 'wwff' })
    registerHook('spots', { hook: SpotsHook, key: 'wwff' })
    registerHook('dataFile', { hook: wwffDataFile, key: 'wwff-all-parks' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(WWFF_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'wwff',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'wwff', label: 'WWFF', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'wwff',
    })
    // The chaser side: every reference hunted, across the whole log — a
    // different key so it doesn't collide with the activator registration
    // above.
    registerHook('export', {
      hook: huntingExportHook({ key: 'wwff', label: 'WWFF', huntingType: HUNTING_TYPE, activationType: ACTIVATION_TYPE, icon: manifest.icon, color: manifest.accentColor }),
      key: 'wwff-hunter',
    })
  },
})
