// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart' show ReceiveLevels;
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/midi/midi_codec.dart';
import 'package:ham2k_logger/services/midi/midi_controller.dart';
import 'package:ham2k_logger/services/midi/midi_mapping.dart';
import 'package:ham2k_logger/services/midi/midi_station.dart';

/// Records what the controller asked of the station; holds the state it reads.
class _Station implements MidiStation {
  final freq = <String, double?>{'A': 14200.0, 'B': 7100.0};
  final mode = <String, String?>{'A': 'USB', 'B': 'CW'};
  final band = <String, String?>{'A': '20m', 'B': '40m'};
  bool hasRadioB = true;
  @override
  bool so2rOn = true;
  @override
  bool keyingEnabled = true;
  final held = <String>{};
  final tunes = <(String, double)>[];
  final powers = <(String, num)>[];
  final passbands = <(String, Passband)>[];
  Passband? currentPassband = const Passband(200, 2800);
  int releases = 0;
  int? wpm = 25;

  @override
  String? radioUuid(String radio) => radio == 'A' || hasRadioB ? 'node-$radio' : null;
  @override
  ({double? freqKHz, String? mode, String? band}) vfo(String radio) => (freqKHz: freq[radio], mode: mode[radio], band: band[radio]);
  @override
  void tune(String radio, double freqKHz) => tunes.add((radio, freqKHz));
  @override
  void setMode(String radio, String m) => mode[radio] = m;
  @override
  void pickBand(String radio, String b) => band[radio] = b;
  @override
  List<String> get bands => const ['40m', '20m', '15m'];
  @override
  List<String> get modes => const ['CW', 'SSB'];
  @override
  num maxWatts(String radio) => 100;
  @override
  void setPower(String radio, num watts) => powers.add((radio, watts));
  @override
  int? keyerSpeed(String radio) => wpm;
  @override
  ({int min, int max})? keyerSpeedRange(String radio) => (min: 5, max: 50);
  @override
  bool setKeyerSpeed(String radio, int value) {
    wpm = value;
    return true;
  }

  @override
  bool canPtt(String radio) => true;
  @override
  bool pttHeld(String radio) => held.contains(radio);
  @override
  bool pttWaiting(String radio) => false;
  @override
  void togglePtt(String radio) => held.contains(radio) ? held.remove(radio) : held.add(radio);
  @override
  void releasePtt() {
    releases++;
    held.clear();
  }

  @override
  Passband? passband(String radio) => currentPassband;
  @override
  void setPassband(String radio, Passband p) => passbands.add((radio, p));
  ReceiveLevels levels = (af: true, rf: true, mute: false);
  final levelsSet = <String>[];
  @override
  ReceiveLevels receiveLevels(String radio) => levels;
  @override
  void setReceiveLevel(String radio, {double? af, double? rf, bool? muted}) =>
      levelsSet.add('$radio ${[if (af != null) 'af=$af', if (rf != null) 'rf=$rf', if (muted != null) 'muted=$muted'].join(' ')}');
  final messages = <int>[];
  @override
  void keyMessage(int n) => messages.add(n);
  int stops = 0;
  @override
  void stop() => stops++;
}

const _knobA = MidiControl(MidiControlKind.cc, 1, 21);
const _coarseA = MidiControl(MidiControlKind.cc, 1, 22);
const _knobB = MidiControl(MidiControlKind.cc, 1, 23);
const _pttA = MidiControl(MidiControlKind.note, 1, 60);
const _power = MidiControl(MidiControlKind.cc, 1, 7);
const _pbHigh = MidiControl(MidiControlKind.cc, 1, 24);
const _af = MidiControl(MidiControlKind.cc, 1, 8);
const _rf = MidiControl(MidiControlKind.cc, 1, 9);
const _mute = MidiControl(MidiControlKind.note, 1, 61);

MidiControlMessage _cc(MidiControl c, int raw) => MidiControlMessage(c, raw, on: raw >= 64);
MidiControlMessage _note(MidiControl c, {required bool on}) => MidiControlMessage(c, on ? 100 : 0, on: on);

