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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/settings/settings_target_dialog.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> _services(Map<String, dynamic> mockHookResults) =>
    _servicesWithExtensions(ExtensionServiceWithFakeHost(FakeExtensionHost(mockHookResults)));

Future<HaLoServices> _servicesWithExtensions(ExtensionService extensions) async =>
    (await makeHaLoServices(extensions: extensions)).services;

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
    await tester.pumpAndSettle();
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
    // no local Dart storage to assert against (FakeExtensionHost.invokeHook
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
    await tester.pumpAndSettle();
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
    // The scroll ensureVisible starts needs a frame before a tap can be
    // aimed: in a sliver viewport the rows move on the NEXT layout, and a
    // tap placed from the old one lands on whatever was there before.
    await tester.pumpAndSettle();
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
    // The scroll ensureVisible starts needs a frame before a tap can be
    // aimed: in a sliver viewport the rows move on the NEXT layout, and a
    // tap placed from the old one lands on whatever was there before.
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.text('Cache cleared'),
      findsOneWidget,
      reason: 'the result banner proves the tap actually reached runSettingsAction, not a dead button',
    );
  });

  testWidgets("an action's state is scoped to its own panel — no other panel's or core's keys leak in", (tester) async {
    // Records the `state` the action call actually received, to pin the
    // cross-panel scoping fix above.
    Map<String, dynamic>? capturedState;
    final services = await _servicesWithExtensions(ExtensionServiceWithFakeHost(FakeExtensionHost({
      'settingsPanel:*:getPanels': [
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
      ],
      'settingsPanel:panelA:getDefinition': {
        'title': 'Panel A',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'flagA', 'label': 'Flag A', 'icon': 'flag', 'value': false, 'target': 'logging'},
        ],
      },
      'settingsPanel:panelB:getDefinition': {
        'title': 'Panel B',
        'elements': [
          {'type': 'field', 'fieldType': 'checkbox', 'key': 'flagB', 'label': 'Flag B', 'icon': 'flag', 'value': false, 'target': 'logging'},
          {'type': 'action', 'key': 'clearCache', 'label': 'Clear Cache', 'method': 'clearCache', 'target': 'logging'},
        ],
      },
      'settingsPanel:panelB:clearCache': (Object? args) {
        capturedState = (args as Map)['state'] as Map<String, dynamic>;
        return 'cleared';
      },
    })));

    await _openDialog(tester, services);
    // Toggle panelA's own field so the dialog's combined _values map holds
    // more than one panel's worth of (namespaced) keys by the time the
    // action fires — the scenario a naive "pass state straight through"
    // implementation would get wrong.
    final toggleA = find.descendant(of: find.widgetWithText(ListTile, 'Flag A'), matching: find.byType(Switch));
    await tester.ensureVisible(toggleA);
    // The scroll ensureVisible starts needs a frame before a tap can be
    // aimed: in a sliver viewport the rows move on the NEXT layout, and a
    // tap placed from the old one lands on whatever was there before.
    await tester.pumpAndSettle();
    await tester.tap(toggleA);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear Cache'));
    await tester.pumpAndSettle();

    expect(
      capturedState,
      {'flagB': false},
      reason: "panelB's action must see its own field bare-keyed and nothing else — not panelA's namespaced "
          'key, not a missing/renamed flagB',
    );
  });

  testWidgets('a fieldType: "account" extension element is picked up, not filtered out', (tester) async {
    final mockHost = FakeExtensionHost({
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
    final mockHost = FakeExtensionHost({
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
    // The scroll ensureVisible starts needs a frame before a tap can be
    // aimed: in a sliver viewport the rows move on the NEXT layout, and a
    // tap placed from the old one lands on whatever was there before.
    await tester.pumpAndSettle();
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

  testWidgets('HALO-83: a core text setting renders in the dialog and commits when its editor closes', (tester) async {
    // The three default-report fields are the first `text` fields any core
    // settings group declares, and a core group's text commit runs through
    // FormRenderer's interaction path — not the switch path every existing
    // core field uses. A field that renders but never saves looks identical
    // in the dialog, so this drives the whole round trip rather than the
    // element map.
    final services = await _services(const {});
    await _openDialog(tester, services, target: 'logging-extended');

    // The row states the setting and its current value; there is nothing to
    // type into until it is opened.
    final row = find.text(t.settings.logging.defaultReportCW.title);
    expect(row, findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '599'), findsNothing);

    await tester.ensureVisible(row);
    // The scroll ensureVisible starts needs a frame before a tap can be
    // aimed: in a sliver viewport the rows move on the NEXT layout, and a
    // tap placed from the old one lands on whatever was there before.
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // Located by its hint, not its label: the hint is what makes an empty
    // field read as "599 unless you say otherwise" instead of as a missing
    // setting, so it is worth matching on.
    final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '599');
    expect(field, findsOneWidget);
    await tester.enterText(field, '5nn');

    // Closing is what commits — the editor edits a copy, so a test that only
    // types proves nothing.
    await tester.tap(find.text(t.common.done).last);
    await tester.pumpAndSettle();

    expect(services.settings.defaultReportCW, '5NN');
  });

  group('HALO-151: showSettingsForKeys', () {
    Future<void> openByKeys(WidgetTester tester, HaLoServices services, List<String> keys) async {
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSettingsForKeys(context, services: services, keys: keys, title: 'Pick one'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows exactly the named settings, whatever target they carry', (tester) async {
      // The whole point of selecting by key: SET can name any setting at all,
      // including ones no target-scoped modal was built to show. Picking a
      // setting whose target is 'logging-extended' proves the dialog isn't
      // quietly still filtering by target.
      final services = await _services(const {});
      await openByKeys(tester, services, ['showGridField']);

      expect(find.text(t.operation.menu.showGridField), findsOneWidget);
      expect(find.text(t.operation.menu.showRstFields), findsNothing,
          reason: 'a sibling in the same group must not come along — the command named one setting');
    });

    testWidgets('the named setting commits through its real path', (tester) async {
      // A dialog that displays the setting but writes nowhere looks identical
      // on screen, so this drives the toggle rather than asserting the row.
      final services = await _services(const {});
      expect(services.settings.showGridField, isFalse);

      await openByKeys(tester, services, ['showGridField']);
      final toggle = find.descendant(
        of: find.widgetWithText(ListTile, t.operation.menu.showGridField),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      // The scroll ensureVisible starts needs a frame before a tap can be
      // aimed: in a sliver viewport the rows move on the NEXT layout, and a
      // tap placed from the old one lands on whatever was there before.
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(services.settings.showGridField, isTrue);
    });

    testWidgets('several keys list together, for a query that named more than one', (tester) async {
      final services = await _services(const {});
      await openByKeys(tester, services, ['showGridField', 'showStateField']);

      expect(find.text(t.operation.menu.showGridField), findsOneWidget);
      expect(find.text(t.operation.menu.showStateField), findsOneWidget);
    });

    testWidgets('rows follow the order the keys were given, not the settings screen order', (tester) async {
      // Commands pass their matches best-first, and the preview line names
      // that first one. Falling back to the scan's own order would put the
      // setting the operator was just told about somewhere down the list.
      //
      // These two are declared showStateField-then-showGridField by
      // LoggingSettingsGroup, so asking for the reverse proves the order came
      // from the caller rather than from the scan.
      final services = await _services(const {});
      await openByKeys(tester, services, ['showGridField', 'showStateField']);

      final gridY = tester.getTopLeft(find.text(t.operation.menu.showGridField)).dy;
      final stateY = tester.getTopLeft(find.text(t.operation.menu.showStateField)).dy;
      expect(gridY, lessThan(stateY));
    });

    testWidgets('nothing is held back behind a "show more settings" disclosure', (tester) async {
      // The caller named exactly what it wants shown, so the extended bucket
      // must stay empty — a disclosure that expands to nothing is a dead end.
      final services = await _services(const {});
      await openByKeys(tester, services, ['showGridField']);

      expect(find.text(t.settings.showMoreSettings), findsNothing);
    });
  });
}

class _AccountRoundTripExtensionService extends ExtensionServiceWithFakeHost {
  _AccountRoundTripExtensionService(super.mockHost);

  final Map<String, Map<String, String>> _store = {};

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => _store[kvKey] ?? const {};

  @override
  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    _store[kvKey] = credentials;
  }
}

class _AccountAwareExtensionService extends ExtensionServiceWithFakeHost {
  _AccountAwareExtensionService(super.mockHost);

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => const {};
}

