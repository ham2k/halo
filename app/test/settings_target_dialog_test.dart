// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-59: showSettingsForTarget's extension-panel scan. An extension
// settingsPanel field tagged `target: '<x>'` should appear in the dialog
// alongside core SettingsGroup elements, and commit through the extension
// host (validate/transform/commit) — never SettingsGroup.commit(), which
// doesn't know these fields exist. Two panels sharing a field key must not
// misroute a commit into each other — the reason for the `<panelKey>.`
// namespacing in settings_target_dialog.dart. `type: 'action'` elements and
// `fieldType: 'account'` fields are scanned in too, dispatching through
// runSettingsAction/showAccountDialogByKey the same as a whole panel would —
// and since one FormRenderer here can hold several panels' elements at once
// (unlike a whole-panel form), every extension-facing call must receive
// `state` scoped to just that element's own panel, not this dialog's
// combined, cross-panel values.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/settings_target_dialog.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> _services(Map<String, dynamic> mockHookResults) =>
    _servicesWithExtensions(ExtensionServiceWithMockHost(MockExtensionHost(mockHookResults)));

Future<HaLoServices> _servicesWithExtensions(ExtensionService extensions) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  extensions.settings = settings;
  final db = HaLoDatabase(NativeDatabase.memory());
  return HaLoServices(db, settings, extensions: extensions);
}

Map<String, dynamic> _panelEntry({required String panelKey, required String kind}) => {
  'key': panelKey,
  'ok': true,
  'value': {'panelKey': panelKey, 'hookKey': panelKey, 'extensionKey': panelKey, 'title': panelKey, 'kind': kind, 'order': 0},
};

