// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { defineExtension } from "@ham2k/extension-sdk"
import type { AnnotatedCallInfo, HookContext, JSONValue, LookupResult } from "@ham2k/extension-sdk"

import { buildCallHistoryTiers, mergeHistory } from "./buildCallHistoryLookup"

import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // A `lookup` hook, not `recentContextLookup` — this answers "who is
    // this station" from the log itself, true for the background queue's
    // enrichment of an already-saved QSO too, not only a contact in
    // progress.
    //
    // LAST, below every other lookup source (qrz/pota/sota/call-notes top
    // out at 100, ham2k-lookup sits at 10): the log is a fallback, never a
    // preference. A live callbook answer describes the station today; the
    // log describes it whenever it was last worked — so history fills only
    // what nothing else answered. That holds even for a field the operator
    // TYPED on the past QSO: a hand-corrected value is evidence about that
    // contact, not a standing override of a fresher source.
    //
    // -1, not the 0 an undeclared hook defaults to (`kernel.ts`): every
    // lookup source in this repo names a priority, but a third party's need
    // not, and a tie at 0 would leave "last" to activation order.
    //
    // The cost of running last is that neither qrz nor ham2k-lookup can see
    // the log when they decide whether to skip their network round-trip, so
    // a station worked before is fetched afresh every time. That is the
    // price of the rule above, not an oversight.
    //
    // Both tiers `buildCallHistoryTiers` produces ride this one
    // registration, keeping their distinct `source` labels — which the
    // operator reads and the queue's degradation guard compares. At most one
    // of them carries a location (see there), so the merge's grid/city
    // reconciliation — which deletes the location fields a result did not
    // itself write — has nothing of ours to delete, and the order the two
    // are returned in decides nothing.
    registerHook("lookup", { hook: { lookupCall }, priority: -1 })
  },
})

async function lookupCall(
  { callInfo, qso }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || "").trim().toUpperCase()
  if (call.length < 3 || !ctx.getHistoryForCall) return []

  // A portable/mobile/DX-prefixed call (`KI2D/P`, `F/KI2D`) is worked as
  // itself, but the station behind it is the same one worked plain — so its
  // history is worth searching too, same as PoLo's `findQSOHistory`
  // `baseCall` widening. `buildCallHistoryTiers` still gates location fields
  // on an EXACT call match (see there): a base-call match tells us who this
  // is, not where THIS variant is operating from.
  //
  // The two fetched in parallel — neither depends on the other's result,
  // and each is its own bridge round-trip.
  const baseCall = (callInfo.baseCall || "").trim().toUpperCase()
  const [history, baseHistory] = await Promise.all([
    ctx.getHistoryForCall(call),
    baseCall && baseCall !== call ? ctx.getHistoryForCall(baseCall) : Promise.resolve([]),
  ])

  const merged = mergeHistory(history ?? [], baseHistory ?? [])
  if (merged.length === 0) return []

  const tiers = buildCallHistoryTiers(call, merged, qso?.uuid as string | undefined)
  return [...tiers.manual, ...tiers.guessed]
}
