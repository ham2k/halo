// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.webSocket`: the sockets extensions hold open, owned by the host core
// beside the engine (in the extension isolate natively, in-process on web) so
// each frame reaches the sandbox without crossing to the UI isolate first.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'engine_runtime.dart';
import 'socket_connect.dart' if (dart.library.io) 'socket_connect_io.dart';

/// How many sockets one extension may hold open at once. A feed needs one; a
/// loop that reconnects without closing would otherwise pile up connections
/// until something outside the app gives out.
const maxWebSocketsPerExtension = 4;

/// The largest frame a socket carries either way: UTF-16 code units for text,
/// bytes for binary. Every inbound frame crosses the bridge as JSON and is
/// parsed by the sandbox, so an unbounded one is an unbounded allocation in
/// both. An oversized inbound frame closes the socket with 1009 rather than
/// being cut down: a truncated message is a wrong one. The SDK checks the same
/// number before sending (extensions/sdk/src/index.ts).
const maxWebSocketFrameSize = 1024 * 1024;

/// The `webSockets` entry that admits every [isLocalNetworkHost] address, over
/// `ws://` or `wss://`: an extension for gear in the shack cannot know the
/// operator's addresses, and `*` would grant the whole internet to reach them.
const localNetworkEntry = 'local';

/// Whether [host] (a `Uri.host`, so an IPv6 literal carries no brackets) is on
/// the device itself or the local network: loopback, RFC 1918, link-local,
/// IPv6 unique-local, and the `localhost` / mDNS `.local` names.
///
/// The one condition under which `host.webSocket` accepts plain `ws://`. Gear
/// and servers in the shack rarely have a certificate; anything past the
/// router has no such excuse. A NAME is judged by its spelling, not by what it
/// resolves to — resolving it here would not bind the connection to that
/// answer, and a browser offers no resolver at all.
bool isLocalNetworkHost(String host) {
  final name = host.toLowerCase();
  if (name == 'localhost' || name.endsWith('.localhost') || name.endsWith('.local')) return true;
  try {
    final b = Uri.parseIPv4Address(name);
    return b[0] == 127 || b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168) || (b[0] == 169 && b[1] == 254);
  } on FormatException {
    // Not an IPv4 literal.
  }
  try {
    final b = Uri.parseIPv6Address(name);
    final loopback = b.take(15).every((byte) => byte == 0) && b[15] == 1;
    return loopback || (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80);
  } on FormatException {
    return false;
  }
}

/// Every socket one runtime's extensions hold, by the kernel-allocated id
/// `host.webSocket` registered its listener under.
class ExtensionSockets {
  /// Hands one event to the sandbox. `close` is the last any socket sends.
  final void Function(int socketId, Map<String, Object?> event) deliver;

  /// Stamped on every handshake where the platform allows it — see
  /// socket_connect.dart.
  final String? userAgent;
  final Map<int, _ExtensionSocket> _open = {};

  ExtensionSockets({required this.deliver, this.userAgent});

  /// Opens the socket `host.webSocket` asked for, once the caller's
  /// `webSockets` grant admits its host: [matches] applies the same rule as
  /// host.fetch to [allowlist], and [localNetworkEntry] admits local addresses
  /// besides. Returns once the request is accepted, not once connected:
  /// everything after — the open, each frame, the failure to connect —
  /// arrives as a socket event, as it does in a browser.
  void open(Map<String, dynamic> params, {required List<String> allowlist, required bool Function(List<String> allowlist, String host) matches}) {
    final extensionKey = params['extensionKey'] as String?;
    final socketId = params['socketId'];
    if (extensionKey == null || socketId is! int) throw ExtensionHostException('webSocket: malformed open request');
    if (_open.containsKey(socketId)) throw ExtensionHostException('webSocket: socket $socketId is already open');
    final uri = Uri.parse(params['url'] as String);
    final declared = matches(allowlist, uri.host) || (allowlist.contains(localNetworkEntry) && isLocalNetworkHost(uri.host));
    if (!declared) {
      throw ExtensionHostException("webSocket blocked: '${uri.host}' is not in extension '$extensionKey's declared webSockets");
    }
    if (uri.scheme == 'ws') {
      if (!isLocalNetworkHost(uri.host)) throw ExtensionHostException('webSocket blocked: plain ws:// is only allowed to a local-network address');
    } else if (uri.scheme != 'wss') {
      throw ExtensionHostException('webSocket blocked: only ws:// and wss:// URLs are allowed');
    }
    final held = _open.values.where((socket) => socket.extensionKey == extensionKey).length;
    if (held >= maxWebSocketsPerExtension) {
      throw ExtensionHostException('webSocket blocked: extension $extensionKey already has $held sockets open');
    }
    _open[socketId] = _ExtensionSocket.connect(
      uri,
      protocols: (params['protocols'] as List?)?.cast<String>(),
      userAgent: userAgent,
      extensionKey: extensionKey,
      onEvent: (event) {
        if (event['type'] == 'close') _open.remove(socketId);
        deliver(socketId, event);
      },
    );
  }

