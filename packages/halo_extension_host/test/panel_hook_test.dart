// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `panel` hook against a REAL bundle (docs/extensions/hooks.md): the two
// calls a panel's whole lifecycle is made of, over the actual bridge. The
// Dart-side catalog and rendering are unit-tested in app/test; what only
// this can prove is that an extension can answer at all, and that the
// descriptor and content shapes both sides agree on survive the crossing.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// Its own host per test: the sample keeps each placement's simulated radio
  /// in module state, which a shared host would carry from one test into the
  /// next.
  Future<ExtensionHost> panelHost() => ExtensionHost.start(
    kernelSource: bundleSource('kernel'),
    extensions: [ExtensionBundle(key: 'k2hrc-panel-scenes', source: bundleSource('k2hrc-panel-scenes'))],
    onHostCall: nullHostCall,
  );

  test('a panel hook advertises its panels, and renders one', () async {
    final host = await panelHost();
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'k2hrc-panel-scenes',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    expect(panels, isA<List>());
    final byKey = {for (final p in (panels as List).cast<Map>()) p['key']: p};
    expect(byKey.keys, ['radio', 'weather', 'controls']);
    // The descriptor's optional halves are what the Layout Setup sheet and
    // the several-placements machinery are built from — a panel that
    // declared them must not lose them on the way across.
    final radio = byKey['radio']!;
    expect(radio['title'], isNotEmpty);
    expect(radio['icon'], 'radio-tower');
    expect(radio['multiple'], isTrue);
    expect(radio['on'], ['tick:1']);

    Future<Map> render(String instanceId) async =>
        await host.invokeHook(
              'panel',
              key: 'k2hrc-panel-scenes',
              method: 'render',
              args: {
                'panelKey': 'radio',
                'instanceId': instanceId,
                'operation': {'uuid': 'op-1', 'stationCall': 'N0DEV'},
                'qsoCount': 7,
                'config': const <String, dynamic>{},
                'reason': 'initial',
              },
              timeout: const Duration(seconds: 30),
            )
            as Map;

    // An event's value has to arrive for the panel to act on it, and the
    // render after it reads the state that event left behind: the only way
    // 14200 is in the scene is that both crossings carried their args.
    final result = await host.invokeHook(
      'panel',
      key: 'k2hrc-panel-scenes',
      method: 'onEvent',
      args: {
        'panelKey': 'radio',
        'instanceId': 'a',
        'operation': const <String, dynamic>{},
        'qsoCount': 0,
        'config': const <String, dynamic>{},
        'reason': 'event',
        'event': {'controlId': 'tune', 'action': 'tune', 'phase': 'commit', 'sequence': 1, 'value': 14200},
      },
      timeout: const Duration(seconds: 30),
    );
    expect(((result as Map)['values'] as Map)['requested'], 14200);

    final document = await render('a');
    expect(document['kind'], 'scene');
    // A scene is the deepest content shape a panel returns — layers and
    // controls nested inside the scene — so it is the one a lossy serializer
    // would break first.
    final scene = document['scene'] as Map;
    expect((scene['values'] as Map)['requested'], 14200);
    expect((scene['layers'] as List).map((l) => (l as Map)['id']), containsAll(['face', 'needle', 'knob']));
    expect((scene['controls'] as List).map((c) => (c as Map)['kind']), containsAll(['knob', 'slider', 'button']));
    // `instanceId` is what keeps two placements of one panel apart; a render
    // that lost it would show the first placement's state in the second.
    expect((((await render('b'))['scene'] as Map)['values'] as Map)['requested'], 14074);
  });

  /// An inline panel extension, so what only a CONTEXT-varying panel can
  /// prove doesn't depend on a shipped one declaring anything in
  /// particular. `k2hrc-panel-scenes` ignores `ctx`, which is right for it
  /// and leaves that half uncovered.
  /// A fixture that fails to EVALUATE fails these tests as "no hook
  /// registered": activation errors are logged and swallowed by the kernel,
  /// so the real cause is in `host.logs`, not in the failure message.
  const contextualPanelSource = """
__polo.defineExtension({
  key: 'panel-test-extension',
  name: 'Panel Test Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('panel', {
      key: 'panel-test',
      hook: {
        getPanels: async function (args, ctx) {
          if (!ctx.developerMode) return []
          return [{ key: 'probe', title: 'Probe', on: ['operation', 'tick:30'] }]
        },
      },
    })
  },
})
""";

  /// `ctx.developerMode` reaches an extension through the host's own
  /// getSettings call, so a test about a panel that varies with it has to
  /// answer that call.
  Future<ExtensionHost> contextualPanelHost(bool developerMode) => ExtensionHost.start(
    kernelSource: bundleSource('kernel'),
    extensions: const [ExtensionBundle(key: 'panel-test-extension', source: contextualPanelSource)],
    onHostCall: (method, params) async => method == 'getSettings' ? {'developerMode': developerMode} : null,
  );

  test('a descriptor carries its refresh triggers across', () async {
    final host = await contextualPanelHost(true);
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'panel-test',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    // `on` is a bare pass-through, but the host builds a panel's refresh
    // budget from it, so a serializer that dropped what it did not recognize
    // would leave a panel that never updates and nothing to say why. Also the
    // positive half of the pair below: a descriptor comes back at all only
    // because HookContext reached getPanels carrying developerMode.
    final panel = (panels as List).single as Map;
    expect(panel['on'], containsAll(['operation', 'tick:30']));
  });

  test('a panel may hide itself from the catalog', () async {
    final host = await contextualPanelHost(false);
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'panel-test',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    // An empty descriptor list survives the crossing as an empty list, not
    // as a failure — a panel that can only be built for some operators is
    // why the hook is a call and not a manifest entry. On its own this
    // cannot tell a correct `false` from a dead bridge; the test above is
    // what rules the second one out.
    expect(panels, isEmpty);
  });
}
