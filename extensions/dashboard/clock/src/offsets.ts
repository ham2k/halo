// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock panel's arithmetic, with no SDK import so it unit-tests under
// plain node — the same split spaceWeather.ts uses.
//
// All of it is arithmetic on the epoch rather than any locale API, and that
// is not a style choice: the extension runtime is QuickJS-NG, which has no
// ECMA-402 at all (`Intl` is undefined), and `toLocaleString(…, {timeZone})`
// silently ignores the zone instead of throwing. A machine sitting in the
// requested zone makes that invisible.

export function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n)
}

/// `HH:MM` at [offsetMinutes] east of UTC. Done by arithmetic on the epoch
/// rather than by any locale API, for the reason in the file header.
export function clockAt(now: Date, offsetMinutes: number): string {
  const shifted = new Date(now.getTime() + offsetMinutes * 60000)
  return `${pad(shifted.getUTCHours())}:${pad(shifted.getUTCMinutes())}`
}

/// `+05:30`, `-08:00`, `UTC` — how an offset is written where a zone name
/// would normally go, so nothing implies knowledge this panel doesn't have.
export function offsetLabel(offsetMinutes: number): string {
  if (offsetMinutes === 0) return "UTC"
  const sign = offsetMinutes < 0 ? "-" : "+"
  const abs = Math.abs(offsetMinutes)
  return `UTC${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`
}

/// Accepts `-7`, `+5.5`, `+05:30`, `9`. Returns null for anything else,
/// which the panel reports rather than silently clocking at UTC.
export function parseOffset(raw: string): number | null {
  const text = raw.trim()
  if (!text) return null
  const colon = /^([+-]?)(\d{1,2}):([0-5]\d)$/.exec(text)
  if (colon) {
    // Same ceiling as the decimal branch. UTC+14 (Kiritimati) is the real
    // maximum; without this, `+25:30` parses happily and clocks a pane a
    // day and a bit into the future.
    if (Number(colon[2]) > 14) return null
    const minutes = Number(colon[2]) * 60 + Number(colon[3])
    return colon[1] === "-" ? -minutes : minutes
  }
  const decimal = /^([+-]?)(\d{1,2})(?:\.(\d{1,2}))?$/.exec(text)
  if (!decimal) return null
  const hours = Number(`${decimal[2]}.${decimal[3] ?? "0"}`)
  if (hours > 14) return null
  const minutes = Math.round(hours * 60)
  return decimal[1] === "-" ? -minutes : minutes
}

/// One `Label = offset` per line, e.g. `Tokyo = +9`. Lines that don't parse
/// are returned as errors rather than dropped — a clock the operator typed
/// and cannot see is worse than one that says what is wrong with it.
export function parseClocks(raw: string): { clocks: { label: string; offset: number }[]; bad: string[] } {
  const clocks: { label: string; offset: number }[] = []
  const bad: string[] = []
  for (const line of raw.split("\n")) {
    const text = line.trim()
    if (!text) continue
    const cut = text.lastIndexOf("=")
    const label = cut < 0 ? "" : text.slice(0, cut).trim()
    const offset = cut < 0 ? null : parseOffset(text.slice(cut + 1))
    if (!label || offset === null) {
      bad.push(text)
      continue
    }
    clocks.push({ label, offset })
  }
  return { clocks, bad }
}
