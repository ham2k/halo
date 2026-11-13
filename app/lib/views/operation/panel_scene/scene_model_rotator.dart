// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A rotator map's own fields: the map, its rim and range rings, and the
// layers it draws over the map where a bearing and a distance, or a place on
// Earth, put them (docs/design/panel-scenes.md § Rotator map).

part of 'scene_model.dart';

/// A bearing: a rotator's `heading` or `target`, the bearing to the station
/// in the call field (`call`), or `az:` and degrees or a scene value — then
/// degrees added (`heading+15deg`). A number is that many degrees.
class SceneRotatorAngle {
  final SceneRotatorAngleBase base;

  /// For [SceneRotatorAngleBase.az]: the degrees, or a scene value naming them.
  final SceneNumber? degrees;
  final double offset;

  const SceneRotatorAngle._(this.base, {this.degrees, this.offset = 0});

  static final _shape = RegExp(r'^(?:(heading|target|call)|az:(-?\d+(?:\.\d+)?|[A-Za-z_][\w.]*))?((?:[+-]\d+(?:\.\d+)?deg)*)$');

  static SceneRotatorAngle? parse(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    if (raw is num) return SceneRotatorAngle._(SceneRotatorAngleBase.az, degrees: SceneNumber._(number(json, key, min: -3600, max: 3600), null, -3600, 3600));
    final match = raw is String && raw.isNotEmpty && raw.length <= 64 ? _shape.firstMatch(raw) : null;
    if (match == null || (match.group(1) == null && match.group(2) == null)) throw FormatException('Invalid rotator bearing: $key');
    var offset = 0.0;
    for (final term in RegExp(r'([+-]\d+(?:\.\d+)?)deg').allMatches(match.group(3)!)) {
      offset += double.parse(term.group(1)!);
    }
    if (offset.abs() > 3600) throw FormatException('Rotator bearing out of range: $key');
    return switch (match.group(1)) {
      'heading' => SceneRotatorAngle._(SceneRotatorAngleBase.heading, offset: offset),
      'target' => SceneRotatorAngle._(SceneRotatorAngleBase.target, offset: offset),
      'call' => SceneRotatorAngle._(SceneRotatorAngleBase.call, offset: offset),
      _ => SceneRotatorAngle._(
        SceneRotatorAngleBase.az,
        offset: offset,
        degrees: switch (match.group(2)!) {
          final name when double.tryParse(name) != null => SceneNumber._(double.parse(name), null, -3600, 3600),
          final name => SceneNumber._(null, name, -3600, 3600),
        },
      ),
    };
  }

  /// The scene value it names, if any.
  String? get valueName => degrees?.value;
}

enum SceneRotatorAngleBase { heading, target, call, az }

/// A distance from the station along a bearing: the `rim` there, or the
/// `center`, then a share of the way to the rim (`%`), kilometres or miles
/// on the ground (`km`, `mi`), and pixels (`px`) — `rim-8px`, `60%`,
/// `1000km+4px`. A number is pixels.
class SceneRotatorRadius {
  /// From the rim rather than the centre.
  final bool rim;
  final double share, km, px;

  const SceneRotatorRadius._({this.rim = false, this.share = 0, this.km = 0, this.px = 0});

  static const center = SceneRotatorRadius._();
  static const atRim = SceneRotatorRadius._(rim: true);

  static final _shape = RegExp(r'^(rim|center)?((?:[+-]?\d+(?:\.\d+)?(?:%|km|mi|px))*)$');

  static SceneRotatorRadius? parse(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return null;
    if (raw is num) return SceneRotatorRadius._(px: number(json, key, min: -8192, max: 8192));
    final match = raw is String && raw.isNotEmpty && raw.length <= 64 ? _shape.firstMatch(raw) : null;
    if (match == null) throw FormatException('Invalid rotator distance: $key');
    var (share, km, px) = (0.0, 0.0, 0.0);
    for (final term in RegExp(r'([+-]?\d+(?:\.\d+)?)(%|km|mi|px)').allMatches(match.group(2)!)) {
      final n = double.parse(term.group(1)!);
      switch (term.group(2)) {
        case '%':
          share += n / 100;
        case 'km':
          km += n;
        case 'mi':
          km += n * 1.609344;
        default:
          px += n;
      }
    }
    if (share.abs() > 10 || km.abs() > 40075 || px.abs() > 8192) throw FormatException('Rotator distance out of range: $key');
    return SceneRotatorRadius._(rim: match.group(1) == 'rim', share: share, km: km, px: px);
  }

