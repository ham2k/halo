// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing logic for the spotting call-field commands, split out from
// index.ts so it can be unit-tested without the extension-runtime globals
// `defineExtension` depends on — same convention as pota/sota's
// refFormatting.ts.

const SELF_SPOT_MATCH = /^(SPOT|SPOTME|SPME|SELFSPOT|QRV|QRT|QSY|QRX)(|[ /][\s\w\d!,.:\-_]*)$/i
const LAST_SPOT_MATCH = /^(SPOTLAST|SPOTEM|SPOTTHEM|SPTHEM)(|[ /][\s\w\d!,.:\-_]*)$/i
const Q_CODES = new Set(["QRV", "QRT", "QSY", "QRX"])
/// A spot source named first, `pota:` in `SPOT pota: hunters first`: one word
/// stuck to its colon, starting with a letter as a hook key does. A colon
/// anywhere later (`SPOT back at 14:30`) is prose.
const SOURCE_PREFIX = /^([a-z][\w-]*):\s*(.*)$/is
const RESPOT_MATCH = /^RESPOT(?:\s+(.*))?$/i
const CLUSTER_MATCH = /^CLUSTER$/i

/// What a spot command says: the comment to spot with (possibly empty), and
/// the one spot source it names, when it does.
export interface SpotCommand {
  comment: string
  source?: string
}

/// The source a spot's text names first ([SOURCE_PREFIX]), split from the
/// rest. As typed: the app matches it against the sources on offer.
function splitSource(text: string): { source?: string; text: string } {
  const match = SOURCE_PREFIX.exec(text)
  return match ? { source: match[1], text: match[2] } : { text }
}

/// Returns the comment to spot with (possibly empty string), or `null` if
/// `input` doesn't match a self-spot command at all. A Q-code trigger
/// (QRV/QRT/QSY/QRX) becomes the first word of the comment; a plain
/// SPOT/SPOTME/SPME/SELFSPOT trigger contributes nothing of its own —
/// matches app-polo's MiscCommands.js. A source named first (`QRV pota:
/// hunters first`) is `source`, and no part of the comment.
export function parseSelfSpotCommand(input: string): SpotCommand | null {
  const match = SELF_SPOT_MATCH.exec(input.trim())
  if (!match) return null
  const [, trigger, rest] = match
  const upperTrigger = trigger.toUpperCase()
  const { source, text: freeText } = splitSource(rest ? rest.slice(1).trim() : "") // drop the leading space/slash separator
  const comment = Q_CODES.has(upperTrigger) ? [upperTrigger, freeText].filter((x) => x).join(" ") : freeText
  return source ? { comment, source } : { comment }
}

/// Returns the comment to spot the last QSO with (possibly empty string), or
/// `null` if `input` doesn't match SPOTLAST or its aliases. The comment
/// follows a space or a slash, as SPOT's does, and names a source first the
/// same way.
export function parseLastSpotCommand(input: string): SpotCommand | null {
  const match = LAST_SPOT_MATCH.exec(input.trim())
  if (!match) return null
  const rest = match[2]
  const { source, text: comment } = splitSource(rest ? rest.slice(1).trim() : "")
  return source ? { comment, source } : { comment }
}

/// RESPOT's bounds: a floor that keeps a public spot cluster from being
/// flooded, and a ceiling past which a spot has aged off the clusters anyway.
/// The app holds to the same bounds whatever an action asks for.
export const RESPOT_MIN_MINUTES = 5
export const RESPOT_MAX_MINUTES = 60

/// What RESPOT asks for: auto-respotting every `minutes` (outside the bounds
/// is the nearest bound), with no `minutes` at all for bare RESPOT — the
/// operator's own interval, a setting only the app knows — or `off` (RESPOT
/// OFF, RESPOT 0). `invalid` for a parameter that is neither, `null` for
/// input that isn't RESPOT at all.
export function parseRespotCommand(input: string): { minutes?: number } | { off: true } | { invalid: true } | null {
  const match = RESPOT_MATCH.exec(input.trim())
  if (!match) return null
  const param = (match[1] ?? "").trim()
  if (!param) return {}
  if (/^OFF$/i.test(param)) return { off: true }
  if (!/^\d+$/.test(param)) return { invalid: true }
  const minutes = Number(param)
  return minutes === 0 ? { off: true } : { minutes: Math.min(RESPOT_MAX_MINUTES, Math.max(RESPOT_MIN_MINUTES, minutes)) }
}

/// CLUSTER, the whole word and nothing after it.
export function isClusterCommand(input: string): boolean {
  return CLUSTER_MATCH.test(input.trim())
}
