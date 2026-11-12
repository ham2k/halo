// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Requests the app makes FOR an extension — a data file, a reference's
// outline — held to the rule `host.fetch` is held to (docs/design/network.md,
// "One rule for every request an extension causes"). The install screen
// tells the operator an extension reaches nothing beyond what it lists, and
// a URL the extension names is the extension reaching, whoever sends it.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:halo_extension_host/halo_extension_host.dart'
    show ExtensionUrlRefusal, allowlistNamesHost, extensionFetchUri, extensionUrlRefusal, fetchHopGuarded, guardedFetchClient, kMaxFetchRedirects;
import 'package:http/http.dart' as http;

/// What an extension may have the app reach for it: the hosts its manifest
/// declares, whether its data files may go to any public host
/// (`requiresAnyDataFileUrl`), and whether developer mode opens the local
/// network.
class ExtensionNetworkGrant {
  const ExtensionNetworkGrant({required this.extensionKey, this.domains = const [], this.anyDataFileHost = false, this.developerMode = false});

  final String extensionKey;
  final List<String> domains;
  final bool anyDataFileHost;
  final bool developerMode;

  /// Why [url] may not be the address the extension named, or null when it
  /// may. [dataFile] for a data file's own address, which
  /// [anyDataFileHost] opens to every public host.
  ExtensionUrlRefusal? refusal(Uri url, {bool dataFile = false}) =>
      extensionUrlRefusal(url, domains: domains, developerMode: developerMode, anyHost: dataFile && anyDataFileHost);

  /// Why a redirect to [url] may not be followed. The extension chose only
  /// the first address; where its server sends the request next is held to
  /// https and kept off the local network, but not to [domains], which
  /// would refuse every file host that answers from a download host of its
  /// own.
  ExtensionUrlRefusal? redirectRefusal(Uri url) => extensionUrlRefusal(url, domains: domains, developerMode: developerMode, anyHost: true);

  /// Whether a request to [url] goes out on the guarded transport, which
  /// judges what the name resolves to as well as its spelling.
  bool guarded(Uri url) => fetchHopGuarded(developerMode: developerMode, namedHost: allowlistNamesHost(domains, url.host));
}

/// What becomes of a lookup's photo (ExtensionService.lookupPhoto).
enum LookupPhoto {
  /// On a host an extension declared: shown as it arrives.
  loads,

  /// On a public https host no extension declared: shown when the operator
  /// asks, naming the host.
  asks,

  /// Plain http, the local network, or no address: never fetched.
  refused,
}

/// A request refused before it was sent: [url] is not one the extension may
/// have the app reach.
class ExtensionUrlRefused implements Exception {
  const ExtensionUrlRefused(this.extensionKey, this.url, this.reason);

  final String extensionKey;
  final Uri url;
  final ExtensionUrlRefusal reason;

  @override
  String toString() => switch (reason) {
    ExtensionUrlRefusal.undeclared => "'${url.host}' is not in extension '$extensionKey's declared domains",
    ExtensionUrlRefusal.localNetwork => "'${url.host}' is on the local network, which extension '$extensionKey' has not named",
    ExtensionUrlRefusal.notHttps => "'$url' is not https",
  };
}

/// The client a request goes out on, [guarded] when [ExtensionNetworkGrant.guarded]
/// says so. Injectable, so a test answers requests without a network.
typedef ExtensionClientFactory = http.Client Function({required bool guarded});

http.Client defaultExtensionClient({required bool guarded}) => guarded ? guardedFetchClient() : http.Client();

/// The client a data file downloads on: an [ExtensionClient] under [grant],
/// judged on the address the extension [named], or the app's own for an
/// address that is the app's ([grant] null).
http.Client dataFileClient(ExtensionNetworkGrant? grant, {Uri? named, required ExtensionClientFactory clients, required bool onWeb}) =>
    grant == null ? clients(guarded: false) : ExtensionClient(grant, named: named, dataFile: true, clients: clients, onWeb: onWeb);

/// An [http.Client] that sends only what [grant] admits, following redirects
/// itself so each hop is judged: the first by
/// [ExtensionNetworkGrant.refusal], the rest by
/// [ExtensionNetworkGrant.redirectRefusal]. A browser follows redirects out
/// of the app's sight, so on web only the first is judged, by spelling.
///
/// Sends an [http.Request] only, which is every request the app makes for
/// an extension; a 303, or a 301 or 302 to a POST, continues as a GET.
class ExtensionClient extends http.BaseClient {
  ExtensionClient(this.grant, {this.named, this.dataFile = false, this.clients = defaultExtensionClient, this.onWeb = kIsWeb});

