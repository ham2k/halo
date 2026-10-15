// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one connection the app holds to a DX cluster node, shared by every
// extension that posts to it or reads from it (docs/design/cluster.md).
// One, because a node logs a call in once: a second session under the same
// call knocks the first one off, so two extensions each holding their own
// would take turns disconnecting each other.
//
// On demand: nothing connects until something sends or subscribes, and the
// session closes once nothing has for [ClusterService.idleTimeout] — the
// operator's own cluster client (N1MM, a band map) is logged in under the
// same call on some node, and holding a session longer than needed is time
// spent fighting it if that node is this one.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../settings_service.dart';
import 'cluster_link.dart';
import 'cluster_protocol.dart';
import 'cluster_settings.dart';

@immutable
class ClusterLine {
  const ClusterLine(this.seq, this.at, this.text);

  /// Increases by one per line for the life of the service, across
  /// reconnects — so a reader asking for what came after the last line it
  /// saw neither misses a line nor sees one twice.
  final int seq;

  /// When it arrived, on the app clock.
  final int at;
  final String text;

  Map<String, dynamic> toJson() => {'seq': seq, 'at': at, 'text': text};
}

enum ClusterState { idle, connecting, connected, failed }

@immutable
class ClusterStatus {
  const ClusterStatus({required this.state, required this.node, this.call, this.error, this.message, required this.lastSeq});

  final ClusterState state;
  final ClusterNode node;

  /// The call logged in, or being logged in.
  final String? call;

  /// Why the last attempt failed, as a code (see [ClusterReply.error]).
  final String? error;

  /// What the node or the system said, when there is something to quote.
  final String? message;

  /// The newest line's [ClusterLine.seq]; 0 before the first.
  final int lastSeq;

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'node': {'name': node.name, 'host': node.host, 'port': node.port},
    'call': ?call,
    'error': ?error,
    'message': ?message,
    'lastSeq': lastSeq,
  };
}

/// What a command came back with.
///
/// [error] codes: `unsupported` (no sockets on this platform), `noCall` (no
/// operator to log in as), `connectFailed`, `needsPassword`, `loginFailed`,
/// `disconnected`, `timeout`, `refused` (the node said no; [message] quotes
/// it), `tooSoon` (spots are spaced [ClusterService.spotInterval] apart),
/// `invalidCall`, `invalidFrequency`.
@immutable
class ClusterReply {
  const ClusterReply.ok(this.lines) : ok = true, error = null, message = null;
  const ClusterReply.failed(this.error, {this.message, this.lines = const []}) : ok = false;

  final bool ok;

  /// Everything the node sent between the command and its next prompt —
  /// which includes whatever spots and announcements arrived meanwhile, since
  /// the node interleaves them with the reply.
  final List<String> lines;
  final String? error;
  final String? message;

  Map<String, dynamic> toJson() => {'ok': ok, 'lines': lines, 'error': ?error, 'message': ?message};
}

/// Delivers a batch of new lines to one subscriber.
typedef ClusterLinesDelivery = Future<void> Function(String subscriber, List<ClusterLine> lines);

class ClusterService extends ChangeNotifier {
  ClusterService({
    required this.settings,
    required this.loginCall,
    required this.password,
    this.connect = connectClusterLink,
    this.supported = clusterLinksSupported,
    this.idleTimeout = const Duration(minutes: 5),
    this.loginTimeout = const Duration(seconds: 5),
    this.replyTimeout = const Duration(seconds: 5),
    this.batchDelay = const Duration(seconds: 1),
    this.spotInterval = const Duration(seconds: 5),
    this.reconnectDelays = const [Duration(seconds: 5), Duration(seconds: 15), Duration(minutes: 1), Duration(minutes: 5)],
  }) {
    _node = ClusterSettings.node(settings);
    settings.addListener(_onSettingsChanged);
  }

  final SettingsService settings;

  /// The call to log in as: the operator of the operation in front, so a
  /// spot reads `DX de <operator>` — at a club station or a multi-op, the
  /// person who heard the station, not the station's call.
  final String? Function() loginCall;

  /// The stored password for a node, read only when the node asks for one.
  final Future<String?> Function(ClusterNode node) password;

  final ClusterConnector connect;
  final bool supported;
  final Duration idleTimeout;

