// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station being worked becomes a spot (LoggingSession.onDraftSpot):
// leaving the call field starts it, the draft moves it, the operator's wipe
// takes it back and its undo returns it, logging sends the contact as logged,
// and a logged contact or a QSY leaves it standing
// (docs/design/logging-fields.md § Local spots).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

typedef _Sent = ({String key, String? call});

void main() {
  installLoggingHarness();

  late List<_Sent> sent;
  setUp(() => sent = []);

  LoggingSession session() => LoggingSession(onDraftSpot: (key, qso) => sent.add((key: key, call: (qso?['their'] as Map?)?['call'] as String?)));

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> typeCallAndLeave(WidgetTester tester, String call) async {
    await tester.enterText(field('Their call'), call);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }

  testWidgets('a call left behind becomes a spot, and only once it is left', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.enterText(field('Their call'), 'W1A');
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump();
    // Each keystroke is half a callsign; the board would show every one.
    expect(sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(sent, hasLength(1));
    expect(sent.single.call, 'W1AW');
  });

  testWidgets('the spot follows the entry under one key, and a corrected call moves it rather than adding one', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final key = sent.single.key;

    // Focus is in Sent now; what is typed there is the draft changing.
    await tester.enterText(field('Sent'), '57');
    await tester.pump();
    expect(sent, hasLength(2));
    expect(sent.last, (key: key, call: 'W1AW'));

    // Back into the call field to fix a busted call: nothing is sent while
    // it is being retyped, and leaving sends the correction under the same key.
    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.enterText(field('Their call'), 'W1AX');
    await tester.pump();
    expect(sent, hasLength(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(sent.last, (key: key, call: 'W1AX'));
  });

  testWidgets("the operator's wipe takes the spot back, and its undo puts it back under the same key", (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final key = sent.single.key;

    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);
    expect(sent.last, (key: key, call: null), reason: 'a wiped entry was a wrong call or a station gone');

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(sent.last, (key: key, call: 'W1AW'));
  });

  testWidgets('undo onto a newer entry takes its spot down before it puts the wiped one back', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final wiped = sent.single.key;
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);
    await typeCallAndLeave(tester, 'K2ABC');
    final newer = sent.last.key;

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();

    // Without the retraction K2ABC's spot has no key left that could take it
    // down, and stands for hours over an entry the operator replaced.
    expect(sent.reversed.take(2).toList(), [(key: wiped, call: 'W1AW'), (key: newer, call: null)]);
  });

  testWidgets('Alt+W after the call is erased in the field takes its spot down', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final key = sent.single.key;
    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.enterText(field('Their call'), '');
    await tester.pump();

    // Nothing composed, so this is the bare wipe — not the wipe button's path.
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);
    expect(sent.last, (key: key, call: null));
  });

  testWidgets('manual time entry spots nothing, left or logged', (tester) async {
    // A paper log typed in afterwards: every station in it would go on the
    // board as on the air now.
    await tester.pumpWidget(
      host(
        session: session(),
        manualTime: ManualTimeHooks(startAtMillis: nowMillis() - const Duration(days: 2).inMilliseconds),
      ),
    );
    await typeCallAndLeave(tester, 'W1AW');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);

    expect(sent.where((s) => s.call != null), isEmpty);
  });

  testWidgets('a logged contact leaves its spot standing, and the next contact gets a spot of its own', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final first = sent.single.key;

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);
    // A retraction here would take down the one station the log proves was there.
    expect(sent.where((s) => s.call == null), isEmpty);
    expect(sent.last, (key: first, call: 'W1AW'), reason: 'the log moves the followed spot, not a second one beside it');

    await typeCallAndLeave(tester, 'K2ABC');
    expect(sent.last.call, 'K2ABC');
    expect(sent.last.key, isNot(first), reason: "under the logged contact's key it would move that station's spot");
  });

  testWidgets('a contact logged straight from the call field is spotted too', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);

    // Enter never blurs, so the call field was never left: only the log can spot it.
    expect(sent, hasLength(1));
    expect(sent.single.call, 'W1AW');
  });

  testWidgets('a QSY wipe leaves the spot where the station was', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');

    tunedRadio.setVfo('vfoA', freq: 14250);
    await tester.pump();
    await tester.pump();

    expect(tester.widget<TextField>(field('Their call')).controller!.text, isEmpty, reason: 'the QSY did wipe the entry');
    expect(sent, hasLength(1), reason: 'the operator moved; the station did not');
  });

  testWidgets('editing a logged contact makes no spot', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.enterText(field('Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    sent.clear();

    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: logged.single, onDraftSpot: session().onDraftSpot),
      ),
    );
    await tester.pump();
    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(sent, isEmpty, reason: 'a record in the log is not a station on the air now');
  });
}
