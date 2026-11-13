// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `map` control's own fields: the projection and the view, the markers
// and the great-circle lines between them, and the styles they are drawn in
// (docs/design/panel-scenes.md § Map). The world under it, `map`, is the
// rotator map's too.

part of 'scene_model.dart';

/// The map's colors: a preset, then any the scene names over it.
class SceneMapStyle {
  final String palette;
  final Color? sea, land, coast, borders, divisions, graticule, background;

  /// Whether the night side is shaded.
  final bool grayline;

  /// Whether the land is drawn at all.
  final bool world;

  SceneMapStyle(Map<dynamic, dynamic> json)
    : palette = _oneOf(json, 'palette', const ['color', 'gray', 'muted', 'contrast', 'teal']) ?? 'color',
      sea = _color(json, 'sea'),
      land = _color(json, 'land'),
      coast = _color(json, 'coast'),
      borders = _color(json, 'borders'),
      divisions = _color(json, 'divisions'),
      graticule = _color(json, 'graticule'),
      background = _color(json, 'background'),
      grayline = json['grayline'] != false,
      world = json['world'] != false;

  static final none = SceneMapStyle(const {});
}

/// A number that follows the map's zoom: one value at every zoom, or stops
/// `[[zoom, value], …]`, read between two stops as a straight line and held
/// past the first and the last.
class SceneZoomed {
  static const maxStops = 16;

  final List<(double, double)> stops;

  const SceneZoomed._(this.stops);

  static SceneZoomed? parse(Map<dynamic, dynamic> json, String key, {required double min, required double max}) {
    final raw = json[key];
    if (raw == null) return null;
    if (raw is num) return SceneZoomed._([(0, number(json, key, min: min, max: max))]);
    if (raw is! List || raw.isEmpty || raw.length > maxStops) throw FormatException('Invalid map zoom stops: $key');
    final stops = <(double, double)>[];
    for (final stop in raw) {
      if (stop is! List || stop.length != 2) throw FormatException('Invalid map zoom stops: $key');
      final zoom = number({'zoom': stop[0]}, 'zoom', min: SceneMapSpec.zoomFloor, max: SceneMapSpec.zoomCeiling);
      final value = number({key: stop[1]}, key, min: min, max: max);
      if (stops.isNotEmpty && zoom <= stops.last.$1) throw FormatException('Map zoom stops rise with the zoom: $key');
      stops.add((zoom, value));
    }
    return SceneZoomed._(stops);
  }

  double at(double zoom) {
    if (zoom <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      final (z1, v1) = stops[i];
      if (zoom <= z1) {
        final (z0, v0) = stops[i - 1];
        return v0 + (v1 - v0) * (zoom - z0) / (z1 - z0);
      }
    }
    return stops.last.$2;
  }
}

/// How a marker, a line or a circle is drawn: a style the scene names in
/// `styles`, or the same fields on the item itself, over it.
class SceneMapLook {
  /// A marker's or a circle's inside; their edges and a line are [color],
  /// [width] wide.
  final Color? fill, color;

  /// Drawn a pixel wider either side under a line or round a marker, so it stands off whatever it crosses.
  final Color? casing;

  /// Pixels, by zoom.
  final SceneZoomed? radius, width;
  final bool? dashed;

  const SceneMapLook._({this.fill, this.color, this.casing, this.radius, this.width, this.dashed});

  SceneMapLook(Map<dynamic, dynamic> json)
    : fill = _color(json, 'fill'),
      color = _color(json, 'color'),
      casing = _color(json, 'casing'),
      radius = SceneZoomed.parse(json, 'radius', min: 0, max: 256),
      width = SceneZoomed.parse(json, 'width', min: 0, max: 64),
      dashed = switch (json['dashed']) {
        null => null,
        final bool b => b,
        _ => throw const FormatException('Invalid map dashed'),
      };

  static const empty = SceneMapLook._();

  /// This look's fields, and [under]'s where this has none.
  SceneMapLook over(SceneMapLook under) => SceneMapLook._(
    fill: fill ?? under.fill,
    color: color ?? under.color,
    casing: casing ?? under.casing,
    radius: radius ?? under.radius,
    width: width ?? under.width,
    dashed: dashed ?? under.dashed,
  );
}

/// What a marker, a line or a circle does when clicked: sends its [event], or opens
/// its [menu] and sends the item picked.
class SceneMapItem {
  final String id;
  final String? style;
  final SceneMapLook own;
  final String? event;
  final SceneMenu? menu;

