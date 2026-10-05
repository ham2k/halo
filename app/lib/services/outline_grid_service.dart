// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA park outlines as services.ham2k.net bundles them: every outlined park
// touching a Maidenhead cell, simplified and clipped to that cell, in one
// document per cell. Two things read them.
//
// Nearby suggestions. A park is a single point to the POTA extension, and a
// long trail's point can sit a state away from where it passes the operator
// — the Appalachian Trail's is nowhere near Bear Mountain, though the trail
// runs through the park. The bundles answer "whose outline is near here",
// which a point cannot.
//
// The results map's dashed outlines. One cached request per cell in view,
// instead of one whole outline per suggested park: the Appalachian Trail's
// whole outline runs to 14.8 MB, its pieces in a cell to a few kilobytes.
//
// Deliberately a POTA special case in the app rather than an extension hook:
// the bundles exist for POTA alone. The fetching and caching are
// GeoshapeService's, so a bundle is kept on the device like any outline and
// still answers offline once fetched.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import '../tools/activity_suggestions.dart';
import '../views/map/map_marker_data.dart';
import 'extensions/extension_service.dart';
import 'geoshape_service.dart';

/// How large a cell a bundle covers, and how simplified its outlines are:
/// a block is 2×2 grid squares (4°×2°) at 500 m detail, a square 2°×1° at
/// 10 m.
enum OutlineGridScale { block, square }

/// One park's pieces from the bundles read, each clipped to its cell.
///
/// [areas] fill a park: what holds a point, never drawn here — their edges
/// along a cell's sides are seams, not the park's boundary. [lines] are what
/// is drawn: the park's own boundary, and the trails a trail park is made of.
class OutlinePieces {
  OutlinePieces();

  final List<MapShapeData> areas = [];
  final List<MapShapeData> lines = [];

  /// How far [point] is from this park, in kilometres — 0 inside it — or
  /// null when the pieces read hold no geometry at all.
  double? distanceKmFrom(GridLocation point) {
    var nearest = double.infinity;
    for (final area in areas) {
      final (:edgeDistance, :inside, size: _) = measureShape(area, point);
      if (inside) return 0;
      nearest = math.min(nearest, edgeDistance);
    }
    for (final line in lines) {
      nearest = math.min(nearest, measureShape(line, point).edgeDistance);
    }
    return nearest.isFinite ? nearest / 1000 : null;
  }
}

/// What [OutlineGridService.parksNear] found: each park within reach with
/// its distance (null with nothing to measure from), the ones POTA labelled
/// that were not already known, and whether every bundle and label was
/// answered.
typedef OutlineParks = ({Map<String, double?> distances, List<Map<String, dynamic>> found, bool settled});

class OutlineGridService {
  OutlineGridService({required this.geoshapes, required this.extensions});

  final GeoshapeService geoshapes;
  final ExtensionService extensions;

  /// The reference type the bundles' parks are suggested as — POTA's own
  /// activation type, so a park found by its outline and the same park found
  /// by its point are one suggestion.
  static const potaActivationType = 'potaActivation';

  /// How close an outline must come to the operation for its park to join
  /// the nearby suggestions.
  static const nearbyRadiusKm = 5.0;

  /// The furthest [parksNear] reaches: a map view's half-diagonal at about
  /// GL zoom 10.
  static const maxRadiusKm = 25.0;

  static const _bundleBase = 'https://services.ham2k.net/lookups/outlines/pota/grid/';

  /// A bundle changes only when its outlines are re-simplified by hand, so a
  /// week is fresh; a cell with none is asked about again sooner.
  static const _maxAge = Duration(days: 7);
  static const _missMaxAge = Duration(days: 1);

  /// Parsed bundles, most recently read last. A block bundle parses to a few
  /// megabytes of points, so only the cells around one place are kept.
  static const _keptBundles = 12;
  final _parsed = <String, Map<String, OutlinePieces>>{};

  /// The names of the cells at [scale] that cover [south]..[north] ×
  /// [west]..[east], in degrees. A box across the antimeridian is not
  /// covered: there is no POTA park out there to find.
  static List<String> cellsCovering({
    required double south,
    required double west,
    required double north,
    required double east,
    required OutlineGridScale scale,
  }) {
    final (lonStep, latStep) = switch (scale) {
      OutlineGridScale.block => (4.0, 2.0),
      OutlineGridScale.square => (2.0, 1.0),
    };
    if (west > east) return const [];
    final cells = <String>[];
    final firstLat = ((south.clamp(-90.0, 89.999) + 90) / latStep).floor();
    final lastLat = ((north.clamp(-90.0, 89.999) + 90) / latStep).floor();
    final firstLon = ((west.clamp(-180.0, 179.999) + 180) / lonStep).floor();
    final lastLon = ((east.clamp(-180.0, 179.999) + 180) / lonStep).floor();
    for (var lat = firstLat; lat <= lastLat; lat++) {
      for (var lon = firstLon; lon <= lastLon; lon++) {
        cells.add(_cellName(lon * lonStep, lat * latStep, scale));
      }
    }
    return cells;
  }

