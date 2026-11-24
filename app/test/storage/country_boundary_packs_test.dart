// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/country_boundary_packs.dart';
import 'package:ham2k_logger/services/country_boundary_packs_storage_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _country = CountryBoundaryPacks.us;
final _base = Uri.parse('https://example.com/packs');

void main() {
  PackageInfo.setMockInitialValues(appName: 'HaLo', packageName: 'com.ham2k.halo', version: '1.0.0', buildNumber: '1', buildSignature: '');
  late _MemoryStorage storage;
  late _TestCatalog catalog;
  late CountryBoundaryPacks packs;

  setUp(() {
    storage = _MemoryStorage();
    catalog = _TestCatalog();
    packs = CountryBoundaryPacks(baseUrl: _base, client: catalog.client, storage: storage);
  });

  test('downloads once and keeps a version and its bytes together after restart', () async {
    expect(await packs.installedPack(_country), isNull);
    expect(catalog.requested, isEmpty);

    expect(await packs.install(_country), 'one');
    final snapshot = (await packs.installedPack(_country))!;
    expect(snapshot.version, 'one');
    expect(snapshot.readMember('RI.bin.gz'), isNotNull);
    expect(snapshot.readMember('../RI.bin.gz'), isNull);
    expect(identical(snapshot, await packs.installedPack(_country)), isTrue);

    expect(await packs.install(_country), 'one');
    expect(catalog.requested.where((uri) => uri.path.endsWith('.zip')), hasLength(1));

    final offline = CountryBoundaryPacks(storage: storage, client: MockClient((_) => throw StateError('Offline')));
    expect(await offline.installedVersion(_country), 'one');
    expect((await offline.installedPack(_country))!.readMember('RI.bin.gz'), snapshot.readMember('RI.bin.gz'));
    await packs.remove(_country);
    expect(await packs.installedPack(_country), isNull);
    expect(await CountryBoundaryPacks(storage: storage).installedPack(_country), isNull);
  });

  test('incomplete data and failed writes leave the last good version available', () async {
    await packs.install(_country);
    final previous = (await packs.installedPack(_country))!;
    catalog.version = 'two';

    catalog.returnedZip = Uint8List.sublistView(catalog.zip, 0, catalog.zip.length - 1);
    await expectLater(packs.install(_country), throwsFormatException);
    expect(identical(previous, await packs.installedPack(_country)), isTrue);

    catalog.returnedZip = null;
    storage.failWrite = true;
    await expectLater(packs.install(_country), throwsStateError);
    expect(await CountryBoundaryPacks(storage: storage).installedVersion(_country), 'one');

    storage.failWrite = false;
    expect(await packs.install(_country), 'two');
    expect(await packs.installedVersion(_country), 'two');
    expect(previous.version, 'one', reason: 'a lookup that already holds a snapshot can finish using it');
    expect(previous.readMember('states.bin.gz'), isNotNull);
  });

  test('rejects foreign, upward and wrong-version paths before requesting them', () async {
    for (final path in ['https://other.example/a.zip', '../us/one.zip', '/us/one.zip', 'us/two.zip', 'us/%6fne.zip']) {
      catalog.path = path;
      await expectLater(packs.install(_country), throwsFormatException);
    }
    expect(catalog.requested.every((uri) => uri.path == '/packs/index.json'), isTrue);
    expect(await packs.installedPack(_country), isNull);
  });

  test('rejects an incorrect digest, unexpected ZIP member and incompatible gzip', () async {
    catalog.declaredHash = '0' * 64;
    await expectLater(packs.install(_country), throwsFormatException);
    catalog.declaredHash = null;

    catalog.zip = _makeZip(badName: true);
    await expectLater(packs.install(_country), throwsFormatException);
    catalog.zip = _makeZip(badGeometry: true);
    await expectLater(packs.install(_country), throwsFormatException);
    expect(storage.bytes, isNull);
  });

  test('does not follow redirects or use non-HTTPS catalogs', () async {
    catalog.redirectZip = true;
    await expectLater(packs.install(_country), throwsA(isA<http.ClientException>()));
    expect(catalog.requested, [_base.resolve('/packs/index.json'), _base.resolve('/packs/us/one.zip')]);
    final insecure = CountryBoundaryPacks(baseUrl: Uri.parse('http://example.com/packs/'), client: catalog.client, storage: storage);
    await expectLater(insecure.install(_country), throwsFormatException);
    expect(catalog.requested, hasLength(2));
  });

  test('a native storage replacement is readable from a new service', () async {
    final directory = await Directory.systemTemp.createTemp('halo-boundary-packs-test-');
    addTearDown(() => directory.delete(recursive: true));
    CountryBoundaryPacks open() => CountryBoundaryPacks(
      baseUrl: _base,
      client: catalog.client,
      storage: FileCountryBoundaryPackStorage(root: directory),
    );

    final first = open();
    expect(await first.installedVersion(_country), isNull);
    expect(await first.install(_country), 'one');
    expect(await open().installedVersion(_country), 'one');
    catalog.version = 'two';
    expect(await first.install(_country), 'two');
    expect(await open().installedVersion(_country), 'two');
    await first.remove(_country);
    expect(await open().installedVersion(_country), isNull);
  });
}

class _MemoryStorage implements CountryBoundaryPackStorage {
  Uint8List? bytes;
  bool failWrite = false;

  @override
  Future<Uint8List?> read(String country) async => bytes;

  @override
  Future<void> replace(String country, Uint8List next) async {
    if (failWrite) throw StateError('Storage is unavailable');
    bytes = next;
  }

  @override
  Future<void> remove(String country) async => bytes = null;
}

class _TestCatalog {
  String version = 'one';
  String? path;
  String? declaredHash;
  Uint8List zip = _makeZip();
  Uint8List? returnedZip;
  bool redirectZip = false;
  final requested = <Uri>[];

  late final client = MockClient((request) async {
    expect(request.followRedirects, isFalse);
    requested.add(request.url);
    if (request.url.path == '/packs/index.json') {
      return http.Response(
        jsonEncode({
          'schema': 1,
          'packs': {
            'US': {'version': version, 'path': path ?? 'us/$version.zip', 'bytes': zip.length, 'sha256': declaredHash ?? sha256.convert(zip).toString()},
          },
        }),
        200,
      );
    }
    expect(request.url.path, '/packs/us/$version.zip');
    if (redirectZip) return http.Response('', 302, headers: {'location': 'https://other.example/redirect.zip'});
    return http.Response.bytes(returnedZip ?? zip, 200);
  });
}

Uint8List _makeZip({bool badName = false, bool badGeometry = false}) {
  const states =
      'AK AL AR AZ CA CO CT DC DE FL GA HI IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY';
  final geometry = const GZipEncoder().encodeBytes(utf8.encode('HSB1\u0000'));
  final wrongGeometry = const GZipEncoder().encodeBytes(utf8.encode('HSB2\u0000'));
  final archive = Archive();
  final members = ['states.bin.gz', for (final state in states.split(' ')) '$state.bin.gz'];
  for (final member in members) {
    final name = badName && member == 'RI.bin.gz' ? '../RI.bin.gz' : member;
    final data = badGeometry && member == 'RI.bin.gz' ? wrongGeometry : geometry;
    archive.addFile(ArchiveFile(name, data.length, data)..compression = CompressionType.none);
  }
  archive.addFile(ArchiveFile('SOURCE-NOTICE.txt', 4, utf8.encode('test'))..compression = CompressionType.none);
  return ZipEncoder().encodeBytes(archive);
}
