// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading a LoFi rejection back out as something an operator can act on.
// Split from index.ts only so it can be tested without booting the
// extension host, the same way report.ts is.

import type { JSONValue } from "@ham2k/halo-extension-sdk"

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
