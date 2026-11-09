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
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

typedef _Sent = ({String key, String? call});

void main() {
  installLoggingHarness();

  late List<_Sent> sent;
  late List<({String text, Map<String, dynamic> at})> tags;
  late List<Map<String, dynamic>> cleared;
  setUp(() {
    sent = [];
    tags = [];
    cleared = [];
  });

  LoggingSession session({bool hostSpots = true, Map<String, dynamic>? suggestion, bool peek = false}) => LoggingSession(
    suggestedQso: suggestion,
    suggestedQsoIsTentative: peek,
    onDraftSpot: (key, qso) {
      sent.add((key: key, call: (qso?['their'] as Map?)?['call'] as String?));
      return hostSpots && qso != null;
    },
    onBandTag: (text, at) {
      tags.add((text: text, at: at));
      return hostSpots;
    },
    onClearLocalSpots: cleared.add,
  );

  Finder field(String label) => find.widgetWithText(TextField, label);

  // A spot row's fill, as a tap on the Spots list hands it over.
  final tapped = <String, dynamic>{
    'their': {'call': 'N6LY'},
    'freq': 14266.0,
    'band': '20m',
    'mode': 'SSB',
    'refs': [
      {'type': 'potaHunter', 'ref': 'US-1131'},
    ],
  };

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

  testWidgets('a spot tapped and left untouched is not spotted again, until it is logged', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.pumpWidget(host(session: session(suggestion: tapped)));
    await tester.pump();
    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // Already on the board: spotted again, the row restamps as heard now, and
    // so does every station the operator clicks past.
    expect(sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);
    expect(sent.single.call, 'N6LY');
  });

  testWidgets('Space on a tapped spot spots it, and logging it moves that spot rather than adding one', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.pumpWidget(host(session: session(suggestion: tapped)));
    await tester.pump();
    await tester.tap(field('Their call'));
    await tester.pump();
    // Space is the operator going on to work the station: without it, a tapped
    // call never reaches the board until it is logged.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(sent.single.call, 'N6LY');
    final key = sent.single.key;

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);
    expect(sent.last.call, 'N6LY');
    expect(sent.last.key, key, reason: 'under a new key the logged contact would sit on the board beside its own spot');
  });

  testWidgets('Space on a peeked spot spots it, and closing the peek takes it back down', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await tester.pumpWidget(host(session: session(suggestion: tapped, peek: true)));
    await tester.pump();
    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(sent.single.call, 'N6LY');

    await tester.pumpWidget(host(session: session()));
    await tester.pump();
    // The peek's wipe only ends the follow: without the retraction the spot
    // stands, freshly stamped, for a station the operator let go, and nothing
    // holds its key to take it down.
    expect(sent.last, (key: sent.first.key, call: null));
  });

  testWidgets('a station typed in keeps its spot when a spot is tapped, and the next one gets its own', (tester) async {
    await tester.pumpWidget(host(session: session()));
    await typeCallAndLeave(tester, 'W1AW');
    final typed = sent.single.key;

    await tester.pumpWidget(host(session: session(suggestion: tapped)));
    await tester.pump();
    await tester.pump();
    // Followed on, the W1AW spot would move to N6LY: the board loses a station
    // that was there and restamps one it already had.
    expect(sent, hasLength(1));

    await tester.tap(field('Their call'));
    await tester.pump();
    await tester.enterText(field('Their call'), 'K2ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(sent.last.call, 'K2ABC');
    expect(sent.last.key, isNot(typed));
  });

  group('band tags', () {
    testWidgets('text ending in ! and Enter tags the frequency, logs nothing, and empties the call field', (tester) async {
      await tester.pumpWidget(host(session: session()));
      await tester.enterText(field('Their call'), 'QRM!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tags.single.text, 'QRM');
      expect(tags.single.at, {'freq': 14285.0, 'band': '20m', 'mode': 'SSB'});
      expect(tester.widget<TextField>(field('Their call')).controller!.text, isEmpty);
      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'a tag is not a contact');
      expect(sent, isEmpty, reason: 'a tag is not an entry the panel follows');

      await tester.enterText(field('Their call'), 'NET!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tags.map((t) => t.text), ['QRM', 'NET'], reason: 'each tag is one of its own, not a draft the second moves');
    });

    testWidgets('a command ending in ! runs as the command, and tags nothing', (tester) async {
      await tester.pumpWidget(
        host(
          session: session(),
          commands: CommandHooks(
            interpretCommand: (input, [operation, qso, execute = false]) async => input == 'GO!' ? {'describe': 'Go', 'commands': const []} : null,
          ),
        ),
      );
      await tester.enterText(field('Their call'), 'GO!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tags, isEmpty);
      expect(tester.widget<TextField>(field('Their call')).controller!.text, isEmpty, reason: 'the command ran, and took its text');
    });

    testWidgets('a lone ! clears the local spots at the radio, and empties the call field', (tester) async {
      await tester.pumpWidget(host(session: session()));
      await tester.enterText(field('Their call'), '!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(cleared.single, {'freq': 14285.0, 'band': '20m', 'mode': 'SSB'});
      expect(tags, isEmpty);
      expect(tester.widget<TextField>(field('Their call')).controller!.text, isEmpty);
    });

    testWidgets('the same station left again after a lone ! goes back on the board', (tester) async {
      await tester.pumpWidget(host(session: session()));
      await typeCallAndLeave(tester, 'W1AW');
      await tester.enterText(field('Sent'), '57');
      await tester.pump();
      await tester.tap(field('Their call'));
      await tester.pump();
      await tester.enterText(field('Their call'), '!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(cleared, hasLength(1));
      final before = sent.length;

      // The clear took this entry's spot down with the rest. Remembered as
      // still sent, the draft below is the one last sent, and would be deduped.
      await typeCallAndLeave(tester, 'W1AW');
      expect(sent.length, before + 1);
      expect(sent.last.call, 'W1AW');
    });

    testWidgets('in a call stack Enter is the logging path\'s, which keeps the queued call', (tester) async {
      // Taken whole, "K1ABC//QRM" would go up as one tag and K1ABC leave the field unlogged.
      await tester.pumpWidget(host(session: session()));
      await tester.enterText(field('Their call'), 'K1ABC//QRM!');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect((logged.single.data['their'] as Map)['call'], 'K1ABC');
      expect(tester.widget<TextField>(field('Their call')).controller!.text, 'QRM!', reason: 'the rest of the stack stays to be worked');
      expect(tags, isEmpty);
      expect(cleared, isEmpty);
    });

    group('when no spot can be made, the text stays and the message slot says why', () {
      // An emptied field reads as done; the operator would never know the tag is not up.
      Future<List<String?>> tagWith(WidgetTester tester, {LoggingSession? on, RadioHookup? radio, ManualTimeHooks? manualTime}) async {
        final messages = <String?>[];
        await tester.pumpWidget(
          host(
            session: on ?? session(),
            radio: radio,
            manualTime: manualTime,
            commands: CommandHooks(onCommandMessageChanged: messages.add),
          ),
        );
        await tester.enterText(field('Their call'), 'QRM!');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.widget<TextField>(field('Their call')).controller!.text, 'QRM!');
        return messages;
      }

      testWidgets('no frequency', (tester) async {
        final bandOnly = FakeVfoStore()..setVfo('vfoA', band: '20m', mode: 'SSB');
        addTearDown(bandOnly.dispose);
        final messages = await tagWith(tester, radio: baseRadio().copyWith(radioService: bandOnly));
        expect(messages.last, t.loggingControls.localSpotNeedsFrequency);
        expect(tags, isEmpty);
      });

      testWidgets('a frequency off every band', (tester) async {
        // Left to the host, its refusal would read as local spots switched off.
        final offBand = FakeVfoStore()..setVfo('vfoA', freq: 14360, mode: 'SSB');
        addTearDown(offBand.dispose);
        final messages = await tagWith(tester, radio: baseRadio().copyWith(radioService: offBand));
        expect(messages.last, t.loggingControls.localSpotNeedsFrequency);
        expect(tags, isEmpty);
      });

      testWidgets('a time that is not the live one', (tester) async {
        final messages = await tagWith(tester, manualTime: ManualTimeHooks(startAtMillis: nowMillis() - const Duration(days: 2).inMilliseconds));
        expect(messages.last, t.loggingControls.localSpotNeedsLiveTime);
        expect(tags, isEmpty);
      });

      testWidgets('the host made no spot: local spots are off', (tester) async {
        final messages = await tagWith(tester, on: session(hostSpots: false));
        expect(messages.last, t.loggingControls.localSpotsOff);
      });
    });
  });
}
