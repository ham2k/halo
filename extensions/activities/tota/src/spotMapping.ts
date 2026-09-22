// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// TOTA cluster spot mapping — pulled out of index.ts so it can be unit-tested
// directly (see spotMapping.test.ts). `@ham2k/extension-sdk` is a tsc-only
// path alias (see extensions/tsconfig.json) that Node's own module resolver,
// used by `node --test`, can't resolve at runtime — so this file may import
// types from it, which type stripping erases, but never values.

import { bandForFrequency } from "@ham2k/lib-operation-data"

import type { Spot } from "@ham2k/extension-sdk"

/// A spot as `rozhledny.eu/apidata/cluster.php` returns it, inside a
/// `{api, version, generated_utc, count, spots, error}` envelope. The feed has
/// no status field: QRT lives in the operator's own comment.
export interface TOTAApiSpot {
  callsign?: string
  tower_ref?: string
  frequency?: number | string
  mode?: string
  time_utc?: string
  comment?: string
  spotter?: string
}

const QRT_COMMENT = /QRT/i

/// [spots] for the board, and how many rows were dropped for a `time_utc`
/// nothing could read — the caller logs that, because a count nobody sees is
/// how a whole dead board passes for a quiet one.
export interface TOTASpotMapping {
  spots: Spot[]
  undated: number
}

/// The newest spot per station, mapped for the spots board.
///
/// A QRT claims its operator's slot without taking it: a station that has said
/// it is done must not come back to the board from an earlier spot. That only
/// holds if the newest spot is the one considered, which is why the order is
/// established here rather than assumed of the feed — nothing in the payload
/// promises one, and a feed handed over oldest-first would silently invert the
/// rule, leaving a packed-up station calling. The feed stamps to the second,
/// so a QRT posted in the same second as the spot it retracts needs the
/// tiebreaker too — without it that pair falls back to the feed order this
/// sort exists to stop depending on.
///
/// Nothing is aged out here. app-polo cuts the feed at an hour, but HaLo's own
/// `SpotsService.maxSpotAge` and the panel's age filter already govern every
/// source together — a cutoff of our own would retire a TOTA spot while a POTA
/// one posted at the same moment stayed, and leave TOTA contributing nothing
/// to the age filter's own longest bucket.
///
/// A spot whose `time_utc` will not parse is dropped: an unranked entry would
/// beat the QRT that followed it, and `spotsForCall` reads an absent time as
/// the epoch and would drop it from call lookup anyway, leaving it half on the
/// board. Counted rather than passed over, so a wire format that moves under
/// us empties the board loudly.
export function spotsFromTOTAApi(apiSpots: TOTAApiSpot[]): TOTASpotMapping {
  const dated = apiSpots
    .filter((spot) => spot)
    .map((spot) => ({
      spot,
      timeInMillis: Date.parse(spot.time_utc ?? ""),
      isQrt: QRT_COMMENT.test(spot.comment ?? ""),
    }))
  const undated = dated.filter(({ timeInMillis }) => Number.isNaN(timeInMillis)).length

  const newestFirst = dated
    .filter(({ timeInMillis }) => !Number.isNaN(timeInMillis))
    .sort((a, b) => b.timeInMillis - a.timeInMillis || Number(b.isQrt) - Number(a.isQrt))

  const spots: Spot[] = []
  const claimedCalls = new Set<string>()
  for (const { spot, timeInMillis, isQrt } of newestFirst) {
    // A row naming no station is dropped outright rather than deduped: it
    // would publish a blank entry to the board and then claim the empty-string
    // slot, silently swallowing every other call-less row behind it.
    const call = (spot.callsign ?? "").toUpperCase()
    if (!call) continue
    if (claimedCalls.has(call)) continue
    claimedCalls.add(call)
    if (isQrt) continue

    const parsed = typeof spot.frequency === "string" ? Number.parseFloat(spot.frequency) : spot.frequency
    const freq = parsed && !Number.isNaN(parsed) ? parsed : undefined
    const sourceInfo: Record<string, string> = {}
    if (spot.comment != null) sourceInfo.comments = spot.comment
    if (spot.spotter != null) sourceInfo.spotter = spot.spotter

    spots.push({
      their: { call },
      freq,
      band: freq ? bandForFrequency(freq) : undefined,
      mode: spot.mode?.toUpperCase(),
      // 'tota' is index.ts's HUNTING_TYPE; it can't be imported from there
      // without a cycle, and it's the extension key, so it doesn't drift.
      refs: spot.tower_ref ? [{ ref: spot.tower_ref, type: "tota" }] : [],
      spot: {
        timeInMillis,
        source: "tota",
        // The tower's NAME comes from the local list, which the spots panel
        // resolves from the ref — app-polo looks it up here, but that is a
        // database round trip per spot.
        label: spot.tower_ref ?? "",
        sourceInfo,
      },
    })
  }

  return { spots, undated }
}
