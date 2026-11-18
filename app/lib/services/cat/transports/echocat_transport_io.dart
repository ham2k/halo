// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../transport.dart';
import 'echocat_transport_config.dart';
import 'websocket_transport_io.dart';

const _timeout = Duration(seconds: 5);

class EchocatTransport extends EchocatTransportConfig {
  const EchocatTransport();

  @override
  Future<EchocatCredentials> pair(String link) async {
    final pairing = parseEchocatPairingLink(link);
    final strings = t.settings.station;
    if (pairing == null) throw EchocatFailure(strings.echocatInvalidLink);

    // The server exchanges this single-use link token for a device token.
    // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/lib/remote-server.js#L2692-L2783
    var certificateFailed = false;
    for (final endpoint in pairing.endpoints) {
      final client = _clientFor(endpoint);
      try {
        final uri = endpoint.uri.replace(scheme: 'https', port: endpoint.uri.port, path: '/api/pair');
        final request = await client.postUrl(uri).timeout(_timeout);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'pairingToken': pairing.token, 'deviceName': 'HaLo', 'devicePlatform': Platform.operatingSystem}));
        final response = await request.close().timeout(_timeout);
        if (response.statusCode == HttpStatus.unauthorized || response.statusCode == HttpStatus.forbidden) {
          throw EchocatFailure(strings.echocatPairingRefused);
        }
        if (response.statusCode != HttpStatus.ok) continue;
        final body = await utf8.decoder.bind(response).join().timeout(_timeout);
        if (jsonDecode(body) case {'deviceToken': final String token} when token.isNotEmpty) {
          return EchocatCredentials(token, [endpoint, ...pairing.endpoints.where((candidate) => candidate != endpoint)]);
        }
      } on HandshakeException {
        certificateFailed = true;
      } on SocketException {
        // Try the other address from the link.
      } on HttpException {
        // Try the other address from the link.
      } on TimeoutException {
        // Try the other address from the link.
      } on FormatException {
        // An endpoint serving a different protocol cannot pair a device.
      } finally {
        client.close(force: true);
      }
    }
    throw EchocatFailure(certificateFailed ? strings.echocatCertificateMismatch : strings.echocatUnreachable);
  }

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final strings = t.settings.station;
    final credentials = EchocatCredentials.decode(target[echocatPairingKey] as String? ?? '');
    if (credentials == null) throw EchocatFailure(strings.echocatPairingRequired);
    var certificateFailed = false;
    for (final endpoint in credentials.endpoints) {
      if (cancel.isCancelled) throw const CatCancelledException();
      try {
        return await _connect(endpoint, credentials.token, cancel);
      } on HandshakeException {
        certificateFailed = true;
      } on SocketException {
        // Try the other address in the pairing.
      } on HttpException {
        // Try the other address in the pairing.
      } on WebSocketException {
        // Try the other address in the pairing.
      } on TimeoutException {
        // Try the other address in the pairing.
      }
    }
    throw EchocatFailure(certificateFailed ? strings.echocatCertificateMismatch : strings.echocatUnreachable);
  }

  Future<EquipmentConnection> _connect(EchocatEndpoint endpoint, String token, CatCancelToken cancel) async {
    final client = _clientFor(endpoint);
    _EchocatConnection? connection;
    var ended = false;
    var connected = false;

    Future<EquipmentConnection> open() async {
      final socket = await WebSocket.connect(endpoint.uri.toString(), customClient: _DirectUpgradeClient(client));
      if (ended) {
        unawaited(socket.close().then((_) {}, onError: (Object _) {}));
        throw const CatCancelledException();
      }
      socket.pingInterval = const Duration(seconds: 15);
      final authorized = Completer<void>();
      var passed = false;
      final wrapping = connection = _EchocatConnection(
        socket,
        routeText: (frame) {
          if (!passed && authorized.isCompleted) return WebSocketTextRoute.ignore;
          final Object? message;
          try {
            message = jsonDecode(frame);
          } on FormatException {
            return WebSocketTextRoute.ignore;
          }
          if (passed) {
            final stopReason = switch (message) {
              {'type': 'kicked'} => t.settings.station.echocatDisplaced,
              {'type': 'revoked'} => t.settings.station.echocatAuthorizationRefused,
              _ => null,
            };
            if (stopReason != null) {
              connection?.manualReconnectReason = stopReason;
              unawaited(connection?.close());
              return WebSocketTextRoute.ignore;
            }
            // The shack also sends its spots and log history on this
            // connection. Only the radio messages belong in CAT traffic.
            return switch (message) {
              {'type': 'scope-state' || 'scope-frame'} => WebSocketTextRoute.samples,
              {'type': 'status' || 'smeter' || 'swr-ratio' || 'fwd-power' || 'pong'} => WebSocketTextRoute.data,
              _ => WebSocketTextRoute.ignore,
            };
          }
          // The desktop client presents the device token after auth-mode.
          // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/lib/remote-client.js#L448-L470
          switch (message) {
            case {'type': 'auth-mode'}:
              socket.add(jsonEncode({'type': 'auth', 'token': token}));
            case {'type': 'auth-ok'}:
              passed = true;
              authorized.complete();
            case {'type': 'auth-fail'}:
              authorized.completeError(EchocatFailure(t.settings.station.echocatAuthorizationRefused));
          }
          return WebSocketTextRoute.ignore;
        },
      );
      socket.add(
        jsonEncode({
          'type': 'hello',
          'protocolVersion': 1,
          'clientVersion': 'HaLo',
          'clientPlatform': Platform.operatingSystem,
          'capabilities': ['scope', 'scope-bins', 'scope-span'],
        }),
      );
      await Future.any<void>([authorized.future, wrapping.closed.then<void>((_) => throw const WebSocketException('ECHOCAT closed during authentication'))]);
      return wrapping;
    }

    try {
      final result = await Future.any<EquipmentConnection>([
        open(),
        cancel.whenCancelled.then<EquipmentConnection>((_) => throw const CatCancelledException()),
      ]).timeout(_timeout);
      if (cancel.isCancelled) throw const CatCancelledException();
      connected = true;
      return result;
    } finally {
      ended = true;
      if (!connected) await connection?.close();
      client.close(force: !connected);
    }
  }
}

class _EchocatConnection extends WebSocketConnection implements RequiresManualReconnect {
  _EchocatConnection(super.socket, {super.routeText});

  @override
  String? manualReconnectReason;
}

/// Dart's WebSocket upgrade follows HTTP redirects by default. Authentication
/// belongs to the origin in the pairing, including when it uses a public CA.
class _DirectUpgradeClient implements HttpClient {
  final HttpClient _client;
  _DirectUpgradeClient(this._client);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => (await _client.openUrl(method, url))..followRedirects = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HttpClient _clientFor(EchocatEndpoint endpoint) {
  final pin = endpoint.fingerprint;
  // A pinned endpoint must match even if a public CA could also vouch for it.
  // A public Tailscale endpoint instead uses the system trust store.
  final client = HttpClient(context: pin == null ? null : SecurityContext(withTrustedRoots: false))..connectionTimeout = _timeout;
  if (pin != null) {
    client.badCertificateCallback = (certificate, host, port) =>
        host == endpoint.uri.host && port == endpoint.uri.port && sha256.convert(certificate.der).toString() == pin;
  }
  return client;
}
