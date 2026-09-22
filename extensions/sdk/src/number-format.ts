// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `Number.prototype.toLocaleString` for engines without Intl.
//
// QuickJS-NG ships no Intl at all, and wires toLocaleString straight to
// Number.prototype.toString — so it silently ignores BOTH arguments. Every
// number an extension renders goes through `fmtInteger`/`fmtOneDecimal` in
// @ham2k/lib-format-tools, which are `n.toLocaleString('en-US', {...})`, so
// without this a 1,500-QSO tally reads "1500 QSOs" and a contest score reads
// "345320". docs/extensions/README.md documents thousands separators as the
// expected behaviour and names fmtInteger as the way to get them.
//
// Deliberately NOT an `Intl` shim. i18next activates its own Formatter on
// `typeof Intl !== "undefined"` (kernel.js:5788) and then calls into
// Intl.NumberFormat/DateTimeFormat/PluralRules. Defining a partial Intl would
// turn today's quiet degradation of `{{v, datetime}}` into a thrown
// ReferenceError that fails the whole hook. Patching the one method that is
// actually used keeps that door shut.
//
// en-US only, and that is faithful rather than lazy: the locale reaching
// toLocaleString has always been the hardcoded 'en-US' literal inside
// lib-format-tools — `navigator` is undefined in every engine we run, so no
// engine has ever done locale-aware formatting here.

export interface NumberFormatOptions {
  minimumFractionDigits?: number
  maximumFractionDigits?: number
  useGrouping?: boolean
}

/// Rounds to `digits` decimals the way Intl does — half-expand on the number's
/// SHORTEST DECIMAL REPRESENTATION, not on the binary double.
///
/// That distinction is the whole reason this helper exists. `toFixed` rounds
/// the underlying binary value, so it disagrees with Intl on every input whose
/// decimal form has a 5 immediately past the last kept digit — 12.35 → "12.3"
/// where Intl gives "12.4", 1.005 → "1.00" where Intl gives "1.01". Measured
/// against real Intl, `toFixed` diverges on ~4% of two-decimal values at
/// {min:1,max:1}. `String(n)` gives exactly the shortest representation Intl
/// rounds, so doing the arithmetic on that string agrees by construction.
function roundHalfExpand(absolute: number, digits: number): string {
  const source = String(absolute)
  // Exponential form (very small values); rare here and not worth reproducing
  // by hand, so defer to the engine rather than get it subtly wrong.
  if (source.includes("e") || source.includes("E")) return absolute.toFixed(digits)

  const dot = source.indexOf(".")
  const whole = dot < 0 ? source : source.slice(0, dot)
  const fraction = dot < 0 ? "" : source.slice(dot + 1)

  if (fraction.length <= digits) {
    const padded = fraction.padEnd(digits, "0")
    return digits === 0 ? whole : `${whole}.${padded}`
  }

  let kept = whole + fraction.slice(0, digits)
  if (fraction.charCodeAt(digits) - 48 >= 5) {
    // Increment the kept digits as one decimal integer, carrying as needed —
    // 9.9995 to 3 digits has to become 10.000, not 9.9990 + 1.
    const chars = kept.split("")
    let i = chars.length - 1
    for (;;) {
      if (i < 0) {
        chars.unshift("1")
        break
      }
      if (chars[i] === "9") {
        chars[i] = "0"
        i--
      } else {
        chars[i] = String(Number(chars[i]) + 1)
        break
      }
    }
    kept = chars.join("")
  }

  const split = kept.length - digits
  const wholeOut = kept.slice(0, split) || "0"
  return digits === 0 ? wholeOut : `${wholeOut}.${kept.slice(split)}`
}

/// Formats `n` the way Intl would for en-US, for the option subset we use.
/// Exported so it can be tested directly — the installer below is a no-op on
/// Node and on the web, where a real implementation already exists.
export function formatNumberEnUS(n: number, options?: NumberFormatOptions): string {
  if (!Number.isFinite(n)) return String(n)

  // At 1e21 and above JS switches to exponential notation. Intl expands it in
  // full; reproducing that faithfully is a lot of code for values no amateur
  // radio tally reaches, so defer to the engine rather than print something
  // subtly different.
  if (Math.abs(n) >= 1e21) return String(n)

  const minimum = options?.minimumFractionDigits ?? 0
  // Intl's own default for a plain decimal is 3, not 0.
  let maximum = options?.maximumFractionDigits ?? Math.max(minimum, 3)
  if (maximum < minimum) maximum = minimum

  const negative = n < 0 // -0 formats as "0", matching the common expectation
  const absolute = Math.abs(n)

  let text = roundHalfExpand(absolute, maximum)
  if (maximum > minimum) {
    // Trim back to `minimum`, the way Intl does.
    text = text.replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
    const dot = text.indexOf(".")
    const decimals = dot < 0 ? 0 : text.length - dot - 1
    if (decimals < minimum) {
      text = (dot < 0 ? `${text}.` : text) + "0".repeat(minimum - decimals)
    }
  }

  const parts = text.split(".")
  if (options?.useGrouping !== false) {
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }
  const out = parts.join(".")
  return negative ? `-${out}` : out
}

/// Installs the polyfill only where it is needed.
///
/// Feature-tested by BEHAVIOUR, not by `typeof Intl`: the check is whether the
/// engine honours the options bag at all. That keeps the real implementation
/// on the web runtime (a Worker, with full Intl) and on any future engine that
/// grows one, instead of replacing a correct implementation with this subset.
export function installNumberFormatPolyfill(): void {
  const engineFormats = (1234.5).toLocaleString("en-US", { maximumFractionDigits: 0 }) === "1,235"
  if (engineFormats) return

  // eslint-disable-next-line no-extend-native
  Number.prototype.toLocaleString = function (this: number, _locales?: unknown, options?: NumberFormatOptions): string {
    return formatNumberEnUS(Number(this), options)
  }
}
