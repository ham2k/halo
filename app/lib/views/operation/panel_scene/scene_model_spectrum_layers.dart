// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spectrum's own layers: rectangles, lines, text and artwork whose
// coordinates are frequencies, moving with the window as it zooms and pans
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_model.dart';

/// A coordinate along the frequency: where a frequency is drawn — a number of
/// Hz or a scene value (`freq:14074000`, `freq:spotHz`), or the tuned
/// frequency (`vfo`) — then Hz that move with the zoom and pixels that do
/// not (`vfo-1500hz+4px`). With no frequency it is pixels from the window's
/// low edge; a number is that too.
class SceneSpectrumAlong {
  /// Null: measured from the window's low edge.
  final SceneNumber? hz;
  final bool vfo;
  final double offsetHz, offsetPx;

  const SceneSpectrumAlong._({this.hz, this.vfo = false, this.offsetHz = 0, this.offsetPx = 0});

  static final _shape = RegExp(r'^(?:(vfo)|freq:(\d+(?:\.\d+)?|[A-Za-z_][\w.]*))?((?:[+-]?\d+(?:\.\d+)?(?:hz|px))*)$');

  static SceneSpectrumAlong? parse(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    if (raw is num) return SceneSpectrumAlong._(offsetPx: number(json, key, min: -8192, max: 8192));
    final match = raw is String && raw.length <= 128 ? _shape.firstMatch(raw) : null;
    if (match == null || raw == '') throw FormatException('Invalid spectrum layer coordinate: $key');
    final hz = switch (match.group(2)) {
      null => null,
      final name when double.tryParse(name) != null => SceneNumber._(double.parse(name), null, -1e12, 1e12),
      final name => SceneNumber._(null, name, -1e12, 1e12),
    };
    final offsets = _offsets(match.group(3)!, key, units: const {'hz', 'px'});
    final (offsetHz, offsetPx) = (offsets['hz'] ?? 0, offsets['px'] ?? 0);
    return SceneSpectrumAlong._(hz: hz, vfo: match.group(1) != null, offsetHz: offsetHz, offsetPx: offsetPx);
  }

  /// Where it is on a window from [lowHz] to [highHz] drawn [width] wide,
  /// in pixels from its low edge. Null where its frequency is unknown.
  double? at(double lowHz, double highHz, double width, double? vfoHz, Map<String, double> values) {
    final base = vfo ? vfoHz : (hz == null ? lowHz : hz!.resolve(values));
    if (base == null || highHz <= lowHz) return null;
    return (base + offsetHz - lowHz) / (highHz - lowHz) * width + offsetPx;
  }
}

/// The parts of a band scope a coordinate across it can name, each from its
/// top edge down (or `:bottom`).
enum SceneSpectrumPart { spectrum, axis, waterfall }

/// A coordinate across the frequency: a part's top or bottom edge
/// (`spectrum`, `waterfall:bottom`), then a share of that part's height
/// (`spectrum+30%`), seconds of age down the waterfall (`waterfall+5s`), and
/// pixels, so an item stays on its part, and at the same share or age of
/// it, as the split and the waterfall's speed change; or the noise on the
/// spectrum, then dB above it, a share of the spectrum's height and pixels
/// (`noise+20db+15%`), so it stays that far above the noise as the floor
/// and range change. With none of these,
/// or as a number, from the control's top edge, a share being of its height.
class SceneSpectrumAcross {
  final SceneSpectrumPart? part;
  final bool bottom, noise;

  /// Of the part's height — the spectrum's from the noise — or the
  /// control's with no part: .3 for `+30%`.
  final double offsetShare;
  final double offsetDb, offsetSeconds, offsetPx;

  const SceneSpectrumAcross._({
    this.part,
    this.bottom = false,
    this.noise = false,
    this.offsetShare = 0,
    this.offsetDb = 0,
    this.offsetSeconds = 0,
    this.offsetPx = 0,
  });

