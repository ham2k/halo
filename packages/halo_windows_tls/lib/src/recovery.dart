// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The io half of halo_windows_tls.dart's conditional export.
//
// On Windows, an HTTPS connection can be refused because the machine has
// never downloaded the server's root (native.dart says why). Every
// HttpClient an isolate creates with the default context is wrapped so that
// such a refusal gets a recovery for its host and port: Windows is asked to
// verify the server, which downloads the root; the chain Windows verified is
// added to SecurityContext.defaultContext; and the connection is opened once
// more. A host whose recovery failed is tried again after a minute.
//
// The chain goes into the shared default context rather than a new one
// because long-lived clients hold one HttpClient for the whole session, and
// a new context would never reach them. HttpOverrides.global and the default
// context both belong to one isolate, so each isolate that opens
// connections installs this for itself.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'native.dart';

export 'native.dart' show WindowsRequestFailed;

/// Wraps every HttpClient this isolate creates from here on, on Windows
/// only. Called before anything in the isolate opens a connection: a client
/// created before this runs is not wrapped. A second call in the same
/// isolate does nothing.
///
/// [userAgent] is what Windows' own request to the server sends.
/// [onRecovered] hears what each recovery found, for a breadcrumb or a log
/// line. [onFailure] hears a recovery that broke — a missing DLL, Windows'
/// own request failing; the refused connection's own error still reaches
/// its caller.
void installWindowsTlsRootRecovery({
  String userAgent = 'Ham2K Logger',
  void Function(String message)? onRecovered,
  void Function(Object error, StackTrace stackTrace)? onFailure,
}) {
  if (!Platform.isWindows || HttpOverrides.current is TlsRootRecoveryOverrides) return;
  HttpOverrides.global = TlsRootRecoveryOverrides(WindowsTlsRootRecovery(userAgent: userAgent, onRecovered: onRecovered, onFailure: onFailure));
}

/// Whether [error] is a refusal a missing root produces. BoringSSL words it
/// one of two ways: "unable to get local issuer certificate" when the server
/// sends a chain that stops short of the root, "self signed certificate in
/// certificate chain" when it sends the untrusted root along. Other
/// certificate failures — an expired certificate, a name that does not
/// match — are not helped by a root and are left alone.
bool isMissingRootFailure(Object error) {
  if (error is! HandshakeException) return false;
  final text = error.toString();
  return text.contains('unable to get local issuer certificate') || text.contains('self signed certificate in certificate chain');
}

/// The certificates Windows verified [host]:[port] with, the server's own
/// left out. Throws [WindowsRequestFailed] when Windows' request failed.
typedef TlsChainLookup = Future<List<Uint8List>> Function(String host, int port);

/// Adds one PEM-encoded certificate to the trust store connections verify
/// against.
typedef TlsRootTrust = void Function(List<int> pem);

/// The recoveries of every wrapped client in the isolate, at most one per
/// host and port a [memory].
class WindowsTlsRootRecovery {
  WindowsTlsRootRecovery({
    TlsChainLookup? lookup,
    TlsRootTrust? trust,
    String userAgent = 'Ham2K Logger',
    this.onRecovered,
    this.onFailure,
    this.timeout = const Duration(seconds: 10),
    this.memory = const Duration(minutes: 1),
    Duration Function()? elapsed,
  }) : _lookup = lookup ?? ((host, port) => Isolate.run(() => chainWindowsVerifies(host, port, userAgent))),
       _trust = trust ?? ((pem) => SecurityContext.defaultContext.setTrustedCertificatesBytes(pem)),
       _elapsed = elapsed ?? _stopwatch();

  final TlsChainLookup _lookup;
  final TlsRootTrust _trust;
  final Duration Function() _elapsed;
  final void Function(String message)? onRecovered;
  final void Function(Object error, StackTrace stackTrace)? onFailure;

  /// How long a refused connection waits for its recovery. A caller's own
  /// connection timeout does not reach WinHTTP, so this bounds the wait. A
  /// lookup that outlasts it still has its chain trusted when it arrives.
  final Duration timeout;

  /// How long a finished recovery stands for its host and port. Within it, a
  /// refusal the recovery did not cure fails at once rather than asking
  /// Windows again; after it, a refusal starts a new recovery, so a failure
  /// that passes — a network still settling after the PC wakes — does not
  /// leave the host refused for the rest of the session.
  final Duration memory;

  final Map<String, Future<bool>> _pending = {};
  final Map<String, ({bool ok, int generation, Duration at})> _finished = {};
  int _generation = 0;

  /// Ticks each time a recovery trusts a chain, whether or not the store
  /// already held it. A connection notes it before opening, so a refusal can
  /// tell whether it was refused by a trust store that may have changed since.
  int get generation => _generation;

  /// Whether a connection to [host]:[port], opened when [generation] read
  /// [openedAt] and then refused for a missing root, should be opened again.
  ///
  /// The first refusal starts the recovery, and any that arrive while it
  /// runs join it, since several requests to one host usually fail
  /// together. A connection opened before the host's chain was trusted is
  /// opened again: the store that refused it has since been fixed. One opened
  /// after was refused by the fixed store, and trying again would double
  /// every request to a host the recovery cannot help.
  Future<bool> shouldRetry(String host, int port, int openedAt) {
    final key = '$host:$port';
    final pending = _pending[key];
    if (pending != null) return pending;
    final finished = _finished[key];
    if (finished != null) {
      if (finished.ok && openedAt < finished.generation) return Future.value(true);
      if (_elapsed() - finished.at < memory) return Future.value(false);
    }
    return _pending[key] = _settle(key, host, port);
  }

