// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SWAP under SO2R (docs/design/logging-fields.md § SO2R): each set's entry
// goes to the other set with the frequency it was on, and the set it lands
// in tunes its radio there — through LoggingControlsController.takeEntry and
// putEntry, which the app's logging panel calls for both sets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

/// A VFO store that, like RadioService, says nothing about a write that
/// changes nothing — the harness's says something about every one.
class _QuietVfoStore extends FakeVfoStore {
  Vfo? _before;

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {
    _before = vfoA;
    super.setVfo(key, freq: freq, band: band, mode: mode, power: power, clearFreq: clearFreq, clearPower: clearPower);
  }

  @override
  void notifyListeners() {
    if (vfoA != _before) super.notifyListeners();
  }
}

void main() {
  installLoggingHarness();

  late So2rLink link;
  late FakeVfoStore radioB;
  late LoggingControlsController controllerA, controllerB;

  setUp(() {
    link = So2rLink();
    addTearDown(link.dispose);
    radioB = FakeVfoStore()..setVfo('vfoA', freq: 7025, mode: 'CW');
    addTearDown(radioB.dispose);
    controllerA = LoggingControlsController();
    controllerB = LoggingControlsController();
  });

  Widget twoSets({ControlStripSettings strip = const ControlStripSettings(), FakeVfoStore? storeA, FakeVfoStore? storeB, EnterSends? Function()? enterSends}) {
    LoggingControls set(String radio, FakeVfoStore store, LoggingControlsController controller) => LoggingControls(
      key: ValueKey('set-$radio'),
      so2r: So2rSet(radio: radio, link: link),
      log: LogHooks(operation: operation, qsosRepository: qsos),
      session: LoggingSession(controller: controller, enterSends: enterSends),
      radio: RadioHookup(radioService: store, radioUpdates: store),
      strip: strip,
      prefs: LoggingPreferences(keyboardAccessory: keyboardAccessory),
    );
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            set('A', storeA ?? tunedRadio, controllerA),
            set('B', storeB ?? radioB, controllerB),
          ],
        ),
      ),
    );
  }

  Finder callField(String radio) => find.descendant(of: find.byKey(ValueKey('set-$radio')), matching: find.widgetWithText(TextField, 'Their call'));
  String callIn(WidgetTester t, String radio) => t.widget<TextField>(callField(radio)).controller!.text;

  Future<void> swap(WidgetTester t) async {
    final a = controllerA.takeEntry()!, b = controllerB.takeEntry()!;
    controllerA.putEntry(b);
    controllerB.putEntry(a);
    await t.pump();
    await t.pump();
  }

  /// What the radio reports back, as CAT writes it: not the entry's own
  /// write, so a QSY as far as the set can tell.
  Future<void> radioReports(WidgetTester t, FakeVfoStore store, {double? freq, String? mode}) async {
    store.setVfo('vfoA', freq: freq, mode: mode);
    await t.pump();
    await t.pump();
  }

  testWidgets('each entry goes to the other set, and each radio to where the other was', (t) async {
    await t.pumpWidget(twoSets());
    await t.enterText(callField('A'), 'W1AW');
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);

    // Each call is for the station on its frequency: one left behind would
    // be logged against a station that is not there.
    expect(callIn(t, 'A'), 'K1ABC');
    expect(callIn(t, 'B'), 'W1AW');
    expect((tunedRadio.vfoA.freq, tunedRadio.vfoA.mode), (7025, 'CW'));
    expect((radioB.vfoA.freq, radioB.vfoA.mode), (14285, 'SSB'));
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets("an empty set still sends its radio across, and takes the other's entry", (t) async {
    await t.pumpWidget(twoSets());
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);

    expect(callIn(t, 'A'), 'K1ABC');
    expect(callIn(t, 'B'), isEmpty);
    expect(tunedRadio.vfoA.freq, 7025);
    expect(radioB.vfoA.freq, 14285);
    await t.pump(const Duration(seconds: 6));
  });

  // Power is the rig's, not the station's: a power that crossed with the
  // entry would log each contact at the other rig's watts. Both radios on
  // one frequency is the case to catch: the swap retunes neither, so no VFO
  // report re-reads the rig's power over what the entry brought.
  testWidgets("each set keeps its own rig's power", (t) async {
    final a = _QuietVfoStore()..setVfo('vfoA', freq: 14285, mode: 'SSB', power: 100);
    final b = _QuietVfoStore()..setVfo('vfoA', freq: 14285, mode: 'SSB', power: 5);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await t.pumpWidget(
      twoSets(
        strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power']),
        storeA: a,
        storeB: b,
      ),
    );
    await t.enterText(callField('A'), 'W1AW');
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);

    Future<Qso> logIn(String radio, int count) async {
      await t.tap(callField(radio));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      return (await waitForQsos(t, count)).last;
    }

    final loggedA = await logIn('A', 1);
    expect((loggedA.theirCall, loggedA.power), ('K1ABC', 100));
    final loggedB = await logIn('B', 2);
    expect((loggedB.theirCall, loggedB.power), ('W1AW', 5));
    expect((a.vfoA.power, b.vfoA.power), (100, 5));
    await t.pump(const Duration(seconds: 6));
  });

  // The answer is part of the contact being worked: forgotten on the way,
  // the next Enter answers the station again instead of thanking it and
  // logging.
  testWidgets('a call Enter Sends Messages has answered is still answered in the set it moves to', (t) async {
    final sent = <String>[];
    EnterSends esm() =>
        EnterSends(running: true, send: (messages, qso, {logged}) => sent.add('${messages.map((m) => m.name).join('+')} @ ${(qso['their'] as Map?)?['call']}'));
    await t.pumpWidget(twoSets(enterSends: esm));
    await t.enterText(callField('A'), 'W1AW');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(sent, ['hisCall+exchange @ W1AW']);
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);
    await t.tap(callField('B'));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(sent.last, 'thanks @ W1AW');
    expect((await waitForQsos(t, 1)).single.theirCall, 'W1AW');
    await t.pump(const Duration(seconds: 6));
  });

  // The trap: the moved entry is the set's draft on a VFO the radio has not
  // reached yet. A rig that takes the mode before the frequency reports
  // where it was in the new mode, and read as a QSY that wipes the entry
  // the operator just moved there.
  testWidgets('the radio passing through on its way there wipes neither entry', (t) async {
    await t.pumpWidget(twoSets());
    await t.enterText(callField('A'), 'W1AW');
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);
    await radioReports(t, tunedRadio, freq: 14285, mode: 'CW');
    await radioReports(t, tunedRadio, freq: 7025, mode: 'CW');
    await radioReports(t, radioB, freq: 7025, mode: 'SSB');
    await radioReports(t, radioB, freq: 14285, mode: 'SSB');

    expect(callIn(t, 'A'), 'K1ABC');
    expect(callIn(t, 'B'), 'W1AW');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a moved entry is still wiped by a real QSY once the radio has settled there', (t) async {
    await t.pumpWidget(twoSets());
    await t.enterText(callField('B'), 'K1ABC');
    await t.pump();

    await swap(t);
    await t.pump(const Duration(seconds: 4));
    await radioReports(t, tunedRadio, freq: 7040, mode: 'CW');

    expect(callIn(t, 'A'), isEmpty, reason: 'the entry moved to radio A is for the station on 7025, not 7040');
    await t.pump(const Duration(seconds: 6));
  });
}
