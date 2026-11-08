// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The grammar of UPDATE, apart from its sentences so it can be tested
// without a runtime.

/// UPDATE or UPD, then what to update.
const UPDATE_MATCH = /^(?:UPDATE|UPD)(?:\s+(.*))?$/i

/// What an UPDATE asks for. `data` with no `matching` is every data file;
/// with it, the files the app finds answering to all of those words.
export type UpdateTarget = { kind: "incomplete" } | { kind: "app" } | { kind: "extensions" } | { kind: "data"; matching?: string[] }

/// What decides the target, when it is everything typed. Any other words are
/// a data file's, which only the app can resolve — so a word added here takes
/// it away from every data file that answers to it. ALL is RELOAD ALL's word
/// for every data file.
const RESERVED: Record<string, UpdateTarget> = {
  DATA: { kind: "data" },
  "DATA FILES": { kind: "data" },
  ALL: { kind: "data" },
  APP: { kind: "app" },
  EXT: { kind: "extensions" },
  EXTENSIONS: { kind: "extensions" },
}

export function parseUpdateCommand(input: string): UpdateTarget | null {
  const match = UPDATE_MATCH.exec(input.trim())
  if (!match) return null
  // Split as the app splits a data file's key, category and name into the
  // words it answers to: on anything not a letter or a digit. Otherwise a
  // key typed whole (ham2k-pota-all-parks) is one word no file answers to.
  const words = (match[1] ?? "")
    .toUpperCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
  if (words.length === 0) return { kind: "incomplete" }
  const reserved = RESERVED[words.join(" ")]
  if (reserved) return reserved
  return { kind: "data", matching: words }
}
