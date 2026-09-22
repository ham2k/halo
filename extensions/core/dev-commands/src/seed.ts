// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure logic for the SEED command (see index.ts), split out so it can be
// unit-tested with plain `node --test` — same convention as spot-commands'
// spotCommandParsing.ts. Everything random takes an injectable `random`
// so tests can drive it deterministically.

/// "SEED" -> 10 QSOs (the default); "SEED 20" -> 20 QSOs; "SEED 15 3H" ->
/// 15 QSOs spread over 3 hours (units: M/H/D). A spread amount typed
/// without its unit yet ("SEED 15 3") is recognized but incomplete.
const SEED_MATCH = /^SEED(?:\s+(\d+)(?:\s+(\d+(?:\.\d+)?)\s*([HMD])?)?)?$/i

const UNIT_MILLIS: Record<string, number> = {
  M: 60_000,
  H: 3_600_000,
  D: 86_400_000,
}

/// Hard cap on one SEED's QSO count: command interpretation re-runs on a
/// debounce while typing and annotates every generated QSO through the
/// lookup pipeline, so an unbounded count could blow the host's 2s
/// interpret timeout (and then dispatch thousands of inserts).
export const MAX_SEED_COUNT = 500

export interface ParsedSeedCommand {
  complete: boolean
  count: number
  spreadMillis?: number
  /// Normalized spread as typed (e.g. "3H"), for describe/confirm text.
  spreadLabel?: string
}

export function parseSeedCommand(input: string): ParsedSeedCommand | null {
  const match = SEED_MATCH.exec(input.trim())
  if (!match) return null
  const [, countText, spreadText, unitText] = match

  const count = Math.min(Math.max(countText ? parseInt(countText, 10) : 10, 1), MAX_SEED_COUNT)

  if (spreadText && !unitText) return { complete: false, count } // "SEED 15 3" — unit still being typed
  if (!spreadText) return { complete: true, count }

  const unit = unitText!.toUpperCase()
  const spreadMillis = parseFloat(spreadText) * UNIT_MILLIS[unit]
  if (!(spreadMillis > 0)) return { complete: true, count } // "SEED 5 0H" — degenerate spread, ignore it
  return { complete: true, count, spreadMillis, spreadLabel: `${spreadText}${unit}` }
}

export interface ExistingQsoStats {
  count?: number
  startAtMillisMin?: number
  startAtMillisMax?: number
}

/// Summarizes an operation's QSO list (as `ctx.getQsos` returns it) into
/// the count/min/max the placement rule needs, counting real contacts only
/// — event markers (`band: 'event'`) ride the same timeline but aren't log
/// entries, and a start-of-operation marker would otherwise anchor the
/// backfill window ahead of the QSOs themselves.
export function existingStatsFromQsos(qsos: Record<string, unknown>[]): ExistingQsoStats {
  let count = 0
  let min: number | undefined
  let max: number | undefined
  for (const qso of qsos) {
    if (qso.band === "event") continue
    count++
    const at = qso.startAtMillis
    if (typeof at !== "number") continue
    if (min === undefined || at < min) min = at
    if (max === undefined || at > max) max = at
  }
  return { count, startAtMillisMin: min, startAtMillisMax: max }
}

export interface SeedPlan {
  /// Ascending start times, one per QSO to seed.
  startTimes: number[]
  /// True when the window was anchored to end at the earliest existing QSO
  /// instead of now (existing log spans less than 1/3 of the spread).
  beforeExisting: boolean
}

