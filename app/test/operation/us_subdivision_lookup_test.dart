// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/country_boundary_packs.dart';
import 'package:ham2k_logger/services/us_subdivision_lookup.dart';

typedef _Ring = List<(double x, double y)>;
typedef _Feature = ({String name, List<List<_Ring>> polygons});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final states = [_feature('RI', _rectangle(-72, 41, -71, 42)), _feature('MA', _rectangle(-72, 42, -71, 43))];
  final rhodeIsland = [
    _feature('Providence', _rectangle(-72, 41, -71.5, 42), holes: [_rectangle(-71.8, 41.4, -71.7, 41.6)]),
    _feature('Newport', _rectangle(-71.5, 41, -71.25, 42)),
    _feature('', _rectangle(-71.25, 41, -71, 42)),
  ];
  final massachusetts = [_feature('Bristol', _rectangle(-72, 42, -71, 43))];

  late _TestPacks packs;
  late UsSubdivisionLookup lookup;
  setUp(() {
    packs = _TestPacks()..snapshot = _TestPack({'states': states, 'RI': rhodeIsland, 'MA': massachusetts});
    lookup = UsSubdivisionLookup(packs: packs);
  });

  test('resolves the state and county from a confident fix', () async {
    await _expectLookup(lookup, const GridLocation(41.5, -71.9), 30, state: 'RI', county: 'Providence');
    await _expectLookup(lookup, const GridLocation(41.5, -71.9), 40, state: 'RI', county: 'Providence');
    expect(packs.snapshot!.requested, ['states', 'RI']);
  });

  test('keeps state and offers both counties when the fix crosses their boundary', () async {
    // The center is in Providence, and the 100 m box reaches the next county.
    const nearEdge = GridLocation(41.5, -71.5005);
    const choices = [(state: 'RI', county: 'Providence'), (state: 'RI', county: 'Newport')];
    await _expectLookup(lookup, nearEdge, 100, state: 'RI', candidates: choices);
    await _expectLookup(lookup, nearEdge, 5, state: 'RI', county: 'Providence');
    await _expectLookup(lookup, const GridLocation(41.5, -71.5), 1, state: 'RI', candidates: choices);
  });

  test('offers state and county pairs and no automatic selection on a state line', () async {
    const choices = [(state: 'RI', county: 'Providence'), (state: 'MA', county: 'Bristol')];
    await _expectLookup(lookup, const GridLocation(41.9995, -71.9), 100, candidates: choices);
    await _expectLookup(lookup, const GridLocation(42, -71.9), 1, candidates: choices);
    expect(packs.snapshot!.requested, ['states', 'RI', 'MA']);
  });

  test('withholds county for a hole, its edge, and an unnamed county', () async {
    await _expectLookup(lookup, const GridLocation(41.5, -71.75), 5, state: 'RI');
    await _expectLookup(lookup, const GridLocation(41.5, -71.8), 5, state: 'RI', candidates: [(state: 'RI', county: 'Providence')]);
    await _expectLookup(lookup, const GridLocation(41.5, -71.25), 5, state: 'RI', candidates: [(state: 'RI', county: 'Newport')]);
    await _expectLookup(lookup, const GridLocation(41.5, -71.1), 5, state: 'RI');
  });

  test('a pack replacement and removal take effect on the next fix', () async {
    const fix = GridLocation(41.5, -71.9);
    await _expectLookup(lookup, fix, 30, state: 'RI', county: 'Providence');
    packs.snapshot = _TestPack({
      'states': states,
      'RI': [_feature('Kent', _rectangle(-72, 41, -71, 42))],
    });
    await _expectLookup(lookup, fix, 30, state: 'RI', county: 'Kent');
    packs.snapshot = null;
    await _expectLookup(lookup, fix, 30);
  });

  test('requires a valid fix and a positive reported accuracy', () async {
    for (final accuracy in [0.0, -1.0, double.nan, double.infinity]) {
      await _expectLookup(lookup, const GridLocation(41.5, -71.9), accuracy);
    }
    await _expectLookup(lookup, const GridLocation(41.5, 181), 1);
    expect(packs.snapshot!.requested, isEmpty);
  });
}

Future<void> _expectLookup(
  UsSubdivisionLookup lookup,
  GridLocation fix,
  double accuracy, {
  String? state,
  String? county,
  List<UsSubdivisionCandidate> candidates = const [],
}) async {
  final result = await lookup.lookup(fix, accuracyMeters: accuracy);
  expect(result.state, state);
  expect(result.county, county);
  expect(result.candidates, candidates);
}

_Feature _feature(String name, _Ring outer, {List<_Ring> holes = const []}) => (
  name: name,
  polygons: [
    [outer, ...holes],
  ],
);

_Ring _rectangle(double west, double south, double east, double north) => [(west, south), (east, south), (east, north), (west, north)];

class _TestPacks extends CountryBoundaryPacks {
  _TestPack? snapshot;

  @override
  Future<CountryBoundaryPackSnapshot?> installedPack(String country) async => snapshot;
}

class _TestPack implements CountryBoundaryPackSnapshot {
  _TestPack(this.featuresByAsset);

  final Map<String, List<_Feature>> featuresByAsset;
  final requested = <String>[];

  @override
  String get version => 'test';

  @override
  String get sha256 => '';

  @override
  Uint8List? readMember(String key) {
    const suffix = '.bin.gz';
    expect(key, endsWith(suffix));
    final asset = key.substring(0, key.length - suffix.length);
    requested.add(asset);
    return _encodeFeatures(featuresByAsset[asset]!);
  }
}

Uint8List _encodeFeatures(List<_Feature> features) {
  final bytes = BytesBuilder()..add(ascii.encode('HSB1'));

  void writeUint(int value) {
    while (value >= 128) {
      bytes.addByte((value & 127) | 128);
      value >>= 7;
    }
    bytes.addByte(value);
  }

  void writeDelta(int delta) => writeUint(delta < 0 ? -2 * delta - 1 : 2 * delta);

  writeUint(features.length);
  for (final feature in features) {
    final name = utf8.encode(feature.name);
    writeUint(name.length);
    bytes.add(name);
    writeUint(feature.polygons.length);
    for (final polygon in feature.polygons) {
      writeUint(polygon.length);
      for (final ring in polygon) {
        writeUint(ring.length);
        var previousX = 0;
        var previousY = 0;
        for (final (longitude, latitude) in ring) {
          final x = (longitude * 100000).round();
          final y = (latitude * 100000).round();
          writeDelta(x - previousX);
          writeDelta(y - previousY);
          previousX = x;
          previousY = y;
        }
      }
    }
  }
  return const GZipEncoder().encodeBytes(bytes.takeBytes());
}