  final ExtensionNetworkGrant grant;

  /// The address the extension named, judged in place of the first hop's
  /// when the app rewrote it on the way: a share link turned into its
  /// download form, a host sent through the Ham2K proxy. What the extension
  /// chose is what its grant covers; the rewrite is the app's.
  final Uri? named;

  /// Whether this sends a data file, which [ExtensionNetworkGrant.anyDataFileHost]
  /// lets reach any public host.
  final bool dataFile;

  final bool onWeb;

  /// Where each hop's client comes from.
  final ExtensionClientFactory clients;
  final List<http.Client> _open = [];

  static const _redirects = {301, 302, 303, 307, 308};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request) throw ArgumentError('ExtensionClient sends an http.Request, not a ${request.runtimeType}');
    var current = request;
    for (var hop = 0; ; hop++) {
      final url = current.url;
      final refusal = hop == 0 ? grant.refusal(named ?? url, dataFile: dataFile) : grant.redirectRefusal(url);
      if (refusal != null) throw ExtensionUrlRefused(grant.extensionKey, hop == 0 ? named ?? url : url, refusal);
      final client = clients(guarded: !onWeb && grant.guarded(url));
      _open.add(client);
      // Sent where the refusal judged it: a plain-http host the Ham2K proxy
      // fronts passed as https because it goes out through the proxy, and
      // sent as spelled it would cross the network in the clear.
      final response = await client.send(_copy(current, url: extensionFetchUri(url, onWeb: false), followRedirects: onWeb));
      final location = response.headers['location'];
      if (onWeb || !_redirects.contains(response.statusCode) || location == null) return response;
      await response.stream.drain<void>();
      if (hop >= kMaxFetchRedirects) throw http.ClientException('more than $kMaxFetchRedirects redirects', url);
      final asGet = response.statusCode == 303 || ((response.statusCode == 301 || response.statusCode == 302) && current.method == 'POST');
      final next = url.resolve(location);
      current = _copy(current, url: next, method: asGet ? 'GET' : current.method, keepBody: !asGet);
      // A credential meant for one host is not sent on to another.
      if (next.host != url.host) current.headers.removeWhere((name, _) => name.toLowerCase() == 'authorization');
    }
  }

  http.Request _copy(http.Request from, {Uri? url, String? method, bool keepBody = true, bool followRedirects = false}) {
    final copy = http.Request(method ?? from.method, url ?? from.url)
      ..headers.addAll(from.headers)
      ..followRedirects = followRedirects
      ..persistentConnection = from.persistentConnection;
    if (keepBody && from.bodyBytes.isNotEmpty) copy.bodyBytes = from.bodyBytes;
    return copy;
  }

  @override
  void close() {
    for (final client in _open) {
      client.close();
    }
    _open.clear();
  }
}

/// The endpoints of an extension's OAuth sign-in, each checked against its
/// grant ([oauthEndpointsFrom]).
typedef OAuthEndpoints = ({Uri authorization, Uri token});

/// [url], an OAuth address the extension named or its issuer's discovery
/// document did, when [grant] reaches it; [ExtensionUrlRefused] otherwise.
///
/// The app runs the sign-in itself — it fetches the discovery document,
/// opens the browser on the authorization endpoint and posts the code to the
/// token endpoint — so each is a request the extension causes, held to its
/// declared `domains`, https and the public internet: an issuer the operator
/// saw on the install screen, and nothing else (docs/extensions/accounts.md).
Uri checkedOAuthUrl(String url, ExtensionNetworkGrant grant) {
  final uri = Uri.parse(url);
  final refusal = grant.refusal(uri);
  if (refusal != null) throw ExtensionUrlRefused(grant.extensionKey, uri, refusal);
  return uri;
}

/// The authorization and token endpoints [discovery] names for [issuer],
/// both checked by [checkedOAuthUrl]. The document must name [issuer] as its
/// own (OpenID Connect Discovery §4.3): one served for another issuer is
/// not this sign-in's.
OAuthEndpoints oauthEndpointsFrom({required String issuer, required Map<String, dynamic> discovery, required ExtensionNetworkGrant grant}) {
  String trimmed(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  final named = discovery['issuer'];
  if (named is! String || trimmed(named) != trimmed(issuer)) {
    throw FormatException("OIDC discovery for '$issuer' names another issuer: '$named'");
  }
  final authorization = discovery['authorization_endpoint'];
  final token = discovery['token_endpoint'];
  if (authorization is! String || token is! String) throw FormatException("OIDC discovery for '$issuer' names no authorization or token endpoint");
  return (authorization: checkedOAuthUrl(authorization, grant), token: checkedOAuthUrl(token, grant));
}
