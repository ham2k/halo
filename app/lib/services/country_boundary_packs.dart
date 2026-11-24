// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:http/http.dart' as http;

import '../config/user_agent.dart';
import 'country_boundary_packs_storage.dart';

export 'country_boundary_packs_storage.dart' show CountryBoundaryPackStorage;

const _catalogBase = String.fromEnvironment('BOUNDARY_PACK_BASE_URL', defaultValue: 'https://raw.githubusercontent.com/ham2k/halo/main/data/country-packs/');
const _downloadTimeout = Duration(seconds: 45);
const _maxIndexBytes = 64 * 1024;
const _maxMemberBytes = 8 * 1024 * 1024;
const _maxInflatedMemberBytes = 16 * 1024 * 1024;
const _notice = 'SOURCE-NOTICE.txt';
const _usStates = [
  'AK',
  'AL',
  'AR',
  'AZ',
  'CA',
  'CO',
  'CT',
  'DC',
  'DE',
  'FL',
  'GA',
  'HI',
  'IA',
  'ID',
  'IL',
  'IN',
  'KS',
  'KY',
  'LA',
  'MA',
  'MD',
  'ME',
  'MI',
  'MN',
  'MO',
  'MS',
  'MT',
  'NC',
  'ND',
  'NE',
  'NH',
  'NJ',
  'NM',
  'NV',
  'NY',
  'OH',
  'OK',
  'OR',
  'PA',
  'RI',
  'SC',
  'SD',
  'TN',
  'TX',
  'UT',
  'VA',
  'VT',
  'WA',
  'WI',
  'WV',
  'WY',
];
final _usMembers = {'states.bin.gz', _notice, for (final state in _usStates) '$state.bin.gz'};

/// An installed version and all of its members from one atomic read. Keep a
/// snapshot for an entire lookup so an update cannot mix its state geometry
/// with another version's county geometry.
abstract interface class CountryBoundaryPackSnapshot {
  String get version;
  String get sha256;
  Uint8List? readMember(String filename);
}

class _PackSnapshot implements CountryBoundaryPackSnapshot {
  _PackSnapshot(this.version, this.sha256, this._members);

  @override
  final String version;
  @override
  final String sha256;
  final Map<String, Uint8List> _members;

  @override
  Uint8List? readMember(String filename) {
    final bytes = _members[filename];
    // Copy just the member before handing it to a caller (or another isolate).
    // ZIP_STORE views are otherwise backed by the entire archive.
    return bytes == null ? null : Uint8List.fromList(bytes);
  }
}

/// Installs optional offline boundary data from the HaLo country pack catalog.
/// Position lookup only reads installed snapshots. It never contacts the catalog.
class CountryBoundaryPacks {
  CountryBoundaryPacks({Uri? baseUrl, this._client, CountryBoundaryPackStorage? storage})
    : _baseUrl = baseUrl ?? Uri.parse(_catalogBase),
      _storage = storage ?? createCountryBoundaryPackStorage();

  static const us = 'US';
  static const maxPackBytes = 32 * 1024 * 1024;

  final Uri _baseUrl;
  final http.Client? _client;
  final CountryBoundaryPackStorage _storage;
  Future<CountryBoundaryPackSnapshot?>? _installed;
  Future<void> _mutation = Future.value();

  Future<CountryBoundaryPackSnapshot?> installedPack(String country) async {
    _requireCountry(country);
    final reading = _installed ??= _restore();
    try {
      return await reading;
    } catch (_) {
      if (identical(_installed, reading)) _installed = null;
      rethrow;
    }
  }

  Future<String?> installedVersion(String country) async => (await installedPack(country))?.version;

  /// Downloads and verifies the replacement before committing it. A partial
  /// download, bad catalog or failed write leaves the last good pack available.
  Future<String> install(String country, {void Function(double fraction)? onProgress}) {
    _requireCountry(country);
    return _mutate(() async {
      final release = await _release();
      final previous = await installedPack(country);
      if (previous?.version == release.version && previous?.sha256 == release.sha256) return release.version;

      final bytes = await _download(_catalog.resolve(release.path), limit: release.bytes, exactSize: release.bytes, onProgress: onProgress);
      final snapshot = await compute(_validateDownload, (release: release, bytes: bytes));
      await _storage.replace(country, _encodeRecord(release, bytes));
      _installed = Future.value(snapshot);
      return snapshot.version;
    });
  }