  /// Pixels from the station, where the rim is [rimPx] away along the
  /// bearing and a kilometre is [pxPerKm].
  double resolve(double rimPx, double pxPerKm) => (rim ? rimPx : 0) + share * rimPx + km * pxPerKm + px;
}

/// Where a layer puts something: a bearing and a distance from the station;
/// a place on Earth (`lat`, `lon`), or the station in the call field
/// (`place: 'call'`); or a share of the way along another layer's line
/// (`on`, `along`) — then screen pixels that do not turn with the bearing
/// (`dx`, `dy`, right and down).
class SceneRotatorPoint {
  final SceneRotatorAngle? az;
  final SceneRotatorRadius? r;
  final double? lat, lon;

  /// The station in the call field, where its lookup puts it.
  final bool call;
  final String? on;
  final double along;
  final double dx, dy;

  SceneRotatorPoint(Map<dynamic, dynamic> json)
    : az = SceneRotatorAngle.parse(json, 'az'),
      r = SceneRotatorRadius.parse(json, 'r'),
      lat = json['lat'] == null ? null : number(json, 'lat', min: -90, max: 90),
      lon = json['lon'] == null ? null : number(json, 'lon', min: -540, max: 540),
      call = switch (json['place']) {
        null => false,
        'call' => true,
        _ => throw const FormatException('Invalid rotator place'),
      },
      on = json['on'] == null ? null : string(json, 'on'),
      along = number(json, 'along', fallback: 1, min: -10, max: 10),
      dx = number(json, 'dx', fallback: 0, min: -8192, max: 8192),
      dy = number(json, 'dy', fallback: 0, min: -8192, max: 8192) {
    final kinds = [az != null || r != null, lat != null || lon != null, call, on != null].where((k) => k).length;
    if (kinds != 1) throw const FormatException('A rotator point is a bearing and distance, a lat and lon, the call\'s place, or a place on another layer');
    if ((lat == null) != (lon == null)) throw const FormatException('A rotator point needs both lat and lon');
    if (json['along'] != null && on == null) throw const FormatException('A rotator point takes along only on another layer');
  }

  static SceneRotatorPoint? parse(Map<dynamic, dynamic> json, String key) => switch (json[key]) {
    null => null,
    final Map<dynamic, dynamic> point => SceneRotatorPoint(point),
    _ => throw FormatException('Invalid rotator point: $key'),
  };

  bool get geographic => lat != null || call;
}

/// [defaults] stands for the host's own decorations — the beam, the target,
/// the heading and the station in the call field — drawn at that place in a
/// scene's list, so a scene can draw under and over them without drawing
/// them itself, in colors it cannot see.
enum SceneRotatorLayerKind { line, wedge, circle, text, svg, defaults }

/// The ids of the host's own decorations, which a later layer may place a point `on`.
const sceneRotatorDefaultLines = {'target', 'heading'};

/// What a drag on a layer does: turns the rotator to where the pointer
/// points (`turn`), or moves its target by [degPerPx] for every pixel the
/// pointer goes along [axis]. The rotator is told once, on release.
class SceneRotatorDrag {
  final String? axis;
  final double degPerPx;

  const SceneRotatorDrag._(this.axis, this.degPerPx);

  static SceneRotatorDrag? parse(Object? raw) => switch (raw) {
    null => null,
    'turn' => const SceneRotatorDrag._(null, 0),
    final Map<dynamic, dynamic> json => SceneRotatorDrag._(
      _oneOf(json, 'axis', const ['x', 'y']) ?? (throw const FormatException('A rotator drag needs an axis')),
      number(json, 'degPerPx', fallback: 1, min: -36, max: 36),
    ),
    _ => throw const FormatException('Invalid rotator drag'),
  };

  bool get turn => axis == null;
}

