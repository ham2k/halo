// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Lookup service. Mirrors `core/scoring`'s architecture: Dart makes a single
// call (`lookupService/core`), and this hook does everything else internally
// — the hardcoded callsign-annotation pre-step, a priority-ordered fan-out
// to every registered `lookup` hook, and the locationScope-aware merge —
// entirely inside the runtime.

import { defineExtension, hooks, host } from "@ham2k/extension-sdk"
import type { CallInfo, CallInfoLookup, HookContext, JSONValue, LookupServiceRequest, LookupServiceResult } from "@ham2k/extension-sdk"

import { annotateCallsign } from "./annotate"
import { runLookupPipeline } from "./mergeLookup"
import { normalizeGuess } from "./normalizeGuess"
import { resolveGuess, storedGuessLookup } from "./resolveGuess"

import manifest from "../manifest.json" with { type: "json" }

async function lookupCallInfo(args: LookupServiceRequest, ctx: HookContext): Promise<LookupServiceResult> {
  const call = (args.callInfo.call || "").trim().toUpperCase()

  const preAnnotation = annotateCallsign(call)
  const seeded = runLookupPipeline(args.callInfo, [preAnnotation])
  const lookups: CallInfoLookup[] = seeded.lookups
  let guess: CallInfo = seeded.guess

  const fold = (currentArgs: unknown, hookResult: unknown) => {
    const results = (hookResult as CallInfoLookup[] | null) ?? []
    const folded = runLookupPipeline(guess, results)
    lookups.push(...folded.lookups)
    guess = folded.guess
    return { ...(currentArgs as Record<string, unknown>), callInfo: guess }
  }

  const entries = await hooks.invokeAllSequential("lookup", "lookupCall", { callInfo: guess, qso: args.qso, operation: args.operation }, fold, ctx.online)

  // Hooks whose answer describes what the station is doing right now, run
  // only for a contact being composed — see RecentContextLookupHook. Last,
  // and folded through the same pipeline, so they see everything the
  // ordinary sources resolved and still lose any field one already filled.
  if (args.recentContext) {
    entries.push(
      ...(await hooks.invokeAllSequential(
        "recentContextLookup",
        "lookupCall",
        { callInfo: guess, qso: args.qso, operation: args.operation },
        fold,
        ctx.online,
      )),
    )
  }

  // A hook that threw has already been isolated (its entry carries the
  // error instead of poisoning the others) — but it must not be *silent*,
  // or a broken lookup source just looks like "no data" in the field.
  for (const entry of entries) {
    if (!entry.ok) host.log(`ERROR lookup hook '${entry.key}' failed for ${call}: ${entry.error}`)
  }

  // The running `guess` above is what each hook sees of the sources before
  // it. The answer is settled afresh from everything fetched, against the
  // contact's refs and what the operator entered — the same settling a saved
  // contact gets from `resolveCallInfo`.
  return { lookups, guess: normalized(call, resolveGuess(call, lookups, args.qso as Record<string, unknown>)) }
}

/// A saved contact's guess settled again from what is already stored on it,
/// with no source asked anything: after the operator edits its location or
/// its refs, so the stored guess says what every reader should show.
///
/// A contact with no `lookups[]` (logged by app-polo, imported) gets its
/// stored guess filed as one, so this and every later settling has something
/// to replay — once overlaid, the guess no longer holds what the lookup said.
async function resolveCallInfo(args: { qso: Record<string, JSONValue> }): Promise<LookupServiceResult | null> {
  const their = (args.qso.their ?? {}) as Record<string, unknown>
  const call = (typeof their.call === "string" ? their.call : "").trim().toUpperCase()
  if (call === "") return null
  const stored = Array.isArray(their.lookups) ? (their.lookups as CallInfoLookup[]) : []
  const guess = their.guess as Record<string, unknown> | undefined
  // What is stored was looked up for a call since corrected: replayed, it
  // would file that station's name and address under this one — and under
  // this call, past the host's check for a crossed result. Nothing is
  // settled; only a lookup of the corrected call can answer for it.
  const storedCall = typeof guess?.call === "string" ? guess.call.trim().toUpperCase() : undefined
  if (storedCall !== undefined && storedCall !== call) return null
  const lookups = stored.length > 0 ? stored : guess ? [storedGuessLookup(guess)] : []
  return { lookups, guess: normalized(call, resolveGuess(call, lookups, args.qso as Record<string, unknown>)) }
}

/// Cleanup of the assembled answer only — `lookups[]` keeps each source's
/// own wording (see normalizeGuess). Cosmetic, and so never allowed to cost
/// the operator a lookup that did resolve: a throw here would empty a guess
/// several sources just filled, and would read on screen as "not found".
function normalized(call: string, guess: CallInfo): CallInfo {
  try {
    return normalizeGuess(guess)
  } catch (e) {
    host.log(`ERROR normalizing the guess for ${call}: ${(e as Error).message ?? e}`)
    return guess
  }
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("lookupService", { hook: { lookupCallInfo, resolveCallInfo }, key: "core" })
  },
})
