// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVTT's parser (see index.ts's DevTimeTravelCommand and
// docs/design/time.md). Split out from index.ts for the same reason seed.ts
// is: a parser with this many accepted forms is worth testing without a
// runtime, and everything here is pure.

/// What a DEVTT input asks for. `error` is a recognized command with an
/// unusable argument — the field must SAY so rather than quietly treating
/// "DEVTT +3hours" as a callsign.
export type TimeTravelRequest =
  | { kind: 'reset' }
  | { kind: 'travel'; deltaMillis: number; speed: number | null }
  | { kind: 'error'; error: string }

const COMMAND_MATCH = /^DEV(?:TT|TIMETRAVEL)(?:\s+(.*))?$/i

// `m` is minutes, not months: this is a debugging tool for a logger, where
// minutes and hours are the interesting scales and a month is `30d`.
/// Matching `AppClock.maxSpeed`.
const MAX_SPEED = 1000

const UNIT_MILLIS: Record<string, number> = {
  S: 1000,
  M: 60 * 1000,
  H: 60 * 60 * 1000,
  D: 24 * 60 * 60 * 1000,
  W: 7 * 24 * 60 * 60 * 1000,
}

const DELTA_TOKEN = /^([+-]?)(\d+(?:\.\d+)?)([SMHDW])$/
const SPEED_TOKEN = /^(\d+(?:\.\d+)?)X$/

/// A century, matching `AppClock.maxTravel`. Bounded HERE as well as app-side
/// because the app receives milliseconds and turns them into a `Duration`, whose
/// int64 microsecond field WRAPS rather than throwing — so a big enough number
/// arrives already wrapped, and the app's own bound then compares a value that
/// has nothing to do with what was typed. Refusing at the text is the only place
/// the real magnitude still exists.
const MAX_DELTA_MILLIS = 100 * 365 * UNIT_MILLIS.D

/// Parses `DEVTT` / `DEVTIMETRAVEL` and its arguments; null when the input is
/// some other command entirely.
///
/// Arguments are whitespace-separated and order-independent: any number of
/// offsets (`+3h`, `-1d`, `90m`, `1.5h` — an unsigned offset is forward) which
/// SUM, and at most one speed factor (`2x`, `0.5x`). No arguments at all means
/// "back to real time", which is why an offset that cancels out is not the way
/// to reset.
export function parseTimeTravelCommand(input: string): TimeTravelRequest | null {
  const match = COMMAND_MATCH.exec(input.trim())
  if (!match) return null

  const args = (match[1] ?? '').trim()
  if (!args) return { kind: 'reset' }

  let deltaMillis = 0
  let speed: number | null = null

  for (const token of args.toUpperCase().split(/\s+/)) {
    const delta = DELTA_TOKEN.exec(token)
    if (delta) {
      const [, sign, amount, unit] = delta
      deltaMillis += (sign === '-' ? -1 : 1) * Number(amount) * UNIT_MILLIS[unit]
      if (Math.abs(deltaMillis) > MAX_DELTA_MILLIS) {
        return { kind: 'error', error: 'DEVTT: that is further than a century — the clock stops there' }
      }
      continue
    }

    const factor = SPEED_TOKEN.exec(token)
    if (factor) {
      const value = Number(factor[1])
      // A stopped or reversed clock isn't a slow one: every elapsed-time label,
      // sequence number and staleness check in the app assumes time moves
      // forward, so this is refused rather than passed on to break them.
      if (!(value > 0)) return { kind: 'error', error: `DEVTT: ${token} would stop the clock` }
      // Matching AppClock.maxSpeed. Refused here too so the message names the
      // limit instead of the app reporting a bare rejection.
      if (value > MAX_SPEED) return { kind: 'error', error: `DEVTT: ${token} is faster than ${MAX_SPEED}x` }
      if (speed !== null) return { kind: 'error', error: 'DEVTT: only one speed at a time' }
      speed = value
      continue
    }

    return {
      kind: 'error',
      error: `DEVTT: "${token}" is neither an offset (+3h, -1d) nor a speed (2x)`,
    }
  }

  // Every token parsed, but none of them said anything — only reachable via a
  // zero offset like `+0h`, which would otherwise read as a silent reset.
  if (deltaMillis === 0 && speed === null) {
    return { kind: 'error', error: 'DEVTT: that changes nothing — bare DEVTT returns to real time' }
  }

  return { kind: 'travel', deltaMillis, speed }
}

/// The question the call field asks before running it, e.g.
/// `Jump 3h forward and run at 2x?`. Developer-facing, so plain English with no
/// i18n catalog — like the rest of dev-commands.
export function describeTimeTravel(request: TimeTravelRequest): string {
  if (request.kind === 'reset') return 'Return to real time?'
  if (request.kind === 'error') return request.error

  const clauses: string[] = []
  if (request.deltaMillis !== 0) {
    const direction = request.deltaMillis < 0 ? 'back' : 'forward'
    clauses.push(`Jump ${formatMillis(Math.abs(request.deltaMillis))} ${direction}`)
  }
  if (request.speed !== null) {
    clauses.push(`${clauses.length ? 'and run' : 'Run'} at ${request.speed}x`)
  }
  return `${clauses.join(' ')}?`
}

/// The largest two whole units of a positive duration, e.g. `3d 2h`, `90m` as
/// `1h 30m`.
function formatMillis(millis: number): string {
  const parts: string[] = []
  let rest = millis
  for (const [unit, size] of [['d', UNIT_MILLIS.D], ['h', UNIT_MILLIS.H], ['m', UNIT_MILLIS.M], ['s', UNIT_MILLIS.S]] as [string, number][]) {
    const whole = Math.floor(rest / size)
    rest -= whole * size
    if (whole === 0 && parts.length === 0) continue
    if (whole === 0 && parts.length === 1) break
    parts.push(`${whole}${unit}`)
    if (parts.length === 2) break
  }
  return parts.length ? parts.join(' ') : '0s'
}
