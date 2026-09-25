// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host's rules for an extension's `host.fetch`: how long each phase may
// take, and whose User-Agent goes out.

/// The host's own allowances for a fetch, and the ceiling an extension's
/// `FetchOptions.timeout` is clamped to.
const fetchHeaderTimeout = Duration(seconds: 15);
const fetchBodyTimeout = Duration(seconds: 30);

/// How long this phase of a fetch may still take: what remains of the
/// caller's [requested] millisecond budget after [elapsed], capped at the
/// host's [ceiling] for the phase.
///
/// Downward only. An extension may declare a request not worth waiting the
/// default for; it may not award itself a longer leash than the host allows,
/// which is the whole reason the host sets one.
///
/// One budget for the whole call, not one per phase. Giving each phase the
/// full ask would let a 3s request take 3s waiting for headers and 3s more
/// reading the body — and 12s once the DNS retry doubles it — so a caller
/// that carefully bounded an optional request would still cost its fan-out
/// everything it was trying to save.
///
/// A zero or negative ask is a caller's bug rather than a request to fail
/// instantly, and falls back to [ceiling] rather than making every fetch
/// throw. A budget genuinely spent DOES return zero: the caller said how long
/// this was worth, and the request is already on the wire by then, so the
/// timeout has something real to interrupt.
Duration remainingFetchTimeout({required int? requested, required Duration elapsed, required Duration ceiling}) {
  if (requested == null || requested <= 0) return ceiling;
  final left = Duration(milliseconds: requested) - elapsed;
  if (left >= ceiling) return ceiling;
  return left.isNegative ? Duration.zero : left;
}

/// The `User-Agent` a `host.fetch` should send. HaLo's [canonical] UA wins,
/// so every request identifies the app consistently — *unless* the calling
/// [extensionKey] is in [overrides] (the manifest's `allowUserAgentOverride`)
/// and [callerHeaders] already carries a `User-Agent`, in which case that one
/// is kept. A whitelisted extension that sets none still gets [canonical], so
/// the request is never left unidentified. See docs/design/network.md.
String? resolveFetchUserAgent({
  required String? canonical,
  required String? extensionKey,
  required Set<String> overrides,
  required Map<String, String> callerHeaders,
}) {
  String? callerUA;
  for (final entry in callerHeaders.entries) {
    if (entry.key.toLowerCase() == 'user-agent') {
      callerUA = entry.value;
      break;
    }
  }
  final mayOverride = extensionKey != null && overrides.contains(extensionKey) && callerUA != null;
  if (mayOverride) return callerUA;
  return canonical ?? callerUA;
}
