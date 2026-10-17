// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVIDLE toggles Show idle metrics, the extension engine's idle share in the
// status bar. The command is the real dev-commands extension; the toggle is
// the app's.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('"DEVIDLE" (any case) dispatches a devIdle action', () async {
    final extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    await extensions.start();
    for (final input in ['DEVIDLE', 'devidle']) {
      final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
      final value = entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      expect((value['commands'] as List).single, {'devIdle': {}}, reason: 'for input "$input"');
    }
  });

  test('the command says whether it is about to enable or disable the metrics', () async {
    // A toggle whose description reads the same both ways leaves the
    // operator to guess which state they are about to land in.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionService()..settings = settings;
    await startWithShippedExtensions(extensions);
    Future<String> describe() async {
      final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': 'DEVIDLE'});
      return (entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map)['describe'] as String;
    }

    expect(await describe(), startsWith('Enable'));
    await settings.setShowIdleMetrics(true);
    expect(await describe(), startsWith('Disable'));
  });

  test('the action flips the setting each time, and says which way it went', () async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();

    final on = await services.handleCommandAction('devIdle');
    expect(settings.showIdleMetrics, isTrue);
    final off = await services.handleCommandAction('devIdle');
    expect(settings.showIdleMetrics, isFalse);
    expect(on!.text, isNot(off!.text));
  });
}
