// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA (Parks on the Air) — the archetype activity extension. Registers:
//   ref:pota / ref:potaActivation  — validation + park decoration via API
//   activity                       — declarative logging + operation controls
//   adifFields                     — SIG/POTA_REF contributions for exports
//   adifImport                     — the same fields read back on import
//   spots                          — POTA.app spots source
//   dataFile                       — CSV database download and offline caching
// Ref types follow app-polo's QSON convention: 'pota' for hunting,
// 'potaActivation' for activating.

import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { locationToGrid6, distanceOnEarth } from "@ham2k/lib-geo-tools"
import { activityAdifImport, activityExportHook, activityScorer, applyLatLonFromApiFields, contestScorer, defineExtension, host, huntingExportHook, isTestOperation, looksLikeReference, LOCATION_ACCURACY } from "@ham2k/extension-sdk"
import type {
  AnnotatedCallInfo,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  LookupResult,
  Ref,
  RefLink,
  Spot,
  SpotEligibility,
  PostResult,
  PostSelfSpotRequest,
  PostOtherSpotRequest,
  DataFileDefinition,
  SuggestArgs,
  ActivitySuggestion,
  LookupRow,
  TitleSuggestion,
} from "@ham2k/extension-sdk"
import { REFERENCE_REGEX, normalizeReference, entityPrefixForCall, transformsForPrefix, hunterDefaultPrefix, activationDefaultPrefix } from "./refFormatting.ts"
import { suggestOperationTitleForPota } from "./titleSuggestion.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

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
  /// The park's own coordinate — tighter than decoding `grid6`. Populated
  /// from the offline table's `lat`/`lon` columns, or bridged from the live
  /// API's `latitude`/`longitude` fields (see the network branch below).
  lat?: number
  lon?: number
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
        lat: row.lat,
        lon: row.lon,
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
      // The live API names these `latitude`/`longitude` (matching the CSV
      // export's own columns), not this interface's `lat`/`lon` — bridged
      // here rather than renamed throughout, so the offline branch above
      // (which reads `row.lat`/`row.lon` straight off the LookupRow) doesn't
      // have to change shape too.
      applyLatLonFromApiFields(park, park as unknown as Record<string, unknown>)
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

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const reference = (ref.ref ?? '').toUpperCase().trim()
    // A reference that resolved to nothing keeps NONE of the old one's
    // decoration, whether it failed the pattern or merely isn't in the list.
    // `label`/`shortLabel` are what the activity row renders in preference to
    // the code itself, so a spread-through pair would show the previous park's
    // name over the new code — and `lat`/`lon` outrank a grid wherever a
    // location is read (docs/design/locations.md), so they would keep the
    // operation at a park it no longer references.
    const undecorated = (name: string): Ref => ({
      ...ref,
      ref: reference,
      name,
      label: undefined,
      shortLabel: undefined,
      grid: undefined,
      lat: undefined,
      lon: undefined,
      location: undefined,
      retired: undefined,
    })

    if (!REFERENCE_REGEX.test(reference)) return undecorated(t('invalidReference'))

    const park = await fetchPark(reference)
    if (!park?.name) return undecorated(t('unknownPark'))

    return {
      ...ref,
      ref: reference,
      name: park.name,
      grid: park.grid6,
      lat: park.lat,
      lon: park.lon,
      location: park.locationDesc,
      program: 'POTA',
      label: `POTA ${reference}: ${park.name}`,
      shortLabel: `POTA ${reference}`,
      // Set here as well as in `suggest`, and always to a boolean, so this is
      // a property of the PARK rather than of how the operator happened to
      // reach it. A code typed straight into the activation control never
      // passes through `suggest` at all, and would otherwise render unmarked
      // beside an identical park picked from the search. Writing it
      // unconditionally is also what lets a re-decoration CLEAR a stale mark
      // once POTA reinstates a park.
      retired: park.active === 0,
    }
  },

  async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
    return suggestOperationTitleForPota(ref, ACTIVATION_TYPE)
  },

  async linkForRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    const reference = (ref.ref ?? '').toUpperCase().trim()
    if (!REFERENCE_REGEX.test(reference)) return null
    return { url: `https://pota.app/#/park/${encodeURIComponent(reference)}` }
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
        color: manifest.accentColor,
        order: 10,
        optionType: 'optional',
        // POTA n-fers: one operation can activate several parks at once,
        // and a QSO can hunt several.
        allowsMultiple: true,
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
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    const prefix = activationDefaultPrefix(operation)
    return [
      {
        key: 'pota/activation',
        label: tFor(ctx)('activationControl'),
        icon: 'pine-tree',
        color: manifest.accentColor,
        order: 10,
        optionType: 'optional',
        // POTA n-fers: one operation can activate several parks at once,
        // and a QSO can hunt several.
        allowsMultiple: true,
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

  async suggest({ location, searchTerm, callsign, scoped }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
    // A name/code search spans every POTA park worldwide, so narrow it to
    // the caller's own DXCC entity when we can tell whose callsign this is
    // — nearby (location-based) results are already geographically scoped
    // by distance and shouldn't also be entity-restricted (a caller near a
    // border may well want a nearby park just across it). Passed INTO the
    // query itself, not filtered after: a common word ("trail") can match
    // thousands of rows worldwide, and the query only returns the first 100
    // it finds — filtering afterward can narrow an already-truncated 100 down
    // to zero even though a real match, in the caller's own country, exists.
    //
    // A park POTA has RETIRED (`active` 0 in the parks file, carried as the
    // row's `flags`) can no longer be activated, so it never belongs in a list
    // of parks to go operate. Excluded by `activeOnly`, and pushed into the
    // query for the same reason as above: POTA delists whole classes of park at
    // once, so a search for a word one of those classes shares could otherwise
    // fill all 100 rows with retired parks and leave the live ones past the
    // cap. A retired park the operator names EXACTLY is still offered, by the
    // fallback below.
    const callerEntity = searchTerm ? entityPrefixForCall(callsign) : undefined
    const rows: LookupRow[] = searchTerm
      ? await host.dbLookupSelectAll('pota', searchTerm, callerEntity, true)
      : location
        ? await host.dbLookupSelectByLocation('pota', location.lat, location.lon, NEARBY_DELTA, true)
        : []

    const withDistance = rows.map((row) => ({
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
        lat: row.lat,
        lon: row.lon,
        location: data.locationDesc,
        program: 'POTA',
        label: `POTA ${row.key}: ${row.name ?? ''}`,
        shortLabel: `POTA ${row.key}`,
        distance,
        relevance: relevanceForMatch(row, searchTerm),
        allowsMultiple: true,
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
    // A code the pattern REJECTS is offered too, but only when POTA alone was
    // asked (`pota: <code>`, or its row in Activity Types). The operator named
    // the program, so the one thing left in doubt is whether HaLo's idea of a
    // POTA reference is right — and a reference the app refuses to accept is
    // an activation the operator cannot log at all. Never on an unscoped
    // search, where every enabled program would answer any text at all with a
    // malformed reference of its own.
    // `looksLikeReference` is what keeps a NAME search out of it: `pota: bear`
    // is someone looking for a park called Bear, and must not also be offered
    // an invented BEAR park at the head of the list.
    const typedMalformed =
      scoped && searchTerm && looksLikeReference(searchTerm.toUpperCase().trim(), REFERENCE_REGEX)
        ? searchTerm.toUpperCase().trim()
        : ''
    const typedSearch = normalizedSearch ?? (typedMalformed || null)
    if (typedSearch && !suggestions.some((s) => s.ref === typedSearch)) {
      const isValidRef = normalizedSearch !== null
      const isTestRef = typedSearch.endsWith('-TEST')
      const t = tFor(ctx)
      // The row query above searched for the RAW text ("us1234"), which a
      // dashless/lowercase reference never matches — the local table's keys
      // are dashed and uppercase. Only normalizing found the well-formed
      // code, so it's worth one more exact lookup before settling for
      // "Unknown": [fetchPark] tries the local table again (this time by
      // the normalized key) and then the network, same as a real ref lookup
      // gets everywhere else.
      const resolved = isTestRef || !isValidRef ? null : await fetchPark(typedSearch)
      const name =
        resolved?.name || (!isValidRef ? t('invalidReference') : isTestRef ? t('testParkName') : t('unknownParkName'))
      // Naming a retired park exactly still offers it — marked, so the
      // operator learns WHY it was missing from the list rather than reading
      // its absence as a bad code. Carried as a flag for the picker to render,
      // never folded into `name`: this suggestion is stored on the operation
      // as it stands (see Ref.retired). Only an explicit 0 counts — a cached
      // park record may carry no `active` at all, and a missing value is not
      // evidence of retirement.
      const retired = resolved?.active === 0
      if (suggestions.length >= MAX_SUGGESTIONS) suggestions.pop()
      suggestions.unshift({
        type: ACTIVATION_TYPE,
        ref: typedSearch,
        name,
        grid: resolved?.grid6,
        lat: resolved?.lat,
        lon: resolved?.lon,
        location: resolved?.locationDesc,
        program: 'POTA',
        label: `POTA ${typedSearch}: ${name}`,
        shortLabel: `POTA ${typedSearch}`,
        relevance: 1,
        allowsMultiple: true,
        retired,
      })
    }

    return suggestions
  },
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

/// The synthetic park a Test Operation always spots under, replacing
/// whatever real activation refs the operation has — so a test spot never
/// reads as a real activation to a hunter, and testing the spotting flow
/// never needs a real park configured.
const TEST_OPERATION_REF: Ref = { type: ACTIVATION_TYPE, ref: 'K-TEST' }

/// A QSO-scoped grid lookup: any POTA park hunted on THIS qso is a more
/// specific ("portable") location than a callsign's registered home QTH —
/// same concept as a `/P` callsign. Returns the park's grid tagged
/// `REASONABLE` accuracy (a park can
/// be large, so its single-point grid may be off by a few grids); the merge
/// keeps whichever same-scope result is most accurate, so this doesn't have
/// to bail when a grid already exists — a more precise SOTA summit on the same
/// qso still wins. Skips when there's no POTA ref or
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

  /// A park-to-park contact with a station at several parks is submitted as one
  /// record PER hunted park — which is why it also counts once per park toward
  /// an activation (docs/design/activities.md §4). Each record names a single
  /// hunted park rather than the comma-joined list `fieldsForOneQSO` writes.
  ///
  /// The ACTIVATION side stays joined for now. app-polo names one park here
  /// because its POTA export offers one file per activated park and each file
  /// sees only its own ref; HaLo has no per-reference export slicing yet
  /// (§3.2/A4), so naming only the first would silently drop the others from
  /// an n-fer activation's export.
  async fieldCombinationsForOneQSO(
    { qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[][]> {
    const huntingRefs = refsOfType(qso, HUNTING_TYPE)
    const activationRefs = refsOfType(operation, ACTIVATION_TYPE)

    const activationFields: { name: string; value: string }[] = []
    if (activationRefs.length > 0) {
      activationFields.push({ name: 'MY_SIG', value: 'POTA' })
      activationFields.push({ name: 'MY_SIG_INFO', value: activationRefs[0].ref! })
      activationFields.push({ name: 'MY_POTA_REF', value: activationRefs.map((r) => r.ref).join(',') })
    }

    if (huntingRefs.length === 0) return [activationFields]

    return huntingRefs.map((ref) => [
      ...activationFields,
      { name: 'SIG', value: 'POTA' },
      { name: 'SIG_INFO', value: ref.ref! },
      { name: 'POTA_REF', value: ref.ref! },
    ])
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
    // A Test Operation always spots under K-TEST (see postSelfSpot), so the
    // option is offered even when the operation has no real POTA ref at all.
    if (isTestOperation(operation.stationCall)) return { enabled: true, icon: 'pine-tree' }
    return refsOfType(operation, ACTIVATION_TYPE).length > 0 ? { enabled: true, icon: 'pine-tree' } : { enabled: false }
  },

  async isOtherSpotEnabled({ qso }: { qso: Record<string, JSONValue> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(qso, HUNTING_TYPE).length > 0 ? { enabled: true, icon: 'pine-tree' } : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult> {
    const call = String(operation.stationCall ?? '')
    // K-TEST regardless of the operation's actual refs — see
    // TEST_OPERATION_REF's doc.
    const refs = isTestOperation(call) ? [TEST_OPERATION_REF] : refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No POTA activation on this operation' }
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
/// SOTA's spot API, which needs a logged-in account). Ported from
/// app-polo's POTAPostSpotAPI.js.
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
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
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
    // Only an explicit '0' retires a park. Reading anything-but-'1' as retired
    // would make every unexpected spelling of this column — a renamed header,
    // a quoted or padded value, a switch to 'true'/'Y' — mark the WHOLE file
    // retired on the next refresh, and `activeOnly` would then empty every
    // search and every nearby result with nothing to say why.
    const active = r.active !== '0'
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

/// POTA's award rules (docs/design/activities.md §4). A park is activated per
/// UTC day with ten contacts; n-fers mean one operation activates several parks
/// and one contact can hunt several. A repeat contact counts again on a new
/// day, band, mode, or park.
const POTA_SCORING = {
  label: 'POTA',
  icon: 'pine-tree',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 10,
  allowsMultipleReferences: true,
  uniquePer: ['band', 'mode', 'day', 'ref'] as const,
  activates: 'daily' as const,
  // Functions, not literals: "park"/"parks"/"P2P" are POTA's own vocabulary,
  // resolved through POTA's own translator at summarize time — a raw string
  // here would be untranslatable, since activityScoring.ts's catalog has no
  // way to know what a given activity calls its reference.
  refNoun: (ctx: HookContext) => tFor(ctx)('park'),
  refNounPlural: (ctx: HookContext) => tFor(ctx)('parksPlural'),
  p2pLabel: (ctx: HookContext) => tFor(ctx)('p2p'),
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: RefHandler, key: 'pota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: RefHandler, key: 'pota' })
    registerHook('activity', { hook: ActivityHook, key: 'pota' })
    registerHook('adifFields', { hook: AdifFieldsHook, key: 'pota' })
    // The inverse of the hook above: POTA_REF/MY_POTA_REF and the SIG pair
    // back into hunted and activated refs. `normalizeReference` REPAIRS a
    // dashless reference as well as rejecting a malformed one, so under
    // `SIG: POTA` a bare `12345` imports as `1-2345`; the SIG check is what
    // keeps that narrow.
    registerHook('adifImport', {
      hook: activityAdifImport({
        sig: 'POTA',
        huntingType: HUNTING_TYPE,
        activationType: ACTIVATION_TYPE,
        refField: 'pota_ref',
        // `normalizeReference` repairs what it can — it inserts the dash a
        // dashless `us1234` is missing — and answers null for what it cannot.
        // Null falls back to the raw text rather than dropping the reference:
        // the record already said this is POTA's, so a park that fails the
        // pattern is malformed rather than foreign, and it imports flagged as
        // invalid where the operator can correct it.
        normalize: (ref) => normalizeReference(ref) ?? ref.toUpperCase().trim(),
      }),
      key: 'pota',
    })
    registerHook('spots', { hook: SpotsHook, key: 'pota' })
    // Priority 100 — higher than every lookup source (QRZ 99, ...), so the
    // POTA park's grid is resolved BEFORE a home-QTH lookup can set
    // callInfo.grid; the `if (callInfo.grid) return []` guard below would
    // otherwise skip this hook once a lower-priority qth-scope grid was
    // already merged in.
    registerHook('lookup', { hook: { lookupCall }, key: 'pota', priority: 100 })
    registerHook('dataFile', { hook: potaDataFile, key: 'pota-all-parks' })
    // Scoped to the ref types rather than 'always': paying a full-log bridge
    // crossing per activity on every operation is what `scope` exists to avoid.
    // An operation that only HUNTS parks carries neither type on its own refs,
    // and still selects this scorer — the host matches the types found in the
    // log and in the work being scored as well (docs/design/activities.md §4).
    registerHook('scoring', {
      hook: contestScorer(activityScorer(POTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'pota',
    })
    // One submittable ADIF per activated park — an n-fer owes the program a log
    // for each (docs/design/activities.md §3.2).
    registerHook('export', {
      hook: activityExportHook({
        key: 'pota',
        label: 'POTA',
        activationType: ACTIVATION_TYPE,
        icon: 'pine-tree',
        // A park worked through a bird is still a park activation, and POTA's
        // uploader reads PROP_MODE/SAT_NAME — so the satellite's fields ride
        // along in this file even though it is POTA's log.
        includeFieldsFrom: ['satellites'],
      }),
      key: 'pota',
    })
    // The chaser side: every park hunted, across the whole log — a different
    // key so it doesn't collide with the activator registration above.
    registerHook('export', {
      hook: huntingExportHook({
        key: 'pota',
        label: 'POTA',
        huntingType: HUNTING_TYPE,
        activationType: ACTIVATION_TYPE,
        icon: 'pine-tree',
        color: manifest.accentColor,
        includeFieldsFrom: ['satellites'],
      }),
      key: 'pota-hunter',
    })
  },
})
