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

  MapMarkerImage({
    required this.id,
    required this.rgba,
    required this.width,
    required this.height,
    required this.pixelRatio,
  });

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapMarkerGlyph && icon == other.icon && color == other.color && image == other.image);

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

  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    required this.color,
    required this.strokeColor,
    this.sizeFactor = 1.0,
    this.popupTitle = '',
    this.popupDetailPrefix = '',
    this.popupBand = '',
    this.popupDetailSuffix = '',
    this.highlight = false,
    this.glyph,
  });

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
          popupTitle == other.popupTitle &&
          popupDetailPrefix == other.popupDetailPrefix &&
          popupBand == other.popupBand &&
          popupDetailSuffix == other.popupDetailSuffix &&
          highlight == other.highlight &&
          glyph == other.glyph);

  @override
  int get hashCode => Object.hash(id, latitude, longitude, label, kind, color, strokeColor, sizeFactor, popupTitle,
      popupDetailPrefix, popupBand, popupDetailSuffix, highlight, glyph);
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
  int get hashCode => Object.hash(
      id, color, highlight, points.length, points.isEmpty ? null : points.first, points.isEmpty ? null : points.last);
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
          'popupTitle': m.popupTitle,
          'popupDetailPrefix': m.popupDetailPrefix,
          'popupBand': m.popupBand,
          'popupDetailSuffix': m.popupDetailSuffix,
          'highlight': m.highlight,
          // Base64 rather than a byte list: both bridges (the webview's
          // string-only channel and the web view's JS interop) carry a
          // string unchanged, while a 9KB list would be walked element by
          // element on the way across.
          if (m.glyph?.image case final image?)
            'image': {
              'id': image.id,
              'rgba': image.base64Rgba,
              'width': image.width,
              'height': image.height,
              'pixelRatio': image.pixelRatio,
            },
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
            'properties': {'color': mapColorToHex(line.color), 'highlight': line.highlight},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in line.points) [p.longitude, p.latitude],
              ],
            },
          },
      ],
    };

/// One filled outline on the map — a SOTA activation zone, and whatever other
/// footprints a program publishes (see the `geojsonUrlForRef` hook).
///
/// The rings are already in drawing order: the first is the outer boundary and
/// the rest are holes, which is GeoJSON's own convention and what both
/// backends want. A GeoJSON polygon repeats its first point as its last; that
/// closing duplicate is kept, since MapLibre requires it and flutter_map is
/// indifferent.
@immutable
class MapShapeData {
  /// `<ref type>/<reference>/<polygon index>` — one source document can carry
  /// several polygons, and each becomes its own shape.
  final String id;
  final List<List<GridLocation>> rings;
  final Color color;

  const MapShapeData({required this.id, required this.rings, required this.color});

  /// Compared by id and color alone. Shapes are content-addressed — a given id
  /// is always the same fetched document, parsed the same way — so a deep
  /// compare of thousands of points on every `didUpdateWidget` would only ever
  /// confirm what the id already says.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MapShapeData && id == other.id && color == other.color);

  @override
  int get hashCode => Object.hash(id, color);
}

/// The polygons of a GeoJSON document, or an empty list for anything that
/// isn't one.
///
/// Deliberately total: this parses a file fetched from a program's own server,
/// which nothing in the app controls, so every malformed shape is skipped and
/// the map draws what it could read. A throw here would take out the map for a
/// pane the operator opened to look at something else.
///
/// Only `Polygon` and `MultiPolygon` are read — a boundary is an area, and a
/// stray point or line in the same document is not part of one.
List<MapShapeData> mapShapesFromGeojson(Object? document, {required String idPrefix, required Color color}) {
  final shapes = <MapShapeData>[];

  void addPolygon(Object? coordinates) {
    if (coordinates is! List) return;
    final rings = <List<GridLocation>>[];
    for (final ring in coordinates) {
      if (ring is! List) continue;
      final points = <GridLocation>[];
      for (final point in ring) {
        // GeoJSON is [longitude, latitude], and may carry a third elevation
        // element this ignores.
        if (point is! List || point.length < 2) continue;
        final lon = point[0], lat = point[1];
        if (lon is! num || lat is! num) continue;
        points.add(GridLocation(lat.toDouble(), lon.toDouble()));
      }
      // Two points describe no area — a degenerate ring would paint nothing
      // and, as an outer ring, would take a real shape's holes with it.
      if (points.length >= 3) rings.add(points);
    }
    if (rings.isEmpty) return;
    shapes.add(MapShapeData(id: '$idPrefix/${shapes.length}', rings: rings, color: color));
  }

  void addGeometry(Object? geometry) {
    if (geometry is! Map) return;
    switch (geometry['type']) {
      case 'Polygon':
        addPolygon(geometry['coordinates']);
      case 'MultiPolygon':
        final polygons = geometry['coordinates'];
        if (polygons is List) polygons.forEach(addPolygon);
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

/// Fill and outline share one hex color and one alpha pair, the same way
/// [mapLinesPayload] splits color from opacity — the GL layers take a flat
/// paint color with opacity applied separately.
Map<String, dynamic> mapShapesPayload(List<MapShapeData> shapes) => {
      'features': [
        for (final shape in shapes)
          {
            'type': 'Feature',
            'properties': {'color': mapColorToHex(shape.color)},
            'geometry': {
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
