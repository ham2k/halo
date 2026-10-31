// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/midi/midi_codec.dart';

void main() {
  group('parseMidiPacket', () {
    test('reads every message in a packet that leans on running status', () {
      // A fast knob burst: one status byte, three CC values behind it. Read
      // as one message, the knob would turn a third as far as it did.
      final messages = parseMidiPacket([0xB0, 21, 65, 21, 65, 21, 63]).messages;
      expect(messages.map((m) => (m.control, m.raw)), [
        (const MidiControl(MidiControlKind.cc, 1, 21), 65),
        (const MidiControl(MidiControlKind.cc, 1, 21), 65),
        (const MidiControl(MidiControlKind.cc, 1, 21), 63),
      ]);
    });

    test('carries running status in from the previous packet', () {
      final messages = parseMidiPacket([22, 1], runningStatus: 0xB3).messages;
      expect(messages.single.control, const MidiControl(MidiControlKind.cc, 4, 22));
    });

    test('a clock byte mid-message does not split it', () {
      // MIDI clock may land between a status and its data; dropping the
      // message around it would lose a PTT press from a controller that
      // also sends clock.
      final messages = parseMidiPacket([0x90, 0xF8, 60, 0xF8, 100]).messages;
      expect(messages.single.control, const MidiControl(MidiControlKind.note, 1, 60));
      expect(messages.single.on, isTrue);
    });

    test('note on with velocity 0 is a release', () {
      expect(parseMidiPacket([0x90, 60, 0]).messages.single.on, isFalse);
      expect(parseMidiPacket([0x80, 60, 64]).messages.single.on, isFalse);
    });

    test('system exclusive is read past, whatever it carries', () {
      final messages = parseMidiPacket([0xF0, 0x7E, 0x10, 0xB0, 0xF7, 0xB0, 7, 100]).messages;
      expect(messages.single.control, const MidiControl(MidiControlKind.cc, 1, 7));
    });

    test('pitch bend is 14 bits, least significant byte first', () {
      expect(parseMidiPacket([0xE0, 0x00, 0x40]).messages.single.raw, 8192);
      expect(parseMidiPacket([0xE0, 0x7F, 0x7F]).messages.single.value, 1);
    });

    test('hands on the running status a packet ends in, and drops it at sysex', () {
      // A device that splits a burst across packets states the status in the
      // first only: losing it would drop every message of the rest.
      expect(parseMidiPacket([0xB2, 7, 100]).runningStatus, 0xB2);
      expect(parseMidiPacket([22, 1], runningStatus: 0xB3).runningStatus, 0xB3);
      expect(parseMidiPacket([0xB2, 7, 100, 0xF0, 1, 0xF7]).runningStatus, isNull);
      expect(parseMidiPacket([0xB2, 7, 100, 0xF8]).runningStatus, 0xB2);
    });
  });

  group('midiEncoderTicks', () {
    test('relative guesses offset-64 near the centre and twos-complement near the ends', () {
      expect(midiEncoderTicks(65, MidiEncoderCoding.relative), 1);
      expect(midiEncoderTicks(63, MidiEncoderCoding.relative), -1);
      expect(midiEncoderTicks(1, MidiEncoderCoding.relative), 1);
      expect(midiEncoderTicks(127, MidiEncoderCoding.relative), -1);
    });

    test('a named coding is taken at its word', () {
      expect(midiEncoderTicks(65, MidiEncoderCoding.sign), -1);
      expect(midiEncoderTicks(127, MidiEncoderCoding.twos), -1);
      expect(midiEncoderTicks(60, MidiEncoderCoding.offset64), -4);
    });

    test('an absolute knob moves by its change, and its first message moves nothing', () {
      // Its first value is wherever the knob happened to sit: read as a
      // move, it would jump the VFO by up to 127 steps on the first touch.
      expect(midiEncoderTicks(90, MidiEncoderCoding.absolute), 0);
      expect(midiEncoderTicks(93, MidiEncoderCoding.absolute, last: 90), 3);
    });
  });

  group('midiStepFrequency', () {
    test('the first step from off the grid lands on the next grid line', () {
      expect(midiStepFrequency(14200370, 1, 1000), 14201000);
      expect(midiStepFrequency(14200370, -1, 1000), 14200000);
    });

    test('on the grid, every tick is a whole step', () {
      expect(midiStepFrequency(14200000, 3, 1000), 14203000);
      expect(midiStepFrequency(14200000, -2, 1000), 14198000);
    });
  });
}
