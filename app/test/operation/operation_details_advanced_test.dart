// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Advanced section of the Operation Details dialog: the operating
// position, Assistance and Self-spotting. The section folds away what most
// operations never change, so it must open on its own whenever something in
// it is NOT the default — a setting that changes how the operation behaves
// can never sit out of sight. The two switches are the operation's SHARED
// data, absent meaning on, and an untouched Save must not turn that absence
// into a stored value. A ref whose rules forbid one forces it off and says
// whose rules those are, without overwriting the operator's own choice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late OperationsRepository operations;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    operations = services.operations;
    operation = await operations.create(stationCall: 'KI2D');
  });

  Future<void> openDialog(WidgetTester tester) async {
    var opened = false;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              if (!opened) {
                opened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await editOperationDetails(context, services, operation);
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setData(Map<String, dynamic> data) async {
    await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, ...data}));
    operation = (await operations.get(operation.uuid))!;
  }

  Future<void> tapAndSave(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
  }

  Finder assistanceSwitch() => find.widgetWithText(SwitchListTile, t.dialogs.assistance);
  Finder selfSpottingSwitch() => find.widgetWithText(SwitchListTile, t.dialogs.selfSpotting);

  /// Whether [finder] can be reached once scrolled to. A folded section stays
  /// MOUNTED, so finding the widget at all says nothing about whether it is
  /// open; only a hit test does.
  Future<bool> reachable(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder.hitTestable().evaluate().isNotEmpty;
  }

  testWidgets('starts folded when everything in it is at its default', (tester) async {
    await openDialog(tester);
    expect(find.text(t.dialogs.advanced), findsOneWidget);
    expect(await reachable(tester, assistanceSwitch()), isFalse);

    await tester.ensureVisible(find.text(t.dialogs.advanced));
    await tester.tap(find.text(t.dialogs.advanced));
    await tester.pumpAndSettle();
    expect(await reachable(tester, assistanceSwitch()), isTrue);
    expect(await reachable(tester, find.widgetWithText(TextField, t.dialogs.operatingPosition)), isTrue);
  });

  for (final (label, setup) in <(String, Future<void> Function())>[
    ('a position is set', () => operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'})),
    ('assistance is off', () => setData({'assistance': false})),
    ('self-spotting is off', () => setData({'selfSpotting': false})),
    (
      'a ref forces a switch off',
      () => setData({
        'refs': [
          {'type': 'cqww', 'assistance': false},
        ],
      }),
    ),
  ]) {
    testWidgets('opens on its own when $label', (tester) async {
      await setup();
      operation = (await operations.get(operation.uuid))!;
      await openDialog(tester);
      expect(await reachable(tester, assistanceSwitch()), isTrue);
    });
  }

  testWidgets('an untouched Save stores neither switch', (tester) async {
    // A stored `true` would be indistinguishable today, but it pins every old
    // operation to a value nobody chose.
    await openDialog(tester);
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    final stored = (await operations.get(operation.uuid))!;
    expect(stored.data.containsKey('assistance'), isFalse);
    expect(stored.data.containsKey('selfSpotting'), isFalse);
    expect(stored.assistance, isTrue);
    expect(stored.selfSpotting, isTrue);
  });

  testWidgets('turning Assistance off stores it on the shared data', (tester) async {
    // Shared, not device-local: an operation is assisted or not as a whole,
    // whichever device the operator is logging from.
    await openDialog(tester);
    await tester.ensureVisible(find.text(t.dialogs.advanced));
    await tester.tap(find.text(t.dialogs.advanced));
    await tester.pumpAndSettle();
    await tapAndSave(tester, assistanceSwitch());

    final stored = (await operations.get(operation.uuid))!;
    expect(stored.data['assistance'], isFalse);
    expect(stored.localData.containsKey('assistance'), isFalse);
    expect(stored.selfSpotting, isTrue, reason: 'the other switch is untouched');
  });

  testWidgets('turning Self-spotting back on stores it on', (tester) async {
    // Once a value is stored, the change has to reach it — skipping the write
    // because `true` is the default would leave the stored `false` in place.
    await setData({'selfSpotting': false});
    await openDialog(tester);
    await tapAndSave(tester, selfSpottingSwitch());

    expect((await operations.get(operation.uuid))!.data['selfSpotting'], isTrue);
  });

  group('forced off by a ref', () {
    setUp(() {
      services.extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'cqww', file: 'cqww.js', core: false, name: 'CQ World Wide DX Contest', shortName: 'CQ WW', hooks: ['ref:cqww']),
        ExtensionInfo(key: 'nyqp', file: 'nyqp.js', core: false, name: 'New York QSO Party', shortName: 'NYQP', hooks: ['ref:qp/ny']),
      ]);
    });

    testWidgets('shows off, cannot be changed, and names the rules', (tester) async {
      await setData({
        'refs': [
          {'type': 'cqww', 'assistance': false},
        ],
      });
      await openDialog(tester);

      final tile = tester.widget<SwitchListTile>(assistanceSwitch());
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull, reason: 'the operator cannot turn on what the rules forbid');
      expect(find.text(t.dialogs.disabledByRules(rules: 'CQ WW')), findsOneWidget);
      expect(find.text(t.dialogs.assistanceDescription), findsNothing);
      expect(tester.widget<SwitchListTile>(selfSpottingSwitch()).onChanged, isNotNull, reason: 'the ref says nothing about self-spotting');
    });

    testWidgets('names the claiming extension, down to a qualified claim', (tester) async {
      // The NYQP ref is the older `qp`/`NY` pair, claimed by `ref:qp/ny`; the
      // bare type would read "QP rules", which no operator knows by that name.
      await setData({
        'refs': [
          {'type': 'qp', 'ref': 'NY', 'selfSpotting': false},
        ],
      });
      await openDialog(tester);
      expect(find.text(t.dialogs.disabledByRules(rules: 'NYQP')), findsOneWidget);
    });

    testWidgets('names every activity whose rules apply, once each', (tester) async {
      await setData({
        'refs': [
          {'type': 'cqww', 'assistance': false},
          {'type': 'qp', 'ref': 'NY', 'assistance': false},
          {'type': 'qp', 'ref': 'NY', 'assistance': false},
        ],
      });
      await openDialog(tester);
      expect(find.text(t.dialogs.disabledByRules(rules: 'CQ WW, NYQP')), findsOneWidget);
    });

    testWidgets("saving keeps the operator's own choice for when the ref is gone", (tester) async {
      // Writing the forced `false` would leave assistance off after the
      // contest ref is removed, on an operation the operator never turned off.
      await setData({
        'refs': [
          {'type': 'cqww', 'assistance': false},
        ],
      });
      await openDialog(tester);
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();

      final stored = (await operations.get(operation.uuid))!;
      expect(stored.data.containsKey('assistance'), isFalse);
      expect(stored.assistance, isFalse, reason: 'the ref still forbids it');
      expect(Operation(uuid: stored.uuid, data: {...stored.data, 'refs': const []}).assistance, isTrue);
    });

    // Lookup All QSOs on such an operation asks first: the operator is about
    // to break the rules this dialog names, and Cancel must mean no lookup.
    for (final (button, expected) in [('Look Up Online', true), ('Cancel', false)]) {
      testWidgets('the lookup warning names the rules, and $button answers $expected', (tester) async {
        await setData({
          'refs': [
            {'type': 'cqww', 'assistance': false},
          ],
        });
        bool? answer;
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Builder(
                builder: (context) =>
                    TextButton(onPressed: () async => answer = await confirmLookupDespiteAssistance(context, services, operation), child: const Text('open')),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text(t.dialogs.lookupDespiteAssistance.bodyRules(rules: 'CQ WW')), findsOneWidget);
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(answer, expected);
      });
    }
  });
}
