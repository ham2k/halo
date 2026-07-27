// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// Copyright ©️ 2024 Steven Hiscocks <steven@hiscocks.me.uk>
// SPDX-License-Identifier: MPL-2.0
//
// cqgma.org's spot endpoint, which several unrelated award programs post
// through: GMA itself plus the castle, lighthouse and mill awards that use its
// infrastructure — `bca`, `blha`, `eca`, `ela`, `mota`, `wca`. Ported once from
// app-polo's `gma/GMAPostSpotAPI.js` + `GMACommonPostSelfSpot.js` and imported
// by relative path, the way the contests share their Cabrillo writer.
//
// Lives outside any extension directory because no single one of them owns it.
// `build.mjs` lists its bundles explicitly, so nothing here is mistaken for an
// extension.
//
// The endpoint is a form POST that answers 200 for both success and most
// failures, so a non-200 is the only signal there is.

import { parseCallsign } from "@ham2k/lib-callsigns"
import { host } from "@ham2k/halo-extension-sdk"
import type { PostResult, Ref } from "@ham2k/halo-extension-sdk"

const GMA_SPOT_URL = 'https://www.cqgma.org/spotsmart2.php'

/// `application/x-www-form-urlencoded`, by hand.
///
/// QuickJS has no `URLSearchParams` — it is a Web API, not part of the
/// language — and reaching for it here threw `URLSearchParams is not defined`
/// at the first real spot. Spaces become `+` rather than `%20`, matching what
/// app-polo's `URLSearchParams` produced and what the endpoint has always been
/// fed.
export function formEncode(fields: Record<string, string>): string {
  return Object.entries(fields)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v).replace(/%20/g, '+')}`)
    .join('&')
}

/// The first of these that holds something, trimmed.
///
/// `??` is not enough for any of the callsigns below: the core hands over an
/// EMPTY STRING as readily as it omits a key — `models.dart`'s `ourCall` getter
/// coerces a null column to `''` — and `'' ?? fallback` is `''`. That silently
/// posted a spot with no spotter, which reads on the cluster as a spot nobody
/// sent.
function firstNonEmpty(...values: unknown[]): string {
  for (const value of values) {
    const text = value == null ? '' : String(value).trim()
    if (text) return text
  }
  return ''
}

export interface GmaSpotRequest {
  /// The station being spotted.
  call: string
  /// Who is doing the spotting — for a self-spot, app-polo sends the BASE call
  /// even when the spotted call carries a portable suffix.
  spotterCall: string
  /// The award reference being spotted. Only one: the endpoint takes a single
  /// reference, so any others go in the comment.
  ref: string
  freq: number
  mode?: string
  comments?: (string | undefined)[]
  /// Overridden by the handful of programs that run their own instance of this
  /// endpoint rather than posting to cqgma.org.
  url?: string
}

export async function postSpotToGMA(
  { call, spotterCall, ref, freq, mode, comments = [], url }: GmaSpotRequest,
): Promise<PostResult> {
  const body = formEncode({
    yspotter: spotterCall,
    ycall: call,
    yreference: ref,
    yqrg: String(freq),
    ymode: mode ?? 'SSB',
    ycomment: comments.filter((c) => c).join(' '),
    B1: 'Submit',
  })

  try {
    const response = await host.fetch(url ?? GMA_SPOT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    })
    if (response.status !== 200) {
      return { ok: false, message: `GMA API returned HTTP ${response.status}` }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) }
  }
}

/// Self-spotting for an activation. The FIRST reference is the one spotted;
/// any others are named in the comment, since the endpoint takes one.
export async function postSelfSpotToGMA(
  { operation, refs, freq, mode, comment, url }: {
    operation: Record<string, unknown>
    refs: Ref[]
    freq: number
    mode?: string
    comment?: string
    url?: string
  },
): Promise<PostResult> {
  if (refs.length === 0) return { ok: false, message: 'No reference to spot' }

  const call = firstNonEmpty(operation.stationCall)
  if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
  // The spotter is the base call even when spotting a portable — app-polo sends
  // `parseCallsign(call).baseCall`, and the endpoint rejects some suffixed
  // spotters outright.
  const baseCall = firstNonEmpty(parseCallsign(call)?.baseCall, call)
  const others = refs.length > 1 ? `also ${refs.slice(1).map((r) => r.ref).join(' ')}` : undefined

  return postSpotToGMA({
    call,
    spotterCall: baseCall,
    ref: refs[0].ref!,
    freq,
    mode,
    comments: [comment, others],
    url,
  })
}

/// Spotting somebody else at a reference you hunted. Same one-reference rule as
/// self-spotting: the first is spotted, the rest are named in the comment.
export async function postOtherSpotToGMA(
  { qso, refs, comment, spotterCall, url }: {
    qso: Record<string, unknown>
    refs: Ref[]
    comment?: string
    spotterCall?: string
    url?: string
  },
): Promise<PostResult> {
  if (refs.length === 0) return { ok: false, message: 'No reference to spot' }

  const their = (qso.their ?? {}) as Record<string, unknown>
  const our = (qso.our ?? {}) as Record<string, unknown>
  const freq = Number(qso.freq)
  if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }

  // Guarded like the frequency above, and for the same reason: a spot naming no
  // station is worse than no spot, because it reaches everybody watching.
  const call = firstNonEmpty(their.call)
  if (!call) return { ok: false, message: 'This QSO has no callsign to spot' }

  const others = refs.length > 1 ? `also ${refs.slice(1).map((r) => r.ref).join(' ')}` : undefined

  return postSpotToGMA({
    call,
    // An in-progress QSO has no `our.call` yet, so the caller's own callsign is
    // the fallback — app-polo's comment on the same line.
    spotterCall: firstNonEmpty(our.call, spotterCall),
    ref: refs[0].ref!,
    freq,
    mode: qso.mode ? String(qso.mode) : undefined,
    comments: [comment, others],
    url,
  })
}
