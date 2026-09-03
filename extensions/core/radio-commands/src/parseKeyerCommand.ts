// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts like parsePowerCommand.ts, so it runs under the
// plain node test runner.

const KEYER_MATCH = /^(KEYER|MACROS)$/i

/// Whether `input` asks for the keyer area — `KEYER`, or `MACROS` for the
/// operator who thinks of the messages by the other loggers' name for them.
export function parseKeyerCommand(input: string): boolean {
  return KEYER_MATCH.test(input.trim())
}
