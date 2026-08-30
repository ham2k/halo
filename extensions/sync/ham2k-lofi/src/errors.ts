// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading a LoFi rejection back out as something an operator can act on.
// Split from index.ts only so it can be tested without booting the
// extension host, the same way report.ts is.

import type { JSONValue } from "@ham2k/extension-sdk"

import { LoFiRequestError } from "./backupCapture.ts"

/// The reports endpoint, shared so the request and the reading of its
/// rejection cannot name it differently.
export const REPORTS_PATH = 'v1/reports'


/// The human-readable complaint in a rejected response, or undefined when
/// there isn't one.
///
/// api-lofi answers in two shapes and the difference is not cosmetic: the
/// permission endpoints render a top-level `error` ("Permission not found"),
/// while the account endpoints render Rails' `errors.details` under
/// `account_errors` — `{ pending_email: [{ error: "in use by another
/// account" }] }`. Reading only the first shape turns every account
/// rejection into a bare "HTTP 422", and the two that matters most for are
/// exactly the two the email flow exists to report: an address already
/// taken, and a resend with nothing pending.
export function loFiErrorMessage(json: Record<string, JSONValue>): string | undefined {
  if (typeof json.error === 'string' && json.error) return json.error

  for (const [key, value] of Object.entries(json)) {
    // `account_errors`, `permission_errors`, and whatever the next
    // controller calls its own — the suffix is the convention, not the
    // prefix.
    if (!key.endsWith('_errors')) continue
    if (typeof value !== 'object' || value === null || Array.isArray(value)) continue

    for (const entries of Object.values(value as Record<string, JSONValue>)) {
      const first = Array.isArray(entries) ? entries[0] : entries
      if (typeof first !== 'object' || first === null || Array.isArray(first)) continue
      const message = (first as Record<string, JSONValue>).error
      // A validation that fails on a bare symbol (`validates_format_of`)
      // serializes as "invalid" — terse, but it names the problem, which
      // "HTTP 422" does not.
      if (typeof message === 'string' && message) return message
    }
  }
  return undefined
}

/// The server lower-cases and trims every address it stores
/// (`Account#normalize_email`), so a comparison against what we sent has to
/// do the same or a capitalized address reads as a rejected one. Returns
/// undefined for anything that isn't a non-empty string, so two absent
/// values never compare equal.
export function normalizedEmail(value: JSONValue | undefined): string | undefined {
  if (typeof value !== 'string') return undefined
  const normalized = value.trim().toLowerCase()
  return normalized || undefined
}

/// Whether a 2xx `/v1/sync` body is a reply the server actually wrote.
///
/// A trusted proxy, CDN error page, or maintenance page can answer 200 with
/// HTML, which `parseJson` turns into `{}` — and a `{}` handed back to
/// SyncEngine has no `error` field, so the engine would mark the whole
/// pushed batch synced on the word of a response the server never wrote.
/// Those QSOs would never push again; a later wipe or device loss makes
/// that permanent. The real reply always carries `success`, `meta` and
/// `account` (api-lofi SyncController#sync — its cooldown branch included),
/// so requiring any one of them costs a genuine reply nothing.
export function isRecognizableSyncResponse(response: {
  success?: boolean
  meta?: Record<string, JSONValue>
  account?: Record<string, JSONValue>
}): boolean {
  return response.success === true || response.meta != null || response.account != null
}

/// Whether a response body is garbage that `JSON.parse` refuses — the
/// signature of a proxy, CDN error page, or maintenance page answering a
/// 2xx it didn't earn. `parseJson` folds that case into `{}`, which most
/// endpoints then read as a valid-but-empty reply and PERSIST (the account
/// snapshot, for one) — so `request` treats it as a transport failure
/// instead. An empty body and a literal `{}` are not garbage: they are the
/// server actually saying nothing.
export function isUnparseableBody(body: string): boolean {
  if (body.trim() === '') return false
  try {
    JSON.parse(body)
    return false
  } catch {
    return true
  }
}

/// What to show an operator whose report did not reach the board.
///
/// `POST v1/reports` answers 404 for a client the server has no ACCOUNT
/// behind — the device registered fine, so the request is authenticated as a
/// client and refused as a stranger. That is the shape of every report filed
/// with sync switched on but this device never linked, which `syncEnabled`
/// alone cannot tell apart from a linked one; without this the operator is
/// handed "LoFi request failed: HTTP 404" for a problem they could have
/// fixed in Settings in a minute.
///
/// Matched on the ENDPOINT as well as the status, because `request()` will
/// register this client on the way through: a 404 from `v1/client` means the
/// configured server (`server` in kv, operator-settable) is not a LoFi
/// server at all, and sending that operator to the linking screen is worse
/// than the raw message they had.
///
/// Anything else keeps its own words: a 422's complaint, a network failure,
/// a proxy's garbage. They name real and different problems, and folding
/// them into the account message would send an operator to Settings to fix
/// an outage.
export function reportFailureMessage(error: unknown, needsAccountMessage: string): string {
  if (error instanceof LoFiRequestError && error.status === 404 && error.path === REPORTS_PATH) {
    return needsAccountMessage
  }
  return error instanceof Error ? error.message : String(error)
}