void main() {
  late _Station station;
  late int now;
  late MidiController controller;

  MidiMapping mapping([Map<String, dynamic> options = const {}]) => MidiMapping.fromConfig({
    midiControlsConfigKey: {
      'vfoAFine': _knobA.toJson(),
      'vfoACoarse': _coarseA.toJson(),
      'vfoBFine': _knobB.toJson(),
      'pttA': _pttA.toJson(),
      'powerA': _power.toJson(),
      'passbandHighA': _pbHigh.toJson(),
      'afA': _af.toJson(),
      'rfA': _rf.toJson(),
      'muteA': _mute.toJson(),
    },
    midiOptionsConfigKey: options,
  });

  setUp(() {
    station = _Station();
    now = 1000000;
    controller = MidiController(station: station, mapping: mapping(), now: () => now);
  });

  group('tuning', () {
    test('a burst of ticks is one tune, not one per message', () {
      // Each tune is a CAT command; a fast spin sends dozens of messages
      // per flush, and a command apiece would flood the radio's link.
      for (var i = 0; i < 5; i++) {
        controller.handle(_cc(_knobA, 65));
      }
      controller.flush();
      expect(station.tunes, [('A', 14200.05)]);
    });

    test('coarse and fine turned together land as one tune', () {
      controller.handle(_cc(_knobA, 65));
      controller.handle(_cc(_coarseA, 65));
      controller.flush();
      expect(station.tunes.single.$1, 'A');
      expect(station.tunes.single.$2, closeTo(14200.06, 1e-9));
    });

    test('the next step builds on what was sent, not on a lagging echo', () {
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      // The radio has not reported the first tune yet: the app still says
      // 14200.0. Stepping from that would send 14200.01 again — the knob
      // would turn and the dial would stand still.
      now += 100;
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.last.$2, closeTo(14200.02, 1e-9));
    });

    test('a tune made elsewhere ends the hold at once', () {
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      // A spot clicked between two nudges: building on the knob's own last
      // tune would take the radio straight back off the spot.
      station.freq['A'] = 7030.0;
      now += 100;
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.last.$2, closeTo(7030.01, 1e-9));
    });

    test('an echo of any earlier step keeps the hold', () {
      for (var i = 0; i < 3; i++) {
        controller.handle(_cc(_knobA, 65));
        controller.flush();
        now += 50;
      }
      // The radio reports the first of the three: still the knob's own.
      station.freq['A'] = 14200.01;
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.last.$2, closeTo(14200.04, 1e-9));
    });

    test('a keyer speed set elsewhere ends its hold too', () {
      controller.mapping = MidiMapping.fromConfig({
        midiControlsConfigKey: {'wpmA': _knobA.toJson()},
      });
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.wpm, 26);
      station.wpm = 30;
      now += 100;
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.wpm, 31);
    });

    test('once the hold lapses, the next step starts from the radio again', () {
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      // The operator turned the radio's own knob since.
      station.freq['A'] = 14250.0;
      now += midiHoldMillis + 1;
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.last.$2, closeTo(14250.01, 1e-9));
    });

    test('CW takes the CW step', () {
      station.mode['A'] = 'CW';
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.single.$2, closeTo(14200.001, 1e-9));
    });

    test('a Digital mode is not tuned', () {
      // FT8's frequency belongs to the digital app; a bumped knob moving it
      // would put every decode off by the bump.
      station.mode['A'] = 'FT8';
      final outcome = controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(outcome!.ignored, MidiIgnored.dataMode);
      expect(station.tunes, isEmpty);
    });

    test('Radio B rows tune nothing while SO2R is off', () {
      station.so2rOn = false;
      final outcome = controller.handle(_cc(_knobB, 65));
      controller.flush();
      expect(outcome!.ignored, MidiIgnored.so2rOff);
      expect(station.tunes, isEmpty);
    });

    test('Radio B rows tune Radio B under SO2R', () {
      controller.handle(_cc(_knobB, 63));
      controller.flush();
      // CW on B: one tick is 1 Hz down.
      expect(station.tunes.single.$1, 'B');
      expect(station.tunes.single.$2, closeTo(7099.999, 1e-9));
    });

    test('a stored step outranks the default', () {
      controller.mapping = mapping({
        'vfoAFine': {midiOptStepPhone: 100},
      });
      controller.handle(_cc(_knobA, 65));
      controller.flush();
      expect(station.tunes.single.$2, closeTo(14200.1, 1e-9));
    });
  });

  group('PTT', () {
    test('hold keys while pressed and unkeys on release', () {
      expect(controller.handle(_note(_pttA, on: true))!.value, 'TX');
      expect(station.held, {'A'});
      expect(controller.handle(_note(_pttA, on: false))!.value, 'RX');
      expect(station.held, isEmpty);
    });

    test('toggle flips on each press and ignores releases', () {
      controller.mapping = mapping({
        'pttA': {midiOptPtt: midiPttToggle},
      });
      controller.handle(_note(_pttA, on: true));
      controller.handle(_note(_pttA, on: false));
      expect(station.held, {'A'});
      controller.handle(_note(_pttA, on: true));
      expect(station.held, isEmpty);
    });

    test('a key someone else holds is left alone', () {
      // The PTT key, a message or a CAT-server client keyed it: a footswitch
      // tap must not take it down mid-over, nor its release drop it.
      station.held.add('A');
      expect(controller.handle(_note(_pttA, on: true))!.ignored, MidiIgnored.keyedElsewhere);
      controller.handle(_note(_pttA, on: false));
      expect(station.held, {'A'});
      expect(station.releases, 0);
    });

    test('keys only in a Phone mode', () {
      station.mode['A'] = 'CW';
      expect(controller.handle(_note(_pttA, on: true))!.ignored, MidiIgnored.notPhone);
      expect(station.held, isEmpty);
    });

    test('keys nothing with the Keying experiment off', () {
      station.keyingEnabled = false;
      expect(controller.handle(_note(_pttA, on: true))!.ignored, MidiIgnored.keyingOff);
      expect(station.held, isEmpty);
    });

    test('once its key is dropped, its release leaves the next key alone', () {
      // The footswitch's key timed out mid-over and the operator went on
      // with the PTT key: lifting the footswitch must not take them off.
      controller.handle(_note(_pttA, on: true));
      station.held.clear();
      controller.forgetDroppedKey();
      station.held.add('A');
      controller.handle(_note(_pttA, on: false));
      expect(station.held, {'A'});
      expect(station.releases, 0);
    });

    test('releaseAll unkeys what this controller keyed', () {
      // The device was unplugged with the footswitch down: no release will
      // ever arrive from it.
      controller.handle(_note(_pttA, on: true));
      controller.releaseAll();
      expect(station.held, isEmpty);
    });

    test('a CC button repeating its pressed value keys once', () {
      controller.mapping = MidiMapping.fromConfig({
        midiControlsConfigKey: {'pttA': const MidiControl(MidiControlKind.cc, 1, 64).toJson()},
      });
      const sustain = MidiControl(MidiControlKind.cc, 1, 64);
      controller.handle(_cc(sustain, 127));
      controller.handle(_cc(sustain, 127));
      expect(station.held, {'A'});
      controller.handle(_cc(sustain, 0));
      expect(station.held, isEmpty);
      expect(station.releases, 1);
    });
  });

  test('a fader sets power on the radio\'s scale, once per flush', () {
    controller.handle(_cc(_power, 10));
    controller.handle(_cc(_power, 127));
    controller.flush();
    expect(station.powers, [('A', 100)]);
  });

  test('a passband edge never crosses the other', () {
    station.currentPassband = const Passband(200, 260);
    for (var i = 0; i < 3; i++) {
      controller.handle(_cc(_pbHigh, 63));
    }
    controller.flush();
    // 260 - 3 × 50 would sit below the low edge: an inverted filter the
    // driver would send as-is.
    expect(station.passbands, isEmpty);
    controller.handle(_cc(_pbHigh, 65));
    controller.flush();
    expect(station.passbands.single.$2, const Passband(200, 310));
  });

  group('receive levels', () {
    test('AF and RF faders land once per flush, as 0…1', () {
      controller.handle(_cc(_af, 10));
      controller.handle(_cc(_af, 127));
      controller.handle(_cc(_rf, 0));
      controller.flush();
      expect(station.levelsSet, ['A af=1.0', 'A rf=0.0']);
    });

    test('a level the radio does not take is turned down, not sent', () {
      station.levels = (af: true, rf: false, mute: false);
      expect(controller.handle(_cc(_rf, 64))!.ignored, MidiIgnored.unsupported);
      controller.flush();
      expect(station.levelsSet, isEmpty);
    });

    test('a radio with a mute of its own takes it, press by press', () {
      station.levels = (af: true, rf: true, mute: true);
      controller.handle(_note(_mute, on: true));
      controller.handle(_note(_mute, on: false));
      controller.handle(_note(_mute, on: true));
      expect(station.levelsSet, ['A muted=true', 'A muted=false']);
    });

    test('without one, mute takes the AF gain to zero and back to where it was', () {
      // Unmuting to anything else would come back louder or quieter than the
      // operator left it — or, with no level known, at a guess.
      expect(controller.handle(_note(_mute, on: true))!.ignored, MidiIgnored.muteNeedsAf);
      controller.handle(_note(_mute, on: false));
      controller.handle(_cc(_af, 76));
      controller.flush();
      station.levelsSet.clear();
      controller.handle(_note(_mute, on: true));
      controller.handle(_note(_mute, on: false));
      controller.handle(_note(_mute, on: true));
      expect(station.levelsSet, ['A af=0.0', 'A af=${76 / 127}']);
    });

    test('moving the AF gain ends an emulated mute', () {
      controller.handle(_cc(_af, 76));
      controller.flush();
      controller.handle(_note(_mute, on: true));
      controller.handle(_note(_mute, on: false));
      controller.handle(_cc(_af, 50));
      controller.flush();
      station.levelsSet.clear();
      // The next press mutes again rather than "unmuting" to 50.
      controller.handle(_note(_mute, on: true));
      expect(station.levelsSet, ['A af=0.0']);
    });
  });
}
