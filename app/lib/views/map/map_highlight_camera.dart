// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Points the map at the QSO in the logging panel. Picking a logged QSO, or
// putting it down, is one deliberate act, and the map answers it at once:
// the pick from where it was logged, with its line back to the operation's
// QTH, and putting it down with the map's framing. How it points is the
// pane's ([MapHighlightCamera.onFocus], [MapHighlightCamera.onFrame]); when
// is this class's. A call being typed — new, or
// into the QSO already picked — is followed once its location has held
// still for [MapHighlightCamera.composingDelay], so each keystroke's guess
// does not swing the map around. A pane coming into sight frames what is
// current at once.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;

import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

/// Where a current QSO is: its great-circle [line] home, or the marker alone
/// with no QTH to draw one to, and the QSO's own [location].
typedef MapFocus = ({List<GridLocation> line, GridLocation location});

class MapHighlightCamera {
  final MapZoomController controller;

  /// Points the map at a current QSO; framing its line by default.
  final void Function(MapFocus focus)? onFocus;

  /// Points the map at what it shows with no current QSO; the whole log by
  /// default.
  final void Function()? onFrame;

  MapHighlightCamera(this.controller, {this.onFocus, this.onFrame});

  static const composingDelay = Duration(seconds: 2);

  bool _seen = false;
  String? _picked;
  MapFocus? _target;
  Timer? _timer;

  /// Takes each visible build's pick ([picked], the uuid of the QSO being
  /// edited, at [pickedFocus] — where it was logged) and the live
  /// call-info's [highlightFocus] ([typed]). No focus is the map's framing.
  void follow({String? picked, MapFocus? pickedFocus, MapFocus? typed}) {
    final now = !_seen || picked != _picked;
    // A fresh pick frames where it was logged: the live guess may still be
    // the call typed before it, or a lookup on its way. A pane coming back
    // into sight on the same pick takes the live guess: by then it is the
    // pick's, edits included.
    final target = picked != null && picked != _picked ? pickedFocus : typed ?? pickedFocus;
    if (!now && target?.location == _target?.location && listEquals(target?.line, _target?.line)) return;
    _seen = true;
    _picked = picked;
    _target = target;
    _timer?.cancel();
    // Out of the build either way: the backend's handlers call into its map.
    _timer = Timer(now ? Duration.zero : composingDelay, _apply);
  }

  /// The pane went out of sight. A pending move is dropped — a hidden map
  /// may have no size to fit by — and the next [follow] frames what is
  /// current at once.
  void hidden() {
    _timer?.cancel();
    _seen = false;
  }

  void _apply() {
    final focus = _target;
    if (focus == null) {
      (onFrame ?? controller.refit)();
    } else if (onFocus case final onFocus?) {
      onFocus(focus);
    } else {
      controller.fitTo(focus.line);
    }
  }

  void dispose() => _timer?.cancel();
}

/// Where [highlight] is: its whole great-circle line, longitudes unwrapped so
/// an arc across the antimeridian is one continuous span — or the marker
/// alone, with no QTH to draw a line to — and the marker's own location. Null
/// with nothing highlighted.
MapFocus? highlightFocus(({List<MapMarkerData> markers, List<MapLineData> lines}) highlight) {
  if (highlight.markers.isEmpty) return null;
  final marker = highlight.markers.first;
  return (line: _linePoints(highlight), location: GridLocation(marker.latitude, marker.longitude));
}

List<GridLocation> _linePoints(({List<MapMarkerData> markers, List<MapLineData> lines}) highlight) {
  if (highlight.lines.isEmpty) return [for (final m in highlight.markers) GridLocation(m.latitude, m.longitude)];
  final points = <GridLocation>[];
  double? previous;
  for (final line in highlight.lines) {
    for (final p in line.points) {
      var longitude = p.longitude;
      if (previous != null) {
        while (longitude - previous > 180) {
          longitude -= 360;
        }
        while (longitude - previous < -180) {
          longitude += 360;
        }
      }
      points.add(GridLocation(p.latitude, longitude));
      previous = longitude;
    }
  }
  return points;
}
