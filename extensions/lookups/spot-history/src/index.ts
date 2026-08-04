// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { AnnotatedCallInfo, HookContext, JSONValue, LookupResult, RefInfo } from "@ham2k/halo-extension-sdk"

import { collectRefsFromSpots } from "./collectRefs.ts"

import manifest from "../manifest.json" with { type: "json" }

/// How recently a station must have been spotted for its references to still
/// describe where it is. Long enough to cover an activator spotted once at
/// the start of a run, short enough that a park they have since left doesn't
/// end up in the log.
const MAX_SPOT_AGE_MINUTES = 30

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // `recentContextLookup`, not `lookup`: a spot describes what a station
    // is doing right now, which is only meaningful for a contact being
    // composed. Registering as an ordinary lookup would also fire this for
    // every callsign on the spots board and for every saved QSO the
    // background queue re-enriches — answers nobody wants and nobody reads.
    registerHook('recentContextLookup', { hook: { lookupCall }, priority: 0 })
  },
})

/// Collects the activity references carried by recent spots for this call.
///
/// Deliberately offline-agnostic — it reads the host's already-fetched spot
/// cache, so it contributes on the fast offline pass too rather than making
/// the operator wait for the network pass to see a park appear.
async function lookupCall(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.getSpotsForCall) return []

  const spots = await ctx.getSpotsForCall(call, MAX_SPOT_AGE_MINUTES)
  if (!spots?.length) return []

  const existingTypes = ((qso?.refs as RefInfo[] | undefined) ?? [])
    .map((ref) => ref?.type)
    .filter((type): type is string => !!type)

  const refs = collectRefsFromSpots(spots, existingTypes)
  if (refs.length === 0) return []

  return [{ call, source: 'Spot History', refs }]
}