  /// With the connect's own five seconds (cluster_link_io.dart), these keep
  /// a spot from a cold start inside the 15 seconds a spots hook has to
  /// answer (`ExtensionService.sendSpot`): past that the hook reports a
  /// timeout while the spot may still go out, and a retry posts it twice.
  final Duration loginTimeout;
  final Duration replyTimeout;
  final Duration batchDelay;

  /// The least time between two spots. A node's own flood control blocks a
  /// spotter it sees repeating, and the block outlives this session — an
  /// extension in a loop would cost the operator their spotting on that
  /// node, not just one refusal.
  final Duration spotInterval;

  /// How long a dropped session waits before reconnecting, per consecutive
  /// failure; the last repeats. Only while something is subscribed — a
  /// session kept for a send has nobody waiting on it.
  final List<Duration> reconnectDelays;

  /// Delivers new lines to subscribers; set by whoever wires the service to
  /// the extensions.
  ClusterLinesDelivery? deliver;

  late ClusterNode _node;
  _Session? _session;
  Future<_Session>? _connecting;
  ClusterState _state = ClusterState.idle;
  String? _error;
  String? _message;

  final _lines = ListQueue<ClusterLine>();
  int _lastSeq = 0;

  /// Each subscriber's newest delivered [ClusterLine.seq].
  final _subscribers = <String, int>{};
  Timer? _flushTimer;
  bool _flushing = false;

  /// Commands go out one at a time: a reply is told apart only by coming
  /// between its command and the next prompt.
  Future<void> _commands = Future.value();
  int? _lastSpotAt;

  Timer? _idleTimer;
  Timer? _reconnectTimer;
  int _failures = 0;
  bool _disposed = false;

  ClusterStatus get status => supported
      ? ClusterStatus(state: _state, node: _node, call: _session?.call, error: _error, message: _message, lastSeq: _lastSeq)
      : ClusterStatus(state: ClusterState.failed, node: _node, error: 'unsupported', lastSeq: _lastSeq);

  Iterable<String> get subscribers => _subscribers.keys;

  /// The scrollback after [after], oldest first, at most [limit] of the
  /// newest.
  List<ClusterLine> lines({int? after, int? limit}) {
    final picked = [
      for (final line in _lines)
        if (after == null || line.seq > after) line,
    ];
    if (limit == null || limit >= picked.length) return picked;
    return picked.sublist(picked.length - limit);
  }

  /// Starts sending [subscriber] every line from now on, connecting if need
  /// be; it stays subscribed until [unsubscribe], across reconnects.
  Future<ClusterStatus> subscribe(String subscriber) async {
    _subscribers.putIfAbsent(subscriber, () => _lastSeq);
    _idleTimer?.cancel();
    try {
      await _ensureSession();
    } on _ClusterFailure {
      _scheduleReconnect();
    }
    return status;
  }

  void unsubscribe(String subscriber) {
    if (_subscribers.remove(subscriber) == null) return;
    if (_subscribers.isEmpty) {
      _reconnectTimer?.cancel();
      _armIdle();
    }
  }

  /// Drops every subscriber not in [keep] — the extensions a restarted
  /// runtime no longer has, whose hooks no delivery could reach.
  void retainSubscribers(Set<String> keep) {
    for (final key in [..._subscribers.keys]) {
      if (!keep.contains(key)) unsubscribe(key);
    }
  }

  /// Sends one command line and collects the reply.
  Future<ClusterReply> send(String command) => _serialized(() => _send(command));

  /// Posts a spot of [call] on [freqKHz], logged in as [loginCall].
  Future<ClusterReply> postSpot({required double freqKHz, required String call, String? comment}) => _serialized(() async {
    final built = spotCommand(freqKHz: freqKHz, call: call, comment: comment);
    if (built.command == null) return ClusterReply.failed(built.error);
    final lastSpotAt = _lastSpotAt;
    if (lastSpotAt != null && realNowMillis() - lastSpotAt < spotInterval.inMilliseconds) return const ClusterReply.failed('tooSoon');
    final reply = await _send(built.command!);
    if (!reply.ok) return reply;
    _lastSpotAt = realNowMillis();
    final refusal = reply.lines.where(isRefusal).firstOrNull;
    // A refusal outranks an echo: DXSpider echoes a spot it keeps local, and
    // a node that refuses one says so in the same reply.
    if (refusal != null) return ClusterReply.failed('refused', message: refusal.trim(), lines: reply.lines);
    return reply;
  });