  Future<void> remove(String country) {
    _requireCountry(country);
    return _mutate(() async {
      await _storage.remove(country);
      _installed = Future.value(null);
    });
  }

  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _mutation.then((_) => action());
    _mutation = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<CountryBoundaryPackSnapshot?> _restore() async {
    final record = await _storage.read(us);
    if (record == null) return null;
    try {
      return await compute(_decodeRecord, record);
    } on FormatException {
      // A corrupt local cache looks absent, so it can be downloaded again.
      return null;
    }
  }

  static void _requireCountry(String country) {
    if (country != us) throw ArgumentError.value(country, 'country', 'Unsupported boundary pack');
  }

  Uri get _catalog {
    final base = _baseUrl;
    if (base.scheme != 'https' || base.host.isEmpty || base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw const FormatException('Country boundary pack catalog needs an HTTPS base URL');
    }
    return base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
  }

  Future<_Release> _release() async {
    final bytes = await _download(_catalog.resolve('index.json'), limit: _maxIndexBytes);
    final value = jsonDecode(utf8.decode(bytes));
    if (value case {'schema': 1, 'packs': {us: final Map<String, dynamic> entry}}) return _Release.fromJson(entry);
    throw const FormatException('Unknown country boundary pack catalog schema');
  }

  Future<Uint8List> _download(Uri url, {required int limit, int? exactSize, void Function(double fraction)? onProgress}) async {
    final client = _client ?? http.Client();
    try {
      // The catalog and its archives share the same configured HTTPS origin.
      // An HTTP redirect cannot extend that trust, even temporarily.
      final request = http.Request('GET', url)..followRedirects = false;
      if (!kIsWeb) request.headers['User-Agent'] = await ham2kUserAgentOrFallback();
      final response = await client.send(request).timeout(_downloadTimeout);
      final declared = response.contentLength;
      if (response.statusCode != 200 || (declared != null && (declared > limit || (exactSize != null && declared != exactSize)))) {
        await response.stream.listen(null).cancel();
        if (response.statusCode != 200) throw http.ClientException('Country boundary pack server returned ${response.statusCode}', url);
        throw const FormatException('Country boundary pack download size differs from the catalog');
      }

      final data = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(_downloadTimeout)) {
        if (data.length + chunk.length > limit) throw const FormatException('Country boundary pack download exceeds its size limit');
        data.add(chunk);
        if (exactSize != null) onProgress?.call(data.length / exactSize);
      }
      if (exactSize != null && data.length != exactSize) throw const FormatException('Country boundary pack download is incomplete');
      return data.takeBytes();
    } finally {
      if (_client == null) client.close();
    }
  }
}

class _Release {
  const _Release({required this.version, required this.bytes, required this.sha256});

  factory _Release.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final path = json['path'];
    final bytes = json['bytes'];
    final hash = json['sha256'];
    if (version is! String ||
        _versionPattern.stringMatch(version) != version ||
        path != 'us/$version.zip' ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > CountryBoundaryPacks.maxPackBytes ||
        hash is! String ||
        _hashPattern.stringMatch(hash) != hash) {
      throw const FormatException('Invalid U.S. country boundary pack release');
    }
    return _Release(version: version, bytes: bytes, sha256: hash.toLowerCase());
  }

  static final _versionPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
  static final _hashPattern = RegExp(r'^[A-Fa-f0-9]{64}$');
  final String version;
  final int bytes;
  final String sha256;

  String get path => 'us/$version.zip';

  Map<String, dynamic> toJson() => {'version': version, 'path': path, 'bytes': bytes, 'sha256': sha256};
}

Uint8List _encodeRecord(_Release release, Uint8List bytes) {
  final metadata = utf8.encode(jsonEncode({'schema': 1, ...release.toJson()}));
  final length = ByteData(4)..setUint32(0, metadata.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(length.buffer.asUint8List())
        ..add(metadata)
        ..add(bytes))
      .takeBytes();
}

CountryBoundaryPackSnapshot _decodeRecord(Uint8List record) {
  if (record.length < 4) throw const FormatException('Truncated local country boundary pack');
  final length = ByteData.sublistView(record).getUint32(0, Endian.little);
  final offset = 4 + length;
  if (length > _maxIndexBytes || offset >= record.length) throw const FormatException('Invalid local country boundary pack metadata');
  final json = jsonDecode(utf8.decode(Uint8List.sublistView(record, 4, offset)));
  if (json is! Map<String, dynamic> || json['schema'] != 1) throw const FormatException('Unknown local country boundary pack schema');
  return _openZip(_Release.fromJson(json), Uint8List.sublistView(record, offset), validateGeometry: false);
}

