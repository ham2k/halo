// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SOTAwatch spot mapping — pulled out of index.ts so it can be unit-tested
// directly (see spotMapping.test.ts). `@ham2k/extension-sdk` is a
// tsc-only path alias (see extensions/tsconfig.json) that Node's own module
// resolver, used by `node --test`, can't resolve at runtime — so this file
// may import types from it, which type stripping erases, but never values.

import { bandForFrequency } from "@ham2k/lib-operation-data"

import type { Spot } from "@ham2k/extension-sdk"

/// A spot as `api-db2.sota.org.uk` returns it. Three fields differ from the
/// retired api2 shape and each one is silently wrong rather than absent if
/// treated the old way: `frequency` is a number in **MHz** (api2 sent a
/// string), `summitCode` is the **whole** reference (api2 split the
/// association code into its own field), and `timeStamp` carries its `Z`.
export interface SOTAApiSpot {
  id: number
  timeStamp: string
  comments: string | null
  callsign: string
  summitCode: string
  summitName: string
  activatorCallsign: string
  activatorName: string
  frequency: number
  mode: string
  points: number
  AltM: number
  AltFt: number
  /// 'NORMAL', 'QRT' or 'TEST'; null on spots posted by clients that don't
  /// set it, which means NORMAL.
  type: string | null
  epoch: string
}

/// U+278A-U+2793: Dingbat Negative Circled Sans-Serif Digits One-Ten — the
/// same glyph scheme app-polo uses for SOTA spot points. Summits only ever
/// score 1-10, matching that block, so anything outside it isn't a real value.
export function summitGlyphForPoints(points: number | undefined): string {
  return points && points >= 1 && points <= 10 ? String.fromCodePoint(10121 + points) : ""
}

function spotType(spot: SOTAApiSpot): string {
  // Most spotters never set the field, and an unset type is a normal spot.
  return (spot.type ?? "").toUpperCase() || "NORMAL"
}

/// api-db2 sends the `Z`; the fallback covers the naive timestamp the field
/// has historically arrived as. Both the dedupe's sort and the mapped spot
/// must read a timestamp the same way — parsing a mixed payload two ways
/// ranks a naive row hours off a UTC one, which is enough to put an older
/// NORMAL above the QRT that followed it.
function timeOf(spot: SOTAApiSpot): number {
  return Date.parse(spot.timeStamp.endsWith("Z") ? spot.timeStamp : spot.timeStamp + "Z")
}

/// The newest spot per activator, mapped for the spots board.
///
/// The two non-NORMAL types drop out on either side of the dedupe, and the
/// order is the whole of their meaning:
///   - TEST goes first, so it is invisible rather than merely unshown. It
///     says nothing about the activator, and surviving the dedupe would let
///     a test post erase that operator's live spot from the board.
///   - QRT goes last, so it wins the dedupe and takes the activator's
///     earlier NORMAL spot with it. Dropping it first would leave a station
///     that has packed up sitting on the board as if it were still calling.
///
/// Newest-first is established here rather than assumed of the feed. The API
/// happens to send it that way, but nothing in the payload promises it, and
/// an out-of-order feed would silently invert the QRT rule — a stale NORMAL
/// row beating the QRT that followed it. `id` breaks ties, because two spots
/// sharing a timestamp would otherwise fall back to that same feed order.
export function spotsFromSOTAApi(apiSpots: SOTAApiSpot[]): Spot[] {
  const newestFirst = apiSpots.filter((spot) => spotType(spot) !== "TEST").sort((a, b) => timeOf(b) - timeOf(a) || b.id - a.id)

  const newestPerCall: SOTAApiSpot[] = []
  const includedCalls = new Set<string>()
  for (const spot of newestFirst) {
    const call = (spot.activatorCallsign ?? "").toUpperCase()
    if (call && !includedCalls.has(call)) {
      includedCalls.add(call)
      newestPerCall.push(spot)
    }
  }

  return (
    newestPerCall
      // An allowlist, not `!== 'QRT'`: `spotType` already reads an unset type
      // as NORMAL, so the two agree on today's payload, but a type SOTA adds
      // later — a soft-delete marker, say — would render as a live spot under
      // a denylist. Dropping what we don't understand claims less.
      .filter((spot) => spotType(spot) === "NORMAL")
      .map((spot) => {
        const freq = Number(spot.frequency) * 1000 // MHz -> kHz
        const ref = (spot.summitCode ?? "").toUpperCase()
        const glyph = summitGlyphForPoints(spot.points)
        const summit = [spot.summitName, spot.AltM ? `${spot.AltM}m` : ""].filter((x) => x).join(", ")
        return {
          their: { call: spot.activatorCallsign },
          freq: freq || undefined,
          band: freq ? bandForFrequency(freq) : undefined,
          mode: spot.mode ? spot.mode.toUpperCase() : undefined,
          // 'sota' is index.ts's HUNTING_TYPE; it can't be imported from there
          // without a cycle, and it's the extension key, so it doesn't drift.
          refs: [{ ref, type: "sota" }],
          icon: "image-filter-hdr",
          spot: {
            timeInMillis: timeOf(spot),
            source: "sota",
            label: `${glyph ? glyph + " " : ""}${ref}: ${summit}`,
            sourceInfo: {
              id: spot.id,
              comments: spot.comments ?? "",
              spotter: spot.callsign,
            },
          },
        }
      })
  )
}
