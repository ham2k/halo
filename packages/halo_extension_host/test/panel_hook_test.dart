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

  /// `getSettings` MUST be answered: an unset handler is not a neutral
  /// default — the kernel's call rejects and getSettingsContext swallows it
  /// (sdk/src/kernel.ts), leaving `ctx.appName` undefined, which the panel
  /// renders as an empty `app.name` rather than failing.
  Future<ExtensionHost> panelHost() => ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'custom-text', source: bundleSource('custom-text'))],
        onHostCall: (method, params) async => method == 'getSettings' ? {'appName': 'Ham2K Logger'} : null,
      );

  test('a panel hook advertises its panels, and renders one', () async {
    final host = await panelHost();
    addTearDown(host.dispose);

    final panels = await host.invokeHook(
      'panel',
      key: 'custom-text',
      method: 'getPanels',
      args: const <String, dynamic>{},
      timeout: const Duration(seconds: 30),
    );

    expect(panels, isA<List>());
    final panel = (panels as List).single as Map;
    expect(panel['key'], 'text');
    expect(panel['title'], isNotEmpty);
    // The descriptor's optional halves are what the Layout Setup sheet and
    // the several-placements machinery are built from — a panel that
    // declared them must not lose them on the way across.
    expect(panel['description'], isNotEmpty);
    expect(panel['preview'], startsWith('<svg'));
    expect(panel['multiple'], isTrue);
    expect((panel['form'] as List).map((f) => (f as Map)['key']), containsAll(['title', 'content']));

    final content = await host.invokeHook(
      'panel',
      key: 'custom-text',
      method: 'render',
      args: {
        'panelKey': 'text',
        'operation': {'uuid': 'op-1', 'stationCall': 'N0DEV'},
        'qsoCount': 7,
        'config': {'title': 'Sked list', 'content': 'Worked {{ op.qsoCount }} so far in {{ app.name }}'},
        'reason': 'initial',
      },
      timeout: const Duration(seconds: 30),
    );

    final document = content as Map;
    expect(document['kind'], 'markdown');
    // Proves the args actually arrived, not merely that something rendered:
    // the count is only in the result because the render args carried it.
    // `app.name` is the one HookContext field this panel consumes, and it
    // reaches the template through the host's own getSettings answer — an
    // unanswered one renders it empty without failing anything.
    expect(document['content'], contains('Worked 7 so far in Ham2K Logger'));
    expect(document['title'], 'Sked list');
    // A render declares its OWN triggers, derived from the operator's
    // template — the one part of the content contract the descriptor cannot
    // carry, and the reason PanelContent has the field at all. `op.qsoCount`
    // is what asks for these two; a template naming nothing live would
    // cross with an empty list.
    expect(document['triggers'], containsAll(['qsoLogged', 'operation']));
  });

  /// An inline panel extension, so what only a CONTEXT-varying panel can
  /// prove doesn't depend on a shipped one declaring anything in
  /// particular. `custom-text` ignores `ctx` and declares no descriptor
  /// triggers, which is right for it and leaves both halves uncovered.
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

    // `on` is the one descriptor field no shipped panel declares — a bare
    // pass-through, but the host builds a panel's refresh budget from it,
    // so a serializer that dropped what it did not recognize would leave a
    // panel that never updates and nothing to say why. Also the positive
    // half of the pair below: a descriptor comes back at all only because
    // HookContext reached getPanels carrying developerMode.
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