/// Something a rotator map draws over the map, in order, each over the ones
/// before: a line (an arrow with a [head]), a wedge between two bearings, a
/// circle, text or artwork.
class SceneRotatorLayer {
  static const maxCount = 256;

  final String id;
  final SceneRotatorLayerKind kind;

  /// A line's ends; a circle's, text's or artwork's place is [at].
  final SceneRotatorPoint? from, to, at;

  /// A wedge's bearings and distances; omitted, from the centre to the rim.
  final SceneRotatorAngle? az, az2;
  final SceneRotatorRadius? r, r2;

  /// The rotator its `heading` and `target` are; null, the control's.
  final String? rotator;

  final Color? color, fill, background;

  /// In place of [color], and of [fill], while its rotator is turning to a target.
  final Color? turningColor, turningFill;

  /// A line's casing, drawn a pixel wider either side under it and round its
  /// head; or a wedge's, a pixel along the outside of each straight side —
  /// not inside, where it would wash the fill, nor along the arcs, the outer
  /// one mostly lying on the rim — so either stands off whatever it crosses.
  final Color? casing;
  final SceneNumber? width, radius, size, weight, padding;
  final bool dashed, italic;
  final ({double width, double length})? head;

  /// Text: [text], a scene [value], or one of the map's own readings ([show]).
  final String? text, value, show, prefix, suffix, fontFamily;
  final int decimals;
  final String align, valign;
  final String? svg;

  /// Artwork's size, in pixels.
  final double svgWidth, svgHeight;

  final String? event;
  final SceneMenu? menu;
  final SceneRotatorDrag? drag;

  /// A click turns the rotator toward this layer's place.
  final bool aim;

  /// Whether it is cut at the rim; `clip: false` lets it sit on or past it.
  final bool clip;

  /// The readings a text layer may [show]: the rotator's, or its own place's
  /// bearing and distance from the station.
  static const shows = ['heading', 'target', 'elevation', 'bearing', 'km', 'mi'];

  bool get interactive => event != null || menu != null || drag != null || aim;

