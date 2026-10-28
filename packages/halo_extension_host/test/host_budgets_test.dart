// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The budgets one bundle is held to beyond its grants (host_budgets.dart): how
// many host calls it may have awaiting an answer, how much `kv` it may hold,
// and that a hook the app has timed out keeps its fetch slot no longer than
// the fetch itself. Driven through the REAL kernel by a probe bundle, with the
// app's answers and the network stubbed below the host's own checks.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/fetch_policy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bundles.dart';

// One bundle defining [keys]: `probe` with its sub-extension `probe-sub`, on
// its budgets as on its grant, and `b0`…`b7` each a bundle of its own. `hang`
// reaches the app through the bound host call the SDK uses, which names its
// caller; `hangAs` through the kernel's public surface, claiming whatever key
// it is given. `probe-sub` registers an account hook, so the kernel reads its
// account before each of its hooks runs.
String probeBundle(List<String> keys) =>
    '''
  for (const key of [${keys.map((key) => "'$key'").join(', ')}]) {
    globalThis.__polo.defineExtension({
      key,
      name: key,
      version: '0.0.1',
      onActivation({ registerHook, hostCall }) {
        const attempt = async (call) => {
          try { return await call() } catch (e) { return 'refused: ' + e.message }
        }
        if (key === 'probe-sub') registerHook('account', { key, hook: {} })
        registerHook('bench', {
          key,
          hook: {
            hang: async () => attempt(() => hostCall('hang', {})),
            hangAs: async ({ claim }) => attempt(() => globalThis.__polo.hostCall('hang', { extensionKey: claim })),
            qsos: async ({ uuid }, ctx) => attempt(() => ctx.getQsos(uuid)),
            fetch: async (args) => attempt(() => hostCall('fetch', args)),
            kvSet: async ({ key: k, value }) => attempt(() => hostCall('kvSet', { key: k, value })),
            kvGet: async ({ key: k }) => hostCall('kvGet', { key: k }),
            kvFill: async ({ prefix, count, value }) => {
              for (let i = 0; i < count; i++) {
                const outcome = await attempt(() => hostCall('kvSet', { key: prefix + i, value }))
                if (typeof outcome === 'string') return 'at ' + i + ': ' + outcome
              }
              return 'stored ' + count
            },
          },
        });
      },
    });
  }
''';

final probe = probeBundle(['probe', 'probe-sub']);

