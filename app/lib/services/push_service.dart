// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../tools/backoff.dart';

/// A named event received on a subscribed push channel.
class PushEvent {
  final String channel;
  final String event;
  final Map<String, dynamic> data;

  const PushEvent({required this.channel, required this.event, required this.data});

  @override
  String toString() => 'PushEvent($channel, $event, $data)';
}

/// The client for ham2k-push, LoFi's realtime fan-out (api-lofi's `push/`).
///
/// ham2k-push speaks the subset of Pusher's WebSocket protocol LoFi uses, so
/// the frames here (`pusher:subscribe`, `pusher:ping`, ...) carry Pusher's
/// names; they are the wire format, not a dependency on Pusher's service.
/// Every LoFi channel (`client-…`, `account-…`, `operation-…`) is public and
/// secured by an unguessable name, so there is no channel auth handshake.
///
/// Push is a latency optimisation over polling, never the source of truth:
/// api-lofi guarantees no delivery, and every consumer keeps its poll.
///
/// Reconnects with exponential backoff (capped at 30s) and re-subscribes
/// every channel once the new connection is confirmed, so callers never need
/// to notice a drop.
class PushService {
  /// Production ham2k-push. Both are public identifiers, so they are compiled
  /// in; a build overrides them (`HAM2K_PUSH_HOST`/`HAM2K_PUSH_KEY`) only to
  /// reach a staging or local Worker.
  static const defaultHost = 'pusher.ham2k.net';
  static const defaultAppKey = 'ham2k-push';

  final String host;
  final String appKey;

  /// Injectable so tests can hand this an in-memory channel instead of a
  /// socket; only `.stream`/`.sink` are used.
  final StreamChannel<dynamic> Function(Uri uri) _connect;

  /// How long a connection may take to be confirmed before it is abandoned.
  /// Without it, a dial into a network that drops packets waits on the OS's
  /// TCP timeout — over a minute — with every subscription parked behind it.
  static const connectTimeout = Duration(seconds: 15);

  /// The longest silence before this client pings. The server's advertised
  /// `activity_timeout` wins when it is shorter.
  static const maxActivityTimeout = Duration(seconds: 120);

  /// How long a ping may go unanswered before the connection counts as dead.
  /// A half-open socket (sleep and wake, a network switch) accepts writes and
  /// delivers nothing; only a missing answer reveals it.
  static const pongTimeout = Duration(seconds: 30);

  static const _maxReconnectDelay = Duration(seconds: 30);

  StreamChannel<dynamic>? _socket;
  StreamSubscription<dynamic>? _socketSub;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  Duration _activityTimeout = maxActivityTimeout;
  Timer? _reconnectTimer;
  Timer? _connectTimer;
  Timer? _activityTimer;
  Timer? _pongTimer;

  final Set<String> _channels = {};
  final _eventsController = StreamController<PushEvent>.broadcast();

  PushService({this.host = defaultHost, this.appKey = defaultAppKey, StreamChannel<dynamic> Function(Uri uri)? connect})
    : _connect = connect ?? _connectWebSocket;

  /// A failed dial errors the channel's stream AND completes its `ready`
  /// future with the same error. The stream's copy is the one handled (it
  /// schedules the reconnect); unlistened, `ready`'s copy escapes to the zone
  /// as an uncaught error on every attempt, which ErrorPolicy treats as an
  /// unknown fault: uploaded, and noticed.
  static StreamChannel<dynamic> _connectWebSocket(Uri uri) {
    final channel = WebSocketChannel.connect(uri);
    channel.ready.ignore();
    return channel;
  }

  /// Whether a connection is open and confirmed by the server.
  bool get isConnected => _connected;

  /// Named events on any subscribed channel. Protocol frames (`pusher:*`,
  /// `pusher_internal:*`) are filtered out — this stream is app events only.
  Stream<PushEvent> get events => _eventsController.stream;

  /// Subscribes to [channel], opening the connection if this is the first
  /// subscription. Idempotent — subscribing to an already-subscribed
  /// channel is a no-op.
  void subscribe(String channel) {
    final isNew = _channels.add(channel);
    _ensureConnecting();
    if (isNew && _connected) _send('pusher:subscribe', {'channel': channel});
  }

  void unsubscribe(String channel) {
    if (!_channels.remove(channel)) return;
    if (_connected) _send('pusher:unsubscribe', {'channel': channel});
  }

  /// The network is back: dial now instead of waiting out the backoff, or
  /// prove an open connection still works — a network switch can leave one
  /// open that no longer reaches anything.
  void reconnectNow() {
    if (_disposed || _channels.isEmpty) return;
    if (_connected) {
      checkConnection();
      return;
    }
    if (_socket != null) return; // A dial is already under way.
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _ensureConnecting();
  }

