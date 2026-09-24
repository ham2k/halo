// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// RadioControlModel on its own — the frequency/band/mode rules and the VFO
// mirror, with no panel around them. The widget suite in
// logging_controls_radio_test.dart exercises the same rules through the fields;
// these pin the model's contract where a panel would hide which side moved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_draft.dart';
import 'package:halo_widgets/src/logging_controls_radio.dart';
import 'package:halo_widgets/src/logging_controls_types.dart';
import 'package:halo_widgets/src/mdi_icons.g.dart';

class _FakeVfoStore implements VfoStore {
  Vfo _vfoA = const Vfo();
  final calls = <String>[];
  final powerCalls = <String>[];

  @override
  Vfo get vfoA => _vfoA;

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {
    calls.add('freq=$freq band=$band mode=$mode clearFreq=$clearFreq');
    if (power != null || clearPower) powerCalls.add('power=$power clear=$clearPower');
    final watts = clearPower ? null : (power ?? _vfoA.power);
    if (freq != null) {
      _vfoA = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? _vfoA.mode, power: watts);
    } else if (band != null || clearFreq) {
      _vfoA = Vfo(band: band ?? _vfoA.band, mode: mode ?? _vfoA.mode, power: watts);
    } else {
      _vfoA = Vfo(freq: _vfoA.freq, band: _vfoA.band, mode: mode ?? _vfoA.mode, power: watts);
    }
  }
}

class _Harness {
  final store = _FakeVfoStore();
  Qso? editingQso;
  bool hasConfiguredRadio = false;
  bool radioConnected = false;
  bool powerInPlay = false;

  /// Only its populating bracket is read by the model under test; the
  /// draft's own data paths are never asked, so it has nothing to read.
  late final draft = QsoDraft(config: () => throw UnsupportedError('the draft is not read here'));
  int rescores = 0;
  int notifications = 0;
  late final model =
      RadioControlModel(
          config: () => (
            radio: RadioHookup(
              radioService: store,
              hasConfiguredRadio: hasConfiguredRadio,
              radioConnected: radioConnected,
              ourItuRegion: 2,
              ourCountryCode: 'US',
            ),
            powerInPlay: () => powerInPlay,
            editingQso: editingQso,
          ),
          draft: draft,
          onRescore: () => rescores++,
        )
        ..addListener(() => notifications++)
        ..bind();
}

