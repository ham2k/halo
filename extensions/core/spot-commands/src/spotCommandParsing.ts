// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing logic for the spotting call-field commands, split out from
// index.ts so it can be unit-tested without the extension-runtime globals
// `defineExtension` depends on — same convention as pota/sota's
// refFormatting.ts.

const SELF_SPOT_MATCH = /^(SPOT|SPOTME|SPME|SELFSPOT|QRV|QRT|QSY|QRX)(|[ /][\s\w\d!,.\-_]*)$/i
const LAST_SPOT_MATCH = /^(SPOTLAST|SPOTEM|SPOTTHEM|SPTHEM)$/i
const Q_CODES = new Set(["QRV", "QRT", "QSY", "QRX"])
const RESPOT_MATCH = /^RESPOT(?:\s+(.*))?$/i

/// Returns the comment to spot with (possibly empty string), or `null` if
/// `input` doesn't match a self-spot command at all. A Q-code trigger
/// (QRV/QRT/QSY/QRX) becomes the first word of the comment; a plain
/// SPOT/SPOTME/SPME/SELFSPOT trigger contributes nothing of its own —
/// matches app-polo's MiscCommands.js.
export function parseSelfSpotCommand(input: string): { comment: string } | null {
  const match = SELF_SPOT_MATCH.exec(input.trim())
  if (!match) return null
  const [, trigger, rest] = match
  const upperTrigger = trigger.toUpperCase()
  const freeText = rest ? rest.slice(1) : "" // drop the leading space/slash separator
  const comment = Q_CODES.has(upperTrigger) ? [upperTrigger, freeText].filter((x) => x).join(" ") : freeText
  return { comment }
}

export function isLastSpotCommand(input: string): boolean {
  return LAST_SPOT_MATCH.test(input.trim())
}

/// RESPOT's defaults: the same ten minutes the Spotting control offers, a
/// floor that keeps a public spot cluster from being flooded, and a ceiling
/// past which a spot has aged off the clusters anyway. The app holds to the
/// same bounds whatever an action asks for.
export const RESPOT_DEFAULT_MINUTES = 10
export const RESPOT_MIN_MINUTES = 5
export const RESPOT_MAX_MINUTES = 60

/// What RESPOT asks for: auto-respotting every `minutes` (bare RESPOT is the
/// default; outside the bounds is the nearest bound), or `off` (RESPOT OFF,
/// RESPOT 0). `invalid` for a parameter that is neither, `null` for input
/// that isn't RESPOT at all.
export function parseRespotCommand(input: string): { minutes: number } | { off: true } | { invalid: true } | null {
  const match = RESPOT_MATCH.exec(input.trim())
  if (!match) return null
  const param = (match[1] ?? "").trim()
  if (!param) return { minutes: RESPOT_DEFAULT_MINUTES }
  if (/^OFF$/i.test(param)) return { off: true }
  if (!/^\d+$/.test(param)) return { invalid: true }
  const minutes = Number(param)
  return minutes === 0 ? { off: true } : { minutes: Math.min(RESPOT_MAX_MINUTES, Math.max(RESPOT_MIN_MINUTES, minutes)) }
}
