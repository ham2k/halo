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

enum ClusterTranscriptKind { received, sent, status, retry, gaveUp }

/// One entry in the console's account of a session: a line either way, a
/// change of state, a command going out again, or one abandoned.
@immutable
class ClusterTranscriptEntry {
  const ClusterTranscriptEntry(this.at, this.kind, {this.text = '', this.status});

  /// On the app clock.
  final int at;
  final ClusterTranscriptKind kind;

  /// The line, or for [ClusterTranscriptKind.retry] and
  /// [ClusterTranscriptKind.gaveUp] the command.
  final String text;

  /// For [ClusterTranscriptKind.status], and why a
  /// [ClusterTranscriptKind.gaveUp] command was abandoned.
  final ClusterStatus? status;
}

/// Everything the console shows, kept to the scrollback size. Its own
/// notifier: a line arrives far more often than the status changes, and the
/// service's listeners (the Settings section) have no use for each one.
class ClusterTranscript extends ChangeNotifier {
  ClusterTranscript(this._size);

  final int Function() _size;
  final _entries = ListQueue<ClusterTranscriptEntry>();

  List<ClusterTranscriptEntry> get entries => List.unmodifiable(_entries);

  void add(ClusterTranscriptEntry entry) {
    _entries.add(entry);
    _trim();
    notifyListeners();
  }

  /// After the scrollback setting changes.
  void trim() {
    if (_trim()) notifyListeners();
  }

  bool _trim() {
    final size = _size();
    final trimmed = _entries.length > size;
    while (_entries.length > size) {
      _entries.removeFirst();
    }
    return trimmed;
  }
}

