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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import '../../services/extensions/extension_ref_results.dart' show RefGeojsonAnswer;
import '../../services/geoshape_service.dart';
import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

/// The zoom, on the GL scale, from which a map fetches reference outlines it
/// was not asked to draw at every zoom — the Map tab's, and the Activities
/// map's unpicked suggestions — fading them in until
/// [refOutlinesOpaqueAtZoom]. Further out a park is a few pixels across, and
/// its outline a fetch for a smudge.
const refOutlinesFromZoom = 7.0;
const refOutlinesOpaqueAtZoom = 8.0;

/// The zoom, on the GL scale, from which the outline credits offer to report
/// a wrong outline: close enough in that the operator can see what is wrong
/// with it.
const outlineIssuesFromZoom = 8.5;

/// A reference as a report about its outline names it: its short label (or
/// bare code) and its name — "POTA US-1234 · Catskill Park".
String outlineRefLabel(Map<String, dynamic> ref) =>
    [ref['shortLabel'] ?? ref['ref'], ref['name']].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

/// One pane's parsed outlines, and what it is still waiting on.
///
/// [onChanged] fires after the state has already changed, so a widget's
/// handler is an ordinary `setState((){})` — and must check `mounted` itself,
/// since an answer can land after the pane is gone.
class RefShapeLoader {
  RefShapeLoader({required this.geoshapes, required this.onChanged, this.keptOnly = false});

  /// Null in a harness with no database to cache in. Every lookup then answers
  /// "nothing", which is also what an operator sees for a program that
  /// publishes no shapes.
  final GeoshapeService? geoshapes;
  final VoidCallback onChanged;

  /// Draws only what the device already holds, never starting a download —
  /// for an outline shown in place of one that could not be read, where
  /// fetching it would be the very download it stands in for.
  final bool keptOnly;

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
    // Queued rather than asked for now: a pane asks for every reference on
    // the operation in one build, and their sources are then resolved
    // together, in one crossing, once the build is done.
    if (_queued.isEmpty) scheduleMicrotask(() => unawaited(_resolveQueued(geoshapes)));
    _queued.add((ref: ref, key: key, id: id, color: color));
    return null;
  }

  final List<({Map<String, dynamic> ref, String key, String id, Color color})> _queued = [];

  Future<void> _resolveQueued(GeoshapeService geoshapes) async {
    final batch = List.of(_queued);
    _queued.clear();
    final List<RefGeojsonAnswer> sources;
    try {
      sources = await geoshapes.sourcesForRefs([for (final item in batch) item.ref]);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'map:geoshape');
      // Paused like any lookup that could not finish: without it a failure
      // that repeats would ride every rebuild, and report on each one.
      final retryAt = nowMillis() + retryAfterFailure.inMilliseconds;
      for (final item in batch) {
        _inFlight.remove(item.key);
        _retryAfterMillis[item.key] = retryAt;
      }
      return;
    }
    for (final (i, item) in batch.indexed) {
      unawaited(_land(geoshapes, sources[i], ref: item.ref, key: item.key, id: item.id, color: item.color));
    }
  }

  Future<void> _land(
    GeoshapeService geoshapes,
    RefGeojsonAnswer source, {
    required Map<String, dynamic> ref,
    required String key,
    required String id,
    required Color color,
  }) async {
    try {
      final shape = await (keptOnly ? geoshapes.keptShapeFromSource(source) : geoshapes.shapeFromSource(source));
      final geojson = shape.geojson;
      if (geojson != null) {
        _shapes[key] = mapShapesFromGeojson(
          jsonDecode(geojson),
          idPrefix: id,
          color: color,
          sourceName: source.source?.sourceName,
          sourceUrl: source.source?.url,
          refLabel: outlineRefLabel(ref),
        );
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
      // Paused like a lookup that could not finish: without it the next
      // rebuild asks again — the body re-downloaded, the report re-sent.
      _retryAfterMillis[key] = nowMillis() + retryAfterFailure.inMilliseconds;
    } finally {
      // In a finally, not after the await: a lookup that throws would
      // otherwise leave its key claimed for the life of the pane, and that
      // reference would silently never draw again.
      _inFlight.remove(key);
    }
  }
}

/// The marker id of the reference a shape from [refShapes] outlines — the
/// shape's own id less the index its document gave it. The last separator
/// only: a SOTA reference carries a slash of its own.
String markerIdOfShape(MapShapeData shape) => shape.id.substring(0, shape.id.lastIndexOf('/'));

/// How far from its point [ref] may be activated, in meters, or null for a
/// reference that declares no radius.
///
/// `activationRadiusInMeters` wins over `activationRadiusInFeet` when a
/// reference carries both. Read, not cast — the values come from an
/// extension, and stored refs keep whatever it answered — so anything but a
/// positive, finite number counts as none.
double? activationRadiusMeters(Map<String, dynamic> ref) {
  double? positive(Object? value) => value is num && value.isFinite && value > 0 ? value.toDouble() : null;
  if (positive(ref['activationRadiusInMeters']) case final meters?) return meters;
  if (positive(ref['activationRadiusInFeet']) case final feet?) return feet * 0.3048;
  return null;
}

