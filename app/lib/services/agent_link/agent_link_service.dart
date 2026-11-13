// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link (docs/design/agent-link.md): listens for `halo-mcp`, asks
// the operator about an app it has not seen, keeps the grants, and hands each
// message to the endpoint extension.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../error_reporting_service.dart';
import 'agent_link_model.dart';
import 'agent_link_peer.dart';
import 'agent_link_socket.dart';

/// Where messages go: the `mcp` core extension, through its `agentLink` hook.
abstract interface class AgentLinkEndpoint {
  /// Whether there is anything to hand messages to. An app is answered
  /// `unavailable` rather than asked about while there is not.
  bool get available;

  /// The messages to send back for [message], in order.
  Future<List<Map<String, dynamic>>> handle({
    required String connection,
    required AgentClient client,
    required AgentAccess access,
    required Map<String, dynamic> message,
  });
}

/// The grants as stored: grant id → its JSON.
abstract interface class AgentGrantStore {
  Map<String, dynamic> read();
  Future<void> write(Map<String, dynamic> grants);
}

/// A question for the operator about one app, by the token its command
/// presented. It stays until answered: an app that stops waiting is let in
/// by the answer the next time it connects with that token.
class AgentLinkRequest {
  final AgentClient client;
  final String tokenHash;
  final _answer = Completer<AgentAccess?>();
  final _withdrawn = Completer<void>();
  final _peers = <AgentLinkPeer>{};
  final _waiting = ValueNotifier(false);

  AgentLinkRequest(this.client, this.tokenHash);

  /// Completes when the link stops before an answer: a dialog still asking
  /// about it closes.
  Future<void> get withdrawn => _withdrawn.future;

  /// Whether the app is still connected, waiting on the answer.
  ValueListenable<bool> get waiting => _waiting;

  void _attach(AgentLinkPeer peer) {
    _peers.add(peer);
    _waiting.value = true;
    unawaited(
      peer.done.then((_) {
        _peers.remove(peer);
        _waiting.value = _peers.isNotEmpty;
      }),
    );
  }
}

/// Why the link is not listening, for Settings to say.
enum AgentLinkFailure {
  /// Another program holds the port, or the system reserves it.
  portUnavailable,
  other,
}

class AgentLinkService extends ChangeNotifier {
  final AgentGrantStore _store;
  final AgentLinkEndpoint _endpoint;
  final bool Function() _wanted;
  final Listenable? _changes;
  final int _port;
  final Duration helloTimeout;
  final Future<AgentLinkListener> Function({required int port, required void Function(AgentLinkPeer peer) onPeer}) _bind;
  final int Function() _now;

  AgentLinkService({
    required this._store,
    required this._endpoint,
    required this._wanted,
    required this._port,
    this._changes,
    this.helloTimeout = const Duration(seconds: 10),
    Future<AgentLinkListener> Function({required int port, required void Function(AgentLinkPeer peer) onPeer})? bind,
    required this._now,
  }) : _bind = bind ?? bindAgentLink {
    _changes?.addListener(_follow);
    _follow();
  }

  AgentLinkListener? _listener;
  bool _binding = false;
  AgentLinkFailure? _failure;
  Timer? _retry;
  bool _disposed = false;
  int _nextConnection = 0;

  final _requests = <AgentLinkRequest>[];
  final _connections = <String, ({String grantId, AgentLinkPeer peer})>{};

  /// The port it listens on, null while it is not listening.
  int? get port => _listener?.port;

  /// The port it listens on, or tries to.
  int get wantedPort => _port;

  AgentLinkFailure? get failure => _failure;

  /// The app the operator is being asked about, first come first asked.
  AgentLinkRequest? get pendingRequest => _requests.firstOrNull;

  /// Every app the operator allowed, oldest first.
  List<AgentGrant> get grants {
    final stored = _store.read();
    return [for (final entry in stored.entries) ?AgentGrant.fromJson(entry.key, entry.value)]..sort((a, b) => a.grantedAt.compareTo(b.grantedAt));
  }

  /// How many connections [grantId] has open.
  int connectionsOf(String grantId) => _connections.values.where((c) => c.grantId == grantId).length;

