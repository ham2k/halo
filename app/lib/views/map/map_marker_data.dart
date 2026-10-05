// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The backend-agnostic contract every Map tab implementation (OSM, the
// MapLibre webview/web view) accepts — built once by the facade
// (map_panel.dart) from `Qso`/`Operation` domain objects via halo_core's
// location resolution and great-circle math, so no backend widget touches
// halo_core's QSO shape directly or re-derives geo math. Markers are plain
// circles (band-colored for QSOs, black for the QTH); lines are
// pre-densified great-circle polylines, already split at the antimeridian.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData;
import 'package:halo_core/halo_core.dart' show GridLocation;

enum MapMarkerKind { qso, qth }

/// A whole marker — fill, ring and glyph — rasterized once by the facade for
/// the backends that cannot draw one themselves: the GL canvas and the
/// desktop/mobile webview have no access to the app's icon font, so a glyph
/// only reaches them as pixels. The pure-Flutter backend ignores this and
/// builds the same marker from [MapMarkerGlyph.icon] directly.
@immutable
class MapMarkerImage {
  /// Stable identity for these exact pixels (glyph, colors and size folded
  /// into one string). The GL backends register the image under it once, and
  /// [MapMarkerData]'s equality compares it instead of scanning [rgba] on
  /// every rebuild.
  final String id;

  /// Premultiplied RGBA, [width] * [height] * 4 bytes — what
  /// `map.addImage` takes without a decode step, so registering an image
  /// never has to be asynchronous.
  final Uint8List rgba;
  final int width;
  final int height;

  /// Image pixels per logical pixel, so the marker keeps its intended size
  /// on a hidpi display instead of rendering at [width] CSS pixels.
  final double pixelRatio;

  MapMarkerImage({required this.id, required this.rgba, required this.width, required this.height, required this.pixelRatio});

  /// Encoded once per image rather than once per payload: the marker list is
  /// rebuilt whenever the search results change, and re-encoding tens of
  /// kilobytes of pixels on each of those is work whose result is identical
  /// every time — the receiving side skips the image outright once it holds
  /// the [id].
  late final String base64Rgba = base64Encode(rgba);

  @override
  bool operator ==(Object other) => identical(this, other) || (other is MapMarkerImage && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

/// A marker that carries a glyph rather than being a plain dot. The two
/// halves travel together because they are one marker in two forms — the
/// widget the pure-Flutter backend builds, and the pixels every other
/// backend needs — and a marker holding only one of them would look
/// different depending on which backend the platform happened to pick.
@immutable
class MapMarkerGlyph {
  final IconData icon;

  /// The glyph itself, over [MapMarkerData.color]. Both come from whatever
  /// on-screen control the marker mirrors, so the two read as one object.
  final Color color;
  final MapMarkerImage image;

  const MapMarkerGlyph({required this.icon, required this.color, required this.image});

  @override
  bool operator ==(Object other) => identical(this, other) || (other is MapMarkerGlyph && icon == other.icon && color == other.color && image == other.image);

  @override
  int get hashCode => Object.hash(icon, color, image);
}

enum MapProjection { mercator, globe }

@immutable
class MapMarkerData {
  /// `qso.uuid`, or `'qth-<grid>'` for a station marker — a stable key for
  /// widget/annotation identity and the webview JS bridge.
  final String id;
  final double latitude;
  final double longitude;

  /// Callsign, or the grid for a QTH marker — the popup's title when the
  /// facade left [popupTitle] empty.
  final String label;
  final MapMarkerKind kind;

  /// Resolved once by the facade (HaLoColors.bandColor for QSOs, black for
  /// the QTH marker, same as app-polo) so backends never need theme/context
  /// access just to color a circle.
  final Color color;

  /// The ring around the circle's fill — resolved once by the facade (opaque,
  /// so [mapColorToHex] never has to carry alpha) rather than by each backend,
  /// so light/dark mode picks one contrast without three copies of the logic.
  final Color strokeColor;

  /// Signal-strength multiplier for the circle's base radius, 0.7–1.3
  /// (S5 = 1.0, same scaling as app-polo's map).
  final double sizeFactor;

  /// The ring's width, or null for the backend's default for this kind of
  /// marker. Set for a marker drawn as chosen — the Activities map's
  /// selected reference.
  final double? strokeWidth;

  /// Popup first line, e.g. `AB6GS • 1,042 mi` or `QTH: CM97aa`.
  final String popupTitle;

  /// Popup second line, split in three so backends can color just the band
  /// with [color]: `51 • SSB • ` + `20m` + ` • 20:12z`. The facade owns the
  /// ` • ` separators — parts may be empty, but concatenating the three
  /// verbatim always yields the correct line (empty for QTH markers).
  final String popupDetailPrefix;
  final String popupBand;
  final String popupDetailSuffix;

  /// The current (being-composed or -edited) QSO's marker: drawn last, in a
  /// dedicated top layer, so it sits above every other marker AND line. See
  /// map_panel.dart's highlight build.
  final bool highlight;

  /// Drawn inside the circle instead of leaving it plain. Null for the plain
  /// dots that make up every QSO map.
  final MapMarkerGlyph? glyph;

  /// Whether the camera's fit-to-markers counts this one. Off for a marker
  /// that arrives BECAUSE the operator moved the map (the Activities map's
  /// references found by panning): counted, each arrival would refit the
  /// camera and yank the map back from where they had just taken it.
  final bool fitsCamera;

  /// When set, the camera refits only when this changes, not whenever the
  /// fitted markers do. A map whose markers come and go under the operator's
  /// hand — a reference added, a dot hidden when zoomed out — keys its fit to
  /// what should move the camera (a new search) and leaves it alone otherwise.
  /// Null: refit whenever the fitted markers change, as the QSO map does.
  final String? fitKey;

  /// Faded in with the map's zoom, over the band its map names
  /// ([MapZoomFades.markers]) — a suggestion, which zoomed out is one dot in
  /// a smear of them.
  final bool fadesWithZoom;

  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    required this.color,
    required this.strokeColor,
    this.sizeFactor = 1.0,
    this.strokeWidth,
    this.popupTitle = '',
    this.popupDetailPrefix = '',
    this.popupBand = '',
    this.popupDetailSuffix = '',
    this.highlight = false,
    this.glyph,
    this.fitsCamera = true,
    this.fitKey,
    this.fadesWithZoom = false,
  });

