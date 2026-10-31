// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVFYIALERT, DEVFYIWARN and DEVFYIINFO post a message of that category to
// the FYI area (docs/design/logging-fields.md § The FYI area). The command
// is the real dev-commands extension; the post is the app's.

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/fyi_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;

  setUpAll(() async {
    extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    await extensions.start();
  });

  Future<Map<String, dynamic>> interpret(String input) async {
    final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
    return (entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> actionOf(Map<String, dynamic> interpretation) =>
      ((interpretation['commands'] as List).single as Map).cast<String, dynamic>()['devFyi'] as Map<String, dynamic>;

  test('each command (any case) dispatches a devFyi action of its own category, with a sample text', () async {
    for (final (input, category) in [('DEVFYIALERT', 'alert'), ('devfyiwarn', 'warning'), ('DevFyiInfo', 'info')]) {
      final action = actionOf(await interpret(input));
      expect(action['category'], category, reason: 'for input "$input"');
      expect(action['text'], isNotEmpty, reason: 'bare "$input" has something to show');
      expect(action['icon'], isNotEmpty, reason: 'the area needs an icon to fold to');
    }
  });

  test('the text after the command is the message, spaces and case kept', () async {
    // Without `mixedCase` the call field uppercases and strips the text the
    // operator typed, and a message exists to be read as written.
    final interpretation = await interpret('DEVFYIWARN Storm **12 mi** away');
    expect(interpretation['mixedCase'], isTrue);
    expect(actionOf(interpretation)['text'], 'Storm **12 mi** away');
  });

  test('a ! on the command posts at high priority, the plain one at none in particular', () async {
    // The pill is the one thing priority changes on the line, and the one
    // thing a tester cannot otherwise provoke from the call field.
    expect(actionOf(await interpret('DEVFYIALERT!'))['priority'], 'high');
    expect(actionOf(await interpret('DEVFYIALERT! Storm'))['text'], 'Storm');
    expect(actionOf(await interpret('DEVFYIALERT')).containsKey('priority'), isFalse);
  });

  test('two posts carry different keys, so they stand side by side', () async {
    // One fixed key would make the second post replace the first, and what
    // the command exists to show is the line SHARED.
    final first = actionOf(await interpret('DEVFYIALERT'));
    final second = actionOf(await interpret('DEVFYIALERT'));
    expect(first['key'], isNot(second['key']));
  });

  test('the action posts the message to the FYI area, for both radios', () async {
    final HaLoHarness(:services) = await makeHaLoServices();

    await services.handleCommandAction('devFyi', {'key': 'one', 'category': 'alert', 'priority': 'high', 'icon': 'alert-octagon', 'text': 'Sample **alert**'});
    await services.handleCommandAction('devFyi', {'key': 'two', 'category': 'warning', 'icon': 'alert', 'text': 'Sample warning'});

    for (final radio in ['A', 'B']) {
      final messages = services.fyi.messagesFor(radio);
      expect(messages.map((m) => m.category), [FyiCategory.alert, FyiCategory.warning], reason: 'in set $radio');
      expect(messages.first.text, 'Sample **alert**');
      expect(messages.first.priority, FyiPriority.high);
    }
  });
}
