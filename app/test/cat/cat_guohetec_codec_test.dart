// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guohetec's native control protocol (Q900, PMR-171), with no radio and no
// serial port.
//
// What this establishes is the protocol as the Q900 manual's Appendix 2
// documents it. What it cannot establish is that a real Q900 answers this
// way: nothing here has met hardware, which is why the driver says
// `hardwareVerified` is false.
//
// Three of these tests exist BECAUSE of that gap, pinning inferences the
// manual states nowhere so a bench session that contradicts one fails here
// rather than silently changing meaning: the CRC's width, the frequency
// byte order, and the PTT polarity. Each is called out where it sits.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/guohetec_codec.dart';

/// A well-formed status payload, so each test can vary the one field it is
/// about instead of restating twenty-four bytes.
List<int> statusPayload({
  bool transmitting = false,
  int vfoAMode = 0x00,
  int vfoBMode = 0x01,
  int vfoAHz = 14074000,
  int vfoBHz = 7074000,
  bool vfoBActive = false,
  int voltage = 138,
  int statusBits = 0x00,
  int signalByte = 0x12,
  int swrByte = 0x00,
}) =>
    [
      transmitting ? 1 : 0,
      vfoAMode,
      vfoBMode,
      ...encodeFrequency(vfoAHz),
      ...encodeFrequency(vfoBHz),
      vfoBActive ? 1 : 0,
      0, // NR/NB
      0, // RIT
      0, // XIT
      20, // filter bandwidth
      0, // spectrum bandwidth
      voltage,
      12, 34, 56, // UTC
      statusBits,
      signalByte,
      swrByte,
    ];

