// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app end of the extension dev loop (HALO-118, docs/extensions/in-repo.md#the-dev-server):
// connects to the dev server an author is running, takes its extensions over the
// ones baked into the app, and swaps one of them in place on every save.
//
// It is deliberately inert unless someone turns it on and types a URL. Nothing
// discovers a dev server and nothing connects to one on its own — this fetches
// code the app will then execute, so the operator naming the host is the whole
// of the trust story. Build secrets never reach a dev extension regardless
// (ExtensionService resolves those by provenance), so the worst a wrong URL
// costs is a broken extension until it disconnects.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show nowLocal;
import 'package:http/http.dart' as http;

import 'extension_service.dart';

/// The dev-server protocol this client speaks (dev-server.mjs `PROTOCOL`).
const _protocolVersion = 1;

enum DevServerState { disconnected, connecting, connected, failed }

class ExtensionDevClient extends ChangeNotifier {
  ExtensionDevClient({required this.extensions, http.Client? httpClient}) : _http = httpClient ?? http.Client(), _ownsHttpClient = httpClient == null;

  final ExtensionService extensions;
  final http.Client _http;
  final bool _ownsHttpClient;

  DevServerState get state => _state;
  DevServerState _state = DevServerState.disconnected;

  /// Why the last connection attempt failed, for the settings pane to show.
  /// A dev tool that fails silently is worse than no dev tool.
  String? get lastError => _lastError;
  String? _lastError;

  /// Extension keys the server is serving, in the order it listed them.
  List<String> get servedKeys => List.unmodifiable(_servedKeys);
  List<String> _servedKeys = const [];

  /// The most recent reload, for the pane to show that the loop is alive.
  ({String key, DateTime at})? get lastReload => _lastReload;
  ({String key, DateTime at})? _lastReload;

  /// Per-extension build errors the server has reported, cleared when that
  /// extension next builds.
  Map<String, String> get buildErrors => Map.unmodifiable(_buildErrors);
  final Map<String, String> _buildErrors = {};

  Uri? _baseUri;
  StreamSubscription<String>? _events;
  StreamSubscription<String>? _logForwarding;
  Timer? _logFlush;
  final List<String> _pendingLogLines = [];
  bool _disposed = false;

  /// Serializes reconnects: connect/disconnect both reboot the runtime, and
  /// two of those interleaving would race over which extension set wins.
  Future<void>? _inFlight;

  Future<void> connect(String url) => _enqueue(() => _connect(url));

  Future<void> disconnect() => _enqueue(_disconnect);

