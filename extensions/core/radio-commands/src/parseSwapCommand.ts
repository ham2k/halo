// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts like parsePowerCommand.ts, so it runs under the
// plain node test runner.

const SWAP_MATCH = /^SWAP$/i

/// Whether `input` asks SO2R's two radios to trade places.
export function parseSwapCommand(input: string): boolean {
  return SWAP_MATCH.test(input.trim())
}
