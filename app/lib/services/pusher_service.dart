// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../tools/backoff.dart';

/// A named event received on a subscribed Pusher channel.
class PusherEvent {
  final String channel;
  final String event;
  final Map<String, dynamic> data;

  const PusherEvent({required this.channel, required this.event, required this.data});

  @override
  String toString() => 'PusherEvent($channel, $event, $data)';
}

/// A minimal hand-rolled client for Pusher's WebSocket protocol
/// (pusher.com/docs/channels/library_auth_reference/pusher-websockets-protocol),
/// used instead of a Pusher SDK package — see pubspec.yaml's comment on the
/// `web_socket_channel` dependency for why: the official
/// `pusher_channels_flutter` package only covers android/ios/web, not
/// macOS/Windows/Linux, and the alternatives are low-trust community
/// packages not worth the risk for something that carries OAuth codes.
///
/// api-lofi's push channels (`client-<uuid[0..7]>-<verifier>`,
/// `account-...`, `operation-...`) are all *public* channels secured by an
/// unguessable name rather than Pusher's private-channel auth handshake
/// (confirmed against api-lofi's `config/initializers/push.rb` and
/// `Client#push_channel_name` — there is no `/pusher/auth` endpoint), same
/// as web-lofi's own Pusher client. So this client only ever needs
/// `pusher:subscribe` with a bare channel name — no channel auth signature
/// to compute.
///
/// Reconnects with exponential backoff (capped at 30s) and re-subscribes
/// every previously-subscribed channel once the new connection is confirmed
/// — callers never need to notice a drop and resubscribe themselves.
class PusherService {
  final String appKey;

  /// Pusher's own deployments are addressed by cluster; ours is not. Exactly
  /// one of [cluster] and [host] is needed, and [host] wins when both are given.
  final String? cluster;

  /// The WebSocket host to connect to, when it isn't Pusher's.
  ///
  /// LoFi is migrating off Pusher onto Ham2K's own fan-out service, which
  /// speaks this same protocol deliberately so builds already in the field
  /// move across by configuration rather than by release (LOFI-47). Setting
  /// this is the entire client-side change.
  final String? host;

  /// Injectable so tests can hand this a fake in-memory channel (e.g. from a
  /// `StreamChannelController`) instead of opening a real socket — typed as
  /// the plain `StreamChannel` supertype rather than `WebSocketChannel`
  /// itself, since that's all this class actually uses (`.stream`/`.sink`),
  /// and it's what makes a fake trivial to build in tests.
  final StreamChannel<dynamic> Function(Uri uri) _connect;

  static const _pingInterval = Duration(seconds: 120);
  static const _maxReconnectDelay = Duration(seconds: 30);

  StreamChannel<dynamic>? _socket;
  StreamSubscription<dynamic>? _socketSub;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final Set<String> _channels = {};
  final _eventsController = StreamController<PusherEvent>.broadcast();

  PusherService({
    required this.appKey,
    this.cluster,
    this.host,
    StreamChannel<dynamic> Function(Uri uri)? connect,
  })  : assert(cluster != null || host != null, 'PusherService needs either a cluster or a host'),
        _connect = connect ?? WebSocketChannel.connect;

  /// Where to connect. Pusher derives its host from the cluster; ours is named
  /// outright.
  String get _wsHost => host ?? 'ws-$cluster.pusher.com';

  /// Named events on any subscribed channel. `pusher:*`/`pusher_internal:*`
  /// protocol events are filtered out — this stream is app events only.
  Stream<PusherEvent> get events => _eventsController.stream;

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

  void _ensureConnecting() {
    if (_socket != null || _disposed) return;
    final uri = Uri.parse('wss://$_wsHost/app/$appKey?protocol=7&client=halo&version=1.0');
    final socket = _connect(uri);
    _socket = socket;
    _socketSub = socket.stream.listen(
      _onMessage,
      onDone: _onDisconnected,
      onError: (Object _) => _onDisconnected(),
      cancelOnError: true,
    );
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
      _startPinging();
      // Re-subscribe everything — this fires after a fresh connect and
      // after every reconnect alike, so callers never need to notice a
      // drop and resubscribe themselves.
      for (final channel in _channels) {
        _send('pusher:subscribe', {'channel': channel});
      }
      return;
    }
    if (event == 'pusher:ping') {
      _send('pusher:pong', const {});
      return;
    }
    if (event == 'pusher:error' || event.startsWith('pusher_internal:')) return;

    final channel = message['channel'] as String?;
    if (channel == null) return;
    _eventsController.add(PusherEvent(channel: channel, event: event, data: _decodeData(message['data'])));
  }

  /// Pusher sends `data` as a JSON-encoded string on the wire (the protocol
  /// spec's normal shape); a plain map is accepted too since nothing stops a
  /// test double — or a future protocol revision — from skipping the
  /// double-encoding.
  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // Fall through to empty — a malformed payload is still a real event
        // (the channel/event name matter more than the body for most of
        // this app's uses, e.g. `webhook_event` only carries an id anyway).
      }
    }
    return const {};
  }

  void _onDisconnected() {
    _connected = false;
    _socket = null;
    unawaited(_socketSub?.cancel());
    _socketSub = null;
    _pingTimer?.cancel();
    if (_disposed) return;

    final delay = exponentialBackoff(_reconnectAttempt, cap: _maxReconnectDelay);
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _ensureConnecting);
  }

  void _startPinging() {
    _pingTimer?.cancel();
    // Pusher's own server-side ping (handled above) is the primary
    // liveness signal; this is a client-initiated backstop in case a
    // half-open connection never gets one.
    _pingTimer = Timer.periodic(_pingInterval, (_) => _send('pusher:ping', const {}));
  }

  void _send(String event, Map<String, dynamic> data) {
    _socket?.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    unawaited(_socketSub?.cancel());
    unawaited(_socket?.sink.close());
    _socket = null;
    unawaited(_eventsController.close());
  }
}