/// Where the seeded QSOs land in time. With a spread: uniformly across the
/// window ending now — unless the existing log's own time span is shorter
/// than 1/3 of that spread, in which case the window ends at the earliest
/// existing QSO (backfilling history instead of interleaving with a much
/// denser real log). Without a spread: exponential inter-QSO gaps (mean two
/// minutes, i.e. a Poisson arrival process, like app-polo's SEED) walking
/// back from now.
export function seedPlan(args: { count: number; spreadMillis?: number; nowMillis: number; existing?: ExistingQsoStats; random?: () => number }): SeedPlan {
  const { count, spreadMillis, nowMillis, existing } = args
  const random = args.random ?? Math.random

  if (spreadMillis && spreadMillis > 0) {
    let endMillis = nowMillis
    let beforeExisting = false
    const minAt = existing?.startAtMillisMin
    if ((existing?.count ?? 0) > 0 && minAt != null) {
      const span = (existing?.startAtMillisMax ?? minAt) - minAt
      if (span < spreadMillis / 3) {
        endMillis = minAt
        beforeExisting = true
      }
    }
    const startTimes = Array.from({ length: count }, () => Math.round(endMillis - spreadMillis + random() * spreadMillis)).sort((a, b) => a - b)
    return { startTimes, beforeExisting }
  }

  const startTimes: number[] = []
  let at = nowMillis
  for (let i = 0; i < count; i++) {
    // Exponential gap, mean 120s, floored so two seeds never collide on the
    // same second even in an unlucky draw.
    at -= Math.max(5_000, Math.round(-Math.log(1 - random()) * 120_000))
    startTimes.push(at)
  }
  return { startTimes: startTimes.sort((a, b) => a - b), beforeExisting: false }
}

// Signal-report strengths weighted to lean heavily on 59/57/55, with the
// rest of the scale as occasional color. Readability drops below 5 only for
// the weak ones.
const STRENGTH_WEIGHTS: [number, number][] = [
  [9, 0.38],
  [7, 0.27],
  [5, 0.18],
  [8, 0.06],
  [6, 0.05],
  [4, 0.03],
  [3, 0.02],
  [2, 0.01],
]

export function randomRST(mode: string | undefined, random: () => number = Math.random): string {
  let pick = random()
  let strength = 9
  for (const [value, weight] of STRENGTH_WEIGHTS) {
    strength = value
    pick -= weight
    if (pick < 0) break
  }
  const readability = strength >= 5 ? 5 : 3 + Math.floor(random() * 2)
  if (mode === "CW" || mode === "RTTY") return `${readability}${strength}9`
  return `${readability}${strength}`
}

/// prefix + last digit + letter suffix — the parts callsign mutation swaps.
const CALL_SHAPE = /^([A-Z0-9]*)(\d)([A-Z]+)$/

/// Filters a Callsign Notes key list down to plain callsign-shaped entries:
/// notes files also carry expansion keywords (e.g. `DAN WD4DAN,WD4JMM`) and
/// compound calls, neither of which should seed a log.
export function seedableCallsFrom(keys: string[]): string[] {
  return keys.filter((key) => key.length >= 4 && CALL_SHAPE.test(key))
}

/// Mutates a call by replacing either its (last) digit or one letter of its
/// suffix — always with a *different* character, so a mutation is never a
/// silent no-op. Calls that don't parse as prefix+digit+suffix come back
/// unchanged.
export function mutateCall(call: string, random: () => number = Math.random): string {
  const match = CALL_SHAPE.exec(call)
  if (!match) return call
  const [, prefix, digit, suffix] = match
  if (random() < 0.5) {
    const replacement = (parseInt(digit, 10) + 1 + Math.floor(random() * 9)) % 10
    return `${prefix}${replacement}${suffix}`
  }
  const index = Math.floor(random() * suffix.length)
  const replacement = String.fromCharCode(65 + ((suffix.charCodeAt(index) - 65 + 1 + Math.floor(random() * 25)) % 26))
  return prefix + digit + suffix.slice(0, index) + replacement + suffix.slice(index + 1)
}

/// app-polo's fallback pool, for when no Callsign Notes data is loaded.
export const FALLBACK_CALLS = ["KI2D", "M1SDH", "EI5IYB", "M0LZN", "WV3H", "LB4FH", "VK1AO"]
