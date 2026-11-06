// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts like parseKeyerCommand.ts, so it runs under the
// plain node test runner.

const ESM_MATCH = /^ESM(?:\s+(ON|OFF))?$/i

/// What `input` asks of Enter Sends Messages, or null when it is not one of
/// its commands: `ESM` / `ESM ON` / `ESM OFF` switch it. Which side of the
/// exchange it plays is the operating style, which `RUN` and `SNP` set
/// (parseStyleCommand.ts).
export function parseEnterSendsCommand(input: string): { on: boolean } | null {
  const esm = ESM_MATCH.exec(input.trim())
  return esm ? { on: esm[1]?.toUpperCase() !== "OFF" } : null
}
