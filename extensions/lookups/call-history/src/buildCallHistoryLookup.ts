// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import type { CallInfoLookup, JSONValue } from "@ham2k/extension-sdk"

/// Fields describing the station itself, not the contact it rode in on —
/// a past QSO's `exchange`/`sent`/`notes`/`refs` belong to that QSO, and
/// would be wrong to carry into an unrelated later contact (e.g. an old
/// contest exchange, or a park worked once).
///
/// `locSource` is deliberately excluded, same as `annotate.ts`'s offline
/// pre-step: a stale provenance tag from the past QSO describes where THAT
/// contact's location came from, and carrying it forward would label this
/// contact's location with a source that never answered for it.
const LOCATION_FIELDS = [
  'city',
  'state',
  'county',
  'country',
  'grid',
  'lat',
  'lon',
  'cqZone',
  'ituZone',
  'entityPrefix',
  'entityName',
  'dxccCode',
  'continent',
] as const

/// The two results [buildCallHistoryTiers] produces. Both ride the single
/// lowest-priority `lookup` registration (see index.ts) — the log never
/// outranks a live source — and they are field-disjoint, since [pick]
/// assigns each field to exactly one tier. What the split still buys is the
/// distinct `source` label below: whether a field the log carried forward
/// was one the operator TYPED on the past QSO or one that was only ever a
/// GUESS on it, which the operator reads and the queue's degradation guard
/// compares.
export type CallHistoryTiers = { manual: CallInfoLookup[]; guessed: CallInfoLookup[] }

function hasValue(value: unknown): boolean {
  return value !== undefined && value !== null && value !== ''
}

/// [their]'s own value for [field] if it was actually typed, else the merged
/// `their.guess`'s value, tagged with which one answered.
function pick(
  their: Record<string, JSONValue>,
  guess: Record<string, JSONValue>,
  field: string,
): { value: JSONValue; tier: keyof CallHistoryTiers } | undefined {
  if (hasValue(their[field])) return { value: their[field], tier: 'manual' }
  if (hasValue(guess[field])) return { value: guess[field], tier: 'guessed' }
  return undefined
}

/// Combines two `getHistoryForCall` results — the composed call's own
/// history and, when it differs, its base call's (`index.ts`'s `KI2D/P` →
/// also search `KI2D`) — deduped by uuid (a QSO could in principle answer
/// both if `theirCall` ever equaled the base call exactly), most recent
/// first. [buildCallHistoryTiers] relies on that ordering to pick "the"
/// most recent match.
export function mergeHistory(
  a: Record<string, JSONValue>[],
  b: Record<string, JSONValue>[],
): Record<string, JSONValue>[] {
  if (b.length === 0) return a
  const seen = new Set<JSONValue>()
  const merged = [...a, ...b].filter((qso) => {
    if (qso.uuid == null) return true
    if (seen.has(qso.uuid)) return false
    seen.add(qso.uuid)
    return true
  })
  merged.sort((x, y) => (Number(y.startAtMillis) || 0) - (Number(x.startAtMillis) || 0))
  return merged
}

