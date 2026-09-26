// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host's rules for an extension's `host.fetch`: where it goes, how long
// each phase may take, and whose User-Agent goes out.

import 'package:halo_core/halo_core.dart' show ham2kProxyHost, ham2kSsoFetchUri, sotaSsoHost;

/// Hosts a WEB build reaches through services.ham2k.net at
/// `https://services.ham2k.net/<host>/…`, because none of them answers a
/// browser's cross-origin request. Kept in step with that Worker's
/// `config.yaml` BY HAND — and some are routed there for one file only, so
/// any other path on them answers 404 from the proxy, not from the source.
///
/// Narrower than the data-file list in the app's DataFileManager: the other
/// hosts there serve a reference file and nothing else.
const servicesProxiedHosts = {
  'api.pota.app',
  'logbook.qrz.com',
  'xmldata.qrz.com',
  'country-files.com',
  'pota.app',
  'www.sotadata.org.uk',
  'sotadata.org.uk',
  'www.hamqsl.com',
  'llota.app',
  // Spot feeds and self-spotting on hosts that send no CORS headers. The
  // remaining spot sources (spots.wwff.co, api-db2.sota.org.uk,
  // api.open-meteo.com, api.wwbota.org, LoFi) answer cross-origin GETs
  // directly.
  'www.cqgma.org',
  'ontheair.nz',
  'www.rozhledny.eu',
  'www.parksnpeaks.org',
  'mobiletracker.stateqso.com',
};

/// Hosts that serve plain http only, which EVERY build reaches through
/// services.ham2k.net — the host fetches https only, and the proxy is their
/// https front door. Same by-hand pact with the Worker's `config.yaml`.
///
/// Deliberately not every proxied host: a native build fetches those
/// directly, so an `http://` typo for one of them is refused rather than
/// quietly detoured through Ham2K infrastructure along with whatever
/// credentials the request carries.
const servicesHttpOnlyHosts = {'qsopartyhub.com'};

/// [uri] as this build must fetch it: through the proxy for an http-only
/// host, and on web for a proxied one; unchanged everywhere else, for the
/// https check to refuse if it is plain http.
///
/// SOTA's SSO host routes by PATH, not by host, and only on web — see
/// halo_core's [ham2kSsoFetchUri] for why the rest of that host stays direct.
Uri extensionFetchUri(Uri uri, {required bool onWeb}) {
  if (onWeb && uri.host == sotaSsoHost) return ham2kSsoFetchUri(uri, onWeb: true);
  if (servicesHttpOnlyHosts.contains(uri.host) || (onWeb && servicesProxiedHosts.contains(uri.host))) {
    return Uri.parse('https://$ham2kProxyHost/${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
  }
  return uri;
}

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
