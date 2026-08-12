// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Kept apart from index.ts, which pulls in the runtime's bare-specifier
// value imports (`defineExtension`, `hooks`, …) that only resolve under tsc —
// this file's own filename.test.ts runs under plain `node --test`.

// Relative import, not the `@ham2k/halo-extension-sdk` alias — same
// constraint mergeLookup.ts documents.
import { exportFilename, startMillisOf } from "../../../sdk/src/exportNames.ts"
import type { JSONValue } from "../../../sdk/src/types.ts"

/// The whole-log export claims no single reference, so the modifier is
/// `Full` — or `<title> Full`, when the operation has one — same trailing tag
/// app-polo's `core-adif` extension uses, with the title kept ahead of it so
/// two titled operations don't still collide on "Full" alone.
export function filenameFor(
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  compact?: boolean,
): string {
  const title = String(operation.title ?? "").trim()
  return exportFilename({
    stationCall: operation.stationCall,
    modifier: title ? `${title} Full` : "Full",
    startAtMillis: startMillisOf(operation, qsos),
    extension: "adi",
    compact,
  })
}
