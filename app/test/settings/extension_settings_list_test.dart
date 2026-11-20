// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dynamic panel's `list` field shows what the panel made of an item it was
// handed — a title named for a value its transform fetched — as soon as the
// item is added. The traps: the form keeps the list the operator edited over
// the one the panel reloads, so without the panel handing it back the new row
// stays untitled until the panel is opened again; a hand-back read before the
// reload the save started has landed is the list from before the save, and
// takes the new row away; and a save the extension refuses must neither seem
// kept nor vanish without a word.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/settings/extension_settings_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A panel whose list is titled by the call its transform fetched. Once
  /// [hold] is set, a definition fetch waits for it.
  ({Map<String, dynamic> hooks, List<Map<String, dynamic>> Function() stored}) panel({Completer<void>? Function()? hold, bool refuse = false}) {
    var stored = <Map<String, dynamic>>[];
    final hooks = <String, dynamic>{
      'settingsPanel:keys:getDefinition': (_) async {
        await hold?.call()?.future;
        return {
          'elements': [
            {
              'type': 'field',
              'fieldType': 'list',
              'key': 'logbooks',
              'label': 'Logbooks',
              'itemLabel': 'logbook',
              'inline': true,
              'itemTitle': r'${title}',
              'value': [
                for (final entry in stored) {...entry, 'title': 'Logbook ${entry['call']}'},
              ],
              'itemFields': [
                {'type': 'field', 'fieldType': 'text', 'key': 'key', 'label': 'Key'},
              ],
            },
          ],
        };
      },
      'settingsPanel:keys:validateField': (_) => null,
      'settingsPanel:keys:transformField': (args) {
        final value = (args as Map)['value'];
        if (args['fieldKey'] != 'logbooks') return value;
        return [
          for (final item in (value as List).cast<Map>()) {'key': item['key'], 'call': 'N0DEV'},
        ];
      },
      'settingsPanel:keys:onChangeField': (args) {
        if (refuse) throw Exception('keychain refused');
        stored = ((args as Map)['value'] as List).cast<Map>().map((item) => item.cast<String, dynamic>()).toList();
        return null;
      },
    };
    return (hooks: hooks, stored: () => stored);
  }

  Future<void> pumpPanel(WidgetTester tester, Map<String, dynamic> hooks) async {
    final services = (await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(hooks)))).services;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ExtensionSettingsPanel(
              services: services,
              descriptor: const {'panelKey': 'keys', 'hookKey': 'keys', 'extensionKey': 'keys', 'title': 'Keys', 'kind': 'dynamic'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addKey(WidgetTester tester, String key) async {
    await tester.tap(find.text(t.formChrome.addItem(label: 'logbook')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
  }

  testWidgets('an added item is titled by what the panel fetched for it, without reopening the panel', (tester) async {
    Completer<void>? gate;
    final keys = panel(hold: () => gate);
    await pumpPanel(tester, keys.hooks);

    gate = Completer<void>();
    await addKey(tester, 'KEY-A');
    expect(keys.stored(), [
      {'key': 'KEY-A', 'call': 'N0DEV'},
    ]);
    // Saved, and the reload the save started still on its way: the row stays
    // as entered rather than the list from before the save coming back.
    expect(find.text(t.formChrome.untitled), findsOneWidget);

    gate.complete();
    gate = null;
    await tester.pumpAndSettle();
    expect(find.text('Logbook N0DEV'), findsOneWidget);
    expect(find.text(t.formChrome.untitled), findsNothing);
  });

  testWidgets('an item the extension would not store stays as entered, saying it was not saved', (tester) async {
    final keys = panel(refuse: true);
    await pumpPanel(tester, keys.hooks);

    await addKey(tester, 'KEY-A');
    expect(keys.stored(), isEmpty);
    expect(find.text(t.formChrome.untitled), findsOneWidget);
    expect(find.text(t.formChrome.notSaved), findsOneWidget);
  });
}
