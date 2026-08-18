// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The LAN link under `PeerSession` (HALO-310): a WebSocket over TCP, one
// side listening and the other dialling.
//
// WebSocket rather than a raw socket because `PeerLink` is message-oriented
// and WebSocket already frames — a raw socket would mean writing (and
// testing) a length-prefix reassembler for no gain. Nothing in this repo
// listened on a socket before this; the CAT transports are all outbound
// clients, so the server half below has no precedent here to copy.
//
// Listening needs `com.apple.security.network.server` on macOS, present in
// both entitlement files already (added for CAT discovery). Dialling needs
// `network.client`, also present.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// Accepts incoming peer links on an ephemeral port.
///
/// The port is chosen by the OS (bind to 0) and published in the beacon
/// rather than fixed: two HaLo windows on one machine must both be able to
/// listen, which a hard-coded port would prevent.
class PeerLinkServer {
  PeerLinkServer._(this._server, this._controller) {
    _server.listen(
      (request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          // Something that isn't a peer — a browser, a port scanner. Answer
          // plainly rather than hanging the connection open.
          request.response.statusCode = HttpStatus.badRequest;
          unawaited(request.response.close());
          return;
        }
        // A web page the operator merely VISITS is outside this feature's
        // threat model, and `ws://` is not subject to CORS — so a page could
        // otherwise scan localhost, upgrade, and talk the peer protocol.
        // Browsers always send Origin on a WebSocket handshake and this app
        // never does, which makes its presence a reliable "not a peer".
        if (request.headers.value('origin') != null) {
          debugPrint('[peer] refused an upgrade carrying an Origin header (a browser, not a peer)');
          request.response.statusCode = HttpStatus.forbidden;
          unawaited(request.response.close());
          return;
        }
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          if (_controller.isClosed) {
            unawaited(socket.close());
            return;
          }
          _controller.add(WebSocketPeerLink(socket));
        } catch (e) {
          debugPrint('[peer] rejected an inbound link: $e');
        }
      },
      onError: (Object e) => debugPrint('[peer] link server error: $e'),
      onDone: () {
        if (!_controller.isClosed) _controller.close();
      },
    );
  }

  final HttpServer _server;
  final StreamController<PeerLink> _controller;

  /// Binds on all interfaces, letting the OS pick the port.
  ///
  /// Throws if the bind fails — unlike the beacon socket, which degrades to
  /// "no peers found". A device that cannot listen can still dial out, but
  /// the caller has to know that so it can say so; silently returning a
  /// server that never accepts anything would be untestable in the field.
  static Future<PeerLinkServer> bind({int port = 0}) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
    return PeerLinkServer._(server, StreamController<PeerLink>.broadcast());
  }

  /// What to publish in the beacon.
  int get port => _server.port;

  Stream<PeerLink> get connections => _controller.stream;

  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
    await _server.close(force: true);
  }
}

/// Dials [address]:[port].
///
/// [timeout] bounds the whole attempt: a peer that has left the network
/// answers neither a SYN nor a close, and the OS default connect timeout is
/// long enough that a discovery loop would pile up attempts behind it.
Future<PeerLink> dialPeerLink(
  String address,
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  var timedOut = false;
  final pending = WebSocket.connect('ws://$address:$port');
  // `.timeout()` fails the future it returns; it does NOT cancel the connect
  // underneath. A slow peer that answers afterwards would leave an open
  // socket nothing holds — and an accepted session on the far side for a
  // link this side already gave up on — so the late arrival is closed.
  unawaited(pending.then(
    (socket) async {
      if (timedOut) await socket.close();
    },
    onError: (Object _) {},
  ));
  final socket = await pending.timeout(timeout, onTimeout: () {
    timedOut = true;
    throw TimeoutException('peer dial to $address:$port timed out', timeout);
  });
  return WebSocketPeerLink(socket);
}

/// A [PeerLink] over one WebSocket. Same contract as CAT's
/// `EquipmentConnection`: [send] never throws, liveness is reported only
/// through [closed], and [close] is idempotent.
@visibleForTesting
class WebSocketPeerLink implements PeerLink {
  WebSocketPeerLink(this._socket) {
    _subscription = _socket.listen(
      (data) {
        if (_controller.isClosed) return;
        // A peer sending text where bytes were expected is still a valid
        // message — WebSocket carries both, and the envelope is UTF-8 JSON
        // either way.
        if (data is List<int>) {
          _controller.add(data);
        } else if (data is String) {
          _controller.add(utf8.encode(data));
        }
      },
      onError: (Object e) {
        if (!_controller.isClosed) _controller.addError(e);
      },
      onDone: _finish,
      cancelOnError: false,
    );
  }

  final WebSocket _socket;
  final _controller = StreamController<List<int>>();
  final _closedCompleter = Completer<void>();
  StreamSubscription<dynamic>? _subscription;
  bool _isClosed = false;

  @override
  Stream<List<int>> get inbound => _controller.stream;

  @override
  void send(List<int> message) {
    if (_isClosed) return;
    try {
      _socket.add(message);
    } catch (e) {
      // A write to a socket the far side already dropped. Never surfaced as
      // a throw: callers write from timers and message handlers, and the
      // `closed` future is what tells them the link is gone.
      debugPrint('[peer] send on a dead link: $e');
    }
  }

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  Future<void> close() async {
    if (_isClosed) {
      await _closedCompleter.future;
      return;
    }
    _finish();
    try {
      await _socket.close();
    } catch (_) {
      // Closing an already-broken socket is not a failure worth reporting.
    }
  }

  void _finish() {
    if (_isClosed) return;
    _isClosed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!_controller.isClosed) unawaited(_controller.close());
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
  }
}
