// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A QSY wipes the entry being composed: the VFO leaving the one the entry was
// started on — at the radio, or from anything but the entry's own Radio
// control and More pane — takes the operator to another station, and the
// entry was for the one they left. Undo brings it back, tuned back to where
// it was started.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  String textOf(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label).first).controller!.text;

  Future<void> tune(WidgetTester tester, {double? freq, String? mode}) async {
    tunedRadio.setVfo('vfoA', freq: freq, mode: mode);
    // Twice: the QSY verdict lands a microtask after the reading, and the
    // test binding flushes microtasks after the frame it pumps.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('tuning the radio away wipes the entry, and undo brings it back on the frequency it was started on', (tester) async {
    await tester.pumpWidget(host());
    // Nothing composed: the panel just follows, with nothing to offer back.
    await tune(tester, freq: 14200);
    expect(find.byIcon(MdiIcons.undo), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tune(tester, freq: 14250);

    expect(textOf(tester, 'Their call'), isEmpty, reason: 'the entry was for the station on 14200');
    expect(await qsosAfterWaiting(tester), isEmpty, reason: 'a QSY throws the entry away, never logs it');

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();

    expect(textOf(tester, 'Their call'), 'W1AW');
    // Restored onto 14250 it would be logged there, against a station that
    // was never on it — the radio goes back with the entry.
    expect(tunedRadio.vfoA.freq, 14200);
    expect(tunedRadio.vfoA.mode, 'SSB');
  });

  testWidgets('a nudge on a voice keeps the entry, and the nudges add up from where it started', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    await tune(tester, freq: 14285.6);
    await tune(tester, freq: 14286);
    expect(textOf(tester, 'Their call'), 'W1AW', reason: 'clearing up a voice is not leaving the station');

    // 600 Hz past the last reading, 1.1 kHz past the start: measured from
    // the last reading, a slow walk off the station would never wipe.
    await tune(tester, freq: 14286.1);
    expect(textOf(tester, 'Their call'), isEmpty);
  });

  testWidgets('CW is held to 200 Hz', (tester) async {
    tunedRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // Exactly 200 Hz, which these doubles put a hair over: zero-beating a
    // caller that far must not cost the entry.
    await tune(tester, freq: 14030.2);
    expect(textOf(tester, 'Their call'), 'W1AW');

    // 500 Hz is inside a phone tolerance, so this fails if CW is held to it.
    await tune(tester, freq: 14030.5);
    expect(textOf(tester, 'Their call'), isEmpty);
  });

  testWidgets('a mode change at the radio wipes too, and undo puts the mode back', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    await tune(tester, mode: 'CW');
    expect(textOf(tester, 'Their call'), isEmpty);

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(textOf(tester, 'Their call'), 'W1AW');
    expect(tunedRadio.vfoA.mode, 'SSB');
    expect(tunedRadio.vfoA.freq, 14285);
  });

  testWidgets("the Radio control's own frequency and mode edit the entry, and move where it is measured from", (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14250');
    await tester.pump(const Duration(seconds: 6));
    expect(tunedRadio.vfoA.freq, 14250, reason: 'the debounced push reached the radio');

    await tester.tap(find.widgetWithText(TextField, 'Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CW').last);
    await tester.pump();
    expect(tunedRadio.vfoA.mode, 'CW');
    expect(textOf(tester, 'Their call'), 'W1AW', reason: "correcting this contact's radio is not a QSY");
    // Past the rig's settling after that write, where anything it reports
    // is taken as the start.
    await tester.pump(const Duration(seconds: 3));

    // Measured from 14250 CW now: from the old start, this is 35 kHz and
    // another mode, and the entry would go.
    await tune(tester, freq: 14250.15);
    expect(textOf(tester, 'Their call'), 'W1AW');
    await tune(tester, freq: 14250.3);
    expect(textOf(tester, 'Their call'), isEmpty);
  });

  testWidgets('a frequency command wipes what was composed beside it, and undo tunes back', (tester) async {
    await tester.pumpWidget(
      host(
        prefs: const LoggingPreferences(showGridField: true),
        commands: CommandHooks(interpretCommand: fakeInterpretCommand),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN31PR');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '7030');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tunedRadio.vfoA.freq, 7030);
    expect(textOf(tester, 'Grid'), isEmpty, reason: 'the command went to another station, like the knob would');
    expect(
      find.textContaining('Frequency set to', findRichText: true),
      findsOneWidget,
      reason: 'the wipe must not eat the confirmation of the command that caused it',
    );

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(textOf(tester, 'Grid'), isNotEmpty);
    expect(tunedRadio.vfoA.freq, 14285);
  });

  testWidgets('a spot tunes the radio for the entry it fills, without wiping it', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpWidget(
      host(
        session: const LoggingSession(
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 7074.0,
            'mode': 'FT8',
          },
        ),
      ),
    );
    await tester.pump();
    expect(tunedRadio.vfoA.freq, 7074);
    expect(textOf(tester, 'Their call'), 'K1ABC');

    // The spot's frequency is where this entry started: the radio settling
    // a few hertz off it is the same station.
    await tune(tester, freq: 7074.1);
    expect(textOf(tester, 'Their call'), 'K1ABC');

    // A rig with no data mode answers FT8 as USB: its word for the same
    // station, and undo would only send FT8 to be answered the same way.
    await tune(tester, mode: 'USB');
    expect(textOf(tester, 'Their call'), 'K1ABC');
  });

  testWidgets('a QSY wipe is no edit of the frequency, and writes nothing to the radio after it', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tune(tester, freq: 14250);

    var writes = 0;
    void count() => writes++;
    tunedRadio.addListener(count);
    addTearDown(() => tunedRadio.removeListener(count));
    await tester.pump(const Duration(seconds: 6));

    // Read as typed, the wipe's new frequency arms the five-second push, and
    // that write takes wherever the radio is then as the next entry's start.
    expect(writes, 0);
  });

  testWidgets('a QSY wipe leaves manual time entry, in the open Time control too, and its undo goes back into it', (tester) async {
    // The next entry is a new station on a new frequency, and stamping it with
    // the stopped clock of the one tuned away from files it at the wrong time.
    String time() => textOf(tester, 'Time (UTC)');
    await tester.pumpWidget(host());
    await tune(tester, freq: 14200);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await openControl(tester, MdiIcons.clockOutline);
    final manualDt = nowUtc().add(const Duration(hours: 6));
    final manual = '${manualDt.hour.toString().padLeft(2, '0')}:${manualDt.minute.toString().padLeft(2, '0')}';
    await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manual);
    await tester.pump();
    expect(find.byIcon(MdiIcons.pause), findsOneWidget, reason: 'a manual time is in force');

    await tune(tester, freq: 14250);
    expect(find.byIcon(MdiIcons.pause), findsNothing, reason: 'the wipe goes back to the clock');
    expect(time(), isNot(manual), reason: 'and the open control shows it');

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(textOf(tester, 'Their call'), 'W1AW');
    expect(find.byIcon(MdiIcons.pause), findsOneWidget);
    expect(time(), manual);
  });

  testWidgets("undo of a QSY wipe never resumes an earlier wipe's manual time", (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await openControl(tester, MdiIcons.clockOutline);
    final manualDt = nowUtc().add(const Duration(hours: 6));
    await tester.enterText(
      find.widgetWithText(TextField, 'Time (UTC)'),
      '${manualDt.hour.toString().padLeft(2, '0')}:${manualDt.minute.toString().padLeft(2, '0')}',
    );
    await tester.pump();
    expect(find.byIcon(MdiIcons.pause), findsOneWidget, reason: 'a manual time is in force');
    await tester.tap(find.byIcon(MdiIcons.backspaceOutline));
    await tester.pump();
    expect(find.byIcon(MdiIcons.pause), findsNothing, reason: 'the wipe goes back to the clock');

    // A new entry, on the clock, inside that wipe's undo window.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
    await tester.pump();
    await tune(tester, freq: 14250);
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();

    expect(textOf(tester, 'Their call'), 'K1ABC');
    expect(find.byIcon(MdiIcons.pause), findsNothing, reason: 'K1ABC was entered on the clock, and would log at the earlier time');
  });

  testWidgets('turning the dial right after Enter logs the contact where it was worked', (tester) async {
    // Both awaits an Enter makes on its way to the save: the interpret round
    // trip ahead of it, and the decorate hook inside it.
    Future<Map<String, dynamic>?> slowNullInterpret(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return null;
    }

    await tester.pumpWidget(
      host(
        log: baseLog().copyWith(
          decorateQsoBeforeSave: (data, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return data;
          },
        ),
        commands: CommandHooks(interpretCommand: slowNullInterpret),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 10));
    await tune(tester, freq: 14250);
    await tester.pump(const Duration(milliseconds: 80));
    await tune(tester, freq: 14240);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await qsosAfterWaiting(tester);
    expect(logged.single.data['their']['call'], 'W1AW', reason: 'a wipe under the Enter drops the contact silently');
    expect(logged.single.data['freq'], 14285);
    expect(find.byIcon(MdiIcons.undo), findsNothing, reason: 'undo would bring back a contact already logged, to be logged twice');
  });

  testWidgets('working split, the transmit frequency is no QSY', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    await tester.pumpWidget(host(radio: RadioHookup(radioService: tunedRadio, radioTransmitting: true)));
    await tune(tester, freq: 14290);
    expect(textOf(tester, 'Their call'), 'W1AW');

    // Back on receive, measured from where the entry started: taken as the
    // start, the transmit frequency would make this a QSY.
    await tester.pumpWidget(host());
    await tune(tester, freq: 14285.5);
    expect(textOf(tester, 'Their call'), 'W1AW');
  });

  testWidgets('the radio coming on line is where an entry typed before it starts', (tester) async {
    RadioHookup rig({required bool connected}) => RadioHookup(radioService: tunedRadio, hasConfiguredRadio: true, radioConnected: connected);
    await tester.pumpWidget(host(radio: rig(connected: false)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // 14285 SSB is only where the radio was last time; the rig's first
    // report is the station being typed for.
    await tester.pumpWidget(host(radio: rig(connected: true)));
    await tune(tester, freq: 7030, mode: 'CW');
    expect(textOf(tester, 'Their call'), 'W1AW');

    await tester.pump(const Duration(seconds: 3));
    await tune(tester, freq: 7030.5);
    expect(textOf(tester, 'Their call'), isEmpty);
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(tunedRadio.vfoA.freq, 7030, reason: 'undo tunes back to the station, not to last session');
  });

  testWidgets('a QSY made while an earlier contact was open wipes the entry on the way back', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          editingQso: Qso(
            uuid: 'earlier',
            operationUuid: operation.uuid,
            data: const {
              'their': {'call': 'K1ABC'},
              'freq': 14285.0,
              'mode': 'SSB',
            },
          ),
        ),
      ),
    );
    await tune(tester, freq: 7030);
    await tester.pumpWidget(host());
    await tester.pump();

    // Put back as it was, it would show 14285 over a radio on 7030 and be
    // logged on 40m at the first nudge.
    expect(textOf(tester, 'Their call'), isEmpty);
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(textOf(tester, 'Their call'), 'W1AW');
    expect(tunedRadio.vfoA.freq, 14285);
  });

  testWidgets('a packet carrying the transmit frequency ahead of its transmit flag is no QSY', (tester) async {
    var keyed = false;
    await tester.pumpWidget(
      host(
        radio: RadioHookup(radioService: tunedRadio, readStatus: () => (connected: false, transmitting: keyed)),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // One packet, as a Kenwood IF reply delivers it: the reading, then the
    // flag beside it, before any rebuild could carry either.
    tunedRadio.setVfo('vfoA', freq: 14290);
    keyed = true;
    await tester.pump();
    expect(textOf(tester, 'Their call'), 'W1AW');
  });

  testWidgets('the radio coming on line ahead of the rebuild that says so is still where the entry starts', (tester) async {
    var online = false;
    await tester.pumpWidget(
      host(
        radio: RadioHookup(radioService: tunedRadio, hasConfiguredRadio: true, readStatus: () => (connected: online, transmitting: false)),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // A network rig answers before the next frame: its first report lands
    // while the panel's own radioConnected still says offline.
    online = true;
    await tune(tester, freq: 7030, mode: 'CW');
    expect(textOf(tester, 'Their call'), 'W1AW');
  });

  testWidgets('a reading taken as the start still rescores the pills against its band', (tester) async {
    var online = false;
    final scoredBands = <String?>[];
    await tester.pumpWidget(
      host(
        radio: RadioHookup(radioService: tunedRadio, hasConfiguredRadio: true, readStatus: () => (connected: online, transmitting: false)),
        lookups: LookupHooks(
          scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
            scoredBands.add(qso['band'] as String?);
            return {'notices': <String>[], 'alerts': <String>[]};
          },
          scoreNoticeLabel: (key) => key,
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(scoredBands, ['20m']);

    // Kept rather than wiped, so the call is still there, scored against a
    // band the radio has left.
    online = true;
    await tune(tester, freq: 7040, mode: 'CW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(textOf(tester, 'Their call'), 'W1AW');
    expect(scoredBands.last, '40m');
  });

  testWidgets("a QSY wipe forgets the command line's hold on the text that was typed", (tester) async {
    Future<Map<String, dynamic>?> fakeNoteCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (!input.toUpperCase().startsWith('NOTE')) return null;
      return {'expectsParams': true, 'mixedCase': true};
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeNoteCommand)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob');
    await tester.pump(const Duration(milliseconds: 200));
    await tune(tester, freq: 14250);
    expect(textOf(tester, 'Their call'), isEmpty);

    // Still held, the next call is typed as the wiped note's free text.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'w1aw');
    expect(textOf(tester, 'Their call'), 'W1AW');
  });
}
