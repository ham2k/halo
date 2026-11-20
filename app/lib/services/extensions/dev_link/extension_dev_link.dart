// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension dev link (docs/design/extension-dev-link.md): lets a dev
// tool on this machine (`h2kext-dev`) ask the running app to load the
// extension it serves, so an author never types an address. Listens on
// loopback while Developer Mode is on, asks the operator about each tool,
// and runs one dev client per tool allowed.
//
// The operator's allow lasts for this app session and is never stored:
// what it lets in is code, and an allow that outlived the session would let
// any later process naming the same folder in without anyone being asked.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../agent_link/agent_link_peer.dart';
import '../../agent_link/agent_link_socket.dart';
import '../../error_reporting_service.dart';
import '../extension_dev_client.dart';

/// The link's protocol version: the `extDevLink` every line carries.
const kExtensionDevLinkVersion = 1;

/// The ports a build listens on, first free one taken. One per edition, so
/// a dev tool reaches the edition its author picks; a Dev build has a range,
/// since several worktrees' Dev builds may run at once.
List<int> extensionDevLinkPorts(String edition) => switch (edition) {
  'prod' => const [47390],
  'next' => const [47391],
  _ => const [47392, 47393, 47394, 47395, 47396, 47397, 47398, 47399],
};

/// What a dev tool asked to run.
@immutable
class ExtensionDevLinkAsk {
  /// The tool's own name and version, as it says them.
  final String tool;
  final String toolVersion;

  /// The extension project's folder, as the tool says it.
  final String dir;

  /// The extension keys it will serve. The dev client takes no others.
  final List<String> keys;

  /// The tool's dev server, always on this machine.
  final Uri server;

  const ExtensionDevLinkAsk({required this.tool, required this.toolVersion, required this.dir, required this.keys, required this.server});

  /// What the operator's allow covers: the same folder serving the same
  /// keys. A tool restarted on it gets back in without asking; one serving
  /// another extension from it asks again.
  String get allowId => [
    dir,
    ...([...keys]..sort()),
  ].join('\n');
}

/// The ask in [hello], or null when it is not one: a field missing or of the
/// wrong type, a key that is not a string, a server that is not plain HTTP
/// on this machine.
@visibleForTesting
ExtensionDevLinkAsk? parseExtensionDevLinkAsk(Map<String, dynamic> hello) {
  final tool = hello['tool'];
  final dir = hello['dir'];
  final keys = hello['keys'];
  final server = hello['server'];
  if (tool is! Map || tool['name'] is! String || (tool['name'] as String).isEmpty) return null;
  if (dir is! String || dir.isEmpty) return null;
  if (keys is! List || keys.isEmpty || keys.any((k) => k is! String || k.isEmpty)) return null;
  if (server is! String) return null;
  final uri = Uri.tryParse(server);
  if (uri == null || uri.scheme != 'http' || !_loopbackHosts.contains(uri.host)) return null;
  return ExtensionDevLinkAsk(
    tool: tool['name'] as String,
    toolVersion: tool['version'] is String ? tool['version'] as String : '',
    dir: dir,
    keys: keys.cast<String>(),
    server: uri,
  );
}

/// A tool on this machine serves on this machine: a server anywhere else,
/// named over the loopback link, is something the operator was never shown.
const _loopbackHosts = {'127.0.0.1', '::1', '[::1]', 'localhost'};

/// A question for the operator about one tool. Withdrawn when the tool
/// hangs up before an answer, or the link stops: the tool asks again when
/// it reconnects.
class ExtensionDevLinkRequest {
  final ExtensionDevLinkAsk ask;
  final _answer = Completer<bool>();
  final _withdrawn = Completer<void>();

  ExtensionDevLinkRequest(this.ask);

  /// Completes when nobody is waiting on the answer any more: a dialog
  /// still asking closes.
  Future<void> get withdrawn => _withdrawn.future;

  void _withdraw() {
    if (!_withdrawn.isCompleted) _withdrawn.complete();
    if (!_answer.isCompleted) _answer.complete(false);
  }
}

/// One tool the operator allowed, connected.
class ExtensionDevLinkConnection {
  final ExtensionDevLinkAsk ask;
  final ExtensionDevClient client;
  final AgentLinkPeer _peer;

  ExtensionDevLinkConnection._(this.ask, this.client, this._peer);
}

class ExtensionDevLink extends ChangeNotifier {
  final bool Function() _wanted;
  final Listenable? _changes;
  final List<int> _ports;
  final Map<String, String> _app;
  final ExtensionDevClient Function(String server, Set<String> keys) _newClient;
  final Future<AgentLinkListener> Function({required int port, required void Function(AgentLinkPeer peer) onPeer}) _bind;
  final Duration helloTimeout;

