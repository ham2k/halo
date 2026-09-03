// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts for the same reason parsePowerCommand.ts is: so the
// WPM command's own parsing runs under the plain node test runner.

const WPM_MATCH = /^(\d{1,2})\s*WPM$/i

/// The keyer speed in `input` (e.g. "20WPM", "25 wpm"), or null for
/// anything else. No range check here: what a keyer accepts is the radio's
/// to say, and the session clamps to it.
export function parseWpmCommand(input: string): number | null {
  const match = WPM_MATCH.exec(input.trim())
  if (!match) return null
  const wpm = Number(match[1])
  return wpm > 0 ? wpm : null
}
