// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVPOPUP (dev-commands extension) reopens the app in a standalone popup
// window — verifies the command is recognized and dispatches a `devPopup`
// action. The web-only `openPopupWindow` call this triggers (main.dart's
// `devPopup` case) isn't reachable from the native test suite, same split as
// devtester_command_test.dart.

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

  group('DEVPOPUP command interpretation (real dev-commands extension)', () {
    test('"DEVPOPUP" (any case) dispatches a devPopup action', () async {
      for (final input in ['DEVPOPUP', 'devpopup', 'DevPopup']) {
        final result = await interpret(input);
        expect(result, isNotNull, reason: 'for input "$input"');
        final commands = (result!['commands'] as List).cast<Map>();
        expect(commands.single['devPopup'], {}, reason: 'for input "$input"');
      }
    });

    test('unrelated input does not match', () async {
      expect(await interpret('DEVPOPUPX'), isNull);
      expect(await interpret('POPUP'), isNull);
    });
  });
}