  /// This marker with another ring — for a map of the same contacts over a
  /// basemap of the other tone (see [strokeColor]).
  MapMarkerData withStrokeColor(Color strokeColor) => MapMarkerData(
    id: id,
    latitude: latitude,
    longitude: longitude,
    label: label,
    kind: kind,
    color: color,
    strokeColor: strokeColor,
    sizeFactor: sizeFactor,
    strokeWidth: strokeWidth,
    popupTitle: popupTitle,
    popupDetailPrefix: popupDetailPrefix,
    popupBand: popupBand,
    popupDetailSuffix: popupDetailSuffix,
    highlight: highlight,
    glyph: glyph,
    fitsCamera: fitsCamera,
    fitKey: fitKey,
    fadesWithZoom: fadesWithZoom,
  );

  /// This marker drawn as the chosen one: [fill] inside a [ring] of
  /// [ringWidth], [sizeFactor] times its size, and [glyph] in place of its
  /// own when given.
  MapMarkerData asChosen({required Color fill, required Color ring, required double ringWidth, double? sizeFactor, MapMarkerGlyph? glyph}) => MapMarkerData(
    id: id,
    latitude: latitude,
    longitude: longitude,
    label: label,
    kind: kind,
    color: fill,
    strokeColor: ring,
    sizeFactor: sizeFactor ?? this.sizeFactor,
    strokeWidth: ringWidth,
    popupTitle: popupTitle,
    popupDetailPrefix: popupDetailPrefix,
    popupBand: popupBand,
    popupDetailSuffix: popupDetailSuffix,
    highlight: highlight,
    glyph: glyph ?? this.glyph,
    fitsCamera: fitsCamera,
    fitKey: fitKey,
    // The chosen one stays at full strength whatever the zoom: its card is
    // open, and a faded dot would not say which one that is.
  );

