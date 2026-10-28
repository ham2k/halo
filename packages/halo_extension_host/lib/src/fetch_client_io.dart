// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The guarded `host.fetch` transport where the platform lets the host own the
// socket: the name is resolved here, every answer is judged, and the
// connection goes to an address that was judged.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'local_network.dart';

/// Resolves a name to the addresses it may be connected to.
typedef AddressLookup = Future<List<InternetAddress>> Function(String host);

/// Opens one connection to a judged address, secured for https.
typedef AddressConnect = Future<Socket> Function(InternetAddress address, int port, {required bool secure});

/// How long a connect attempt has the field to itself before the next judged
/// address is tried beside it — the stagger `Socket.connect` races a name's
/// addresses with, so an address that is advertised but dead (IPv6 on a
/// router that has none) costs a quarter second rather than the header
/// budget. A refusal frees the field at once.
const kConnectStagger = Duration(milliseconds: 250);

/// The client for a hop that may not reach the local network: an `HttpClient`
/// whose sockets come from [guardedConnection]. Its proxy rules are the
/// default client's — the environment's `https_proxy` and `no_proxy` — so a
/// build behind a proxy fetches through it on both transports.
http.Client guardedFetchClient() => IOClient(HttpClient()..connectionFactory = guardedConnection);

/// `HttpClient.connectionFactory` for [guardedFetchClient]: resolve, judge,
/// connect to what was judged. Judging the spelling alone (fetch_policy.dart)
/// leaves two ways in — a name that resolves to a local address, by a DNS
/// answer that changes between the check and the connect, and a literal in a
/// form the spelling check does not read (`2130706433`) — and both end here,
/// because the socket goes to an address this function looked at.
///
/// Returns a SECURE socket for https: a client given a connection factory
/// uses the socket it gets as it is, and does not add TLS over it.
///
/// Through a proxy the connection goes to the PROXY, plain, for the client
/// to tunnel and secure through. The proxy is the operator's own
/// configuration, not the extension's, and it resolves the target itself, so
/// a name reaching it was judged by its spelling alone.
Future<ConnectionTask<Socket>> guardedConnection(Uri url, String? proxyHost, int? proxyPort) =>
    guardedConnectionWith(url, proxyHost: proxyHost, proxyPort: proxyPort, lookup: InternetAddress.lookup, connect: _connect);

Future<Socket> _connect(InternetAddress address, int port, {required bool secure}) =>
    // A looked-up address carries the name it was looked up by, which is what
    // the certificate is checked against; a literal is checked as a literal.
    secure ? SecureSocket.connect(address, port) : Socket.connect(address, port);

/// [guardedConnection] with its resolver, its socket opener and its stagger
/// injectable, so a test can hand it answers and see what it connects to.
///
/// Every answer must pass, not just the one connected to: a resolver that
/// pairs a public address with a private one is offering the private one to
/// whichever attempt the first refuses. The task exists before the lookup
/// runs, so a client closing while the resolver hangs cancels this too.
Future<ConnectionTask<Socket>> guardedConnectionWith(
  Uri url, {
  String? proxyHost,
  int? proxyPort,
  required AddressLookup lookup,
  required AddressConnect connect,
  Duration stagger = kConnectStagger,
}) async {
  var cancelled = false;
  Future<Socket> open() async {
    final host = proxyHost ?? url.host;
    final literal = InternetAddress.tryParse(host);
    final addresses = literal != null ? [literal] : await lookup(host);
    if (addresses.isEmpty) throw SocketException("Failed host lookup: '$host'");
    if (proxyHost == null) {
      for (final address in addresses) {
        // The platform's own reading of the address first, then the host's:
        // an answer the spelling rule has no range for must still not get
        // through.
        if (address.isLoopback || address.isLinkLocal || address.isMulticast || isLocalNetworkHost(address.address)) {
          throw SocketException("fetch refused: '${url.host}' resolves to the local network (${address.address})");
        }
      }
    }
    if (cancelled) throw const SocketException('connection cancelled');
    final port = proxyHost == null ? url.port : proxyPort!;
    final secure = proxyHost == null && url.scheme == 'https';
    return _race(
      addresses,
      (address) => connect(address, port, secure: secure),
      stagger: stagger,
      isCancelled: () => cancelled,
    );
  }

  // Handed over through a completer, not as `open()`'s own future: a refusal
  // on a literal is decided before the caller holds the task, and a future
  // that fails with nobody listening yet is reported as uncaught.
  final done = Completer<Socket>();
  unawaited(open().then(done.complete, onError: done.completeError));
  return ConnectionTask.fromSocket(done.future, () => cancelled = true);
}

/// Opens [addresses] in order, each [stagger] after the last unless that one
/// has already failed, and keeps the first socket to connect; the rest are
/// closed as they arrive. Every attempt failing fails with the last failure.
/// A cancel closes whatever arrives after it.
Future<Socket> _race(
  List<InternetAddress> addresses,
  Future<Socket> Function(InternetAddress address) open, {
  required Duration stagger,
  required bool Function() isCancelled,
}) {
  final done = Completer<Socket>();
  var next = 0;
  var failed = 0;
  Timer? ticker;
  void attempt() {
    if (done.isCompleted || next >= addresses.length) return;
    Future.sync(() => open(addresses[next++])).then(
      (socket) {
        if (done.isCompleted) {
          socket.destroy();
          return;
        }
        ticker?.cancel();
        if (isCancelled()) {
          socket.destroy();
          done.completeError(const SocketException('connection cancelled'));
          return;
        }
        done.complete(socket);
      },
      onError: (Object e, StackTrace st) {
        failed++;
        if (done.isCompleted) return;
        if (failed == addresses.length) {
          ticker?.cancel();
          done.completeError(e, st);
          return;
        }
        attempt();
      },
    );
  }

  attempt();
  if (addresses.length > 1) ticker = Timer.periodic(stagger, (_) => attempt());
  return done.future;
}