void main() {
  requireBundles();

  /// The bundles the host knows, `probe` among them unless [probeUnknown]:
  /// then `probe-sub` is a bundle of its own until a reload registers `probe`.
  Map<String, List<String>> bundles({bool probeUnknown = false}) => {
    if (!probeUnknown) 'probe': ['a.example'],
    for (var i = 0; i < 8; i++) 'b$i': [],
  };

  Future<ExtensionHost> hostWith({HostCallHandler? onHostCall, http.Client? client, bool probeUnknown = false}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(key: 'probe', source: probe),
        for (var i = 0; i < 8; i++) ExtensionBundle(key: 'b$i', source: probeBundle(['b$i'])),
      ],
      fetchAllowlists: bundles(probeUnknown: probeUnknown),
      httpClient: client ?? MockClient((_) async => http.Response('', 404)),
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: onHostCall ?? nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<dynamic> call(
    ExtensionHost host,
    String method, {
    Map<String, dynamic> args = const {},
    String key = 'probe',
    Duration timeout = const Duration(seconds: 20),
  }) => host.invokeHook('bench', key: key, method: method, args: args, timeout: timeout);

  /// An app that answers `hang` only once [gate] completes, counting the calls
  /// it is holding, and everything else at once.
  ({Completer<void> gate, int Function() holding, HostCallHandler handler}) hangingApp() {
    final gate = Completer<void>();
    var holding = 0;
    return (
      gate: gate,
      holding: () => holding,
      handler: (method, params) async {
        if (method != 'hang') return nullHostCall(method, params);
        holding++;
        await gate.future;
        return 'done';
      },
    );
  }

  Future<void> until(FutureOr<bool> Function() condition, {required String reason}) async {
    final waited = Stopwatch()..start();
    while (!await condition()) {
      if (waited.elapsed > const Duration(seconds: 10)) fail('timed out waiting for $reason');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('host calls awaiting an answer', () {
    test('the thirty-third of a bundle is refused, and an answer frees the slot', () async {
      final app = hangingApp();
      final host = await hostWith(onHostCall: app.handler);
      final held = [for (var i = 0; i < kMaxHostCallsPending; i++) call(host, 'hang')];
      await until(() => app.holding() == kMaxHostCallsPending, reason: 'the app to hold $kMaxHostCallsPending calls');

      expect(await call(host, 'hang'), contains("'probe' already has $kMaxHostCallsPending calls awaiting an answer"));

      app.gate.complete();
      expect(await Future.wait(held), everyElement('done'));
      expect(await call(host, 'hang'), 'done');
    });

    test("a bundle's sub-extensions draw on its calls, not thirty-two of their own", () async {
      final app = hangingApp();
      final host = await hostWith(onHostCall: app.handler);
      final held = [for (var i = 0; i < kMaxHostCallsPending; i++) call(host, 'hang')];
      await until(() => app.holding() == kMaxHostCallsPending, reason: 'the app to hold the calls');

      expect(await call(host, 'hang', key: 'probe-sub'), contains("'probe' already has $kMaxHostCallsPending calls"));

      app.gate.complete();
      await Future.wait(held);
    });

    test('the ceiling across every extension holds whoever has slots to spare', () async {
      final app = hangingApp();
      final host = await hostWith(onHostCall: app.handler);
      // Eight bundles at their own cap reach it together.
      final bundles = kMaxHostCallsPendingTotal ~/ kMaxHostCallsPending;
      final held = [
        for (var b = 0; b < bundles; b++)
          for (var i = 0; i < kMaxHostCallsPending; i++) call(host, 'hang', key: 'b$b'),
      ];
      await until(() => app.holding() == kMaxHostCallsPendingTotal, reason: 'the app to hold $kMaxHostCallsPendingTotal calls');

      // `probe` has nothing awaiting an answer, and is refused all the same.
      expect(await call(host, 'hang'), contains('$kMaxHostCallsPendingTotal calls are awaiting an answer across every extension'));

      app.gate.complete();
      await Future.wait(held);
      expect(await call(host, 'hang'), 'done');
    });

    test('the public surface is one caller of its own, whatever key a call claims', () async {
      final app = hangingApp();
      final host = await hostWith(onHostCall: app.handler);
      // Claiming `probe`'s key parks nothing on `probe`: the kernel names the surface instead.
      final held = [
        for (var i = 0; i < kMaxHostCallsPending; i++) call(host, 'hangAs', args: {'claim': 'probe'}),
      ];
      await until(() => app.holding() == kMaxHostCallsPending, reason: 'the app to hold the calls');

      expect(await call(host, 'hangAs', args: {'claim': 'b0'}), contains("'__polo.hostCall' already has $kMaxHostCallsPending calls"));
      final own = call(host, 'hang');
      await until(() => app.holding() == kMaxHostCallsPending + 1, reason: "probe's own call to be held");

      app.gate.complete();
      await Future.wait([...held, own]);
    });

    test("a hook's log read draws on its bundle's calls", () async {
      final app = hangingApp();
      final host = await hostWith(onHostCall: app.handler);
      final held = [for (var i = 0; i < kMaxHostCallsPending; i++) call(host, 'hang')];
      await until(() => app.holding() == kMaxHostCallsPending, reason: 'the app to hold the calls');

      expect(await call(host, 'qsos', args: {'uuid': 'op'}), contains("'probe' already has $kMaxHostCallsPending calls awaiting an answer (getQsoChanges)"));

      app.gate.complete();
      await Future.wait(held);
    });

    test("the kernel names the hook's extension on the reads it makes for it", () async {
      final seen = <String, Object?>{};
      final host = await hostWith(
        onHostCall: (method, params) async {
          seen[method] = params['extensionKey'];
          return nullHostCall(method, params);
        },
      );
      await call(host, 'qsos', args: {'uuid': 'op'}, key: 'probe-sub');

      // The log copy's read, and the account read before a hook of an extension that registers one.
      expect(seen['getQsoChanges'], 'probe-sub');
      expect(seen['getAccount'], 'probe-sub');
    });
  });

  group('kv', () {
    test('an entry past the cap is refused, one at it is kept, and its key is part of it', () async {
      final host = await hostWith();
      // Encodes to exactly the cap under a one-character key, quotes included.
      final big = 'x' * (kMaxKvEntryChars - 3);
      expect(
        await call(host, 'kvSet', args: {'key': 'a', 'value': '${big}x'}),
        contains("'a' and its value are ${kMaxKvEntryChars + 1} characters of JSON, more than $kMaxKvEntryChars"),
      );
      expect(await call(host, 'kvSet', args: {'key': 'a', 'value': big}), isNull);
      expect(await call(host, 'kvGet', args: {'key': 'a'}), big);
      // The same value under a longer key is over: a name is heap too.
      expect(await call(host, 'kvSet', args: {'key': 'ab', 'value': big}), contains('more than $kMaxKvEntryChars'));
    });

    test('the key past the cap is refused; rewriting one it holds is not a new one', () async {
      final host = await hostWith();
      expect(await call(host, 'kvFill', args: {'prefix': 'k', 'count': kMaxKvKeysPerBundle, 'value': 1}), 'stored $kMaxKvKeysPerBundle');

      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), contains("'probe' already holds $kMaxKvKeysPerBundle keys"));
      expect(await call(host, 'kvSet', args: {'key': 'k0', 'value': 2}), isNull);
      expect(await call(host, 'kvGet', args: {'key': 'k0'}), 2);
      // Setting null frees the key itself, not only its characters.
      expect(await call(host, 'kvSet', args: {'key': 'k0', 'value': null}), isNull);
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), isNull);
    });

    test("a sub-extension stores in its bundle's quota, not one of its own", () async {
      final host = await hostWith();
      expect(await call(host, 'kvFill', args: {'prefix': 'k', 'count': kMaxKvKeysPerBundle, 'value': 1}), 'stored $kMaxKvKeysPerBundle');

      expect(await call(host, 'kvSet', args: {'key': 'mine', 'value': 1}, key: 'probe-sub'), contains("'probe' already holds"));
      // Its own namespace all the same: the bundle's keys are not its.
      expect(await call(host, 'kvGet', args: {'key': 'k0'}, key: 'probe-sub'), isNull);
    });

    test("a key stored before its bundle was known is the bundle's once it is", () async {
      final host = await hostWith(probeUnknown: true);
      expect(await call(host, 'kvSet', args: {'key': 'early', 'value': 1}, key: 'probe-sub'), isNull);
      await host.reloadBundle(
        ExtensionBundle(key: 'probe', source: probe),
        domains: ['a.example'],
      );

      expect(await call(host, 'kvFill', args: {'prefix': 'k', 'count': kMaxKvKeysPerBundle - 1, 'value': 1}), 'stored ${kMaxKvKeysPerBundle - 1}');
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), contains("'probe' already holds"));
      expect(await call(host, 'kvSet', args: {'key': 'early', 'value': null}, key: 'probe-sub'), isNull);
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), isNull);
    });

    test("the app's seeded keys are outside the quota, and stay so", () async {
      final host = await hostWith();
      for (var i = 0; i < kMaxKvKeysPerBundle; i++) {
        host.setKV('probe', 'seed$i', i);
      }
      expect(await call(host, 'kvGet', args: {'key': 'seed0'}), 0);
      expect(await call(host, 'kvFill', args: {'prefix': 'k', 'count': kMaxKvKeysPerBundle, 'value': 1}), 'stored $kMaxKvKeysPerBundle');
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), contains('already holds'));

      // A seeded key the extension rewrites is still the app's; one the app seeds over is no longer the extension's.
      expect(await call(host, 'kvSet', args: {'key': 'seed0', 'value': 'mine'}), isNull);
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), contains('already holds'));
      host.setKV('probe', 'k0', 'seeded');
      expect(await call(host, 'kvSet', args: {'key': 'one more', 'value': 1}), isNull);
    });
  });

  group('a hook the app has timed out', () {
    /// A network that holds the first [lagging] requests until [gate]
    /// completes and answers the rest at once.
    ({Completer<void> gate, MockClient client}) laggingNetwork({required int lagging}) {
      final gate = Completer<void>();
      var seen = 0;
      return (
        gate: gate,
        client: MockClient((_) async {
          if (++seen <= lagging) await gate.future;
          return http.Response('ok', 200);
        }),
      );
    }

    /// Hooks the app gives up on after [timeout] while their fetch still waits.
    Future<List<Object>> abandonedFetches(ExtensionHost host, {required Map<String, dynamic> options, required Duration timeout}) => Future.wait([
      for (var i = 0; i < kMaxFetchesInFlight; i++)
        call(
          host,
          'fetch',
          args: {'url': 'https://a.example/$i', ...options},
          timeout: timeout,
        ).then<Object>((_) => fail('answered'), onError: (Object e) => e),
    ]);

    test('keeps its fetch slot only until the fetch ends', () async {
      final net = laggingNetwork(lagging: kMaxFetchesInFlight);
      final host = await hostWith(client: net.client);
      expect(await abandonedFetches(host, options: const {}, timeout: const Duration(milliseconds: 200)), everyElement(isA<HookTimeoutException>()));

      expect(await call(host, 'fetch', args: {'url': 'https://a.example/more'}), contains('already has $kMaxFetchesInFlight requests in flight'));

      net.gate.complete();
      // The eight end on the network's schedule, not the test's.
      Object? last;
      await until(() async => (last = await call(host, 'fetch', args: {'url': 'https://a.example/after'})) is Map, reason: 'the slots to free: $last');
      expect((last as Map)['status'], 200);
    });

    test('or until the timeout the extension gave it, with the network never answering', () async {
      final net = laggingNetwork(lagging: kMaxFetchesInFlight);
      final host = await hostWith(client: net.client);
      expect(
        await abandonedFetches(host, options: const {'timeout': 300}, timeout: const Duration(milliseconds: 100)),
        everyElement(isA<HookTimeoutException>()),
      );
      expect(await call(host, 'fetch', args: {'url': 'https://a.example/more'}), contains('already has $kMaxFetchesInFlight requests in flight'));

      // The fetches give up on their own; nothing answers the first eight.
      Object? last;
      await until(() async => (last = await call(host, 'fetch', args: {'url': 'https://a.example/after'})) is Map, reason: 'the slots to free: $last');
      expect((last as Map)['status'], 200);
      expect(net.gate.isCompleted, isFalse);
    });
  });

  group('RateWindow', () {
    test('admits the limit within the span, then one more for each admission that ages out', () {
      var now = 0;
      final window = RateWindow(12, const Duration(minutes: 1), nowMillis: () => now);
      for (var i = 0; i < 12; i++) {
        now = i * 1000;
        expect(window.admit(), isTrue);
      }
      now = 12000;
      expect(window.admit(), isFalse);
      now = 59999;
      expect(window.admit(), isFalse);
      now = 60000;
      expect(window.admit(), isTrue, reason: 'the first admission is a minute old');
      // A refusal left no mark: one admission aged out admits exactly one.
      expect(window.admit(), isFalse);
    });
  });
}
