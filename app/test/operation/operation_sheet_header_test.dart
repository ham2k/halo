// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Setup sheet's operation pills (activities_view_header.dart's
// _operationPills), which give ground as the row narrows and must give it in
// a fixed order: one line while everything fits, otherwise two — the
// callsigns and the pencil on top, the title and notes marker below —
// shedding the title first, then the operator callsign, then the notes
// marker, never the station callsign or the pencil, and leaving a "…" pill
// wherever something went.
//
// The decision is made from measured text widths, so it reads differently
// under the test font than on a device; these tests pin the ORDER and the
// invariants, never a pixel width, and sweep widths rather than name one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// Widths from roomy to cramped. The absolute numbers don't matter — what the
/// tests read is how the header's answer changes ALONG the sweep. It stops at
/// 380: below that the sheet's BODY overflows, a pre-existing narrow-layout
/// issue these are not about (see operation_view_layout_test.dart).
const _widths = [1400.0, 1000.0, 800.0, 620.0, 480.0, 380.0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Opens the sheet over an operation carrying every optional pill.
  ///
  /// [textScaler] is how these tests reach the ROOMY end of both ladders: the
  /// test font is far wider per character than any real one, so at scale 1.0
  /// even a 1400px window cannot show the long title or every pill, and the
  /// first rung of each ladder would never be exercised. Scaling the text down
  /// buys that room without pretending a window is wider than it is.
  Future<void> openSheet(
    WidgetTester tester, {
    String stationCall = 'VK9/AB1CDE/P',
    String operatorCall = 'VE3ABC/VE2',
    String userTitle = 'A Long Operation Title',
    String multiIdentifier = '',
    double textScaler = 1.0,
  }) async {
    // Otherwise the onboarding flow opens the sheet itself and races the tap.
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final created = await services.operations.create(stationCall: stationCall, userTitle: userTitle);
    // Every optional pill present, so a sweep starts from the crowded case
    // rather than from a header that had nothing to shed.
    final operation = Operation(
      uuid: created.uuid,
      // The operator goes in the slot the POSITION names, which is where the
      // header reads it from — left on `operatorCall`, a positioned operation
      // would show no operator pill and the sweeps below would be measuring a
      // header one pill short.
      data: {...created.data, operatorCallKeyFor(multiIdentifier): operatorCall, 'notes': 'some notes'},
    );
    await services.operations.saveData(operation);
    if (multiIdentifier.isNotEmpty) {
      await services.operations.updateLocalData(operation.uuid, {'multiIdentifier': multiIdentifier});
    }

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          // Around the navigator, not the home widget: the sheet is a pushed
          // route, so a MediaQuery inside `home` would never reach it.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScaler)),
            child: child!,
          ),
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(stationCall));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);
  }

  Future<void> resize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    await tester.pumpAndSettle();
  }

  testWidgets('a multi-station position rides on the identity line, ahead of the operator', (tester) async {
    // The position is what turns this device's spots into `.../OP2`, so it
    // belongs with the callsigns it modifies rather than among the extras —
    // and ahead of the operator, whose call it qualifies.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 900);
    await openSheet(tester, multiIdentifier: '2', textScaler: 0.5);

    final sheet = find.byType(OperationSheet);
    final position = find.descendant(of: sheet, matching: find.textContaining('Pos: '));
    final operator = find.descendant(of: sheet, matching: find.textContaining('Op: '));
    expect(position, findsOneWidget);
    expect(tester.getTopLeft(position).dx, lessThan(tester.getTopLeft(operator).dx));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('no position, no pill', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 900);
    await openSheet(tester, textScaler: 0.5);

    expect(find.descendant(of: find.byType(OperationSheet), matching: find.textContaining('Pos: ')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the operation pills keep the callsigns and pencil on the top line, shedding extras below', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 900);
    await openSheet(tester);

    var everDroppedTitle = false;
    var everDroppedNotes = false;
    var everDroppedOperator = false;
    var everTwoRuns = false;

    for (final width in _widths) {
      await resize(tester, width);
      final at = 'at $width logical px';
      // Scoped to the sheet: the view behind it carries a pencil of its own,
      // and a bare byIcon would match both.
      final sheet = find.byType(OperationSheet);
      final station = find.descendant(of: sheet, matching: find.textContaining('Station: '));
      final pencil = find.descendant(of: sheet, matching: find.byIcon(MdiIcons.pencil));

      expect(station, findsOneWidget, reason: 'the station callsign never goes, $at');
      expect(pencil, findsOneWidget, reason: 'the pencil never goes, $at');

      final titleText = find.descendant(of: sheet, matching: find.text('A Long Operation Title'));
      final notesIcon = find.descendant(of: sheet, matching: find.byIcon(MdiIcons.fileDocument));
      final operatorText = find.descendant(of: sheet, matching: find.textContaining('Op: '));
      final titlePill = titleText.evaluate().isNotEmpty;
      final notesPill = notesIcon.evaluate().isNotEmpty;
      final operatorPill = operatorText.evaluate().isNotEmpty;

      // Within the extras the title goes before the notes marker, which is the
      // only place the header admits the notes exist at all.
      if (titlePill) expect(notesPill, isTrue, reason: 'the title goes before the notes marker, $at');

      // Nothing vanishes silently: a shed pill leaves a marker behind, and a
      // row with all its pills has no marker to explain.
      final marker = find.descendant(of: sheet, matching: find.text('…'));
      final shedSomething = !titlePill || !notesPill || !operatorPill;
      expect(
        marker.evaluate().isNotEmpty,
        shedSomething,
        reason: shedSomething ? 'a shed pill leaves a "…" behind, $at' : 'no marker with every pill shown, $at',
      );
      if (!titlePill) everDroppedTitle = true;
      if (!notesPill) everDroppedNotes = true;
      if (!operatorPill) everDroppedOperator = true;
      if (everDroppedTitle) expect(titlePill, isFalse, reason: 'a dropped pill does not come back, $at');
      if (everDroppedNotes) expect(notesPill, isFalse, reason: 'a dropped pill does not come back, $at');

      // The identity rides the top line: whatever else the width forces out,
      // the callsigns and the pencil are the row a reader's eye lands on
      // first, never pushed under the title and notes.
      double topOf(Finder pill) => tester.getTopLeft(find.ancestor(of: pill, matching: find.byType(Container)).first).dy;
      final identityTop = topOf(station);
      expect(topOf(pencil), identityTop, reason: 'the pencil shares the station line, $at');
      if (operatorPill) {
        expect(topOf(operatorText), identityTop, reason: 'the operator shares the station line, $at');
      }
      final tops = {identityTop, if (titlePill) topOf(titleText), if (notesPill) topOf(notesIcon), if (operatorPill) topOf(operatorText)};
      expect(tops.length, lessThanOrEqualTo(2), reason: 'the pills stay within two runs, $at');
      if (tops.length == 2) everTwoRuns = true;
      for (final top in tops) {
        expect(top, greaterThanOrEqualTo(identityTop), reason: 'the extras never sit above the identity, $at');
      }
      expect(tester.takeException(), isNull, reason: 'no overflow, $at');
    }

    expect(everTwoRuns, isTrue, reason: 'the sweep reaches a width that needs the second run');
    expect(everDroppedOperator, isTrue, reason: 'the sweep reaches a width where the operator pill cannot fit');
    expect(everDroppedTitle || everDroppedNotes, isTrue, reason: 'the sweep reaches a width that sheds an extra');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a roomy row shows every pill on one line, with no marker', (tester) async {
    // The un-shed case, which the sweep above cannot reach: without it the
    // marker assertion only ever runs in its positive direction, so a header
    // that ALWAYS drew a "…" would pass.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 900);
    await openSheet(tester, stationCall: 'N0CALL', operatorCall: 'W1AW', userTitle: 'Op One', textScaler: 0.5);

    final sheet = find.byType(OperationSheet);
    final station = find.descendant(of: sheet, matching: find.textContaining('Station: '));
    expect(station, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.textContaining('Op: ')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Op One')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.byIcon(MdiIcons.fileDocument)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.byIcon(MdiIcons.pencil)), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('…')),
      findsNothing,
      reason: 'nothing was shed',
    );

    // One line: every pill shares the station's top edge.
    double topOf(Finder pill) => tester.getTopLeft(find.ancestor(of: pill, matching: find.byType(Container)).first).dy;
    final identityTop = topOf(station);
    for (final pill in [
      find.descendant(of: sheet, matching: find.textContaining('Op: ')),
      find.descendant(of: sheet, matching: find.text('Op One')),
      find.descendant(of: sheet, matching: find.byIcon(MdiIcons.fileDocument)),
      find.descendant(of: sheet, matching: find.byIcon(MdiIcons.pencil)),
    ]) {
      expect(topOf(pill), identityTop, reason: 'one run while everything fits');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
