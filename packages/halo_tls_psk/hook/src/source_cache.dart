// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'unified_patch.dart';

const _maxArchiveBytes = 32 * 1024 * 1024;
const _maxExpandedBytes = 128 * 1024 * 1024;
const _maxFileBytes = 16 * 1024 * 1024;
const _maxMetadataBytes = 1024 * 1024;
const _downloadTimeout = Duration(minutes: 2);
const _lockTimeout = Duration(minutes: 5);
const _cacheFormat = 'halo-mbedtls-source-v2';
final _pending = <String, Future<void>>{};

class MbedTlsSourceException implements Exception {
  final String message;
  const MbedTlsSourceException(this.message);
  @override
  String toString() => 'Mbed TLS source: $message';
}

/// Shared across checkouts and unaffected by `flutter clean`. The optional
/// platform inputs let tests exercise all hosts without touching user caches.
Uri defaultMbedTlsCacheDirectory({String? operatingSystem, Map<String, String>? environment}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final env = environment ?? Platform.environment;
  String? base;
  if (os == 'windows') {
    base = env['LOCALAPPDATA'];
    if (base == null || base.isEmpty) {
      final profile = env['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) base = '$profile/AppData/Local';
    }
  } else {
    final home = env['HOME'];
    if (os == 'macos') {
      if (home != null && home.startsWith('/')) base = '$home/Library/Caches';
    } else {
      final xdg = env['XDG_CACHE_HOME'];
      if (xdg != null && xdg.startsWith('/')) {
        base = xdg;
      } else if (home != null && home.startsWith('/')) {
        base = '$home/.cache';
      }
    }
  }
  if (base == null || base.isEmpty || (os == 'windows' && !RegExp(r'^(?:[a-zA-Z]:[/\\]|[/\\]{2})').hasMatch(base))) {
    throw const MbedTlsSourceException('Cannot locate the user cache directory; provide --cache-dir or the cache_dir build-hook setting');
  }
  return Uri.directory(base, windows: os == 'windows').resolve('ham2k/halo_tls_psk/mbedtls/');
}

/// Returns only a fully verified, patched source tree. Every cache hit is
/// rehashed; the completion marker alone is never trusted. A corrupt cache
/// fails closed and must be removed explicitly before retrying.
Future<Uri> prepareMbedTls({required Uri packageRoot, required Uri cacheDirectory, bool offline = false}) async {
  final manifest = await _Manifest.read(Directory.fromUri(packageRoot).absolute.uri);
  final requestedCache = Directory.fromUri(cacheDirectory);
  await requestedCache.create(recursive: true);
  final cache = Directory(await requestedCache.resolveSymbolicLinks());
  // POSIX file locks are process-scoped. Serialize callers in this isolate too;
  // separate hook processes are serialized by the OS lock below.
  final previous = _pending[cache.path] ?? Future<void>.value();
  final released = Completer<void>();
  _pending[cache.path] = released.future;
  await previous;
  try {
    return await _withLock(cache, () => _prepare(cache, manifest, offline));
  } finally {
    released.complete();
    if (identical(_pending[cache.path], released.future)) unawaited(_pending.remove(cache.path));
  }
}

Future<T> _withLock<T>(Directory cache, Future<T> Function() action) async {
  final file = File.fromUri(cache.uri.resolve('.lock'));
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file) {
    throw const MbedTlsSourceException('Cache lock is not a regular file');
  }
  final lock = await file.open(mode: FileMode.append);
  var locked = false;
  try {
    final elapsed = Stopwatch()..start();
    while (!locked) {
      try {
        await lock.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        if (elapsed.elapsed >= _lockTimeout) {
          throw const MbedTlsSourceException('Timed out waiting for the source cache lock');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return await action();
  } finally {
    if (locked) await lock.unlock();
    await lock.close();
  }
}

Future<Uri> _prepare(Directory cache, _Manifest manifest, bool offline) async {
  // The cache-wide lock guarantees no active invocation owns these. A killed
  // process may leave a large partial tree, including before publication.
  await for (final entry in cache.list(followLinks: false)) {
    if (entry is Directory && entry.uri.pathSegments.where((part) => part.isNotEmpty).last.startsWith('.staging-')) {
      await entry.delete(recursive: true);
    }
  }
  final completed = Directory.fromUri(cache.uri.resolve('${manifest.key}/'));
  if (await FileSystemEntity.type(completed.path, followLinks: false) != FileSystemEntityType.notFound) {
    await _requireDirectory(completed);
    final marker = await _readFile(File.fromUri(completed.uri.resolve('complete')), _maxMetadataBytes);
    if (utf8.decode(marker) != '${manifest.key}\n') throw const MbedTlsSourceException('Invalid source cache completion marker');
    final source = Directory.fromUri(completed.uri.resolve('source/'));
    await _verifyTree(source, manifest.finalFiles);
    return source.uri;
  }
  final archiveFile = File.fromUri(cache.uri.resolve('${manifest.archiveKey}.tar.gz'));
  final archiveType = await FileSystemEntity.type(archiveFile.path, followLinks: false);
  Uint8List bytes;
  if (archiveType == FileSystemEntityType.notFound) {
    if (offline) {
      throw const MbedTlsSourceException('Offline cache miss. Run dart tool/prefetch.dart with this cache directory while online first.');
    }
    bytes = await _download(manifest.archive);
  } else {
    bytes = await _readFile(archiveFile, _maxArchiveBytes);
  }
  final staging = await cache.createTemp('.staging-');
  try {
    final source = Directory.fromUri(staging.uri.resolve('source/'));
    await source.create();
    await _extract(bytes, source, manifest.files);
    // GitHub may repackage the same commit. Trust selected file bytes, not
    // gzip/tar metadata, and publish the archive only after every file matches.
    if (archiveType == FileSystemEntityType.notFound) {
      final download = File.fromUri(staging.uri.resolve('archive'));
      await download.writeAsBytes(bytes, flush: true);
      await download.rename(archiveFile.path);
    }
    for (final patch in manifest.patches) {
      final originals = <String, List<int>>{};
      for (final path in patch.files.keys) {
        originals[path] = await _readFile(File.fromUri(source.uri.resolve(path)), _maxFileBytes);
      }
      final Map<String, List<int>> changed;
      try {
        changed = applySourcePatch(utf8.decode(patch.bytes), originals);
      } on FormatException catch (error) {
        throw MbedTlsSourceException('Cannot apply ${patch.path}: ${error.message}');
      }
      for (final entry in changed.entries) {
        _checkHash(entry.value, patch.files[entry.key]!, 'patched ${entry.key}');
        await File.fromUri(source.uri.resolve(entry.key)).writeAsBytes(entry.value);
      }
    }
    await _verifyTree(source, manifest.finalFiles);
    await File.fromUri(staging.uri.resolve('complete')).writeAsString('${manifest.key}\n', flush: true);
    await staging.rename(completed.path);
    return completed.uri.resolve('source/');
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

Future<Uint8List> _download(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..findProxy = HttpClient.findProxyFromEnvironment;
  client.autoUncompress = false;
  try {
    return await (() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) throw MbedTlsSourceException('Archive download returned HTTP ${response.statusCode}');
      if (response.contentLength > _maxArchiveBytes) throw const MbedTlsSourceException('Archive exceeds download limit');
      return _readStream(response, _maxArchiveBytes, 'Archive download');
    })().timeout(_downloadTimeout);
  } on TimeoutException {
    throw const MbedTlsSourceException('Archive download timed out; prefetch the source cache before building offline');
  } on SocketException {
    throw const MbedTlsSourceException('Could not download the pinned archive; check network access or prefetch the source cache');
  } on HttpException {
    throw const MbedTlsSourceException('Pinned archive download failed');
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> _readStream(Stream<List<int>> stream, int limit, String label) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > limit) throw MbedTlsSourceException('$label exceeds its byte limit');
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

Future<void> _extract(Uint8List compressed, Directory source, Map<String, String> expected) async {
  final Uint8List expanded;
  try {
    expanded = await _readStream(gzip.decoder.bind(Stream.value(compressed)), _maxExpandedBytes, 'Expanded archive');
  } on FormatException {
    throw const MbedTlsSourceException('Invalid gzip archive');
  }
  final decoder = TarDecoder();
  final found = <String, Uint8List>{};
  final names = <String>{};
  String? root;
  try {
    decoder.decodeBytes(
      expanded,
      verify: true,
      callback: (entry) {
        final name = entry.name.endsWith('/') ? entry.name.substring(0, entry.name.length - 1) : entry.name;
        _safePath(name);
        if (!names.add(name.toLowerCase()) || names.length > 10000) {
          throw const MbedTlsSourceException('Duplicate, case-colliding, or excessive archive entries');
        }
        final parts = name.split('/');
        root ??= parts.first;
        if (parts.first != root) throw const MbedTlsSourceException('Archive has multiple source roots');
        final type = decoder.files.last.typeFlag;
        if (entry.isSymbolicLink || (type != '0' && type != '' && type != '5')) {
          throw const MbedTlsSourceException('Archive links and special files are not allowed');
        }
        if (parts.length == 1) {
          if (!entry.isDirectory) throw const MbedTlsSourceException('Archive root is not a directory');
          return;
        }
        final relative = parts.skip(1).join('/');
        if (!expected.containsKey(relative)) return;
        if (!entry.isFile || entry.size > _maxFileBytes) throw MbedTlsSourceException('Invalid source entry: $relative');
        final content = entry.content;
        _checkHash(content, expected[relative]!, relative);
        found[relative] = content;
      },
    );
  } on FormatException {
    throw const MbedTlsSourceException('Invalid tar archive');
  }
  if (found.length != expected.length) throw const MbedTlsSourceException('Archive is missing allowlisted source files');
  for (final entry in found.entries) {
    final file = File.fromUri(source.uri.resolve(entry.key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value);
  }
}

Future<void> _verifyTree(Directory source, Map<String, String> expected) async {
  await _requireDirectory(source);
  final directories = <String>{};
  for (final path in expected.keys) {
    var parent = path;
    while (parent.contains('/')) {
      parent = parent.substring(0, parent.lastIndexOf('/'));
      directories.add(parent);
    }
  }
  final seen = <String>{};
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(source.path.length + (source.path.endsWith(Platform.pathSeparator) ? 0 : 1)).replaceAll(Platform.pathSeparator, '/');
    if (entity is Directory && directories.contains(relative)) continue;
    if (entity is! File || !expected.containsKey(relative) || !seen.add(relative)) {
      throw MbedTlsSourceException('Unexpected source cache entry: $relative; remove this cache entry and retry');
    }
    _checkHash(await _readFile(entity, _maxFileBytes), expected[relative]!, 'cached $relative');
  }
  if (seen.length != expected.length) throw const MbedTlsSourceException('Source cache is incomplete; remove this cache entry and retry');
}

Future<void> _requireDirectory(Directory directory) async {
  if (await FileSystemEntity.type(directory.path, followLinks: false) != FileSystemEntityType.directory) {
    throw const MbedTlsSourceException('Source cache directory is missing or is a link');
  }
}

Future<Uint8List> _readFile(File file, int limit) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
    throw MbedTlsSourceException('Missing or non-regular file: ${file.path}');
  }
  if (await file.length() > limit) throw MbedTlsSourceException('File exceeds its byte limit: ${file.path}');
  return _readStream(file.openRead(), limit, 'File');
}

void _checkHash(List<int> bytes, String expected, String label) {
  if (sha256.convert(bytes).toString() != expected) throw MbedTlsSourceException('SHA-256 mismatch: $label');
}

void _safePath(String path) {
  final parts = path.split('/');
  if (path.length > 512 ||
      parts.any(
        (part) =>
            part.isEmpty ||
            part == '.' ||
            part == '..' ||
            !RegExp(r'^[a-zA-Z0-9_.+-]+$').hasMatch(part) ||
            part.endsWith('.') ||
            RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', caseSensitive: false).hasMatch(part),
      )) {
    throw MbedTlsSourceException('Unsafe source path: $path');
  }
}

Map<String, String> _hashMap(Object? value) {
  if (value is! Map<String, Object?> || value.isEmpty || value.length > 4096) throw const MbedTlsSourceException('Invalid source hash inventory');
  final result = <String, String>{};
  final folded = <String>{};
  for (final entry in value.entries) {
    if (entry.value is! String) throw const MbedTlsSourceException('Invalid source hash entry');
    final path = entry.key;
    _safePath(path);
    if (path != 'LICENSE' && path != 'README.md' && !path.startsWith('include/') && !path.startsWith('library/')) {
      throw MbedTlsSourceException('Source path is outside the allowlist: $path');
    }
    if (!folded.add(path.toLowerCase()) || !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.value as String)) {
      throw const MbedTlsSourceException('Invalid hash or case-colliding source path');
    }
    result[path] = entry.value as String;
  }
  return result;
}

class _Patch {
  final String path;
  final Uint8List bytes;
  final Map<String, String> files;
  _Patch(this.path, this.bytes, this.files);
}

class _Manifest {
  final Uri archive;
  final String archiveKey;
  final Map<String, String> files;
  final List<_Patch> patches;
  final String key;
  _Manifest(this.archive, this.archiveKey, this.files, this.patches, this.key);
  Map<String, String> get finalFiles => {...files, for (final patch in patches) ...patch.files};

  static Future<_Manifest> read(Uri packageRoot) async {
    final bytes = await _readFile(File.fromUri(packageRoot.resolve('UPSTREAM.json')), _maxMetadataBytes);
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const MbedTlsSourceException('Invalid UPSTREAM.json');
    }
    if (data is! Map<String, Object?> || data['archive'] is! String || data['patches'] is! List<Object?>) {
      throw const MbedTlsSourceException('Invalid upstream manifest');
    }
    final archive = Uri.tryParse(data['archive'] as String);
    if (archive == null ||
        archive.host.isEmpty ||
        archive.userInfo.isNotEmpty ||
        archive.hasFragment ||
        (archive.scheme != 'https' && !(archive.scheme == 'http' && (archive.host == '127.0.0.1' || archive.host == '::1')))) {
      throw const MbedTlsSourceException('Archive URL must use HTTPS (HTTP is allowed only for loopback tests)');
    }
    final files = _hashMap(data['files']);
    final archiveKey = sha256.convert(utf8.encode(jsonEncode([archive.toString(), files]))).toString();
    final patches = <_Patch>[];
    final keyBytes = BytesBuilder()
      ..add(utf8.encode('$_cacheFormat\n'))
      ..add(bytes);
    final patchEntries = data['patches'] as List<Object?>;
    if (patchEntries.length > 64) throw const MbedTlsSourceException('Too many source patches');
    for (final item in patchEntries) {
      if (item is! Map<String, Object?> || item['file'] is! String || item['sha256'] is! String) throw const MbedTlsSourceException('Invalid patch manifest');
      final path = item['file'] as String;
      _safePath(path);
      if (!path.startsWith('patches/')) throw const MbedTlsSourceException('Patch is outside patches/');
      final patch = await _readFile(File.fromUri(packageRoot.resolve(path)), _maxMetadataBytes);
      _checkHash(patch, item['sha256'] as String, path);
      final changed = _hashMap(item['modified_files']);
      if (changed.keys.any((path) => !files.containsKey(path))) throw const MbedTlsSourceException('Patch modifies a non-allowlisted file');
      patches.add(_Patch(path, patch, changed));
      keyBytes.add(patch);
    }
    return _Manifest(archive, archiveKey, files, patches, sha256.convert(keyBytes.takeBytes()).toString());
  }
}
