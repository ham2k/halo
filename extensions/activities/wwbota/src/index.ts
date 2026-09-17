// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WWBOTA (Bunkers on the Air) — an award with its own spot FEED,
// and one whose activation threshold depends on WHICH reference is being
// activated: 10 contacts in Slovenia and North Macedonia, 25 everywhere else.
//
// It also answers for the legacy `ukbota` ref types. The award was UKBOTA
// before it went worldwide and logs synced from app-polo still carry those, so
// dropping them would leave old bunker references undecorated. They are
// registered but deliberately NOT in the manifest's `hooks`: that list is what
// the host offers to enable for an unhandled reference, and there is no
// control for a legacy type — an offer that cannot clear the row is worse than
// no offer (hook-check.mjs enforces this).

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  entityPrefixForCall,
  host,
  huntingExportHook,
  learnedReferencePrefix,
  referenceActivity,
} from "@ham2k/extension-sdk"
import type { RefTransform } from "@ham2k/extension-sdk"
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
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'wwbota'
const ACTIVATION_TYPE = 'wwbotaActivation'
/// Pre-worldwide ref types, still present in synced logs.
const LEGACY_TYPES = ['ukbota', 'ukbotaActivation']

const REFERENCE_REGEX = /^B\/(?:[0-9][A-Z][0-9A-Z]*|[A-Z][0-9A-Z]*)-[0-9]{4,}$/i

/// The prefix a station's bunkers carry — "B/G" for an English call, "B/US"
/// for a US one — read off the loaded list, since the country segment only
/// MOSTLY follows the DXCC entity prefix (Canada is "CA", Italy "IT"). The
/// hunting control follows the OTHER station, the activation control our own;
/// a call nobody can place gets the program's home "B/G".
async function defaultPrefix(operation: Record<string, unknown>, qso: Record<string, unknown> | undefined): Promise<string> {
  const theirCall = (qso?.their as Record<string, unknown> | undefined)?.call as string | undefined
  const entityPrefix = entityPrefixForCall(theirCall) ?? entityPrefixForCall(operation.stationCall as string | undefined)
  if (!entityPrefix) return 'B/G'
  return learnedReferencePrefix('wwbota', entityPrefix, `B/${entityPrefix}`)
}

/// Live-typing reformatting, after app-polo's WWBOTAInput chain: a bare
/// number takes the default prefix ("0001" -> "B/G-0001"), a country segment
/// typed without its scheme gets it ("G-" -> "B/G-"), and a run-on reference
/// gets its dash and scheme ("G0001" / "B/G0001" -> "B/G-0001").
///
/// Every bunker number is exactly four digits, and the dash waits for the
/// fourth: a country segment can END in a digit ("E7", "S5", "Z3"), so an
/// earlier dash would split "E7" while it is still being typed. Even so,
/// "E7000" reads as "E" plus four digits until the fifth arrives, which is
/// what the last rule is for: five digits after a letter-only segment mean
/// the first was the segment's, and the dash moves.
export function transformsForPrefix(prefix: string): RefTransform[] {
  return [
    { pattern: '(^|,\\s*)(\\d\\d+)', replacement: `\${1}${prefix}-\${2}`, flags: 'gi' },
    { pattern: '(^|,\\s*)(?!B/)([0-9]?[A-Z]+[0-9]?)-', replacement: '${1}B/${2}-', flags: 'gi' },
    { pattern: '(?<![A-Z0-9/])(?:B/)?([0-9]?[A-Z]+[0-9]?)(\\d{4})(?!\\d)', replacement: 'B/${1}-${2}', flags: 'gi' },
    { pattern: 'B/([0-9]?[A-Z]+)-(\\d)(\\d{4})(?!\\d)', replacement: 'B/${1}${2}-${3}', flags: 'gi' },
    { pattern: '[^A-Z0-9/\\-, ]', replacement: '', flags: 'gi' },
  ]
}

const API_BASE = 'https://api.wwbota.org'

