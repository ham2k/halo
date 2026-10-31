// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a control on a MIDI controller can be mapped to. The ids are stored in
// the node's config: renaming one forgets every mapping made to it.

import 'midi_codec.dart';

enum MidiTargetKind {
  /// An endless knob or jog wheel sending relative CC — or a plain knob read
  /// by its change ([MidiEncoderCoding.absolute]).
  encoder,

  /// A knob or slider scaled onto the target's range.
  fader,

  /// A note, or a CC read as pressed at 64 and above.
  button;

  /// The messages a control mapped to this kind may send. A button can be
  /// learned from a CC, an encoder never from a note: a note says nothing
  /// about direction.
  Set<MidiControlKind> get accepts => switch (this) {
    encoder => const {MidiControlKind.cc},
    fader => const {MidiControlKind.cc, MidiControlKind.pb},
    button => const {MidiControlKind.note, MidiControlKind.cc},
  };
}

/// What the target does, apart from which radio it does it to.
enum MidiAction { vfoCoarse, vfoFine, ptt, power, wpm, bandUp, bandDown, modeNext, passbandLow, passbandHigh, afGain, rfGain, mute, message, stop }

class MidiTarget {
  final String id;
  final MidiTargetKind kind;
  final MidiAction action;

  /// `A` or `B`; null for a target that acts on the operator's radio as a
  /// key press would (the messages) or on every radio (stop).
  final String? radio;

  /// The message number, for [MidiAction.message].
  final int? message;

  /// Default Hz per tick, for a target that tunes.
  final int stepPhone, stepCw;

  const MidiTarget(this.id, this.kind, this.action, {this.radio, this.message, this.stepPhone = 0, this.stepCw = 0});

  bool get tunes => action == MidiAction.vfoCoarse || action == MidiAction.vfoFine;
}

List<MidiTarget> _radioTargets(String radio) => [
  MidiTarget('vfo${radio}Coarse', MidiTargetKind.encoder, MidiAction.vfoCoarse, radio: radio, stepPhone: 50, stepCw: 5),
  MidiTarget('vfo${radio}Fine', MidiTargetKind.encoder, MidiAction.vfoFine, radio: radio, stepPhone: 10, stepCw: 1),
  MidiTarget('ptt$radio', MidiTargetKind.button, MidiAction.ptt, radio: radio),
  MidiTarget('power$radio', MidiTargetKind.fader, MidiAction.power, radio: radio),
  MidiTarget('wpm$radio', MidiTargetKind.encoder, MidiAction.wpm, radio: radio),
  MidiTarget('bandUp$radio', MidiTargetKind.button, MidiAction.bandUp, radio: radio),
  MidiTarget('bandDown$radio', MidiTargetKind.button, MidiAction.bandDown, radio: radio),
  MidiTarget('mode$radio', MidiTargetKind.button, MidiAction.modeNext, radio: radio),
  MidiTarget('passbandLow$radio', MidiTargetKind.encoder, MidiAction.passbandLow, radio: radio, stepPhone: 50, stepCw: 10),
  MidiTarget('passbandHigh$radio', MidiTargetKind.encoder, MidiAction.passbandHigh, radio: radio, stepPhone: 50, stepCw: 10),
  MidiTarget('af$radio', MidiTargetKind.fader, MidiAction.afGain, radio: radio),
  MidiTarget('rf$radio', MidiTargetKind.fader, MidiAction.rfGain, radio: radio),
  MidiTarget('mute$radio', MidiTargetKind.button, MidiAction.mute, radio: radio),
];

/// Every target, in the order the mapping pane lists them.
final List<MidiTarget> midiTargets = List.unmodifiable([
  ..._radioTargets('A'),
  ..._radioTargets('B'),
  for (var n = 1; n <= 8; n++) MidiTarget('message$n', MidiTargetKind.button, MidiAction.message, message: n),
  const MidiTarget('stop', MidiTargetKind.button, MidiAction.stop),
]);

final Map<String, MidiTarget> _byId = {for (final t in midiTargets) t.id: t};

MidiTarget? midiTargetById(String id) => _byId[id];

/// Hz per tick a tuning or passband row offers.
const midiStepChoices = [1, 5, 10, 20, 50, 100, 250, 500, 1000, 2500, 5000, 10000];

/// A step as the pane and the monitor line write it: `50 Hz`, `1 kHz`, `2.5 kHz`.
String midiStepLabel(int hz) => hz < 1000 ? '$hz Hz' : '${hz % 1000 == 0 ? hz ~/ 1000 : hz / 1000} kHz';