  SceneMapItem(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      style = json['style'] == null ? null : string(json, 'style'),
      own = SceneMapLook(json),
      event = json['event'] == null ? null : string(json, 'event'),
      menu = sceneMenu(json);

  bool get acts => event != null || menu != null;
}

class SceneMapMarker extends SceneMapItem {
  final double lat, lon;

  SceneMapMarker(super.json) : lat = number(json, 'lat', min: -90, max: 90), lon = number(json, 'lon', min: -540, max: 540);
}

/// The great circle between two places, each a marker's id or `{ lat, lon }`.
class SceneMapLine extends SceneMapItem {
  final Object from, to;

  SceneMapLine(super.json) : from = _end(json, 'from'), to = _end(json, 'to');

  static Object _end(Map<dynamic, dynamic> json, String key) => switch (json[key]) {
    final String id => id,
    final Map<dynamic, dynamic> at => (lat: number(at, 'lat', min: -90, max: 90), lon: number(at, 'lon', min: -540, max: 540)),
    _ => throw FormatException('Invalid map line end: $key'),
  };
}

/// The places [km] round [at], a marker's id or `{ lat, lon }`: a circle on
/// the Earth, which on most maps is no circle. Its look's `fill` fills it.
class SceneMapCircle extends SceneMapItem {
  /// Half the way round the Earth: past it, a circle closes in on the antipode.
  static const maxKm = 20015.0;

  final Object at;
  final double km;

  SceneMapCircle(super.json) : at = SceneMapLine._end(json, 'at'), km = number(json, 'km', min: 0, max: maxKm) {
    if (km <= 0) throw const FormatException('A map circle is more than 0 km round');
  }
}

/// A `map` control: the world in a projection, a view the operator zooms
/// and pans within the scene's limits, and the markers and lines the scene
/// places on it by latitude and longitude.
class SceneMapSpec {
  static const keys = [
    'projection', 'home', 'origin', 'map', 'zoom', 'pan', 'styles', 'markers', 'lines', 'circles', //
    'zoomValue', 'hoverLat', 'hoverLon', 'actions', 'gestures',
  ];

  static const maxMarkers = 4096;
  static const maxLines = 1024;
  static const maxCircles = 256;
  static const maxStyles = 64;
  static const double zoomFloor = 0;
  static const double zoomCeiling = 16;

  /// `mercator` (Web Mercator), `equirectangular`, `miller`, `patterson`,
  /// `azimuthal` (equidistant) or `robinson`.
  final String projection;

  /// The place in the view's middle until the operator pans; null, the operation's location.
  final ({double lat, double lon})? home;

  /// Where the projection is centred — the azimuthal map's middle, the
  /// others' central meridian; null, [home].
  final ({double lat, double lon})? origin;
  final SceneMapStyle map;

  /// 0 fits the whole world; each step closer doubles the scale.
  final double zoomMin, zoomMax;
  final SceneNumber? zoom;

  /// What the view may be panned over; null, the whole world.
  final ({double north, double south, double west, double east})? panBounds;

  /// Whether the view stays on the world, or within [panBounds], never
  /// showing past their edge: the widest zoom is the one that fills the pane.
  final bool panCover;

  final Map<String, SceneMapLook> styles;
  final List<SceneMapMarker> markers;
  final List<SceneMapLine> lines;
  final List<SceneMapCircle> circles;

  /// Scene values the control writes: its zoom, and the place under the pointer.
  final String? zoomValue, hoverLat, hoverLon;

  /// Whether the host's whole-map button is drawn.
  final bool actions;

  /// `native` or `off`.
  final String zoomGesture, panGesture;