/// Slovenia and North Macedonia ask 10 contacts; everywhere else asks 25. The
/// country is the second segment of the reference (`B/S5-0001`).
///
/// Upper-cased here rather than trusted: the scorer reads refs off the
/// operation verbatim, so this depends on whatever wrote them having
/// normalised. Getting it wrong is silent — a Slovenian activator would simply
/// be shown 25 instead of 10, with no error to notice.
function bunkerThreshold(refs: string[]): number {
  return Math.max(
    ...refs.map((ref) => (['S5', 'Z3'].includes(ref.toUpperCase().split(/[/-]/)[1]) ? 10 : 25)),
  )
}

/// A repeat contact is a duplicate on the same band and day. Unlike MOTA and
/// SiOTA, a bunker the station hasn't given before DOES advance the activation
/// as well as earning the bunker-to-bunker credit.
const WWBOTA_SCORING = {
  label: 'WWBOTA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  allowsMultipleReferences: true,
  qsosToActivate: bunkerThreshold,
  uniquePer: ['band', 'day', 'ref'] as const,
  activates: 'once' as const,
  refNoun: (ctx: HookContext) => tFor(ctx)('bunker'),
  refNounPlural: (ctx: HookContext) => tFor(ctx)('bunkersPlural'),
  p2pLabel: (ctx: HookContext) => tFor(ctx)('b2b'),
}

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'wwbota',
  label: 'WWBOTA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'B/G-0001',
  refInput: async ({ operation, qso, side }) => {
    const prefix = await defaultPrefix(operation, side === 'hunting' ? qso : undefined)
    return { placeholder: `${prefix}-...`, transforms: transformsForPrefix(prefix) }
  },
  tFor,
  // app-polo names every hunted bunker in a single record's SIG_INFO.
  splitRecordsPerHuntedRef: false,
  // Derived from the scorer's own rule, not a separate flag — the UI control
  // and the scorer can't disagree about whether this award allows n-fers.
  allowsMultiple: WWBOTA_SCORING.allowsMultipleReferences,
})

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

interface WWBOTAApiSpot {
  call: string
  /// MHz, unlike most spot feeds.
  freq: number
  mode?: string
  time: string
  type?: string
  comment?: string
  spotter?: string
  references: { reference: string }[]
}

