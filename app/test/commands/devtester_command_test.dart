// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVTESTER (dev-commands extension) re-shows the tester-notes overlay on
// demand — verifies the command is recognized and dispatches a `devTester`
// action. main.dart's `_TesterOverlayGateState` (which listens for
// `HaLoServices.devTesterTrigger` and force-shows the overlay) is a private
// class reachable only through the full app tree, so that half of the
// wiring is verified manually rather than here — same split as
// devsplash_command_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

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

  group('DEVTESTER command interpretation (real dev-commands extension)', () {
    test('"DEVTESTER" (any case) dispatches a devTester action', () async {
      for (final input in ['DEVTESTER', 'devtester', 'DevTester']) {
        final result = await interpret(input);
        expect(result, isNotNull, reason: 'for input "$input"');
        final commands = (result!['commands'] as List).cast<Map>();
        expect(commands.single['devTester'], {}, reason: 'for input "$input"');
      }
    });

    test('unrelated input does not match', () async {
      expect(await interpret('DEVTESTERY'), isNull);
      expect(await interpret('TESTER'), isNull);
    });
  });
}
