// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spectrum's annotations: text boxes at frequencies, standing from the
// spectrum's foot or the waterfall's head, with what they list when open
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_model.dart';

/// Text at a frequency on the panadapter or the waterfall, drawn by the host
/// and clickable: with an [event], a click sends `activate` carrying the
/// frequency as `value` and [id] as `annotation`, and does not tune; with a
/// [menu], it opens the menu there, and the item picked is sent the same way.
/// With a [secondaryEvent], a right-click sends that the same way.
class SceneSpectrumAnnotation {
  final String id, text;
  final SceneNumber hz;
  final SceneSpectrumAnchor anchor;
  final bool onWaterfall;

  /// Pixels from the panadapter's bottom up to the text's, or from the
  /// waterfall's top down to the text's.
  final SceneNumber? offset;

  /// Where [offset] measures from in place of that edge, in a layer's
  /// coordinates across the frequency — `noise+30db` stands a spot that far
  /// above the noise whatever the radio's scale. An app without it measures
  /// from the edge.
  final SceneSpectrumAcross? y;

  /// Which end of the text sits at [hz].
  final String align;

  /// The point on the box that marks [hz]: its [SceneSpectrumPointer.size],
  /// and whether it leaves the box's top or bottom edge. Null: none.
  final SceneSpectrumPointer? pointer;
  final SceneNumber? size, weight, borderWidth, radius;

  /// Around the text, upright on the screen: across it and above and below it.
  final SceneNumber? padding, paddingY;

  /// Lines shown under the text while the pointer is on it, or a touch has
  /// opened it — those it stands for — over any annotation it would overlap,
  /// each with an icon of its own, as [icon] is; where any line has one, every
  /// line's text starts past an icon's room.
  final List<({String text, ({String name, Color? color})? icon})>? more;

  /// A border on the edge facing the one [offset] measures from, drawn while
  /// it is open with its [more] lines.
  final ({Color color, SceneNumber? width})? openBorder;

  /// Its box's fill while it is open with its [more] lines, in place of [background].
  final Color? openBackground;

  /// A short count or tag after the text, in a pill: its text, ink and fill.
  final ({String text, Color? color, Color? background})? badge;
  final String? fontFamily, event;
  final SceneMenu? menu;

  /// What a right-click on it sends, as a click sends [event]: what the scene does to it there,
  /// such as taking it down. API 22; none, a right-click does nothing.
  final String? secondaryEvent;
  final bool italic;
  final Color? color, background, borderColor;

  /// The border on only the edge facing the one [offset] measures from — under
  /// the text on the spectrum, over it on the waterfall — rather than all
  /// around. An app without it draws the whole border.
  final bool borderNear;

  /// The box runs from the tops of the text's capitals to its baseline,
  /// rather than over its whole line: [align] and [offset] place the baseline
  /// or the capitals' tops, and descenders hang past the box.
  final bool baseline;

  /// Hz from [hz] the box covers at the least — a spot's passband: where they
  /// lie further apart than the box is long, the box runs from one to the
  /// other and the text is centred in it; otherwise [align] places it.
  final ({SceneNumber from, SceneNumber to})? stretch;

  /// A named icon (MDI or `fa-`) before the text, at its size, in its own
  /// color or the text's. An app without it draws the text alone, so it
  /// raises no API level.
  final ({String name, Color? color})? icon;

  /// Drawn as a line where the box's near border would be — [collapsedWidth]
  /// pixels wide, the box's whole width with [collapsedBox], or four fifths
  /// of it — the box itself only while the pointer is on the line or on it,
  /// over any it would overlap.
  final bool collapsed, collapsedBox;
  final double? collapsedWidth;

  bool get clickable => event != null || menu != null;

  /// Shown otherwise while the pointer is on it: whole where it is collapsed, with [more] under it.
  bool get opens => collapsed || more != null;

