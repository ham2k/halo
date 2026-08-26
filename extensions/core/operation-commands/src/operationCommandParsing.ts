// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing for the operation call-field commands, split out from
// index.ts so it can be unit-tested without the extension-runtime globals
// `defineExtension` depends on — same convention as spotCommandParsing.ts.
//
// Both commands take their argument after a space OR a slash, the separator
// every call-field command accepts (`OPER/KI2D` is what an operator typing a
// callsign reaches for).

const OPERATOR_MATCH = /^(OPER|OPERATOR)(?:[ /](.*))?$/i
const POSITION_MATCH = /^POSITION(?:[ /](.*))?$/i

/// `null` when the input is not an OPER command at all; `{ call: '' }` when
/// the word was typed with nothing after it — a recognized command that
/// cannot run yet, which the caller reports rather than letting Enter log
/// "OPER" as somebody's callsign.
export function parseOperatorCommand(input: string): { call: string } | null {
  const match = OPERATOR_MATCH.exec(input.trim())
  if (!match) return null
  return { call: (match[2] ?? '').trim().toUpperCase() }
}

/// `null` when the input is not a POSITION command. `position` is the digits
/// typed, `''` when nothing was, and `invalid` marks an argument that is not
/// a whole number — which must be reported, not silently rounded or ignored:
/// the value ends up in a callsign on the air.
export function parsePositionCommand(input: string): { position: string; invalid: boolean } | null {
  const match = POSITION_MATCH.exec(input.trim())
  if (!match) return null
  const arg = (match[1] ?? '').trim()
  // Bounded, not just numeric: `String(Number(...))` would quietly coerce a
  // 20-digit entry into a different number, and that number goes on the air.
  // A station has operators, not thousands of them.
  return { position: arg, invalid: arg !== '' && !/^\d{1,2}$/.test(arg) }
}

/// `POSITION 0` means "no position", the same as an empty field in the
/// Operation Details dialog — a station numbered from 1, so 0 is free to
/// mean off and an operator gets a way to undo the setting by typing.
export function positionValueFor(position: string): string {
  return Number(position) === 0 ? '' : String(Number(position))
}
