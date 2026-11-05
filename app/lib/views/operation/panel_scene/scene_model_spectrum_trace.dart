// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a spectrum's trace and the fill under it are drawn: the control's own
// look, and an overlay's over its range of frequencies
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_model.dart';

/// A color by level: spread evenly with the others when [at] is null, else at
/// that height of the spectrum — `noise+3db`, `spectrum+40%`.
typedef SceneSpectrumStop = ({Color color, SceneSpectrumAcross? at});

/// The trace's look, and its fill's. Colors by level are stops, lowest level
/// first, spread from the spectrum's bottom to its top or each at its own
/// level — so a level keeps its color wherever the floor and range put it on
/// screen. A field left null is the control's, for an overlay, or the
/// theme's, for the control.
class SceneSpectrumTrace {
  final Color? color, fill, fillBottom;
  final List<SceneSpectrumStop>? colors, fillColors;
  final SceneNumber? width;
  final bool? dashed;

  /// The control's own: the trace averaged across this many pixels of
  /// frequency and drawn as a curve. An overlay has none — a trace smoothed in
  /// one range only would bend at its edges.
  final SceneNumber? smooth;

  SceneSpectrumTrace._(
    Map<dynamic, dynamic> json, {
    required String color,
    required String width,
    required String dashed,
    required String colors,
    required String fill,
    String? fillBottom,
    required String fillColors,
    String? smooth,
  }) : color = _color(json, color),
       width = SceneNumber.parse(json, width, min: .25, max: 8),
       dashed = switch (json[dashed]) {
         null => null,
         final bool on => on,
         _ => throw FormatException('Invalid scene spectrum $dashed'),
       },
       colors = json[colors] == null ? null : _levels(json[colors], colors),
       fill = _color(json, fill),
       fillBottom = fillBottom == null ? null : _color(json, fillBottom),
       fillColors = json[fillColors] == null ? null : _levels(json[fillColors], fillColors),
       smooth = smooth == null ? null : SceneNumber.parse(json, smooth, min: 0, max: 20) {
    // One way to color each: a scene giving two would see one of them ignored.
    if (this.color != null && this.colors != null) throw FormatException('A spectrum trace takes $color or $colors, not both');
    if ((this.fill != null || this.fillBottom != null) && this.fillColors != null) {
      throw FormatException('A spectrum trace fill takes $fill or $fillColors, not both');
    }
  }

  /// The control's, from its flat keys.
  SceneSpectrumTrace.control(Map<dynamic, dynamic> json)
    : this._(
        json,
        color: 'traceColor',
        width: 'traceWidth',
        dashed: 'traceDashed',
        colors: 'traceColors',
        fill: 'fillColor',
        fillBottom: 'fillColorBottom',
        fillColors: 'fillColors',
        smooth: 'traceSmooth',
      );

  /// An overlay's `trace`, over the frequencies it spans.
  SceneSpectrumTrace.overlay(Map<dynamic, dynamic> json)
    : this._(json, color: 'color', width: 'width', dashed: 'dashed', colors: 'colors', fill: 'fill', fillColors: 'fillColors');

  /// 2 to 8 colors spread evenly, or as many `{ color, at }` each at its level
  /// on the spectrum. Not a mix: a plain color among placed ones has no
  /// place of its own to take.
  static List<SceneSpectrumStop> _levels(Object? raw, String key) {
    if (raw is! List || raw.isEmpty || raw.first is! Map) return [for (final color in SceneSpectrumSpec._stops(raw, key)) (color: color, at: null)];
    if (raw.length < 2 || raw.any((stop) => stop is! Map)) throw FormatException('Invalid scene $key');
    if (raw.length > 8) throw _overCount(key, raw.length, 8);
    return [
      for (final Map<dynamic, dynamic> stop in raw.cast<Map<dynamic, dynamic>>())
        (color: _color(stop, 'color') ?? (throw FormatException('A $key stop needs a color')), at: _level(stop, key)),
    ];
  }

  /// A height on the spectrum: from the noise, or the spectrum's own edges.
  static SceneSpectrumAcross _level(Map<dynamic, dynamic> stop, String key) {
    final at = SceneSpectrumAcross.parse(stop, 'at') ?? (throw FormatException('A $key stop needs at'));
    if (!at.noise && at.part != SceneSpectrumPart.spectrum) throw FormatException('A $key stop is a level on the spectrum: noise or spectrum');
    return at;
  }

  Iterable<String> get valueNames => [?width?.value, ?smooth?.value];
}
