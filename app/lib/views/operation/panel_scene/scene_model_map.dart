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

  /// The document's object this was read from.
  final Map<dynamic, dynamic> source;
  final String? style;
  final SceneMapLook own;
  final String? event;
  final SceneMenu? menu;

  SceneMapItem(Map<dynamic, dynamic> json)
    : source = json,
      id = string(json, 'id'),
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

/// Text set along a line or a circle's edge, contour style: turned to run
/// with the edge where it sits, upright, the edge cut under it.
class SceneMapLabel {
  /// The words; null on a circle, its distance.
  final String? text;

  /// A circle's distance's unit, `km` or `mi`; null, the operator's.
  final String? unit;

  /// Where it sits: on a circle, its bearing from the middle; on a line, its
  /// share of the way from the start. Null, wherever the view shows the
  /// edge, as near the circle's north or the line's middle as it can.
  final double? az, along;

  /// Its font size, in pixels.
  final double size;
  final Color? color;

  const SceneMapLabel._({this.text, this.unit, this.az, this.along, this.size = 11, this.color});

  /// [json]'s `label`: its text, `true` for a circle's distance, or the
  /// fields. A line's has text: it has no distance to show.
  static SceneMapLabel? parse(Map<dynamic, dynamic> json, {required bool circle}) {
    final raw = json['label'];
    if (raw is Map) {
      // Each kind's own fields: one on the other kind would be dropped, the label put somewhere the author did not say.
      for (final key in circle ? const ['along'] : const ['unit', 'az']) {
        if (raw[key] != null) throw FormatException('A map ${circle ? 'circle' : 'line'} label has no $key');
      }
    }
    final label = switch (raw) {
      null || false => null,
      true when circle => const SceneMapLabel._(),
      true => throw const FormatException('A map line label has text: a line has no distance to show'),
      final String _ => SceneMapLabel._(text: string(json, 'label')),
      final Map<dynamic, dynamic> l => SceneMapLabel._(
        text: l['text'] == null ? null : string(l, 'text'),
        unit: _oneOf(l, 'unit', const ['km', 'mi']),
        az: l['az'] == null ? null : number(l, 'az', min: -360, max: 720),
        along: l['along'] == null ? null : number(l, 'along', min: 0, max: 1),
        size: number(l, 'size', fallback: 11, min: 4, max: 72),
        color: _color(l, 'color'),
      ),
      _ => throw const FormatException('Invalid map label'),
    };
    if (label != null && !circle && label.text == null) throw const FormatException('A map line label has text: a line has no distance to show');
    // Empty, it would draw nothing and still cut the lines under it.
    if (label?.text?.trim().isEmpty ?? false) throw const FormatException('A map label has words');
    return label;
  }
}

/// The way between places, each a marker's id or `{ lat, lon }`: from
/// [from] to [to], or through [points]; each step along a great circle.
class SceneMapLine extends SceneMapItem {
  /// The most [points] one line runs through.
  static const maxPoints = 4096;

  /// The places it runs through, in order: `from` and `to`, or `points`.
  final List<Object> points;

  /// Whether it runs on from its last point back to its first: a contour.
  final bool closed;
  final SceneMapLabel? label;

  SceneMapLine(super.json)
    : points = _points(json),
      closed = switch (json['closed']) {
        null || false => false,
        true => true,
        _ => throw const FormatException('Invalid map line closed'),
      },
      label = SceneMapLabel.parse(json, circle: false);

  /// How many steps its great circles take, a step a degree and a step for
  /// any shorter, its points places: counted once, as a line a patch left
  /// alone is carried from scene to scene.
  late final int steps = stepsThrough(const {});

  /// [steps], with its markers' places from [markers].
  int stepsThrough(Map<String, SceneMapMarker> markers) {
    final places = [
      for (final p in points)
        switch (p) {
          final String id => (lat: markers[id]?.lat ?? 0, lon: markers[id]?.lon ?? 0),
          final ({double lat, double lon}) at => at,
          _ => (lat: 0.0, lon: 0.0),
        },
    ];
    if (closed) places.add(places.first);
    var steps = 0;
    for (var i = 0; i + 1 < places.length; i++) {
      steps += math.max(1, degreesApart(places[i].lat, places[i].lon, places[i + 1].lat, places[i + 1].lon).ceil());
    }
    return steps;
  }