  /// Pings now and drops the connection unless it answers within
  /// [pongTimeout]. For moments a connection may have died without a close —
  /// the app resuming after its process was suspended.
  void checkConnection() {
    if (!_connected || _pongTimer != null) return;
    _activityTimer?.cancel();
    _ping();
  }

  void _ensureConnecting() {
    if (_socket != null || _disposed) return;
    final uri = Uri.parse('wss://$host/app/$appKey?protocol=7&client=halo&version=1.0');
    final socket = _connect(uri);
    _socket = socket;
    _socketSub = socket.stream.listen(_onMessage, onDone: _onDisconnected, onError: (Object _) => _onDisconnected(), cancelOnError: true);
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, _drop);
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // Malformed frame — not our problem to crash over.
    }

    final event = message['event'] as String?;
    if (event == null) return;

    if (event == 'pusher:connection_established') {
      _connected = true;
      _reconnectAttempt = 0;
      _connectTimer?.cancel();
      _connectTimer = null;
      _activityTimeout = _activityTimeoutFrom(_decodeData(message['data']));
      _noteActivity();
      for (final channel in _channels) {
        _send('pusher:subscribe', {'channel': channel});
      }
      return;
    }
    if (!_connected) return;
    // Any frame proves the connection alive, the pong a ping asked for
    // included.
    _noteActivity();

    if (event == 'pusher:ping') {
      _send('pusher:pong', const {});
      return;
    }
    if (event == 'pusher:error') {
      // ham2k-push answers a subscription past its per-socket budget with
      // one (code 4100) and keeps the connection; the channel just never
      // delivers. Worth a console line, never a reconnect.
      debugPrint('[push] server error: ${_decodeData(message['data'])}');
      return;
    }
    if (event.startsWith('pusher:') || event.startsWith('pusher_internal:')) return;

    final channel = message['channel'] as String?;
    if (channel == null) return;
    _eventsController.add(PushEvent(channel: channel, event: event, data: _decodeData(message['data'])));
  }

  /// The server's `activity_timeout`, capped at [maxActivityTimeout]: the
  /// protocol has the client ping after the shorter of its own and the
  /// server's.
  static Duration _activityTimeoutFrom(Map<String, dynamic> data) {
    final seconds = data['activity_timeout'];
    if (seconds is! num || seconds <= 0) return maxActivityTimeout;
    final advertised = Duration(milliseconds: (seconds * 1000).round());
    return advertised < maxActivityTimeout ? advertised : maxActivityTimeout;
  }

  /// `data` arrives as a JSON-encoded string (the protocol's double
  /// encoding); a plain map is accepted too — ham2k-push's own auto-answered
  /// pong carries one.
  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // A malformed payload is still a real event: the channel and event
        // name are what consumers act on.
      }
    }
    return const {};
  }

  void _noteActivity() {
    _pongTimer?.cancel();
    _pongTimer = null;
    _activityTimer?.cancel();
    _activityTimer = Timer(_activityTimeout, _ping);
  }

  void _ping() {
    // Byte for byte the frame ham2k-push auto-answers without waking its
    // Durable Object (push/src/protocol.ts PING_FRAME). Any other spelling
    // still gets a pong, but bills a wake per ping per connection.
    _send('pusher:ping', const {});
    _pongTimer = Timer(pongTimeout, _drop);
  }

  /// Abandons a connection that stopped answering, or never got confirmed,
  /// and goes through the same reconnect as a close from the far end.
  void _drop() {
    final socket = _socket;
    // Detached first: a channel may report its own close as `onDone`, which
    // would count this disconnect twice and double the backoff.
    _onDisconnected();
    unawaited(socket?.sink.close());
  }

  void _onDisconnected() {
    _connected = false;
    unawaited(_socketSub?.cancel());
    _socketSub = null;
    _socket = null;
    _cancelConnectionTimers();
    if (_disposed) return;

    final delay = exponentialBackoff(_reconnectAttempt, cap: _maxReconnectDelay);
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _ensureConnecting);
  }

  void _cancelConnectionTimers() {
    _connectTimer?.cancel();
    _connectTimer = null;
    _activityTimer?.cancel();
    _activityTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
  }

  void _send(String event, Map<String, dynamic> data) {
    _socket?.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  void dispose() {
    _disposed = true;
    _connected = false;
    _reconnectTimer?.cancel();
    _cancelConnectionTimers();
    unawaited(_socketSub?.cancel());
    unawaited(_socket?.sink.close());
    _socket = null;
    unawaited(_eventsController.close());
  }
}
