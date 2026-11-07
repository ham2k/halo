// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The VFO keys — ⌥↓ ⌥↑ a fine step, with ⇧ a coarse one — as the Operation
// and Chasing views hear them (docs/design/keyboard-shortcuts.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show ArrowKeysOwner, keyEventTaken;
import 'package:intl/date_symbol_data_local.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/vfo_keys.dart';
import 'package:ham2k_logger/services/radio_service.dart' show VfoOrigin;
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/chase_view.dart';
import 'package:ham2k_logger/views/operation/log_find_bar.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  // A loaded contact shows its call info, which formats dates.
  setUpAll(initializeDateFormatting);

  group('one step', () {
    // Phone signals sit kilohertz apart, CW and data ones tens of hertz: one
    // step for every mode is either useless on one or crawling on the other.
    test('is ten times finer on CW and the data modes than on phone', () {
      expect(vfoKeyStepHz('CW', coarse: false), 10);
      expect(vfoKeyStepHz('FT8', coarse: false), 10);
      expect(vfoKeyStepHz('USB', coarse: false), 100);
      expect(vfoKeyStepHz('CW', coarse: true), 100);
      expect(vfoKeyStepHz('USB', coarse: true), 1000);
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

  /// An operation with [logged] contacts in it, oldest first.
  Future<void> pumpOperation(WidgetTester tester, {List<String> logged = const []}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    for (final (i, call) in logged.indexed) {
      await services.qsos.add(operation.uuid, {
        'their': {'call': call},
        'mode': 'USB',
        'startAtMillis': 1000 * (i + 1),
      });
    }
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey arrow, {bool shift = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(arrow);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 100));
  }

  TextField callField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));

  // Past the lookup queue's wait for an extension runtime that never boots
  // here: a loaded contact queues a lookup that holds a timer that long.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 25));
  }

  // Each press from where the last one landed, not from the radio's last
  // report: with no radio behind the VFO there is none, and with one a
  // press in a row would start again from a frequency already left.
  testWidgets('step from the grid line behind, and add up press after press', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14025.374, mode: 'CW');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, closeTo(14025.380, 1e-6));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, closeTo(14025.390, 1e-6));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(services.radio.vfo('vfoA').freq, closeTo(14025.380, 1e-6));
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(services.radio.vfo('vfoA').freq, closeTo(14025.400, 1e-6));
    await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
    expect(services.radio.vfo('vfoA').freq, closeTo(14025.300, 1e-6));
    await unmount(tester);
  });

  testWidgets("under SO2R it tunes the set the operator is in, and leaves the other's", (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    services.radio.setVfo('vfoB', freq: 7200, mode: 'LSB');
    services.cat.noteOperatorRadio('B');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, 14250);
    expect(services.radio.vfo('vfoB').freq, closeTo(7200.1, 1e-6));
    await unmount(tester);
  });

  // A text field other than the logging fields — the Find bar, a note — uses
  // every arrow: ⌥↑ pages the Find bar's matches, ⇧⌥↑ selects in a note.
  // Tuning as well would move the radio off the station being worked.
  testWidgets('leave the arrows, with any modifier, to a text field outside the logging fields', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(LogFindBar), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await unmount(tester);
  });

  // The logging fields hear the press after the VFO's handler, which cannot
  // stop it: a press it tuned on and left unmarked also moves the field's
  // caret (⌥↑ on a Mac sends it to the start of the call) or selects.
  testWidgets('mark a press it tuned on as taken', (tester) async {
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    final taken = <bool>[];
    bool handler(KeyEvent event) {
      if (event is! KeyDownEvent || !onVfoKey(event, radio: services.radio, statusBar: services.statusBar, vfo: 'vfoA', qsoLoaded: false)) {
        return false;
      }
      taken.add(keyEventTaken(event));
      return true;
    }

    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));
    await tester.pumpWidget(const SizedBox());
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(services.radio.vfo('vfoA').freq, closeTo(14249.9, 1e-6));
    expect(taken, [true]);
    await unmount(tester);
  });

  // The same, through the Operation view's own handler and the call field's
  // ladder: ⇧⌥↑ there also selects to the start of the call, and the next
  // letter typed replaces it.
  testWidgets('tune from the call field, and leave its text unselected', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
    expect(services.radio.vfo('vfoA').freq, 14249);
    expect(callField(tester).controller?.selection, const TextSelection.collapsed(offset: 4));
    await unmount(tester);
  });

  // With a logged contact loaded the panel shows it, not the VFO: a tune
  // would move the radio with nothing on screen to say so, while the
  // operator expects ⌥↑ to page the log as it does everywhere else.
  testWidgets('leave every key to the log while a logged contact is loaded', (tester) async {
    await pumpOperation(tester, logged: ['W1AW', 'K1ABC', 'N0DEV']);
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(callField(tester).controller?.text, 'N0DEV');
    await press(tester, LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(callField(tester).controller?.text, 'W1AW', reason: '⌥↑ paged the log');
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await unmount(tester);
  });

  // A dialog or a pushed route over the operation has the keyboard: a tune
  // behind it would move the radio while the operator works in the dialog.
  testWidgets('tune nothing with a dialog over the operation', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(OperationView)),
        builder: (_) => const AlertDialog(content: Text('over')),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await unmount(tester);
  });

  // With no radio and a band picked by name there is nothing to step from;
  // a press that did nothing with no word why reads as a broken key.
  testWidgets('say so on the status bar with no frequency to step from', (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', band: '20m', mode: 'USB', clearFreq: true);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, isNull);
    expect(services.statusBar.itemForKey('vfo-keys:no-frequency'), isNotNull);
    await unmount(tester);
  });

  // A radio's last report outlives its connection: stepping from one on
  // 40m after the operator picked 20m would put the next contact back on 40m.
  testWidgets("step from the radio's report only while it is on the VFO's band", (tester) async {
    await pumpOperation(tester);
    services.radio.setVfo('vfoA', freq: 7074, mode: 'USB', origin: VfoOrigin.radio);
    services.radio.setVfo('vfoA', band: '40m', clearFreq: true);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, closeTo(7074.1, 1e-6));
    services.radio.setVfo('vfoA', band: '20m', clearFreq: true);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(services.radio.vfo('vfoA').freq, isNull);
    expect(services.radio.vfo('vfoA').band, '20m');
    await unmount(tester);
  });

  // A scene knob or slider steps on the arrows whatever the modifiers: the
  // VFO stepping on the same press would move both. A disabled one steps on
  // nothing, and a press left to it would do nothing at all.
  testWidgets('leave the arrows, with any modifier, to a control that steps on them while it can', (tester) async {
    services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Future<void> pumpControl({required bool enabled}) async {
      await tester.pumpWidget(
        ArrowKeysOwner(
          owns: enabled,
          child: Focus(focusNode: focus, autofocus: true, child: const SizedBox()),
        ),
      );
      await tester.pump();
    }

    bool handler(KeyEvent event) =>
        event is KeyDownEvent && onVfoKey(event, radio: services.radio, statusBar: services.statusBar, vfo: 'vfoA', qsoLoaded: false);
    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));
    await pumpControl(enabled: true);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(services.radio.vfo('vfoA').freq, 14250);
    await pumpControl(enabled: false);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(services.radio.vfo('vfoA').freq, closeTo(14249.9, 1e-6));
    await unmount(tester);
  });

  // Chasing is tuning to spots and logging what is heard there: the same
  // keys as in an operation. On radio1 even under SO2R: the operator's set
  // is what an operation's panel last reported, and may be no set Chasing
  // shows.
  testWidgets('tune radio1 in the Chasing view as well', (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    await pumpHaLo(
      tester,
      (services) => ChaseView(services: services),
      harness: harness,
      size: const Size(1400, 900),
    );
    await settleFrames(tester);
    // As an operation left in set B, its panel's report outliving it.
    services.cat.noteOperatorRadio('B');
    services.radio.setVfo('vfoA', freq: 7030, mode: 'CW');
    services.radio.setVfo('vfoB', freq: 14030, mode: 'CW');
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(services.radio.vfo('vfoA').freq, closeTo(7030.1, 1e-6));
    expect(services.radio.vfo('vfoB').freq, 14030);
    await unmount(tester);
  });
}