CountryBoundaryPackSnapshot _validateDownload(({_Release release, Uint8List bytes}) download) =>
    _openZip(download.release, download.bytes, validateGeometry: true);

CountryBoundaryPackSnapshot _openZip(_Release release, Uint8List bytes, {required bool validateGeometry}) {
  if (bytes.length != release.bytes || sha256.convert(bytes).toString() != release.sha256) {
    throw const FormatException('Country boundary pack checksum does not match the catalog');
  }

  try {
    // The producer uses a flat, stored ZIP with no comment or Zip64
    // records. Bound the central directory before letting the reader walk it.
    const endBytes = 22;
    if (bytes.length < endBytes) throw const FormatException('Truncated country boundary ZIP');
    final end = bytes.length - endBytes;
    final data = ByteData.sublistView(bytes);
    final centralLength = data.getUint32(end + 12, Endian.little);
    if (data.getUint32(0, Endian.little) != ZipFile.zipSignature ||
        data.getUint32(end, Endian.little) != ZipDirectory.eocdSignature ||
        data.getUint16(end + 4, Endian.little) != 0 ||
        data.getUint16(end + 6, Endian.little) != 0 ||
        data.getUint16(end + 8, Endian.little) != _usMembers.length ||
        data.getUint16(end + 10, Endian.little) != _usMembers.length ||
        centralLength > _maxIndexBytes ||
        data.getUint32(end + 16, Endian.little) + centralLength != end ||
        data.getUint16(end + 20, Endian.little) != 0) {
      throw const FormatException('Unexpected country boundary ZIP structure');
    }

    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    final members = <String, Uint8List>{};
    for (final header in directory.fileHeaders) {
      final name = header.filename;
      final file = header.file;
      final type = (header.externalFileAttributes >> 16) & 0xf000;
      final limit = name == _notice ? _maxIndexBytes : _maxMemberBytes;
      if (!_usMembers.contains(name) ||
          members.containsKey(name) ||
          file == null ||
          file.filename != name ||
          (type != 0 && type != 0x8000) ||
          header.generalPurposeBitFlag & 1 != 0 ||
          file.flags & 1 != 0 ||
          header.compressionMethod != ZipFile.zipCompressionStore ||
          file.compressionMethod != CompressionType.none ||
          file.uncompressedSize != file.compressedSize ||
          file.uncompressedSize <= 0 ||
          file.uncompressedSize > limit) {
        throw const FormatException('Unexpected member in country boundary ZIP');
      }

      final content = file.getStream(decompress: false).toUint8List();
      if (content.length != file.uncompressedSize || getCrc32(content) != header.crc32) {
        throw const FormatException('Damaged member in country boundary ZIP');
      }
      if (validateGeometry && name != _notice) _checkGeometry(content);
      members[name] = content;
    }
    if (members.length != _usMembers.length) throw const FormatException('Incomplete country boundary ZIP');
    return _PackSnapshot(release.version, release.sha256, members);
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('Damaged country boundary ZIP: $error');
  }
}

void _checkGeometry(Uint8List bytes) {
  if (bytes.length < 18 || bytes[0] != 0x1f || bytes[1] != 0x8b || bytes[2] != 8) {
    throw const FormatException('Boundary geometry is not gzip');
  }
  final trailer = ByteData.sublistView(bytes, bytes.length - 8);
  final length = trailer.getUint32(4, Endian.little);
  if (length < 5 || length > _maxInflatedMemberBytes) throw const FormatException('Boundary geometry exceeds its size limit');
  final output = _BoundedOutput(length);
  // Force the streaming implementation, which can enforce the output limit
  // while inflating on every platform.
  const GZipDecoderWeb().decodeStream(InputMemoryStream(bytes), output);
  final geometry = output.getBytes();
  if (geometry.length != length || getCrc32(geometry) != trailer.getUint32(0, Endian.little) || ascii.decode(geometry.take(4).toList()) != 'HSB1') {
    throw const FormatException('Invalid country boundary geometry schema');
  }
}

class _BoundedOutput extends OutputMemoryStream {
  _BoundedOutput(this.limit) : super(size: limit);

  final int limit;

  void _check(int amount) {
    if (length + amount > limit) throw const FormatException('Boundary geometry exceeds its size limit');
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}
