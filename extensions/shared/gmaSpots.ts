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
  const body = new URLSearchParams({
    yspotter: spotterCall,
    ycall: call,
    yreference: ref,
    yqrg: String(freq),
    ymode: mode ?? 'SSB',
    ycomment: comments.filter((c) => c).join(' '),
    B1: 'Submit',
  }).toString()

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

  const call = String(operation.stationCall ?? '')
  // The spotter is the base call even when spotting a portable — app-polo sends
  // `parseCallsign(call).baseCall`, and the endpoint rejects some suffixed
  // spotters outright.
  const baseCall = parseCallsign(call)?.baseCall ?? call
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