  /// This marker with its camera-fit fields replaced — see [fitsCamera] and
  /// [fitKey].
  MapMarkerData withFit({bool? fitsCamera, String? fitKey, bool? fadesWithZoom}) => MapMarkerData(
    id: id,
    latitude: latitude,
    longitude: longitude,
    label: label,
    kind: kind,
    color: color,
    strokeColor: strokeColor,
    sizeFactor: sizeFactor,
    strokeWidth: strokeWidth,
    popupTitle: popupTitle,
    popupDetailPrefix: popupDetailPrefix,
    popupBand: popupBand,
    popupDetailSuffix: popupDetailSuffix,
    highlight: highlight,
    glyph: glyph,
    fitsCamera: fitsCamera ?? this.fitsCamera,
    fitKey: fitKey ?? this.fitKey,
    fadesWithZoom: fadesWithZoom ?? this.fadesWithZoom,
  );

  /// Value equality so `didUpdateWidget`/`listEquals` checks can tell a
  /// same-content rebuild from an actual data change, rather than always
  /// seeing a "different" list because the facade rebuilds a fresh one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapMarkerData &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          label == other.label &&
          kind == other.kind &&
          color == other.color &&
          strokeColor == other.strokeColor &&
          sizeFactor == other.sizeFactor &&
          strokeWidth == other.strokeWidth &&
          popupTitle == other.popupTitle &&
          popupDetailPrefix == other.popupDetailPrefix &&
          popupBand == other.popupBand &&
          popupDetailSuffix == other.popupDetailSuffix &&
          highlight == other.highlight &&
          glyph == other.glyph &&
          fitsCamera == other.fitsCamera &&
          fitKey == other.fitKey &&
          fadesWithZoom == other.fadesWithZoom);

  @override
  int get hashCode => Object.hash(
    id,
    latitude,
    longitude,
    label,
    kind,
    color,
    strokeColor,
    sizeFactor,
    strokeWidth,
    popupTitle,
    popupDetailPrefix,
    popupBand,
    popupDetailSuffix,
    highlight,
    glyph,
    fitsCamera,
    fitKey,
    fadesWithZoom,
  );
}

/// One contiguous polyline of a QSO's great-circle arc back to its QTH —
/// a single QSO contributes two of these when the arc crosses the
/// antimeridian (see halo_core's greatCirclePoints).
@immutable
class MapLineData {
  /// `<qso.uuid>/<segment index>` — stable identity, same role as
  /// [MapMarkerData.id].
  final String id;
  final List<GridLocation> points;
  final Color color;

  /// The current QSO's great-circle line — drawn last in a top layer so it
  /// paints over every other line AND marker. See map_panel.dart's highlight
  /// build.
  final bool highlight;

  const MapLineData({required this.id, required this.points, required this.color, this.highlight = false});

  /// The interior points are a pure function of the endpoints (see
  /// greatCirclePoints), so comparing id + color + length + endpoints is
  /// equivalent to a deep compare — without the O(points) scan that would
  /// otherwise run per line on every `listEquals` in a backend's
  /// `didUpdateWidget`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapLineData &&
          id == other.id &&
          color == other.color &&
          highlight == other.highlight &&
          points.length == other.points.length &&
          (points.isEmpty || (points.first == other.points.first && points.last == other.points.last)));

  @override
  int get hashCode => Object.hash(id, color, highlight, points.length, points.isEmpty ? null : points.first, points.isEmpty ? null : points.last);
}

/// '#RRGGBB' for CSS/GL consumption (alpha stripped — see [mapLinesPayload]).
String mapColorToHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// The JSON shapes consumed by the shared MapLibre GL script (map_gl_script.dart)
/// — one encoder for the two backends that feed it (desktop webview and
/// Flutter web), so the wire format can't drift from the JS that reads it.
List<Map<String, dynamic>> mapMarkersPayload(List<MapMarkerData> markers) => [
  for (final m in markers)
    {
      'id': m.id,
      'latitude': m.latitude,
      'longitude': m.longitude,
      'label': m.label,
      'kind': m.kind.name,
      'color': mapColorToHex(m.color),
      'strokeColor': mapColorToHex(m.strokeColor),
      'sizeFactor': m.sizeFactor,
      'strokeWidth': ?m.strokeWidth,
      'popupTitle': m.popupTitle,
      'popupDetailPrefix': m.popupDetailPrefix,
      'popupBand': m.popupBand,
      'popupDetailSuffix': m.popupDetailSuffix,
      'highlight': m.highlight,
      'fit': m.fitsCamera,
      'fitKey': ?m.fitKey,
      if (m.fadesWithZoom) 'fades': true,
      // Base64 rather than a byte list: both bridges (the webview's
      // string-only channel and the web view's JS interop) carry a
      // string unchanged, while a 9KB list would be walked element by
      // element on the way across.
      if (m.glyph?.image case final image?)
        'image': {'id': image.id, 'rgba': image.base64Rgba, 'width': image.width, 'height': image.height, 'pixelRatio': image.pixelRatio},
    },
];

