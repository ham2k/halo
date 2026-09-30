// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The equipment editor's Advanced Settings fold, as an operator adding a
// radio meets it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/station_panel.dart';
import '../support/halo_test_support.dart';

void main() {
  late HaLoServices services;

  setUp(() async {
    services = (await makeHaLoServices()).services;
  });

  /// Fixed pumps, never `pumpAndSettle`: the Add dialog runs a discovery
  /// spinner, and an animation that never ends is a settle that never
  /// arrives.
  Future<void> pick(WidgetTester tester, String query, String name) async {
    // Tall enough that the whole form fits above the pane's footer, which
    // otherwise sits over the fold at the test's default 800x600.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: StationPanel(services: services)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(t.settings.station.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump();
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    final fold = find.text(t.settings.station.advancedSettings);
    await tester.ensureVisible(fold);
    await tester.tap(fold);
    await tester.pump();
    await tester.pump(collapseDuration);
  }

  /// The row a label belongs to, counted only where a tap would reach it: a
  /// shut fold keeps its rows mounted, and a field's own label never takes
  /// the hit (its decorator does), so a bare text finder passes either way.
  Finder reachable(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is InputDecorator || w is ListTile || w is CheckboxListTile || w is SwitchListTile),
      )
      .first
      .hitTestable();

  bool? checked(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is CheckboxListTile || w is SwitchListTile || w is ListTile));
    final box = find.descendant(of: row.first, matching: find.byType(Checkbox));
    if (box.evaluate().isNotEmpty) return tester.widget<Checkbox>(box.first).value;
    return tester.widget<Switch>(find.descendant(of: row.first, matching: find.byType(Switch)).first).value;
  }

  testWidgets('a serial radio folds its lines and cadences away, closed', (tester) async {
    await pick(tester, 'FT-817', t.settings.station.models.ft817);
    final st = t.settings.station;

    expect(find.text(st.advancedSettings), findsOneWidget);
    expect(reachable(st.serialRtsHigh), findsNothing, reason: 'closed until the operator asks');
    expect(reachable(st.pollInterval), findsNothing);
    expect(reachable(st.serialPort), findsOneWidget, reason: 'what every operator fills in stays out of the fold');

    await openAdvanced(tester);
    expect(reachable(st.serialRtsHigh), findsOneWidget);
    expect(reachable(st.serialDtrHigh), findsOneWidget);
    expect(reachable(st.telemetryInterval), findsOneWidget);
    expect(reachable(st.pollInterval), findsOneWidget);
    // What the boxes open on is what the connection does: an unchecked box
    // over a line held high is the operator being lied to.
    expect(checked(tester, st.serialRtsHigh), isFalse);
    expect(checked(tester, st.serialDtrHigh), isFalse);
  });

  testWidgets('the troubleshooting notes close the form, after the fold', (tester) async {
    // The notes arrive among the always-shown fields, so a form that only
    // pulls the fold's members out leaves them sitting ABOVE Advanced
    // Settings, between the fields the operator is filling in.
    await pick(tester, 'FT-891', t.settings.station.models.ft891);
    final st = t.settings.station;

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top(st.troubleshootingNotes), greaterThan(top(st.advancedSettings)));

    await openAdvanced(tester);
    expect(top(st.troubleshootingNotes), greaterThan(top(st.pollInterval)), reason: "below the fold's contents too, not just its header");
  });
}
