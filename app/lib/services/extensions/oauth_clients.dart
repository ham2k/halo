// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OAuth clients Ham2K registered with a service, each bound to the one
// extension it was registered for. Such a client is public: its id and
// redirect are in the extension's code for anyone to copy, and the service
// issues tokens to whoever completes a sign-in with them. Without the binding,
// any extension that declares the service's host could start that sign-in and
// be handed the operator's tokens for it.
//
// The issuer and endpoints are the extension's to name, and one of its own
// can send the browser on to the service's sign-in. What the service answers
// to is the redirect its client is registered with, so that is bound too: a
// sign-in accepts a code only on the redirect it sent (`_doOAuth`,
// settings/accounts_panel.dart), and a registered client's redirects are its
// extension's alone. LoFi's relay is the one redirect every service shares,
// so there the code's `iss` (RFC 9207) is the binding: every service below
// sends it, and a sign-in refuses a code another issuer gave. A client added
// here for a service that sends no `iss` is open on Web, Linux and Windows.

import '../deep_link_service.dart';

/// The registered clients, by sign-in host and client id, to the key of the
/// extension each belongs to.
const _registeredClients = <({String host, String clientId}), String>{
  (host: 'sso.sota.org.uk', clientId: 'polo'): 'ham2k-sota',
  (host: 'spotterbot.ham2k.net', clientId: 'halo'): 'ham2k-discord-spotterbot',
};

/// The registered clients' redirects, by the host of the app's own
/// `com.ham2k.*.auth://` scheme, to the key of the extension each belongs to.
const _registeredRedirectHosts = <String, String>{'sota': 'ham2k-sota', 'spotterbot': 'ham2k-discord-spotterbot'};

/// The extension the OAuth client [clientId] was registered for at any of
/// [addresses] — a sign-in's issuer and the endpoints its discovery document
/// names — or null when Ham2K registered it at none of them, so any extension
/// may use it.
String? registeredOAuthClientOwner(Iterable<Uri> addresses, String clientId) {
  for (final address in addresses) {
    final owner = _registeredClients[(host: _host(address), clientId: clientId)];
    if (owner != null) return owner;
  }
  return null;
}

/// The extension whose registered client comes home on [redirectUrl], or
/// null for a redirect Ham2K registered for no one.
String? registeredOAuthRedirectOwner(String? redirectUrl) {
  final uri = redirectUrl == null ? null : Uri.tryParse(redirectUrl);
  if (uri == null || !DeepLinkService.isAuthCallback(uri)) return null;
  return _registeredRedirectHosts[_host(uri)];
}

/// [uri]'s host as a resolver reads it: any case, and a trailing dot names
/// the same host.
String _host(Uri uri) {
  final host = uri.host.toLowerCase();
  return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
}
