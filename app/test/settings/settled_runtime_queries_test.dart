// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A query that lands while the extension runtime is booting, or is caught by
// a replacement, answers as if no extension registered anything. Where the
// caller takes that answer as the truth, the operator is told a setting does
// not exist, or that there are no accounts to connect.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/settings/settings_scan.dart';
import 'package:ham2k_logger/views/settings/accounts_panel.dart';

import '../support/halo_test_support.dart';

/// A runtime whose boot or replacement the test finishes by hand: [host] is
/// whatever is up right now, and [start] waits on [boot].
class _ControlledExtensions extends ExtensionService {
  ExtensionHost? current;
  Completer<void> boot = Completer<void>()..complete();

  _ControlledExtensions(this.current);

  @override
  ExtensionHost? get host => current;

  @override
  bool get ready => current != null;

  @override
  Future<void> start() => boot.future;

  // The real read goes to the keychain, which this test has nothing to say
  // about.
  @override
  Future<Map<String, String>?> getAccountCredentials(String kvKey) async => const {};
}

/// Answers the account catalog, or holds it until the test releases it.
class _AccountsHost extends FakeExtensionHost {
  final String label;
  Completer<List<Map<String, dynamic>>>? held;

  _AccountsHost(this.label);

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) {
    if (category != 'account' || method != 'getDefinition') return Future.value(const []);
    final answer = [
      {
        'key': 'acct',
        'ok': true,
        'value': {'key': 'acct', 'kvKey': 'acct', 'label': label, 'fields': const []},
      },
    ];
    return held?.future ?? Future.value(answer);
  }
}

/// One extension settings panel with one field, `ext.example`.
FakeExtensionHost _settingsHost() => FakeExtensionHost({
  'settingsPanel:*:getPanels': [
    {
      'key': 'ext',
      'ok': true,
      'value': {'panelKey': 'ext', 'hookKey': 'ext', 'extensionKey': 'ext', 'title': 'Extension', 'kind': 'dynamic', 'order': 50},
    },
  ],
  'settingsPanel:ext:getDefinition': {
    'elements': [
      {'type': 'field', 'fieldType': 'text', 'key': 'example', 'label': 'Example', 'value': ''},
    ],
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a settings scan made while the runtime boots includes the extensions\' settings', () async {
    // SET right after launch: the scan backs the command's lookup, and a
    // setting missing from it is refused as unknown.
    final extensions = _ControlledExtensions(null)..boot = Completer<void>();
    final harness = await makeHaLoServices(extensions: extensions);

    final scan = scanSettings(harness.services);
    await Future<void>.delayed(Duration.zero);
    extensions.current = _settingsHost();
    extensions.boot.complete();

    expect((await scan).map((setting) => setting.key), contains('ext.example'));
  });

  testWidgets('the accounts list a replacement interrupts comes from the runtime that replaced it', (tester) async {
    final dying = _AccountsHost('Old Account')..held = Completer();
    final extensions = _ControlledExtensions(dying);
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: CustomScrollView(slivers: [AccountsPanel(services: services)]),
      ),
      extensions: extensions,
    );

    // The replacement disposes the old host, which fails the pending call.
    extensions.current = _AccountsHost('New Account');
    dying.held!.completeError(ExtensionHostException('extension host disposed'));
    await tester.pumpAndSettle();

    expect(find.text('New Account'), findsOneWidget);
  });

  test('with a runtime up, a scan answers without waiting for its boot to finish', () async {
    // SET runs the scan from inside a command hook, which a boot still in its
    // activation wait is already serving — and whose preview gives up after
    // two seconds, reading as no setting matching at all.
    final extensions = _ControlledExtensions(_settingsHost())..boot = Completer<void>();
    final harness = await makeHaLoServices(extensions: extensions);

    final scanned = await scanSettings(harness.services).timeout(const Duration(seconds: 5));

    expect(scanned.map((setting) => setting.key), contains('ext.example'));
  });
}
