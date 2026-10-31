// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a MIDI controller does to the station, by radio letter. The
// production side ([CatMidiStation]) goes through the same paths the logging
// panel and an extension panel do (PanelRadioService): Radio A through
// `vfoA`, Radio B through `vfoB`, PTT through the app's own latch — so the
// logging fields follow a knob, Smart VFO Snap settles it, and SO2R's
// one-radio-on-the-air rule holds for a footswitch as for the PTT key.

import 'package:halo_core/halo_core.dart' show popularBands, mainModes, bandForFrequency, isSidebandMode;

import '../cat/cat_service.dart';
import '../cat/driver.dart' show ReceiveLevels;
import '../cat/equipment.dart';
import '../radio_service.dart';
import '../settings_service.dart';

/// The station as a controller sees it. [radio] is always `A` or `B`.
abstract interface class MidiStation {
  /// The node a radio letter is now, or null: no Main VFO radio of this
  /// station's own for `A`; SO2R off or no Radio B for `B`.
  String? radioUuid(String radio);

  bool get so2rOn;

  /// The app's VFO for the radio: what the logging fields show.
  ({double? freqKHz, String? mode, String? band}) vfo(String radio);
  void tune(String radio, double freqKHz);
  void setMode(String radio, String mode);
  void pickBand(String radio, String band);

  /// The operator's band and mode lists, which the logging panel steps too.
  List<String> get bands;
  List<String> get modes;

  num maxWatts(String radio);
  void setPower(String radio, num watts);

  /// The Keying experiment: WPM, PTT and the messages key nothing without it,
  /// as the app's own keying surfaces don't.
  bool get keyingEnabled;
  int? keyerSpeed(String radio);
  ({int min, int max})? keyerSpeedRange(String radio);
  bool setKeyerSpeed(String radio, int wpm);

  bool canPtt(String radio);
  bool pttHeld(String radio);
  bool pttWaiting(String radio);
  void togglePtt(String radio);

  /// Drops the operator's key, or a press waiting on SO2R's other radio.
  void releasePtt();

  Passband? passband(String radio);
  void setPassband(String radio, Passband passband);

  /// Which of AF gain, RF gain and a mute of its own the radio takes.
  ReceiveLevels receiveLevels(String radio);

  /// AF and RF gain as 0…1 of the radio's range; [muted] its own mute.
  void setReceiveLevel(String radio, {double? af, double? rf, bool? muted});

  /// Keys message [n] as its function key would, from the operation in front.
  void keyMessage(int n);

  /// Escape: stops every message, chain, repeat and key.
  void stop();
}

class CatMidiStation implements MidiStation {
  final CatService cat;
  final RadioService radio;
  final SettingsService settings;

  CatMidiStation({required this.cat, required this.radio, required this.settings});

  String _vfoKey(String r) => r == 'B' ? 'vfoB' : 'vfoA';

  @override
  String? radioUuid(String r) => r == 'B' ? cat.radio2 : cat.localRadio1;

  @override
  bool get so2rOn => settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;

  @override
  ({double? freqKHz, String? mode, String? band}) vfo(String r) {
    final vfo = radio.vfo(_vfoKey(r));
    final reported = switch (radioUuid(r)) {
      final uuid? => cat.stateFor(uuid).vfo,
      null => null,
    };
    // A band picked by name clears the app's frequency until the radio
    // reports where it landed: the radio's own word fills the gap.
    final freq = vfo.freq ?? reported?.freqKHz;
    return (freqKHz: freq, mode: vfo.mode ?? reported?.mode, band: vfo.band ?? (freq == null ? null : bandForFrequency(freq)));
  }

  // `dial`: a knob turning, which Smart VFO Snap settles like the radio's own.
  @override
  void tune(String r, double freqKHz) => radio.setVfo(_vfoKey(r), freq: freqKHz, origin: VfoOrigin.dial);

  @override
  void setMode(String r, String mode) => radio.setVfo(_vfoKey(r), mode: mode);

  /// As the Band field's pick (LoggingControls.applyBandPick): a sideband
  /// belonged to the band being left, so it is asked for again as `SSB` and
  /// re-derived on the new one.
  @override
  void pickBand(String r, String band) {
    final key = _vfoKey(r);
    final current = radio.vfo(key);
    radio.setVfo(key, band: band, mode: band != current.band && isSidebandMode(current.mode) ? 'SSB' : null);
  }

  @override
  List<String> get bands => settings.enabledBands.isEmpty ? popularBands : settings.enabledBands;

  @override
  List<String> get modes => settings.enabledModes.isEmpty ? mainModes : settings.enabledModes;

  @override
  num maxWatts(String r) {
    final node = switch (radioUuid(r)) {
      final uuid? => cat.nodeFor(uuid),
      null => null,
    };
    final type = node == null ? null : cat.typeFor(node);
    return (type?.driverConfig(node!.config)['maxWatts'] as num?) ?? 100;
  }

  @override
  void setPower(String r, num watts) {
    // Radio A through its VFO, so the power a knob sets is the power the
    // next QSO logs; nothing sends `vfoB`'s own power to Radio B.
    if (r == 'A') {
      radio.setVfo('vfoA', power: watts);
    } else if (radioUuid(r) case final uuid?) {
      cat.setNodePower(uuid, watts);
    }
  }

  @override
  bool get keyingEnabled => settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;

  @override
  int? keyerSpeed(String r) => cat.keyer(r).keyerSpeed;

  @override
  ({int min, int max})? keyerSpeedRange(String r) => cat.keyer(r).keyerSpeedRange;

  @override
  bool setKeyerSpeed(String r, int wpm) => cat.keyer(r).setKeyerSpeed(wpm);

  @override
  bool canPtt(String r) => cat.keyer(r).canPtt;

  @override
  bool pttHeld(String r) => cat.pttHeldOn(radioUuid(r));

  @override
  bool pttWaiting(String r) => cat.pttWaitingOn(radioUuid(r));

  @override
  void togglePtt(String r) {
    if (radioUuid(r) case final uuid?) cat.togglePtt(uuid);
  }

  @override
  void releasePtt() => cat.pttKeys.release();

  @override
  Passband? passband(String r) => switch (radioUuid(r)) {
    final uuid? => cat.stateFor(uuid).passband,
    null => null,
  };

  @override
  void setPassband(String r, Passband passband) {
    if (radioUuid(r) case final uuid?) cat.setNodePassband(uuid, passband);
  }

  @override
  ReceiveLevels receiveLevels(String r) => switch (radioUuid(r)) {
    final uuid? => cat.receiveLevelsFor(uuid),
    null => (af: false, rf: false, mute: false),
  };

  @override
  void setReceiveLevel(String r, {double? af, double? rf, bool? muted}) {
    if (radioUuid(r) case final uuid?) cat.setNodeReceiveLevel(uuid, af: af, rf: rf, muted: muted);
  }

  @override
  void keyMessage(int n) => cat.requestMessageKey(n);

  @override
  void stop() => cat.stopKeying();
}
