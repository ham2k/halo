// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where the Operation Postcard's map looks: the Map tab's own framing fitted
// to the postcard's shape, kept inside a flat world and around the markers
// and the popup the tab showed. Flat Web Mercator arithmetic, no widgets.

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../map/map_zoom_controller.dart';

/// A marker's place on the map, for [postcardCamera] to keep in the picture.
typedef PostcardMarker = ({double latitude, double longitude});

/// The Map tab's open popup, which the postcard draws over [at] itself — the
/// GL map's is a page element over its canvas, and no snapshot of the canvas
/// has it — and keeps in the picture like the markers. [size] is the card and
/// its tip together.
typedef PostcardCallout = ({PostcardMarker at, Size size});

/// Room around a marker kept clear of the image's edges and the header: a
/// dot's radius at its largest, and its ring.
const postcardMarkerMargin = 12.0;

/// Where a callout's tip ends above its marker: the GL map's popup, at the
/// offset the map script opens it with.
const postcardCalloutGap = 12.0;

/// The postcard's camera for a [frame], from what the Map tab showed
/// ([view]): all of the tab's map fits in the image, the side that runs out
/// first setting the zoom, around the tab's own center. The header is laid
/// over it like everything else, and takes no room of its own. The map still
/// covers the whole image; the other way, it shows more around what was
/// framed. A square is cut from the tab instead: the tab's shorter side spans
/// its width, and the longer one is cropped.
///
/// A flat map ([withinWorld]) is kept inside the Web Mercator world, drawn in
/// [tileSize]-pixel tiles: where the image would reach past a pole the camera
/// slides until its edge is the world's, rather than leave a blank strip, and
/// a world shorter than the image is zoomed until it is not. And every one of
/// [markers] the tab showed stays in the picture — with the [callout] over
/// one of them — clear of the edges and of the top [header] pixels the band
/// covers: the camera zooms out no further, and pans no further, than that
/// takes. A whole-world portrait can be too narrow for them all, the world
/// being only so tall; it is then centered on them. A globe keeps the fit
/// alone — this is flat-map arithmetic.
///
/// A postcard is north-up and flat whatever the tab's bearing and pitch: the
/// callout and the markers are placed on it by flat, unturned arithmetic.
MapCameraPosition postcardCamera(
  MapCameraView view,
  Size frame, {
  required double tileSize,
  bool withinWorld = true,
  List<PostcardMarker> markers = const [],
  PostcardCallout? callout,
  double header = 0,
}) {
  final viewport = view.viewport;
  final scale = frame.width == frame.height
      ? frame.width / math.min(viewport.width, viewport.height)
      : math.min(frame.width / viewport.width, frame.height / viewport.height);
  if (!scale.isFinite || scale <= 0) return MapCameraPosition(latitude: view.camera.latitude, longitude: view.camera.longitude, zoom: view.camera.zoom);
  final fitted = MapCameraPosition(latitude: view.camera.latitude, longitude: view.camera.longitude, zoom: view.camera.zoom + math.log(scale) / math.ln2);
  if (!withinWorld) return fitted;

  // Everything to keep in the picture: a point in world units (see
  // [_tabPoint]) and the pixels it needs around that point, which no zoom
  // changes.
  final cx = (view.camera.longitude + 180) / 360;
  final cy = MapCameraPosition.mercatorY(view.camera.latitude);
  ({double x, double y})? shown(PostcardMarker marker) => _tabPoint(view, marker, tileSize: tileSize);

  const m = postcardMarkerMargin;
  final keepers = <({double x, double y, double left, double right, double up, double down})>[
    for (final marker in markers)
      if (shown(marker) case final p?) (x: p.x, y: p.y, left: m, right: m, up: m, down: m),
    if (callout != null)
      if (shown(callout.at) case final p?)
        (x: p.x, y: p.y, left: callout.size.width / 2, right: callout.size.width / 2, up: postcardCalloutGap + callout.size.height, down: m),
  ];

  // The range of centers, in pixels of a world [world] wide, that keeps every
  // keeper in the clear part of the image — empty (lo > hi) where none can.
  ({double lo, double hi}) xRange(double world) => (
    lo: keepers.map((k) => k.x * world + k.right).fold(double.negativeInfinity, math.max) - frame.width / 2,
    hi: keepers.map((k) => k.x * world - k.left).fold(double.infinity, math.min) + frame.width / 2,
  );
  ({double lo, double hi}) yRange(double world) => (
    lo: keepers.map((k) => k.y * world + k.down).fold(double.negativeInfinity, math.max) - frame.height / 2,
    hi: keepers.map((k) => k.y * world - k.up).fold(double.infinity, math.min) + frame.height / 2 - header,
  );
  bool fits(double zoom) {
    final world = tileSize * math.pow(2, zoom);
    final x = xRange(world), y = yRange(world);
    return x.lo <= x.hi && y.lo <= y.hi;
  }

  // A world shorter than the image leaves a blank above or below it whatever
  // the center — and the GL library would zoom in to fill it anyway.
  final floor = math.log(frame.height / tileSize) / math.ln2;
  var zoom = math.max(fitted.zoom, floor);
  if (keepers.isNotEmpty && !fits(zoom) && fits(floor)) {
    // The widest zoom that still fits: the keepers only spread further apart
    // as the map zooms in, so the zooms that fit are all the ones below it.
    var lo = floor, hi = zoom;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    zoom = lo;
  } else if (keepers.isNotEmpty && !fits(zoom)) {
    zoom = floor;
  }
  final world = tileSize * math.pow(2, zoom);

  // The center: the tab's, moved the least that keeps every keeper in the
  // clear part of the image — or on their middle, where no center can hold
  // them all.
  double keep(double center, ({double lo, double hi}) range) => range.lo <= range.hi ? center.clamp(range.lo, range.hi) : (range.lo + range.hi) / 2;
  var x = cx, y = cy;
  if (keepers.isNotEmpty) {
    x = keep(cx * world, xRange(world)) / world;
    y = keep(cy * world, yRange(world)) / world;
  }
  // Inside the world last: a blank strip is never the answer, even for a
  // marker that close to the pole.
  y = y.clamp(frame.height / 2 / world, 1 - frame.height / 2 / world);
  final longitude = x * 360 - 180;
  return MapCameraPosition(
    // The tab's own numbers where nothing moved them, rather than their round
    // trip through the projection.
    latitude: y == cy ? view.camera.latitude : view.camera.atMercatorY(y).latitude,
    longitude: x == cx ? view.camera.longitude : longitude - 360 * ((longitude + 180) / 360).floorToDouble(),
    zoom: zoom,
  );
}