void main() {
  group('CRC', () {
    // The manual's C listing is only a standard CRC if its `unsigned int` is
    // sixteen bits wide (guohetec_codec.dart). This is the check vector
    // every CRC-16/CCITT-FALSE implementation agrees on, so it pins the
    // width AND catches a paraphrase of the algorithm that drifts.
    test('matches the CCITT-FALSE check vector', () {
      expect(guohetecCrc('123456789'.codeUnits), 0x29B1);
    });

    test('covers the length byte, not the preamble', () {
      final frame = buildGuohetecFrame(GuohetecOpcode.statusSync);
      // Drop the four preamble bytes and the two CRC bytes: what is left is
      // what the CRC is taken over. If the preamble were included, this
      // computed value would not match the transmitted one.
      final body = frame.sublist(4, frame.length - 2);
      final stated = (frame[frame.length - 2] << 8) | frame.last;
      expect(guohetecCrc(body), stated);
    });
  });

  group('framing', () {
    test('length counts the command and the CRC, not itself', () {
      final frame = buildGuohetecFrame(GuohetecOpcode.powerLevel, [50]);
      expect(frame.sublist(0, 4), [0xA5, 0xA5, 0xA5, 0xA5]);
      // one command byte + one data byte + two CRC bytes
      expect(frame[4], 4);
      expect(frame.length, 4 + 1 + 4);
    });

    test('a frame round-trips through the framer', () {
      final framer = GuohetecFramer();
      final frames = framer.add(buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x00]));
      expect(frames, [const GuohetecFrame(command: GuohetecOpcode.equipmentType, data: [0x00])]);
      expect(framer.crcFailures, 0);
    });

    test('a frame split across two reads still frames', () {
      final whole = buildGuohetecFrame(GuohetecOpcode.statusSync, statusPayload());
      final framer = GuohetecFramer();
      // Split inside the payload — the case a serial port produces on its
      // own and the one that makes a stateless splitter lose every packet.
      expect(framer.add(whole.sublist(0, 9)), isEmpty);
      final frames = framer.add(whole.sublist(9));
      expect(frames.single.command, GuohetecOpcode.statusSync);
    });

    test('a bad CRC is counted and dropped, and the next frame still lands', () {
      final corrupt = buildGuohetecFrame(GuohetecOpcode.statusSync, statusPayload());
      corrupt[corrupt.length - 1] ^= 0xFF;
      final good = buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x00]);

      final framer = GuohetecFramer();
      final frames = framer.add([...corrupt, ...good]);

      expect(framer.crcFailures, 1);
      expect(frames.single.command, GuohetecOpcode.equipmentType);
    });

    test('a corrupt LENGTH byte does not swallow the frame behind it', () {
      // The trap: resuming past a failed packet's own stated length trusts
      // the very byte the failure says is untrustworthy. Corrupt the length
      // so it reaches into the next packet, and a framer that skips by it
      // loses that packet for good — while one that rescans from just past
      // the header still finds it.
      final corrupt = buildGuohetecFrame(GuohetecOpcode.statusSync, statusPayload());
      final good = buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x00]);
      corrupt[4] = corrupt[4] + 6; // now ends six bytes into `good`

      final framer = GuohetecFramer();
      final frames = framer.add([...corrupt, ...good]);

      expect(framer.crcFailures, 1);
      expect(frames.single.command, GuohetecOpcode.equipmentType);
    });

    test('a spectrum sweep between frames is discarded, not framed', () {
      // The radio may volunteer these, and they carry no length and no CRC
      // (guohetec_codec.dart). Framing one as a packet would hand a driver
      // 256 bytes of magnitudes as a status reply.
      final sweep = [0x7E, 0x7E, 0x7E, 0x7E, ...List.filled(80, 0x33)];
      final framer = GuohetecFramer();
      final frames = framer.add([...sweep, ...buildGuohetecFrame(GuohetecOpcode.meters, [0x12, 0x00])]);
      expect(frames.single.command, GuohetecOpcode.meters);
      expect(framer.crcFailures, 0);
    });

    test('a false header does not hold up the real packets behind it', () {
      // 0xA5 is a legal frequency byte and a legal CRC half, so four of them
      // in a noise burst is ordinary and the byte behind them is arbitrary.
      // Believed literally, it claims a packet that will never arrive — and
      // a framer that stopped at the first incomplete packet would leave
      // every real one behind it unframed until that phantom's byte count
      // was made up, freezing the VFO display for seconds and then
      // delivering seconds-old packets as though they were current.
      for (final claimed in [0xFF, 0x3F]) {
        final framer = GuohetecFramer();
        framer.add([0xA5, 0xA5, 0xA5, 0xA5, claimed]);
        final frames = framer.add(buildGuohetecFrame(GuohetecOpcode.meters, [0x12, 0x00]));
        expect(frames.single.command, GuohetecOpcode.meters, reason: 'claimed length $claimed');
      }
    });

    test('a genuinely split packet is still waited for', () {
      // The other half of the same decision: continuing the scan past an
      // incomplete packet must not throw away a packet that really is just
      // split across two reads.
      final whole = buildGuohetecFrame(GuohetecOpcode.statusSync, statusPayload());
      final framer = GuohetecFramer();
      framer.add(whole.sublist(0, 20));
      expect(framer.add(whole.sublist(20)).single.command, GuohetecOpcode.statusSync);
    });

    test('a run of preambles resolves to the header before the length byte', () {
      // A truncated packet's tail can leave stray 0xA5 in front of a real
      // header. Taking the FIRST four of the run would read a preamble byte
      // as the length.
      final framer = GuohetecFramer();
      final frames = framer.add([0xA5, 0xA5, ...buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x00])]);
      expect(frames.single.command, GuohetecOpcode.equipmentType);
    });

    test('noise never grows the buffer without limit', () {
      final framer = GuohetecFramer();
      for (var i = 0; i < 20; i++) {
        framer.add(List.filled(200, 0xA5));
      }
      // Still able to frame a real packet after 4000 bytes of junk.
      final frames = framer.add(buildGuohetecFrame(GuohetecOpcode.meters, [0x12, 0x00]));
      expect(frames.single.command, GuohetecOpcode.meters);
    });

    test('reset drops a partial frame so it cannot prefix the next connection', () {
      final whole = buildGuohetecFrame(GuohetecOpcode.statusSync, statusPayload());
      final framer = GuohetecFramer();
      framer.add(whole.sublist(0, 9));
      framer.reset();
      expect(framer.add(whole.sublist(9)), isEmpty);
    });
  });

  group('frequency', () {
    // UNVERIFIED against hardware: the manual gives the width and the
    // maximum and never the byte order. This pins big-endian, so a capture
    // that shows otherwise fails here.
    test('is four big-endian bytes of plain hertz', () {
      expect(encodeFrequency(14074000), [0x00, 0xD6, 0xC0, 0x90]);
      expect(decodeFrequency([0x00, 0xD6, 0xC0, 0x90]), 14074000);
    });

    test("carries the radio's full 2 GHz range", () {
      expect(decodeFrequency(encodeFrequency(2000000000)), 2000000000);
    });

    test('keeps single hertz, unlike the Yaesu binary protocol', () {
      // That one counts tens of hertz in BCD and cannot express the last
      // digit at all. Nothing here should round.
      expect(decodeFrequency(encodeFrequency(14074005)), 14074005);
    });
  });

  group('modes', () {
    test('round-trip through their codes', () {
      for (final name in guohetecModeCodes.keys) {
        expect(guohetecModeNameForCode(guohetecCodeForModeName(name)!), name);
      }
    });

    test('an undocumented code reports no mode rather than a guess', () {
      // A wrong mode beside a right frequency is the dangerous one: the
      // frequency makes the reading look trustworthy.
      expect(guohetecModeNameForCode(0x7F), isNull);
    });

    test('setting modes needs a code for both VFOs', () {
      // The command carries both, so a mode the radio cannot express in
      // either slot must send nothing at all rather than a byte the radio
      // reads as some other mode.
      expect(buildSetModesCommand(vfoAMode: 'USB', vfoBMode: 'RTTY-LSB'), isNull);
      expect(buildSetModesCommand(vfoAMode: 'FT8', vfoBMode: 'USB'), isNull);
      expect(buildSetModesCommand(vfoAMode: 'USB', vfoBMode: 'LSB'), isNotNull);
    });
  });

  group('PTT', () {
    // UNVERIFIED, and the most dangerous inference in the file: the manual
    // says 0x00 PRESSES and 0x01 RELEASES, which is backwards from every
    // instinct. Inverted, the app transmits when it means to stop.
    test('zero transmits and one releases', () {
      expect(buildPttCommand(true).payload, [0x00]);
      expect(buildPttCommand(false).payload, [0x01]);
    });
  });

  group('status', () {
    test('reads both VFOs, their modes, and which is active', () {
      final status = parseStatus(statusPayload(vfoBActive: true))!;
      expect(status.vfoAHz, 14074000);
      expect(status.vfoBHz, 7074000);
      expect(status.vfoAMode, 'USB');
      expect(status.vfoBMode, 'LSB');
      // The reason this protocol is worth having over the FT-817 costume:
      // the second VFO is readable, so a split operator's transmit
      // frequency is not invisible.
      expect(status.activeFreqHz, 7074000);
      expect(status.activeMode, 'LSB');
    });

    test('reports voltage in tenths', () {
      expect(parseStatus(statusPayload(voltage: 138))!.voltageVolts, closeTo(13.8, 0.001));
    });

    test('reads the status bits by position', () {
      final status = parseStatus(statusPayload(statusBits: 0x21))!;
      expect(status.bluetoothConnected, isTrue); // bit 0
      expect(status.gpsOnline, isFalse); // bit 1
      expect(status.antennaTunerOn, isFalse); // bit 4
      expect(status.highPower, isTrue); // bit 5
    });

    test('a short payload reads as unreadable, not as a frequency', () {
      // The CRC has already passed by this point, so a short payload means
      // the firmware disagrees with the manual. Reading fields at the
      // offsets a full payload would have builds a frequency out of
      // whatever bytes happen to be there.
      expect(parseStatus(statusPayload().sublist(0, 20)), isNull);
    });
  });

  group('meters', () {
    test('the top bit picks S-meter or power', () {
      // Which scale arrives follows the PTT rather than any setting, so a
      // reading without its scale would be attributed to the wrong meter.
      expect(parseSignalMeter(0x12), const GuohetecMeterReading(scale: GuohetecMeterScale.sMeter, raw: 18));
      expect(parseSignalMeter(0x92), const GuohetecMeterReading(scale: GuohetecMeterScale.power, raw: 18));
    });

    test('the top two bits pick SWR, audio or ALC', () {
      expect(parseSwrMeter(0x0A)?.scale, GuohetecMeterScale.swr);
      expect(parseSwrMeter(0x4A)?.scale, GuohetecMeterScale.audio);
      expect(parseSwrMeter(0x8A)?.scale, GuohetecMeterScale.alc);
      expect(parseSwrMeter(0x0A)?.raw, 10);
    });

    test('the undefined fourth scale reports nothing', () {
      // The manual defines three of the four bit patterns. Guessing at the
      // fourth would put an invented SWR next to the threshold an operator
      // is warned at.
      expect(parseSwrMeter(0xCA), isNull);
    });
  });
}

extension on List<int> {
  /// A built frame's data bytes: everything between the command byte and
  /// the two CRC bytes. Spelling those offsets out at each call site
  /// obscures what is being asserted.
  List<int> get payload => sublist(6, length - 2);
}
