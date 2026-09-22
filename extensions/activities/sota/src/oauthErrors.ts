// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The `error` code from an OAuth error response, or null when [body] is not
/// one.
///
/// What tells a provider's OWN rejection apart from anything else that can
/// answer on that URL — a proxy's HTML error page, an edge rate limit, an
/// empty body. That difference decides whether a failed refresh clears the
/// account's session, so a bare status is not enough to act on: on web the
/// request passes through Ham2K's CORS proxy (halo_core's
/// `ham2kSsoFetchUri`), and a hop that is merely misconfigured must never
/// read as a revoked token.
export function oauthErrorCode(body: string): string | null {
  try {
    const parsed = JSON.parse(body) as Record<string, unknown>
    const error = parsed?.error
    return typeof error === "string" && error ? error : null
  } catch {
    return null
  }
}
