// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Lookup service. Mirrors `core/scoring`'s architecture: Dart makes a single
// call (`lookupService/core`), and this hook does everything else internally
// — the hardcoded callsign-annotation pre-step, a priority-ordered fan-out
// to every registered `lookup` hook, and the locationScope-aware merge —
// entirely inside the runtime.

import { defineExtension, hooks, host } from "@ham2k/halo-extension-sdk"
import type { CallInfo, CallInfoLookup, HookContext, LookupServiceRequest, LookupServiceResult } from "@ham2k/halo-extension-sdk"

import { annotateCallsign } from "./annotate"
import { runLookupPipeline } from "./mergeLookup"

import manifest from "../manifest.json" with { type: "json" }

async function lookupCallInfo(args: LookupServiceRequest, ctx: HookContext): Promise<LookupServiceResult> {
  const call = (args.callInfo.call || '').trim().toUpperCase()

  const preAnnotation = annotateCallsign(call)
  const seeded = runLookupPipeline(args.callInfo, [preAnnotation])
  const lookups: CallInfoLookup[] = seeded.lookups
  let guess: CallInfo = seeded.guess

  const entries = await hooks.invokeAllSequential(
    'lookup',
    'lookupCall',
    { callInfo: guess, qso: args.qso, operation: args.operation },
    (currentArgs, hookResult) => {
      const results = (hookResult as CallInfoLookup[] | null) ?? []
      const folded = runLookupPipeline(guess, results)
      lookups.push(...folded.lookups)
      guess = folded.guess
      return { ...(currentArgs as Record<string, unknown>), callInfo: guess }
    },
    ctx.online,
  )

  // A hook that threw has already been isolated (its entry carries the
  // error instead of poisoning the others) — but it must not be *silent*,
  // or a broken lookup source just looks like "no data" in the field.
  for (const entry of entries) {
    if (!entry.ok) host.log(`ERROR lookup hook '${entry.key}' failed for ${call}: ${entry.error}`)
  }

  return { lookups, guess }
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('lookupService', { hook: { lookupCallInfo }, key: 'core' })
  },
})
