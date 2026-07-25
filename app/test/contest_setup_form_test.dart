// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest's setup (its identifier, the exchange we send) is configured
// through an `input.kind == 'form'` operation control rendered with the shared
// FormRenderer, and the values live on the operation's contest ref — see
// docs/design/contests.md §5.4. These tests pin that round trip, because a
// contest whose setup doesn't persist exports an unsubmittable log.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

/// One form-kind operation control, shaped exactly as simple-contest returns it.
const _setupControl = {
  'key': 'simple-contest/setup',
  'label': 'Contest Setup',
  'icon': 'flag-checkered',
  'input': {
    'kind': 'form',
    'refType': 'simple-contest',
    'form': {
      'title': 'Contest Setup',
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'contestIdentifier', 'label': 'Contest'},
        {'type': 'field', 'fieldType': 'text', 'key': 'exchange', 'label': 'Exchange Sent'},
      ],
    },
  },
};

/// The shared MockExtensionHost only overrides the public `host` getter, while
/// control collection reads the private field — so controls would come back
/// empty. Overriding the two methods this view actually calls is both simpler
/// and a tighter statement of what the test depends on.
class _ContestExtensions extends ExtensionServiceWithMockHost {
  _ContestExtensions() : super(const MockExtensionHost({}));

  @override
  Future<List<Map<String, dynamic>>> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      [Map<String, dynamic>.from(_setupControl)];

  /// Stands in for simple-contest's own decorateRef: label the ref with the
  /// contest identifier so the Activities row has something to show.
  @override
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async {
    final id = ref['contestIdentifier'] as String?;
    return {...ref, if (id != null && id.isNotEmpty) 'shortLabel': id};
  }
}

Future<(HaLoServices, Operation)> _setUp(List<Map<String, dynamic>> refs) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _ContestExtensions()..settings = settings;
  return (
    HaLoServices(db, settings, extensions: extensions),
    Operation(uuid: 'op-1', data: {'refs': refs}),
  );
}

Future<void> _pumpPane(WidgetTester tester, HaLoServices services, Operation operation,
    {ValueChanged<Operation>? onChanged}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: OperationSheet(services: services, operation: operation, onOperationChanged: onChanged),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an existing contest ref opens its setup form pre-filled, and saves back onto the ref',
      (tester) async {
    final (services, operation) = await _setUp([
      {'type': 'simple-contest', 'contestIdentifier': 'CQ-WW-SSB', 'exchange': '59 001', 'shortLabel': 'CQ-WW-SSB'},
    ]);

    Operation? saved;
    await _pumpPane(tester, services, operation, onChanged: (op) => saved = op);

    // Tapping the activity row opens the setup form rather than the
    // single-reference-code dialog contests have no use for.
    await tester.tap(find.text('CQ-WW-SSB'));
    await tester.pumpAndSettle();
    expect(find.text('Contest Setup'), findsWidgets);

    // Pre-filled from the ref — the operator edits what's there, and doesn't
    // retype the whole setup to change one field.
    final exchangeField = find.widgetWithText(TextField, 'Exchange Sent');
    expect(exchangeField, findsOneWidget);
    expect(tester.widget<TextField>(exchangeField).controller?.text, '59 001');

    await tester.enterText(exchangeField, '59 002');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final refs = (saved ?? operation).refs;
    expect(refs.length, 1);
    expect(refs.single['type'], 'simple-contest');
    expect(refs.single['exchange'], '59 002');
    // The untouched field survives — a form save must not drop ref data it
    // didn't ask about.
    expect(refs.single['contestIdentifier'], 'CQ-WW-SSB');
  });

  testWidgets('cancelling the setup form leaves the ref untouched', (tester) async {
    final (services, operation) = await _setUp([
      {'type': 'simple-contest', 'contestIdentifier': 'CQ-WW-SSB', 'exchange': '59 001', 'shortLabel': 'CQ-WW-SSB'},
    ]);

    Operation? saved;
    await _pumpPane(tester, services, operation, onChanged: (op) => saved = op);

    await tester.tap(find.text('CQ-WW-SSB'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Exchange Sent'), 'DISCARDED');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect((saved ?? operation).refs.single['exchange'], '59 001');
  });
}
