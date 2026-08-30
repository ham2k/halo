// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import type { RefInfo, Spot } from "@ham2k/extension-sdk"

/// Reduces a station's recent spots to the activity references worth
/// proposing for the QSO being logged. Pure, so the hook itself stays a thin
/// wrapper around the host call.
///
/// [spots] must arrive newest-first (the host's `getSpotsForCall` orders
/// them) — the first spot to offer a given ref type wins, so an activator who
/// moved between two parks inside the window contributes the one they are on
/// now, not the one they left.
///
/// A type already in [existingTypes] is dropped rather than re-proposed: the
/// host only applies types the QSO lacks, so re-offering one would make every
/// lookup pass propose a ref that can never land.
export function collectRefsFromSpots(spots: Spot[], existingTypes: Iterable<string> = []): RefInfo[] {
  const claimed = new Set<string>(existingTypes)
  const refs: RefInfo[] = []
  for (const spot of spots ?? []) {
    for (const ref of spot?.refs ?? []) {
      if (!ref?.type || !ref?.ref) continue
      if (claimed.has(ref.type)) continue
      claimed.add(ref.type)
      refs.push({ type: ref.type, ref: ref.ref })
    }
  }
  return refs
}