  /// Never throws: a callback that does — a crash reporter failing early in
  /// boot — goes to the zone, and the refused connection keeps its own
  /// error. Without the finally, such a throw would leave the recovery
  /// pending for good, and every later refusal to the host would join it.
  Future<bool> _settle(String key, String host, int port) async {
    var ok = false;
    try {
      ok = await _recover(key, host, port);
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    } finally {
      unawaited(_pending.remove(key));
      _finish(key, ok);
    }
    return ok;
  }

  void _finish(String key, bool ok) => _finished[key] = (ok: ok, generation: ok ? ++_generation : _generation, at: _elapsed());

  Future<bool> _recover(String key, String host, int port) async {
    final lookup = _lookup(host, port);
    try {
      return _trustChain(host, port, await lookup.timeout(timeout));
    } on TimeoutException {
      // Windows is often still downloading the root, so running long is not
      // a failure. What it finds is trusted when it arrives, and the host
      // counts as recovered from then on; only the connections waiting now
      // give up.
      onRecovered?.call('$host:$port: still waiting on Windows; its chain is trusted when it arrives');
      unawaited(() async {
        try {
          if (_trustChain(host, port, await lookup)) _finish(key, true);
        } catch (error, stackTrace) {
          onFailure?.call(error, stackTrace);
        }
      }());
      return false;
    } catch (error, stackTrace) {
      onFailure?.call(error, stackTrace);
      return false;
    }
  }

  /// Adding a certificate the store already holds does nothing, so hosts
  /// that share a chain need no bookkeeping here.
  bool _trustChain(String host, int port, List<Uint8List> chain) {
    for (final der in chain) {
      _trust(ascii.encode(pemOf(der)));
    }
    onRecovered?.call('$host:$port: trusting the ${chain.length} certificates Windows verified it with');
    return chain.isNotEmpty;
  }
}

Duration Function() _stopwatch() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

/// [der] as a PEM block, the form SecurityContext reads.
String pemOf(Uint8List der) {
  final body = base64.encode(der);
  final lines = [for (var i = 0; i < body.length; i += 64) body.substring(i, i + 64 < body.length ? i + 64 : body.length)];
  return '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n-----END CERTIFICATE-----\n';
}

/// Wraps each HttpClient created on the default context in a
/// [TlsRootRecoveringHttpClient].
class TlsRootRecoveryOverrides extends HttpOverrides {
  TlsRootRecoveryOverrides(this._recovery);

  final WindowsTlsRootRecovery _recovery;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Recovery adds roots to the default context only, so a client with its
    // own context would be refused the same way on the retry.
    final usesDefault = context == null || identical(context, SecurityContext.defaultContext);
    return usesDefault ? TlsRootRecoveringHttpClient(client, _recovery) : client;
  }
}

/// An HttpClient that recovers a connection a missing Windows root refused.
///
/// Only the `…Url` methods are guarded: the host-and-port ones always speak
/// plain http, so there is no handshake to refuse. A redirect to https is
/// followed inside the request after it was opened, so its refusal is not
/// seen here.
///
/// A client given its own [connectionFactory] gets no recovery: it decides
/// where its sockets go — the extension host's guarded fetch connects only
/// to an address it has judged — and WinHTTP would resolve the name again
/// on its own, reaching an address nobody judged.
class TlsRootRecoveringHttpClient implements HttpClient {
  TlsRootRecoveringHttpClient(this._inner, this._recovery);

  final HttpClient _inner;
  final WindowsTlsRootRecovery _recovery;
  bool _ownsConnections = false;

  Future<HttpClientRequest> _guarded(Uri url, Future<HttpClientRequest> Function() open) async {
    if (_ownsConnections) return open();
    final openedAt = _recovery.generation;
    try {
      return await open();
    } on HandshakeException catch (error) {
      if (!isMissingRootFailure(error)) rethrow;
      // A wss:// URL reaches here as https with port 0.
      final port = url.port == 0 ? HttpClient.defaultHttpsPort : url.port;
      if (!await _recovery.shouldRetry(url.host, port, openedAt)) rethrow;
      // Nothing was sent on the refused connection, so opening it again is
      // safe for any method.
      return open();
    }
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _guarded(url, () => _inner.openUrl(method, url));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _guarded(url, () => _inner.getUrl(url));
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _guarded(url, () => _inner.postUrl(url));
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _guarded(url, () => _inner.putUrl(url));
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _guarded(url, () => _inner.deleteUrl(url));
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _guarded(url, () => _inner.patchUrl(url));
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _guarded(url, () => _inner.headUrl(url));

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) => _inner.open(method, host, port, path);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => _inner.get(host, port, path);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => _inner.post(host, port, path);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => _inner.put(host, port, path);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => _inner.delete(host, port, path);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => _inner.patch(host, port, path);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => _inner.head(host, port, path);

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;
  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;
  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) => _inner.authenticate = f;
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) => _inner.authenticateProxy = f;
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {
    _ownsConnections = f != null;
    _inner.connectionFactory = f;
  }

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) => _inner.badCertificateCallback = callback;
  @override
  set keyLog(dynamic Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) => _inner.addCredentials(url, realm, credentials);
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);
  @override
  void close({bool force = false}) => _inner.close(force: force);
}
