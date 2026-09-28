// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bridges the Map tab's zoom buttons (map_panel.dart) to whichever backend
// is currently live. Each backend that supports zoom-by-button wires its
// own zoomIn/zoomOut into a controller instance passed down at construction,
// so the buttons don't need a backend-specific controller type — the facade
// swaps backends (OSM vs the MapLibre webview/web view) without the button
// widget caring which one is underneath.
//
// It also carries the two things the Operation Postcard asks of a map: where
// the Map tab is looking ([camera]), and a picture of a framed map
// ([snapshot]).

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

class MapZoomController {
  void Function()? onZoomIn;
  void Function()? onZoomOut;

  /// Set by every backend that can be pointed somewhere — see [moveTo].
  void Function(double latitude, double longitude, double zoom)? onMoveTo;

  /// Set by every backend — see [camera].
  Future<MapCameraView?> Function()? onCamera;

  /// Set by the GL backends only: the OSM backend is Flutter all the way
  /// down, so a picture of it is a RepaintBoundary's to take — once
  /// [onSettled] says there is one to take.
  Future<Uint8List> Function(double pixelRatio)? onSnapshot;

  /// Set by the OSM backend for a framed map: completes once every tile it
  /// asked for has arrived or failed — or throws [MapSnapshotException] when
  /// that takes too long.
  Future<void> Function()? onSettled;

  void zoomIn() => onZoomIn?.call();
  void zoomOut() => onZoomOut?.call();

  /// Where the live map is looking and how much of it shows, or null while
  /// no backend is live — or while a GL backend's page has not yet answered
  /// the first time.
  Future<MapCameraView?> camera() async => onCamera?.call();

  /// A PNG of a framed map (see [MapFrame]) at [pixelRatio] physical pixels
  /// per logical one. Null when the live backend takes no snapshots; throws
  /// when it takes one and fails.
  Future<Uint8List>? snapshot(double pixelRatio) => onSnapshot?.call(pixelRatio);

  /// Centers the map on one point at [zoom], leaving whatever it is showing
  /// in place — this is a camera move, not a data change, so it never
  /// competes with a backend's own fit-to-markers.
  ///
  /// Silently does nothing when no backend is live: the Activities pane
  /// builds its controller with the pane and hands it to whichever backend
  /// the platform picks, so the rows above the map can call this during the
  /// frame before that backend's State has wired itself up.
  void moveTo(double latitude, double longitude, {double zoom = closeUpZoom}) => onMoveTo?.call(latitude, longitude, zoom);

  /// Close enough to read one reference's surroundings — a summit's
  /// activation zone frames at roughly half the pane at this level, where
  /// the marker-fit's own cap (zoom 11) leaves it a speck.
  static const closeUpZoom = 14.0;

  /// The closest a map's fit to its markers comes, on the GL scale: a lone
  /// marker, or a tight cluster, would otherwise fit at street level.
  static const fitMaxZoom = 10.5;

  /// A flutter_map zoom on the GL backends' scale: its 256-pixel tiles show
  /// the same view one level higher than GL's 512-pixel ones.
  static double glZoomOf({required double osmZoom}) => osmZoom - 1;
}

/// The box a map shows, in degrees, longitudes wrapped into ±180 — so [west]
/// past [east] is a view across the antimeridian. Structurally the record
/// `suggestActivities` takes, so the two need no conversion.
typedef MapViewBounds = ({double south, double west, double north, double east});

/// Where a map came to rest: its [camera] (zoom on the GL scale, see
/// [MapZoomController.glZoomOf]) and the [bounds] it shows.
typedef MapCameraSettled = ({MapCameraPosition camera, MapViewBounds bounds});

/// [south]..[north] and [west]..[east] as a [MapViewBounds]: longitudes
/// wrapped into ±180, and a span of the whole world as exactly that.
MapViewBounds mapViewBounds({required double south, required double west, required double north, required double east}) {
  if (east - west >= 360) return (south: south, west: -180.0, north: north, east: 180.0);
  double wrap(double lon) => ((lon + 180) % 360 + 360) % 360 - 180;
  return (south: south, west: wrap(west), north: north, east: wrap(east));
}

/// Where a map is looking. Zoom is the backend's own: a GL zoom and a
/// flutter_map zoom for the same view differ by one (512- against 256-pixel
/// tiles), which is harmless as long as a position is only ever handed back to
/// the kind of backend that produced it — the only thing [MapFrame] does.
class MapCameraPosition {
  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;
  final double pitch;

  const MapCameraPosition({required this.latitude, required this.longitude, required this.zoom, this.bearing = 0, this.pitch = 0});

