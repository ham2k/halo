// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Windows missing-root recovery, minus the WinHTTP call (which only a
// Windows machine can run). The refusal it recovers from is a Windows one:
// macOS verifies through Apple's Security framework and words the same
// refusal differently, so these tests drive the wrapper with the exact
// messages BoringSSL produces, and check the PEM it builds against the real
// SecurityContext.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_windows_tls/src/recovery.dart';
import 'package:test/test.dart';

HandshakeException _refusal(String reason) => HandshakeException(
  'Handshake error in client',
  OSError('CERTIFICATE_VERIFY_FAILED: $reason(../../../flutter/third_party/boringssl/src/ssl/handshake.cc:298)'),
);

/// Word for word what Windows builds report.
final _missingRoot = _refusal('unable to get local issuer certificate');
final _rootSentUntrusted = _refusal('self signed certificate in certificate chain');
final _expired = _refusal('certificate has expired');

const _testRootPem = '''
-----BEGIN CERTIFICATE-----
MIIBmTCCAT+gAwIBAgIUO6Qv4uWiTBBxr0ie6KsMA6z0yOgwCgYIKoZIzj0EAwIw
GTEXMBUGA1UEAwwOSGFMbyBUZXN0IFJvb3QwIBcNMjYxMTE1MDAxNDM4WhgPMjEy
NjEwMjIwMDE0MzhaMBkxFzAVBgNVBAMMDkhhTG8gVGVzdCBSb290MFkwEwYHKoZI
zj0CAQYIKoZIzj0DAQcDQgAEdogQZB/F+dnEQDrc8OsEHXiFqUS+8uLD3HsDvxBz
hVJRaPmE7Fu+lR4SdIhGXBK195/0buiZSAiCBCTEtIf2qqNjMGEwHQYDVR0OBBYE
FLpyuwePVXMgkcTmqG1tp4OVbWqIMB8GA1UdIwQYMBaAFLpyuwePVXMgkcTmqG1t
p4OVbWqIMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49
BAMCA0gAMEUCIQCPq3oeXOJmzdKO04Pnsv9ynKA5R4oT94We/R3kZi52/gIgWzk6
zxO+JTdOjKC8/yc6XO8NbT6L2NwJOmnjfWTjB4w=
-----END CERTIFICATE-----
''';

Uint8List _testRootDer() {
  final body = _testRootPem.split('\n').where((line) => line.isNotEmpty && !line.startsWith('-----')).join();
  return base64.decode(body);
}

final _stash = Uri.parse('https://stash.ham2k.net/data/file.json');
final _lofi = Uri.parse('https://lofi.ham2k.net/v1/sync');

class _FakeRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers each openUrl with the next queued outcome: a request, an error to
/// throw, or a future that settles to either.
class _FakeClient implements HttpClient {
  _FakeClient(this.outcomes);

