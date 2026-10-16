// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots in and out: the Spotting control, a suggested QSO arriving from the
// spots list or a deep link, and the row a peer sees. The tentative fill a
// slid row offers is beside this file.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('SPOTLAST resolves to the last real QSO, skipping trailing event markers (ham2k/halo-dist#10)', (tester) async {
    // `qsos` is oldest-first (matches watchForOperation's ORDER BY
    // startAtMillis) — the event marker logged after both real QSOs must
    // NOT be picked just because it's last in the list.
    final firstQso = Qso(
      uuid: 'q1',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'K1ABC'},
        'startAtMillis': 1000,
      },
    );
    final lastRealQso = Qso(
      uuid: 'q2',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1XYZ'},
        'startAtMillis': 2000,
      },
    );
    final trailingEventMarker = Qso(uuid: 'evt', operationUuid: operation.uuid, data: {'band': 'event', 'startAtMillis': 3000});

    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    final spottedQsos = <Map<String, dynamic>?>[];
    Future<Map<String, dynamic>?> fakeSpotLastCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'SPOTLAST') return null;
      return {
        'describe': 'Spot the last logged QSO?',
        'confirm': 'Spotting last QSO…',
        'commands': [
          {
            'sendSpots': {'target': 'last'},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        log: baseLog().copyWith(qsos: [firstQso, lastRealQso, trailingEventMarker]),
        commands: CommandHooks(
          interpretCommand: fakeSpotLastCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
        // Sent by the Spotting control, as SPOT is, so the button shows it in
        // flight and the source icons colour by its answers.
        spotting: SpottingHooks(
          suggestSpotSources: ({required operation, qso}) async => [
            {'hookKey': 'pota'},
          ],
          sendSpot: ({required sources, required operation, qso, freq, mode, comment, spotterCall}) async {
            spottedQsos.add(qso);
            return {
              'pota': {'ok': true},
            };
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SPOTLAST');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(spottedQsos.single?['their'], {'call': 'W1XYZ'});
    expect(dispatched.single.key, 'sendSpots', reason: 'the app still answers the command where it was typed');
    expect(dispatched.single.value, {'target': 'last'}, reason: 'a spot that went out has no failure to report');
  });

  testWidgets("a spot carries the operation's device-local data, where the multi-station identifier lives", (tester) async {
    // `ExtensionService.spotCallForSelfSpot` builds `KI2D/OP2` out of
    // `operation['local']`. Drop it from the payload and every device of a
    // multi-station operation self-spots as the same bare call — the exact
    // collision the identifier exists to prevent, and one nothing inside this
    // widget would report.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
    operation = (await operations.get(operation.uuid))!;

    final spottedOperations = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>?> fakeSpotCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'SPOT') return null;
      return {
        'describe': 'Self-spot?',
        'confirm': 'Spotting…',
        'commands': [
          {'sendSpots': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeSpotCommand),
        // A typed self-spot is the Spotting control's own, sent as its button's.
        spotting: SpottingHooks(
          suggestSpotSources: ({required operation, qso}) async => [
            {'hookKey': 'pota'},
          ],
          sendSpot: ({required sources, required operation, qso, freq, mode, comment, spotterCall}) async {
            spottedOperations.add(operation);
            return {
              'pota': {'ok': true},
            };
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SPOT');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final spotted = spottedOperations.single;
    expect((spotted['local'] as Map)['multiIdentifier'], '2');
    expect(spotted['stationCall'], 'KI2D', reason: 'the suffix is applied downstream, not here');
  });

  group('RESPOT', () {
    final sent = <double?>[];
    var accept = true;
    Future<List<Map<String, dynamic>>> oneSource({required Map<String, dynamic> operation, Map<String, dynamic>? qso}) async => [
      {'hookKey': 'pota', 'icon': 'pine-tree'},
    ];
    Future<Map<String, Map<String, dynamic>>> recordingSend({
      required List<Map<String, dynamic>> sources,
      required Map<String, dynamic> operation,
      Map<String, dynamic>? qso,
      double? freq,
      String? mode,
      String? comment,
      String? spotterCall,
    }) async {
      sent.add(freq);
      return {
        'pota': {'ok': accept},
      };
    }

    Future<Map<String, dynamic>?> fakeRespot(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'RESPOT') return null;
      return {
        'confirm': 'Re-spotting every 5 min',
        'commands': [
          {
            'autoRespot': {'minutes': 5},
          },
        ],
      };
    }

    Future<void> runRespot(WidgetTester tester, {CommandActionHandler? onCommandAction}) async {
      await tester.pumpWidget(
        host(
          commands: CommandHooks(interpretCommand: fakeRespot, onCommandAction: onCommandAction),
          spotting: SpottingHooks(suggestSpotSources: oneSource, sendSpot: recordingSend),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RESPOT');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
    }

    setUp(() {
      sent.clear();
      accept = true;
      // Respots are timed on the real clock, which the widget-test zone only
      // moves when followed.
      AppClock.followZoneClock = true;
    });
    tearDown(() => AppClock.followZoneClock = false);

    // The command must drive the Spotting control's own auto-respotting, not
    // a second one beside it: otherwise the chip would not say so, its Stop
    // button would not stop it, and a QSY would leave it spotting a
    // frequency the operator has left.
    testWidgets('spots now and turns the Spotting chip to auto re-spot; moving the VFO stops it', (tester) async {
      await runRespot(tester);
      expect(sent, [14285]);
      expect(find.text('Auto re-spot'), findsOneWidget);
      await tester.tap(find.text('Auto re-spot'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Auto in 5:00. Stop?'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1, seconds: 15));
      expect(find.text('Auto in 3:45. Stop?'), findsOneWidget);
      await tester.pump(const Duration(minutes: 3, seconds: 46));
      expect(sent, [14285, 14285], reason: 'five minutes, as asked');

      tunedRadio.setVfo('vfoA', freq: 7200);
      await tester.pump();
      expect(find.text('Auto re-spot'), findsNothing);
      await tester.pump(const Duration(minutes: 11));
      expect(sent, hasLength(2));
    });

    testWidgets('a spot that does not go through says so instead of confirming', (tester) async {
      accept = false;
      await runRespot(tester);
      expect(find.textContaining('pota failed'), findsOneWidget);
      expect(find.text('Auto re-spot'), findsNothing);
      await tester.pump(const Duration(minutes: 11));
      expect(sent, hasLength(1), reason: 'nothing to repeat');
    });

    // The setting reaches the panel as a new widget; a running auto re-spot
    // that only read it on starting would go on at the old interval.
    testWidgets('a bare RESPOT follows the interval setting, changed while it runs', (tester) async {
      Future<Map<String, dynamic>?> bareRespot(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async =>
          input.trim().toUpperCase() != 'RESPOT'
          ? null
          : {
              'commands': [
                {'autoRespot': <String, dynamic>{}},
              ],
            };
      Widget panel(int minutes) => host(
        commands: CommandHooks(interpretCommand: bareRespot),
        spotting: SpottingHooks(
          suggestSpotSources: oneSource,
          sendSpot: recordingSend,
          respotInterval: Duration(minutes: minutes),
        ),
      );
      await tester.pumpWidget(panel(10));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RESPOT');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sent, [14285]);
      await tester.pumpWidget(panel(20));
      await tester.pump(const Duration(minutes: 11));
      expect(sent, hasLength(1), reason: 'twenty minutes now, not ten');
      await tester.pump(const Duration(minutes: 9, seconds: 1));
      expect(sent, hasLength(2));
    });

    // The app answers a command where it was typed: from the palette, a
    // notice in the call field would land behind it, under the hook's
    // "Re-spotting every 5 min".
    testWidgets("with an app to answer it, the failure goes there rather than to the call field", (tester) async {
      accept = false;
      final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
      await runRespot(tester, onCommandAction: (action, [params]) async => dispatched.add(MapEntry(action, params)));
      expect(dispatched.single.key, 'autoRespot');
      expect(dispatched.single.value!['failure'], contains('pota failed'));
      expect(find.textContaining('pota failed'), findsNothing);
    });
  });

  group('Spotting settings button', () {
    Future<List<Map<String, dynamic>>> noSources({required Map<String, dynamic> operation, Map<String, dynamic>? qso}) async => [];
    Future<Map<String, Map<String, dynamic>>> noopSend({
      required List<Map<String, dynamic>> sources,
      required Map<String, dynamic> operation,
      Map<String, dynamic>? qso,
      double? freq,
      String? mode,
      String? comment,
      String? spotterCall,
    }) async => {};

    Future<void> openSpotting(WidgetTester tester, SpottingHooks spotting) async {
      await tester.pumpWidget(host(spotting: spotting));
      await tester.pump();
      await tester.tap(find.text('Self-spotting'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the Spotting settings from the end of the row', (tester) async {
      var opened = 0;
      await openSpotting(tester, SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend, onOpenSettings: () => opened++));
      await tester.tap(find.byKey(const ValueKey('spottingSettingsButton')));
      expect(opened, 1);
    });

    // A host with nowhere to keep the settings must not offer a button that
    // does nothing.
    testWidgets('is not there without settings to open', (tester) async {
      await openSpotting(tester, SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend));
      expect(find.byKey(const ValueKey('spottingSettingsButton')), findsNothing);
    });
  });

  group('Spotting control pill label', () {
    // The collapsed pill is always one of the two short, fixed labels —
    // never the longer dynamic button text ("Self-spot at 7.200", "First
    // set a frequency to spot", "Spot KN2X at 7.200", "Too late to spot
    // KN2X"), which is reserved for the button inside the expanded panel.
    Future<List<Map<String, dynamic>>> noSources({required Map<String, dynamic> operation, Map<String, dynamic>? qso}) async => [];
    Future<Map<String, Map<String, dynamic>>> noopSend({
      required List<Map<String, dynamic>> sources,
      required Map<String, dynamic> operation,
      Map<String, dynamic>? qso,
      double? freq,
      String? mode,
      String? comment,
      String? spotterCall,
    }) async => {};

    testWidgets('shows "Self-spotting" with no frequency set', (tester) async {
      await tester.pumpWidget(
        host(
          spotting: SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend),
        ),
      );
      await tester.pump();
      expect(find.text('Self-spotting'), findsOneWidget);
      expect(find.text('First set a frequency to spot'), findsNothing);
    });

    testWidgets('shows "Self-spotting" (not "Self-spot at ...") once a frequency is set', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285);
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: fakeRadio),
          spotting: SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend),
        ),
      );
      await tester.pump();
      expect(find.text('Self-spotting'), findsOneWidget);
      expect(find.textContaining('Self-spot at'), findsNothing);
    });

    testWidgets('shows "Spotting" (not "Spot ... at ..." or "Too late") while editing a recent QSO', (tester) async {
      final recentQso = Qso(
        uuid: 'recent',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'KN2X'},
          'freq': 14285,
          'startAtMillis': DateTime.now().millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: recentQso),
          spotting: SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend),
        ),
      );
      await tester.pump();
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.textContaining('Spot KN2X'), findsNothing);
    });

    testWidgets('shows "Spotting" (not "Too late...") while editing a stale QSO', (tester) async {
      final staleQso = Qso(
        uuid: 'stale',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'KN2X'},
          'freq': 14285,
          'startAtMillis': DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: staleQso),
          spotting: SpottingHooks(suggestSpotSources: noSources, sendSpot: noopSend),
        ),
      );
      await tester.pump();
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.textContaining('Too late'), findsNothing);
    });
  });

  testWidgets('a suggestedQso populates call/freq/band/mode for a new QSO', (tester) async {
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
      ),
    );

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(find.text('20m'), findsWidgets);
  });

  testWidgets('a suggestedQso carrying startAtMillis logs at that time, not at now', (tester) async {
    // A `/qso` deep link reports when a contact ACTUALLY happened — a WSJT-X
    // bridge hands over a QSO already made — so composing it at "now" files
    // it minutes late. The suggestion's time has to become the manual time,
    // exactly as if the operator had typed it.
    const madeAt = 1750000000000;
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
            'startAtMillis': madeAt,
          },
        ),
      ),
    );
    await tester.pump();
    // The suggestion fills the field without focusing it, and Enter is
    // delivered to whatever has focus.
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.startAtMillis, madeAt);
  });

  testWidgets('a suggestedQso with no startAtMillis does not inherit the last one', (tester) async {
    // A spot says nothing about when a contact happens. Without the explicit
    // clear, a spot tapped after a deep link would log at the LINK's time.
    const madeAt = 1750000000000;
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
            'startAtMillis': madeAt,
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'K1ABC');
    expect(logged.single.startAtMillis, isNot(madeAt));
  });

  testWidgets('HALO-32: applying a suggestedQso with no mode of its own never runs the band-plan guess', (tester) async {
    // tunedRadio (host()'s default) seeds Mode as SSB; 14074 kHz is FT8
    // territory per the band plan, but this suggestion carries no mode of
    // its own — applying it must leave the mode exactly as-is, not guess
    // FT8 from the frequency. This is the cold-start (initState) path,
    // where `_applySuggestedQso` runs before `_onFreqChanged`'s listener is
    // even attached — so on its own this only proves the guess doesn't fire
    // when it structurally can't. The next test below covers the path where
    // it structurally could.
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
          },
        ),
      ),
    );
    await tester.pump();

    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('HALO-32: a second suggestedQso (didUpdateWidget, listener already attached) still never guesses the mode', (tester) async {
    // Unlike the cold-start case above, a suggestedQso arriving via
    // didUpdateWidget (a second spot tapped on an already-mounted widget,
    // line ~1807) runs AFTER `_onFreqChanged`'s listener is attached — the
    // one path where a broken populate guard would actually let a
    // stray band-plan guess through. Build with no suggestion first so the
    // widget is fully mounted (Mode defaults to SSB, per tunedRadio), then
    // apply a suggestion with a frequency but no mode.
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0, // FT8 territory per the band plan
          },
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('a suggestedQso moves the VFO, so a connected radio follows the spot', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();

    // Tapping a spot is specific intent — "work THIS station" — so it takes
    // the radio there, rather than only filling in the form.
    expect(fakeRadio.vfoA.freq, 14074.0);
    expect(fakeRadio.vfoA.mode, 'FT8');
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('tapping a second spot moves the VFO again', (tester) async {
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();
    expect(fakeRadio.vfoA.freq, 14074.0);

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 7035.0,
            'mode': 'CW',
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();

    expect(fakeRadio.vfoA.freq, 7035.0);
    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('HALO-58: a spot tap focuses the callsign field, so Enter can log the suggested QSO', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(host());
      // The tap that produces a suggestion lands in the Spots pane, outside
      // the logging fields — without this unfocus, the call field's own
      // autofocus keeps the assertion green with the fix deleted.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: {
              'their': {'call': 'W1AW'},
              'freq': 14074.0,
              'mode': 'FT8',
            },
          ),
        ),
      );
      await tester.pump();

      final callField = find.widgetWithText(TextField, 'Their call');
      expect(tester.widget<TextField>(callField).focusNode!.hasFocus, isTrue);

      // The point of the focus: Enter, with nothing else touched, logs the
      // suggested contact. Driven the way the engine submits (receiveAction),
      // which needs the field's input connection — absent when nothing holds
      // focus.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(callField).controller!.text, isEmpty); // wiped: the QSO was logged
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-58: on mobile a spot tap leaves focus alone (no uninvited virtual keyboard)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(host());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: {
              'their': {'call': 'W1AW'},
              'freq': 14074.0,
              'mode': 'FT8',
            },
          ),
        ),
      );
      await tester.pump();

      // The suggestion still filled the field — it just didn't grab focus,
      // which on a phone would pop the keyboard over the call info the tap
      // surfaced (docs/design/logging-fields.md's mobile carve-out).
      final callField = find.widgetWithText(TextField, 'Their call');
      expect(tester.widget<TextField>(callField).controller!.text, 'W1AW');
      expect(tester.widget<TextField>(callField).focusNode!.hasFocus, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: mobile with no hardware keyboard starts with no field focused', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // The carve-out itself: an unconditional autofocus here means every
      // phone opens the operation view with the virtual keyboard already up.
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: a hardware keyboard restores the callsign autofocus on mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    hardwareKeyboardAttached.value = true;
    try {
      // With a physical keyboard there is no virtual keyboard to pop, so the
      // desktop rule applies: the callsign field is the default focus.
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isTrue);
    } finally {
      hardwareKeyboardAttached.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: with a hardware keyboard, a spot tap focuses the callsign on mobile too', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    hardwareKeyboardAttached.value = true;
    try {
      await tester.pumpWidget(host());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: {
              'their': {'call': 'W1AW'},
              'freq': 14074.0,
              'mode': 'FT8',
            },
          ),
        ),
      );
      await tester.pump();

      // The keyboard clause, not the platform clause: dropping
      // `hardwareKeyboardAttached` from the spot-tap guard leaves an iPad
      // keyboard user unable to press Enter after tapping a spot.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isTrue);
    } finally {
      hardwareKeyboardAttached.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('clicking into the frequency field after a spot does not switch live follow off', (tester) async {
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();
    await openControl(tester, MdiIcons.radio);

    // The suggestion wrote the field under the populate bracket. If that write
    // didn't move the edit baseline, this bare cursor placement reads as an
    // edit and live follow silently stops.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pumpAndSettle();

    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('the suggestion push does not notify listeners during the build phase', (tester) async {
    // Reproduces what the real app hit: SpotsPanel listens to the VFO and
    // calls setState when it changes. `_applySuggestedQso` runs from
    // initState and didUpdateWidget — both inside the build phase — so
    // pushing synchronously made that setState land mid-build, which
    // Flutter refuses. It surfaced only in the log, because ErrorPolicy
    // classes it logOnly.
    Widget tree(Map<String, dynamic> suggestion) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            VfoWatcher(store: fakeRadio),
            Expanded(
              child: LoggingControls(
                log: baseLog(),
                session: LoggingSession(suggestedQso: suggestion),
                radio: RadioHookup(radioService: fakeRadio, radioUpdates: fakeRadio),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      tree({
        'their': {'call': 'W1AW'},
        'freq': 14074.0,
        'mode': 'FT8',
      }),
    );
    await tester.pumpAndSettle();

    // A second spot, which is what drives didUpdateWidget.
    await tester.pumpWidget(
      tree({
        'their': {'call': 'K1ABC'},
        'freq': 7035.0,
        'mode': 'CW',
      }),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fakeRadio.vfoA.freq, 7035.0, reason: 'deferred, but it still lands');
  });

  testWidgets('a suggestion carrying no radio state leaves the VFO alone', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();

    // A bare callsign — a deeplink, say — says nothing about where to tune,
    // and must not retune a connected radio to nowhere.
    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.mode, 'SSB');
  });

  testWidgets('a suggestion while editing an existing QSO does not move the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
      },
    );

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          editingQso: existingQso,
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 21000.0,
            'mode': 'CW',
          },
        ),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await tester.pump();

    expect(fakeRadio.vfoA.freq, 14285, reason: 'the suggestion was ignored, so the VFO is too');
  });

  testWidgets('a suggestedQso is ignored while editingQso is set — it never clobbers an in-progress edit', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
      },
    );

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          editingQso: existingQso,
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 14074.0,
          },
        ),
      ),
    );

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
  });

  testWidgets('a new suggestedQso (different Map instance) re-applies over the previous one', (tester) async {
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
          },
        ),
      ),
    );
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'K1ABC'},
            'freq': 7100.0,
          },
        ),
      ),
    );
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'K1ABC');
  });

  testWidgets('selecting a suggestedQso (spot/deeplink) triggers a lookup, not just population (#315)', (tester) async {
    // #315: tapping a spot populates the call field but must also run a
    // callsign lookup — the same as if the operator had typed the call.
    // Regressed because _applySuggestedQso populated under the bracket,
    // which suppresses _onCallChanged's own lookup, and never scheduled one.
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      lookups++;
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    Widget build({Map<String, dynamic>? suggestedQso}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          session: LoggingSession(suggestedQso: suggestedQso),
          radio: baseRadio(),
          lookups: LookupHooks(lookup: lookup, callLocationLine: (guess) => guess['location'] as String?),
        ),
      ),
    );

    // A live logging panel with nothing entered yet — no call, no lookup.
    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 0);

    // A spot is tapped, delivering a suggestedQso (a new Map instance, as the
    // real spot flow does — didUpdateWidget → _applySuggestedQso).
    await tester.pumpWidget(
      build(
        suggestedQso: {
          'their': {'call': 'W1AW'},
          'freq': 14074.0,
          'mode': 'FT8',
        },
      ),
    );
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    // The populated call must be looked up, exactly as typing it would.
    expect(lookups, 0); // debounced — nothing yet
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 2); // offline + online pass
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  // The slid-right spot action reaches this panel as `logRequest`. Its whole
  // promise is that a contact ends up in the log, made from a surface the
  // operator is NOT looking at — so every way it can quietly not happen is a
  // contact they believe they made and did not.
  group('a log request from the spots list', () {
    testWidgets('is not swallowed while a QSO is being edited', (tester) async {
      // The regression: `didUpdateWidget` returns early whenever `editingQso`
      // is set — an ordinary two-pane state with the spots list still on
      // screen — so the request was consumed and never retried. The gesture
      // had already fired its heavy haptic and closed the row.
      var asked = 0;
      bool? askedAboutEditing;
      final edited = Qso(
        uuid: 'q1',
        operationUuid: operation.uuid,
        data: const {
          'their': {'call': 'W1AW'},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: edited)));
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            editingQso: edited,
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              askedAboutEditing = editing;
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      expect(asked, 1, reason: 'the request reached the panel instead of being dropped');
      expect(askedAboutEditing, isTrue, reason: 'and it knows an edit is what is at risk');
    });

    testWidgets('asks before overwriting a part-typed entry', (tester) async {
      var asked = 0;
      bool? askedAboutEditing;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              askedAboutEditing = editing;
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      expect(asked, 1, reason: 'a half-typed contact is work too, and it is about to be wiped');
      expect(askedAboutEditing, isFalse, reason: 'nothing is being edited — this is a fresh entry');
    });

    testWidgets('a part-typed entry with no callsign is scaffolding, not work', (tester) async {
      // A grid, a frequency or a reference with no station attached is what
      // the operator left lying around, not a contact in progress — prompting
      // over it teaches them to dismiss the prompt. The mutation this catches
      // is widening the guard back to every composed field.
      var asked = 0;

      await tester.pumpWidget(host(prefs: LoggingPreferences(showGridField: true)));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN31pr');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return true;
            },
          ),
          prefs: LoggingPreferences(showGridField: true),
        ),
      );

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0, reason: 'no station was being composed, so there was nothing to ask about');
      expect(logged.single.data['their']['call'], 'K1ABC');
      expect(
        (logged.single.data['their'] as Map)['grid'],
        anyOf(isNull, ''),
        reason: 'the stray grid belonged to nobody — the spot replaces it rather than inheriting it',
      );
    });

    testWidgets('the prompt is a real route here too', (tester) async {
      // Same failure class as the peek's prompt: this ask is also made from
      // didUpdateWidget, so it also has to leave the frame before pushing.
      Future<bool> ask({required bool editing}) async {
        final context = tester.element(find.byType(LoggingControls));
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('Clear it?'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Go back'))],
          ),
        );
        return answer ?? false;
      }

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Clear it?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
    });

    testWidgets('leaves the focus alone, so a phone does not raise its keyboard', (tester) async {
      // The wipe that follows a log focuses the call field — right when the
      // operator is typing here, wrong when the contact was logged by a
      // gesture made on another surface. On a phone that focus is a keyboard,
      // thrown up over the spots list they are still working.
      final field = find.widgetWithText(TextField, 'Their call').first;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
          ),
        ),
      );
      await waitForQsos(tester, 1);
      await tester.pump();

      expect(tester.widget<TextField>(field).controller?.text, isEmpty, reason: 'logged and wiped');
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);
    });

    testWidgets('nor after clearing the way at the prompt, nor when it cannot log at all', (tester) async {
      // The other two ways this route ends. Both reach for the call field to
      // say something to an operator who is not standing in front of it.
      final field = find.widgetWithText(TextField, 'Their call').first;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(field, 'W9XYZ');
      await tester.pump();
      // Typing leaves the field focused; the operator then went to the spots
      // list, which is where the gesture below is made from. Without this the
      // test would be asserting about focus that was already theirs.
      tester.widget<TextField>(field).focusNode?.unfocus();
      await tester.pump();

      // Clear-and-log: the wipe that makes room for the spot.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ({required bool editing}) async => true,
          ),
        ),
      );
      await waitForQsos(tester, 1);
      await tester.pump();

      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse, reason: 'cleared and logged');

      // A spot carrying nothing loggable: `_log` bails, pointing at the field
      // that would have to be fixed — which on a phone is a keyboard over the
      // list, for a station the operator can do nothing about from there.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 2,
              qso: const {
                'their': {'call': ''},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse, reason: 'nothing to log, nothing to say here');
    });

    testWidgets('logs straight away when there is nothing to lose', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            logRequest: (
              serial: 1,
              qso: const {
                'their': {'call': 'K1ABC'},
                'band': '20m',
                'mode': 'SSB',
              },
            ),
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return true;
            },
          ),
        ),
      );

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0, reason: 'an empty panel has nothing worth interrupting the operator over');
      expect(logged.single.data['their']['call'], 'K1ABC');
    });
  });

  group('the row a peer sees', () {
    // The producing half of HALO-395, against the real controls rather than a
    // hand-built payload: what a peer renders is only as honest as what this
    // publishes.

    testWidgets('a report the operator never touched travels as a hint, not a value', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(host(session: LoggingSession(onPeerDraftChanged: (_, fields) => rows.add(fields))));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      final row = rows.last;
      final sent = row.firstWhere((f) => f.key == 'sent');
      // The trap: the DRAFT carries '59' here either way, because
      // `_rstOrDefault` folds the placeholder in. Only the empty value beside
      // a populated hint says the operator did not answer it.
      expect(sent.value, isEmpty);
      expect(sent.hint, isNotEmpty);
      expect(row.firstWhere((f) => f.key == 'call').value, 'KN2X');
    });

    testWidgets('a report typed over its own placeholder becomes the operator\'s answer', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(host(session: LoggingSession(onPeerDraftChanged: (_, fields) => rows.add(fields))));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();
      final before = rows.last.firstWhere((f) => f.key == 'sent');

      // Typing exactly what the placeholder already showed. Nothing in the
      // draft moves; this must still be reported, or the panel can never show
      // a deliberate report as deliberate.
      await tester.enterText(find.byType(TextField).at(1), before.hint!);
      await tester.pump();

      expect(rows.last.firstWhere((f) => f.key == 'sent').value, before.hint);
    });

    testWidgets('the row is the operator\'s own order, so switchSentRcvd travels', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(
        host(
          session: LoggingSession(onPeerDraftChanged: (_, fields) => rows.add(fields)),
          prefs: LoggingPreferences(switchSentRcvd: true),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      expect(rows.last.map((f) => f.key).take(3), ['call', 'rcvd', 'sent']);
    });

    testWidgets('a field the operator switched on joins the row', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(
        host(
          session: LoggingSession(onPeerDraftChanged: (_, fields) => rows.add(fields)),
          prefs: LoggingPreferences(showStateField: true),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      expect(rows.last.map((f) => f.key), contains('state'));
    });

    testWidgets('a host with nothing to tell is never asked', (tester) async {
      // The null gate is what keeps the whole path off the keystroke route.
      var built = 0;
      await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: (_) => built++)));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();
      expect(built, greaterThan(0), reason: 'the draft path itself still works');
    });
  });
}