  static final _shape = RegExp(r'^(?:(spectrum|axis|waterfall)(?::(top|bottom))?|(noise))?((?:[+-]?\d+(?:\.\d+)?(?:px|%|db|s))*)$');

  static SceneSpectrumAcross? parse(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    if (raw is num) return SceneSpectrumAcross._(offsetPx: number(json, key, min: -8192, max: 8192));
    final match = raw is String && raw.length <= 64 ? _shape.firstMatch(raw) : null;
    if (match == null || raw == '') throw FormatException('Invalid spectrum layer coordinate: $key');
    final part = match.group(1) == null ? null : SceneSpectrumPart.values.byName(match.group(1)!);
    final noise = match.group(3) != null;
    // dB measure from the noise and seconds down the waterfall; a share is of a part, the spectrum, or the control.
    final offsets = _offsets(match.group(4)!, key, units: {'px', '%', if (noise) 'db', if (part == SceneSpectrumPart.waterfall) 's'});
    return SceneSpectrumAcross._(
      part: part,
      bottom: match.group(2) == 'bottom',
      noise: noise,
      offsetShare: (offsets['%'] ?? 0) / 100,
      offsetDb: offsets['db'] ?? 0,
      offsetSeconds: offsets['s'] ?? 0,
      offsetPx: offsets['px'] ?? 0,
    );
  }

  /// Where it is, in pixels from the control's top in its own frame, given
  /// where each part [extent] lies, the control's [height], the [noise] and
  /// the spectrum's [floor] and [range] in dB as it draws them, and the
  /// waterfall's [secondsPerPixel]. Null where its part is not shown, or
  /// what it measures from is not known yet.
  double? at(
    ({double top, double bottom})? Function(SceneSpectrumPart part) extent,
    double height, {
    double? noise,
    double? floor,
    double? range,
    double? secondsPerPixel,
  }) {
    if (this.noise) {
      final spectrum = extent(SceneSpectrumPart.spectrum);
      if (noise == null || spectrum == null || floor == null || range == null || range <= 0) return null;
      final height = spectrum.bottom - spectrum.top;
      return spectrum.bottom - (noise + offsetDb - floor) / range * height + offsetShare * height + offsetPx;
    }
    if (part == null) return offsetShare * height + offsetPx;
    final edges = extent(part!);
    if (edges == null) return null;
    var at = (bottom ? edges.bottom : edges.top) + offsetShare * (edges.bottom - edges.top) + offsetPx;
    if (offsetSeconds != 0) {
      if (secondsPerPixel == null || secondsPerPixel <= 0) return null;
      at += offsetSeconds / secondsPerPixel;
    }
    return at;
  }
}

/// The sums of [terms]' offsets by unit, refusing one not in [units].
Map<String, double> _offsets(String terms, String key, {required Set<String> units}) {
  final sums = <String, double>{};
  for (final term in RegExp(r'([+-]?\d+(?:\.\d+)?)(hz|px|%|db|s)').allMatches(terms)) {
    final unit = term.group(2)!;
    if (!units.contains(unit)) throw FormatException('Invalid spectrum layer coordinate: $key');
    sums[unit] = (sums[unit] ?? 0) + double.parse(term.group(1)!);
  }
  final limits = {'px': 8192.0, 'hz': 1e9, '%': 1000.0, 'db': 1000.0, 's': 86400.0};
  if (sums.entries.any((sum) => sum.value.abs() > limits[sum.key]!)) throw FormatException('Spectrum layer coordinate out of range: $key');
  return sums;
}

enum SceneSpectrumLayerKind { rect, line, text, svg }

/// Something a spectrum draws over its picture where a coordinate puts it:
/// [x] and [x2] along the frequency, [y] and [y2] across it, whichever way
/// the control is turned. A rect or artwork fills the box between the two
/// corners; a line runs from one to the other; text sits at the first.
class SceneSpectrumLayer {
  static const maxCount = 512;

  final String id;
  final SceneSpectrumLayerKind kind;
  final SceneSpectrumAlong x;
  final SceneSpectrumAlong? x2;