  SceneMapSpec(Map<dynamic, dynamic> json)
    : projection = _oneOf(json, 'projection', const ['mercator', 'equirectangular', 'miller', 'patterson', 'azimuthal', 'robinson']) ?? 'mercator',
      home = switch (json['home']) {
        null => null,
        final Map<dynamic, dynamic> h => (lat: number(h, 'lat', min: -90, max: 90), lon: number(h, 'lon', min: -540, max: 540)),
        _ => throw const FormatException('Invalid map home'),
      },
      origin = switch (json['origin']) {
        null => null,
        final Map<dynamic, dynamic> o => (lat: number(o, 'lat', min: -90, max: 90), lon: number(o, 'lon', min: -540, max: 540)),
        _ => throw const FormatException('Invalid map origin'),
      },
      map = json['map'] == null ? SceneMapStyle.none : SceneMapStyle(_map(json, 'map')),
      zoomMin = number(_part(json, 'zoom'), 'min', fallback: zoomFloor, min: zoomFloor, max: zoomCeiling),
      zoomMax = number(_part(json, 'zoom'), 'max', fallback: 10, min: zoomFloor, max: zoomCeiling),
      zoom = SceneNumber.parse(_part(json, 'zoom'), 'initial', min: zoomFloor, max: zoomCeiling),
      panBounds = switch (_part(json, 'pan')['bounds']) {
        null => null,
        final Map<dynamic, dynamic> b => (
          north: number(b, 'north', min: -90, max: 90),
          south: number(b, 'south', min: -90, max: 90),
          west: number(b, 'west', min: -540, max: 540),
          east: number(b, 'east', min: -540, max: 540),
        ),
        _ => throw const FormatException('Invalid map pan bounds'),
      },
      panCover = switch (_part(json, 'pan')['cover']) {
        null || false => false,
        true => true,
        _ => throw const FormatException('Invalid map pan cover'),
      },
      styles = switch (json['styles']) {
        null => const {},
        final Map<dynamic, dynamic> s when s.length <= maxStyles => {
          for (final MapEntry(:key, :value) in s.entries)
            string({'style': key}, 'style'): value is Map ? SceneMapLook(value) : throw FormatException('Invalid map style: $key'),
        },
        final Map<dynamic, dynamic> s => throw _overCount('map styles', s.length, maxStyles),
        _ => throw const FormatException('Invalid map styles'),
      },
      markers = [for (final m in items(json['markers'] ?? const [], maxMarkers, what: 'map markers')) _item(m, SceneMapMarker.new)],
      lines = [for (final l in items(json['lines'] ?? const [], maxLines, what: 'map lines')) _item(l, SceneMapLine.new)],
      circles = [for (final c in items(json['circles'] ?? const [], maxCircles, what: 'map circles')) _item(c, SceneMapCircle.new)],
      zoomValue = json['zoomValue'] == null ? null : string(json, 'zoomValue'),
      hoverLat = json['hoverLat'] == null ? null : string(json, 'hoverLat'),
      hoverLon = json['hoverLon'] == null ? null : string(json, 'hoverLon'),
      actions = json['actions'] != false,
      zoomGesture = _gesture(json, 'zoom'),
      panGesture = _gesture(json, 'pan') {
    if (zoomMin > zoomMax) throw const FormatException('A map zoom min is past its max, 10 where it gives none');
    if (panBounds case final b? when b.south >= b.north) throw const FormatException('A map pan bounds south is past its north');
    final ids = <String>{};
    for (final item in [...markers, ...lines, ...circles]) {
      if (!ids.add(item.id)) throw FormatException('Duplicate map marker, line or circle ID: ${item.id}');
      if (item.style case final style? when !styles.containsKey(style)) throw FormatException('Unknown map style: ${item.id}');
    }
    final markerIds = {for (final m in markers) m.id};
    for (final line in lines) {
      for (final end in [line.from, line.to]) {
        if (end is String && !markerIds.contains(end)) throw FormatException('A map line ends at a marker it does not have: ${line.id}');
      }
    }
    for (final circle in circles) {
      if (circle.at case final String id when !markerIds.contains(id)) throw FormatException('A map circle is round a marker it does not have: ${circle.id}');
    }
  }

  static Map<dynamic, dynamic> _part(Map<dynamic, dynamic> json, String key) => switch (json[key]) {
    null => const {},
    final Map<dynamic, dynamic> part => part,
    _ => throw FormatException('Invalid map $key'),
  };

  /// A marker or line, its id named in the refusal: among thousands, "Invalid scene color" alone leaves the author to find which.
  static T _item<T>(Map<dynamic, dynamic> json, T Function(Map<dynamic, dynamic>) make) {
    try {
      return make(json);
    } on FormatException catch (e) {
      final id = json['id'];
      if (id is! String || e.message.endsWith(': $id')) rethrow;
      throw FormatException('${e.message}: $id');
    }
  }

  static String _gesture(Map<dynamic, dynamic> json, String key) {
    final gestures = json['gestures'];
    if (gestures == null) return 'native';
    if (gestures is! Map) throw const FormatException('Invalid map gestures');
    return _oneOf(gestures, key, const ['native', 'off']) ?? 'native';
  }

  /// A marker or line's look: its own fields, over its style's.
  SceneMapLook lookOf(SceneMapItem item) => item.own.over(styles[item.style] ?? SceneMapLook.empty);

  Iterable<String> get valueNames => [?zoom?.value, ?zoomValue, ?hoverLat, ?hoverLon];

  /// The values the control writes rather than the extension.
  Iterable<String> get written => [?zoomValue, ?hoverLat, ?hoverLon];
}
