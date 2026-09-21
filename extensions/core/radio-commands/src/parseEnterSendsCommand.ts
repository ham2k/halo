// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Split out of index.ts like parseKeyerCommand.ts, so it runs under the
// plain node test runner.

const ESM_MATCH = /^ESM(?:\s+(ON|OFF))?$/i
const RUN_MATCH = /^RUN$/i
const SP_MATCH = /^(SP|S&P)$/i

/// What `input` asks of Enter Sends Messages, or null when it is not one of
/// its commands: `ESM` / `ESM ON` / `ESM OFF` switch it, and `RUN` / `SP`
/// (or `S&P`) pick the side of the exchange — switching it on too, since
/// Run and S&P mean nothing else here and an operator naming one wants it.
export function parseEnterSendsCommand(input: string): { on: boolean; running?: boolean } | null {
  const text = input.trim()
  const esm = ESM_MATCH.exec(text)
  if (esm) return { on: esm[1]?.toUpperCase() !== 'OFF' }
  if (RUN_MATCH.test(text)) return { on: true, running: true }
  if (SP_MATCH.test(text)) return { on: true, running: false }
  return null
}