  static List<Object> _points(Map<dynamic, dynamic> json) {
    final raw = json['points'];
    if (raw == null) {
      if (json['from'] == null && json['to'] == null) throw const FormatException('A map line runs from and to two places, or through its points');
      return [_end(json, 'from'), _end(json, 'to')];
    }
    if (json['from'] != null || json['to'] != null) throw const FormatException('A map line runs from and to two places, or through its points');
    if (raw is! List) throw const FormatException('Invalid map line points');
    if (raw.length > maxPoints) throw _overCount('map line points', raw.length, maxPoints);
    if (raw.length < 2) throw const FormatException('A map line runs through two points or more');
    final points = <Object>[];
    for (final (i, p) in raw.indexed) {
      try {
        points.add(_end({'point': p}, 'point'));
      } on FormatException catch (e) {
        // Among thousands, the one at fault named.
        throw FormatException('${e.message} at points[$i]');
      }
    }
    return points;
  }

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
  final SceneMapLabel? label;

  SceneMapCircle(super.json)
    : at = SceneMapLine._end(json, 'at'),
      km = number(json, 'km', min: 0, max: maxKm),
      label = SceneMapLabel.parse(json, circle: true) {
    if (km <= 0) throw const FormatException('A map circle is more than 0 km round');
  }
}

/// A picture laid on the map by its corners — top left, top right, bottom
/// right, bottom left — each a place; or by `bounds`, the box between two
/// parallels and two meridians. The picture's inside falls evenly in
/// latitude and longitude between them, so a picture of the world in plate
/// carrée given its edges lands where it shows in every projection.
class SceneMapOverlay {
  /// The most overlays one map holds.
  static const maxOverlays = 16;

  final String id;
  final String image;
  final List<({double lat, double lon})> corners;
  final double opacity;

  /// The document's object this was read from.
  final Map<dynamic, dynamic> source;

  SceneMapOverlay(Map<dynamic, dynamic> json)
    : source = json,
      id = string(json, 'id'),
      image = sceneImage(json, 'image'),
      opacity = number(json, 'opacity', fallback: 1, min: 0, max: 1),
      corners = _corners(json);

  static List<({double lat, double lon})> _corners(Map<dynamic, dynamic> json) {
    ({double lat, double lon}) place(Object? raw) => switch (raw) {
      final Map<dynamic, dynamic> p => (lat: number(p, 'lat', min: -90, max: 90), lon: number(p, 'lon', min: -540, max: 540)),
      _ => throw const FormatException('Invalid map overlay corner'),
    };
    final corners = json['corners'], bounds = json['bounds'];
    if ((corners == null) == (bounds == null)) throw const FormatException('A map overlay is placed by its corners or its bounds');
    if (corners != null) {
      if (corners is! List || corners.length != 4) throw const FormatException('A map overlay has four corners');
      return [for (final c in corners) place(c)];
    }
    if (bounds is! Map) throw const FormatException('Invalid map overlay bounds');
    final north = number(bounds, 'north', min: -90, max: 90), south = number(bounds, 'south', min: -90, max: 90);
    final west = number(bounds, 'west', min: -540, max: 540), east = number(bounds, 'east', min: -540, max: 540);
    if (south >= north) throw const FormatException('A map overlay bounds south is past its north');
    // An east less than the west crosses the antimeridian, as pan bounds do.
    final right = east >= west ? east : east + 360;
    return [(lat: north, lon: west), (lat: north, lon: right), (lat: south, lon: right), (lat: south, lon: west)];
  }
}

/// A `map` control: the world in a projection, a view the operator zooms
/// and pans within the scene's limits, and the markers and lines the scene
/// places on it by latitude and longitude.
class SceneMapSpec {
  static const keys = [
    'projection', 'home', 'origin', 'map', 'zoom', 'pan', 'styles', 'markers', 'lines', 'circles', 'images', //
    'zoomValue', 'hoverLat', 'hoverLon', 'actions', 'gestures',
  ];

  static const maxMarkers = 4096;
  static const maxLines = 1024;

  /// The most steps all of a map's lines take in all, each the great circle
  /// between two of a line's places, counted a step a degree and a step
  /// for any shorter: each degree is a point on it, placed on the screen
  /// every frame it is in view. 1,024 lines across half the Earth fit;
  /// 65,536 places a world apart, four million times a degree, would not.
  static const maxLineSteps = 262144;
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

  /// Whether the view zooms out no further than the world, or [panBounds],
  /// fills the pane's height, pole to pole, whatever its width; without it,
  /// out to the whole world, centered.
  final bool panCover;

  /// Whether a map that goes round the world (no [panBounds], not the
  /// azimuthal) repeats it east and west across the pane's spare width;
  /// false, it shows it once and a pan turns it under the view.
  final bool panRepeat;

  final Map<String, SceneMapLook> styles;
  final List<SceneMapMarker> markers;
  final List<SceneMapLine> lines;
  final List<SceneMapCircle> circles;

  /// Pictures laid on the world, under the circles, lines and markers, a
  /// later one over an earlier.
  final List<SceneMapOverlay> overlays;

