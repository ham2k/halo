// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Points the map at the QSO in the logging panel. Picking a logged QSO, or
// putting it down, is one deliberate act, and the map answers it at once:
// the pick from where it was logged, with its line back to the operation's
// QTH, and putting it down with the whole log. A call being typed — new, or
// into the QSO already picked — is followed once its location has held
// still for [MapHighlightCamera.composingDelay], so each keystroke's guess
// does not swing the map around. A pane coming into sight frames what is
// current at once.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;

import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

class MapHighlightCamera {
  final MapZoomController controller;

  MapHighlightCamera(this.controller);

  static const composingDelay = Duration(seconds: 2);

  bool _seen = false;
  String? _picked;
  List<GridLocation>? _target;
  Timer? _timer;

  /// Takes each visible build's pick ([picked], the uuid of the QSO being
  /// edited, framed by [pickedPoints] — where it was logged) and the live
  /// call-info's [highlightFitPoints] ([typed]). Null points frame the whole
  /// log.
  void follow({String? picked, List<GridLocation>? pickedPoints, List<GridLocation>? typed}) {
    final now = !_seen || picked != _picked;
    // A fresh pick frames where it was logged: the live guess may still be
    // the call typed before it, or a lookup on its way. A pane coming back
    // into sight on the same pick takes the live guess: by then it is the
    // pick's, edits included.
    final target = picked != null && picked != _picked ? pickedPoints : typed ?? pickedPoints;
    if (!now && listEquals(target, _target)) return;
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
    final points = _target;
    if (points == null) {
      controller.refit();
    } else {
      controller.fitTo(points);
    }
  }

  void dispose() => _timer?.cancel();
}

/// What framing [highlight] covers: its whole great-circle line, longitudes
/// unwrapped so an arc across the antimeridian is one continuous span — or
/// the marker alone, with no QTH to draw a line to. Null with nothing
/// highlighted.
List<GridLocation>? highlightFitPoints(({List<MapMarkerData> markers, List<MapLineData> lines}) highlight) {
  if (highlight.markers.isEmpty) return null;
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