  SceneRotatorLayer(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      kind = SceneRotatorLayerKind.values.byName(
        _oneOf(json, 'kind', const ['line', 'wedge', 'circle', 'text', 'svg', 'defaults']) ?? (throw const FormatException('A rotator layer needs a kind')),
      ),
      from = SceneRotatorPoint.parse(json, 'from'),
      to = SceneRotatorPoint.parse(json, 'to'),
      at = SceneRotatorPoint.parse(json, 'at'),
      az = SceneRotatorAngle.parse(json, 'az'),
      az2 = SceneRotatorAngle.parse(json, 'az2'),
      r = SceneRotatorRadius.parse(json, 'r'),
      r2 = SceneRotatorRadius.parse(json, 'r2'),
      rotator = json['rotator'] == null ? null : string(json, 'rotator'),
      color = _color(json, 'color'),
      fill = _color(json, 'fill'),
      background = _color(json, 'background'),
      turningColor = _color(json, 'turningColor'),
      turningFill = _color(json, 'turningFill'),
      casing = _color(json, 'casing'),
      width = SceneNumber.parse(json, 'width', min: 0, max: 40),
      radius = SceneNumber.parse(json, 'radius', min: 0, max: 200),
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      padding = SceneNumber.parse(json, 'padding', min: 0, max: 40),
      dashed = json['dashed'] == true,
      italic = json['italic'] == true,
      head = switch (json['head']) {
        null => null,
        final Map<dynamic, dynamic> head => (width: number(head, 'width', min: 1, max: 200), length: number(head, 'length', min: 1, max: 200)),
        _ => throw const FormatException('Invalid rotator arrow head'),
      },
      text = json['text'] == null ? null : string(json, 'text'),
      value = json['value'] == null ? null : string(json, 'value'),
      show = _oneOf(json, 'show', shows),
      prefix = json['prefix'] == null ? null : string(json, 'prefix'),
      suffix = json['suffix'] == null ? null : string(json, 'suffix'),
      fontFamily = json['fontFamily'] == null ? null : string(json, 'fontFamily'),
      decimals = number(json, 'decimals', fallback: 0, min: 0, max: 6).round(),
      align = _oneOf(json, 'align', const ['start', 'center', 'end']) ?? 'center',
      valign = _oneOf(json, 'valign', const ['top', 'center', 'bottom']) ?? 'center',
      svg = json['svg'] == null ? null : string(json, 'svg'),
      svgWidth = number(json, 'svgWidth', fallback: 24, min: 1, max: 1024),
      svgHeight = number(json, 'svgHeight', fallback: 24, min: 1, max: 1024),
      event = json['event'] == null ? null : string(json, 'event'),
      menu = sceneMenu(json),
      drag = SceneRotatorDrag.parse(json['drag']),
      aim = json['aim'] == true,
      clip = json['clip'] != false {
    void need(bool ok, String what) {
      if (!ok) throw FormatException('A rotator ${kind.name} layer $what: $id');
    }

    final line = kind == SceneRotatorLayerKind.line, wedge = kind == SceneRotatorLayerKind.wedge;
    need(line == (from != null && to != null), line ? 'needs from and to' : 'takes no from or to');
    need(!line || at == null, 'takes no at');
    need(wedge == (az != null && az2 != null), wedge ? 'needs az and az2' : 'takes no az or az2');
    need(wedge || (r == null && r2 == null), 'takes no r or r2');
    final defaults = kind == SceneRotatorLayerKind.defaults;
    need(!defaults || json.keys.every((k) => k == 'id' || k == 'kind'), 'takes nothing but its id');
    need(line || wedge || defaults || at != null, 'needs at');
    need(head == null || line, 'takes no head');
    need(casing == null || line || wedge, 'takes no casing');
    need(kind == SceneRotatorLayerKind.text || (text == null && value == null && show == null), 'takes no text');
    need(kind != SceneRotatorLayerKind.text || [text, value, show].where((t) => t != null).length == 1, 'needs one of text, value or show');
    need((kind == SceneRotatorLayerKind.svg) == (svg != null), kind == SceneRotatorLayerKind.svg ? 'needs svg' : 'takes no svg');
    need(!(kind == SceneRotatorLayerKind.circle && color == null && fill == null), 'with no color or fill draws nothing');
    need(!(wedge && color == null && fill == null), 'with no color or fill draws nothing');
    if (svg != null) {
      final refusal = svgArtworkRefusal('rotator layer artwork', svg!);
      if (refusal != null) throw refusal;
    }
    // A click opens the menu or sends the event; one doing both loses one.
    if (event != null && menu != null) throw FormatException('A rotator layer takes an event or a menu, not both: $id');
    if (aim && (event != null || menu != null)) throw FormatException('A rotator layer that aims takes no event or menu: $id');
    if (menu != null && menu!.isEmpty) throw FormatException('A rotator layer menu needs entries: $id');
  }

  Iterable<SceneRotatorPoint> get points => [?from, ?to, ?at];

  Iterable<String> get valueNames => [
    for (final n in [width, radius, size, weight, padding]) ?n?.value,
    for (final a in [az, az2, for (final p in points) p.az]) ?a?.valueName,
    ?value,
  ];
}

/// Tick marks or labels on the rim: every [every] degrees from north, or at
/// the bearings in [at].
class SceneRotatorRimMarks {
  final double? every;
  final List<double>? at;
  final Color? color;
  final double length, width, size, offset;
  final double? weight;

  /// A label's words, by the bearing it stands at; omitted, the bearing in degrees.
  final List<String>? text;

  SceneRotatorRimMarks(Map<dynamic, dynamic> json, {required bool labels})
    : every = json['every'] == null ? null : number(json, 'every', min: 1, max: 360),
      at = switch (json['at']) {
        null => null,
        final List<dynamic> at when at.length <= 360 => [
          for (final a in at) number({'v': a}, 'v', min: -360, max: 720),
        ],
        _ => throw const FormatException('Invalid rim marks at'),
      },
      color = _color(json, 'color'),
      length = number(json, 'length', fallback: 6, min: 0, max: 100),
      width = number(json, 'width', fallback: 1, min: 0, max: 20),
      size = number(json, 'size', fallback: 12, min: 4, max: 72),
      weight = json['weight'] == null ? null : number(json, 'weight', min: 100, max: 900),
      offset = number(json, 'offset', fallback: labels ? 12 : 0, min: -200, max: 200),
      text = json['text'] == null
          ? null
          : [
              for (final t in json['text'] as List) string({'t': t}, 't'),
            ] {
    if ((every == null) == (at == null)) throw const FormatException('Rim marks need every or at');
    if (text != null && (at == null || text!.length != at!.length)) throw const FormatException('Rim label text goes with at, one each');
  }