  /// Sends a frame on a socket the caller opened: `data` for text, `binary`
  /// (base64) for bytes.
  void send(Map<String, dynamic> params) => _owned(params).send(params['data'], params['binary']);

  /// Closes a socket the caller opened.
  void close(Map<String, dynamic> params) => _owned(params).close(params['code'], params['reason']);

  /// The socket a send or close names — refused unless the caller opened it.
  /// Ids come from the kernel's shared counter, so they are guessable; only
  /// the kernel-stamped `extensionKey` makes one extension's id useless to
  /// another.
  _ExtensionSocket _owned(Map<String, dynamic> params) {
    final socket = _open[params['socketId']];
    if (socket == null || socket.extensionKey != params['extensionKey']) {
      throw ExtensionHostException('webSocket: socket ${params['socketId']} is not open');
    }
    return socket;
  }

  /// Drops, unannounced, the sockets [socketIds] name — the ones whose
  /// listeners the kernel just dropped with their extension, so nobody is left
  /// to hear a close. Ids, not an owner's key: the kernel knows exactly which
  /// extensions a bundle defined, where a key prefix would also match a
  /// separate bundle named after it.
  void abandon(Iterable<int> socketIds) {
    for (final id in socketIds) {
      _open.remove(id)?.abandon();
    }
  }

  /// Drops every socket, for a runtime that is going away.
  void abandonAll() => abandon(_open.keys.toList());
}

/// One extension's WebSocket, reporting everything that happens to it as the
/// events `host.webSocket` hands its callbacks: `open`, `message`, `error`
/// and, exactly once and always last, `close`.
class _ExtensionSocket {
  /// Kernel-stamped: the only extension whose sends and closes reach this.
  final String extensionKey;
  final WebSocketChannel _channel;
  final void Function(Map<String, Object?> event) onEvent;
  StreamSubscription<dynamic>? _subscription;
  bool _open = false;
  bool _finished = false;

  /// The code and reason the HOST closed with (a frame it refuses), reported
  /// in the close event over whatever the peer echoes back.
  (int, String)? _hostClose;

  /// The code and reason the extension closed with. A close this end starts
  /// finishes with no peer code at all (`package:web_socket` stops reading
  /// once it sends its own), so without this every clean close the extension
  /// asked for would report 1006 — abnormal — to the extension that asked.
  (int, String)? _localClose;

  _ExtensionSocket.connect(Uri uri, {List<String>? protocols, String? userAgent, required this.extensionKey, required this.onEvent})
    : _channel = connectExtensionSocket(uri, protocols: protocols, userAgent: userAgent) {
    _channel.ready.then((_) {
      // A close asked for while connecting must not be followed by an
      // `open`. Natively the stream finishes before `ready` completes in that
      // case, so `_finished` already holds; `_localClose` covers an adapter
      // that orders the two the other way.
      if (_finished || _localClose != null) return;
      _open = true;
      onEvent({'type': 'open', 'protocol': _channel.protocol ?? ''});
    }, onError: (Object e) => _fail('$e'));
    _subscription = _channel.stream.listen(_onFrame, onError: (Object e) => _fail('$e'), onDone: _onDone);
  }

