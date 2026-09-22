// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ADIF states a coordinate in its Location data type — `XDDD MM.MMM`, a
// hemisphere letter, three digits of degrees, then minutes to three decimals
// — never as the signed decimal degrees QSON stores. `N041 22.500`, not
// `41.375`.

/// Formats a stored coordinate as an ADIF Location, or `undefined` for
/// anything that isn't a usable number — a missing value, a string a data file
/// left unparsed, or a magnitude outside the axis. Undefined is what `field()`
/// skips, so an unusable coordinate writes no ADIF field at all rather than a
/// malformed one.
export function formatAdifCoordinate(value: unknown, axis: "lat" | "lon"): string | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined
  const limit = axis === "lat" ? 90 : 180
  if (value < -limit || value > limit) return undefined

  const hemisphere = axis === "lat" ? (value < 0 ? "S" : "N") : value < 0 ? "W" : "E"
  const magnitude = Math.abs(value)
  let degrees = Math.floor(magnitude)
  let minutes = (magnitude - degrees) * 60

  // Rounding to the three decimals ADIF carries can push the minutes to a full
  // sixty (59.99999' becomes 60.000'), which is not a minute value ADIF can
  // state — carry it into the degrees instead of writing one.
  if (Number(minutes.toFixed(3)) >= 60) {
    degrees += 1
    minutes = 0
  }

  return `${hemisphere}${String(degrees).padStart(3, "0")} ${minutes.toFixed(3).padStart(6, "0")}`
}
