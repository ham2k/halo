// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Test Operations (docs: Test Operations) are detected once here so every
// extension that needs to special-case one agrees on the same rule —
// `exportNames.ts` (filename suffix) and POTA's spotting hook both use this.
// Mirrors `halo_core`'s `Operation.isTestOperation`; the two can't share code
// across the Dart/TypeScript boundary, so this is the TypeScript side's only
// copy — every caller here imports it rather than re-deriving it.

import type { JSONValue } from "./types"

/// True when any comma-separated call in `stationCall` ends in `/T` or
/// `/TEST` — checked per-call, not on the joined string, so a real call
/// isn't hidden behind a test one earlier or later in a multi-operator
/// list (`"W1AW/T, KI2D"` is still a Test Operation).
export function isTestOperation(stationCall: JSONValue | undefined): boolean {
  return String(stationCall ?? "")
    .split(",")
    .map((call) => call.trim().toUpperCase())
    .some((call) => call.endsWith("/T") || call.endsWith("/TEST"))
}