Future<void> _openDialog(WidgetTester tester, HaLoServices services, {String target = 'logging'}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      // A Scaffold ancestor, not just the bare button: an action element's
      // result banner goes through ScaffoldMessenger.showSnackBar, which
      // asserts there's a Scaffold to present it on.
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSettingsForTarget(context, services: services, target: target, title: 'Test Settings'),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a Tier 1 extension field tagged target commits to Dart-owned storage, not through a SettingsGroup', (tester) async {
    final services = await _services({
      'settingsPanel:*:getPanels': [_panelEntry(panelKey: 'myext', kind: 'simple')],
      'settingsPanel:myext:getDefinition': {
        'title': 'My Extension',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'checkbox',
            'key': 'sendSpots',
            'label': 'Send Spots',
            'icon': 'radio',
            'value': false,
            'target': 'logging',
          },
        ],
      },
    });

    await _openDialog(tester, services);
    expect(find.text('Send Spots'), findsOneWidget, reason: 'the extension field is included in the scan');

    final toggle = find.descendant(of: find.widgetWithText(ListTile, 'Send Spots'), matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(
      services.settings.prefs.getString('settingsPanel.myext.sendSpots'),
      'true',
      reason: 'Tier 1 commits go straight to Dart-owned kv storage, keyed <panelKey>.<fieldKey> — never SettingsGroup.commit()',
    );
  });

  testWidgets('a Tier 2 extension field appears and commits without crashing', (tester) async {
    // Tier 2's commit forwards to the extension's own onChangeField — there's
    // no local Dart storage to assert against (MockExtensionHost.invokeHook
    // just echoes back a canned response), so this pins "reaches the target
    // dialog, edits without throwing, dialog stays usable" rather than a
    // specific persisted value; the Tier 1 test above is what actually pins
    // the routing-goes-through-the-extension-host guarantee.
    final services = await _services({
      'settingsPanel:*:getPanels': [_panelEntry(panelKey: 'dynext', kind: 'dynamic')],
      'settingsPanel:dynext:getDefinition': {
        'title': 'Dynamic Extension',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'checkbox',
            'key': 'liveFlag',
            'label': 'Live Flag',
            'icon': 'flag',
            'value': false,
            'target': 'logging',
          },
        ],
      },
    });

    await _openDialog(tester, services);
    final toggle = find.descendant(of: find.widgetWithText(ListTile, 'Live Flag'), matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Live Flag'), findsOneWidget, reason: 'the dialog is still intact after a Tier 2 commit round trip');
  });

  testWidgets('two panels declaring the same field key stay independent — no cross-panel misrouting', (tester) async {
    final services = await _services({
      'settingsPanel:*:getPanels': [
        _panelEntry(panelKey: 'panelA', kind: 'simple'),
        _panelEntry(panelKey: 'panelB', kind: 'simple'),
      ],
      'settingsPanel:panelA:getDefinition': {
        'title': 'Panel A',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'apiKey', 'label': 'Panel A Flag', 'icon': 'key', 'value': false, 'target': 'logging'},
        ],
      },
      'settingsPanel:panelB:getDefinition': {
        'title': 'Panel B',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'apiKey', 'label': 'Panel B Flag', 'icon': 'key', 'value': false, 'target': 'logging'},
        ],
      },
    });

    await _openDialog(tester, services);
    // Both rows present — a naive bare-fieldKey map would have let the
    // second panel scanned silently clobber the routing for the first.
    expect(find.text('Panel A Flag'), findsOneWidget);
    expect(find.text('Panel B Flag'), findsOneWidget);

    final toggleA = find.descendant(of: find.widgetWithText(ListTile, 'Panel A Flag'), matching: find.byType(Switch));
    await tester.ensureVisible(toggleA);
    await tester.tap(toggleA);
    await tester.pumpAndSettle();

    expect(services.settings.prefs.getString('settingsPanel.panelA.apiKey'), 'true');
    expect(
      services.settings.prefs.getString('settingsPanel.panelB.apiKey'),
      isNull,
      reason: 'editing panelA\'s "apiKey" must not touch panelB\'s field of the same name',
    );
  });

  testWidgets('a type: "action" extension element is picked up and dispatches through runSettingsAction', (tester) async {
    final services = await _services({
      'settingsPanel:*:getPanels': [_panelEntry(panelKey: 'actext', kind: 'simple')],
      'settingsPanel:actext:getDefinition': {
        'title': 'Action Extension',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'shown', 'label': 'Shown Field', 'icon': 'flag', 'value': false, 'target': 'logging'},
          {'type': 'action', 'key': 'clearCache', 'label': 'Clear Cache', 'method': 'clearCache', 'target': 'logging'},
        ],
      },
      'settingsPanel:actext:clearCache': 'Cache cleared',
    });

    await _openDialog(tester, services);
    expect(find.text('Shown Field'), findsOneWidget, reason: 'the panel is genuinely being scanned');
    final button = find.widgetWithText(OutlinedButton, 'Clear Cache');
    expect(button, findsOneWidget, reason: 'action elements now render, routed through their own panel');

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.text('Cache cleared'),
      findsOneWidget,
      reason: 'the result banner proves the tap actually reached runSettingsAction, not a dead button',
    );
  });

  testWidgets("an action's state is scoped to its own panel — no other panel's or core's keys leak in", (tester) async {
    final host = _StateCapturingHost();
    final services = await _servicesWithExtensions(_StateCapturingExtensionService(host));

    await _openDialog(tester, services);
    // Toggle panelA's own field so the dialog's combined _values map holds
    // more than one panel's worth of (namespaced) keys by the time the
    // action fires — the scenario a naive "pass state straight through"
    // implementation would get wrong.
    final toggleA = find.descendant(of: find.widgetWithText(ListTile, 'Flag A'), matching: find.byType(Switch));
    await tester.ensureVisible(toggleA);
    await tester.tap(toggleA);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear Cache'));
    await tester.pumpAndSettle();

    expect(
      host.capturedState,
      {'flagB': false},
      reason: "panelB's action must see its own field bare-keyed and nothing else — not panelA's namespaced "
          'key, not a missing/renamed flagB',
    );
  });

  testWidgets('a fieldType: "account" extension element is picked up, not filtered out', (tester) async {
    final mockHost = MockExtensionHost({
      'settingsPanel:*:getPanels': [_panelEntry(panelKey: 'acctext', kind: 'simple')],
      'settingsPanel:acctext:getDefinition': {
        'title': 'Account Extension',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'account',
            'key': 'qrzStatus',
            'label': 'QRZ.com Account',
            'account': {'key': 'qrz'},
            'target': 'logging',
          },
        ],
      },
    });
    // Secure storage isn't mocked in widget tests (see
    // account_lookup_failure_test.dart) — stub getAccountCredentials
    // directly so the field resolves to "not connected" rather than
    // "unavailable" (whose Connect button FormRenderer disables), which
    // would make this test unable to tell "filtered out" from "included but
    // disabled".
    final services = await _servicesWithExtensions(_AccountAwareExtensionService(mockHost));

    await _openDialog(tester, services);
    expect(find.text('QRZ.com Account'), findsOneWidget, reason: 'the account field is no longer filtered out');
    expect(
      find.widgetWithText(TextButton, 'Connect'),
      findsOneWidget,
      reason: 'and its status resolved cleanly, so the Connect button is enabled rather than dead',
    );
  });

  testWidgets('after Connect closes having saved, the account field refreshes on its own — no separate trigger needed', (tester) async {
    final mockHost = MockExtensionHost({
      'settingsPanel:*:getPanels': [_panelEntry(panelKey: 'acctext', kind: 'simple')],
      'settingsPanel:acctext:getDefinition': {
        'title': 'Account Extension',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'account',
            'key': 'qrzStatus',
            'label': 'QRZ.com Account',
            'account': {'key': 'qrz'},
            'target': 'logging',
          },
        ],
      },
      // getAccounts() (invokeHookAll 'account'/'getDefinition') is a
      // separate mechanism from getSettingsPanelDefinition's own status
      // resolution — showAccountDialogByKey needs this to find the account
      // to open its pane for.
      'account:*:getDefinition': [
        {
          'key': 'acctext',
          'ok': true,
          'value': {
            'key': 'qrz',
            'kvKey': 'qrz',
            'label': 'QRZ.com Account',
            'fields': [
              {'key': 'username', 'type': 'text', 'label': 'Username'},
            ],
          },
        },
      ],
    });
    final extensions = _AccountRoundTripExtensionService(mockHost);
    final services = await _servicesWithExtensions(extensions);

    // showAccountDialogByKey (unlike _ExtensionSettingsPanel's own
    // _manageAccount) opens on the app's root navigator, not this test's
    // local context — needs the same navigatorKey main.dart wires up.
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSettingsForTarget(context, services: services, target: 'logging', title: 'Test Settings'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final connect = find.widgetWithText(TextButton, 'Connect');
    expect(connect, findsOneWidget, reason: 'starts out not connected');
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'KI2D');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextButton, 'Manage'),
      findsOneWidget,
      reason: 'the target dialog reloaded on its own once the account pane closed — Connect became Manage '
          'without any unrelated field edit or restart forcing a refresh',
    );
  });

  testWidgets('HALO-83: a core text setting renders in the dialog and commits on blur', (tester) async {
    // The three default-report fields are the first `text` fields any core
    // settings group declares, and a core group's text commit runs through
    // FormRenderer's blur path — not the switch path every existing core
    // field uses. A field that renders but never saves looks identical in the
    // dialog, so this drives the whole round trip rather than the element map.
    final services = await _services(const {});
    await _openDialog(tester, services, target: 'logging-extended');

    expect(find.text(t.settings.logging.defaultReportCW.title), findsOneWidget);
    // Located by its hint, not its label: the compact row puts the label in a
    // sibling ListTile rather than inside the field's own decoration. The hint
    // is what makes an empty field read as "599 unless you say otherwise"
    // instead of as a missing setting, so it is worth matching on.
    final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '599');
    expect(field, findsOneWidget);

    await tester.ensureVisible(field);
    await tester.enterText(field, '5nn');
    // Blur is what commits — FormRenderer's text fields have no per-keystroke
    // autosave, so a test that only types proves nothing. Moving focus to a
    // neighbouring field is the gesture; tapping a label is not, since a bare
    // Text takes no focus and the edit would still be sitting uncommitted.
    final phoneField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '59');
    await tester.ensureVisible(phoneField);
    await tester.tap(phoneField);
    await tester.pumpAndSettle();

    expect(services.settings.defaultReportCW, '5NN');
  });
}

