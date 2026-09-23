// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../error_reporting_service.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

/// The most a client may leave unread before it is hung up on. Replies are
/// queued in memory until the client reads them, and one that keeps asking
/// without ever reading — `\dump_state` is twelve bytes in and seven hundred
/// out — would otherwise grow that queue without bound. Far above what any
/// real client leaves waiting.
const _maxUnsent = 1024 * 1024;

/// Listens for [protocol]'s clients on [port], on every interface when [lan]
/// and on loopback only otherwise. Throws when the port cannot be bound — a
/// server that is not listening has to be able to say so.
///
/// Loopback means both families: a client told `localhost` may resolve it to
/// `::1` first, and a server on `127.0.0.1` alone turns that into a refused
/// connection — or, worse, into a connection to whatever other program holds
/// `::1` on that port. So the IPv6 half is skipped only on a machine without
/// IPv6, and a port held there fails the bind like one held on IPv4.
///
/// [onStopped] is called if the system closes a listening socket out from
/// under the server — never for [CatServerListener.close].
Future<CatServerListener> bindCatServer(
  CatServerProtocol protocol,
  CatServerRig rig, {
  required int port,
  required bool lan,
  void Function()? onClientsChanged,
  void Function()? onStopped,
}) async {
  final sockets = <ServerSocket>[];
  try {
    if (lan) {
      // Dual-stack where there is IPv6, so one socket takes both families.
      sockets.add(await ServerSocket.bind(await _hasIPv6(InternetAddress.anyIPv6) ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4, port));
    } else {
      sockets.add(await ServerSocket.bind(InternetAddress.loopbackIPv4, port));
      if (await _hasIPv6(InternetAddress.loopbackIPv6)) {
        sockets.add(await ServerSocket.bind(InternetAddress.loopbackIPv6, sockets.first.port, v6Only: true));
      } else {
        debugPrint('[cat-server] ${protocol.key}: no IPv6 loopback, serving 127.0.0.1 only');
      }
    }
  } catch (_) {
    // The bind's own failure is what the caller must hear, so a failure to
    // let go of the half already bound is reported apart from it rather than
    // thrown in its place.
    for (final socket in sockets) {
      await socket.close().then((_) {}, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'CatServer:${protocol.key}:unbind'));
    }
    rethrow;
  }
  return _IoCatServerListener(protocol, rig, sockets, onClientsChanged, onStopped);
}

/// Whether this machine can listen on [address] at all — asked on a port the
/// system picks, so the answer says nothing about any port in use.
Future<bool> _hasIPv6(InternetAddress address) async {
  try {
    final probe = await ServerSocket.bind(address, 0, v6Only: true);
    await probe.close();
    return true;
  } on SocketException {
    return false;
  }
}

/// The errno values meaning "address in use" and "permission denied" on
/// macOS/iOS, Linux/Android and Windows.
const _addressInUse = {48, 98, 10048};
const _permissionDenied = {13, 10013};

/// What a bind failure amounts to: null for anything that is not the
/// network's own answer, which the caller treats as a bug.
CatServerFailure? catServerFailureOf(Object error) {
  final int? code;
  switch (error) {
    case SocketException(:final osError):
      code = osError?.errorCode;
    case OSError(:final errorCode):
      code = errorCode;
    default:
      return null;
  }
  if (_addressInUse.contains(code)) return CatServerFailure.portInUse;
  if (_permissionDenied.contains(code)) return CatServerFailure.portDenied;
  return CatServerFailure.other;
}

class _IoCatServerListener implements CatServerListener {
  final CatServerProtocol protocol;
  final CatServerRig rig;
  final List<ServerSocket> _sockets;
  final void Function()? _onClientsChanged;
  final void Function()? _onStopped;

  /// Each connected client, and how to end it: flushing what is queued for
  /// it, or not.
  final _clients = <Socket, void Function({required bool flush})>{};
  final _subscriptions = <StreamSubscription<Socket>>[];
  bool _closing = false;

  _IoCatServerListener(this.protocol, this.rig, this._sockets, this._onClientsChanged, this._onStopped) {
    for (final socket in _sockets) {
      _subscriptions.add(
        socket.listen(
          _accept,
          // Accepting itself failing — out of file descriptors, say — is the
          // machine's trouble, not a client's, and worth hearing about.
          onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'CatServer:${protocol.key}:accept'),
          // A listening socket ends only when closed, and one the system
          // closed — an interface gone across a sleep — leaves a server that
          // says it is listening and accepts nothing.
          onDone: () {
            if (!_closing) _onStopped?.call();
          },
        ),
      );
    }
  }

  @override
  int get port => _sockets.first.port;

  @override
  int get clientCount => _clients.length;

  void _accept(Socket client) {
    final String peer;
    try {
      client.setOption(SocketOption.tcpNoDelay, true);
      peer = '${client.remoteAddress.address}:${client.remotePort}';
    } on Exception catch (e) {
      // Gone before it could be looked at — a port scanner's connect-and-reset
      // is the usual one, and the OS says so as an OSError or a
      // SocketException depending on which call noticed. No client to serve.
      if (e is! OSError && e is! SocketException) rethrow;
      client.destroy();
      return;
    }
    debugPrint('[cat-server] ${protocol.key}: client $peer connected');

    // Replies go to the socket through a stream it pauses when the client is
    // not reading. [unsent] counts what has been queued and not yet taken by
    // the socket, which is what [_maxUnsent] limits.
    final replies = StreamController<List<int>>();
    var unsent = 0;
    final written = client.addStream(
      replies.stream.map((bytes) {
        unsent -= bytes.length;
        return bytes;
      }),
    );

    late final CatServerConnection connection;
    void end({required bool flush}) {
      if (_clients.remove(client) == null) return;
      connection.close();
      // A client that finished sending still gets the replies to what it
      // sent — `echo f | nc localhost 4532` is a whole session — so a normal
      // end flushes. One hung up on gets nothing more.
      if (flush) {
        unawaited(replies.close());
        unawaited(written.then((_) => client.close()).then((_) {}, onError: (Object _) => client.destroy()));
      } else {
        client.destroy();
      }
      debugPrint('[cat-server] ${protocol.key}: client $peer disconnected');
      _onClientsChanged?.call();
    }

    void hangUp() => end(flush: false);

    connection = createCatServerConnection(
      protocol,
      rig,
      // Never to a client that has been ended. A client that went away on its
      // own is reported by `done`.
      send: (bytes) {
        if (!_clients.containsKey(client)) return;
        unsent += bytes.length;
        if (unsent > _maxUnsent) return hangUp();
        replies.add(bytes);
      },
      hangUp: hangUp,
      quit: () => end(flush: true),
    );
    _clients[client] = end;
    _onClientsChanged?.call();
    // A write to a client that has reset the connection fails here, not at
    // `add`; that is the client leaving. Unhandled, it escapes into the zone
    // as an error on every ordinary disconnect.
    unawaited(client.done.then((_) {}, onError: (Object _) => hangUp()));
    unawaited(written.then((_) {}, onError: (Object _) => hangUp()));

    client.listen(
      (bytes) {
        try {
          connection.receive(bytes);
        } catch (e, st) {
          // A codec that throws is a bug, and one client's input must not
          // take the server down with it, or any other client.
          ErrorReportingService.report(e, st, context: 'CatServer:${protocol.key}');
          hangUp();
        }
      },
      onError: (Object _) => hangUp(),
      onDone: () => end(flush: true),
      cancelOnError: true,
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final socket in _sockets) {
      await socket.close();
    }
    for (final end in [..._clients.values]) {
      end(flush: false);
    }
  }
}