  /// The bearings it marks, 0–360.
  List<double> get bearings => at ?? [for (var b = 0.0; b < 360 - 1e-9; b += every!) b];
}

/// The rim: the edge of the map, a circle while the whole Earth is in view
/// and a rounded box zoomed in.
class SceneRotatorRim {
  final Color? color, background;
  final double width;
  final List<SceneRotatorRimMarks> ticks, labels;

  SceneRotatorRim(Map<dynamic, dynamic> json)
    : color = _color(json, 'color'),
      background = _color(json, 'background'),
      width = number(json, 'width', fallback: 1.5, min: 0, max: 20),
      ticks = [for (final t in items(json['ticks'] ?? const [], 16, what: 'rim tick sets')) SceneRotatorRimMarks(t, labels: false)],
      labels = [for (final l in items(json['labels'] ?? const [], 16, what: 'rim label sets')) SceneRotatorRimMarks(l, labels: true)];
}

/// A circle at a distance on the ground from the station, with labels on it.
class SceneRotatorRing {
  final double km;
  final String unit;
  final Color? color;
  final double width;
  final bool dashed;
  final List<({double az, String? text, double size, Color? color})> labels;

  SceneRotatorRing(Map<dynamic, dynamic> json)
    : unit = _oneOf(json, 'unit', const ['km', 'mi']) ?? 'km',
      km = number(json, 'distance', min: 1, max: 20038) * (_oneOf(json, 'unit', const ['km', 'mi']) == 'mi' ? 1.609344 : 1),
      color = _color(json, 'color'),
      width = number(json, 'width', fallback: 1, min: 0, max: 20),
      dashed = json['dashed'] == true,
      labels = [
        for (final l in items(json['labels'] ?? const [], 16, what: 'ring labels'))
          (
            az: number(l, 'az', min: -360, max: 720),
            text: l['text'] == null ? null : string(l, 'text'),
            size: number(l, 'size', fallback: 11, min: 4, max: 72),
            color: _color(l, 'color'),
          ),
      ];
}

/// A `rotatorMap` control: one rotator, on a map of the world centred on the
/// station, and whatever the scene draws over it by bearing and distance.
class SceneRotatorSpec {
  static const keys = [
    'rotator', 'home', 'map', 'rim', 'rings', 'zoom', 'pan', 'beamWidth', 'decorations', //
    'headingDeg', 'targetDeg', 'elevationDeg', 'hoverAz', 'hoverKm', 'zoomValue', 'status', 'hud', 'actions', 'snap', 'stops', 'rotators',
  ];

  /// Shared with the band scope: the same word, the same idea.
  static const sharedKeys = ['gestures'];

  /// A rotator's id; null, the station's first.
  final String? rotator;

  /// The map's centre; null, the operation's location.
  final ({double lat, double lon})? home;
  final SceneMapStyle map;

  /// Null: the host's own rim — ticks every 10°, N, E, S and W.
  final SceneRotatorRim? rim;
  final List<SceneRotatorRing> rings;

  /// Null: the host's own decorations — the beam, the target, the station in the call field.
  final List<SceneRotatorLayer>? layers;

  /// The zoom's bounds and the one it starts at (1: the whole Earth fits).
  final double zoomMin, zoomMax;
  final SceneNumber? zoom;

  /// Where the station may be panned — the `square` around the widest
  /// view's circle, or the whole `pane` — and how near that area's edge, as
  /// a share of the pane's shorter side.
  final String panArea;
  final double panMargin;

  /// Where the station is panned to until the operator pans, in pixels from
  /// the pane's middle — for a panel keeping where the operator left it.
  final SceneNumber? panX, panY;

  /// The default decorations' beam, in degrees; 0 draws none.
  final SceneNumber? beamWidth;

  /// How close to the station in the call field, in pixels, a click turns to its exact bearing.
  final double snap;

