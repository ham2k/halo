// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the kernel hands the app for a `dataFile` definition. The app reads
// only what this fan-out carries: a field registered but left out here never
// reaches the importer, and the file silently imports as if it were absent.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  test("a ham2k definition reaches the app with its deltaUrl, resolved, and its fields", () async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: const [
        ExtensionBundle(
          key: 'calls',
          source: '''
__halo.defineExtension({
  key: 'calls',
  name: 'Calls',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('dataFile', {
      key: 'calls-hf',
      hook: {
        name: 'HF calls',
        description: 'Calls with HF privileges',
        url: 'https://example.test/download?set=hf',
        deltaUrl: function () { return 'https://example.test/delta?set=hf&since={since}' },
        maxAgeInDays: 1,
        fetchType: 'ham2k',
        category: 'calls-hf',
        fields: { key: 'call', name: 'name' },
      },
    })
  },
})
''',
        ),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
    final def = (entries.singleWhere((e) => e['key'] == 'calls-hf')['value'] as Map).cast<String, dynamic>();

    expect(def['fetchType'], 'ham2k');
    expect(def['deltaUrl'], 'https://example.test/delta?set=hf&since={since}', reason: 'a function, like url, is called for its value');
    expect(def['fields'], {'key': 'call', 'name': 'name'});
  });
}
