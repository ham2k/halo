// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/radio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('vfoA is empty with nothing persisted yet', () {
    final radio = RadioService(prefs);
    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, isNull);
    expect(radio.vfoA.mode, isNull);
  });

  test('setVfo with freq derives the band', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'SSB');
  });

  test('setVfo with band clears freq (manually picked band, no exact frequency)', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285);
    radio.setVfo('vfoA', band: '40m');

    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, '40m');
  });

  test('setVfo with only mode leaves freq/band untouched', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    radio.setVfo('vfoA', mode: 'CW');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'CW');
  });

  test('persists across instances — a fresh RadioService picks up the last saved state', () async {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    // Writes are debounced now (a CAT-connected radio reports every knob
    // step), so wait for the real thing rather than guessing at a delay.
    await radio.flushPendingWrites();

    final freshRadio = RadioService(prefs);
    expect(freshRadio.vfoA.freq, 14285);
    expect(freshRadio.vfoA.band, '20m');
    expect(freshRadio.vfoA.mode, 'SSB');
  });

  test('is not scoped to any operation — the same vfoA is shared everywhere', () async {
    // There's no per-operation concept in RadioService at all: setting vfoA
    // once means every reader (regardless of which operation is on screen)
    // sees the same value, immediately and after a reload.
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 7100, mode: 'CW');
    await radio.flushPendingWrites();

    final anotherOperationsRadio = RadioService(prefs);
    expect(anotherOperationsRadio.vfoA.freq, 7100);
    expect(anotherOperationsRadio.vfoA.mode, 'CW');
  });

  test('notifies listeners on setVfo', () {
    final radio = RadioService(prefs);
    var notifications = 0;
    radio.addListener(() => notifications++);

    radio.setVfo('vfoA', freq: 14285);
    expect(notifications, 1);

    radio.setVfo('vfoA', mode: 'CW');
    expect(notifications, 2);
  });

  // A CAT-connected radio restates its whole state on every status push and
  // on every periodic resync. Treating each restatement as a change would
  // notify every listener — and, before the debounce below, rewrite the
  // prefs — dozens of times a second while the operator turns the knob.
  test('a restatement of the current VFO is not a change', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    var notifications = 0;
    radio.addListener(() => notifications++);

    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    expect(notifications, 0);

    radio.setVfo('vfoA', freq: 14285.5, mode: 'SSB');
    expect(notifications, 1, reason: 'a real change still notifies');
  });

  test('a burst of changes is debounced into one write, and the last value wins', () async {
    // Long enough that "nothing has landed yet" below cannot be a race with
    // the timer — the write is async, so a bare synchronous read after the
    // loop sees nothing whether or not the debounce exists.
    final radio = RadioService(prefs, writeDelay: const Duration(seconds: 10));
    for (var step = 0; step < 20; step++) {
      radio.setVfo('vfoA', freq: 14285 + step * 0.1);
    }
    await pumpEventQueue();

    // Spinning a VFO knob reports every step, and a connected radio does
    // this for as long as the operator keeps turning it. Asserting only the
    // final value would hold just as well with no debounce at all — which
    // is what 20 writes for 20 steps looks like.
    expect(RadioService(prefs).vfoA.freq, isNull, reason: 'still inside the debounce window');

    await radio.flushPendingWrites();
    expect(RadioService(prefs).vfoA.freq, closeTo(14286.9, 0.001));
  });

  test('origin defaults to user, and is remembered for the notification', () {
    final radio = RadioService(prefs);
    VfoOrigin? seen;
    radio.addListener(() => seen = radio.lastVfoOrigin);

    radio.setVfo('vfoA', freq: 14285);
    expect(seen, VfoOrigin.user, reason: 'every existing caller means user');

    // GATO writes what the radio reported, then has to recognise its own
    // echo when the notification comes back around — otherwise it re-tunes
    // the radio to the value the radio just gave it.
    radio.setVfo('vfoA', freq: 7100, origin: VfoOrigin.radio);
    expect(seen, VfoOrigin.radio);
  });
}
