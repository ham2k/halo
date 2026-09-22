// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A deleted operation is read-only until it is undeleted. The reason is not
// tidiness: saving one re-stamps it, and that stamp is how Undelete finds the
// QSOs app-polo tombstoned with it — so an edit made first strands them for
// good — and a QSO logged into one lands in an operation every other device
// treats as gone. Undelete therefore has to be the one thing on offer, in
// place of Delete and of every way to write.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(HaLoServices, String)> pumpDeletedOperation(WidgetTester tester, {bool firstEverOpen = false}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    // Otherwise the operation sheet opens itself over the header.
    if (!firstEverOpen) await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    await services.operations.softDelete(operation.uuid);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (services, operation.uuid);
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  final toolsButton = find.byIcon(MdiIcons.tools);
  // The first field of the logging panel: the call.
  final callField = find.byType(EditableText).first;
  final notice = find.textContaining('This operation is deleted');

  testWidgets('a deleted operation offers Undelete where Delete and the ways to edit were', (tester) async {
    final (services, uuid) = await pumpDeletedOperation(tester);

    await tester.tap(toolsButton.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Delete Operation'), findsNothing);
    expect(find.text('Operation Details'), findsNothing, reason: 'a save re-stamps the tombstone Undelete keys on');

    await tester.tap(find.widgetWithText(ListTile, 'Undelete Operation'));
    await tester.pumpAndSettle();
    expect((await services.operations.get(uuid))!.deleted, isFalse);

    // The view is still open on it, now as a live operation.
    await tester.tap(toolsButton.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Delete Operation'), findsOneWidget);
    expect(find.text('Operation Details'), findsOneWidget);
    expect(find.text('Undelete Operation'), findsNothing);

    await tearDownView(tester);
  });

  // The first operation a user ever opens shows its setup sheet unasked — or,
  // with no callsign on the profile yet, a callsign prompt that SAVES the
  // operation. Either one is a write the guard on the header never sees.
  testWidgets('the first-open onboarding does not prompt over a deleted operation', (tester) async {
    final (services, _) = await pumpDeletedOperation(tester, firstEverOpen: true);
    expect(services.settings.activeProfile.operatorCall, isEmpty, reason: 'the prompt branch is the one under test');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(notice, findsOneWidget);

    await tearDownView(tester);
  });

  testWidgets('the logging panel is out of reach until the operation is undeleted from its notice', (tester) async {
    final (services, uuid) = await pumpDeletedOperation(tester);

    expect(notice, findsOneWidget);
    expect(callField.hitTestable(), findsNothing, reason: 'a tap must not reach the logging fields');
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ExcludeFocus>(),
      isNull,
      reason: 'nor may the keyboard: the call field autofocuses, and Enter logs',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Undelete Operation'));
    await tester.pumpAndSettle();

    expect((await services.operations.get(uuid))!.deleted, isFalse);
    expect(notice, findsNothing);
    expect(callField.hitTestable(), findsOneWidget);

    await tearDownView(tester);
  });
}
