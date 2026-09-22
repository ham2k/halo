// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/zero_beat.dart';

void main() {
  /// A suggestion as `suggestedQsoFromSpot` builds one — the shape this reads
  /// keys off, so a rename there shows up here rather than as a live feature
  /// that silently stopped working.
  Map<String, dynamic> spot({double? freq = 14050, String? mode = 'CW'}) => {
    'their': {'call': 'N0DX'},
    'freq': ?freq,
    'mode': ?mode,
    'refs': const [],
  };

  Map<String, dynamic> offset(Map<String, dynamic> qso, {bool enabled = true, bool connected = true, double range = 25, double draw = 0.0}) =>
      zeroBeatSuggestion(qso, enabled: enabled, radioConnected: connected, rangeHz: range, draw: draw);

  group('zeroBeatOffsetHz', () {
    test('never lands near zero — an offset of a few Hz is still a zero beat', () {
      // The whole feature, in one property: if this can return something tiny,
      // the operator who drew it is calling on the same note as everyone else
      // and the setting did nothing for them.
      for (var i = 0; i <= 1000; i++) {
        final offset = zeroBeatOffsetHz(25, i / 1000);
        expect(offset.abs(), greaterThanOrEqualTo(10), reason: 'draw ${i / 1000} gave $offset Hz');
        expect(offset.abs(), lessThanOrEqualTo(25), reason: 'draw ${i / 1000} gave $offset Hz');
      }
    });

    test('uses both sides, and distance does not depend on which side', () {
      // Deriving the side from the draw's low bit would put every near offset
      // above the spot and every far one below it — a bias no range assertion
      // would catch, and one an activator would hear as a lopsided pileup.
      final above = <int>[];
      final below = <int>[];
      for (var i = 0; i < 1000; i++) {
        final offset = zeroBeatOffsetHz(50, i / 1000);
        (offset > 0 ? above : below).add(offset.abs());
      }
      expect(above, isNotEmpty);
      expect(below, isNotEmpty);
      // Same span on each side, so neither side is systematically closer in.
      expect(above.reduce((a, b) => a < b ? a : b), below.reduce((a, b) => a < b ? a : b));
      expect(above.reduce((a, b) => a > b ? a : b), below.reduce((a, b) => a > b ? a : b));
    });

    test('the range setting is the outer bound, in Hz', () {
      expect(zeroBeatOffsetHz(25, 0.0).abs(), 10); // 40% of 25
      expect(zeroBeatOffsetHz(25, 0.499).abs(), 25);
      expect(zeroBeatOffsetHz(75, 0.0).abs(), 30); // 40% of 75
      expect(zeroBeatOffsetHz(75, 0.499).abs(), 75);
    });

    test('the dead zone has an absolute floor, so the narrowest range still clears the pile', () {
      // 40% of the 10 Hz range is 4 Hz, which against a ~600 Hz sidetone is
      // not audibly off the spot — the one thing the dead zone exists to
      // guarantee, and what the setting's description promises.
      for (var i = 0; i < 200; i++) {
        final offset = zeroBeatOffsetHz(10, i / 200).abs();
        expect(offset, greaterThanOrEqualTo(8), reason: 'draw ${i / 200} gave $offset Hz');
        expect(offset, lessThanOrEqualTo(10), reason: 'draw ${i / 200} gave $offset Hz');
      }
    });

    test('the extremes of the draw are offsets, not discarded values', () {
      // `Random().nextDouble()` returns [0, 1); a rule that only handled the
      // open interior would silently produce 0 Hz at the edge.
      expect(zeroBeatOffsetHz(25, 0.0), isNot(0));
      expect(zeroBeatOffsetHz(25, 0.9999), isNot(0));
    });
  });

  group('applyZeroBeatOffset', () {
    test('moves the frequency by exactly the offset', () {
      expect(applyZeroBeatOffset(14050.0, 17), 14050.017);
      expect(applyZeroBeatOffset(14050.0, -17), 14049.983);
      expect(applyZeroBeatOffset(7030.5, 25), 7030.525);
    });

    test('always lands on a whole Hz, whatever precision the spot carried', () {
      // Adding offsetHz/1000 to the kHz value would pass sub-Hz precision
      // through to the radio — asking a rig for a fraction of a Hz it cannot
      // tune to, off a spot that was never that precise to begin with.
      expect(applyZeroBeatOffset(14050.0005, 17), 14050.018);
      expect(applyZeroBeatOffset(14050.00049, -17), 14049.983);
      for (final freq in [14050.0005, 7030.4999, 21025.12345]) {
        final hz = applyZeroBeatOffset(freq, 25) * 1000;
        expect(hz, closeTo(hz.roundToDouble(), 1e-6), reason: '$freq produced a fractional Hz');
      }
    });
  });

  group('shouldAvoidZeroBeat', () {
    test('CW only — phone and data are left exactly on the spot', () {
      // A few Hz is separable by ear on CW. On phone it is inaudible, and a
      // data decoder expects the tone where the spot said it would be.
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: 14050), isTrue);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'SSB', freqKHz: 14250), isFalse);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'FT8', freqKHz: 14074), isFalse);
      // Only literal 'CW' classifies as CW (superModeForMode), so CWR is Digital.
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CWR', freqKHz: 14050), isFalse);
    });

    test('a suggestion with no usable frequency is nothing to offset', () {
      // A bare-callsign suggestion (a deeplink) carries no freq, and must not
      // become a QSO at 0.025 kHz.
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: null), isFalse);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: 0), isFalse);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: null, freqKHz: 14050), isFalse);
    });

    test('off means off', () {
      expect(shouldAvoidZeroBeat(enabled: false, radioConnected: true, mode: 'CW', freqKHz: 14050), isFalse);
    });

    test('LF spots are left alone, though the freq field would now carry the offset', () {
      // The round trip that used to make this impossible now holds: parseFreq
      // breaks the kHz/MHz tie on the band plan, so an LF offset survives the
      // field. The hold on LF is therefore a deliberate one about on-air
      // behaviour, not a workaround — asserted here so that removing it is a
      // decision someone makes rather than a side effect.
      expect(parseFreq(fmtFreqInput(474.021)), 474.021);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: 474), isFalse);
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: 137.5), isFalse);
      // …and the HF spot right above the cutoff still round-trips.
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: true, mode: 'CW', freqKHz: 1810), isTrue);
      expect(parseFreq(fmtFreqInput(1810.021)), 1810.021);
    });

    test('with no radio under CAT the frequency is left exactly on the spot', () {
      // Nothing would act on the offset: the operator reads the number off the
      // screen and dials it in by hand. Offsetting would hand them digits to
      // hand-tune for no benefit, and leave the log claiming a frequency they
      // never transmitted on.
      expect(shouldAvoidZeroBeat(enabled: true, radioConnected: false, mode: 'CW', freqKHz: 14050), isFalse);
    });
  });

  group('zeroBeatSuggestion', () {
    test('reads the keys suggestedQsoFromSpot actually writes', () {
      // The whole feature hangs off `freq` and `mode` being spelled the way
      // the spot builder spells them. Renaming either there would make this
      // silently do nothing, with the pure-function tests all still green.
      final moved = offset(spot());
      expect(moved['freq'], isNot(14050));
      expect(moved['freq'], closeTo(14050, 0.025));
      // Everything else is carried through untouched.
      expect((moved['their'] as Map)['call'], 'N0DX');
      expect(moved['mode'], 'CW');
      expect(moved['refs'], isEmpty);
    });

    test('never mutates the caller\'s map — it belongs to the spot list', () {
      final source = spot();
      offset(source);
      expect(source['freq'], 14050);
    });

    test('a spot that should not move is returned as-is, not copied', () {
      // Identity matters downstream: LoggingControls re-applies a suggestion
      // only when the map is a NEW instance, so handing back a copy of an
      // unchanged suggestion would be a spurious re-apply.
      final phone = spot(mode: 'SSB');
      expect(identical(offset(phone), phone), isTrue);
      final disconnected = spot();
      expect(identical(offset(disconnected, connected: false), disconnected), isTrue);
      final lf = spot(freq: 474);
      expect(identical(offset(lf), lf), isTrue);
    });

    test('an offset that would leave the band flips to the other side', () {
      // 30 m runs 10100-10150. A spot at the very bottom offset downward
      // would be out of band: retuning the rig somewhere illegal, logging it
      // there, and clearing the VFO band the Spots panel's auto filter reads.
      final low = offset(spot(freq: 10100.005), draw: 0.75); // draw > 0.5 => below
      expect(low['freq'], greaterThan(10100.0));
      final high = offset(spot(freq: 10149.995), draw: 0.25); // draw < 0.5 => above
      expect(high['freq'], lessThan(10150.0));
    });

    test('when neither side fits the band, the spot frequency is kept', () {
      // Driven with a range no setting offers, because that is the only way
      // to make BOTH sides fail on a real band (30 m is 50 kHz wide, and the
      // widest offered range is 75 Hz). Without a range this extreme the drop
      // path can't be reached, and a test that can't reach it can't fail when
      // it's deleted.
      final source = spot(freq: 10125.0);
      for (final draw in [0.0, 0.3, 0.6, 0.99]) {
        expect(
          identical(offset(source, range: 100000, draw: draw), source),
          isTrue,
          reason: 'draw $draw pushed the spot out of 30 m instead of leaving it alone',
        );
      }
    });

    test('an offset never pushes the frequency below the LF cutoff', () {
      // The cutoff protects a round-trip through the frequency field, so it
      // has to hold for the MOVED value and not just the spot's — a downward
      // offset from just above 1000 would land at 999.9-something, which
      // parseFreq reads back as MHz. Here the flip to the other side rescues
      // it; the invariant is what matters, not which branch delivers it.
      for (final draw in [0.0, 0.25, 0.6, 0.99]) {
        final moved = offset(spot(freq: 1000.02), range: 75, draw: draw)['freq'] as double;
        expect(moved, greaterThanOrEqualTo(1000.0), reason: 'draw $draw landed at $moved');
      }
    });
  });

  group('ZeroBeatOffsetter', () {
    test('the same spot keeps its frequency, but every call returns a NEW map', () {
      // Identity is the signal LoggingControls.didUpdateWidget re-applies on.
      // Returning a remembered map would silently stop the panel refilling,
      // the callsign restoring and the VFO push firing — on EVERY spot, not
      // just the ones this offsets.
      var draws = 0;
      final offsetter = ZeroBeatOffsetter(nextDraw: () => (draws++ % 7) / 7);
      Map<String, dynamic> tap(Map<String, dynamic> s) => offsetter.apply(s, enabled: true, radioConnected: true, rangeHz: 25);

      final first = tap(spot());
      final second = tap(spot());
      expect(second['freq'], first['freq'], reason: 'the rig would move mid-exchange');
      expect(identical(second, first), isFalse, reason: 'the suggestion would not re-apply');
    });

    test('a spot it does not offset is still handed back as a fresh instance each tap', () {
      // The regression this guards is not CW-specific: a phone spot, or any
      // spot with the feature off, must keep re-applying on every tap.
      final offsetter = ZeroBeatOffsetter(nextDraw: () => 0.5);
      final a = spot(mode: 'SSB');
      final b = spot(mode: 'SSB');
      expect(identical(offsetter.apply(a, enabled: true, radioConnected: true, rangeHz: 25), a), isTrue);
      expect(identical(offsetter.apply(b, enabled: true, radioConnected: true, rangeHz: 25), b), isTrue);
    });

    test('an excursion to another spot does not redraw the first one', () {
      var draws = 0;
      final offsetter = ZeroBeatOffsetter(nextDraw: () => (draws++ % 7) / 7);
      Map<String, dynamic> tap(Map<String, dynamic> s) => offsetter.apply(s, enabled: true, radioConnected: true, rangeHz: 25);

      final first = tap(spot());
      tap(spot(freq: 7030));
      expect(tap(spot())['freq'], first['freq']);
    });

    test('spots that are never offset cost no cache slot', () {
      // Drawing before the enabled/CW/connected gate spends a slot on every
      // phone spot browsed, evicting the CW spot being worked — and the rig
      // retunes tens of Hz when the operator taps back to it.
      var draws = 0;
      final offsetter = ZeroBeatOffsetter(nextDraw: () => (draws++ % 97) / 97);
      Map<String, dynamic> tap(Map<String, dynamic> s) => offsetter.apply(s, enabled: true, radioConnected: true, rangeHz: 25);

      final mine = tap(spot());
      for (var i = 0; i < 60; i++) {
        tap(spot(freq: 7000.0 + i, mode: 'SSB'));
      }
      expect(tap(spot())['freq'], mine['freq']);
    });

    test('the spot being worked survives eviction as long as it keeps being tapped', () {
      // Eviction has to be by LAST USE. In insertion order the spot tapped
      // steadily all session is the first one dropped, while a spot glanced
      // at once and abandoned outlives it.
      var draws = 0;
      final offsetter = ZeroBeatOffsetter(nextDraw: () => (draws++ % 97) / 97);
      Map<String, dynamic> tap(Map<String, dynamic> s) => offsetter.apply(s, enabled: true, radioConnected: true, rangeHz: 25);

      final mine = tap(spot());
      for (var i = 0; i < 20; i++) {
        tap(spot(freq: 7000.0 + i));
      }
      expect(tap(spot())['freq'], mine['freq']); // touched here, so it must not age out
      for (var i = 0; i < 20; i++) {
        tap(spot(freq: 7100.0 + i));
      }
      expect(tap(spot())['freq'], mine['freq']);
    });

    test('turning the setting off takes effect on the next tap of the same spot', () {
      // Only the draw is remembered; everything else is re-evaluated, so a
      // toggle is never masked by a cached result.
      final offsetter = ZeroBeatOffsetter(nextDraw: () => 0.25);
      final on = offsetter.apply(spot(), enabled: true, radioConnected: true, rangeHz: 25);
      expect(on['freq'], isNot(14050));
      final off = offsetter.apply(spot(), enabled: false, radioConnected: true, rangeHz: 25);
      expect(off['freq'], 14050);
    });
  });
}