/// Whether the Map tab ([view]) showed any of [marker]'s dot, on a flat map
/// of [tileSize]-pixel tiles.
bool postcardTabShows(MapCameraView view, PostcardMarker marker, {required double tileSize}) => _tabPoint(view, marker, tileSize: tileSize) != null;

/// [marker] in world units — 0..1 across and down the whole Mercator world,
/// x on the copy of the world nearest the tab's center, which is the one the
/// tab drew it on — or null when the tab showed none of its dot. Half a dot at
/// the tab's edge counts: it is a marker the operator saw.
({double x, double y})? _tabPoint(MapCameraView view, PostcardMarker marker, {required double tileSize}) {
  final cx = (view.camera.longitude + 180) / 360;
  final cy = MapCameraPosition.mercatorY(view.camera.latitude);
  final tabWorld = tileSize * math.pow(2, view.camera.zoom);
  final dx = (marker.longitude + 180) / 360 - cx;
  final x = cx + dx - dx.roundToDouble();
  final y = MapCameraPosition.mercatorY(marker.latitude);
  // Where the tab's rotation put it on screen: a bearing names the direction
  // at the top, so the map is turned back by it. Pitch is not reckoned with.
  final turn = -view.camera.bearing * math.pi / 180;
  final east = (x - cx) * tabWorld, south = (y - cy) * tabWorld;
  final across = east * math.cos(turn) - south * math.sin(turn);
  final down = east * math.sin(turn) + south * math.cos(turn);
  if (across.abs() > view.viewport.width / 2 + postcardMarkerMargin || down.abs() > view.viewport.height / 2 + postcardMarkerMargin) return null;
  return (x: x, y: y);
}

/// Where [marker] shows in a [frame] held at [camera] on a flat map of
/// [tileSize]-pixel tiles, in the frame's logical pixels from its top left —
/// on the copy of the world nearest the center.
Offset postcardPoint(MapCameraPosition camera, PostcardMarker marker, Size frame, {required double tileSize}) {
  final world = tileSize * math.pow(2, camera.zoom);
  final dx = (marker.longitude - camera.longitude) / 360;
  return Offset(
    (dx - dx.roundToDouble()) * world + frame.width / 2,
    (MapCameraPosition.mercatorY(marker.latitude) - MapCameraPosition.mercatorY(camera.latitude)) * world + frame.height / 2,
  );
}
