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
    // Persistence is fire-and-forget in setVfo — wait a beat for it to land.
    await Future<void>.delayed(Duration.zero);

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
    await Future<void>.delayed(Duration.zero);

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
}