  /// Runs [operation] after whatever is already queued, never alongside it.
  ///
  /// Two details the obvious version gets wrong. The latch is by IDENTITY:
  /// clearing `_inFlight` unconditionally would let an already-superseded
  /// operation's completion clear a successor that is still running, and the
  /// next caller would then run concurrently with it — the exact race this
  /// exists to prevent. And a failed operation must not poison the queue:
  /// chaining plainly would leave `_inFlight` an error future, and every
  /// connect and disconnect for the rest of the session would propagate that
  /// error without ever running.
  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _inFlight ?? Future<void>.value();
    late final Future<void> mine;
    mine = previous.then((_) => operation(), onError: (_) => operation()).whenComplete(() {
      if (identical(_inFlight, mine)) _inFlight = null;
    });
    return _inFlight = mine;
  }

  Future<void> _connect(String url) async {
    await _teardown();
    _state = DevServerState.connecting;
    _lastError = null;
    _buildErrors.clear();
    notifyListeners();

    try {
      final base = _normalize(url);
      _baseUri = base;

      final ping = await _getJson(base.resolve('ping'));
      if (ping['server'] != 'halo-ext-dev') {
        throw const FormatException('that is not a HaLo extension dev server');
      }
      final protocol = (ping['protocol'] as num?)?.toInt() ?? 0;
      if (protocol != _protocolVersion) {
        // Named in both directions rather than "incompatible": whichever side
        // is older, the person reading this is the one who can update it.
        throw FormatException('dev server speaks protocol $protocol, this app speaks $_protocolVersion');
      }

      final index = await _getJson(base.resolve('index.json'));
      final infos = [
        for (final entry in ((index['extensions'] as List?) ?? const []).cast<Map<String, dynamic>>()) ExtensionInfo.fromJson({...entry, 'source': 'dev'}),
      ];
      if (infos.isEmpty) throw const FormatException('the dev server is serving no extensions');

      final bundles = <String, ({String source, ExtensionInfo info})>{};
      for (final info in infos) {
        bundles[info.key] = (source: await _getText(base.resolve(info.file)), info: info);
      }
      _servedKeys = [for (final info in infos) info.key];

      // One reboot for the whole set: connecting changes WHICH extensions
      // exist, which a per-extension reload cannot express.
      await extensions.setDevBundles(bundles);

      _listenForEvents(base);
      _startLogForwarding();
      // Every runtime restart replaces the host, and with it the log stream
      // just subscribed to. Without re-attaching, the remote console goes
      // quiet after the first restart — and connecting IS a restart, so it
      // would go quiet almost immediately.
      extensions.runtimeGeneration.addListener(_startLogForwarding);
      _state = DevServerState.connected;
      notifyListeners();
    } catch (e) {
      _state = DevServerState.failed;
      _lastError = _describe(e);
      _servedKeys = const [];
      // Whatever a previous connection left loaded is now running with no
      // server behind it, and the pane is about to say "not connected" — so
      // the app must actually not be running it. Reverting to the built-in
      // extensions is what makes the two agree.
      try {
        await extensions.setDevBundles(const {});
      } catch (_) {
        // Already failing; a restart that also fails changes nothing here.
      }
      notifyListeners();
    }
  }

  Future<void> _disconnect() async {
    await _teardown();
    _state = DevServerState.disconnected;
    _lastError = null;
    _servedKeys = const [];
    _buildErrors.clear();
    notifyListeners();
    try {
      // Back to the extensions the app shipped with.
      await extensions.setDevBundles(const {});
    } catch (e) {
      // Reported rather than thrown: this runs on a queue shared with every
      // later connect, and a runtime restart that failed here must not be
      // able to take those down with it.
      _lastError = _describe(e);
      notifyListeners();
    }
  }

  Future<void> _teardown() async {
    extensions.runtimeGeneration.removeListener(_startLogForwarding);
    await _events?.cancel();
    _events = null;
    await _logForwarding?.cancel();
    _logForwarding = null;
    _logFlush?.cancel();
    _logFlush = null;
    _pendingLogLines.clear();
    _baseUri = null;
  }

  /// Subscribes to the server's Server-Sent Events stream. Each `data:` line
  /// is one JSON event; the blank line between events is ignored.
  void _listenForEvents(Uri base) {
    final request = http.Request('GET', base.resolve('events'))..headers['accept'] = 'text/event-stream';
    _events = _http
        .send(request)
        .asStream()
        .asyncExpand((response) => response.stream.transform(utf8.decoder).transform(const LineSplitter()))
        .listen(
          _onEventLine,
          onError: (Object error) {
            // The server went away (stopped, or the laptop slept). Say so and
            // stay put: the extensions already loaded keep working, and the
            // operator can reconnect when it's back.
            _state = DevServerState.failed;
            _lastError = 'lost the dev server: ${_describe(error)}';
            notifyListeners();
          },
          onDone: () {
            if (_disposed || _state != DevServerState.connected) return;
            _state = DevServerState.failed;
            _lastError = 'the dev server closed the connection';
            notifyListeners();
          },
        );
  }

  /// Feeds one raw SSE line in, as the server's stream would. The stream
  /// itself is an HTTP connection, so a test that wants to assert what an
  /// event DOES has no other way in.
  @visibleForTesting
  void debugHandleEventLine(String line) => _onEventLine(line);

  void _onEventLine(String line) {
    if (!line.startsWith('data: ')) return;
    final Map<String, dynamic> event;
    try {
      event = jsonDecode(line.substring(6)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (event['type']) {
      case 'hello':
        // The server's backlog of extensions that are failing to build. They
        // are absent from its index, so the app is running the versions it
        // shipped with — which must be visible, not inferred from an
        // extension mysteriously not changing when saved.
        final errors = (event['buildErrors'] as Map?)?.cast<String, dynamic>() ?? const {};
        for (final entry in errors.entries) {
          _buildErrors[entry.key] = '${entry.value}';
        }
        if (errors.isNotEmpty) notifyListeners();
      case 'reload':
        unawaited(_applyReload(event));
      case 'buildError':
        final key = event['key'] as String?;
        if (key == null) return;
        _buildErrors[key] = event['message'] as String? ?? 'build failed';
        notifyListeners();
    }
  }

  Future<void> _applyReload(Map<String, dynamic> event) async {
    final key = event['key'] as String?;
    final base = _baseUri;
    if (key == null || base == null) return;
    try {
      // The event carries the extension's whole manifest entry, so a `domains`
      // edited between two saves applies with the code that expects it.
      final info = ExtensionInfo.fromJson({...event, 'source': 'dev'});
      final source = await _getText(base.resolve(info.file));
      await extensions.applyDevBundle(key, source: source, info: info);
      _buildErrors.remove(key);
      _lastReload = (key: key, at: nowLocal());
    } catch (e) {
      _buildErrors[key] = 'could not load: ${_describe(e)}';
    }
    notifyListeners();
  }

  /// Forwards what the runtime logs back to the dev server's terminal — the
  /// remote console. Batched on a short timer because an extension logging in
  /// a loop should not become one HTTP request per line.
  void _startLogForwarding() {
    _logForwarding?.cancel();
    _logForwarding = extensions.host?.logs.listen((line) {
      _pendingLogLines.add(line);
      _logFlush ??= Timer(const Duration(milliseconds: 250), _flushLogs);
    });
  }

  void _flushLogs() {
    _logFlush = null;
    final base = _baseUri;
    if (base == null || _pendingLogLines.isEmpty) return;
    final lines = [..._pendingLogLines];
    _pendingLogLines.clear();
    // Fire and forget: a dev console that cannot be reached is not worth
    // failing anything over, and the lines are in the app's own log anyway.
    unawaited(
      _http
          .post(base.resolve('logs'), headers: {'content-type': 'application/json'}, body: jsonEncode({'lines': lines}))
          .catchError((Object _) => http.Response('', 599)),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final body = await _getText(url);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<String> _getText(Uri url) async {
    final response = await _http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode} from $url', url);
    }
    return response.body;
  }

  /// Accepts what someone actually types: a bare host, a host:port, with or
  /// without a scheme, with or without a trailing slash. The trailing slash
  /// matters — `Uri.resolve` against a path-less base would otherwise drop the
  /// last segment.
  static Uri _normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) throw const FormatException('enter the dev server address');
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.parse(text);
    if (uri.host.isEmpty) throw FormatException('could not read a host from "$input"');
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }

  static String _describe(Object error) {
    if (error is FormatException) return error.message;
    if (error is http.ClientException) return error.message;
    if (error is TimeoutException) return 'timed out';
    return error.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    if (_ownsHttpClient) _http.close();
    super.dispose();
  }
}