/// Builds the "Call History" tiers from a station's past QSOs (already
/// matched on `theirCall`/`baseCall`, most recent first). Both come back
/// empty when there's nothing to offer — no history, or the only match is
/// the QSO being looked up itself.
///
/// [call] is the call being COMPOSED — usually every match's own `their.call`
/// too, but a caller may widen the search to a base call (`index.ts`, for
/// `KI2D/P` finding `KI2D`'s history), in which case a match found only that
/// way can still name the station but must not describe where THIS variant
/// is operating from.
///
/// [currentQsoUuid] excludes that QSO from its own history — the background
/// queue re-enriches already-saved QSOs, and without this a QSO with no
/// *other* history would echo its own guess back as "Call History".
export function buildCallHistoryTiers(
  call: string,
  history: Record<string, JSONValue>[],
  currentQsoUuid?: string,
): CallHistoryTiers {
  const past = history.filter((qso) => !currentQsoUuid || qso.uuid !== currentQsoUuid)
  if (past.length === 0) return { manual: [], guessed: [] }

  const mostRecent = (past[0].their as Record<string, JSONValue>) ?? {}
  const guess = (mostRecent.guess as Record<string, JSONValue>) ?? {}

  const fields: Record<keyof CallHistoryTiers, Record<string, JSONValue>> = { manual: {}, guessed: {} }
  let locationScope: JSONValue | undefined

  const name = pick(mostRecent, guess, 'name')
  if (name) fields[name.tier].name = name.value

  // The station's photo, remembered from the last time they were worked. It
  // rides the GUESSED tier (nobody types a photo URL). Safe to carry because
  // every live source outranks this one, so a profile picture that changed is
  // not frozen at whatever URL this QSO happened to store, while a call worked
  // before still shows a face with no network at all. Not tied to
  // the location rules below — a photo describes the operator, not where this
  // variant of their call is operating from today.
  const image = pick(mostRecent, guess, 'image')
  if (image) fields[image.tier].image = image.value

  // A location logged during a POTA/SOTA activation (or any other portable
  // op) is the park/summit, not the station's home QTH — carrying it forward
  // would show that temporary location as if it were permanent. And a match
  // found only via the base-call widening above is a different variant of
  // the same station — its OWN location (portable, DX-prefixed, home,
  // whatever it was) says nothing about where the call being composed now
  // is operating from.
  const isPortableGuess = guess.locationScope === 'portable' || guess.locationScope === 'prefixed'
  const isExactCallMatch = typeof mostRecent.call === 'string' && mostRecent.call.toUpperCase() === call
  // A `locSource: 'prefix'` pair is lib-country-files' DXCC centroid, carrying
  // cty.dat's west-positive longitude — never the station. Carrying it forward
  // would re-issue a mirrored coordinate on a NEW contact, and issue it
  // untagged, past the rule that refuses it on the QSO it came from
  // (halo_core's `locationFromGuess`; `locSource` itself is excluded above).
  // `entityPrefix` still rides along, and the centroid is resolved from it at
  // read time, correctly signed.
  const isCentroid = (info: Record<string, JSONValue>) => info.locSource === 'prefix'
  // Every location field this QSO contributes travels in ONE result, and the
  // tier is decided for the group rather than per field. `mergeLookupIntoGuess`
  // reconciles grid against city/state/country by DELETING whichever of them
  // the result being folded did not itself write — so a station's location
  // split across two results has the second clear the first's half of it, and
  // the operator's typed city or grid is exactly what disappears. Splitting a
  // name from a grid is safe; splitting a location is not.
  //
  // Any typed member makes the whole group typed: a hand-corrected field is
  // what the `Call History` label is FOR, and a group carrying one has been
  // verified by a human at least in part.
  if (!isPortableGuess && isExactCallMatch) {
    const location: Record<string, JSONValue> = {}
    let locationTier: keyof CallHistoryTiers = 'guessed'
    for (const field of LOCATION_FIELDS) {
      const picked = pick(mostRecent, guess, field)
      if (!picked) continue
      if ((field === 'lat' || field === 'lon') && isCentroid(picked.tier === 'manual' ? mostRecent : guess)) continue
      location[field] = picked.value
      if (picked.tier === 'manual') locationTier = 'manual'
    }
    Object.assign(fields[locationTier], location)
    if (typeof guess.locationScope === 'string') locationScope = guess.locationScope
  }

  // NOT `history: past` — a lookup result's `history` rides through the
  // merge pipeline unconditionally (mergeLookup.ts) and gets PERSISTED onto
  // the QSO (lookup_queue_service.dart writes `lookups` straight to
  // `their.lookups`). Each past QSO's own `their.lookups` can itself carry a
  // Call History entry, so populating `history` here would compound on every
  // repeat contact — a station worked ten times would store roughly the sum
  // of all nine earlier records. Nothing reads this field today; add it back
  // trimmed to a handful of scalars (uuid/operation/startAtMillis/band/mode)
  // if a "worked before" surface ever needs it.
  const tiers: CallHistoryTiers = { manual: [], guessed: [] }
  for (const tier of ['manual', 'guessed'] as const) {
    if (Object.keys(fields[tier]).length === 0) continue
    const lookup: CallInfoLookup & Record<string, JSONValue> = {
      call,
      // Distinct per tier — NOT both "Call History". `lookup_queue_service
      // .dart`'s degradation guard compares stored vs fresh `source` SETS to
      // decide whether a re-enrichment is safe to write; two entries with
      // the identical label would make a manually-verified field silently
      // replaceable by a guessed one, since "Call History answered before"
      // and "Call History answered again" would look the same regardless of
      // which tier actually did.
      source: tier === 'manual' ? 'Call History' : 'Call History (guess)',
      scope: 'general',
      ...fields[tier],
    }
    if (LOCATION_FIELDS.some((f) => f in fields[tier])) {
      // Stated, never left undefined — `mergeLookupIntoGuess`'s scope
      // comparisons all short-circuit on a null scope. A past QSO predating
      // the annotation pre-step carries no `guess.locationScope`, and 'qth'
      // is what the guard above already established to get here: a
      // non-portable, exact-call match is the station's own QTH.
      lookup.locationScope = (locationScope ?? 'qth') as CallInfoLookup['locationScope']
    }
    tiers[tier] = [lookup]
  }
  return tiers
}
