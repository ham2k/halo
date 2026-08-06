// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How old a cached reading is, in words. Shared by every panel that shows
// something it fetched, because the age is what separates "this is the
// weather" from "this WAS the weather, before you walked into a valley" —
// and a panel that cannot reach its source keeps rendering the last reading
// indefinitely.

/// Stays readable past an hour: "97 minutes ago" is true and useless at a
/// glance, and an hour is roughly where a fetched reading starts being
/// worth doubting.
export function readingAge(at: number, now: number = Date.now()): string {
  const minutes = Math.floor((now - at) / 60000)
  if (minutes < 1) return "just now"
  if (minutes === 1) return "1 minute ago"
  if (minutes < 60) return `${minutes} minutes ago`
  const hours = Math.floor(minutes / 60)
  if (hours === 1) return "over an hour ago"
  if (hours < 24) return `over ${hours} hours ago`
  return "over a day ago"
}