const SpotsHook = {
  sourceName: 'WWBOTA',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    const response = await host.fetch(`${API_BASE}/spots/`, { headers: { Accept: 'application/json' } })
    if (response.status !== 200) throw new Error(`WWBOTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as WWBOTAApiSpot[]

    return apiSpots.map((spot) => {
      const references = spot.references ?? []
      // Frequencies arrive in MHz; the rest of HaLo works in kHz.
      const freq = Number(spot.freq)
      const freqKHz = freq ? freq * 1000 : undefined
      // One bunker is worth naming; several are only worth listing, since the
      // names would not fit and app-polo makes the same call.
      const label = references.length === 1
        ? references[0].reference
        : references.map((r) => r.reference).join(' ')

      // Only what the feed actually supplied — `sourceInfo` is a JSON map, and
      // an absent field belongs absent rather than set to undefined.
      const sourceInfo: Record<string, JSONValue> = {}
      if (spot.type != null) sourceInfo.type = spot.type
      if (spot.comment != null) sourceInfo.comments = spot.comment
      if (spot.spotter != null) sourceInfo.spotter = spot.spotter

      return {
        their: { call: (spot.call ?? '').toUpperCase() },
        freq: freqKHz,
        band: freqKHz ? bandForFrequency(freqKHz) : undefined,
        mode: spot.mode?.toUpperCase(),
        refs: references.map((r) => ({ ref: r.reference, type: HUNTING_TYPE })),
        spot: {
          timeInMillis: Date.parse(spot.time),
          source: 'wwbota',
          label,
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
    if (refs.length === 0) return { ok: false, message: 'No WWBOTA activation on this operation' }
    const call = String(operation.stationCall ?? '').trim()
    if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
    return postSpotToWWBOTA({ call, refs, freq, mode, comment, spotterCall: call })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No WWBOTA reference on this QSO' }
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
    return postSpotToWWBOTA({
      call,
      refs,
      freq,
      mode: qso.mode ? String(qso.mode) : undefined,
      comment,
      spotterCall: String(our.call ?? '').trim() || String(spotterCall ?? '').trim() || undefined,
    })
  },
}

/// The references go in the COMMENT, not in a field of their own — the spot
/// endpoint takes a single flat record. They are grouped by scheme so a
/// multi-bunker spot reads `B/G-0001,0002` rather than repeating the prefix,
/// which is what the award's own tooling expects to parse back out.
function referenceComment(refs: Ref[], comment?: string): string {
  const byScheme = new Map<string, string[]>()
  for (const ref of refs) {
    const [scheme, number] = (ref.ref ?? '').split('-')
    if (!scheme || !number) continue
    const numbers = byScheme.get(scheme)
    if (numbers) numbers.push(number)
    else byScheme.set(scheme, [number])
  }
  const grouped = [...byScheme.entries()].map(([scheme, nums]) => `${scheme}-${nums.join(',')}`).join(' ')
  return [grouped, comment].filter((part) => part).join(' ')
}

/// One flat record, frequency in MHz, and no credentials — WWBOTA's spot API is
/// open. `type` tells the feed whether the operator is on the air or done;
/// app-polo reads it out of the comment and so do we.
async function postSpotToWWBOTA(
  { call, refs, freq, mode, comment, spotterCall }: {
    call: string
    refs: Ref[]
    freq: number
    mode?: string
    comment?: string
    spotterCall?: string
  },
): Promise<PostResult> {
  try {
    const response = await host.fetch(`${API_BASE}/spots/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        // Omitted rather than guessed when we have none: an in-progress QSO has
        // no `our.call` yet, and sending the SPOTTED station as its own spotter
        // would be a plain lie.
        ...(spotterCall ? { spotter: spotterCall } : {}),
        call,
        freq: freq / 1000,
        // Null, not a guess: the feed would rather know the mode is unknown
        // than be told SSB.
        mode: mode || null,
        comment: referenceComment(refs, comment),
        type: /QRT/i.test(comment ?? '') ? 'QRT' : 'Live',
      }),
    })
    if (response.status !== 200 && response.status !== 201) {
      return { ok: false, message: `WWBOTA API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

const wwbotaDataFile: DataFileDefinition = {
  key: 'wwbota-all-bunkers',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: `${API_BASE}/bunkers/?format=CSV`,
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'wwbota',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    const ref = (r.Reference ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.Lat)
    const parsedLon = Number.parseFloat(r.Long)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon

    // The column is `Maidenhead` in some exports and `Locator` in others.
    const published = (r.Maidenhead || r.Locator || '').trim()
    const grid = published ? published.replace(/[A-Z]{2}$/, (x) => x.toLowerCase()) : undefined

    // The DXCC code is authoritative; the reference's own country segment
    // (`B/G-0001` → `G`) is the fallback when the list omits it.
    const dxccCode = Number.parseInt(r.DXCC, 10)
    const entityPrefix = DXCC_BY_CODE[dxccCode]?.entityPrefix ?? ref.split('-')[0].split('/')[1]

    return {
      subCategory: entityPrefix,
      key: ref,
      name: r.Name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: r.Name,
        type: r.Type,
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
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'wwbota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'wwbota' })
    // Logs synced from app-polo still carry the pre-worldwide types.
    for (const type of LEGACY_TYPES) {
      registerHook(`ref:${type}`, { hook: refHandler, key: 'wwbota' })
    }
    registerHook('activity', { hook: activityHook, key: 'wwbota' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'wwbota' })
    registerHook('adifImport', { hook: adifImportHook, key: 'wwbota' })
    registerHook('spots', { hook: SpotsHook, key: 'wwbota' })
    registerHook('dataFile', { hook: wwbotaDataFile, key: 'wwbota-all-bunkers' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(WWBOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'wwbota',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'wwbota', label: 'WWBOTA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'wwbota',
    })
    // The chaser side: every reference hunted, across the whole log — a
    // different key so it doesn't collide with the activator registration
    // above.
    registerHook('export', {
      hook: huntingExportHook({ key: 'wwbota', label: 'WWBOTA', huntingType: HUNTING_TYPE, activationType: ACTIVATION_TYPE, icon: manifest.icon, color: manifest.accentColor }),
      key: 'wwbota-hunter',
    })
  },
})