  /// Null: the control's top, and for [y2] its bottom.
  final SceneSpectrumAcross? y, y2;

  /// The outline, a line's or text's color; the inside.
  final Color? color, fill, background;
  final SceneNumber? width, radius, size, weight, padding;
  final bool dashed, italic;

  /// Drawn behind the spectrum's grid, areas and trace rather than over the
  /// picture — and so hidden under the waterfall, which is opaque.
  final bool behind;

  /// Text: [text] as given, or a scene value [value] with [decimals], between [prefix] and [suffix].
  final String? text, value, prefix, suffix, fontFamily;
  final int decimals;

  /// Which end of the text is at [x], and which edge at [y].
  final String align, valign;
  final String? svg;

  /// Sent as `activate` when it is clicked, with the frequency clicked and the
  /// layer's id; a click there tunes nothing. A [menu] opens where it is
  /// clicked instead, and sends the item picked the same way.
  final String? event;
  final SceneMenu? menu;

  bool get clickable => event != null || menu != null;

  SceneSpectrumLayer(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      kind = SceneSpectrumLayerKind.values.byName(
        _oneOf(json, 'kind', const ['rect', 'line', 'text', 'svg']) ?? (throw const FormatException('A spectrum layer needs a kind')),
      ),
      x = SceneSpectrumAlong.parse(json, 'x') ?? (throw const FormatException('A spectrum layer needs x')),
      x2 = SceneSpectrumAlong.parse(json, 'x2'),
      y = SceneSpectrumAcross.parse(json, 'y'),
      y2 = SceneSpectrumAcross.parse(json, 'y2'),
      color = _color(json, 'color'),
      fill = _color(json, 'fill'),
      background = _color(json, 'background'),
      width = SceneNumber.parse(json, 'width', min: 0, max: 20),
      radius = SceneNumber.parse(json, 'radius', min: 0, max: 40),
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      padding = SceneNumber.parse(json, 'padding', min: 0, max: 40),
      dashed = json['dashed'] == true,
      behind = json['behind'] == true,
      italic = json['italic'] == true,
      text = json['text'] == null ? null : SceneSpectrumAnnotation._short(json, 'text'),
      value = json['value'] == null ? null : string(json, 'value'),
      prefix = json['prefix'] == null ? null : string(json, 'prefix'),
      suffix = json['suffix'] == null ? null : string(json, 'suffix'),
      fontFamily = json['fontFamily'] == null ? null : string(json, 'fontFamily'),
      decimals = number(json, 'decimals', fallback: 0, min: 0, max: 6).round(),
      align = _oneOf(json, 'align', const ['start', 'center', 'end']) ?? 'start',
      valign = _oneOf(json, 'valign', const ['top', 'center', 'bottom']) ?? 'top',
      svg = json['svg'] == null ? null : string(json, 'svg'),
      event = json['event'] == null ? null : string(json, 'event'),
      menu = sceneMenu(json) {
    SceneSpectrumAnnotation._clickable(id, event, menu);
    final boxed = kind == SceneSpectrumLayerKind.rect || kind == SceneSpectrumLayerKind.svg;
    if (boxed && x2 == null) throw FormatException('A spectrum ${kind.name} layer needs x2: $id');
    if (kind == SceneSpectrumLayerKind.text && (text == null) == (value == null)) {
      throw FormatException('A spectrum text layer needs text or a value: $id');
    }
    if ((kind == SceneSpectrumLayerKind.svg) != (svg != null)) throw FormatException('Only a spectrum svg layer has svg: $id');
    if (svg != null) {
      final refusal = svgArtworkRefusal('spectrum layer artwork', svg!);
      if (refusal != null) throw refusal;
    }
    if (kind == SceneSpectrumLayerKind.rect && color == null && fill == null) {
      throw FormatException('A spectrum rect layer with no color or fill draws nothing: $id');
    }
  }

  Iterable<String> get valueNames => [
    for (final n in [x.hz, x2?.hz, width, radius, size, weight, padding]) ?n?.value,
    ?value,
  ];
}
