// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `panel` hook against a REAL bundle (docs/extensions/hooks.md): the two
// calls a panel's whole lifecycle is made of, over the actual bridge. The
// Dart-side catalog and rendering are unit-tested in app/test; what only
// this can prove is that an extension can answer at all, and that the
// descriptor shape both sides agree on survives the crossing.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// `ctx.developerMode` reaches an extension through the host's own
  /// getSettings call, so a test about a panel that varies with it has to
  /// answer that call.
  Future<ExtensionHost> hostWithDeveloperMode(bool developerMode) => ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'dev-commands', source: bundleSource('dev-commands'))],
        onHostCall: (method, params) async => method == 'getSettings' ? {'developerMode': developerMode} : null,
      );

  test('a panel hook advertises its panels, and renders one', () async {
    // dev-commands hides its panel outside developer mode, which is also the
    // check that a panel CAN vary with context rather than being a static
    // manifest entry.
    final host = await hostWithDeveloperMode(true);
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'dev-commands',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    expect(panels, isA<List>());
    final panel = (panels as List).single as Map;
    expect(panel['key'], 'context');
    expect(panel['title'], isNotEmpty);
    // The descriptor's optional halves are what the Layout Setup sheet and
    // the refresh budget are built from — a panel that declared them must
    // not lose them on the way across.
    expect(panel['description'], isNotEmpty);
    expect(panel['preview'], startsWith('<svg'));
    expect(panel['on'], contains('operation'));
    expect((panel['form'] as List).single, containsPair('key', 'showOperation'));

    final content = await host.invokeHook(
      'panel',
      key: 'dev-commands',
      method: 'render',
      args: {
        'panelKey': 'context',
        'operation': {'uuid': 'op-1', 'stationCall': 'N0DEV'},
        'qsoCount': 7,
        'config': {'showOperation': false},
        'reason': 'initial',
      },
      timeout: const Duration(seconds: 30),
    );

    final document = content as Map;
    expect(document['kind'], 'markdown');
    // Proves the args actually arrived, not merely that something rendered.
    expect(document['content'], contains('op-1'));
    expect(document['content'], contains('7'));
    expect(document['content'], contains('initial'));
  });

  test('a panel may hide itself from the catalog', () async {
    final host = await hostWithDeveloperMode(false);
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'dev-commands',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    // A developer tool has no business in a normal operator's panel list —
    // the same rule dev commands follow about the command palette.
    expect(panels, isEmpty);
  });
}