/// Opacity travels separately — the GL layer paints a flat hex line-color,
/// with the (shared) alpha applied as line-opacity.
Map<String, dynamic> mapLinesPayload(List<MapLineData> lines) => {
  'opacity': lines.isEmpty ? 1.0 : lines.first.color.a.clamp(0.0, 1.0),
  'features': [
    for (final line in lines)
      {
        'type': 'Feature',
        // The id is what a patch removes or replaces by (`mapLinesPatchPayload`).
        'properties': {'id': line.id, 'color': mapColorToHex(line.color), 'highlight': line.highlight},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in line.points) [p.longitude, p.latitude],
          ],
        },
      },
  ],
};

/// How markers shrink as a map zooms out, on the GL scale:
/// [mapMarkerSmallScale] of their size at or below [mapMarkerSmallAtZoom],
/// growing linearly to their full size at [mapMarkerFullAtZoom]. Every marker
/// on every map — zoomed out over a continent, a full-size dot per contact or
/// reference buries the map under them. Plain constants, not a record: the GL
/// script is a const string that interpolates them.
const mapMarkerSmallAtZoom = 3.0;
const mapMarkerFullAtZoom = 8.0;
const mapMarkerSmallScale = 0.5;

/// A marker's size at [glZoom] against its full size — see
/// [mapMarkerSmallAtZoom].
double mapMarkerScaleAt(double glZoom) {
  final t = ((glZoom - mapMarkerSmallAtZoom) / (mapMarkerFullAtZoom - mapMarkerSmallAtZoom)).clamp(0.0, 1.0);
  return mapMarkerSmallScale + (1 - mapMarkerSmallScale) * t;
}

/// A band of zoom, on the GL scale, over which something fades in: invisible
/// at [from], fully shown at [to].
typedef MapZoomFade = ({double from, double to});

/// What a map fades in as it closes in, each null for "never faded":
/// [markers] for the markers with [MapMarkerData.fadesWithZoom],
/// [dashedShapes] for every dashed [MapShapeData], and [solidShapes] for the
/// rest. The backends apply it against their own live zoom, so a fade follows
/// a pinch frame by frame rather than jumping when the gesture ends.
typedef MapZoomFades = ({MapZoomFade? markers, MapZoomFade? dashedShapes, MapZoomFade? solidShapes});

/// How far [fade] has come at [glZoom]: 0 at or below its start, 1 at or past
/// its end. A null fade is always fully shown.
double mapZoomFadeOpacity(MapZoomFade? fade, double glZoom) {
  if (fade == null) return 1;
  if (fade.to <= fade.from) return glZoom >= fade.to ? 1 : 0;
  return ((glZoom - fade.from) / (fade.to - fade.from)).clamp(0.0, 1.0);
}

/// [fades] as the GL script's `setZoomFades` takes it.
Map<String, dynamic> mapZoomFadesPayload(MapZoomFades? fades) => {
  if (fades?.markers case final m?) 'markers': {'from': m.from, 'to': m.to},
  if (fades?.dashedShapes case final d?) 'dashedShapes': {'from': d.from, 'to': d.to},
  if (fades?.solidShapes case final s?) 'solidShapes': {'from': s.from, 'to': s.to},
};

/// One piece of a reference's footprint on the map — a SOTA activation zone,
/// a park's boundary, and whatever other footprints a program publishes (see
/// the `geojsonUrlForRef` hook).
///
/// An area's rings are already in drawing order: the first is the outer
/// boundary and the rest are holes, which is GeoJSON's own convention and what
/// both backends want. A GeoJSON polygon repeats its first point as its last;
/// that closing duplicate is kept, since MapLibre requires it and flutter_map
/// is indifferent.
///
/// A line — a trail or a river that IS the park — has [isLine] set and its
/// one path as the only ring. It is stroked, never filled: closing a trail to
/// fill it would paint the country between its ends.
///
/// A [dashed] shape is a reference the operator is only looking around at —
/// a suggestion nobody has picked. It is a dashed edge with no fill, drawn
/// under every solid shape, so the operation's own footprint and the one
/// whose card is open still read as the subject where the two overlap.
///
/// An [isActivationRadius] shape is the circle a reference's activation
/// radius draws around its coordinate (`refShapes`), not a fetched document:
/// it has no source to credit and nothing for an outline report to name.
@immutable
class MapShapeData {
  /// `<ref type>/<reference>/<shape index>` — one source document can carry
  /// several polygons and lines, and each becomes its own shape.
  final String id;
  final List<List<GridLocation>> rings;
  final Color color;
  final bool isLine;
  final bool dashed;

