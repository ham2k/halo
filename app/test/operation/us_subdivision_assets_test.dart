// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/country_boundary_packs.dart';
import 'package:ham2k_logger/services/us_subdivision_lookup.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the published pack installs, reopens offline, and resolves its real boundaries', () async {
    const country = CountryBoundaryPacks.us;
    const root = '../data/country-packs';
    final index = await File('$root/index.json').readAsString();
    final manifest = jsonDecode(index) as Map<String, dynamic>;
    final entry = (manifest['packs'] as Map<String, dynamic>)[country] as Map<String, dynamic>;
    final path = entry['path'] as String;
    final archive = await File('$root/$path').readAsBytes();
    final store = _MemoryPackStorage();
    final baseUrl = Uri.parse('https://packs.example/country-packs/');
    final requests = <String>[];
    final packs = CountryBoundaryPacks(
      baseUrl: baseUrl,
      storage: store,
      client: MockClient((request) async {
        expect(request.url.host, baseUrl.host);
        expect(request.url.query, isEmpty);
        requests.add(request.url.path);
        return request.url.path.endsWith('/index.json') ? http.Response(index, 200) : http.Response.bytes(archive, 200);
      }),
    );
    const providence = GridLocation(41.8241, -71.4132);
    final before = UsSubdivisionLookup(packs: packs);
    await _expectLookup(before, providence);
    expect(requests, isEmpty, reason: 'accepting a fix never initiates a download');
    expect(await packs.install(country), entry['version']);
    expect(requests, ['/country-packs/index.json', '/country-packs/$path']);

    final reopened = CountryBoundaryPacks(
      baseUrl: baseUrl,
      storage: store,
      client: MockClient((_) async => throw StateError('offline lookup attempted a request')),
    );
    final offline = UsSubdivisionLookup(packs: reopened);
    await _expectLookup(offline, providence, state: 'RI', county: 'Providence');
    await _expectLookup(offline, const GridLocation(41.7627, -72.6745), state: 'CT');
    const attu = GridLocation(52.8677, 173.1912);
    const amatignak = GridLocation(51.2695, -179.1115);
    for (final island in [attu, amatignak]) {
      await _expectLookup(offline, island, state: 'AK', county: 'Aleutians West');
    }
    await _expectLookup(offline, const GridLocation(43.6534, -79.3839));

    const countyLine = GridLocation(41.76083, -71.43);
    final boundary = await offline.lookup(countyLine, accuracyMeters: 200);
    expect(boundary.state, 'RI');
    expect(boundary.county, isNull);
    expect(boundary.candidates, unorderedEquals([(state: 'RI', county: 'Kent'), (state: 'RI', county: 'Providence')]));
  });
}

Future<void> _expectLookup(UsSubdivisionLookup lookup, GridLocation fix, {String? state, String? county}) async {
  final result = await lookup.lookup(fix, accuracyMeters: 20);
  expect(result.state, state);
  expect(result.county, county);
  expect(result.candidates, isEmpty);
}

class _MemoryPackStorage implements CountryBoundaryPackStorage {
  Uint8List? _bytes;

  @override
  Future<Uint8List?> read(String country) async => _bytes;

  @override
  Future<void> replace(String country, Uint8List bytes) async => _bytes = bytes;

  @override
  Future<void> remove(String country) async => _bytes = null;
}
