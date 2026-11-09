// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show HaloDialog;
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/cw_messages_dialog.dart';
import 'package:ham2k_logger/views/settings/keyboard_shortcuts_panel.dart' show KeyerMessageKeys;

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
  });

  Widget host() => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showCwMessagesDialog(context, services), child: const Text('open')),
        ),
      ),
    ),
  );

  testWidgets('with nothing to key CW: says so first, then speed and repeat, then which set', (tester) async {
    // The order is the point: how messages go out is adjusted between
    // contacts, which set is being edited far less often, and a key that
    // cannot send makes every control below moot — so that comes first.
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    double top(Finder finder) => tester.getTopLeft(finder.first).dy;
    final notice = find.text('Current radio does not support CW keying');
    expect(notice, findsOneWidget);
    expect(top(notice), lessThan(top(find.text('Keyer speed'))));
    expect(top(find.text('Keyer speed')), lessThan(top(find.text('Message Set'))));
    expect(top(find.text('Repeat M1')), lessThan(top(find.text('Message Set'))));
  });

  // The trap: on a phone, the speed and the repeat side by side leave the
  // cooldown no room to read, or overflow.
  testWidgets('the repeat sits beside the speed where it fits, and under it on a phone', (tester) async {
    double top(Finder finder) => tester.getTopLeft(finder.first).dy;
    addTearDown(tester.view.reset);

    for (final (size, beside) in [(const Size(1200, 900), true), (const Size(360, 780), false)]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'nothing overflows at ${size.width}');
      expect(top(find.text('Repeat M1')) > top(find.text('Keyer speed')) + 24, !beside, reason: 'at ${size.width}');
      await tester.pumpWidget(const SizedBox());
    }
  });

  // The row is where an operator looks for which key sends a message, so it
  // is where changing that key is found — once Keyboard Shortcuts is on;
  // without it the keys are fixed, and the caps only say which they are.
  testWidgets("a row's keys open the shortcut editor for its message, with Keyboard Shortcuts on", (tester) async {
    Finder caps() => find.descendant(of: find.byType(KeyerMessageKeys).first, matching: find.byType(InkWell));
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(KeyerMessageKeys), findsNWidgets(SettingsService.cwMessageCount));
    expect(caps(), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await services.settings.setExperimentEnabled('kb', true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(caps());
    await tester.pumpAndSettle();
    expect(find.text('Send message 1'), findsOneWidget, reason: "the editor, titled by the message's command");
  });

  testWidgets('one row per key, labelled where a label exists, the message underneath', (tester) async {
    await services.settings.setCwMessage(1, 'CQ CQ DE {{ op.call }} K');
    await services.settings.setCwMessageLabel(1, 'CQ');
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CW Keyer Messages'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(SettingsService.cwMessageCount));
    expect(find.text('CQ CQ DE {{ op.call }} K'), findsOneWidget);
    expect(find.textContaining('F1'), findsWidgets);
    // The set the write landed in is a SEEDED one, so the rows that say
    // "(empty)" are the ones the seeds left alone — not all seven others.
    final set = services.settings.activeCwMessageSet;
    final empties = [
      for (var n = 1; n <= SettingsService.cwMessageCount; n++)
        if (set.message(n).trim().isEmpty) n,
    ];
    expect(empties, isNotEmpty);
    expect(find.text('(empty)'), findsNWidgets(empties.length), reason: 'the unset ones say so');
  });

  testWidgets('a row opens its own dialog: the message, then the label under Details; its Save stores both', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing, reason: 'the editor stores as it goes; its way out is Done');
    expect(find.text('Revert'), findsNothing, reason: 'nothing to put back yet');

    // The header above the rows is tall enough to push a row under the
    // footer at the test's window size; an operator scrolls it into view.
    await tester.ensureVisible(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(HaloDialog, 'Message 3'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'M3'), '{{ qso.call }} 5NN TU');
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Exchange');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Stored by the row's Save, with the editor still open: a pane closed by
    // a tap outside must not drop an edit that looked made.
    expect(services.settings.cwMessage(3), '{{ qso.call }} 5NN TU');
    expect(services.settings.cwMessageLabel(3), 'Exchange');
    expect(find.widgetWithText(HaloDialog, 'Message 3'), findsNothing, reason: 'closed on Save');
    expect(find.textContaining('Exchange'), findsOneWidget);
    expect(find.text('Revert'), findsOneWidget, reason: 'offered from the first change on');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('CW Keyer Messages'), findsNothing);
    expect(services.settings.cwMessage(3), '{{ qso.call }} 5NN TU', reason: 'Done keeps what is stored');
  });

  // Help is a detour, not a way out: an operator reaches for it WHILE
  // writing messages, so its Done must land them back on the editor. Popping
  // one route too many — or Help sitting in the trailing group where its
  // Done reads as the editor's own — would close the editor and, with it,
  // the Revert of what they had changed.
  testWidgets('Help opens over the editor at the leading edge, and Done returns to the draft', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The header above the rows is tall enough to push a row under the
    // footer at the test's window size; an operator scrolls it into view.
    await tester.ensureVisible(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'M3'), '{{ qso.call }} {{ qso.serial | pad: 3 }}');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.text('Help')).dx, lessThan(tester.getCenter(find.text('Done')).dx));
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Writing CW Messages'), findsOneWidget);
    for (final template in ['{{ op.call }}', '{{ qso.call }}', '{{ qso.rst }}', '{{ qso.serial }}']) {
      expect(find.text(template), findsOneWidget);
    }
    expect(find.textContaining('| pad: 3 }}'), findsWidgets);
    expect(find.textContaining('| cut }}'), findsWidgets);

    // The help's Done, over the editor's own.
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(find.text('Writing CW Messages'), findsNothing);
    expect(find.text('CW Keyer Messages'), findsOneWidget, reason: 'the editor is still open behind it');
    expect(find.text('Revert'), findsOneWidget, reason: 'with what it would put back');
  });

  // What Enter keys from each F-key is ESM's to explain, and ESM exists only
  // behind its experiment: shown without it, the help would describe a
  // feature the operator cannot turn on.
  testWidgets('Help explains what Enter Sends Messages keys only while its experiment is on', (tester) async {
    // The editor behind the help lists its own keys too; only the help counts.
    Finder inHelp(Finder finder) => find.descendant(
      of: find.ancestor(of: find.text('Writing CW Messages'), matching: find.byType(HaloDialog)),
      matching: finder,
    );
    Future<void> openHelp() async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
    }

    await openHelp();
    expect(inHelp(find.text('F5  {{qso.call}}')), findsNothing);
    expect(inHelp(find.textContaining('next.call')), findsNothing);

    await services.settings.setExperimentEnabled('esm', true);
    await tester.pumpWidget(const SizedBox());
    await openHelp();
    expect(inHelp(find.text('F5  {{qso.call}}')), findsOneWidget, reason: 'read off the ESM set: their call on F5');
    expect(inHelp(find.textContaining('next.call')), findsOneWidget, reason: 'and the stacking thanks it suggests');
  });

  testWidgets('Revert puts back every set the operator touched, and the set in use, not just the one on screen', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Future<void> editRow(int index, String text) async {
      await tester.ensureVisible(find.byType(ListTile).at(index));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).at(index));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'M${index + 1}'), text);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    final sets = services.settings.cwMessageSets;
    final (defaults, pota) = (sets.first, sets.last);
    await editRow(2, 'DEFAULT EDIT');
    // Edits land on whichever set is in use — so the dialog's way of
    // touching a second set is to switch to it.
    await tester.tap(find.text('Default').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POTA').last);
    await tester.pumpAndSettle();
    expect(services.settings.cwMessageSetId, pota.id, reason: 'a pick is in use the moment it is made');
    await editRow(2, 'POTA EDIT');

    // The trap: a Revert that kept only the set on screen would leave
    // Default edited, and POTA keying F1-F8 after the operator undid it all.
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    final after = {for (final set in services.settings.cwMessageSets) set.id: set};
    expect(after[defaults.id]!.message(3), defaults.message(3));
    expect(after[pota.id]!.message(3), pota.message(3));
    expect(services.settings.cwMessageSetId, defaults.id);
    expect(find.text('Revert'), findsNothing, reason: 'nothing left to put back');
  });

  // The repeat and Enter Sends Messages are how the keyer behaves, not what
  // the messages say: Revert takes back the messages, and taking these with
  // them would undo a pick the operator made on purpose, which the Phone
  // Keyer beside it keeps.
  testWidgets('the keyer behaviour applies as it changes, and survives a Revert of the messages', (tester) async {
    await services.settings.setExperimentEnabled('esm', true);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(RepeatFields), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Cooldown before repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 seconds').last);
    await tester.pumpAndSettle();
    expect(services.settings.cwRepeatDelay, const Duration(seconds: 5));

    await tester.tap(find.descendant(of: find.byType(EnterSendsField), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(services.cat.enterSends.value, (on: true, running: false));

    await tester.ensureVisible(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'M3'), 'TAKEN BACK');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    expect(services.settings.cwRepeatDelay, const Duration(seconds: 5));
    expect(services.cat.enterSends.value, (on: true, running: false));
  });

  // Run or S&P is the set's operating style, which every new contact
  // records; a switch that only says on or off must not quietly move it,
  // either way.
  testWidgets('the Enter Sends Messages switch turns ESM on and off and leaves Run or S&P where it is', (tester) async {
    await services.settings.setExperimentEnabled('esm', true);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final esmSwitch = find.descendant(of: find.byType(EnterSendsField), matching: find.byType(Switch));

    for (final running in [true, false]) {
      services.cat.setEnterSends(running: running);
      await tester.tap(esmSwitch);
      await tester.pumpAndSettle();
      expect(services.cat.enterSends.value, (on: true, running: running));
      expect(tester.widget<Switch>(esmSwitch).value, isTrue, reason: 'the switch shows a change made through it');
      await tester.tap(esmSwitch);
      await tester.pumpAndSettle();
      expect(services.cat.enterSends.value, (on: false, running: running));
    }

    services.cat.setEnterSends(on: true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(esmSwitch).value, isTrue, reason: 'the switch follows ESM switched on elsewhere — the pill, the ESM command');
  });

  testWidgets('an install with nothing stored is seeded: a Default to key, and a POTA beside it', (tester) async {
    final sets = services.settings.cwMessageSets;
    expect(sets.map((set) => set.name), ['Default', 'POTA']);
    expect(services.settings.activeCwMessageSet.name, 'Default');
    expect(services.settings.cwMessage(1), 'CQ DE {{op.call}} K');
    expect(services.settings.cwMessageLabel(1), 'CQ');
    // POTA is Default with its CQ changed — what duplicating a set makes,
    // and the shape the operator's next one will be.
    expect(sets.last.message(1), 'CQ POTA DE {{op.call}} K');
    expect(sets.last.message(2), sets.first.message(2));
  });

  testWidgets('messages written before sets existed become a set of their own, and stay in use', (tester) async {
    // What an upgrade finds: the pre-sets keys, under their own storage.
    SharedPreferences.setMockInitialValues({'settings.radio': '{"cwMessage1":"CQ DE N0CALL K","cwMessageLabel1":"MY CQ"}'});
    final settings = SettingsService(await SharedPreferences.getInstance());
    expect(settings.cwMessageSets.map((set) => set.name), ['My Messages', 'Default', 'POTA']);
    // FIRST, and therefore active: an upgrade must not change what the
    // function keys send.
    expect(settings.activeCwMessageSet.name, 'My Messages');
    expect(settings.cwMessage(1), 'CQ DE N0CALL K');
    expect(settings.cwMessageLabel(1), 'MY CQ');
  });

  testWidgets('picking a set changes what the keys send at once, and Revert picks the one in use before', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POTA').last);
    await tester.pumpAndSettle();
    expect(services.settings.activeCwMessageSet.name, 'POTA');
    expect(services.settings.cwMessage(1), 'CQ POTA DE {{op.call}} K');
    expect(find.text('Revert'), findsOneWidget, reason: 'a pick is a change Revert can take back');

    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    expect(services.settings.activeCwMessageSet.name, 'Default');
  });
}