  void _onFrame(dynamic data) {
    if (_finished || _hostClose != null) return;
    final size = data is String ? data.length : (data as List<int>).length;
    if (size > maxWebSocketFrameSize) {
      _closeFromHost(1009, 'message too big');
    } else if (data is String) {
      onEvent({'type': 'message', 'data': data});
    } else {
      // Base64 because the bridge is JSON; the SDK decodes it back to an
      // ArrayBuffer.
      onEvent({'type': 'message', 'binary': base64Encode(data as List<int>)});
    }
  }

  /// Closes over a frame the host refuses. [code] is what the EXTENSION is
  /// told; the peer gets 1000 with [reason], because a client may send only
  /// 1000 or 3000-4999 and `package:web_socket` enforces that from an async
  /// gap no catch here reaches.
  void _closeFromHost(int code, String reason) {
    _hostClose = (code, reason);
    unawaited(_channel.sink.close(1000, reason).catchError((_) {}));
  }

  void _onDone() {
    final peer = _channel.closeCode == null ? null : (_channel.closeCode!, _channel.closeReason ?? '');
    final (code, reason) = _hostClose ?? peer ?? _localClose ?? (1006, '');
    _finish({'type': 'close', 'code': code, 'reason': reason, 'wasClean': code != 1006});
  }

  /// A connection that failed or broke: one `error`, then the `close` that
  /// always follows it. Whichever of `ready` and the stream reports first
  /// wins; the other finds the socket finished.
  void _fail(String message) {
    if (_finished) return;
    onEvent({'type': 'error', 'message': message});
    _finish({'type': 'close', 'code': 1006, 'reason': '', 'wasClean': false});
    unawaited(_channel.sink.close().catchError((_) {}));
  }

  void _finish(Map<String, Object?> closeEvent) {
    if (_finished) return;
    _finished = true;
    onEvent(closeEvent);
    unawaited(_subscription?.cancel());
  }

  void send(Object? data, Object? binary) {
    if (!_open || _finished || _hostClose != null || _localClose != null) throw ExtensionHostException('webSocket: socket is not open');
    final Object frame;
    if (data is String) {
      frame = data;
    } else if (binary is String) {
      try {
        frame = Uint8List.fromList(base64Decode(binary));
      } on FormatException {
        throw ExtensionHostException('webSocket: binary frame is not valid base64');
      }
    } else {
      throw ExtensionHostException('webSocket: a frame is text or bytes');
    }
    if ((frame is String ? frame.length : (frame as Uint8List).length) > maxWebSocketFrameSize) throw ExtensionHostException('webSocket: message too big');
    _channel.sink.add(frame);
  }

  /// The extension's own close. The `close` event follows when the closing
  /// handshake completes, carrying what the peer answered.
  void close(Object? code, Object? reason) {
    // The codes an application may send, as a browser's WebSocket.close
    // enforces: everything else is reserved to the protocol or its endpoints.
    if (code != null && (code is! int || (code != 1000 && (code < 3000 || code > 4999)))) {
      throw ExtensionHostException('webSocket: close code must be 1000 or 3000-4999');
    }
    if (reason != null && (reason is! String || utf8.encode(reason).length > 123)) {
      throw ExtensionHostException('webSocket: close reason must be a string of at most 123 bytes');
    }
    if (_finished || _localClose != null) return;
    // 1005 is what a browser reports for a close that named no code.
    _localClose = ((code as int?) ?? 1005, (reason as String?) ?? '');
    unawaited(_channel.sink.close(code, reason).catchError((_) {}));
  }

  /// Drops the socket without telling the extension — for an owner that is
  /// going away (unloaded, or the whole runtime), which has nobody left to
  /// hear a close event. 1000, not "going away" 1001, for the reason
  /// [_closeFromHost] gives.
  void abandon() {
    _finished = true;
    unawaited(_channel.sink.close(1000, 'going away').catchError((_) {}));
    unawaited(_subscription?.cancel());
  }
}