/// What a command came back with.
///
/// [error] codes: `unsupported` (no sockets on this platform), `off` (the
/// operator turned the cluster connection off), `noCall` (no
/// operator to log in as), `connectFailed`, `needsPassword`, `loginFailed`,
/// `disconnected`, `timeout`, `refused` (the node said no; [message] quotes
/// it), `tooSoon` (spots are spaced [ClusterService.spotInterval] apart),
/// `invalidCall`, `invalidFrequency`. A command answers `connectFailed`,
/// `disconnected` or `timeout` only once no further attempt fits in
/// [ClusterService.deadline].
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
    this.connectTimeout = const Duration(seconds: 5),
    this.loginTimeout = const Duration(seconds: 5),
    this.replyTimeout = const Duration(seconds: 5),
    this.batchDelay = const Duration(seconds: 1),
    this.spotInterval = const Duration(seconds: 5),
    this.deadline = const Duration(seconds: 14),
    this.reconnectDelays = const [Duration(seconds: 5), Duration(seconds: 15), Duration(minutes: 1), Duration(minutes: 5)],
  }) {
    _node = ClusterSettings.node(settings);
    _enabled = ClusterSettings.connects(settings);
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

  /// Each step's own limit, within what [deadline] leaves.
  final Duration connectTimeout;
  final Duration loginTimeout;
  final Duration replyTimeout;
  final Duration batchDelay;

  /// The least time between two spots. A node's own flood control blocks a
  /// spotter it sees repeating, and the block outlives this session — an
  /// extension in a loop would cost the operator their spotting on that
  /// node, not just one refusal.
  final Duration spotInterval;

  /// How long a command has, from when it is asked for to its answer: the
  /// wait behind other commands, every attempt and each attempt's connect,
  /// login and reply all fit inside it. Under the 15 seconds a spots hook
  /// has to answer (`ExtensionService.sendSpot`), since past that the hook
  /// reports a timeout while the spot may still go out.
  ///
  /// Within it, a command that was not confirmed — the connection dropped
  /// under it, the node never answered, the reconnect failed — is sent again
  /// on a fresh session. A command the node took before the drop then goes
  /// out twice, which is the lesser harm for a spot: a node drops a duplicate
  /// before passing it on, and an operator whose spot silently never went out
  /// has no way to tell. Any other command can repeat too
  /// (docs/design/cluster.md § Lifecycle).
  final Duration deadline;

  /// The failures [deadline] retries.
  static const _unconfirmed = {'disconnected', 'timeout', 'connectFailed'};

  /// Between two attempts at one command, so a node that refuses connections
  /// outright is not dialled in a tight loop.
  static const _retryPause = Duration(seconds: 1);

  /// The least time left in [deadline] that an attempt starts with. Less, and
  /// the reply would get a wait no node answers in: the command would go out
  /// and be reported as failed.
  static const _leastAttempt = Duration(seconds: 2);

  /// How long a dropped session waits before reconnecting, per consecutive
  /// failure; the last repeats. Only while something is subscribed — a
  /// session kept for a send has nobody waiting on it.
  final List<Duration> reconnectDelays;

  /// Delivers new lines to subscribers; set by whoever wires the service to
  /// the extensions.
  ClusterLinesDelivery? deliver;

  late ClusterNode _node;
  late bool _enabled;
  late final transcript = ClusterTranscript(() => ClusterSettings.scrollback(settings));
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

  /// The console asked for the session to stay up while it is open.
  bool _held = false;

  /// The console's Disconnect, until something next asks for the session:
  /// no reconnect, no retry, and a connect already under way is dropped.
  bool _parked = false;

  /// Whether a dropped session should come back on its own.
  bool get _wanted => _subscribers.isNotEmpty || _held;

  ClusterStatus get status => !supported
      ? ClusterStatus(state: ClusterState.failed, node: _node, error: 'unsupported', lastSeq: _lastSeq)
      : !_enabled
      ? ClusterStatus(state: ClusterState.failed, node: _node, error: 'off', lastSeq: _lastSeq)
      : ClusterStatus(state: _state, node: _node, call: _session?.call, error: _error, message: _message, lastSeq: _lastSeq);

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
  Future<ClusterStatus> subscribe(String subscriber) {
    _subscribers.putIfAbsent(subscriber, () => _lastSeq);
    return _keepUp();
  }

  void unsubscribe(String subscriber) {
    if (_subscribers.remove(subscriber) == null) return;
    if (!_wanted) {
      _reconnectTimer?.cancel();
      _armIdle();
    }
  }

  /// The console's Connect: logs in, and keeps the session up — reconnecting
  /// it if it drops — until [disconnect] or [release].
  Future<ClusterStatus> stayConnected() {
    _held = true;
    return _keepUp();
  }

  /// Connects for a session [_wanted] now keeps up, or schedules the retry.
  Future<ClusterStatus> _keepUp() async {
    _parked = false;
    _idleTimer?.cancel();
    try {
      await _ensureSession();
    } on _ClusterFailure {
      _scheduleReconnect();
    }
    return status;
  }

  /// The console's Disconnect: closes the session now. It stays closed, even
  /// with subscribers, until something next asks for it — a command, a
  /// spot, a subscription or Connect: only a drop the node or the network
  /// causes reconnects on its own.
  void disconnect() {
    _held = false;
    _parked = true;
    _reconnectTimer?.cancel();
    _closeSession(ClusterState.idle);
  }

  /// The console closed: the session goes back to the usual rules.
  void release() {
    if (!_held) return;
    _held = false;
    if (!_wanted) _reconnectTimer?.cancel();
    _armIdle();
  }

  /// Drops every subscriber not in [keep] — the extensions a restarted
  /// runtime no longer has, whose hooks no delivery could reach.
  void retainSubscribers(Set<String> keep) {
    for (final key in [..._subscribers.keys]) {
      if (!keep.contains(key)) unsubscribe(key);
    }
  }

  /// Sends one command line and collects the reply.
  Future<ClusterReply> send(String command) {
    final until = realNowMillis() + deadline.inMilliseconds;
    return _serialized(() => _send(command, until));
  }

  /// Posts a spot of [call] on [freqKHz], logged in as [loginCall].
  Future<ClusterReply> postSpot({required double freqKHz, required String call, String? comment}) {
    final until = realNowMillis() + deadline.inMilliseconds;
    return _serialized(() async {
      final built = spotCommand(freqKHz: freqKHz, call: call, comment: comment);
      if (built.command == null) return ClusterReply.failed(built.error);
      final lastSpotAt = _lastSpotAt;
      if (lastSpotAt != null && realNowMillis() - lastSpotAt < spotInterval.inMilliseconds) return const ClusterReply.failed('tooSoon');
      final reply = await _send(built.command!, until);
      if (!reply.ok) return reply;
      _lastSpotAt = realNowMillis();
      final refusal = reply.lines.where(isRefusal).firstOrNull;
      // A refusal outranks an echo: DXSpider echoes a spot it keeps local, and
      // a node that refuses one says so in the same reply.
      if (refusal != null) return ClusterReply.failed('refused', message: refusal.trim(), lines: reply.lines);
      return reply;
    });
  }

  Future<ClusterReply> _serialized(Future<ClusterReply> Function() run) {
    final result = _commands.then((_) => run());
    _commands = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ClusterReply> _send(String command, int until) async {
    _idleTimer?.cancel();
    _parked = false;
    try {
      var reply = _left(deadline, until) >= _leastAttempt ? await _attempt(command, until) : const ClusterReply.failed('timeout');
      while (!reply.ok && _retries(reply) && _left(deadline, until) >= _retryPause + _leastAttempt) {
        await Future<void>.delayed(_retryPause);
        if (_disposed || _parked || !_enabled) break;
        transcript.add(ClusterTranscriptEntry(nowMillis(), ClusterTranscriptKind.retry, text: command));
        reply = await _attempt(command, until);
      }
      // A command the off switch cut short answers as every later one does.
      if (!reply.ok && !_enabled && supported) reply = ClusterReply.failed('off', lines: reply.lines);
      if (!reply.ok) _gaveUp(command, reply);
      return reply;
    } finally {
      _armIdle();
    }
  }

  /// Whether [reply] leaves its command unconfirmed. A node that answered
  /// before it hung up took the command: `bye` is answered that way, and
  /// sending it again would only log in to be thrown out again. A spot from
  /// the network arriving meanwhile is no answer.
  bool _retries(ClusterReply reply) =>
      !_disposed &&
      !_parked &&
      _enabled &&
      _unconfirmed.contains(reply.error) &&
      !(reply.error == 'disconnected' && reply.lines.any((line) => !isBroadcast(line)));

  /// [limit], or what is left before [until] when that is less.
  static Duration _left(Duration limit, int until) {
    final left = until - realNowMillis();
    return left <= 0 ? Duration.zero : (left < limit.inMilliseconds ? Duration(milliseconds: left) : limit);
  }

  /// A command abandoned for good shows up in the console, and in the status
  /// when nothing holds the session — otherwise a test that timed out would
  /// read as "Not connected", and a command typed there would vanish.
  void _gaveUp(String command, ClusterReply reply) {
    if (_disposed) return;
    final error = reply.error;
    if (_unconfirmed.contains(error) && _state == ClusterState.idle && _enabled && !_parked) _fail(error!, reply.message);
    transcript.add(
      ClusterTranscriptEntry(
        nowMillis(),
        ClusterTranscriptKind.gaveUp,
        text: command,
        status: ClusterStatus(state: ClusterState.failed, node: _node, error: error, message: reply.message, lastSeq: _lastSeq),
      ),
    );
  }

  Future<ClusterReply> _attempt(String command, int until) async {
    try {
      final session = await _ensureSession(until: until);
      final wait = _left(replyTimeout, until);
      final reply = await session.command(command, wait);
      // Only a node silent for the whole reply timeout is taken for gone: a
      // wait the deadline cut short says nothing about the session.
      if (reply.error == 'timeout' && wait == replyTimeout) _abandon(session);
      return reply;
    } on _ClusterFailure catch (failure) {
      return ClusterReply.failed(failure.code, message: failure.message);
    }
  }

  /// Closes [session] as dropped once it leaves a command unanswered. A
  /// connection the network lost without a reset still reads as open, and
  /// keeps taking writes, until the OS gives up on it minutes later — every
  /// command until then would wait out its timeout on a dead line.
  void _abandon(_Session session) {
    if (!identical(session, _session)) return;
    _closeSession(ClusterState.idle, notify: false);
    _error = 'timeout';
    _message = null;
    _setState(_wanted ? ClusterState.failed : ClusterState.idle);
    _scheduleReconnect();
  }

  void _armIdle() {
    _idleTimer?.cancel();
    if (_wanted || _disposed) return;
    _idleTimer = Timer(idleTimeout, () {
      if (!_wanted) _closeSession(ClusterState.idle);
    });
  }

  /// The logged-in session for the current node and operator, opening one —
  /// or replacing one logged in as someone else, or to another node.
  ///
  /// [until] bounds the wait, for a command that has to answer by then.
  Future<_Session> _ensureSession({int? until}) async {
    if (!supported) throw const _ClusterFailure('unsupported');
    if (!_enabled) throw const _ClusterFailure('off');
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
      final _Session session;
      try {
        session = until == null ? await pending : await pending.timeout(_left(deadline, until));
      } on TimeoutException {
        throw const _ClusterFailure('timeout');
      }
      if (session.call == call && session.node == node) return session;
    }
    final attempt = _open(node, call, until);
    _connecting = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_connecting, attempt)) _connecting = null;
    }
  }

  Future<_Session> _open(ClusterNode node, String call, int? until) async {
    _closeSession(ClusterState.connecting, notify: false);
    _node = node;
    _setState(ClusterState.connecting);
    final ClusterLink link;
    try {
      link = await connect(node.host, node.port, until == null ? connectTimeout : _left(connectTimeout, until));
    } catch (e) {
      if (_parked || !_enabled) throw _ClusterFailure(_enabled ? 'disconnected' : 'off');
      _fail('connectFailed', '$e');
      throw _ClusterFailure('connectFailed', '$e');
    }
    // Off, or Disconnect, while the connect was under way: there was no
    // session yet for either to close.
    if (_parked || !_enabled) {
      unawaited(link.close());
      throw _ClusterFailure(_enabled ? 'disconnected' : 'off');
    }
    final session = _Session(node, call, link, onLine: _append, onSent: _sent, onClosed: _onSessionClosed, password: () => password(node));
    _session = session;
    final loginWait = until == null ? loginTimeout : _left(loginTimeout, until);
    try {
      await session.login(loginWait);
    } on _ClusterFailure catch (failure) {
      // The node hung up on the call — one it will not take. Not a drop to
      // retry: logging in again and again is how a node comes to ban one.
      if (session.closeReason != null && _session == null && _node == node && _enabled && !_parked) {
        _fail('loginFailed', session.closeReason);
        throw _ClusterFailure('loginFailed', session.closeReason);
      }
      // Superseded — the server changed, or the session was closed — the
      // status is the replacement's to report, not this login's.
      if (!_isCurrent(session, node)) {
        _drop(session);
        rethrow;
      }
      _closeSession(ClusterState.failed, notify: false);
      // Out of time is not the node refusing the login.
      final code = failure.code == 'loginFailed' && loginWait < loginTimeout ? 'timeout' : failure.code;
      _fail(code, code == failure.code ? failure.message : null);
      throw _ClusterFailure(code, code == failure.code ? failure.message : null);
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
      _setState(_wanted ? ClusterState.failed : ClusterState.idle);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !supported || !_enabled || _parked || !_wanted || _reconnectTimer?.isActive == true) return;
    final delay = reconnectDelays[_failures.clamp(0, reconnectDelays.length - 1)];
    _failures++;
    _reconnectTimer = Timer(delay, _reconnect);
  }

  Future<void> _reconnect() async {
    if (!_wanted || _parked) return;
    try {
      await _ensureSession();
    } on _ClusterFailure {
      _scheduleReconnect();
    }
  }

  void _onSettingsChanged() {
    final node = ClusterSettings.node(settings);
    _trimLines();
    transcript.trim();
    final enabled = ClusterSettings.connects(settings);
    if (enabled != _enabled) {
      final before = status;
      _enabled = enabled;
      _node = node;
      _failures = 0;
      _reconnectTimer?.cancel();
      _closeSession(ClusterState.idle, notify: false);
      _setState(ClusterState.idle, before: before);
      if (enabled) unawaited(_reconnect());
      return;
    }
    if (node == _node) return;
    _node = node;
    final session = _session;
    if (session == null) {
      notifyListeners();
      return;
    }
    // A subscriber is reading the old node; it reads the new one from here.
    _closeSession(ClusterState.idle);
    if (_wanted) {
      _failures = 0;
      _scheduleReconnect();
    }
  }

  void _append(String text) {
    final at = nowMillis();
    _lines.add(ClusterLine(++_lastSeq, at, text));
    transcript.add(ClusterTranscriptEntry(at, ClusterTranscriptKind.received, text: text));
    _trimLines();
    if (_subscribers.isNotEmpty && deliver != null) _flushTimer ??= Timer(batchDelay, _flush);
  }

  void _sent(String text) => transcript.add(ClusterTranscriptEntry(nowMillis(), ClusterTranscriptKind.sent, text: text));

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

  /// [before] for a change [status] already shows, such as the off switch.
  void _setState(ClusterState state, {ClusterStatus? before}) {
    before ??= status;
    _state = state;
    if (_disposed) return;
    final after = status;
    if (after.state != before.state || after.error != before.error || after.call != before.call) {
      transcript.add(ClusterTranscriptEntry(nowMillis(), ClusterTranscriptKind.status, status: after));
    }
    notifyListeners();
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
    transcript.dispose();
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
  _Session(this.node, this.call, this._link, {required this.onLine, required this.onSent, required this.onClosed, required this.password}) {
    _subscription = _link.data.listen(_onData, onDone: _onDone, onError: (Object error) => _onDone(error), cancelOnError: true);
  }

  final ClusterNode node;
  final String call;
  final ClusterLink _link;
  final void Function(String text) onLine;

  /// Each line sent, but the password.
  final void Function(String text) onSent;
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
    onSent(line);
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
    onSent(call);
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
