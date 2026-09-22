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

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

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

/// The contest, as this view reaches it: the setup control it offers — which
/// grows a field once the operation carries the contest's ref — and the label
/// its decorateRef hook gives that ref.
class _ContestExtensions extends ExtensionServiceWithFakeHost {
  _ContestExtensions()
    : super(
        FakeExtensionHost({
          // Stands in for simple-contest's own decorateRef: label the ref with
          // the contest identifier so the Activities row has something to show.
          'ref:simple-contest:null:decorateRef': (Object? args) {
            final ref = ((args as Map)['ref'] as Map).cast<String, dynamic>();
            final id = ref['contestIdentifier'] as String?;
            return {...ref, if (id != null && id.isNotEmpty) 'shortLabel': id};
          },
        }),
      );

  /// A field the control only offers once the operation carries the ref. Stands
  /// in for the State Parks setup, which asks Ohio for the park it is in, a
  /// power class and an entry category — and asks an operation with no event
  /// chosen for none of them.
  static const _refDependentField = {'type': 'field', 'fieldType': 'text', 'key': 'mode', 'label': 'Mode'};

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async {
    final refs = (operationData['refs'] as List?)?.cast<Map>() ?? const <Map>[];
    final control = Map<String, dynamic>.from(_setupControl);
    if (refs.any((ref) => ref['type'] == 'simple-contest')) {
      final input = Map<String, dynamic>.from(control['input'] as Map);
      final form = Map<String, dynamic>.from(input['form'] as Map);
      form['elements'] = [...form['elements'] as List, _refDependentField];
      input['form'] = form;
      control['input'] = input;
    }
    return (controls: [control], loadFailed: false);
  }
}

Future<(HaLoServices, Operation)> _setUp(List<Map<String, dynamic>> refs) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _ContestExtensions()..settings = settings;
  return (HaLoServices(db, settings, extensions: extensions), Operation(uuid: 'op-1', data: {'refs': refs}));
}

Future<void> _pumpPane(WidgetTester tester, HaLoServices services, Operation operation, {ValueChanged<Operation>? onChanged}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(services: services, operation: operation, onOperationChanged: onChanged),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an existing contest ref opens its setup form pre-filled, and saves back onto the ref', (tester) async {
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

  testWidgets('adding the ref rebuilds the controls, so its own form is complete right away', (tester) async {
    // A setup form can only ask what the ref it configures makes sense of: the
    // State Parks form asks Ohio for the park it is in, a power class and an
    // entry category, and an operation with no event chosen for none of them.
    // The descriptors were built once when the panel opened, so the form an
    // operator got straight after adding an event was the empty version, and
    // stayed that way until they closed the panel and came back — with no way to
    // tell that the fields they never saw existed.
    final (services, operation) = await _setUp([]);

    Operation? saved;
    await _pumpPane(tester, services, operation, onChanged: (op) => saved = op);

    // Adding it from the activity-type list, which is where an operation with no
    // contest ref yet starts.
    await tester.tap(find.text('Contest Setup').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contest'), 'CQ-WW-SSB');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect((saved ?? operation).refs.single['contestIdentifier'], 'CQ-WW-SSB');

    // Reopening it: the field that only exists once the ref does is there, with
    // no trip out of the panel in between.
    await tester.tap(find.text('CQ-WW-SSB'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Mode'), findsOneWidget, reason: 'the form was rebuilt against the ref that now exists');
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
