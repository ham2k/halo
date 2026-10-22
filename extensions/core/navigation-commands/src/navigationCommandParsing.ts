// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing for GO, split out from index.ts so it can be unit-tested
// without the extension-runtime globals `defineExtension` depends on — same
// convention as operationCommandParsing.ts.

export type Place = { word: string; to: string; alias?: boolean; keywords?: string[]; experiment?: string; developerMode?: boolean }

/// Where GO can go: the word typed, and the `navigate` destination it names.
/// Several words may name one place (HUNT is CHASE, CAT is STATION). Order
/// is the catalog's, and an alias follows the word it stands for.
///
/// A place behind an `experiment` (or developer mode) does not exist for GO
/// until that is on — it is neither listed nor understood, the same as the
/// view it leads to, which the app hides until then.
export const PLACES: ReadonlyArray<Place> = [
  { word: "HOME", to: "operations", keywords: ["OPERATIONS"] },
  { word: "MAPS", to: "maps", keywords: ["MAP"] },
  { word: "LOGS", to: "logs", keywords: ["QSOS", "CONTACTS"], experiment: "logs" },
  { word: "CHASE", to: "chase", keywords: ["CHASING"], experiment: "chase" },
  { word: "HUNT", to: "chase", alias: true, experiment: "chase" },
  { word: "SETTINGS", to: "settings", keywords: ["PREFERENCES", "OPTIONS"] },
  { word: "PROFILE", to: "profiles", keywords: ["CALLSIGN", "PROFILES"] },
  { word: "STATION", to: "station", keywords: ["RADIO", "RIG", "EQUIPMENT"] },
  { word: "CAT", to: "station", alias: true },
  { word: "SYNC", to: "sync", keywords: ["CLOUD", "BACKUP"] },
  { word: "PEERS", to: "peers", keywords: ["P2P", "NETWORK"], experiment: "p2p" },
  { word: "ACCOUNTS", to: "accounts", keywords: ["SERVICES", "DATA SOURCES", "CREDENTIALS"] },
  { word: "DATA", to: "accounts", alias: true },
  { word: "EXTENSIONS", to: "extensions", keywords: ["FEATURES", "ACTIVITIES", "CONTESTS"] },
  { word: "DEV", to: "developer", keywords: ["DEVELOPER"], developerMode: true },
  { word: "HELP", to: "help", keywords: ["SUPPORT", "FORUMS", "RESOURCES"] },
  { word: "ABOUT", to: "about", keywords: ["VERSION", "CREDITS"] },
]

/// The [PLACES] that exist for this user: their experiment is on, and
/// developer mode when they need it.
export function availablePlaces(enabledExperiments: readonly string[], developerMode: boolean): Place[] {
  return PLACES.filter((p) => (!p.experiment || enabledExperiments.includes(p.experiment)) && (!p.developerMode || developerMode))
}

/// What [place]'s catalog row is found by besides its own word: its
/// keywords, and the alias words that go to the same place (CAT for STATION).
export function keywordsOf(place: Place, places: readonly Place[]): string[] {
  return [...(place.keywords ?? []), ...places.filter((p) => p.alias && p.to === place.to).map((p) => p.word)]
}

/// The whole word GO, then a place after a space or a slash — the separator
/// every call-field command accepts.
const GO_MATCH = /^GO(?:[ /](.*))?$/i

export type GoCommand =
  /// Nothing after GO yet, or the start of more than one place (`GO S`).
  { kind: "incomplete"; candidates: string[] } | { kind: "place"; word: string; to: string } | { kind: "unknown"; text: string }

/// `null` when the input is not GO at all — the whole word, so a callsign
/// that happens to start with it still logs normally.
///
/// A place resolves on its full word or on any start of it that only one
/// place's word begins (`GO MA` is MAPS), so the operator never has to
/// finish a word the bar already knows.
export function parseGoCommand(input: string, places: readonly Place[]): GoCommand | null {
  const match = GO_MATCH.exec(input.trim())
  if (!match) return null
  const text = (match[1] ?? "").trim().toUpperCase()
  if (!text) return { kind: "incomplete", candidates: places.filter((p) => !p.alias).map((p) => p.word) }
  const exact = places.find((p) => p.word === text)
  if (exact) return { kind: "place", word: exact.word, to: exact.to }
  const starts = places.filter((p) => p.word.startsWith(text))
  const destinations = new Set(starts.map((p) => p.to))
  if (destinations.size === 1) return { kind: "place", word: starts[0].word, to: starts[0].to }
  if (starts.length > 1) return { kind: "incomplete", candidates: starts.map((p) => p.word) }
  return { kind: "unknown", text }
}
