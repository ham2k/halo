// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The runtime is told about developer mode: at boot, and again whenever the
// setting changes, because the one thing that lets a wildcard `domains` grant
// reach the local network is main-isolate state the runtime cannot read for
// itself. Through the real service, the real kernel and the real client: a
// fetch to loopback the rule refuses never opens a socket, and one the rule
// admits fails on the socket instead, where nothing listens.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

const probe = r'''
  globalThis.__polo.defineExtension({
    key: 'probe',
    name: 'probe',
    version: '0.0.1',
    onActivation({ registerHook, hostCall }) {
      registerHook('bench', {
        key: 'probe',
        hook: { fetch: async (args) => await hostCall('fetch', args) },
      });
    },
  });
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    // The production order (bootstrap.dart, then extension_wiring.dart): the
    // runtime is started before the settings are wired, so anything attached
    // to settings at start attaches to nothing.
    extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
  });

  /// How a fetch to loopback ends: refused by the rule, or let through to a
  /// port nothing listens on.
  Future<String> fetchLoopback() async {
    try {
      await extensions.host!.invokeHook('bench', key: 'probe', method: 'fetch', args: {'url': 'https://127.0.0.1:1/'}, timeout: const Duration(seconds: 10));
      return 'answered';
    } catch (e) {
      return '$e';
    }
  }

  test('developer mode reaches the runtime when the settings are wired, and on every change after', () async {
    await settings.setDeveloperMode(true);
    await extensions.start();
    await extensions.setDevBundles({
      'probe': (
        source: probe,
        info: ExtensionInfo(key: 'probe', file: 'probe.js', source: ExtensionSource.dev, core: true, name: 'probe', domains: const ['*']),
      ),
    });
    // No hook runs before the settings are wired, so the first probe comes
    // after: a runtime that booted with none read developer mode as off, and
    // only the wiring can have told it otherwise.
    extensions.settings = settings;
    // The wiring's other duty (extension_wiring.dart): a runtime that booted
    // before the settings ran its catch-up for nothing and left it unsettled,
    // which the harness's teardown waits on.
    await catchUpOnCatalogExtensions(extensions);
    expect(await fetchLoopback(), isNot(contains('is on the local network')), reason: 'the settings arrived, and the runtime was told: through to the socket');
    await settings.setDeveloperMode(false);
    expect(await fetchLoopback(), contains('is on the local network'), reason: 'withdrawn, and the runtime was told');
    await settings.setDeveloperMode(true);
    expect(await fetchLoopback(), isNot(contains('is on the local network')), reason: 'granted again');
  });
}
