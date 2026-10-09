// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ctx.getSpots`, through the real kernel: which operation a panel's spots are
// judged against when it names none. The default is the operation the panel
// was rendered for — without it every panel has to know to pass its own uuid,
// and one that forgets shows every worked station as new.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// A panel that lists the calls `ctx.getSpots` answers, asking with whatever
/// options its config carries.
const _reader = '''
__polo.defineExtension({
  key: 'spots-reader',
  name: 'spots-reader',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('panel', { key: 'spots-reader', hook: {
      getPanels: async function () { return [{ key: 'board', title: 'Board', on: ['spots'] }] },
      render: async function (args, ctx) {
        const spots = await ctx.getSpots(args.config.options)
        return { kind: 'markdown', content: spots.map(function (s) { return s.their.call }).join(',') }
      },
    }})
  },
})
''';

void main() {
  requireBundles();

  late ExtensionHost host;
  final sent = <Map<String, dynamic>>[];
  Object? answer;

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'spots-reader', source: _reader)],
      useIsolate: false,
      onHostCall: (method, params) async {
        if (method != 'getSpots') return null;
        sent.add(params);
        return answer;
      },
    );
    await host.activated;
  });

  tearDownAll(() => host.dispose());

  setUp(() {
    sent.clear();
    answer = [
      {
        'their': {'call': 'K1ABC'},
        'spot': {'timeInMillis': 0, 'source': 'test'},
      },
    ];
  });

  Future<String> render([Map<String, dynamic>? options]) async {
    final result = await host.invokeHook(
      'panel',
      key: 'spots-reader',
      method: 'render',
      args: {
        'panelKey': 'board',
        'operation': {'uuid': 'op-1'},
        'qsoCount': 0,
        'config': {'options': ?options},
        'reason': 'spots',
      },
    );
    return (result as Map)['content'] as String;
  }

  test('a panel\'s spots are judged against the operation it was rendered for', () async {
    expect(await render(), 'K1ABC');
    expect(sent.single['operationUuid'], 'op-1');
  });

  test('an operation the caller names wins', () async {
    await render({'operationUuid': 'op-2'});
    expect(sent.single['operationUuid'], 'op-2');
  });

  test('declining annotations sends no operation to judge against', () async {
    await render({'annotate': false, 'filter': 'all'});
    expect(sent.single['operationUuid'], isNull);
    expect(sent.single['filter'], 'all');
  });

  test('a host answering nothing reads as an empty board', () async {
    answer = null;
    expect(await render(), '');
  });
}