  /// The cell whose south-west corner is [lon]/[lat] degrees east/north of
  /// the grid's origin (180°W, 90°S): `FN31` for a square, and for a block
  /// its first and last squares, `FN20-31`.
  static String _cellName(double lon, double lat, OutlineGridScale scale) {
    final field = String.fromCharCodes([65 + lon ~/ 20, 65 + lat ~/ 10]);
    final lonDigit = (lon % 20) ~/ 2, latDigit = (lat % 10).toInt();
    return switch (scale) {
      OutlineGridScale.square => '$field$lonDigit$latDigit',
      OutlineGridScale.block => '$field$lonDigit$latDigit-${lonDigit + 1}${latDigit + 1}',
    };
  }

  /// Every park with pieces in [cells], each park's pieces from all of them,
  /// and whether every cell was read — one this device cannot fetch and holds
  /// no copy of contributes nothing, and is worth asking about again.
  Future<({Map<String, OutlinePieces> parks, bool settled})> piecesIn(List<String> cells) async {
    final parks = <String, OutlinePieces>{};
    var settled = true;
    for (final bundle in await Future.wait(cells.map(_bundle))) {
      if (bundle == null) {
        settled = false;
        continue;
      }
      for (final MapEntry(key: ref, value: pieces) in bundle.entries) {
        final park = parks.putIfAbsent(ref, OutlinePieces.new);
        park.areas.addAll(pieces.areas);
        park.lines.addAll(pieces.lines);
      }
    }
    return (parks: parks, settled: settled);
  }

  /// The parks whose outline comes within [radiusKm] of [center] — the
  /// operation's place for the nearby list, a map view's centre and its
  /// half-diagonal for a pan.
  ///
  /// Each is measured from [measureFrom], or not at all without one: a
  /// distance from wherever a map happened to be is no answer (see
  /// `suggestActivities`). Those not in [known] are decorated by POTA itself,
  /// from the park list it keeps on the device, so they read exactly like the
  /// parks POTA suggests; one it does not know, or has retired, is left out,
  /// as its own nearby list leaves it out. [OutlineParks.settled] is false
  /// when a bundle could not be read or POTA could not be asked, so a caller
  /// knows to ask again.
  ///
  /// A reach past [maxRadiusKm] finds nothing: a view that wide holds more
  /// parks than are worth decorating, in more bundles than are worth reading,
  /// and its outlines are a few pixels across anyway.
  Future<OutlineParks> parksNear(GridLocation center, double radiusKm, {GridLocation? measureFrom, Set<String> known = const {}}) async {
    if (radiusKm > maxRadiusKm) return (distances: const <String, double?>{}, found: const <Map<String, dynamic>>[], settled: true);
    final (:parks, :settled) = await piecesIn(_blocksAround(center, radiusKm));
    final distances = <String, double?>{
      for (final MapEntry(key: ref, value: pieces) in parks.entries)
        if (pieces.distanceKmFrom(center) case final distance? when distance <= radiusKm) ref: measureFrom == null ? null : pieces.distanceKmFrom(measureFrom),
    };
    final unknown = [
      for (final ref in distances.keys)
        if (!known.contains(ref)) {'type': potaActivationType, 'ref': ref},
    ];
    if (unknown.isEmpty) return (distances: distances, found: const <Map<String, dynamic>>[], settled: settled);

    final answers = await extensions.refHookAnswers(unknown, RefMethod.decorateRef);
    final found = <Map<String, dynamic>>[];
    var labelled = true;
    for (final answer in answers) {
      // A park with no label is one POTA's list does not hold; a hook that
      // failed or ran out of time said nothing about it either way.
      if (!answer.ok) {
        if (answer.asked && !answer.noHandler) labelled = false;
        continue;
      }
      final park = answer.value;
      if (park is! Map || park['label'] == null || park['retired'] == true) continue;
      final distance = distances[park['ref']];
      found.add({...park.cast<String, dynamic>(), 'distance': ?distance, 'relevance': 1, 'allowsMultiple': true});
    }
    return (distances: distances, found: found, settled: settled && labelled);
  }

