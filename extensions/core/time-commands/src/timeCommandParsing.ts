// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The time commands' parser (see index.ts). Pure, so every accepted form is
// tested without a runtime.

/// What a time command asks for. `error` is a recognized shape with an
/// impossible value: "25:00" must say so, not log as a callsign.
export type TimeCommand =
  | { kind: "now" }
  | { kind: "delta"; deltaMillis: number; label: string }
  | { kind: "time"; hour: number; minute: number; second?: number }
  | { kind: "minute"; minute: number }
  | { kind: "second"; second: number }
  | { kind: "date"; month: number; day: number }
  | { kind: "error"; error: "badTime" | "badDate" | "tooFar" }

export type DateOrder = "mdy" | "dmy" | "ymd"

const UNIT_MILLIS: Record<string, number> = { S: 1000, M: 60 * 1000, H: 60 * 60 * 1000, D: 24 * 60 * 60 * 1000 }

// `m` is minutes, as in DEVTT: a month is `30d`. No unit means minutes, the
// step a transcribed log usually moves by.
const DELTA_MATCH = /^([+-])(\d+)([SMHD]?)$/
const TIME_MATCH = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/
const MINUTE_MATCH = /^:(\d{2})$/
const SECOND_MATCH = /^::(\d{2})$/
const DATE_MATCH = /^(\d{1,2})\/(\d{1,2})$/

/// A century: the app turns milliseconds into a `Duration`, whose int64
/// microseconds WRAP rather than throw, so the bound has to hold here, where
/// the typed magnitude still exists.
const MAX_DELTA_MILLIS = 100 * 365 * UNIT_MILLIS.D

const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

/// [day] of [month] in [year], a Feb 29 in a common year falling back to the
/// 28th — as the app applies a date.
export function clampDay(month: number, day: number, year: number): number {
  const leap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0
  return month === 2 && day === 29 && !leap ? 28 : day
}

/// Parses a time command typed into the call field; null for anything else,
/// partial forms ("12:3", ":3", "::3") included — they are still being typed.
///
/// A two-part date reads in [order]'s month/day order; a year-first region
/// writes the month before the day too.
export function parseTimeCommand(input: string, order: DateOrder = "mdy"): TimeCommand | null {
  const text = input.trim().toUpperCase()
  if (text === "NOW") return { kind: "now" }

  const delta = DELTA_MATCH.exec(text)
  if (delta) {
    const [, sign, amount, typedUnit] = delta
    const unit = typedUnit || "M"
    const deltaMillis = (sign === "-" ? -1 : 1) * Number(amount) * UNIT_MILLIS[unit]
    if (Math.abs(deltaMillis) > MAX_DELTA_MILLIS) return { kind: "error", error: "tooFar" }
    return { kind: "delta", deltaMillis, label: `${sign}${Number(amount)}${unit.toLowerCase()}` }
  }

  const time = TIME_MATCH.exec(text)
  if (time) {
    const hour = Number(time[1])
    const minute = Number(time[2])
    const second = time[3] === undefined ? undefined : Number(time[3])
    if (hour > 23 || minute > 59 || (second ?? 0) > 59) return { kind: "error", error: "badTime" }
    return second === undefined ? { kind: "time", hour, minute } : { kind: "time", hour, minute, second }
  }

  const minute = MINUTE_MATCH.exec(text)
  if (minute) {
    const value = Number(minute[1])
    if (value > 59) return { kind: "error", error: "badTime" }
    return { kind: "minute", minute: value }
  }

  const second = SECOND_MATCH.exec(text)
  if (second) {
    const value = Number(second[1])
    if (value > 59) return { kind: "error", error: "badTime" }
    return { kind: "second", second: value }
  }

  const date = DATE_MATCH.exec(text)
  if (date) {
    const [first, second] = [Number(date[1]), Number(date[2])]
    const [month, day] = order === "dmy" ? [second, first] : [first, second]
    if (month < 1 || month > 12 || day < 1 || day > DAYS_IN_MONTH[month - 1]) return { kind: "error", error: "badDate" }
    return { kind: "date", month, day }
  }

  return null
}