  /// Not part of equality: it is fixed by the id, like the rings.
  final bool isActivationRadius;

  /// Who the shape comes from, as the map's credit line names it. Not part of
  /// equality: it is fixed by the id, like the rings.
  final String? sourceName;

  /// Where the shape was fetched from, and the reference it outlines as an
  /// operator would name it — what a report of a wrong outline needs to say.
  /// Not part of equality either.
  final String? sourceUrl;
  final String? refLabel;

  const MapShapeData({
    required this.id,
    required this.rings,
    required this.color,
    this.isLine = false,
    this.dashed = false,
    this.isActivationRadius = false,
    this.sourceName,
    this.sourceUrl,
    this.refLabel,
  });

  MapShapeData asDashed() => MapShapeData(
    id: id,
    rings: rings,
    color: color,
    isLine: isLine,
    dashed: true,
    isActivationRadius: isActivationRadius,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
    refLabel: refLabel,
  );

  /// Compared by id, color and [dashed] alone. Shapes are content-addressed —
  /// a given id is always the same fetched document, parsed the same way — so
  /// a deep compare of thousands of points on every `didUpdateWidget` would
  /// only ever confirm what the id already says. [dashed] is in it because
  /// the same reference turns solid when its card opens, and a map that saw
  /// an equal list would keep drawing it dashed.
  @override
  bool operator ==(Object other) => identical(this, other) || (other is MapShapeData && id == other.id && color == other.color && dashed == other.dashed);

  @override
  int get hashCode => Object.hash(id, color, dashed);
}

/// The polygons and lines of a GeoJSON document, or an empty list for anything
/// that has neither.
///
/// Deliberately total: this parses a file fetched from a program's own server,
/// which nothing in the app controls, so every malformed shape is skipped and
/// the map draws what it could read. A throw here would take out the map for a
/// pane the operator opened to look at something else.
///
/// Points are not read: a footprint is an area, or a trail or river that a
/// park is made of, and a lone point is neither.
List<MapShapeData> mapShapesFromGeojson(
  Object? document, {
  required String idPrefix,
  required Color color,
  String? sourceName,
  String? sourceUrl,
  String? refLabel,
}) {
  final shapes = <MapShapeData>[];

  List<GridLocation> pointsOf(Object? path) {
    final points = <GridLocation>[];
    if (path is! List) return points;
    for (final point in path) {
      // GeoJSON is [longitude, latitude], and may carry a third elevation
      // element this ignores.
      if (point is! List || point.length < 2) continue;
      final lon = point[0], lat = point[1];
      if (lon is! num || lat is! num) continue;
      points.add(GridLocation(lat.toDouble(), lon.toDouble()));
    }
    return points;
  }

  void addPolygon(Object? coordinates) {
    if (coordinates is! List) return;
    final rings = <List<GridLocation>>[];
    for (final ring in coordinates) {
      final points = pointsOf(ring);
      // Two points describe no area — a degenerate ring would paint nothing
      // and, as an outer ring, would take a real shape's holes with it.
      if (points.length >= 3) rings.add(points);
    }
    if (rings.isEmpty) return;
    shapes.add(MapShapeData(id: '$idPrefix/${shapes.length}', rings: rings, color: color, sourceName: sourceName, sourceUrl: sourceUrl, refLabel: refLabel));
  }

  void addLine(Object? coordinates) {
    final points = pointsOf(coordinates);
    if (points.length < 2) return;
    shapes.add(
      MapShapeData(
        id: '$idPrefix/${shapes.length}',
        rings: [points],
        color: color,
        isLine: true,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        refLabel: refLabel,
      ),
    );
  }

  void addGeometry(Object? geometry) {
    if (geometry is! Map) return;
    switch (geometry['type']) {
      case 'Polygon':
        addPolygon(geometry['coordinates']);
      case 'MultiPolygon':
        final polygons = geometry['coordinates'];
        if (polygons is List) polygons.forEach(addPolygon);
      case 'LineString':
        addLine(geometry['coordinates']);
      case 'MultiLineString':
        final lines = geometry['coordinates'];
        if (lines is List) lines.forEach(addLine);
      case 'GeometryCollection':
        final geometries = geometry['geometries'];
        if (geometries is List) geometries.forEach(addGeometry);
    }
  }

  if (document is Map && document['type'] == 'FeatureCollection') {
    final features = document['features'];
    if (features is List) {
      for (final feature in features) {
        if (feature is Map) addGeometry(feature['geometry']);
      }
    }
  } else if (document is Map && document['type'] == 'Feature') {
    addGeometry(document['geometry']);
  } else {
    addGeometry(document);
  }
  return shapes;
}