  /// The operator's answer to [request]: an access, or null to deny. An
  /// allow is kept as a grant whether or not the app is still waiting. An
  /// answer to a request already withdrawn changes nothing.
  Future<void> answer(AgentLinkRequest request, AgentAccess? access) async {
    if (!_requests.remove(request)) return;
    if (access != null) {
      final grant = AgentGrant(
        id: mintAgentLinkToken().substring(0, 12),
        client: request.client,
        access: access,
        tokenHash: request.tokenHash,
        grantedAt: _now(),
      );
      try {
        await _store.write({..._store.read(), grant.id: grant.toJson()});
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'AgentLink:grant');
        // Withdrawn rather than denied: the app is told to try again, which
        // asks the operator again, instead of waiting on an answer that
        // never comes or hearing a refusal nobody gave.
        _settle(request);
        return;
      }
    }
    if (!request._answer.isCompleted) request._answer.complete(access);
    if (!_disposed) notifyListeners();
  }

  /// Changes what [grantId] may do, from its next message on; null forgets
  /// it and hangs up its connections, so its next connection asks again.
  Future<void> setAccess(String grantId, AgentAccess? access) async {
    final stored = {..._store.read()};
    final grant = AgentGrant.fromJson(grantId, stored[grantId]);
    if (grant == null) return;
    if (access == null) {
      stored.remove(grantId);
    } else {
      stored[grantId] = grant.copyWith(access: access).toJson();
    }
    await _store.write(stored);
    if (access == null) {
      for (final connection in [..._connections.values.where((c) => c.grantId == grantId)]) {
        await connection.peer.close();
      }
    }
    notifyListeners();
  }

  void _follow() {
    if (_disposed) return;
    if (_wanted()) {
      unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (_listener != null || _binding) return;
    _binding = true;
    _retry?.cancel();
    try {
      final listener = await _bind(port: _port, onPeer: (peer) => unawaited(_serve(peer)));
      if (_disposed || !_wanted()) {
        await listener.close();
        return;
      }
      _listener = listener;
      _failure = null;
      ErrorReportingService.recordSuccess(_bindReportKey);
      debugPrint('[agent-link] listening on 127.0.0.1:${listener.port}');
    } catch (e, st) {
      _failure = agentLinkPortUnavailable(e) ? AgentLinkFailure.portUnavailable : AgentLinkFailure.other;
      // Once per streak: the retry below would otherwise upload the same
      // failure every ten seconds for the rest of the session.
      if (_failure == AgentLinkFailure.other) ErrorReportingService.reportIfRepeated(_bindReportKey, e, st, context: 'AgentLink:bind');
      debugPrint('[agent-link] could not listen on $_port: $e');
      // Another program, or another copy of this edition, may let go of the
      // port; the link comes up then without the operator doing anything.
      _retry = Timer(const Duration(seconds: 10), _follow);
    } finally {
      _binding = false;
      if (!_disposed) notifyListeners();
    }
  }

  static const _bindReportKey = 'agentLink:bind';

  Future<void> _stop() async {
    _retry?.cancel();
    final listener = _listener;
    // Followed on every settings change while the experiment is off: a stop
    // with nothing to stop says nothing.
    if (listener == null && _failure == null && _requests.isEmpty) return;
    _listener = null;
    _failure = null;
    for (final request in [..._requests]) {
      _settle(request);
    }
    if (listener != null) await listener.close();
    if (!_disposed) notifyListeners();
  }

  Future<void> _serve(AgentLinkPeer peer) async {
    final lines = StreamIterator(peer.lines);
    try {
      final String first;
      try {
        if (!await lines.moveNext().timeout(helloTimeout)) return;
        first = lines.current;
      } on TimeoutException {
        return;
      }
      final hello = parseAgentHello(first);
      if (hello == null) {
        // A hello of another version is a halo-mcp that does not match this
        // app, and told so. Anything else is not ours — a web page's HTTP
        // request, most likely — and nothing is answered: a reply would be
        // something for that page to read.
        if (isAgentHelloOfAnyVersion(first)) _refuse(peer, 'protocol');
        return;
      }
      if (!_endpoint.available) {
        _refuse(peer, 'unavailable');
        return;
      }
      final token = hello.token;
      if (token == null) {
        _refuse(peer, 'protocol');
        return;
      }
      var grant = _grantFor(token);
      if (grant == null) {
        final request = await _ask(hello.client, agentTokenHash(token), peer);
        if (request == null) return;
        grant = _grantFor(token);
        if (grant == null) {
          // The link stopping withdraws the question; nobody refused.
          _refuse(peer, request._withdrawn.isCompleted ? 'unavailable' : 'denied');
          return;
        }
      }
      peer.send(jsonEncode({'agentLink': kAgentLinkVersion, 'ok': true, 'access': grant.access.name}));
      grant = grant.copyWith(lastSeenAt: _now());
      try {
        await _store.write({..._store.read(), grant.id: grant.toJson()});
      } catch (e, st) {
        // Bookkeeping only: Settings shows an older "last seen".
        ErrorReportingService.report(e, st, context: 'AgentLink:lastSeen');
      }
      final connection = 'c${_nextConnection++}';
      _connections[connection] = (grantId: grant.id, peer: peer);
      notifyListeners();
      try {
        while (await lines.moveNext()) {
          final Object? message;
          try {
            message = jsonDecode(lines.current);
          } on FormatException {
            _rpcError(peer, null, -32700, 'Not JSON');
            continue;
          }
          if (message is Map<String, dynamic>) {
            unawaited(_deliver(connection, grant.id, peer, message));
          } else {
            // A batch, or a bare value: MCP sends neither since 2025-06-18.
            _rpcError(peer, null, -32600, 'One JSON-RPC message per line');
          }
        }
      } finally {
        _connections.remove(connection);
        if (!_disposed) notifyListeners();
      }
    } finally {
      await lines.cancel();
      await peer.close();
    }
  }

  /// The grant whose token [token] is, if any.
  AgentGrant? _grantFor(String token) {
    final hash = agentTokenHash(token);
    for (final grant in grants) {
      if (grant.tokenHash == hash) return grant;
    }
    return null;
  }

  /// Asks the operator about the app presenting [tokenHash], and waits for
  /// the answer: the question once it is answered or withdrawn, null when
  /// the app hung up first. An app that connects again while the question
  /// is up waits on the same question rather than raising a second one.
  Future<AgentLinkRequest?> _ask(AgentClient client, String tokenHash, AgentLinkPeer peer) async {
    var request = _requests.where((r) => r.tokenHash == tokenHash).firstOrNull;
    if (request == null) {
      request = AgentLinkRequest(client, tokenHash);
      _requests.add(request);
      notifyListeners();
    }
    request._attach(peer);
    final asked = request;
    return Future.any([asked._answer.future.then((_) => asked), peer.done.then((_) => null)]);
  }

  /// Ends [request] without the operator: the dialog asking about it closes.
  void _settle(AgentLinkRequest request) {
    if (request._answer.isCompleted) return;
    _withdraw(request);
    request._answer.complete(null);
  }

  void _withdraw(AgentLinkRequest request) {
    _requests.remove(request);
    if (!request._withdrawn.isCompleted) request._withdrawn.complete();
    if (!_disposed) notifyListeners();
  }

  void _refuse(AgentLinkPeer peer, String reason) => peer.send(jsonEncode({'agentLink': kAgentLinkVersion, 'ok': false, 'reason': reason}));

  Future<void> _deliver(String connection, String grantId, AgentLinkPeer peer, Map<String, dynamic> message) async {
    // Read per message: an access the operator changed applies from the next
    // one, and a grant removed meanwhile answers nothing more.
    final grant = grants.where((g) => g.id == grantId).firstOrNull;
    if (grant == null) {
      await peer.close();
      return;
    }
    // The endpoint stopped under a connected app (the runtime restarting):
    // hung up, so the app's next connection is answered `unavailable`.
    if (!_endpoint.available) {
      await peer.close();
      return;
    }
    try {
      final replies = await _endpoint.handle(connection: connection, client: grant.client, access: grant.access, message: message);
      for (final reply in replies) {
        peer.send(jsonEncode(reply));
      }
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'AgentLink:handle');
      final id = message['id'];
      // A request the agent waits on is answered even when the endpoint
      // failed: an unanswered one holds the agent until its own timeout.
      if (id != null) _rpcError(peer, id, -32603, 'Ham2K Logger could not answer: $e');
    }
  }

  void _rpcError(AgentLinkPeer peer, Object? id, int code, String text) => peer.send(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': text},
    }),
  );

  /// Ends the link for good: at exit, and in tests.
  Future<void> closeForExit() async {
    _disposed = true;
    _changes?.removeListener(_follow);
    _retry?.cancel();
    for (final request in [..._requests]) {
      _settle(request);
    }
    final listener = _listener;
    _listener = null;
    if (listener != null) await listener.close();
  }
}

/// The grants in the app's preferences, under one key.
class PrefsAgentGrantStore implements AgentGrantStore {
  static const key = 'agentLink.grants';

  final Map<String, dynamic> Function(String key) _read;
  final Future<void> Function(String key, Map<String, dynamic> value) _write;

  PrefsAgentGrantStore({required this._read, required this._write});

  @override
  Map<String, dynamic> read() => _read(key);

  @override
  Future<void> write(Map<String, dynamic> grants) => _write(key, grants);
}
