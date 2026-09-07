// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVONBOARD (dev-commands extension) re-shows the first-run onboarding
// overlay (Issue #43) on demand — verifies the command is recognized and
// dispatches a `devOnboard` action. The gate half of the wiring
// (`_OnboardingGateState` listening for `HaLoServices.devOnboardTrigger`)
// is covered in onboarding_test.dart.

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

  group('DEVONBOARD command interpretation (real dev-commands extension)', () {
    test('"DEVONBOARD" (any case) dispatches a devOnboard action', () async {
      for (final input in ['DEVONBOARD', 'devonboard', 'DevOnboard']) {
        final result = await interpret(input);
        expect(result, isNotNull, reason: 'for input "$input"');
        final commands = (result!['commands'] as List).cast<Map>();
        expect(commands.single['devOnboard'], {}, reason: 'for input "$input"');
      }
    });

    test('unrelated input does not match', () async {
      expect(await interpret('DEVONBOARDING'), isNull);
    });
  });
}
