// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Test Operations (docs: Test Operations) are detected once here so every
// extension that needs to special-case one agrees on the same rule —
// `exportNames.ts` (filename suffix) and POTA's spotting hook both use this.
// Mirrors `halo_core`'s `Operation.isTestOperation`; the two can't share code
// across the Dart/TypeScript boundary, so this is the TypeScript side's only
// copy — every caller here imports it rather than re-deriving it.

import type { JSONValue } from "./types.ts"

/// True when any comma-separated call in `stationCall` carries a `T` or
/// `TEST` SEGMENT — checked per-call, not on the joined string, so a real
/// call isn't hidden behind a test one earlier or later in a multi-operator
/// list (`"W1AW/T, KI2D"` is still a Test Operation).
///
/// Segments, not a suffix, exactly as `halo_core`'s `isTestCall` explains:
/// a substring match would opt `W1AW/TESTER` in, and matching only the last
/// segment would miss `KI2D/T/P` — or `KI2D/TEST/OP1`, the call a
/// multi-station Test Operation self-spots under, which arrives here already
/// carrying both suffixes (`ExtensionService.spotCallForSelfSpot`).
export function isTestOperation(stationCall: JSONValue | undefined): boolean {
  return String(stationCall ?? "")
    .split(",")
    .flatMap((call) => call.trim().toUpperCase().split("/"))
    .some((segment) => segment === "T" || segment === "TEST")
}
