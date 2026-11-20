// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spot keys — ⌘↓ ⌘↑ the nearest spot up or down the band, with ⇧ the
// nearest new multiplier — as the Operation view hears them
// (docs/design/keyboard-shortcuts.md).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show DockGroup;
import 'package:intl/date_symbol_data_local.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spot_board.dart' show spotCandidateKey;
import 'package:ham2k_logger/views/operation/spot_keys.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart' show suggestedQsoFromSpot;
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> spot(String call, double freq, {String band = '20m', String mode = 'CW'}) => {
  'their': {'call': call},
  'freq': freq,
  'band': band,
  'mode': mode,
  'spot': {'timeInMillis': nowMillis()},
};

void main() {
  setUpAll(initializeDateFormatting);

  group('one press', () {
    final band = [spot('K1A', 14010), spot('K2B', 14020), spot('K3C', 14030)];
    String? step(double? freq, {required bool higher, Map<String, dynamic>? landed, double? from, List<Map<String, dynamic>>? spots}) =>
        (spotKeysStep(
                  spots ?? band,
                  freqKHz: freq,
                  higher: higher,
                  landed: landed == null ? null : (freq: (landed['freq'] as num).toDouble(), key: spotKeysKey(landed), from: from),
                )?['their']
                as Map?)?['call']
            as String?;

    test('goes to the nearest spot up or down the band from the VFO, and nowhere past its end', () {
      expect(step(14015, higher: true), 'K2B');
      expect(step(14015, higher: false), 'K1A');
      expect(step(14035, higher: true), isNull);
      expect(step(14005, higher: false), isNull);
    });

    // With no frequency there is nowhere to step from; the band's first spot
    // that way is the one the operator would reach turning the dial.
    test('starts from an end of the band when the VFO has no frequency', () {
      expect(step(null, higher: true), 'K1A');
      expect(step(null, higher: false), 'K3C');
    });

    // Zero-beat avoidance tunes a suggestion up to 75 Hz off the spot: a
    // press measured from that VFO alone would land on the same spot again.
    test('steps past the spot the VFO sits on, a zero-beat offset off it', () {
      expect(step(14019.95, higher: true), 'K3C');
      expect(step(14020.05, higher: false), 'K1A');
    });

    // Two stations spotted on one frequency: measured by frequency alone, the
    // second could never be reached.
    test('reaches every station on one frequency, stepping on from the last one landed on', () {
      final crowded = [...band, spot('K2Z', 14020)];
      expect(step(14015, higher: true, spots: crowded), 'K2B');
      expect(step(14020, higher: true, spots: crowded, landed: crowded[1]), 'K2Z');
      expect(step(14020, higher: true, spots: crowded, landed: crowded[3]), 'K3C');
      expect(step(14020, higher: false, spots: crowded, landed: crowded[3]), 'K2B');
    });

    // Logging the station landed on strikes its spot, which leaves the list.
    // Measured from the VFO then, the next press would jump past every other
    // station on that frequency.
    test('steps on from a station landed on that has left the list, to the others on its frequency', () {
      final crowded = [...band, spot('K2Z', 14020)];
      final worked = crowded.where((s) => (s['their'] as Map)['call'] != 'K2B').toList();
      expect(step(14020, higher: true, spots: worked, landed: crowded[1]), 'K2Z');
      expect(step(14020, higher: false, spots: worked, landed: crowded[3]), 'K1A');
    });

    // The suggestion tunes the VFO a frame after the press: a held key's
    // repeat can arrive first, and measured from the VFO alone it would find
    // the same spot again rather than step on.
    test('steps on from the station landed on while the VFO still stands where the press found it', () {
      expect(step(14015, higher: true, landed: band[1], from: 14015), 'K3C');
      expect(step(14016, higher: true, landed: band[1], from: 14015), 'K2B', reason: 'tuned since, by hand');
    });

    // The operator tuned away by hand since: the press is from where they
    // are now, not from a spot left behind.
    // A source reports 14020 as an integer, while the suggestion made of it
    // carries 14020.0: known by different keys, a tap's station would never
    // be found among the spots to step on from.
    test('knows a spot and the suggestion made of it as one station', () {
      final reported = {...spot('K2B', 14020), 'freq': 14020};
      expect(spotKeysKey(suggestedQsoFromSpot(reported)), spotKeysKey(reported));
    });

    test('measures from the VFO once it has left the spot last landed on', () {
      expect(step(14028, higher: false, landed: band[0]), 'K2B');
    });
  });

  group('which spots', () {
    final k1a = spot('K1A', 14010), k2b = spot('K2B', 14020), k3c = spot('K3C', 14030), ours = spot('KI2D', 14025), dx = spot('DL1ABC', 7018, band: '40m');
    final board = [k1a, k2b, k3c, ours, dx];
    final scores = {
      spotCandidateKey('K1A', k1a): (notices: <String>[], alerts: ['duplicate']),
      spotCandidateKey('K3C', k3c): (notices: ['newMult'], alerts: <String>[]),
    };
    List<String> pick({bool mult = false, Map<String, ({List<String> notices, List<String> alerts})>? judged, Map<String, num> values = const {}}) => [
      for (final s in spotKeysPick(board, band: '20m', scores: judged ?? scores, values: values, ourBaseCalls: {'KI2D'}, mult: mult))
        (s['their'] as Map)['call'] as String,
    ];

    // A worked station is no contact to make: stepping onto it costs a press
    // and, filled into the call field, a dupe the operator has to back out of.
    test('leaves out the worked, our own and other bands', () {
      expect(pick(), ['K2B', 'K3C']);
    });

    // A station out of the contest — DX in Sweepstakes — is worth no points,
    // and a press landing on it is one the operator has to press past.
    test('leaves out a station worth 0 points, and keeps one worth any', () {
      expect(pick(values: {spotCandidateKey('K2B', k2b): 0, spotCandidateKey('K3C', k3c): 2}), ['K3C']);
    });

    // CQ WW gives a station in our own country no points, and it can still be
    // a new zone: ⇧ exists to find exactly that spot.
    test('keeps a new multiplier worth 0 points, with ⇧ and without', () {
      expect(pick(mult: true, values: {spotCandidateKey('K3C', k3c): 0}), ['K3C']);
      expect(pick(values: {spotCandidateKey('K3C', k3c): 0}), ['K2B', 'K3C']);
    });

    // One operator of a multi-op spot still worth points keeps the station, as
    // one unworked operator keeps it unstruck.
    test('keeps a spot while any operator on it is worth points', () {
      final pair = spot('K4D,K5E', 14040);
      expect(
        [
          for (final s in spotKeysPick(
            [pair],
            band: '20m',
            scores: const {},
            values: {spotCandidateKey('K4D', pair): 0, spotCandidateKey('K5E', pair): 1},
            ourBaseCalls: const {},
            mult: false,
          ))
            s,
        ],
        [pair],
      );
      expect(
        spotKeysPick(
          [pair],
          band: '20m',
          scores: const {},
          values: {spotCandidateKey('K4D', pair): 0, spotCandidateKey('K5E', pair): 0},
          ourBaseCalls: const {},
          mult: false,
        ),
        isEmpty,
      );
    });

    test('with ⇧, only the new multipliers', () {
      expect(pick(mult: true), ['K3C']);
    });

    // Before the board has judged the operation nothing is known to be
    // worked, and every spot stays reachable.
    test('takes every spot before the board has judged the operation', () {
      expect(pick(judged: const {}), ['K1A', 'K2B', 'K3C']);
    });
  });

  late HaLoHarness harness;
  late HaLoServices services;

  setUp(() async {
    harness = await makeHaLoServices();
    services = harness.services;
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  });

  Future<void> pumpOperation(WidgetTester tester, {List<String> logged = const []}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    for (final (i, call) in logged.indexed) {
      await services.qsos.add(operation.uuid, {
        'their': {'call': call},
        'mode': 'CW',
        'startAtMillis': 1000 * (i + 1),
      });
    }
    await tester.pumpWidget(
      TranslationProvider(
        // The app's own actions: the spot keys' chords are Flutter's page
        // scroll too, and the app's scroll stands down for a press they took.
        child: MaterialApp(
          actions: haloAppActions,
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Ctrl, the platform's ⌘ off a Mac — the test platform is not Apple's.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey arrow) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(arrow);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  String? call(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller?.text;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 25));
  }

  // A spot on another band is not "up the band" from here, and the
  // operator's own spot suggests no one to work.
  testWidgets('suggest the next spot on the band as a tap would, and skip other bands and our own', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14015, band: '20m', mode: 'CW');
    services.spots.replaceSpots('feed', [spot('K1A', 14010), spot('KI2D', 14018), spot('DL1ABC', 7018, band: '40m'), spot('K2B', 14020)]);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(call(tester), 'K2B');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(call(tester), 'K1A');
    await unmount(tester);
  });

  // Two stations on one frequency, through the view: the second press steps
  // on from the station the first suggested, rather than past them both.
  testWidgets('reach each station spotted on one frequency, press after press', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14015, band: '20m', mode: 'CW');
    services.spots.replaceSpots('feed', [spot('K2B', 14020), spot('K2Z', 14020), spot('K3C', 14030)]);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(call(tester), 'K2B');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(call(tester), 'K2Z');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(call(tester), 'K3C');
    await unmount(tester);
  });

  bool saidNoSpots() => services.statusBar.items.any((item) => item.key == 'spot-keys:none');

  // A layout with no logging pane has nowhere to show a suggestion: a press
  // taken there would land on a spot that never appears, and keep landing on
  // it, since the VFO never moves. Measured against the same press in the
  // default layout, which says there is nothing up the band.
  testWidgets('leave the keys alone in a layout with no logging pane', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14015, band: '20m', mode: 'CW');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(saidNoSpots(), isTrue, reason: 'the default layout takes the press');
    await unmount(tester);
  });

  testWidgets('a layout of spots alone leaves the press untaken', (tester) async {
    await services.settings.setLayoutData(LayoutKeys.operationDock, DockGroup(['spots']).toJson());
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14015, band: '20m', mode: 'CW');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(saidNoSpots(), isFalse);
    await unmount(tester);
  });

  // With a logged contact loaded, ⌘↑/⌘↓ are the QSO list's ends: a spot
  // suggested there would replace the contact being looked at.
  testWidgets('leave the keys to the log while a logged contact is loaded', (tester) async {
    await pumpOperation(tester, logged: ['W1AW', 'K1ABC', 'N0DEV']);
    services.radio.setVfo('vfoA', freq: 14015, band: '20m', mode: 'CW');
    services.spots.replaceSpots('feed', [spot('K2B', 14020)]);
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(call(tester), 'N0DEV');
    // ⌘, which walks the list on every platform; with Keyboard Shortcuts off
    // it is a spot key's as Ctrl is.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(call(tester), 'W1AW', reason: "⌘↑ went to the list's end");
    await unmount(tester);
  });
}