void main() {
  testWidgets('a frequency names its band, and a band picked by hand only stands without one', (tester) async {
    final h = _Harness();
    h.model.setBand('40m');
    expect(h.model.band, '40m');
    h.model.freqController.text = '14285';
    expect(h.model.band, '20m', reason: 'the frequency outranks the manual band');
    expect(h.model.manualBand, isNull, reason: 'a typed frequency retires the manual band');
    h.model.freqController.clear();
    expect(h.model.band, '20m', reason: 'clearing the field keeps the band it was last on');
    h.model.dispose();
  });

  testWidgets('a record with no band stays bandless, whatever frequency the operator last typed', (tester) async {
    final h = _Harness();
    h.model.freqController.text = '14074';
    h.draft.populate(() {
      h.model.setBand(null);
      expect(h.model.band, isNull, reason: 'the empty-field fallback must not refill a null band');
      expect(h.model.freq, isNull);
      h.model.setBand('40m');
      expect(h.model.band, '40m');
    });
    h.model.dispose();
  });

  testWidgets('typing a frequency guesses the mode from the band plan and pushes after the debounce', (tester) async {
    final h = _Harness();
    h.model.freqController.text = '14074';
    expect(h.model.mode, 'FT8');
    expect(h.model.freqTouched, isTrue, reason: 'the operator\'s edit is newer than the VFO');
    expect(h.store.calls, isEmpty, reason: 'a keystroke is debounced, not pushed');
    await tester.pump(const Duration(seconds: 5));
    expect(h.store.calls, ['freq=14074.0 band=20m mode=FT8 clearFreq=false']);
    expect(h.model.freqTouched, isFalse, reason: 'pushed means the field and the VFO agree again');
    expect(h.rescores, greaterThan(0), reason: 'band and mode moved, so the notices are stale');
    expect(h.notifications, greaterThan(0), reason: 'the panel repaints from the notification, not from the field');
    h.model.dispose();
  });

  testWidgets('a programmatic write neither guesses a mode nor arms a push', (tester) async {
    final h = _Harness();
    h.draft.populate(() => h.model.freqController.text = '14074');
    expect(h.model.mode, 'SSB');
    expect(h.model.freqTouched, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(h.store.calls, isEmpty);
    expect(h.rescores, 0, reason: 'the populating caller schedules its own rescore');
    h.model.dispose();
  });

  testWidgets('editing an existing QSO changes the QSO, never the VFO', (tester) async {
    final h = _Harness();
    h.editingQso = const Qso(
      uuid: 'q1',
      operationUuid: 'op',
      data: {
        'their': {'call': 'W1AW'},
      },
    );
    h.model.freqController.text = '14074';
    await tester.pump(const Duration(seconds: 5));
    h.model.applyBandPick('40m');
    h.model.setMode('CW');
    expect(h.store.calls, isEmpty);
    expect(h.model.band, '40m');
    expect(h.model.mode, 'CW');
    h.model.dispose();
  });

  testWidgets('a band pick empties the frequency, re-derives a sideband on a move, and pushes at once', (tester) async {
    final h = _Harness();
    h.model.freqController.text = '14285'; // 20m, SSB → USB
    expect(h.model.mode, 'USB');
    h.model.applyBandPick('40m');
    expect(h.model.freqController.text, isEmpty);
    expect(h.model.band, '40m');
    expect(h.model.mode, 'LSB', reason: 'the stored sideband belonged to the band being left');
    expect(h.store.calls.last, 'freq=null band=40m mode=null clearFreq=false');
    h.model.dispose();
  });

  testWidgets('settling a pending edit flushes it, and a discarded one is dropped with the follow restored', (tester) async {
    final h = _Harness();
    h.model.freqController.text = '7200';
    expect(h.store.calls, isEmpty);
    h.model.settlePendingFreqEdit();
    expect(h.store.calls, hasLength(1), reason: 'the operator typed it and the field still shows it');

    h.model.freqController.text = '7250';
    h.model.settlePendingFreqEdit(flush: false);
    await tester.pump(const Duration(seconds: 5));
    expect(h.store.calls, hasLength(1), reason: 'not flushed, and the pending push must not fire later either');
    expect(h.model.freqTouched, isFalse, reason: 'live follow must not stay off for the session');
    h.model.dispose();
  });

  testWidgets('seeding from the VFO takes the mode even when the frequency is the operator\'s', (tester) async {
    final h = _Harness();
    h.store.setVfo('vfoA', freq: 7074, mode: 'FT8');
    h.store.calls.clear();
    h.model.freqController.text = '7200';
    h.model.seedFromVfo(skipFrequency: true);
    expect(h.model.freqController.text, '7200');
    expect(h.model.mode, 'FT8');
    h.model.seedFromVfo();
    expect(h.model.freq, 7074);
    expect(h.model.freqTouched, isFalse);
    h.model.dispose();
  });

  testWidgets('a spinning dial holds the chip at its step\'s decimals until the frequency settles', (tester) async {
    final h = _Harness();
    String head() => h.model.summary.split(' • ').first;
    // Follow-the-VFO writes are programmatic, like the rig turning under CAT.
    void tune(String text) => h.draft.populate(() => h.model.freqController.text = text);

    tune('14074.9');
    tune('14075');
    expect(head(), '14,075.0', reason: 'a 100 Hz step must not shed its decimal at the whole kHz, or the chip changes width');
    tune('14075.01');
    tune('14075.1');
    expect(head(), '14,075.10', reason: 'a finer step widens the floor');

    await tester.pump(FreqDecimalsHold.settleDelay - const Duration(seconds: 1));
    tune('14075.2');
    await tester.pump(FreqDecimalsHold.settleDelay - const Duration(seconds: 1));
    expect(head(), '14,075.20', reason: 'every step restarts the wait, so the floor holds while the dial turns');

    await tester.pump(const Duration(seconds: 1));
    expect(head(), '14,075.2', reason: 'once settled, trailing zeros go');
    h.model.dispose();
  });

  testWidgets('the summary spells out only the sideband that contradicts the frequency', (tester) async {
    final h = _Harness();
    h.model.freqController.text = '7200';
    h.model.mode = 'LSB';
    expect(h.model.summary, endsWith(' • SSB'));
    expect(h.model.summaryParts(errorColor: Colors.red).last.color, isNull);
    h.model.mode = 'USB';
    final parts = h.model.summaryParts(errorColor: Colors.red);
    expect(parts.last.text, 'USB');
    expect(parts.last.color, Colors.red);
    expect(h.model.summary, endsWith(' • USB'));
    h.model.dispose();
  });

  testWidgets('typed dropdown text commits to the first match, and a pick is never a filter', (tester) async {
    final h = _Harness();
    h.model.modeController.text = 'c';
    expect(h.model.modeMenuEntries.map((e) => e.value), everyElement(contains('C')));
    h.model.commitModeText();
    expect(h.model.mode, 'CW');
    expect(h.model.modeController.text, 'CW');
    expect(h.model.modeMenuEntries.length, greaterThan(1), reason: 'the commit clears the filter');

    h.model.modeController.text = 'FT8'; // what DropdownMenu writes before onSelected
    h.model.pickMode('FT8');
    expect(h.model.modeMenuEntries.length, greaterThan(1), reason: 'a pick narrows nothing');
    h.model.dispose();
  });

  testWidgets('the chip is a cat only for a configured rig, and coloured only then', (tester) async {
    final h = _Harness();
    expect(h.model.chipIcon, MdiIcons.radio);
    expect(h.model.statusColor(ThemeData.light(), selected: false), isNull, reason: 'no radio to report on');
    h.hasConfiguredRadio = true;
    h.radioConnected = true;
    // Read live from the configuration: the rig's status changes under a
    // mounted panel, and a glyph captured once would show the old rig.
    expect(h.model.chipIcon, MdiIcons.cat);
    expect(h.model.statusColor(ThemeData.light(), selected: false), isNotNull);
    h.model.dispose();
  });

  testWidgets('power follows the VFO only while in play, and never over typing or a logged QSO', (tester) async {
    final h = _Harness();
    h.store.setVfo('vfoA', power: 100);
    h.model.seedFromVfo();
    expect(h.model.powerController.text, isEmpty, reason: 'nothing asked for power to be logged');

    h.powerInPlay = true;
    h.model.seedFromVfo();
    expect(h.model.powerController.text, '100');
    expect(h.model.powerSummary, startsWith('100 '));

    h.editingQso = const Qso(uuid: 'q1', operationUuid: 'op', data: {});
    h.store.setVfo('vfoA', power: 50);
    h.model.seedPowerFromVfo();
    expect(h.model.powerController.text, '100', reason: "a logged QSO's power is its own, not the rig's");
    h.editingQso = null;

    // The trap: a seed that lands while the operator is typing overwrites
    // their entry with the rig's — the field has to be left alone while it
    // holds focus, and committed when focus leaves it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: h.model.powerController, focusNode: h.model.powerFocus),
        ),
      ),
    );
    h.model.powerFocus.requestFocus();
    await tester.pump();
    h.model.powerController.text = '5';
    h.model.seedPowerFromVfo();
    expect(h.model.powerController.text, '5');
    h.model.powerFocus.unfocus();
    await tester.pump();
    expect(h.store.powerCalls.last, 'power=5 clear=false', reason: 'blur is what commits the field to the VFO');
    h.model.dispose();
  });

  test('committing power pushes the watts, clears an empty field, and never while editing', () {
    final h = _Harness();
    h.model.powerController.text = '100';
    h.model.commitPower();
    expect(h.store.powerCalls, ['power=100 clear=false']);
    h.model.powerController.clear();
    h.model.commitPower();
    expect(h.store.powerCalls.last, 'power=null clear=true');

    h.editingQso = const Qso(uuid: 'q1', operationUuid: 'op', data: {});
    h.model.powerController.text = '25';
    h.model.commitPower();
    expect(h.store.powerCalls, hasLength(2), reason: 'an edit applies to the QSO, never the VFO');

    h.draft.powerOnRecord = true;
    h.model.clearPowerEntry();
    expect(h.model.powerController.text, isEmpty);
    expect(h.draft.powerOnRecord, isFalse, reason: 'the record the power belonged to is closed');
    h.model.dispose();
  });

  test('a rig that drops its power empties the field, and every keystroke reaches the panel', () {
    final h = _Harness()..powerInPlay = true;
    h.store.setVfo('vfoA', power: 100);
    h.model.seedPowerFromVfo();
    expect(h.model.powerController.text, '100');
    h.store.setVfo('vfoA', clearPower: true);
    h.model.seedPowerFromVfo();
    expect(h.model.powerController.text, isEmpty, reason: 'the field mirrors the VFO, absence included');

    // The chip's summary and the action button read the field on every
    // build, so a keystroke must repaint the panel — the model, not the
    // panel, owns that listener now.
    final before = h.notifications;
    h.model.powerController.text = '5';
    expect(h.notifications, greaterThan(before));
    h.model.dispose();
  });
}