  /// From the GL script's `camera()`; null for anything else.
  static MapCameraPosition? fromJson(Object? json) {
    if (json is! Map) return null;
    final latitude = json['latitude'], longitude = json['longitude'], zoom = json['zoom'];
    if (latitude is! num || longitude is! num || zoom is! num) return null;
    final bearing = json['bearing'], pitch = json['pitch'];
    return MapCameraPosition(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      zoom: zoom.toDouble(),
      bearing: bearing is num ? bearing.toDouble() : 0,
      pitch: pitch is num ? pitch.toDouble() : 0,
    );
  }

  Map<String, Object> toJson() => {'latitude': latitude, 'longitude': longitude, 'zoom': zoom, 'bearing': bearing, 'pitch': pitch};

  /// This camera at [zoom] instead.
  MapCameraPosition atZoom(double zoom) => MapCameraPosition(latitude: latitude, longitude: longitude, zoom: zoom, bearing: bearing, pitch: pitch);

  /// This camera with its center at [y] down a Web Mercator world (see
  /// [mercatorY]).
  MapCameraPosition atMercatorY(double y) =>
      MapCameraPosition(latitude: math.atan(_sinh(math.pi * (1 - 2 * y))) * 180 / math.pi, longitude: longitude, zoom: zoom, bearing: bearing, pitch: pitch);

  /// How far down a Web Mercator world [latitude] falls: 0 at its top edge
  /// (85.0511°N), 1 at its bottom.
  static double mercatorY(double latitude) {
    final sinLat = math.sin(latitude * math.pi / 180);
    return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
}

/// A picture of the map that could not be had: the map never came up, or
/// never finished drawing — offline, a tile server that stopped answering.
/// An outcome for the operator to be told about, not a bug to report.
class MapSnapshotException implements Exception {
  final String message;
  const MapSnapshotException(this.message);

  @override
  String toString() => message;
}

/// How the GL map script's snapshot says it gave up waiting for the map to
/// settle, and that the map was taken down while it waited — the two
/// rejections that are a [MapSnapshotException] rather than a fault (see
/// [isMapSnapshotOutcome]).
const mapSnapshotTimeoutMessage = 'the map did not settle';
const mapSnapshotRemovedMessage = 'the map was taken down';

/// Whether a GL snapshot's rejection, as [message], is an outcome rather than
/// a fault.
bool isMapSnapshotOutcome(String message) => message.contains(mapSnapshotTimeoutMessage) || message.contains(mapSnapshotRemovedMessage);

/// How long a snapshot waits, all told, for a map to come up and settle:
/// long enough for a slow link to deliver a screen of tiles at twice the
/// pixels.
const mapSnapshotTimeout = Duration(milliseconds: mapSnapshotTimeoutMs);
const mapSnapshotTimeoutMs = 30000;

/// How long a camera read waits for a map still coming up — a tap on the
/// Map tab's camera button before its map has loaded — before giving up on
/// it.
const mapCameraWait = Duration(seconds: 10);

/// What a live map shows: where it is looking, and the size of the window it
/// looks through, in logical pixels — together, the stretch of the world an
/// operator has framed — and the marker whose popup is open over it, if any.
typedef MapCameraView = ({MapCameraPosition camera, Size viewport, String? popup});

/// From the GL script's `camera()`; null for anything else.
MapCameraView? mapCameraViewFromJson(Object? json) {
  final camera = MapCameraPosition.fromJson(json);
  if (camera == null || json is! Map) return null;
  final width = json['width'], height = json['height'], popup = json['popup'];
  if (width is! num || height is! num) return null;
  return (camera: camera, viewport: Size(width.toDouble(), height.toDouble()), popup: popup is String ? popup : null);
}

/// A map made to be a picture rather than explored: laid out at [width] ×
/// [height] logical pixels whatever space it is given, held at [camera], and
/// scaled to fit — so a preview of it and a snapshot of it differ only in
/// resolution. See `frame` in map_gl_script.dart.
class MapFrame {
  final double width;
  final double height;
  final MapCameraPosition camera;

  const MapFrame({required this.width, required this.height, required this.camera});
}

/// The bytes of a `data:` URL, which is what a canvas snapshot crosses the
/// bridge as.
Uint8List decodeDataUrl(String url) {
  final comma = url.indexOf(',');
  if (!url.startsWith('data:') || comma < 0) throw FormatException('not a data URL', url.length > 40 ? url.substring(0, 40) : url);
  return base64Decode(url.substring(comma + 1));
}
