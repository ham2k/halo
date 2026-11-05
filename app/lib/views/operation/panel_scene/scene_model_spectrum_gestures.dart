// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who handles a spectrum's gestures, and what scrolling over it does
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_model.dart';

/// What the host does with one of a spectrum's gestures.
enum SceneSpectrumGesture {
  /// The host acts: tunes the radio, or moves the window it shows.
  native,

  /// The host sends the control's event and the extension decides.
  event,

  /// Nothing.
  off,
}

/// A spectrum's `gestures`: a click (and the wheel) that tunes, a drag on the
/// axis or a pinch that zooms, a drag over the panadapter or waterfall that
/// pans. A null one takes the default for the bundle's extension API — see
/// `SceneSpectrumSource.nativeGestures`.
class SceneSpectrumGestures {
  final SceneSpectrumGesture? tune, zoom, pan, split, levels;

  /// What scrolling up and down, and sideways, does — a wheel's or a
  /// trackpad's — whichever way the spectrum lies.
  final SceneSpectrumScroll vertical, horizontal;

  const SceneSpectrumGestures({
    this.tune,
    this.zoom,
    this.pan,
    this.split,
    this.levels,
    this.vertical = SceneSpectrumScroll.tune,
    this.horizontal = SceneSpectrumScroll.pan,
  });

  static const _names = ['native', 'event', 'off'];

  static SceneSpectrumGestures parse(Object? raw) => switch (raw) {
    null => const SceneSpectrumGestures(),
    final Map<dynamic, dynamic> json when json.keys.every(const ['tune', 'zoom', 'pan', 'split', 'levels', 'scroll'].contains) => SceneSpectrumGestures(
      tune: _gesture(json, 'tune'),
      zoom: _gesture(json, 'zoom'),
      pan: _gesture(json, 'pan'),
      split: _gesture(json, 'split'),
      levels: _gesture(json, 'levels'),
      vertical: _scroll(json, 'vertical') ?? SceneSpectrumScroll.tune,
      horizontal: _scroll(json, 'horizontal') ?? SceneSpectrumScroll.pan,
    ),
    _ => throw const FormatException('Invalid scene spectrum gestures'),
  };

  static SceneSpectrumScroll? _scroll(Map<dynamic, dynamic> json, String key) => switch (json['scroll']) {
    null => null,
    final Map<dynamic, dynamic> scroll when scroll.keys.every(const ['vertical', 'horizontal'].contains) => switch (_oneOf(scroll, key, const [
      'tune',
      'pan',
      'off',
    ])) {
      final name? => SceneSpectrumScroll.values.byName(name),
      null => null,
    },
    _ => throw const FormatException('Invalid scene spectrum gestures scroll'),
  };

  static SceneSpectrumGesture? _gesture(Map<dynamic, dynamic> json, String key) => switch (_oneOf(json, key, _names)) {
    final name? => SceneSpectrumGesture.values.byName(name),
    null => null,
  };
}

/// What a scroll over a spectrum does: tunes as the wheel does, moves the
/// window along the frequency, or nothing.
enum SceneSpectrumScroll { tune, pan, off }