  /// [suggestions] with [parks] in them: a POTA suggestion among the parks
  /// takes the nearer of its own distance and its outline's — inside a park
  /// is 0 from it, wherever its point is — and the parks found by outline
  /// alone join, unless already listed or in [elsewhere] (another list the
  /// operator sees). [suggestions] itself when nothing changes, so a caller
  /// can tell by identity.
  static List<Map<String, dynamic>> withParks(List<Map<String, dynamic>> suggestions, OutlineParks parks, {Set<String> elsewhere = const {}}) {
    var changed = false;
    Map<String, dynamic> nearer(Map<String, dynamic> suggestion) {
      final outline = suggestion['type'] == potaActivationType ? parks.distances[suggestion['ref']] : null;
      final point = suggestion['distance'];
      if (outline == null || (point is num && point <= outline)) return suggestion;
      changed = true;
      return {...suggestion, 'distance': outline};
    }

    final updated = [for (final suggestion in suggestions) nearer(suggestion)];
    final listed = {...elsewhere, ...potaRefsIn(updated)};
    for (final park in parks.found) {
      if (listed.add(park['ref'] as String)) {
        updated.add(park);
        changed = true;
      }
    }
    return changed ? rankActivitySuggestions(updated) : suggestions;
  }

  /// Reads the bundles around each POTA park in [refs] that has a place, so
  /// they are on the device before they are needed — an operation is often
  /// set up at home, online, and opened at the park, offline. Each cell at
  /// most once a session; a read that fails here is simply asked again when
  /// the cell is next needed.
  void prefetchFor(Iterable<Map<String, dynamic>> refs) {
    for (final ref in refs) {
      final at = ref['type'] == potaActivationType ? locationFromLatLon(ref['lat'], ref['lon']) : null;
      if (at == null) continue;
      for (final cell in _blocksAround(at, nearbyRadiusKm)) {
        if (_prefetched.add(cell)) unawaited(_bundle(cell));
      }
    }
  }

  final _prefetched = <String>{};

  /// The block cells within [radiusKm] of [center].
  static List<String> _blocksAround(GridLocation center, double radiusKm) {
    final latSpan = radiusKm / 111.32;
    final lonSpan = radiusKm / (111.32 * math.max(math.cos(center.latitude * math.pi / 180), 0.01));
    return cellsCovering(
      south: center.latitude - latSpan,
      west: center.longitude - lonSpan,
      north: center.latitude + latSpan,
      east: center.longitude + lonSpan,
      scale: OutlineGridScale.block,
    );
  }

  /// The POTA references in [suggestions].
  static Set<String> potaRefsIn(Iterable<Map<String, dynamic>> suggestions) => {
    for (final suggestion in suggestions)
      if (suggestion['type'] == potaActivationType && suggestion['ref'] is String) suggestion['ref'] as String,
  };

  /// A park's whole outline, as POTA's `geojsonUrlForRef` names it — what an
  /// outline report about a bundle's pieces points a reviewer at, rather
  /// than at a cell clipped out of it.
  static String outlineUrlFor(String ref) => 'https://services.ham2k.net/lookups/outlines/pota/$ref.geojson';

  /// The parsed bundle for [cell], or null when it could not be read and no
  /// copy is kept — not remembered, so the next read asks again.
  Future<Map<String, OutlinePieces>?> _bundle(String cell) async {
    final url = '$_bundleBase$cell.geojson';
    if (_parsed.remove(url) case final kept?) return _parsed[url] = kept;
    final shape = await geoshapes.shapeFromSource((source: RefGeojson(url: url, maxAge: _maxAge, missMaxAge: _missMaxAge, sourceName: 'OSM'), answered: true));
    if (!shape.resolved) return null;
    final parks = shape.geojson == null ? const <String, OutlinePieces>{} : parseBundle(shape.geojson!, cell: cell, url: url);
    _parsed[url] = parks;
    while (_parsed.length > _keptBundles) {
      _parsed.remove(_parsed.keys.first);
    }
    return parks;
  }

  /// Each park's pieces in the bundle for [cell].
  ///
  /// Total, like [mapShapesFromGeojson]: a bundle comes from a server the app
  /// does not control, so a feature it cannot read is skipped.
  @visibleForTesting
  static Map<String, OutlinePieces> parseBundle(String geojson, {required String cell, required String url}) {
    final parks = <String, OutlinePieces>{};
    final Object? document;
    try {
      document = jsonDecode(geojson);
    } on FormatException {
      return parks;
    }
    final features = document is Map ? document['features'] : null;
    if (features is! List) return parks;
    for (final feature in features) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      final ref = (properties is Map ? properties['reference'] : null) ?? feature['id'];
      final kind = properties is Map ? properties['kind'] : null;
      if (ref is! String || (kind != 'area' && kind != 'edge' && kind != 'trail')) continue;
      final shapes = mapShapesFromGeojson(feature, idPrefix: 'grid/$cell/$ref/$kind', color: Colors.transparent, sourceName: 'OSM', sourceUrl: url);
      final park = parks.putIfAbsent(ref, OutlinePieces.new);
      (kind == 'area' ? park.areas : park.lines).addAll(shapes);
    }
    return parks;
  }
}
