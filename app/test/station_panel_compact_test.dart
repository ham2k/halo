// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control's quick-access dialog (StationPanel's `compact` mode):
// current configuration and the current rig only, a Power field, no Add
// Equipment/Other Options, and a More Settings/Done footer.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/station_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
  });

  // The VFO's persist debounce, which a Power commit arms and which would
  // otherwise outlive the widget tree and fail the test on a pending timer.
  Future<void> settleVfoWrite(WidgetTester tester) => tester.runAsync(services.radio.flushPendingWrites);

  Widget wrap(Widget child) => TranslationProvider(
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('shows only the current rig, not other radios, and no Add Equipment', (tester) async {
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Second Radio');
    expect(services.cat.radio1, isNotNull, reason: 'newest addNode designates radio1');

    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Main Radio'), findsNothing, reason: 'radio1 is Second Radio, the newest added');
    // Once in the VFO dropdown's selected value, once in the equipment row.
    expect(find.text('Second Radio'), findsNWidgets(2));
    expect(find.text('Add equipment'), findsNothing);
  });

  testWidgets('hides Other Options entirely', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Other Options'), findsNothing);
    expect(find.text('Track Station Info for each QSO'), findsNothing);
  });

  testWidgets('has no equipment row when no rig is designated', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsNothing, reason: 'compact mode never shows this message');
  });

  testWidgets('Power field persists to the VFO on submit', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(services.radio.vfoA.power, isNull);
    expect(find.text('Watts'), findsOneWidget, reason: 'unit label after the field');
    await tester.enterText(find.widgetWithText(TextFormField, 'Power'), '100');
    expect(services.radio.vfoA.power, isNull, reason: 'not committed until submit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 100);
  });

  testWidgets('Power field commits on losing focus, not just on submit', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Power'), '50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 50);
  });

  testWidgets('typing does not rebuild the field mid-entry (no per-keystroke remount)', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, 'Power');
    await tester.enterText(field, '1');
    await tester.pump();
    // A per-keystroke commit-and-remount (the ValueKey bug) would have
    // pushed '1' to settings already and swapped in a fresh Element/
    // FocusNode — losing focus after the first digit. Still focused here
    // means the rest of a multi-digit value can land in the same field.
    expect(services.radio.vfoA.power, isNull);
    await tester.enterText(field, '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 15);
  });

  testWidgets('footer: More Settings fires the callback, Done pops the pane', (tester) async {
    var moreSettingsTapped = false;
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: StationPanel(
              services: services,
              compact: true,
              onMoreSettings: () => moreSettingsTapped = true,
            ),
          ),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More Settings'));
    await tester.pumpAndSettle();
    expect(moreSettingsTapped, isTrue);

    // Still open — this test's onMoreSettings doesn't pop, unlike the real
    // logging_panel.dart wiring, so Done is exercised as a separate action.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(StationPanel), findsNothing);
  });
}
