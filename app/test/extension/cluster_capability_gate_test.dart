// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The cluster host calls are manifest capabilities in three levels
// (`requiresClusterRead`, `requiresClusterSpot`, `requiresClusterCommand`).
// Every level logs the operator in to a node; the upper two speak there in
// their name — a spot read worldwide as theirs, or any command at all. A
// level leaking into the next would let a spotter announce to every node.
//
// Driven through the REAL kernel with probe bundles, as the radio gate is:
// the host checks a key, and the kernel is what makes it the caller's own.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/cluster/cluster_service.dart';
import 'package:ham2k_logger/services/cluster/cluster_settings.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

String probe(String key) =>
    '''
  globalThis.__polo.defineExtension({
    key: '$key',
    name: '$key probe',
    version: '0.0.1',
    onActivation({ registerHook, hostCall }) {
      const received = [];
      registerHook('bench', {
        key: '$key',
        hook: {
          call: async (args) => await hostCall(args.method, args.params ?? {}),
          received: async () => received,
        },
      });
      registerHook('cluster', {
        key: '$key',
        hook: { onLines: async ({ lines }) => { received.push(...lines.map((l) => l.text)) } },
      });
    },
  });
''';

class FakeCluster extends Fake implements ClusterService {
  final calls = <String>[];
  final subscribed = <String>{};

  static const _status = ClusterStatus(state: ClusterState.connected, node: ClusterNode('K3LR', 'dx.k3lr.com', 23), call: 'KI2D', lastSeq: 0);

  @override
  ClusterStatus get status => _status;

  @override
  List<ClusterLine> lines({int? after, int? limit}) => [const ClusterLine(1, 0, 'DX de W3LPL: 14025.0 JA1ABC')];

  @override
  Future<ClusterStatus> subscribe(String subscriber) async {
    subscribed.add(subscriber);
    return _status;
  }

  @override
  void unsubscribe(String subscriber) => subscribed.remove(subscriber);

  @override
  void retainSubscribers(Set<String> keep) => subscribed.removeWhere((key) => !keep.contains(key));

  @override
  Future<ClusterReply> postSpot({required double freqKHz, required String call, String? comment}) async {
    calls.add('spot $freqKHz $call');
    return const ClusterReply.ok([]);
  }

  @override
  Future<ClusterReply> send(String command) async {
    calls.add('send $command');
    return const ClusterReply.ok([]);
  }
}

({String source, ExtensionInfo info}) bundle(String key, {bool read = false, bool spot = false, bool command = false}) => (
  source: probe(key),
  info: ExtensionInfo(
    key: key,
    file: '$key.js',
    source: ExtensionSource.dev,
    core: true,
    name: key,
    hooks: const ['bench', 'cluster'],
    requiresClusterRead: read,
    requiresClusterSpot: spot,
    requiresClusterCommand: command,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late FakeCluster cluster;

  setUp(() async {
    cluster = FakeCluster();
    extensions = ExtensionService()..clusterCalls.cluster = () => cluster;
    await extensions.setDevBundles({
      'reader': bundle('reader', read: true),
      'spotter': bundle('spotter', spot: true),
      'commander': bundle('commander', command: true),
      'plain': bundle('plain'),
    });
  });

  Future<dynamic> call(String who, String method, [Map<String, dynamic> params = const {}]) =>
      extensions.host!.invokeHook('bench', key: who, method: 'call', args: {'method': method, 'params': params}, timeout: const Duration(seconds: 10));

  Matcher blockedFor(String capability) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(capability)));

  const spot = {'freq': 7200, 'call': 'N2Y', 'comment': 'test'};

  test('an extension that declares nothing cannot reach the cluster at all', () async {
    for (final method in ['clusterStatus', 'clusterLines', 'clusterSubscribe']) {
      await expectLater(call('plain', method), blockedFor('requiresClusterRead'));
    }
    await expectLater(call('plain', 'clusterPostSpot', spot), blockedFor('requiresClusterSpot'));
    await expectLater(call('plain', 'clusterSend', {'command': 'sh/dx'}), blockedFor('requiresClusterCommand'));
    expect(cluster.calls, isEmpty);
    expect(cluster.subscribed, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('read does not post, and spot does not send any command', () async {
    expect((await call('reader', 'clusterStatus') as Map)['call'], 'KI2D');
    expect(await call('reader', 'clusterLines'), hasLength(1));
    await expectLater(call('reader', 'clusterPostSpot', spot), blockedFor('requiresClusterSpot'));

    expect((await call('spotter', 'clusterPostSpot', spot) as Map)['ok'], true);
    // A spotter that could send could ANNOUNCE/FULL to every node, or change
    // the operator's password on this one.
    await expectLater(call('spotter', 'clusterSend', {'command': 'announce/full hi'}), blockedFor('requiresClusterCommand'));

    expect((await call('commander', 'clusterSend', {'command': 'sh/dx'}) as Map)['ok'], true);
    expect((await call('commander', 'clusterPostSpot', spot) as Map)['ok'], true);
    expect(cluster.calls, ['spot 7200.0 N2Y', 'send sh/dx', 'spot 7200.0 N2Y']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('naming a capable extension in the call does not borrow its capability, or its subscription', () async {
    await expectLater(call('plain', 'clusterSend', {'command': 'sh/dx', 'extensionKey': 'commander'}), blockedFor('requiresClusterCommand'));
    await call('reader', 'clusterSubscribe', {'extensionKey': 'spotter'});
    expect(cluster.subscribed, {'reader'});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a subscriber\'s cluster hook receives the lines', () async {
    await extensions.deliverClusterLines('reader', [const ClusterLine(7, 0, 'DX de K1TTT: 7010.0 ZL2XX').toJson()]);
    expect(await extensions.host!.invokeHook('bench', key: 'reader', method: 'received', timeout: const Duration(seconds: 10)), ['DX de K1TTT: 7010.0 ZL2XX']);
    expect(await extensions.host!.invokeHook('bench', key: 'spotter', method: 'received', timeout: const Duration(seconds: 10)), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a runtime restart drops every subscription, whose hooks went with the old runtime', () async {
    await call('reader', 'clusterSubscribe');
    expect(cluster.subscribed, {'reader'});
    await extensions.setDevBundles({'reader': bundle('reader', read: true)});
    expect(cluster.subscribed, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
