// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the real kernel sends for `ctx.getSpots` and `ctx.getHistoryForCall`,
// read by the parsers the app and the CLI answer them with. Both refuse an
// option they do not know, so a misspelled one cannot answer unfiltered —
// and the kernel adds a key of its own to every call it makes. Tested apart,
// a kernel that names its caller and a parser that refuses the name both
// pass, and every call an extension makes to either is refused.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// A panel that asks for spots and for a call's history with the options its
/// config carries, and shows what came back or why it did not.
const _reader = '''
__polo.defineExtension({
  key: 'option-reader',
  name: 'option-reader',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('panel', { key: 'option-reader', hook: {
      getPanels: async function () { return [{ key: 'reader', title: 'Reader' }] },
      render: async function (args, ctx) {
        const said = async function (read) {
          try { await read(); return 'answered' } catch (e) { return String(e && e.message || e) }
        }
        const spots = await said(function () { return ctx.getSpots(args.config.spots) })
        const history = await said(function () { return ctx.getHistoryForCall('K1ABC', args.config.history) })
        return { kind: 'markdown', content: spots + '|' + history }
      },
    }})
  },
})
''';

void main() {
  requireBundles();

  late ExtensionHost host;

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'option-reader', source: _reader)],
      useIsolate: false,
      onHostCall: (method, params) async {
        switch (method) {
          case 'getSpots':
            SpotsQuery.fromParams(params);
            return const [];
          case 'getHistoryForCall':
            HistoryFilter.fromParams(params);
            return const [];
        }
        return null;
      },
    );
    await host.activated;
  });

  tearDownAll(() => host.dispose());

  Future<String> render({Map<String, dynamic>? spots, Map<String, dynamic>? history}) async {
    final result = await host.invokeHook(
      'panel',
      key: 'option-reader',
      method: 'render',
      args: {
        'panelKey': 'reader',
        'operation': {'uuid': 'op-1'},
        'qsoCount': 0,
        'config': {'spots': ?spots, 'history': ?history},
        'reason': 'initial',
      },
    );
    return (result as Map)['content'] as String;
  }

  test('a call with no options is answered', () async {
    expect(await render(), 'answered|answered');
  });

  test('a call with options is answered', () async {
    expect(await render(spots: {'filter': 'all', 'band': '20m', 'annotate': false}, history: {'band': '20m', 'limit': 10}), 'answered|answered');
  });

  test('a misspelled option is still refused, naming it', () async {
    // What accepting the kernel's own key must not become: a parser that lets
    // any key through answers `bands: '20m'` with every band.
    expect(await render(spots: {'bands': '20m'}, history: {'bands': '20m'}), allOf(contains('`bands`'), isNot(contains('answered'))));
  });
}
