// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { defineExtension } from "@ham2k/extension-sdk"
import type { AnnotatedCallInfo, HookContext, JSONValue, LookupResult } from "@ham2k/extension-sdk"

import { buildCallHistoryTiers, mergeHistory } from "./buildCallHistoryLookup"
import type { CallHistoryTiers } from "./buildCallHistoryLookup"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // A `lookup` hook, not `recentContextLookup` — this answers "who is
    // this station" from the log itself, true for the background queue's
    // enrichment of an already-saved QSO too, not only a contact in
    // progress.
    //
    // Registered TWICE, at opposite ends of the priority range, because the
    // two tiers `buildCallHistoryTiers` produces deserve opposite trust: a
    // field the operator actually TYPED on the past QSO was verified by a
    // human and should win over a live QRZ/Ham2K Lookup answer, so it
    // registers ABOVE every other lookup source (qrz/pota/sota/call-notes
    // top out at 100). A field that was only ever a GUESS on that QSO —
    // never typed, never verified — stays at the bottom (below
    // ham2k-lookup's 10) and only fills a gap nothing else answered; a
    // stale automated guess must not outrank a fresh live lookup.
    registerHook('lookup', { hook: { lookupCall: lookupCallManual }, priority: 150 })
    registerHook('lookup', { hook: { lookupCall: lookupCallGuessed }, key: 'call-history_guessed', priority: 1 })
  },
})

async function historyTiers(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<CallHistoryTiers | null> {
  const call = (callInfo.call || '').trim().toUpperCase()
  if (call.length < 3 || !ctx.getHistoryForCall) return null

  // The manual/guessed registrations both call this independently — a
  // request-scoped cache would need something to key it on, and nothing
  // distinguishes "this lookup pass" from "a later, unrelated one for the
  // same call" (module state outlives any one pass). `getHistoryForCall`
  // is capped to a handful of rows host-side (extension_service.dart) for
  // exactly this reason: paying for a cheap, small read twice per pass is
  // fine; caching it wrong and serving stale history after new QSOs land
  // is not.
  // A portable/mobile/DX-prefixed call (`KI2D/P`, `F/KI2D`) is worked as
  // itself, but the station behind it is the same one worked plain — so its
  // history is worth searching too, same as PoLo's `findQSOHistory`
  // `baseCall` widening. `buildCallHistoryTiers` still gates location fields
  // on an EXACT call match (see there): a base-call match tells us who this
  // is, not where THIS variant is operating from.
  //
  // The two fetched in parallel — neither depends on the other's result,
  // and each is its own bridge round-trip.
  const baseCall = (callInfo.baseCall || '').trim().toUpperCase()
  const [history, baseHistory] = await Promise.all([
    ctx.getHistoryForCall(call),
    baseCall && baseCall !== call ? ctx.getHistoryForCall(baseCall) : Promise.resolve([]),
  ])

  const merged = mergeHistory(history ?? [], baseHistory ?? [])
  if (merged.length === 0) return null

  return buildCallHistoryTiers(call, merged, qso?.uuid as string | undefined)
}

async function lookupCallManual(
  args: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const tiers = await historyTiers(args, ctx)
  return tiers?.manual ?? []
}

async function lookupCallGuessed(
  args: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const tiers = await historyTiers(args, ctx)
  return tiers?.guessed ?? []
}