  Future<ClusterReply> _serialized(Future<ClusterReply> Function() run) {
    final result = _commands.then((_) => run());
    _commands = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ClusterReply> _send(String command) async {
    _idleTimer?.cancel();
    try {
      final session = await _ensureSession();
      return await session.command(command, replyTimeout);
    } on _ClusterFailure catch (failure) {
      return ClusterReply.failed(failure.code, message: failure.message);
    } finally {
      _armIdle();
    }
  }

  void _armIdle() {
    _idleTimer?.cancel();
    if (_subscribers.isNotEmpty || _disposed) return;
    _idleTimer = Timer(idleTimeout, () {
      if (_subscribers.isEmpty) _closeSession(ClusterState.idle);
    });
  }

  /// The logged-in session for the current node and operator, opening one —
  /// or replacing one logged in as someone else, or to another node.
  Future<_Session> _ensureSession() async {
    if (!supported) throw const _ClusterFailure('unsupported');
    final call = _normalizedCall(loginCall());
    if (call == null) {
      _fail('noCall', null);
      throw const _ClusterFailure('noCall');
    }
    final node = ClusterSettings.node(settings);
    final current = _session;
    if (current != null && current.call == call && current.node == node && current.open) return current;
    final pending = _connecting;
    if (pending != null) {
      final session = await pending;
      if (session.call == call && session.node == node) return session;
    }
    final attempt = _open(node, call);
    _connecting = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_connecting, attempt)) _connecting = null;
    }
  }

  Future<_Session> _open(ClusterNode node, String call) async {
    _closeSession(ClusterState.connecting, notify: false);
    _node = node;
    _setState(ClusterState.connecting);
    final ClusterLink link;
    try {
      link = await connect(node.host, node.port);
    } catch (e) {
      _fail('connectFailed', '$e');
      throw _ClusterFailure('connectFailed', '$e');
    }
    final session = _Session(node, call, link, onLine: _append, onClosed: _onSessionClosed, password: () => password(node));
    _session = session;
    try {
      await session.login(loginTimeout);
    } on _ClusterFailure catch (failure) {
      // Superseded — the server changed, or the session was closed — the
      // status is the replacement's to report, not this login's.
      if (!_isCurrent(session, node)) {
        _drop(session);
        rethrow;
      }
      _closeSession(ClusterState.failed, notify: false);
      _fail(failure.code, failure.message);
      rethrow;
    }
    if (!_isCurrent(session, node)) {
      _drop(session);
      throw const _ClusterFailure('disconnected', 'The server changed during the login');
    }
    _failures = 0;
    _error = null;
    _message = null;
    _setState(ClusterState.connected);
    return session;
  }

  /// Whether [session] is still the one the settings ask for.
  bool _isCurrent(_Session session, ClusterNode node) => identical(_session, session) && session.open && _node == node;

  /// Closes a superseded [session] without touching the status.
  void _drop(_Session session) {
    if (identical(_session, session)) _session = null;
    session.close();
  }

  void _onSessionClosed(_Session session) {
    if (!identical(session, _session)) return;
    _session = null;
    if (_disposed) return;
    if (_state == ClusterState.connected) {
      _error = 'disconnected';
      _message = session.closeReason;
      _setState(_subscribers.isEmpty ? ClusterState.idle : ClusterState.failed);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _subscribers.isEmpty || _reconnectTimer?.isActive == true) return;
    final delay = reconnectDelays[_failures.clamp(0, reconnectDelays.length - 1)];
    _failures++;
    _reconnectTimer = Timer(delay, () async {
      if (_subscribers.isEmpty) return;
      try {
        await _ensureSession();
      } on _ClusterFailure {
        _scheduleReconnect();
      }
    });
  }

  void _onSettingsChanged() {
    final node = ClusterSettings.node(settings);
    _trimLines();
    if (node == _node) return;
    _node = node;
    final session = _session;
    if (session == null) {
      notifyListeners();
      return;
    }
    // A subscriber is reading the old node; it reads the new one from here.
    _closeSession(ClusterState.idle);
    if (_subscribers.isNotEmpty) {
      _failures = 0;
      _scheduleReconnect();
    }
  }

  void _append(String text) {
    _lines.add(ClusterLine(++_lastSeq, nowMillis(), text));
    _trimLines();
    if (_subscribers.isNotEmpty && deliver != null) _flushTimer ??= Timer(batchDelay, _flush);
  }

  void _trimLines() {
    final size = ClusterSettings.scrollback(settings);
    while (_lines.length > size) {
      _lines.removeFirst();
    }
  }

  Future<void> _flush() async {
    _flushTimer = null;
    final deliver = this.deliver;
    if (_flushing || deliver == null) return;
    _flushing = true;
    try {
      await Future.wait([
        for (final entry in [..._subscribers.entries])
          if (entry.value < _lastSeq) _deliverTo(deliver, entry.key, entry.value),
      ]);
    } finally {
      _flushing = false;
    }
    if (_subscribers.entries.any((entry) => entry.value < _lastSeq)) _flushTimer ??= Timer(batchDelay, _flush);
  }

  Future<void> _deliverTo(ClusterLinesDelivery deliver, String subscriber, int cursor) async {
    final batch = lines(after: cursor);
    if (batch.isEmpty) return;
    // Moved before the delivery: a subscriber whose hook fails must not be
    // handed the same lines again on every flush after it.
    _subscribers[subscriber] = batch.last.seq;
    try {
      await deliver(subscriber, batch);
    } catch (e) {
      debugPrint('[cluster] delivery to $subscriber failed: $e');
    }
  }

  void _closeSession(ClusterState next, {bool notify = true}) {
    _idleTimer?.cancel();
    final session = _session;
    _session = null;
    session?.close();
    if (notify) _setState(next);
  }

  void _fail(String code, String? message) {
    _error = code;
    _message = message;
    _setState(ClusterState.failed);
  }

  void _setState(ClusterState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_onSettingsChanged);
    _idleTimer?.cancel();
    _reconnectTimer?.cancel();
    _flushTimer?.cancel();
    _session?.close();
    _session = null;
    super.dispose();
  }
}