/// The shape a tap at [point] lands on, or null for none.
///
/// A tap within [toleranceMeters] of an edge or a trail takes that shape, the
/// nearest first — a line has no inside to tap, and a dashed outline no fill.
/// Otherwise the smallest area holding the point wins, so a state park inside
/// a national forest is the one a tap in the park picks, rather than whichever
/// shape happened to come first.
MapShapeData? shapeAt(List<MapShapeData> shapes, GridLocation point, {required double toleranceMeters}) {
  MapShapeData? nearestEdge;
  var nearestDistance = double.infinity;
  MapShapeData? smallestArea;
  var smallestSize = double.infinity;
  for (final shape in shapes) {
    final (:edgeDistance, :inside, :size) = measureShape(shape, point);
    if (edgeDistance <= toleranceMeters && edgeDistance < nearestDistance) {
      nearestDistance = edgeDistance;
      nearestEdge = shape;
    }
    if (inside && size < smallestSize) {
      smallestSize = size;
      smallestArea = shape;
    }
  }
  return nearestEdge ?? smallestArea;
}

/// Every shape a tap at [point] touches — holding it, or within
/// [toleranceMeters] of an edge or a trail — with the area of its bounding
/// box in square metres, for a caller that ranks them itself.
List<({MapShapeData shape, double size})> shapesAt(List<MapShapeData> shapes, GridLocation point, {required double toleranceMeters}) => [
  for (final shape in shapes)
    if (measureShape(shape, point) case (:final edgeDistance, :final inside, :final size) when inside || edgeDistance <= toleranceMeters)
      (shape: shape, size: size),
];

/// How far [point] is from [shape]'s nearest edge, whether the shape holds
/// it, and its bounding box's area.
///
/// Measured on a local flat projection around [point], which is exact enough
/// for the few pixels a tap spans and the areas a map on screen can show.
({double edgeDistance, bool inside, double size}) measureShape(MapShapeData shape, GridLocation point) {
  final cosLat = math.cos(point.latitude * math.pi / 180);
  const metersPerDegree = 111320.0;
  (double, double) local(GridLocation p) => ((p.longitude - point.longitude) * cosLat * metersPerDegree, (p.latitude - point.latitude) * metersPerDegree);

  double distanceToSegment((double, double) a, (double, double) b) {
    final (ax, ay) = a;
    final (bx, by) = b;
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0 ? 0.0 : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final x = ax + t * dx, y = ay + t * dy;
    return math.sqrt(x * x + y * y);
  }

  var edgeDistance = double.infinity;
  var inside = false;
  var minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final ring in shape.rings) {
    final points = [for (final p in ring) local(p)];
    for (var i = 0; i < points.length; i++) {
      final (x, y) = points[i];
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      if (i == 0) continue;
      final previous = points[i - 1];
      edgeDistance = math.min(edgeDistance, distanceToSegment(previous, points[i]));
      // Even-odd across every ring, so a point in a hole is outside.
      final (px, py) = previous;
      if (!shape.isLine && (y > 0) != (py > 0) && 0 < px + (-py) * (x - px) / (y - py)) inside = !inside;
    }
  }
  return (edgeDistance: edgeDistance, inside: inside, size: (maxX - minX) * (maxY - minY));
}

