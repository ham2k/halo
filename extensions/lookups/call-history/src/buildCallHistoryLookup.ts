// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import type { CallInfoLookup, JSONValue } from "@ham2k/halo-extension-sdk"

/// Fields describing the station itself, not the contact it rode in on —
/// a past QSO's `exchange`/`sent`/`notes`/`refs` belong to that QSO, and
/// would be wrong to carry into an unrelated later contact (e.g. an old
/// contest exchange, or a park worked once).
///
/// `locSource` is deliberately excluded, same as `annotate.ts`'s offline
/// pre-step: at priority 150 a stale provenance tag from the past QSO would
/// block whichever source actually resolves the CURRENT location from
/// recording where its own data came from.
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

/// The two results [buildCallHistoryTiers] produces, fed to two differently
/// -prioritized `lookup` hook registrations (see index.ts) so they compete
/// against other sources on their own merits: a field the operator actually
/// TYPED on the past QSO outranks a live QRZ/Ham2K Lookup answer (they
/// verified it themselves), while a field that was only ever a GUESS on
/// that QSO — never typed, so never verified — stays lowest priority and
/// only fills a gap no live source answered. Both distinctions collapse to
/// one field-level split, since one past QSO can carry a manually-corrected
/// name alongside a merely-guessed grid.
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

  // A location logged during a POTA/SOTA activation (or any other portable
  // op) is the park/summit, not the station's home QTH — carrying it forward
  // would show that temporary location as if it were permanent. And a match
  // found only via the base-call widening above is a different variant of
  // the same station — its OWN location (portable, DX-prefixed, home,
  // whatever it was) says nothing about where the call being composed now
  // is operating from.
  const isPortableGuess = guess.locationScope === 'portable' || guess.locationScope === 'prefixed'
  const isExactCallMatch = typeof mostRecent.call === 'string' && mostRecent.call.toUpperCase() === call
  if (!isPortableGuess && isExactCallMatch) {
    for (const field of LOCATION_FIELDS) {
      const picked = pick(mostRecent, guess, field)
      if (picked) fields[picked.tier][field] = picked.value
    }
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
    if (locationScope !== undefined && LOCATION_FIELDS.some((f) => f in fields[tier])) {
      lookup.locationScope = locationScope as CallInfoLookup['locationScope']
    }
    tiers[tier] = [lookup]
  }
  return tiers
}