class _AccountRoundTripExtensionService extends ExtensionServiceWithMockHost {
  _AccountRoundTripExtensionService(super.mockHost);

  final Map<String, Map<String, String>> _store = {};

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => _store[kvKey] ?? const {};

  @override
  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    _store[kvKey] = credentials;
  }
}

class _AccountAwareExtensionService extends ExtensionServiceWithMockHost {
  _AccountAwareExtensionService(super.mockHost);

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => const {};
}

/// A hand-rolled [ExtensionHost] (rather than [MockExtensionHost], whose
/// canned-result map can't see call arguments) that records the `state` an
/// action call actually received, to pin the cross-panel scoping fix above.
class _StateCapturingHost implements ExtensionHost {
  Map<String, dynamic>? capturedState;

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (category == 'settingsPanel' && key == 'panelA' && method == 'getDefinition') {
      return {
        'title': 'Panel A',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'flagA', 'label': 'Flag A', 'icon': 'flag', 'value': false, 'target': 'logging'},
        ],
      };
    }
    if (category == 'settingsPanel' && key == 'panelB' && method == 'getDefinition') {
      return {
        'title': 'Panel B',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'flagB', 'label': 'Flag B', 'icon': 'flag', 'value': false, 'target': 'logging'},
          {'type': 'action', 'key': 'clearCache', 'label': 'Clear Cache', 'method': 'clearCache', 'target': 'logging'},
        ],
      };
    }
    if (category == 'settingsPanel' && key == 'panelB' && method == 'clearCache') {
      capturedState = (args as Map)['state'] as Map<String, dynamic>;
      return 'cleared';
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (category == 'settingsPanel' && method == 'getPanels') {
      return [
        {
          'key': 'panelA',
          'ok': true,
          'value': {'panelKey': 'panelA', 'hookKey': 'panelA', 'extensionKey': 'panelA', 'title': 'Panel A', 'kind': 'simple', 'order': 0},
        },
        {
          'key': 'panelB',
          'ok': true,
          'value': {'panelKey': 'panelB', 'hookKey': 'panelB', 'extensionKey': 'panelB', 'title': 'Panel B', 'kind': 'simple', 'order': 1},
        },
      ];
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StateCapturingExtensionService extends ExtensionService {
  final _StateCapturingHost mockHost;
  _StateCapturingExtensionService(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}