/// Fill and outline share one hex color and one alpha pair, the same way
/// [mapLinesPayload] splits color from opacity — the GL layers take a flat
/// paint color with opacity applied separately.
Map<String, dynamic> mapShapesPayload(List<MapShapeData> shapes) => {
  'features': [
    for (final shape in shapes)
      {
        'type': 'Feature',
        'properties': {'color': mapColorToHex(shape.color), 'dashed': shape.dashed},
        'geometry': shape.isLine
            ? {
                'type': 'LineString',
                'coordinates': [
                  for (final p in shape.rings.first) [p.longitude, p.latitude],
                ],
              }
            : {
                'type': 'Polygon',
                'coordinates': [
                  for (final ring in shape.rings)
                    [
                      for (final p in ring) [p.longitude, p.latitude],
                    ],
                ],
              },
      },
  ],
};

/// What changed between two id-keyed lists: the entries to add or replace,
/// each with its index in the new list, and the ids to drop. A backend that
/// patches its source with this instead of replacing it sends one logged
/// contact's marker and line over the bridge rather than every contact's —
/// at a few thousand contacts the whole set is tens of megabytes of JSON per
/// emission, parsed twice.
///
/// Order is part of what a set says (the layers draw in list order, and the
/// host sorts contacts so smaller circles land on top), and a patch names
/// only what changed. So a patch is offered only when the entries present in
/// BOTH lists kept their relative order ([orderKept]): the far side then
/// replaces changed entries in place and inserts new ones at their indices,
/// and the result is the host's list exactly. A list whose unchanged entries
/// moved — a board re-sorted — is a set.
typedef MapDiff<T> = ({List<T> upserts, List<int> indices, List<String> removeIds, bool orderKept});

MapDiff<T> diffById<T>(List<T> before, List<T> after, String Function(T) idOf) {
  final previous = {for (final item in before) idOf(item): item};
  final afterIds = {for (final item in after) idOf(item)};
  final upserts = <T>[];
  final indices = <int>[];
  final keptAfter = <String>[];
  for (var i = 0; i < after.length; i++) {
    final item = after[i];
    final id = idOf(item);
    final was = previous.remove(id);
    if (was != null) keptAfter.add(id);
    // `==` is each type's own: a line compares by id and endpoints, a marker by
    // every field, so a changed popup title is a replacement and a line that
    // merely moved in the list is not.
    if (was == null || was != item) {
      upserts.add(item);
      indices.add(i);
    }
  }
  final keptBefore = [
    for (final item in before)
      if (afterIds.contains(idOf(item))) idOf(item),
  ];
  var orderKept = keptBefore.length == keptAfter.length;
  for (var i = 0; orderKept && i < keptBefore.length; i++) {
    orderKept = keptBefore[i] == keptAfter[i];
  }
  return (upserts: upserts, indices: indices, removeIds: previous.keys.toList(), orderKept: orderKept);
}

MapDiff<MapMarkerData> diffMarkers(List<MapMarkerData> before, List<MapMarkerData> after) => diffById(before, after, (m) => m.id);

MapDiff<MapLineData> diffLines(List<MapLineData> before, List<MapLineData> after) => diffById(before, after, (l) => l.id);

/// Whether a patch is worth sending in place of the whole set. A patch that
/// touches most of the set — the first paint, a theme change that recolours
/// every line — costs the same JSON as the set plus a merge on the far side,
/// so the set goes instead; and one that cannot reproduce the list's order
/// (see [MapDiff]) is not a patch at all.
bool patchIsSmaller<T>(MapDiff<T> diff, {required int total}) {
  final touched = diff.upserts.length + diff.removeIds.length;
  return diff.orderKept && total > 0 && touched > 0 && touched * 2 < total;
}

/// The patch shapes `poloPatchMarkers` / `poloPatchLines` take: the entries
/// to add or replace in the wire shape the set verbs take, each entry's index
/// in the host's list, and the ids to drop. A line patch carries no opacity:
/// every base line shares one, and a change to it recolours every line, which
/// is a set.
Map<String, dynamic> mapMarkersPatchPayload(MapDiff<MapMarkerData> diff) => {
  'upsert': mapMarkersPayload(diff.upserts),
  'indices': diff.indices,
  'removeIds': diff.removeIds,
};

Map<String, dynamic> mapLinesPatchPayload(MapDiff<MapLineData> diff) => {
  'upsert': mapLinesPayload(diff.upserts)['features'],
  'indices': diff.indices,
  'removeIds': diff.removeIds,
};
