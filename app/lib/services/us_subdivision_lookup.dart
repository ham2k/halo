// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:halo_core/halo_core.dart';

import 'country_boundary_packs.dart';

const _unitsPerDegree = 100000;

typedef UsSubdivisionCandidate = ({String state, String? county});
typedef UsSubdivisionResult = ({String? state, String? county, List<UsSubdivisionCandidate> candidates});

const UsSubdivisionResult noUsSubdivision = (state: null, county: null, candidates: []);

/// A subdivision can autofill when it contains the entire accuracy area.
/// Intersections are possible locations for the operator to choose from.
class UsSubdivisionLookup {
  UsSubdivisionLookup({CountryBoundaryPacks? packs}) : _packs = packs ?? CountryBoundaryPacks();

  final CountryBoundaryPacks _packs;
  _DecodedPack? _decodedPack;

  Future<UsSubdivisionResult> lookup(GridLocation fix, {required double accuracyMeters}) async {
    final area = _FixArea.forLocation(fix, accuracyMeters);
    if (area == null) return noUsSubdivision;
    final installed = await _packs.installedPack(CountryBoundaryPacks.us);
    if (installed == null) {
      _decodedPack = null;
      return noUsSubdivision;
    }
    final previous = _decodedPack;
    final pack = previous != null && identical(previous.snapshot, installed) ? previous : (_decodedPack = _DecodedPack(installed));
    final states = _matches(await pack.states, area);
    final state = _containedName(states);

    if (state != null) {
      final counties = _matches(await pack.counties(state), area);
      final county = _containedName(counties);
      return (state: state, county: county, candidates: county == null ? _countyChoices(state, counties) : const <UsSubdivisionCandidate>[]);
    }

    final candidates = <UsSubdivisionCandidate>[];
    for (final stateMatch in states) {
      final name = stateMatch.name;
      if (name == null) continue;
      final counties = _matches(await pack.counties(name), area);
      final choices = _countyChoices(name, counties);
      candidates.addAll(choices);
      if (choices.isEmpty || counties.any((match) => match.name == null)) candidates.add((state: name, county: null));
    }
    return (state: null, county: null, candidates: candidates);
  }
}

class _DecodedPack {
  _DecodedPack(this.snapshot);

  final CountryBoundaryPackSnapshot snapshot;
  late final Future<List<_Boundary>> states = _load('states');
  final _byState = <String, Future<List<_Boundary>>>{};

  Future<List<_Boundary>> counties(String state) {
    final cached = _byState.remove(state);
    // A state-line lookup commonly uses two adjacent states at a time.
    if (_byState.length >= 2) _byState.remove(_byState.keys.first);
    return _byState[state] = cached ?? _load(state);
  }

  Future<List<_Boundary>> _load(String name) async {
    final data = snapshot.readMember('$name.bin.gz');
    if (data == null) throw FormatException('Missing subdivision geometry for $name');
    return compute(_decodeBoundaries, data);
  }
}

typedef _SubdivisionMatch = ({String? name, bool contained});

List<_SubdivisionMatch> _matches(List<_Boundary> boundaries, _FixArea area) {
  final matches = <_SubdivisionMatch>[];
  for (final boundary in boundaries) {
    var relation = _Relation.outside;
    for (final polygon in boundary.polygons) {
      final candidate = polygon.relationTo(area);
      if (candidate == _Relation.outside) continue;
      relation = candidate;
      if (relation == _Relation.inside) break;
    }
    if (relation != _Relation.outside) matches.add((name: boundary.name, contained: relation == _Relation.inside));
  }
  return matches;
}

String? _containedName(List<_SubdivisionMatch> matches) => matches.length == 1 && matches.single.contained ? matches.single.name : null;

List<UsSubdivisionCandidate> _countyChoices(String state, List<_SubdivisionMatch> matches) => [
  for (final match in matches)
    if (match.name != null) (state: state, county: match.name),
];

class _FixArea {
  const _FixArea(this.x, this.y, this.dx, this.dy);

  final double x;
  final double y;
  final double dx;
  final double dy;

  double get left => x - dx;
  double get right => x + dx;
  double get bottom => y - dy;
  double get top => y + dy;

  static _FixArea? forLocation(GridLocation fix, double accuracyMeters) {
    final lat = fix.latitude;
    final lon = fix.longitude;
    if (!lat.isFinite || lat.abs() > 90 || !lon.isFinite || lon.abs() > 180 || !accuracyMeters.isFinite || accuracyMeters <= 0) {
      return null;
    }

    // Enclose the accuracy circle with a rectangle, using a lower bound on
    // metres per degree and an extra metre for coordinate quantization.
    const minMetersPerDegree = 110000;
    final latRadius = (accuracyMeters + 1) / minMetersPerDegree;
    final farthestLatitude = lat.abs() + latRadius;
    if (farthestLatitude >= 90) return null;
    final lonRadius = latRadius / math.cos(farthestLatitude * math.pi / 180);
    if (lonRadius >= 180) return null;
    return _FixArea(lon * _unitsPerDegree, lat * _unitsPerDegree, lonRadius * _unitsPerDegree, latRadius * _unitsPerDegree);
  }
}

class _Boundary {
  const _Boundary(this.name, this.polygons);

  final String? name;
  final List<_Polygon> polygons;
}

