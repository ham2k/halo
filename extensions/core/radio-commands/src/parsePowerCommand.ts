// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pulled out of index.ts (which imports the SDK's `defineExtension` and so
// can't load under the plain node test runner — see spot-commands'
// spotCommandParsing.ts for the same split) so POWER's own parsing can be
// tested directly.

const POWER_MATCH = /^(\d+(?:\.\d+)?)W$/i

/// The wattage in `input` (e.g. "5W", "2.5W"), or null for anything else.
export function parsePowerCommand(input: string): number | null {
  const match = POWER_MATCH.exec(input.trim())
  return match ? Number(match[1]) : null
}