  SceneSpectrumAnnotation(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      text = _short(json, 'text'),
      hz = SceneNumber.parse(json, 'hz', min: -1e12, max: 1e12) ?? (throw const FormatException('A spectrum annotation needs hz')),
      anchor = SceneSpectrumAnchor.values.byName(_oneOf(json, 'anchor', const ['vfo', 'center', 'absolute']) ?? 'absolute'),
      // `pan` is the spectrum's name before extension API 17.
      onWaterfall = (_oneOf(json, 'part', const ['spectrum', 'pan', 'waterfall']) ?? 'spectrum') == 'waterfall',
      offset = SceneNumber.parse(json, 'offset', min: -2000, max: 2000),
      y = SceneSpectrumAcross.parse(json, 'y'),
      align = _oneOf(json, 'align', const ['start', 'center', 'end']) ?? 'center',
      pointer = switch (json['pointer']) {
        false => null,
        null || true => SceneSpectrumPointer(const {}),
        final Map<dynamic, dynamic> pointer => pointer['show'] == false ? null : SceneSpectrumPointer(pointer),
        _ => throw const FormatException('Invalid scene spectrum pointer'),
      },
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      padding = switch (json['padding']) {
        final Map<dynamic, dynamic> padding => SceneNumber.parse(padding, 'x', min: 0, max: 40),
        _ => SceneNumber.parse(json, 'padding', min: 0, max: 40),
      },
      paddingY = switch (json['padding']) {
        final Map<dynamic, dynamic> padding => SceneNumber.parse(padding, 'y', min: 0, max: 40),
        _ => SceneNumber.parse(json, 'padding', min: 0, max: 40),
      },
      more = switch (json['more']) {
        null => null,
        final List<dynamic> lines when lines.length <= 32 => List.unmodifiable([
          for (final line in lines)
            switch (line) {
              final String text when text.length <= 256 => (text: text, icon: null),
              final Map<dynamic, dynamic> line => (text: _short(line, 'text'), icon: _icon(line['icon'])),
              _ => throw const FormatException('Invalid spectrum annotation more line: text up to 256 characters, or { text, icon }'),
            },
        ]),
        _ => throw const FormatException('Invalid spectrum annotation more: up to 32 lines'),
      },
      openBorder = switch (json['openBorder']) {
        null => null,
        final Map<dynamic, dynamic> border => (
          color: _color(border, 'color') ?? (throw const FormatException('A spectrum annotation openBorder needs a color')),
          width: SceneNumber.parse(border, 'width', min: 0, max: 10),
        ),
        _ => throw const FormatException('Invalid spectrum annotation openBorder'),
      },
      openBackground = _color(json, 'openBackground'),
      badge = switch (json['badge']) {
        null => null,
        final Map<dynamic, dynamic> badge => (text: _short(badge, 'text'), color: _color(badge, 'color'), background: _color(badge, 'background')),
        _ => throw const FormatException('Invalid spectrum annotation badge'),
      },
      borderWidth = SceneNumber.parse(json, 'borderWidth', min: 0, max: 10),
      radius = SceneNumber.parse(json, 'radius', min: 0, max: 40),
      fontFamily = json['fontFamily'] == null ? null : string(json, 'fontFamily'),
      event = json['event'] == null ? null : string(json, 'event'),
      menu = sceneMenu(json),
      secondaryEvent = json['secondaryEvent'] == null ? null : string(json, 'secondaryEvent'),
      italic = json['italic'] == true,
      color = _color(json, 'color'),
      background = _color(json, 'background'),
      borderColor = _color(json, 'borderColor'),
      borderNear = (_oneOf(json, 'borderEdges', const ['all', 'near']) ?? 'all') == 'near',
      baseline = switch (json['baseline']) {
        null || false => false,
        true => true,
        _ => throw const FormatException('Invalid spectrum annotation baseline'),
      },
      stretch = switch (json['stretch']) {
        null => null,
        final Map<dynamic, dynamic> span => (
          from: SceneNumber.parse(span, 'from', min: -1e7, max: 1e7) ?? (throw const FormatException('A spectrum annotation stretch needs from')),
          to: SceneNumber.parse(span, 'to', min: -1e7, max: 1e7) ?? (throw const FormatException('A spectrum annotation stretch needs to')),
        ),
        _ => throw const FormatException('Invalid spectrum annotation stretch'),
      },
      icon = _icon(json['icon']),
      collapsed = switch (json['collapsed']) {
        null || false => false,
        true || Map<dynamic, dynamic>() => true,
        _ => throw const FormatException('Invalid spectrum annotation collapsed'),
      },
      collapsedBox = switch (json['collapsed']) {
        final Map<dynamic, dynamic> line => line['width'] == 'box',
        _ => false,
      },
      collapsedWidth = switch (json['collapsed']) {
        final Map<dynamic, dynamic> line when line['width'] != null && line['width'] != 'box' => number(line, 'width', min: 1, max: 200),
        _ => null,
      } {
    _clickable(id, event, menu);
  }

  /// A click opens a menu where there is one, so an event beside it would never be sent.
  static void _clickable(String id, String? event, SceneMenu? menu) {
    if (menu != null && (menu.isEmpty || event != null)) throw FormatException('A spectrum menu needs entries and no event beside it: $id');
  }

  static ({String name, Color? color})? _icon(Object? json) => switch (json) {
    null => null,
    final Map<dynamic, dynamic> icon => (name: string(icon, 'name'), color: _color(icon, 'color')),
    _ => throw const FormatException('Invalid spectrum annotation icon'),
  };

  static String _short(Map<dynamic, dynamic> json, String key) {
    final text = string(json, key);
    if (text.length > 256) throw _overLength('annotation $key', text.length, 256);
    return text;
  }

  Iterable<String> get valueNames => [
    for (final n in [hz, offset, size, weight, padding, paddingY, borderWidth, radius, pointer?.size, stretch?.from, stretch?.to, openBorder?.width]) ?n?.value,
  ];
}

/// The point an annotation's box makes at its frequency.
class SceneSpectrumPointer {
  final SceneNumber? size;

  /// `top` or `bottom`; null points toward the part's edge the annotation
  /// is measured from — down on the panadapter, up on the waterfall.
  final String? corner;

  SceneSpectrumPointer(Map<dynamic, dynamic> json)
    : size = SceneNumber.parse(json, 'size', min: 0, max: 40),
      corner = _oneOf(json, 'corner', const ['top', 'bottom']) {
    if (json['show'] != null && json['show'] is! bool) throw const FormatException('Invalid scene spectrum pointer');
  }
}

/// The direction a spectrum's waterfall moves. Everything is laid out for
/// `down` and then mirrored or turned, text excepted, which stays upright.
enum SceneSpectrumFlow { down, up, right, left }

/// What a mark's numbers are measured from.
enum SceneSpectrumAnchor {
  /// The tuned frequency.
  vfo,

  /// The middle of the sweep — on a Flex the panadapter's center, which is
  /// not its slice.
  center,

  /// Nothing: the numbers are frequencies.
  absolute,
}
