// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// EXP (dev-commands extension) toggles an experimental feature. The flip
// itself resolves the token against experiments.yaml app-side
// (handleCommandAction's toggleExperiment case) — so what matters here is
// that EXP is recognized, bare EXP asks for a parameter instead of running,
// the token passes through verbatim in the toggleExperiment action, and the
// preview names the direction the flip will take from the catalog and state
// the hook context carries.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    setExperimentsForTesting(const [
      ExperimentDefinition(key: 'layouts', name: 'Layouts', aliases: ['lay']),
    ]);
    extensions = ExtensionService()..settings = settings;
    await startWithShippedExtensions(extensions);
  });

  Future<Map<String, dynamic>?> interpret(String input) async {
    final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  group('EXP command interpretation (real dev-commands extension)', () {
    test('"EXP <token>" dispatches toggleExperiment with the token', () async {
      final result = await interpret('EXP LAYOUTS');
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['toggleExperiment'], {'token': 'LAYOUTS'});
    });

    test('preview says Enable for an experiment that is off, by its uppercased display name', () async {
      final result = await interpret('EXP LAYOUTS');
      expect(result!['describe'], 'Enable experiment LAYOUTS?');
    });

    test('preview says Disable once the experiment is on, resolving an alias like the flip does', () async {
      await settings.setExperimentEnabled('layouts', true);
      // The flip's own invalidation is what keeps the preview honest right
      // after it; a stale cache here would still say Enable.
      extensions.invalidateHookContext();
      final result = await interpret('EXP LAY');
      expect(result!['describe'], 'Disable experiment LAYOUTS?');
      expect((result['commands'] as List).cast<Map>().single['toggleExperiment'], {'token': 'LAY'});
    });

    test('an unknown token still previews as a toggle and reaches the app to fail there', () async {
      final result = await interpret('EXP NOPE');
      expect(result!['describe'], 'Toggle experiment NOPE?');
      expect(result['commands'], isNotNull);
    });

    test('bare "EXP" expects a parameter instead of executing', () async {
      final result = await interpret('EXP');
      expect(result, isNotNull);
      expect(result!['expectsParams'], isTrue);
      expect(result['commands'], isNull);
    });

    test('unrelated input does not match', () async {
      expect(await interpret('EXPORT'), isNull);
    });

    test('extra words error instead of demoting back to callsign text', () async {
      // The bare-EXP expectsParams result put the field into free-text mode,
      // so a second word must stay a (failed) command — falling back to null
      // would let Enter treat "EXP LAYOUTS ON" as a callsign to log.
      final result = await interpret('EXP LAYOUTS ON');
      expect(result, isNotNull);
      expect(result!['error'], isA<String>());
      expect(result['commands'], isNull);
    });
  });
}
