// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVSPLASH (dev-commands extension) re-shows the startup release-notes
// overlay (Issue #42) on demand — verifies the command is recognized and
// dispatches a `devSplash` action. main.dart's `_ReleaseOverlayGateState`
// (which listens for `HaLoServices.devSplashTrigger` and force-shows the
// overlay) is a private class reachable only through the full app tree, so
// that half of the wiring is verified manually rather than here.

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

  group('DEVSPLASH command interpretation (real dev-commands extension)', () {
    test('"DEVSPLASH" (any case) dispatches a devSplash action', () async {
      for (final input in ['DEVSPLASH', 'devsplash', 'DevSplash']) {
        final result = await interpret(input);
        expect(result, isNotNull, reason: 'for input "$input"');
        final commands = (result!['commands'] as List).cast<Map>();
        expect(commands.single['devSplash'], {}, reason: 'for input "$input"');
      }
    });

    test('unrelated input does not match', () async {
      expect(await interpret('DEVSPLASHY'), isNull);
      expect(await interpret('SPLASH'), isNull);
    });
  });
}
