// Copyright ©️ 2026 Ham2K
// SPDX-License-Identifier: MPL-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/midi/cw_paddle_input.dart';

void main() {
  test('Vail configuration selects the onboard keyer and converts speed and pitch', () {
    expect(vailCwSetup(wpm: 20, iambicB: true, pitchHz: 440), [
      [0xB0, 0, 0],
      [0xC0, 8],
      [0xB0, 1, 30],
      [0xB0, 2, 69],
    ]);
    expect(vailCwSetup(wpm: 25, iambicB: false, pitchHz: 880), [
      [0xB0, 0, 0],
      [0xC0, 7],
      [0xB0, 1, 24],
      [0xB0, 2, 81],
    ]);
  });

  test('Vail key stays down until all overlapping channel-one notes are released', () {
    final edges = <(bool, int)>[];
    final input = CwPaddleInput(profile: CwPaddleProfile.vail, onEdge: (down, at) => edges.add((down, at)), nowMicros: () => 0);
    input.accept([0x91, 0, 127], 1);
    input.accept([0x90, 3, 127], 2);
    input.accept([0x90, 0, 127, 1, 127], 10);
    input.accept([0x80, 0, 0], 15);
    input.accept([0x90, 1, 0], 20);
    expect(edges, [(true, 10), (false, 20)]);
    expect(input.held, isFalse);
  });

  test('TinyMIDI turns a quick dit tap into one complete mark', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi);
      harness.press(20);
      expect(harness.edges, [(true, 0)], reason: 'the first mark starts in the MIDI callback without a timer or debounce');
      harness.wait(10);
      harness.send([0x90, 20, 0]);
      harness.wait(200);
      expect(harness.edges, [(true, 0), (false, 60000)]);
      expect(harness.input.held, isFalse);
    });
  });

  test('holding dah repeats with a one-dit gap even if the note is duplicated', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi);
      harness.press(21);
      harness.wait(10);
      harness.press(21);
      harness.wait(241);
      harness.release(21);
      harness.wait(500);
      expect(harness.edges, [(true, 0), (false, 180000), (true, 240000), (false, 420000)]);
    });
  });

  for (final modeB in [false, true]) {
    test('iambic ${modeB ? 'B adds an' : 'A omits the'} opposite mark on squeeze release', () {
      fakeAsync((time) {
        final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi, iambicB: modeB);
        harness.press(20);
        harness.wait(10);
        harness.press(21);
        harness.wait(10);
        harness.release(20);
        harness.release(21);
        harness.wait(350);
        expect(harness.edges, [
          (true, 0),
          (false, 60000),
          if (modeB) ...[(true, 120000), (false, 300000)],
        ]);
      });
    });
  }

  test('sustained squeeze alternates elements and a lone held lever takes over', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi);
      harness.press(21);
      harness.wait(10);
      harness.press(20);
      harness.wait(241);
      harness.release(20);
      harness.wait(150);
      harness.release(21);
      harness.wait(350);
      expect(harness.edges, [(true, 0), (false, 180000), (true, 240000), (false, 300000), (true, 360000), (false, 540000)]);
    });
  });

  test('a tap of the opposite lever between deadlines is remembered', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi, iambicB: false);
      harness.press(21);
      harness.wait(10);
      harness.release(21);
      harness.wait(10);
      harness.press(20);
      harness.wait(10);
      harness.release(20);
      harness.wait(600);
      expect(harness.edges, [(true, 0), (false, 180000), (true, 240000), (false, 300000)]);
    });
  });

  test('legacy HaliKey treats zero velocity as a press after a MoMIDI CC', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.haliKey);
      harness.send([0xB0, 0, 0, 0x90, 20, 0]);
      expect(harness.edges, [(true, 0)], reason: 'a MoMIDI timing reset starts the first mark immediately');
      harness.wait(20);
      harness.send([0x80, 20, 15]);
      harness.wait(200);
      expect(harness.edges, [(true, 0), (false, 60000)]);
    });
  });

  test('HaliKey with aftertouch timing keeps ordinary zero-velocity releases', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.haliKey);
      harness.press(21);
      harness.wait(140);
      harness.send([0xA0, 21, 1, 0x80, 21, 14]);
      harness.wait(200);
      harness.press(20);
      harness.wait(15);
      harness.send([0xB0, 0, 0, 0x90, 20, 0]);
      harness.wait(300);
      expect(harness.edges, [(true, 0), (false, 180000), (true, 340000), (false, 400000)]);
    });
  });

  for (final timingStatus in [0xB0, 0xA0]) {
    test('HaliKey timing status ${timingStatus.toRadixString(16)} combines velocity with the high part', () {
      fakeAsync((time) {
        final harness = _PaddleHarness(time, CwPaddleProfile.haliKey);
        harness.press(20);
        harness.wait(20);
        harness.send([0x80, 20, 15]);
        harness.wait(200);
        harness.send([timingStatus, timingStatus == 0xB0 ? 0 : 20, 1, 0x90, 20, 34]);
        harness.wait(80);
        harness.release(20);
        harness.wait(150);
        expect(harness.edges.take(4), [(true, 0), (false, 60000), (true, 175000), (false, 235000)]);
      });
    });
  }

  for (final modeB in [false, true]) {
    test('iambic ${modeB ? 'B' : 'A'} re-arms after a suspended squeeze only when both levers are up', () {
      fakeAsync((time) {
        final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi, iambicB: modeB);
        harness.press(20);
        harness.press(21);
        harness.wait(20);
        harness.input.suspend();
        harness.release(20);
        harness.wait(300);
        expect(harness.edges, [(true, 0)]);
        expect(harness.input.paddleDown, isTrue);
        harness.release(21);
        expect(harness.input.held, isFalse);
        harness.press(20);
        harness.release(20);
        expect(harness.input.paddleDown, isFalse);
        expect(harness.input.held, isTrue);
        harness.wait(150);
        expect(harness.edges, [(true, 0), (true, 320000), (false, 380000)]);
      });
    });
  }

  test('reset on disconnect forgets held notes and cancels the keyer timer', () {
    fakeAsync((time) {
      final harness = _PaddleHarness(time, CwPaddleProfile.tinyMidi);
      harness.press(20);
      harness.input.reset();
      expect(harness.input.held, isFalse);
      harness.wait(300);
      expect(harness.edges, [(true, 0)]);
      harness.press(21);
      harness.release(21);
      harness.wait(300);
      expect(harness.edges, [(true, 0), (true, 300000), (false, 480000)]);
    });
  });
}

class _PaddleHarness {
  _PaddleHarness(this.time, CwPaddleProfile profile, {bool iambicB = true}) {
    input = CwPaddleInput(profile: profile, onEdge: (down, at) => edges.add((down, at)), nowMicros: () => time.elapsed.inMicroseconds, iambicB: iambicB);
  }

  final FakeAsync time;
  final edges = <(bool, int)>[];
  late final CwPaddleInput input;

  void wait(int millis) => time.elapse(Duration(milliseconds: millis));
  void send(List<int> bytes) => input.accept(bytes, time.elapsed.inMicroseconds);
  void press(int note) => send([0x90, note, 127]);
  void release(int note) => send([0x80, note, 0]);
}