  final List<Object> outcomes;
  final opened = <Uri>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    opened.add(url);
    var outcome = outcomes.removeAt(0);
    if (outcome is Future<Object>) outcome = await outcome;
    if (outcome is HttpClientRequest) return outcome;
    throw outcome;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Lookups {
  final calls = <(String, int)>[];
  List<Uint8List> chain = [
    Uint8List.fromList([1, 2, 3]),
  ];

  /// Thrown by the next lookups instead of answering, while set.
  Object? failure;
  Completer<void>? gate;

  Future<List<Uint8List>> call(String host, int port) async {
    calls.add((host, port));
    await gate?.future;
    if (failure case final failure?) throw failure;
    return chain;
  }
}

/// A clock the test moves by hand.
class _Clock {
  var now = Duration.zero;
  Duration call() => now;
}

void main() {
  test('a missing root is recovered and the connection opened again, without the caller seeing the refusal', () async {
    final request = _FakeRequest();
    final inner = _FakeClient([_missingRoot, request]);
    final lookups = _Lookups();
    final trusted = <String>[];
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (pem) => trusted.add(ascii.decode(pem))));

    expect(await client.getUrl(_stash), same(request));
    expect(lookups.calls, [('stash.ham2k.net', 443)]);
    expect(trusted, [pemOf(lookups.chain.single)], reason: 'what Windows verified must reach the trust store before the retry');
    expect(inner.opened, [_stash, _stash]);
  });

  test('a server that sends its untrusted root along is recovered the same way', () async {
    final inner = _FakeClient([_rootSentUntrusted, _FakeRequest()]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    await client.openUrl('GET', _stash);
    expect(inner.opened, hasLength(2));
  });

  test('other certificate failures are not recovered: a root cannot fix an expired certificate', () async {
    final inner = _FakeClient([_expired]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_expired)));
    expect(lookups.calls, isEmpty);
    expect(inner.opened, hasLength(1));
  });

  test('within a minute of its recovery, a host it did not help is not retried, so every request is not doubled', () async {
    final inner = _FakeClient([_missingRoot, _FakeRequest(), _missingRoot, _missingRoot, _FakeRequest()]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}, elapsed: _Clock().call));

    await client.openUrl('GET', _stash);
    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(inner.opened, hasLength(3), reason: 'opened after the recovery, so refused by the fixed store: no retry');
    expect(lookups.calls, hasLength(1));

    await client.openUrl('GET', _lofi);
    expect(lookups.calls, [('stash.ham2k.net', 443), ('lofi.ham2k.net', 443)], reason: 'another host still gets its own');
  });

  test('a recovery that failed is tried again after a minute, so a passing failure does not last the session', () async {
    final inner = _FakeClient([_missingRoot, _missingRoot, _missingRoot, _FakeRequest()]);
    final lookups = _Lookups()..failure = WindowsRequestFailed('WinHttpSendRequest', 12007);
    final clock = _Clock();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}, onFailure: (_, _) {}, elapsed: clock.call));

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    clock.now = const Duration(seconds: 59);
    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(lookups.calls, hasLength(1), reason: 'within the minute, Windows is not asked again');

    lookups.failure = null;
    clock.now = const Duration(seconds: 61);
    await client.openUrl('GET', _stash);
    expect(lookups.calls, hasLength(2));
    expect(inner.opened, hasLength(4), reason: 'the second recovery worked, so the connection is opened again');
  });

  test('another port of the same host is recovered on its own', () async {
    final inner = _FakeClient([_missingRoot, _FakeRequest(), _missingRoot, _FakeRequest()]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    await client.openUrl('GET', _stash);
    await client.openUrl('GET', Uri.parse('https://stash.ham2k.net:8443/x'));
    expect(lookups.calls, [('stash.ham2k.net', 443), ('stash.ham2k.net', 8443)]);
  });

  test('requests that fail together share one recovery, and each is opened again', () async {
    final first = _FakeRequest();
    final second = _FakeRequest();
    final inner = _FakeClient([_missingRoot, _missingRoot, first, second]);
    final lookups = _Lookups()..gate = Completer<void>();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    final a = client.openUrl('GET', _stash);
    final b = client.openUrl('GET', _stash);
    await pumpEventQueue();
    lookups.gate!.complete();

    expect(await Future.wait([a, b]), unorderedEquals([first, second]));
    expect(lookups.calls, hasLength(1));
  });

  test('a connection opened before the recovery finished but refused after it is still opened again', () async {
    final lateRefusal = Completer<Object>();
    final retried = _FakeRequest();
    final inner = _FakeClient([_missingRoot, lateRefusal.future, _FakeRequest(), retried]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    final first = client.openUrl('GET', _stash);
    final late = client.openUrl('GET', _stash);
    await first;
    lateRefusal.complete(_missingRoot);

    expect(await late, same(retried), reason: 'it was refused by the store the recovery has since fixed');
    expect(lookups.calls, hasLength(1));
  });

  test("when Windows' own request fails, the connection keeps its own error and the failure is reported with Windows' error", () async {
    final inner = _FakeClient([_missingRoot]);
    final refused = WindowsRequestFailed('WinHttpSendRequest', 12175);
    final lookups = _Lookups()..failure = refused;
    final failures = <Object>[];
    final client = TlsRootRecoveringHttpClient(
      inner,
      WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}, onFailure: (error, _) => failures.add(error)),
    );

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(inner.opened, hasLength(1), reason: 'nothing was trusted, so opening again would only be refused again');
    expect(failures, [refused], reason: 'whether a failure is worth uploading is ErrorPolicy\'s call, not this package\'s');
  });

  test('a recovery that breaks leaves the caller its connection error, and is reported on its own', () async {
    final inner = _FakeClient([_missingRoot]);
    final broken = StateError('winhttp.dll missing');
    final failures = <Object>[];
    final client = TlsRootRecoveringHttpClient(
      inner,
      WindowsTlsRootRecovery(lookup: (_, _) async => throw broken, trust: (_) {}, onFailure: (error, _) => failures.add(error)),
    );

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(failures, [broken]);
  });

  test('a recovery that runs long gives up waiting without reporting a failure, since Windows is usually still downloading', () async {
    final inner = _FakeClient([_missingRoot]);
    final lookups = _Lookups()..gate = Completer<void>();
    final failures = <Object>[];
    final client = TlsRootRecoveringHttpClient(
      inner,
      WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}, onFailure: (error, _) => failures.add(error), timeout: const Duration(milliseconds: 50)),
    );

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(failures, isEmpty);

    final offline = WindowsRequestFailed('WinHttpSendRequest', 12007);
    lookups.failure = offline;
    lookups.gate!.complete();
    await pumpEventQueue();
    expect(failures, [offline], reason: 'a late lookup that fails is the one failure to report');
  });

  test('a callback that throws goes to the zone, and does not leave the host stuck on a recovery that never ends', () async {
    final inner = _FakeClient([_missingRoot, _missingRoot]);
    final broken = StateError('reporter not ready');
    final uncaught = <Object>[];
    final lookups = _Lookups()..failure = WindowsRequestFailed('WinHttpSendRequest', 12007);
    final clock = _Clock();
    final client = TlsRootRecoveringHttpClient(
      inner,
      WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}, onFailure: (_, _) => throw broken, elapsed: clock.call),
    );

    await runZonedGuarded(() async {
      await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
      clock.now = const Duration(minutes: 2);
      await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    }, (error, _) => uncaught.add(error));
    expect(uncaught, [broken, broken]);
    expect(lookups.calls, hasLength(2), reason: 'the second refusal starts its own recovery rather than joining a dead one');
  });

  test('a lookup that outlasts the time limit still has its chain trusted when it arrives, and counts as a recovery', () async {
    final lateRefusal = Completer<Object>();
    final retried = _FakeRequest();
    final inner = _FakeClient([_missingRoot, lateRefusal.future, retried]);
    final lookups = _Lookups()..gate = Completer<void>();
    final trusted = <List<int>>[];
    final client = TlsRootRecoveringHttpClient(
      inner,
      WindowsTlsRootRecovery(lookup: lookups.call, trust: trusted.add, onFailure: (_, _) {}, timeout: const Duration(milliseconds: 50)),
    );

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(trusted, isEmpty);
    final inFlight = client.openUrl('GET', _stash);
    lookups.gate!.complete();
    await pumpEventQueue();
    expect(trusted, hasLength(1), reason: 'Windows was only slow: later connections must not be refused');

    lateRefusal.complete(_missingRoot);
    expect(await inFlight, same(retried), reason: 'opened before the late trust, so refused by a store that has since been fixed');
    expect(lookups.calls, hasLength(1));
  });

  test('a server that leaves out an intermediate is recovered: every certificate Windows used is trusted', () async {
    final inner = _FakeClient([_missingRoot, _FakeRequest()]);
    final intermediate = Uint8List.fromList([4, 5, 6]);
    final root = Uint8List.fromList([7, 8, 9]);
    final lookups = _Lookups()..chain = [intermediate, root];
    final trusted = <String>[];
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (pem) => trusted.add(ascii.decode(pem))));

    await client.openUrl('GET', _stash);
    expect(trusted, [pemOf(intermediate), pemOf(root)]);
  });

  test('a client that chooses its own connections gets no recovery, so WinHTTP never reaches an address nobody judged', () async {
    final inner = _FakeClient([_missingRoot]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}))
      ..connectionFactory = (url, proxyHost, proxyPort) => throw UnimplementedError();

    await expectLater(client.openUrl('GET', _stash), throwsA(same(_missingRoot)));
    expect(lookups.calls, isEmpty);
  });

  test('a wss:// connection, which arrives as https with port 0, is recovered on port 443', () async {
    final inner = _FakeClient([_missingRoot, _FakeRequest()]);
    final lookups = _Lookups();
    final client = TlsRootRecoveringHttpClient(inner, WindowsTlsRootRecovery(lookup: lookups.call, trust: (_) {}));

    await client.openUrl('GET', Uri(scheme: 'https', host: 'ws.example.net', port: 0, path: '/'));
    expect(lookups.calls, [('ws.example.net', 443)]);
  });

  test('the PEM built from a Windows certificate is what SecurityContext reads', () {
    final pem = pemOf(_testRootDer());
    expect(pem, _testRootPem);
    expect(() => SecurityContext(withTrustedRoots: false).setTrustedCertificatesBytes(ascii.encode(pem)), returnsNormally);
  });

  test('clients on the default context are wrapped, and a client with a context of its own is not', () {
    HttpOverrides.runWithHttpOverrides(() {
      expect(HttpClient(), isA<TlsRootRecoveringHttpClient>());
      expect(HttpClient(context: SecurityContext.defaultContext), isA<TlsRootRecoveringHttpClient>());
      expect(
        HttpClient(context: SecurityContext()),
        isNot(isA<TlsRootRecoveringHttpClient>()),
        reason: 'recovery trusts roots in the default context only, so retrying a client with its own would be refused again',
      );
    }, TlsRootRecoveryOverrides(WindowsTlsRootRecovery(lookup: _Lookups().call, trust: (_) {})));
  });
}
