// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Callsign helpers that need no country file. Kept apart from dxcc.ts, whose
// import loads the bundled BIGCTY data into every bundle that reaches it.
// Import by relative path from a file that must stay resolvable by plain
// `node --test`.

import { parseCallsign } from "@ham2k/lib-callsigns"

/// The call without its portable prefix or suffix, uppercased — who operated,
/// so `DL1ABC/P` and `DL1ABC` are one person. Falls back to the trimmed input
/// when it doesn't parse as a callsign.
export function baseCallOf(call: string): string {
  const trimmed = call.trim().toUpperCase()
  return parseCallsign(trimmed).baseCall || trimmed
}