  /// The only bearings the antenna can point at — a 4-square's four, a
  /// switched array's — each turn landing on the nearest. Empty: any.
  final List<double> stops;

  /// Scene values the control writes: the rotator's heading — the last it
  /// gave, kept while it is not answering, so [status] says whether it is
  /// current — target and elevation, the bearing and distance under the
  /// pointer, and the zoom.
  final String? headingDeg, targetDeg, elevationDeg, hoverAz, hoverKm, zoomValue;

  /// Other rotators whose readings the control writes too — the ones a
  /// scene draws beside its own, by their `rotator` — each into the names given.
  final List<({String rotator, String? headingDeg, String? targetDeg, String? status})> rotators;

  /// A scene string the control writes with the rotator's state:
  /// `connected`, `turning`, `stale`, `connecting`, `disconnecting`,
  /// `disconnected`, `error` or `none` — for a `when` to test.
  final String? status;

  /// Whether the host's heading readout, and its connect, stop and whole-map buttons, are drawn.
  final bool hud, actions;

  /// What a click on the map and a drag of the view do: `native`, `event` or `off`.
  final String turn, zoomGesture, panGesture;

  SceneRotatorSpec(Map<dynamic, dynamic> json)
    : rotator = json['rotator'] == null ? null : string(json, 'rotator'),
      home = switch (json['home']) {
        null => null,
        final Map<dynamic, dynamic> h => (lat: number(h, 'lat', min: -90, max: 90), lon: number(h, 'lon', min: -540, max: 540)),
        _ => throw const FormatException('Invalid rotator home'),
      },
      map = json['map'] == null ? SceneMapStyle.none : SceneMapStyle(_map(json, 'map')),
      rim = json['rim'] == null ? null : SceneRotatorRim(_map(json, 'rim')),
      rings = [for (final r in items(json['rings'] ?? const [], 16, what: 'rotator rings')) SceneRotatorRing(r)],
      layers = json['decorations'] == null
          ? null
          : [for (final l in items(json['decorations'], SceneRotatorLayer.maxCount, what: 'rotator decorations')) _layer(l)],
      zoomMin = number(json['zoom'] is Map ? json['zoom'] as Map : const {}, 'min', fallback: 1, min: 1, max: 100),
      zoomMax = number(json['zoom'] is Map ? json['zoom'] as Map : const {}, 'max', fallback: 20, min: 1, max: 100),
      zoom = json['zoom'] is Map ? SceneNumber.parse(json['zoom'] as Map, 'initial', min: 1, max: 100) : null,
      panArea = _oneOf(json['pan'] is Map ? json['pan'] as Map : const {}, 'area', const ['square', 'pane']) ?? 'pane',
      panMargin = number(json['pan'] is Map ? json['pan'] as Map : const {}, 'margin', fallback: 10, min: 0, max: 50) / 100,
      panX = json['pan'] is Map ? SceneNumber.parse(json['pan'] as Map, 'x', min: -8192, max: 8192) : null,
      panY = json['pan'] is Map ? SceneNumber.parse(json['pan'] as Map, 'y', min: -8192, max: 8192) : null,
      beamWidth = SceneNumber.parse(json, 'beamWidth', min: 0, max: 360),
      snap = number(json, 'snap', fallback: 12, min: 0, max: 100),
      stops = switch (json['stops']) {
        null => const [],
        final List<dynamic> stops when stops.isNotEmpty && stops.length <= 360 => [
          for (final s in stops) (number({'s': s}, 's', min: -360, max: 720) % 360 + 360) % 360,
        ],
        _ => throw const FormatException('Invalid rotator stops'),
      },
      headingDeg = json['headingDeg'] == null ? null : string(json, 'headingDeg'),
      targetDeg = json['targetDeg'] == null ? null : string(json, 'targetDeg'),
      elevationDeg = json['elevationDeg'] == null ? null : string(json, 'elevationDeg'),
      hoverAz = json['hoverAz'] == null ? null : string(json, 'hoverAz'),
      hoverKm = json['hoverKm'] == null ? null : string(json, 'hoverKm'),
      zoomValue = json['zoomValue'] == null ? null : string(json, 'zoomValue'),
      status = json['status'] == null ? null : string(json, 'status'),
      rotators = [
        for (final r in items(json['rotators'] ?? const [], 8, what: 'rotator readouts'))
          (
            rotator: string(r, 'rotator'),
            headingDeg: r['headingDeg'] == null ? null : string(r, 'headingDeg'),
            targetDeg: r['targetDeg'] == null ? null : string(r, 'targetDeg'),
            status: r['status'] == null ? null : string(r, 'status'),
          ),
      ],
      hud = json['hud'] != false,
      actions = json['actions'] != false,
      turn = _gesture(json, 'turn'),
      zoomGesture = _gesture(json, 'zoom'),
      panGesture = _gesture(json, 'pan') {
    if (json['zoom'] != null && json['zoom'] is! Map) throw const FormatException('Invalid rotator zoom');
    if (json['pan'] != null && json['pan'] is! Map) throw const FormatException('Invalid rotator pan');
    if (zoomMin > zoomMax) throw const FormatException('A rotator zoom min is past its max');
    final ids = layers?.map((l) => l.id).toList() ?? const <String>[];
    if (ids.toSet().length != ids.length) throw const FormatException('Duplicate rotator layer ID');
    final defaultsAt = layers?.indexWhere((l) => l.kind == SceneRotatorLayerKind.defaults) ?? -1;
    if (layers != null && layers!.where((l) => l.kind == SceneRotatorLayerKind.defaults).length > 1) {
      throw const FormatException('A rotator map draws its defaults once');
    }
    if (defaultsAt >= 0 && ids.any(sceneRotatorDefaultLines.contains)) {
      throw const FormatException("A rotator layer beside the defaults takes none of their ids");
    }
    // A place along another layer is along a line drawn before it: one
    // drawn after would be placed from where it was last frame, or never.
    for (final (i, layer) in (layers ?? const <SceneRotatorLayer>[]).indexed) {
      for (final point in layer.points) {
        final on = point.on;
        if (on == null) continue;
        // The default heading and target are lines too, once the defaults are drawn.
        if (sceneRotatorDefaultLines.contains(on) && defaultsAt >= 0 && defaultsAt < i) continue;
        final index = ids.indexOf(on);
        if (index < 0 || index >= i || layers![index].kind != SceneRotatorLayerKind.line) {
          throw FormatException('A rotator point is placed on a line drawn before it: ${layer.id}');
        }
      }
    }
  }

