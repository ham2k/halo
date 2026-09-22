// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Which SOTA SSO calls a WEB build makes through Ham2K's CORS reverse proxy
/// (services.ham2k.net) instead of straight at Keycloak.
///
/// Only browsers need this. SOTA's Keycloak stamps
/// `Access-Control-Allow-Origin` on these endpoints from the `polo` client's
/// "Web Origins" field, which is empty, so a browser fetch fails with a bare
/// "Failed to fetch" while the authorization leg — a navigation, not a fetch
/// — succeeds. Native builds call SOTA directly and must keep doing so.
library;

const ham2kProxyHost = 'services.ham2k.net';

const sotaSsoHost = 'sso.sota.org.uk';

/// The SOTA SSO paths services.ham2k.net actually routes, kept in step with
/// that Worker's `config.yaml` BY HAND — a path named here that it does not
/// route answers 404 instead of reaching Keycloak.
///
/// Deliberately two exact paths rather than the host: proxying puts SOTA
/// access and refresh tokens through Ham2K infrastructure, which this app's
/// original design kept them out of. The authorization CODE may transit us
/// — LoFi's webhook relay receives it on web, and PKCE leaves it useless
/// without the verifier the browser holds — but the tokens it buys are a
/// different thing, and every path added here widens what else can pass. The
/// discovery document is CORS-open at the source, so it must NOT be listed.
const sotaProxiedSsoPaths = {'/auth/realms/SOTA/protocol/openid-connect/token', '/auth/realms/SOTA/account'};

/// [uri] as this build must fetch it: through the proxy where a browser would
/// otherwise be refused, unchanged everywhere else.
Uri ham2kSsoFetchUri(Uri uri, {required bool onWeb}) {
  if (!onWeb) return uri;
  if (uri.host != sotaSsoHost) return uri;
  if (!sotaProxiedSsoPaths.contains(uri.path)) return uri;
  return Uri.parse('https://$ham2kProxyHost/${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
}
