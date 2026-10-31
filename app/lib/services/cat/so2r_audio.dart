// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator hears of SO2R's two radios, and the rule that decides it
// — docs/design/cat.md § The SO2R switcher. Pure: no I/O, no Flutter.

/// What reaches the operator's headphones from the two radios.
///
/// Stereo is always radio A in the left ear and radio B in the right, and
/// carries a focus all the same: OTRSP's `RX1S` and `RX2S` are one stereo,
/// and the radio they name is what a box that has no stereo puts in both
/// ears instead.
enum So2rAudio {
  /// Radio A in both ears.
  a,

  /// Radio B in both ears.
  b,

  /// A left, B right; A in both ears where stereo is not possible.
  stereoA,

  /// A left, B right; B in both ears where stereo is not possible.
  stereoB;

  bool get stereo => this == stereoA || this == stereoB;

  /// The radio in focus, `A` or `B`.
  String get focus => this == a || this == stereoA ? 'A' : 'B';

  /// Whether [radio] (`A` or `B`) is heard.
  bool hears(String radio) => stereo || focus == radio;

  static So2rAudio of({required String focus, required bool stereo}) => switch ((focus, stereo)) {
    ('B', false) => b,
    ('B', true) => stereoB,
    (_, false) => a,
    (_, true) => stereoA,
  };
}

/// What one radio's own audio does under a [So2rAudio], for a radio that
/// switches it itself — two slices of one FlexRadio.
enum So2rEar { both, left, right, muted }

/// [radio]'s (`A` or `B`) ear under [audio].
So2rEar so2rEarFor(So2rAudio audio, String radio) {
  if (audio.stereo) return radio == 'A' ? So2rEar.left : So2rEar.right;
  return audio.focus == radio ? So2rEar.both : So2rEar.muted;
}

/// What the operator should hear: the radio of the set they are in
/// ([operatorRadio]), both radios in [stereo]; and, with
/// [listenWhileTransmitting], the other radio while exactly one of them is
/// on the air — the operator talking or sending on one is listening on the
/// other. In stereo both are heard already, and only the focus moves, for a
/// box that cannot do stereo.
So2rAudio wantedSo2rAudio({
  required String operatorRadio,
  required bool stereo,
  required bool listenWhileTransmitting,
  required bool transmittingA,
  required bool transmittingB,
}) {
  var focus = operatorRadio == 'B' ? 'B' : 'A';
  if (listenWhileTransmitting && transmittingA != transmittingB) focus = transmittingA ? 'B' : 'A';
  return So2rAudio.of(focus: focus, stereo: stereo);
}