  /// How long a connected tool whose dev client failed waits before its
  /// client tries again.
  final Duration retryDelay;

  /// [app] is what a probe is told about this app: its `name`, `edition`
  /// (`regular`, `next` or `dev`), `label` and `version`. [newClient] makes
  /// the dev client for one allowed tool, taking only [keys] from its
  /// server.
  ExtensionDevLink({
    required this._wanted,
    required this._ports,
    required this._app,
    required this._newClient,
    this._changes,
    Future<AgentLinkListener> Function({required int port, required void Function(AgentLinkPeer peer) onPeer})? bind,
    this.helloTimeout = const Duration(seconds: 10),
    this.retryDelay = const Duration(seconds: 3),
  }) : _bind = bind ?? bindAgentLink {
    _changes?.addListener(_follow);
    _follow();
  }

  AgentLinkListener? _listener;
  bool _binding = false;
  bool _failed = false;
  Timer? _retry;
  bool _disposed = false;
  int _nextServer = 0;

  final _allowed = <String>{};
  final _requests = <ExtensionDevLinkRequest>[];
  final _connections = <ExtensionDevLinkConnection>[];

  /// Every tool that has asked and not yet hung up, waiting on the operator
  /// or connected: what is told when Developer Mode goes off.
  final _asked = <AgentLinkPeer>{};

  /// The port it listens on, null while it is not listening.
  int? get port => _listener?.port;

  /// Whether it wants to listen and none of its ports could be had.
  bool get failed => _failed;

  /// When [failed], what went wrong if it was not just the ports being taken
  /// or reserved; null when it was.
  String? get failure => _failure;
  String? _failure;

  /// The tool the operator is being asked about, first come first asked.
  ExtensionDevLinkRequest? get pendingRequest => _requests.firstOrNull;

  /// The tools connected, oldest first.
  List<ExtensionDevLinkConnection> get connections => List.unmodifiable(_connections);

  /// The operator's answer to [request]. An allow lasts until the app quits,
  /// or until the operator disconnects the tool.
  void answer(ExtensionDevLinkRequest request, {required bool allow}) {
    if (!_requests.remove(request)) return;
    if (allow) _allowed.add(request.ask.allowId);
    if (!request._answer.isCompleted) request._answer.complete(allow);
    if (!_disposed) notifyListeners();
  }

  /// The operator ends [connection]: its extensions go, the tool is told to
  /// stop asking, and its next ask, from a restart, asks the operator again.
  Future<void> disconnect(ExtensionDevLinkConnection connection) async {
    _allowed.remove(connection.ask.allowId);
    _send(connection._peer, {'closed': 'disconnected'});
    await connection._peer.close();
  }