class _Polygon {
  const _Polygon(this.outer, this.holes);

  final _Ring outer;
  final List<_Ring> holes;

  _Relation relationTo(_FixArea area) {
    var relation = outer.relationTo(area);
    if (relation == _Relation.outside) return relation;
    for (final hole in holes) {
      switch (hole.relationTo(area)) {
        case _Relation.inside:
          return _Relation.outside;
        case _Relation.touches:
          relation = _Relation.touches;
        case _Relation.outside:
          break;
      }
    }
    return relation;
  }
}

enum _Relation { outside, inside, touches }

class _Ring {
  const _Ring(this.coords, {required this.left, required this.right, required this.bottom, required this.top});

  // Alternating longitude and latitude in quantized units. The generator
  // requires rings to be split at the antimeridian, so each stays local.
  final Int32List coords;
  final int left;
  final int right;
  final int bottom;
  final int top;

  _Relation relationTo(_FixArea area) {
    if (area.right < left || area.left > right || area.top < bottom || area.bottom > top) return _Relation.outside;

    var inside = false;
    var previousX = coords[coords.length - 2];
    var previousY = coords.last;
    for (var i = 0; i < coords.length; i += 2) {
      final x = coords[i];
      final y = coords[i + 1];
      if (_segmentTouches(area, previousX, previousY, x, y)) return _Relation.touches;

      // Follow a horizontal ray from the center of the fix. Count a vertex
      // once even when both edges meeting it are otherwise ray candidates.
      if ((y > area.y) != (previousY > area.y) && area.x < x + (previousX - x) * (area.y - y) / (previousY - y)) {
        inside = !inside;
      }
      previousX = x;
      previousY = y;
    }
    return inside ? _Relation.inside : _Relation.outside;
  }
}

bool _segmentTouches(_FixArea area, int x1, int y1, int x2, int y2) {
  if ((x1 < area.left && x2 < area.left) ||
      (x1 > area.right && x2 > area.right) ||
      (y1 < area.bottom && y2 < area.bottom) ||
      (y1 > area.top && y2 > area.top)) {
    return false;
  }

  // The bounding boxes overlap. The remaining possible separating axis is
  // the line along the segment. Project the box's center and half-extents
  // onto its normal to detect an intersection, including a shared edge.
  final dx = x2 - x1;
  final dy = y2 - y1;
  final offset = (dx * (area.y - y1) - dy * (area.x - x1)).abs();
  return offset <= dx.abs() * area.dy + dy.abs() * area.dx;
}

List<_Boundary> _decodeBoundaries(Uint8List data) {
  final reader = _BoundaryReader(const GZipDecoder().decodeBytes(data));
  if (reader.readString(4) != 'HSB1') throw const FormatException('Unknown US subdivision data format');
  final boundaries = List<_Boundary>.generate(reader.readUint(), (_) {
    final name = reader.readString(reader.readUint());
    final polygons = List<_Polygon>.generate(reader.readUint(), (_) {
      final ringCount = reader.readUint();
      if (ringCount < 1) throw const FormatException('US subdivision polygon has no exterior ring');
      final outer = reader.readRing();
      final holes = List<_Ring>.generate(ringCount - 1, (_) => reader.readRing(), growable: false);
      return _Polygon(outer, holes);
    }, growable: false);
    return _Boundary(name.isEmpty ? null : name, polygons);
  }, growable: false);
  if (reader.offset != reader.bytes.length) throw const FormatException('Unexpected data after US subdivision boundaries');
  return boundaries;
}

class _BoundaryReader {
  _BoundaryReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  String readString(int length) {
    final end = offset + length;
    if (end > bytes.length) throw const FormatException('Truncated US subdivision data');
    final value = utf8.decode(Uint8List.sublistView(bytes, offset, end));
    offset = end;
    return value;
  }

  int readUint() {
    var value = 0;
    for (var shift = 0; shift <= 28 && offset < bytes.length; shift += 7) {
      final byte = bytes[offset++];
      if (shift == 28 && byte > 7) break;
      value |= (byte & 127) << shift;
      if (byte < 128) return value;
    }
    throw const FormatException('Invalid US subdivision data integer');
  }

  int readDelta() {
    final value = readUint();
    final magnitude = value >> 1;
    // Dart's web bitwise operators return unsigned values, so apply the
    // sign with arithmetic before accumulating the coordinate.
    return value.isEven ? magnitude : -magnitude - 1;
  }

  _Ring readRing() {
    final vertexCount = readUint();
    if (vertexCount < 3 || vertexCount * 2 > bytes.length - offset) throw const FormatException('Invalid US subdivision ring size');
    final coords = Int32List(2 * vertexCount);
    var longitude = 0;
    var latitude = 0;
    var left = 180 * _unitsPerDegree;
    var right = -180 * _unitsPerDegree;
    var bottom = 90 * _unitsPerDegree;
    var top = -90 * _unitsPerDegree;
    for (var i = 0; i < coords.length; i += 2) {
      longitude += readDelta();
      latitude += readDelta();
      coords[i] = longitude;
      coords[i + 1] = latitude;
      left = math.min(left, longitude);
      right = math.max(right, longitude);
      bottom = math.min(bottom, latitude);
      top = math.max(top, latitude);
    }
    return _Ring(coords, left: left, right: right, bottom: bottom, top: top);
  }
}
