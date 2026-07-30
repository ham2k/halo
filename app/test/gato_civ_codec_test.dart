// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CI-V, against hand-worked byte vectors.
//
// The vectors are written out by hand from Icom's documented frame layout,
// NOT produced by calling the builders and asserting they equal themselves.
// app-polo's driver spec did the latter in six places, which is a test that
// cannot fail when the encoding is wrong (Rule 9). The BCD byte order is
// the specific thing worth pinning: it is the reverse of how the number
// reads, and getting it backwards puts the radio on a plausible-looking
// wrong frequency rather than failing loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/gato/drivers/civ_codec.dart';

void main() {
  group('BCD frequency', () {
    test('is five bytes, least-significant pair first', () {
      // 14.074000 MHz = 0014074000 Hz. Digit pairs from the top:
      // 00 14 07 40 00 — reversed on the wire: 00 40 07 14 00.
      expect(encodeBcdFrequency(14074000), [0x00, 0x40, 0x07, 0x14, 0x00]);
    });

    test('a worked second vector, to catch a transposition the first would not', () {
      // 7.195500 MHz = 0007195500 Hz → pairs 00 07 19 55 00 → reversed.
      expect(encodeBcdFrequency(7195500), [0x00, 0x55, 0x19, 0x07, 0x00]);
    });

    test('carries the 1 Hz and 10 Hz digits the FT-891 path throws away', () {
      // 14074123 Hz → 00 14 07 41 23 → reversed.
      expect(encodeBcdFrequency(14074123), [0x23, 0x41, 0x07, 0x14, 0x00]);
    });

    test('round-trips', () {
      for (final hz in [1840000, 7074000, 14250000, 50313000, 144200000, 430000000]) {
        expect(decodeBcdFrequency(encodeBcdFrequency(hz)), hz, reason: '$hz Hz');
      }
    });

    test('decodes a captured reply', () {
      expect(decodeBcdFrequency([0x00, 0x40, 0x07, 0x14, 0x00]), 14074000);
    });

    test('rejects bytes that are not valid BCD', () {
      // A nibble above 9 means these are not a frequency at all. Reading
      // them as one would tune the radio somewhere arbitrary.
      expect(decodeBcdFrequency([0x00, 0x4A, 0x07, 0x14, 0x00]), isNull);
      expect(decodeBcdFrequency([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), isNull);
    });
  });

  group('frames', () {
    test('a read-frequency frame, byte for byte', () {
      // FE FE <radio> <controller> 03 FD, to an IC-705 at its default address.
      expect(
        buildReadFrequencyFrame(to: 0xA4),
        [0xFE, 0xFE, 0xA4, 0xE0, 0x03, 0xFD],
      );
    });

    test('a set-frequency frame carries the BCD payload', () {
      expect(
        buildSetFrequencyFrame(to: 0xA4, freqHz: 14074000),
        [0xFE, 0xFE, 0xA4, 0xE0, 0x05, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD],
      );
    });

    test('set-mode omits the filter byte unless asked', () {
      // polo always sent `01`, which forced the operator's filter to FIL1
      // on every mode change. The mode alone leaves the filter alone.
      expect(buildSetModeFrame(to: 0xA4, mode: 'USB'), [0xFE, 0xFE, 0xA4, 0xE0, 0x06, 0x01, 0xFD]);
      expect(
        buildSetModeFrame(to: 0xA4, mode: 'USB', filter: 2),
        [0xFE, 0xFE, 0xA4, 0xE0, 0x06, 0x01, 0x02, 0xFD],
      );
    });

    test('an unknown mode builds nothing rather than a malformed frame', () {
      // 'SSB' never reaches a driver — GatoService resolves it first — and
      // CI-V has no code for it either way.
      expect(buildSetModeFrame(to: 0xA4, mode: 'SSB'), isNull);
      expect(buildSetModeFrame(to: 0xA4, mode: null), isNull);
    });

    test('the IC-705 D-STAR mode is in the table', () {
      expect(civCodeForModeName('DV'), 0x17);
      expect(civModeNameForCode(0x17), 'DV');
    });

    test('parses a reply', () {
      final frame = parseCivFrame([0xFE, 0xFE, 0xE0, 0xA4, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD])!;
      expect(frame.to, 0xE0);
      expect(frame.from, 0xA4);
      expect(frame.command, CivCommand.readFrequency);
      expect(decodeBcdFrequency(frame.data), 14074000);
    });

    test('rejects malformed frames', () {
      expect(parseCivFrame([0xFE, 0xFE, 0xA4, 0xE0, 0x03]), isNull, reason: 'no terminator');
      expect(parseCivFrame([0xFE, 0xA4, 0xE0, 0x03, 0xFD]), isNull, reason: 'one preamble');
      expect(parseCivFrame([0xFE, 0xFE, 0xFD]), isNull, reason: 'too short');
    });
  });

  group('ACK, NG, and echo — what polo could not tell apart', () {
    test('an accepted command is an ACK', () {
      final frame = parseCivFrame([0xFE, 0xFE, 0xE0, 0xA4, 0xFB, 0xFD])!;
      expect(frame.isAck, isTrue);
      expect(frame.isNak, isFalse);
    });

    test('a rejected command is an NG, not silence', () {
      // polo ignored 0xFA entirely, so a command the radio refused was
      // indistinguishable from one it never received — and the app went on
      // believing the radio had moved.
      final frame = parseCivFrame([0xFE, 0xFE, 0xE0, 0xA4, 0xFA, 0xFD])!;
      expect(frame.isNak, isTrue);
      expect(frame.isAck, isFalse);
    });

    test('our own frame coming back is recognisable as an echo', () {
      // CI-V is a bus and the radio echoes what it receives. Without this
      // the driver reads its own set-frequency back as if the radio had
      // reported it.
      final ours = parseCivFrame(buildSetFrequencyFrame(to: 0xA4, freqHz: 14074000))!;
      expect(ours.isEchoOf(civDefaultControllerAddress), isTrue);

      final theirs = parseCivFrame([0xFE, 0xFE, 0xE0, 0xA4, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD])!;
      expect(theirs.isEchoOf(civDefaultControllerAddress), isFalse);
    });

    test('a broadcast transceive announcement is for us; another controller is not', () {
      final broadcast = parseCivFrame([0xFE, 0xFE, 0x00, 0xA4, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD])!;
      expect(broadcast.isFor(civDefaultControllerAddress), isTrue);
      expect(broadcast.command, CivCommand.transceiveFrequency);

      // Addressed to a different controller on the same bus.
      final other = parseCivFrame([0xFE, 0xFE, 0xE1, 0xA4, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD])!;
      expect(other.isFor(civDefaultControllerAddress), isFalse);
    });
  });

  group('framing', () {
    test('splits several frames out of one chunk', () {
      final framer = CivFramer();
      final frames = framer.add([
        ...buildReadFrequencyFrame(to: 0xA4),
        ...buildReadModeFrame(to: 0xA4),
      ]);
      expect(frames.map((f) => f.command), [CivCommand.readFrequency, CivCommand.readMode]);
    });

    test('carries a partial frame across chunks', () {
      final framer = CivFramer();
      expect(framer.add([0xFE, 0xFE, 0xE0, 0xA4, 0x03, 0x00]), isEmpty);
      expect(framer.add([0x40, 0x07, 0x14, 0x00, 0xFD]).single.command, CivCommand.readFrequency);
    });

    test('survives a frame split one byte at a time', () {
      final framer = CivFramer();
      final found = <CivFrame>[];
      for (final byte in buildSetFrequencyFrame(to: 0xA4, freqHz: 14074000)) {
        found.addAll(framer.add([byte]));
      }
      expect(found.single.command, CivCommand.setFrequency);
    });

    test('skips leading noise and frames what follows', () {
      final framer = CivFramer();
      final frames = framer.add([0x00, 0xAA, 0x55, ...buildReadFrequencyFrame(to: 0xA4)]);
      expect(frames.single.command, CivCommand.readFrequency);
    });

    test('a stream that never terminates does not grow the buffer without limit', () {
      // A wrong baud rate, or a half-open socket dribbling noise. polo's
      // residual had no cap at all.
      final framer = CivFramer();
      for (var i = 0; i < 100; i++) {
        framer.add(List.filled(100, civPreamble));
      }
      // Still frames a real frame once one arrives, rather than being
      // wedged by 10 kB of accumulated garbage.
      expect(framer.add(buildReadFrequencyFrame(to: 0xA4)).single.command, CivCommand.readFrequency);
    });

    test('reset drops a partial tail so it cannot prefix the next connection', () {
      final framer = CivFramer();
      framer.add([0xFE, 0xFE, 0xE0, 0xA4, 0x03, 0x00]);
      framer.reset();
      expect(framer.add([0x40, 0x07, 0x14, 0x00, 0xFD]), isEmpty);
    });
  });

  test('the documented radio addresses', () {
    // The driver takes this as configuration; these are the factory
    // defaults, and the IC-705's is the one that matters here.
    expect(civRadioAddresses['IC-705'], 0xA4);
    expect(civRadioAddresses['IC-7300'], 0x94);
  });
}
