// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts like parseEnterSendsCommand.ts, so it runs under the
// plain node test runner.

const RUN_MATCH = /^RUN$/i
const SNP_MATCH = /^(SNP|SP|S&P)$/i

/// The operating style `input` asks for — `RUN`, or `SNP` (also `SP` and
/// `S&P`) for the normal style, search and pounce — or null when it is not one of these words.
/// Only the bare word: `SP` and `SN` are Polish prefixes, and anything longer
/// is a callsign being typed.
export function parseStyleCommand(input: string): "run" | "normal" | null {
  const text = input.trim()
  if (RUN_MATCH.test(text)) return "run"
  if (SNP_MATCH.test(text)) return "normal"
  return null
}
