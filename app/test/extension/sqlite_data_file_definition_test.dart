// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `sqlite` data file's definition as the real kernel hands it to the app.
// The kernel builds each definition from the fields it knows, so one it does
// not pass on never reaches DataFileManager — and a `sqlite` file without its
// `sqliteQuery` fails every sync, in every install, while every test that
// hands the manager a definition directly stays green.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

const _probe = '''
(function () {
'use strict'
__halo.defineExtension({
  key: 'dev-scp-probe',
  name: 'SCP probe',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('dataFile', { key: 'dev-scp-probe', hook: {
      name: 'Super Check Partial',
      description: 'Calls heard in contests',
      url: 'https://www.supercheckpartial.com/SCP.DB',
      maxAgeInDays: 1,
      fetchType: 'sqlite',
      category: 'dev-scp-probe',
      sqliteQuery: 'SELECT callsign, annual_rate AS rate FROM callsigns',
      fields: { key: 'callsign' },
    }})
  },
})
})()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the kernel hands the app the query and the fields a sqlite data file declares', () async {
    final extensions = ExtensionService();
    await makeHaLoServices(extensions: extensions);
    await startWithShippedExtensions(extensions);
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-scp-probe', source: _probe, api: 25));

    final entries = await extensions.host!.invokeAll(Hooks.dataFileGetDefinition);
    final value = (entries.cast<Map<dynamic, dynamic>>().firstWhere((e) => e['key'] == 'dev-scp-probe')['value'] as Map).cast<String, dynamic>();
    expect(value['fetchType'], 'sqlite');
    expect(value['sqliteQuery'], 'SELECT callsign, annual_rate AS rate FROM callsigns');
    expect(value['fields'], {'key': 'callsign'});
  });
}