/// The circle [ref]'s activation radius draws around its coordinate, or null
/// for a reference with no radius or no `lat`/`lon`.
///
/// Never around a `grid`: a 6-character square is several kilometres
/// across, so its centre can sit further from the reference than the whole
/// radius, and a circle drawn there would put the activator in range where
/// they are not (docs/design/locations.md).
///
/// The radius and the centre are in the id: a map compares shapes by id and
/// skips redrawing an equal list, so a reference that moved, or whose radius
/// changed, would otherwise keep its circle where it was.
MapShapeData? activationRadiusShape(Map<String, dynamic> ref, {required String id, required Color color}) {
  final meters = activationRadiusMeters(ref);
  final center = locationFromLatLon(ref['lat'], ref['lon']);
  if (meters == null || center == null) return null;
  return MapShapeData(
    id: '$id/radius-$meters@${center.latitude},${center.longitude}',
    rings: [circleOnEarth(center, meters / 1000)],
    color: color,
    isActivationRadius: true,
    refLabel: outlineRefLabel(ref),
  );
}

/// The outlines and activation radii for every reference in [refs], in each
/// one's own activity color — the same pair its row and its marker use, so a
/// dot, a row and an outline all read as one object. A reference with
/// neither contributes nothing; one with both draws both.
///
/// [markerIdFor] names the shape after whatever the calling pane calls that
/// reference's marker.
List<MapShapeData> refShapes(
  Iterable<Map<String, dynamic>> refs, {
  required RefShapeLoader loader,
  required List<Map<String, dynamic>> controls,
  required Color fallbackColor,
  required String Function(Map<String, dynamic> ref) markerIdFor,
}) {
  final shapes = <MapShapeData>[];
  for (final ref in refs) {
    final id = markerIdFor(ref);
    final color = colorForRefType(controls, ref['type'] as String?, code: refCodeOf(ref)) ?? fallbackColor;
    shapes.addAll(loader.shapeFor(ref, id: id, color: color) ?? const []);
    if (activationRadiusShape(ref, id: id, color: color) case final circle?) shapes.add(circle);
  }
  return shapes;
}

/// The line under a map showing reference outlines: they are no survey, and
/// here is who drew them. Nothing at all while [shapes] is empty.
///
/// Bottom-left, and at most 60% of the width it is given, so the backend's
/// own credit in the bottom-right corner is never covered — flutter_map's
/// strip and MapLibre's control both sit there.
class MapOutlinesNotice extends StatelessWidget {
  const MapOutlinesNotice({super.key, required this.shapes, this.camera, this.onReportIssue});

  final List<MapShapeData> shapes;

  /// The map's last camera report — what [outlineIssuesFromZoom] is checked
  /// against. Without one, no issues link.
  final ValueListenable<MapCameraSettled?>? camera;

  /// Opens the outline-issue dialog (outline_issue_dialog.dart), from an
  /// "Issues?" link after the credits. Offered only close in, and only where a
  /// report can leave the device ([ErrorReportingService.reportingEnabled]):
  /// a form whose Send can never send is worse than no form.
  final VoidCallback? onReportIssue;

  @override
  Widget build(BuildContext context) {
    // An activation radius is the program's own rule drawn around its own
    // coordinate: nobody to credit, and nothing for a report to correct.
    final outlines = shapes.where((shape) => !shape.isActivationRadius);
    if (outlines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sources = {for (final shape in outlines) ?shape.sourceName}.toList()..sort();
    final style = theme.textTheme.bodySmall;
    final camera = this.camera;
    final onReportIssue = ErrorReportingService.reportingEnabled ? this.onReportIssue : null;
    // One line of text, the link inline on the credits' baseline — a row of
    // two widgets centres them instead, and the smaller bold link sits off it.
    Widget credits(bool withLink) => Text.rich(
      TextSpan(
        children: [
          if (sources.isNotEmpty) TextSpan(text: context.t.map.outlinesSource(sources: sources.join(', '))),
          if (withLink) ...[
            if (sources.isNotEmpty) const WidgetSpan(child: SizedBox(width: Space.lg)),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: onReportIssue,
                  child: Text(
                    context.t.map.outlineIssue.link,
                    // The span it sits in is scaled already; scaling this
                    // too would size it by the text scale squared.
                    textScaler: TextScaler.noScaling,
                    style: style?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      style: style,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.bottomLeft,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
          // On the web the map under it would otherwise take the link's
          // clicks (user-interface.md, "Over a map, on the web").
          child: PlatformViewShield(
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t.map.outlinesDisclaimer, style: style?.copyWith(fontWeight: FontWeight.bold)),
                    if (onReportIssue == null || camera == null)
                      if (sources.isNotEmpty) credits(false) else const SizedBox.shrink()
                    else
                      ValueListenableBuilder(
                        valueListenable: camera,
                        builder: (context, settled, _) {
                          final close = (settled?.camera.zoom ?? 0) >= outlineIssuesFromZoom;
                          return sources.isEmpty && !close ? const SizedBox.shrink() : credits(close);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