  /// Scene values the control writes: its zoom, and the place under the pointer.
  final String? zoomValue, hoverLat, hoverLon;

  /// Whether the host's whole-map button is drawn.
  final bool actions;

  /// `native` or `off`; a zoom also `center`, about the view's middle
  /// rather than the pointer.
  final String zoomGesture, panGesture;

  /// [previous], this map in the scene before, lends every marker, line and
  /// circle read from the very object it was: a patch to one marker of
  /// thousands reads that one.
  SceneMapSpec(Map<dynamic, dynamic> json, {SceneMapSpec? previous})
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
      panRepeat = switch (_part(json, 'pan')['repeat']) {
        null || true => true,
        false => false,
        _ => throw const FormatException('Invalid map pan repeat'),
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
      markers = [
        for (final m in items(json['markers'] ?? const [], maxMarkers, what: 'map markers'))
          previous?._from[m] as SceneMapMarker? ?? _item(m, SceneMapMarker.new),
      ],
      lines = [
        for (final l in items(json['lines'] ?? const [], maxLines, what: 'map lines')) previous?._from[l] as SceneMapLine? ?? _item(l, SceneMapLine.new),
      ],
      overlays = [for (final o in items(json['images'] ?? const [], SceneMapOverlay.maxOverlays, what: 'map images')) _item(o, SceneMapOverlay.new)],
      circles = [
        for (final c in items(json['circles'] ?? const [], maxCircles, what: 'map circles'))
          previous?._from[c] as SceneMapCircle? ?? _item(c, SceneMapCircle.new),
      ],
      zoomValue = json['zoomValue'] == null ? null : string(json, 'zoomValue'),
      hoverLat = json['hoverLat'] == null ? null : string(json, 'hoverLat'),
      hoverLon = json['hoverLon'] == null ? null : string(json, 'hoverLon'),
      actions = json['actions'] != false,
      zoomGesture = _gesture(json, 'zoom'),
      panGesture = _gesture(json, 'pan') {
    if (zoomMin > zoomMax) throw const FormatException('A map zoom min is past its max, 10 where it gives none');
    final byId = {for (final m in markers) m.id: m};
    var steps = 0;
    for (final line in lines) {
      steps += line.points.any((p) => p is String) ? line.stepsThrough(byId) : line.steps;
      if (steps > maxLineSteps) throw _overCount('degrees of map lines in all', steps, maxLineSteps);
    }
    if (panBounds case final b? when b.south >= b.north) throw const FormatException('A map pan bounds south is past its north');
    final ids = <String>{};
    for (final item in [...markers, ...lines, ...circles]) {
      if (!ids.add(item.id)) throw FormatException('Duplicate map marker, line or circle ID: ${item.id}');
      if (item.style case final style? when !styles.containsKey(style)) throw FormatException('Unknown map style: ${item.id}');
    }
    final markerIds = {for (final m in markers) m.id};
    for (final line in lines) {
      for (final end in line.points) {
        if (end is String && !markerIds.contains(end)) throw FormatException('A map line runs through a marker it does not have: ${line.id}');
      }
    }
    for (final circle in circles) {
      if (circle.at case final String id when !markerIds.contains(id)) throw FormatException('A map circle is round a marker it does not have: ${circle.id}');
    }
    if (overlays.map((o) => o.id).toSet().length != overlays.length) throw const FormatException('Duplicate map image ID');
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
      // A budget stays one: the operator is told a limit was passed, not that the scene is broken.
      if (e is PanelContentRefusal) throw PanelContentRefusal(e.budget, e.max, '${e.message}: $id');
      throw FormatException('${e.message}: $id');
    }
  }

  static String _gesture(Map<dynamic, dynamic> json, String key) {
    final gestures = json['gestures'];
    if (gestures == null) return 'native';
    if (gestures is! Map) throw const FormatException('Invalid map gestures');
    return _oneOf(gestures, key, key == 'zoom' ? const ['native', 'center', 'off'] : const ['native', 'off']) ?? 'native';
  }

  late final Map<Map<dynamic, dynamic>, SceneMapItem> _from = Map.identity()..addEntries([...markers, ...lines, ...circles].map((i) => MapEntry(i.source, i)));

  /// A marker or line's look: its own fields, over its style's.
  SceneMapLook lookOf(SceneMapItem item) => item.own.over(styles[item.style] ?? SceneMapLook.empty);

  Iterable<String> get valueNames => [?zoom?.value, ?zoomValue, ?hoverLat, ?hoverLon];

  /// The values the control writes rather than the extension.
  Iterable<String> get written => [?zoomValue, ?hoverLat, ?hoverLon];
}