  /// A decoration, its id named in the refusal: among 256 of them, "Invalid rotator place" alone leaves the author to find which.
  static SceneRotatorLayer _layer(Map<dynamic, dynamic> json) {
    try {
      return SceneRotatorLayer(json);
    } on FormatException catch (e) {
      final id = json['id'];
      if (id is! String || e.message.endsWith(': $id')) rethrow;
      throw FormatException('${e.message}: $id');
    }
  }

  static String _gesture(Map<dynamic, dynamic> json, String key) {
    final gestures = json['gestures'];
    if (gestures == null) return 'native';
    if (gestures is! Map) throw const FormatException('Invalid rotator gestures');
    // A zoom or a pan only moves the view, which is the host's to draw.
    return _oneOf(gestures, key, key == 'turn' ? const ['native', 'event', 'off'] : const ['native', 'off']) ?? 'native';
  }

  Iterable<String> get valueNames => [
    ?zoom?.value,
    ?panX?.value,
    ?panY?.value,
    ?beamWidth?.value,
    for (final layer in layers ?? const <SceneRotatorLayer>[]) ...layer.valueNames,
    ?headingDeg,
    ?targetDeg,
    ?elevationDeg,
    ?hoverAz,
    ?hoverKm,
    ?zoomValue,
    for (final r in rotators) ...[?r.headingDeg, ?r.targetDeg],
  ];

  /// The scene strings the control writes.
  Iterable<String> get statusNames => [?status, for (final r in rotators) ?r.status];

  /// The values and strings the control writes rather than the extension.
  Iterable<String> get written => [
    ?headingDeg,
    ?targetDeg,
    ?elevationDeg,
    ?hoverAz,
    ?hoverKm,
    ?zoomValue,
    ?status,
    for (final r in rotators) ...[?r.headingDeg, ?r.targetDeg, ?r.status],
  ];
}