  /// The app is quitting: hangs up without rebooting the extension runtime
  /// onto the shipped bundles ([ExtensionDevClient.closeForExit]).
  Future<void> closeForExit() async {
    _disposed = true;
    _retry?.cancel();
    _changes?.removeListener(_follow);
    for (final request in [..._requests]) {
      request._withdraw();
    }
    _requests.clear();
    for (final connection in [..._connections]) {
      await connection.client.closeForExit();
    }
    await _listener?.close();
    _listener = null;
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
      Object? lastError;
      (Object, StackTrace)? reportable;
      for (final port in _ports) {
        try {
          final listener = await _bind(port: port, onPeer: (peer) => unawaited(_serve(peer)));
          if (_disposed || !_wanted()) {
            await listener.close();
            return;
          }
          _listener = listener;
          _failed = false;
          _failure = null;
          ErrorReportingService.recordSuccess(_bindReportKey);
          debugPrint('[ext-dev-link] listening on 127.0.0.1:${listener.port}');
          return;
        } catch (e, st) {
          lastError = e;
          if (!agentLinkPortUnavailable(e)) reportable ??= (e, st);
        }
      }
      _failed = true;
      _failure = reportable == null ? null : '${reportable.$1}';
      // Once per streak: the retry below would otherwise upload the same
      // failure every ten seconds for the rest of the session.
      if (reportable case (final e, final st)) {
        ErrorReportingService.reportIfRepeated(_bindReportKey, e, st, context: 'ExtensionDevLink:bind');
      }
      debugPrint('[ext-dev-link] could not listen on any of $_ports: $lastError');
      // Whatever holds the ports may let go — another Dev build quitting —
      // and the link comes up then without the operator doing anything.
      _retry = Timer(const Duration(seconds: 10), _follow);
    } finally {
      _binding = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _stop() async {
    _retry?.cancel();
    final listener = _listener;
    if (listener == null && !_failed && _requests.isEmpty && _connections.isEmpty) return;
    _listener = null;
    _failed = false;
    _failure = null;
    for (final request in [..._requests]) {
      request._withdraw();
    }
    _requests.clear();
    // Said before the listener hangs up on them, or a tool takes the closed
    // connection for the app quitting.
    for (final peer in [..._asked]) {
      _send(peer, {'ok': false, 'reason': 'unavailable', 'message': 'Developer Mode is off'});
    }
    // Developer Mode off takes the tools' extensions with it, and their
    // allows: turning it back on is a new decision.
    _allowed.clear();
    if (listener != null) await listener.close();
    if (!_disposed) notifyListeners();
  }

  static const _bindReportKey = 'extensionDevLink:bind';

  void _send(AgentLinkPeer peer, Map<String, Object?> message) => peer.send(jsonEncode({'extDevLink': kExtensionDevLinkVersion, ...message}));

  Future<void> _serve(AgentLinkPeer peer) async {
    final lines = StreamIterator(peer.lines);
    try {
      final Map<String, dynamic> hello;
      try {
        if (!await lines.moveNext().timeout(helloTimeout)) return;
        final decoded = jsonDecode(lines.current);
        // Anything else is not a dev tool — a web page's HTTP request, most
        // likely — and nothing is answered: a reply would be something for
        // that page to read.
        if (decoded is! Map<String, dynamic> || !decoded.containsKey('extDevLink')) return;
        hello = decoded;
      } on TimeoutException {
        return;
      } on FormatException {
        return;
      }
      // The app quitting while the first line was on its way.
      if (_disposed) return;
      if (hello['extDevLink'] != kExtensionDevLinkVersion) {
        _send(peer, {'ok': false, 'reason': 'protocol', 'message': 'this app speaks dev link $kExtensionDevLinkVersion'});
        return;
      }
      if (hello['probe'] == true) {
        _send(peer, {'app': _app});
        return;
      }
      final ask = parseExtensionDevLinkAsk(hello);
      if (ask == null) {
        _send(peer, {'ok': false, 'reason': 'protocol', 'message': 'needs tool, dir, keys and a server on this machine'});
        return;
      }
      _asked.add(peer);
      if (!_allowed.contains(ask.allowId)) {
        final request = ExtensionDevLinkRequest(ask);
        _requests.add(request);
        notifyListeners();
        _send(peer, {'asking': true});
        unawaited(
          peer.done.then((_) {
            if (_requests.remove(request)) {
              request._withdraw();
              if (!_disposed) notifyListeners();
            }
          }),
        );
        final allowed = await request._answer.future;
        if (request._withdrawn.isCompleted) return;
        if (!allowed) {
          _send(peer, {'ok': false, 'reason': 'denied'});
          return;
        }
      }
      _send(peer, {'ok': true});
      await _run(ask, peer, lines);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'ExtensionDevLink:serve');
    } finally {
      _asked.remove(peer);
      await lines.cancel();
      await peer.close();
    }
  }

  /// Runs [ask]'s dev client until the tool hangs up, telling the tool how
  /// it is doing, and trying again while it fails: the tool does not ask
  /// again while it is connected, so a connect that failed (a build broken
  /// when the tool started, a key the tool's previous run is still letting
  /// go of) would otherwise stay failed until the author restarts it.
  Future<void> _run(ExtensionDevLinkAsk ask, AgentLinkPeer peer, StreamIterator<String> lines) async {
    final client = _newClient('link:${_nextServer++}', ask.keys.toSet());
    final connection = ExtensionDevLinkConnection._(ask, client, peer);
    Timer? retry;
    void retryWhileFailed() {
      if (client.state != DevServerState.failed) {
        retry?.cancel();
        retry = null;
        return;
      }
      retry ??= Timer(retryDelay, () {
        retry = null;
        if (_connections.contains(connection)) unawaited(client.connect(ask.server.toString()));
      });
    }

    String? lastSent;
    void report() {
      final state = switch (client.state) {
        DevServerState.connected => {'state': 'connected', 'keys': client.servedKeys, 'refused': client.refused, 'notLoaded': client.loadErrors},
        DevServerState.failed => {'state': 'failed', 'message': client.lastError ?? ''},
        _ => null,
      };
      if (state == null) return;
      final line = jsonEncode(state);
      if (line == lastSent) return;
      lastSent = line;
      _send(peer, state);
    }

    client
      ..addListener(report)
      ..addListener(retryWhileFailed);
    _connections.add(connection);
    notifyListeners();
    try {
      await client.connect(ask.server.toString());
      // Nothing the tool sends after the ask means anything; reading on is
      // how the hang-up is noticed.
      while (await lines.moveNext()) {}
    } finally {
      retry?.cancel();
      client
        ..removeListener(report)
        ..removeListener(retryWhileFailed);
      _connections.remove(connection);
      if (!_disposed) {
        await client.disconnect();
        if (!_disposed) notifyListeners();
      }
      client.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(closeForExit());
    super.dispose();
  }
}
