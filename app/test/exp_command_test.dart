// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// EXP (dev-commands extension) toggles an experimental feature. The hook
// only parses — token resolution against experiments.yaml happens app-side
// (handleCommandAction's toggleExperiment case) — so what matters here is
// that EXP is recognized, bare EXP asks for a parameter instead of running,
// and the token passes through verbatim in the toggleExperiment action.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;

  setUp(() async {
    extensions = ExtensionService();
    await extensions.start();
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