/// The call a node is logged in with: the base call as the operator writes
/// it, uppercase, with no SSID — a spot reads `DX de KI2D`, as the operator
/// would post it by hand.
String? _normalizedCall(String? call) {
  final trimmed = call?.trim().toUpperCase() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class _ClusterFailure implements Exception {
  const _ClusterFailure(this.code, [this.message]);
  final String code;
  final String? message;
}

/// One telnet session: the login, then commands.
class _Session {
  _Session(this.node, this.call, this._link, {required this.onLine, required this.onClosed, required this.password}) {
    _subscription = _link.data.listen(_onData, onDone: _onDone, onError: (Object error) => _onDone(error), cancelOnError: true);
  }

  final ClusterNode node;
  final String call;
  final ClusterLink _link;
  final void Function(String text) onLine;
  final void Function(_Session session) onClosed;
  final Future<String?> Function() password;

  late final StreamSubscription<List<int>> _subscription;
  final _decoder = ClusterLineDecoder();
  bool open = true;

  /// Why the connection ended, when the node or the network ended it.
  String? closeReason;

  bool _callSent = false;
  bool _passwordSent = false;
  Completer<void>? _loggedIn = Completer<void>();

  /// The reply being collected, if a command is out, and what ends it: true
  /// at the node's next prompt, false when the connection closes first.
  List<String>? _reply;
  Completer<bool>? _prompted;

  Future<void> login(Duration timeout) async {
    final loggedIn = _loggedIn!;
    try {
      await loggedIn.future.timeout(timeout);
    } on TimeoutException {
      // No command prompt is no login, even from a node that took the call:
      // it may still be asking something this session did not recognize,
      // and whatever is sent next would be the answer. An operator who
      // turned prompts off on a node turns them back on (SET/PROMPT).
      throw _ClusterFailure('loginFailed', _callSent ? 'The node never showed its command prompt' : 'The node never asked for a callsign');
    } finally {
      _loggedIn = null;
    }
  }

  Future<ClusterReply> command(String line, Duration timeout) async {
    if (!open) throw const _ClusterFailure('disconnected');
    final reply = _reply = <String>[];
    final prompted = _prompted = Completer<bool>();
    _link.write(encodeClusterLine(line));
    try {
      if (!await prompted.future.timeout(timeout)) return ClusterReply.failed('disconnected', lines: reply);
    } on TimeoutException {
      // A node that answers without a prompt after it — or a user who turned
      // prompts off on this node — still answered.
      if (reply.isEmpty) return const ClusterReply.failed('timeout');
    } finally {
      _reply = null;
      _prompted = null;
    }
    return ClusterReply.ok(reply);
  }

  /// How long the node must stay silent after what reads as a login or
  /// password prompt before it is answered. A real prompt waits for its
  /// answer; text that only ends like one — a banner or welcome text the
  /// network cut there, a line ending "set your password:" — is followed by
  /// more, which cancels the answer ([_onData]).
  static const promptQuiet = Duration(milliseconds: 300);
  Timer? _promptTimer;

  void _onData(List<int> bytes) {
    _promptTimer?.cancel();
    final lines = _decoder.add(bytes);
    for (final text in lines) {
      _take(text);
    }
    final partial = _decoder.partial;
    if (partial.trim().isEmpty) {
      // Nothing after the last newline: that line is where the node stopped,
      // and may be a prompt it ended with one.
      final last = lines.lastWhere((line) => line.trim().isNotEmpty, orElse: () => '');
      if (isPromptLine(last) && _awaits(last)) _promptTimer = Timer(promptQuiet, () => _answer(last));
      return;
    }
    if (_awaits(partial)) {
      _promptTimer = Timer(promptQuiet, () {
        _take(_decoder.takePartial());
        _answer(partial);
      });
    } else if (isCommandPrompt(partial, call)) {
      _take(_decoder.takePartial());
    }
  }

  /// Whether [text] is a login prompt this session still has to answer.
  bool _awaits(String text) => _loggedIn != null && !_loggedIn!.isCompleted && (isPasswordPrompt(text) || (!_callSent && isLoginPrompt(text)));

  /// Answers the call or password prompt [text].
  void _answer(String text) {
    if (!open || !_awaits(text)) return;
    if (isPasswordPrompt(text)) {
      unawaited(_answerPassword());
      return;
    }
    _callSent = true;
    _link.write(encodeClusterLine(call));
  }

  Future<void> _answerPassword() async {
    if (_passwordSent) {
      _failLogin(const _ClusterFailure('loginFailed', 'The node refused the password'));
      return;
    }
    _passwordSent = true;
    final secret = await password();
    if (secret == null || secret.isEmpty) {
      _failLogin(const _ClusterFailure('needsPassword'));
      return;
    }
    if (open) _link.write(encodeClusterLine(secret));
  }

  void _failLogin(_ClusterFailure failure) {
    final loggedIn = _loggedIn;
    if (loggedIn != null && !loggedIn.isCompleted) loggedIn.completeError(failure);
  }

  void _take(String text) {
    onLine(text);
    if (isCommandPrompt(text, call)) {
      final loggedIn = _loggedIn;
      if (loggedIn != null && !loggedIn.isCompleted) loggedIn.complete();
      final prompted = _prompted;
      if (prompted != null && !prompted.isCompleted) prompted.complete(true);
      return;
    }
    _reply?.add(text);
  }

  void _onDone([Object? error]) {
    if (!open) return;
    open = false;
    _promptTimer?.cancel();
    closeReason = error == null ? 'The node closed the connection' : '$error';
    _failLogin(_ClusterFailure('disconnected', closeReason));
    final prompted = _prompted;
    if (prompted != null && !prompted.isCompleted) prompted.complete(false);
    onClosed(this);
  }

  void close() {
    if (!open) return;
    open = false;
    // Ended here rather than left to time out: a login or a command still
    // waiting on this session would otherwise answer, late, for a session
    // that is gone.
    _promptTimer?.cancel();
    _failLogin(const _ClusterFailure('disconnected', 'The session was closed'));
    final prompted = _prompted;
    if (prompted != null && !prompted.isCompleted) prompted.complete(false);
    unawaited(_subscription.cancel());
    // A courtesy the node logs as a clean logout; nothing waits on it.
    try {
      _link.write(encodeClusterLine('bye'));
    } catch (_) {}
    unawaited(_link.close());
  }
}
