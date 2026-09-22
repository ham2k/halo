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
