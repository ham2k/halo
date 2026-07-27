// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// getAccounts() fans out to the `account` hooks, and that fan-out can fail for
// reasons that have nothing to do with the user's accounts: the runtime isn't
// up yet, it died and is restarting, or one hook eats the 2s budget. It used to
// answer every one of those with an empty list — indistinguishable from "asked,
// and no extension declares an account".
//
// An extension settings panel caches the answer (_accountsCache), so a single
// failed fan-out latched "there are no accounts" for the rest of that panel's
// life: every later tap on an account field silently did nothing, and the only
// thing that clears the cache is a dialog saving — a dialog that can no longer
// open. The boot deadlock in #402 made that fire on every single launch; it's
// fixed, but the failure modes it stood for are not going away.

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
import 'package:ham2k_logger/views/settings_view.dart';

/// One extension with a settings panel whose only field is an `account`
/// reference, plus the matching `account` hook — with a switch that makes the
/// account fan-out fail the way a dead or busy runtime does, while the panel
/// itself keeps working.
class _FlakyAccountHost implements ExtensionHost {
  bool accountsFail = true;

  /// Stands in for anything about the account that a runtime restart can
  /// change — the field list here, an account appearing or disappearing in
  /// the real thing.
  String accountFieldLabel = 'My Account Username';

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (category == 'settingsPanel' && key == 'myext' && method == 'getDefinition') {
      return {
        'title': 'My Extension',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'account',
            'key': 'account',
            'label': 'My Account',
            'account': {'key': 'myext'},
          },
        ],
      };
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
          'key': 'myext',
          'ok': true,
          'value': {
            'panelKey': 'myext',
            'hookKey': 'myext',
            'extensionKey': 'myext',
            'title': 'My Extension',
            'kind': 'dynamic',
            'order': 50,
          },
        },
      ];
    }
    if (category == 'account' && method == 'getDefinition') {
      if (accountsFail) throw Exception('runtime is not answering');
      return [
        {
          'key': 'myext',
          'ok': true,
          'value': {
            'key': 'myext',
            'kvKey': 'myext',
            'label': 'My Account',
            'fields': [
              {'key': 'username', 'type': 'text', 'label': accountFieldLabel},
            ],
          },
        },
      ];
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHostService extends ExtensionService {
  final _FlakyAccountHost mockHost;
  _MockHostService(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}

  // Secure storage isn't mocked in widget tests, and this account is never
  // connected here — the field renders "Not Connected" either way.
  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Opens the extension's own settings panel — the same
  /// _ExtensionSettingsPanel All Settings embeds, minus the scrolling — and
  /// leaves it showing its single account field.
  Future<({_FlakyAccountHost host, HaLoServices services})> openPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final host = _FlakyAccountHost();
    final services = HaLoServices(db, settings, extensions: _MockHostService(host)..settings = settings);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Extension'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextButton, 'Connect'),
      findsOneWidget,
      reason: "the extension's account field did not render",
    );
    return (host: host, services: services);
  }

  test('getAccounts answers null, not an empty list, when the extensions cannot be asked', () async {
    // A never-started service has no runtime to ask. "No runtime" and "no
    // accounts declared" have to stay distinguishable, or every caller that
    // caches or reports on the answer gets it wrong in the same direction.
    expect(
      await ExtensionService().getAccounts(),
      isNull,
      reason: 'a service with no runtime reported a definitive "no accounts declared"',
    );
  });

  testWidgets('an account field still opens its dialog after a failed account lookup', (tester) async {
    final (:host, :services) = await openPanel(tester);
    final connect = find.widgetWithText(TextButton, 'Connect');

    // First tap, while the fan-out is failing: no dialog, but the press must
    // not look ignored — a Connect button that does nothing at all is
    // indistinguishable from a broken one.
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.text('My Account Username'), findsNothing);
    expect(
      services.statusBar.itemForKey('accounts:lookup')?.text,
      t.settings.accounts.lookupFailed,
      reason: 'the account lookup failed with nothing said to the user',
    );

    // The runtime recovers — a restart, or the slow hook answering this time.
    host.accountsFail = false;
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(
      find.text('My Account Username'),
      findsOneWidget,
      reason: 'the panel cached the failed lookup as "no such account", so the '
          'account field is dead for the rest of this panel\'s life',
    );
  });

  testWidgets('a runtime restart drops the cached accounts', (tester) async {
    final (:host, :services) = await openPanel(tester);
    final connect = find.widgetWithText(TextButton, 'Connect');
    host.accountsFail = false;

    // Fill the cache from the current generation.
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.text('My Account Username'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    // A restart (crash recovery, or an extension being enabled or disabled)
    // replaces the runtime, and with it what the accounts look like — the
    // cache belongs to the generation it was filled from.
    host.accountFieldLabel = 'My Account Passphrase';
    services.extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();

    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(
      find.text('My Account Passphrase'),
      findsOneWidget,
      reason: 'the dialog was built from accounts cached before the restart, '
          'so it describes a runtime that no longer exists',
    );
  });
}
