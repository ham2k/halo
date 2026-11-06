// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ctx.opStyle` (docs/extensions/host.md § The hook context): each logging
// set's operating style, with or without a radio. Through the REAL kernel,
// which builds every hook's context from `getSettings` and caches it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

const _probe = '''
  globalThis.__halo.defineExtension({
    key: 'probe',
    name: 'probe',
    version: '0.0.1',
    onActivation({ registerHook }) {
      registerHook('bench', { key: 'probe', hook: { call: async (args, ctx) => ctx.opStyle ?? null } });
    },
  });
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The trap: the kernel caches the context for seconds, and the style moves
  // with no setting saved — a hook reading it right after a CQ would see the
  // style from before it.
  test("a hook reads each set's style, fresh after a change, with no radio at all", () async {
    final extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    final services = (await makeHaLoServices(extensions: extensions)).services;
    await extensions.setDevBundles({
      'probe': (source: _probe, info: const ExtensionInfo(key: 'probe', file: 'probe.js', source: ExtensionSource.dev, core: true, name: 'probe')),
    });
    Future<Object?> read() => extensions.host!.invokeHook('bench', key: 'probe', method: 'call', args: const {}, timeout: const Duration(seconds: 10));

    expect(await read(), {'A': 'normal'}, reason: 'normal is the default, and B is not a set outside SO2R');
    services.cat.setStyle('A', OperatingStyle.run);
    expect(await read(), {'A': 'run'});

    await services.settings.setExperimentEnabled('so2r', true);
    services.cat.setStyle('B', OperatingStyle.run);
    expect(await read(), {'A': 'run', 'B': 'run'});
  }, timeout: const Timeout(Duration(seconds: 60)));
}
