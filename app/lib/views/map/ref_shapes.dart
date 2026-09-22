// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rules for putting a reference's outline on a map, shared by the two
// panes that draw one — the Activities pane's results map and the Map tab.
// Both ask the same question about the same operation, and a summit whose
// activation zone showed in one pane and not the other would read as a bug in
// whichever the operator looked at second.
//
// The fetching and the on-device cache live a layer down, in GeoshapeService;
// this is only the per-pane memory of what has already been parsed, and the
// backoff that keeps a failed lookup from riding the rebuild rate.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import '../../services/geoshape_service.dart';
import 'map_marker_data.dart';

/// One pane's parsed outlines, and what it is still waiting on.
///
/// [onChanged] fires after the state has already changed, so a widget's
/// handler is an ordinary `setState((){})` — and must check `mounted` itself,
/// since an answer can land after the pane is gone.
class RefShapeLoader {
  RefShapeLoader({required this.geoshapes, required this.onChanged});

  /// Null in a harness with no database to cache in. Every lookup then answers
  /// "nothing", which is also what an operator sees for a program that
  /// publishes no shapes.
  final GeoshapeService? geoshapes;
  final VoidCallback onChanged;

  /// How long a reference that could NOT be looked up is left alone.
  ///
  /// An unresolved answer is deliberately not remembered — an activator whose
  /// signal comes back while the map is open should get their outline — but
  /// without a pause the retry would ride every rebuild, and these panes
  /// rebuild on a marker tap, a search, and each marker glyph that finishes
  /// rasterizing.
  static const retryAfterFailure = Duration(seconds: 30);

  /// Keyed by marker id AND the color it was parsed in: the color is baked
  /// into a [MapShapeData] and never re-read, so a reference whose type
  /// declares none — it falls back to the theme's own primary — would keep its
  /// light-mode outline through a switch to dark while its marker recolored.
  /// [MapShapeData]'s equality folds the color in too, so nothing downstream
  /// would notice the mismatch either.
  final Map<String, List<MapShapeData>> _shapes = {};
  final Set<String> _inFlight = {};
  final Map<String, int> _retryAfterMillis = {};

  /// The outline for [ref] if it has been fetched, otherwise null with a fetch
  /// started — the [onChanged] that lands the polygons brings them onto the
  /// map.
  ///
  /// [id] identifies the reference on the map that owns it (the marker id, so
  /// a shape and its dot can be traced to each other); [color] is the one the
  /// reference's own marker uses, so an outline and its dot read as one
  /// object.
  List<MapShapeData>? shapeFor(Map<String, dynamic> ref, {required String id, required Color color}) {
    final key = '$id/${color.toARGB32()}';
    final ready = _shapes[key];
    if (ready != null) return ready;
    final geoshapes = this.geoshapes;
    if (geoshapes == null) return null;
    final retryAt = _retryAfterMillis[key];
    if (retryAt != null && nowMillis() < retryAt) return null;
    if (!_inFlight.add(key)) return null;
    unawaited(() async {
      try {
        final shape = await geoshapes.shapeForRef(ref);
        final geojson = shape.geojson;
        if (geojson != null) {
          _shapes[key] = mapShapesFromGeojson(jsonDecode(geojson), idPrefix: id, color: color);
        } else if (shape.resolved) {
          // The program publishes none — remember that, and stop asking.
          _shapes[key] = const [];
        } else {
          // This device could not find out (offline, or a server having a bad
          // day). Nothing is remembered, so it asks again — after a pause.
          _retryAfterMillis[key] = nowMillis() + retryAfterFailure.inMilliseconds;
        }
        onChanged();
      } catch (e, stack) {
        // A shape that can't be read is not worth a notice over a map the
        // operator opened to look at something else — but it IS a program's
        // document the app failed to parse, which nothing else would say.
        ErrorReportingService.report(e, stack, context: 'map:geoshape');
      } finally {
        // In a finally, not after the await: a lookup that throws would
        // otherwise leave its key claimed for the life of the pane, and that
        // reference would silently never draw again.
        _inFlight.remove(key);
      }
    }());
    return null;
  }
}

/// The outlines for every reference in [refs], in each one's own activity
/// color — the same pair its row and its marker use, so a dot, a row and an
/// outline all read as one object. A reference with no shape contributes
/// nothing.
///
/// [markerIdFor] names the shape after whatever the calling pane calls that
/// reference's marker.
List<MapShapeData> refShapes(
  Iterable<Map<String, dynamic>> refs, {
  required RefShapeLoader loader,
  required List<Map<String, dynamic>> controls,
  required Color fallbackColor,
  required String Function(Map<String, dynamic> ref) markerIdFor,
}) => [
  for (final ref in refs)
    ...?loader.shapeFor(
      ref,
      id: markerIdFor(ref),
      color: colorForRefType(controls, ref['type'] as String?, code: refCodeOf(ref)) ?? fallbackColor,
    ),
];
