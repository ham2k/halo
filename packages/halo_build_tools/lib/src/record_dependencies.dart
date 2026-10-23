// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const _maxArchiveBytes = 32 * 1024 * 1024;
const _maxExpandedBytes = 128 * 1024 * 1024;
const _maxFileBytes = 16 * 1024 * 1024;
const _maxMetadataBytes = 2 * 1024 * 1024;
const _buildDirectories = {'.dart_tool', 'build', '.gradle', '.cxx', '.build', '.swiftpm'};
final _pendingLocks = <String, Future<void>>{};

class RecordDependencyException implements Exception {
  final String message;
  const RecordDependencyException(this.message);

  @override
  String toString() => 'Record dependencies: $message';
}

/// Archives are shared, but every checkout owns its generated plugin sources.
Directory defaultRecordCacheDirectory({String? operatingSystem, Map<String, String>? environment}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final env = environment ?? Platform.environment;
  final override = env['HALO_RECORD_CACHE'];
  if (override != null && override.isNotEmpty) return Directory(override).absolute;
  final home = env[os == 'windows' ? 'USERPROFILE' : 'HOME'];
  final base = switch (os) {
    'windows' => env['LOCALAPPDATA'] ?? (home == null ? null : '$home/AppData/Local'),
    'macos' => home == null ? null : '$home/Library/Caches',
    _ => env['XDG_CACHE_HOME'] ?? (home == null ? null : '$home/.cache'),
  };
  if (base == null || base.isEmpty) {
    throw const RecordDependencyException('Cannot locate the user cache; set HALO_RECORD_CACHE to an absolute directory.');
  }
  return Directory.fromUri(Uri.directory(base, windows: os == 'windows').resolve('ham2k/record/'));
}

/// Completes path dependencies whose tracked scaffolds allow Flutter discovery.
/// Every source cache hit is rehashed. Build outputs are retained when sources
/// match; generated source drift triggers replacement. Tracked scaffold edits
/// are refused and their checkout line endings are preserved.
Future<void> prepareRecordDependencies({
  required Directory repositoryRoot,
  Directory? cacheDirectory,
  bool offline = false,
  bool prefetchOnly = false,
  void Function(String)? log,
}) async {
  final root = Directory(await repositoryRoot.resolveSymbolicLinks());
  final manifest = await _readManifest(root);
  final requestedCache = cacheDirectory ?? defaultRecordCacheDirectory();
  await requestedCache.create(recursive: true);
  final cache = Directory(await requestedCache.resolveSymbolicLinks());
  final localLock = File.fromUri(root.uri.resolve('.dart_tool/record_dependencies.lock'));
  await _withLock(localLock, () async {
    await _withLock(File.fromUri(cache.uri.resolve('.lock')), () async {
      final scaffoldSources = <_Package, Map<String, Uint8List>>{};
      for (final package in manifest) {
        scaffoldSources[package] = await _readScaffolds(package, Directory.fromUri(root.uri.resolve('packages/${package.name}_patched/')));
      }
      for (final package in manifest) {
        final destination = Directory.fromUri(root.uri.resolve('packages/${package.name}_patched/'));
        if (!prefetchOnly && await _matchesTree(destination, package.files, scaffolds: package.scaffolds)) continue;
        final bytes = await _archiveBytes(package, cache, offline, log);
        if (!prefetchOnly) {
          log?.call('Preparing ${package.name} ${package.version}');
          await _materialize(package, bytes, destination, scaffoldSources[package]!);
        }
      }
    });
  });
}

Future<T> _withLock<T>(File file, Future<T> Function() action) async {
  // POSIX locks are process scoped, so also serialize calls in this isolate.
  final previous = _pendingLocks[file.path] ?? Future<void>.value();
  final released = Completer<void>();
  _pendingLocks[file.path] = released.future;
  await previous;
  RandomAccessFile? handle;
  var locked = false;
  try {
    await file.parent.create(recursive: true);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file) {
      throw RecordDependencyException('Lock is not a regular file: ${file.path}');
    }
    handle = await file.open(mode: FileMode.append);
    final elapsed = Stopwatch()..start();
    while (!locked) {
      try {
        await handle.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        if (elapsed.elapsed > const Duration(minutes: 5)) {
          throw RecordDependencyException('Timed out waiting for ${file.path}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return await action();
  } finally {
    try {
      if (locked) await handle!.unlock();
    } finally {
      try {
        await handle?.close();
      } finally {
        released.complete();
        if (identical(_pendingLocks[file.path], released.future)) unawaited(_pendingLocks.remove(file.path));
      }
    }
  }
}

Future<Uint8List> _archiveBytes(_Package package, Directory cache, bool offline, void Function(String)? log) async {
  final file = File.fromUri(cache.uri.resolve('${package.archiveHash}.tar.gz'));
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type == FileSystemEntityType.file) {
    if (await file.length() <= _maxArchiveBytes) {
      final bytes = await _readFile(file, _maxArchiveBytes);
      if (_hash(bytes) == package.archiveHash) return bytes;
    }
  } else if (type != FileSystemEntityType.notFound) {
    throw RecordDependencyException('Archive cache entry is not a regular file: ${file.path}');
  }
  if (offline) {
    throw RecordDependencyException('Offline archive cache is missing or corrupt for ${package.name}. Run prepare_record.dart --prefetch while online.');
  }
  log?.call('Downloading ${package.name} ${package.version}');
  final bytes = await _download(package.url);
  if (_hash(bytes) != package.archiveHash) {
    throw RecordDependencyException('Archive SHA-256 mismatch for ${package.name}; no sources were published.');
  }
  final staging = await cache.createTemp('.download-');
  try {
    final temporary = File.fromUri(staging.uri.resolve('archive.tar.gz'));
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  } finally {
    await staging.delete(recursive: true);
  }
  return bytes;
}

Future<Uint8List> _download(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..autoUncompress = false
    ..findProxy = (url) => url.host == '127.0.0.1' || url.host == '::1' ? 'DIRECT' : HttpClient.findProxyFromEnvironment(url);
  try {
    return await (() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) throw RecordDependencyException('Archive download returned HTTP ${response.statusCode}: $uri');
      if (response.contentLength > _maxArchiveBytes) throw const RecordDependencyException('Archive exceeds download limit.');
      return _readStream(response, _maxArchiveBytes);
    })().timeout(const Duration(minutes: 2));
  } on TimeoutException {
    throw const RecordDependencyException('Archive download timed out; prefetch dependencies before building offline.');
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Uint8List>> _readScaffolds(_Package package, Directory directory) async {
  final result = <String, Uint8List>{};
  for (final path in package.scaffolds) {
    final file = File.fromUri(directory.uri.resolve(path));
    Uint8List bytes;
    try {
      bytes = await _readFile(file, _maxFileBytes);
      if (_hash(_normalize(bytes)) != package.files[path]) throw const FormatException('Scaffold hash mismatch');
    } on Object {
      throw RecordDependencyException(
        'Tracked scaffold is missing, edited, or not a regular file: ${file.path}. '
        'Preserve your edits and restore the tracked file, or update its hash in dependencies/record/UPSTREAM.json.',
      );
    }
    result[path] = bytes;
  }
  return result;
}

Future<void> _checkScaffoldsUnchanged(_Package package, Directory directory, Map<String, Uint8List> expected) async {
  final current = await _readScaffolds(package, directory);
  for (final path in package.scaffolds) {
    if (_hash(current[path]!) != _hash(expected[path]!)) {
      throw RecordDependencyException('Tracked scaffold changed during preparation: ${File.fromUri(directory.uri.resolve(path)).path}. Retry preparation.');
    }
  }
}

Future<void> _materialize(_Package package, Uint8List bytes, Directory destination, Map<String, Uint8List> scaffolds) async {
  await destination.parent.create(recursive: true);
  final staging = await destination.parent.createTemp('.${package.name}-');
  final source = Directory.fromUri(staging.uri.resolve('source/'));
  final backup = Directory.fromUri(staging.uri.resolve('previous/'));
  var retainStaging = false;
  await source.create();
  try {
    await _extract(bytes, source, package.files.keys.toSet().difference(package.scaffolds));
    if (package.patch != null && package.patch!.isNotEmpty) {
      final patch = File.fromUri(staging.uri.resolve('changes.patch'));
      await patch.writeAsBytes(package.patch!);
      // An isolated repository avoids parent-worktree prefix/config semantics.
      await _git(source, ['init', '--quiet']);
      await _git(source, ['-c', 'core.autocrlf=false', 'apply', '--check', '--whitespace=nowarn', patch.path]);
      await _git(source, ['-c', 'core.autocrlf=false', 'apply', '--whitespace=nowarn', patch.path]);
      await Directory.fromUri(source.uri.resolve('.git/')).delete(recursive: true);
    }
    for (final entry in package.overlays.entries) {
      final file = File.fromUri(source.uri.resolve(entry.key));
      if (await file.exists()) throw RecordDependencyException('Overlay replaces upstream source instead of patching it: ${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
    }
    for (final entry in scaffolds.entries) {
      final file = File.fromUri(source.uri.resolve(entry.key));
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.notFound) {
        throw RecordDependencyException('Patch or overlay replaces a tracked scaffold: ${entry.key}');
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
    }
    if (!await _matchesTree(source, package.files, scaffolds: package.scaffolds, allowBuildOutputs: false)) {
      throw RecordDependencyException('Final source hashes do not match ${package.name}; check its patch and overlay manifest.');
    }
    final type = await FileSystemEntity.type(destination.path, followLinks: false);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.directory) {
      throw RecordDependencyException('Generated destination is not a directory: ${destination.path}');
    }
    await _checkScaffoldsUnchanged(package, destination, scaffolds);
    if (type == FileSystemEntityType.directory) await destination.rename(backup.path);
    try {
      // Check the renamed original too, so edits during staging remain intact.
      if (await backup.exists()) await _checkScaffoldsUnchanged(package, backup, scaffolds);
      await source.rename(destination.path);
    } catch (publishError) {
      if (await backup.exists()) {
        try {
          await backup.rename(destination.path);
        } catch (restoreError) {
          retainStaging = true;
          throw RecordDependencyException(
            'Cannot publish ${package.name} or restore its previous directory. Previous sources are retained at ${backup.path}. '
            'Publish error: $publishError; restore error: $restoreError',
          );
        }
      }
      rethrow;
    }
  } finally {
    if (!retainStaging) await staging.delete(recursive: true);
  }
}

Future<void> _git(Directory directory, List<String> arguments) async {
  final environment = Map<String, String>.of(Platform.environment)
    ..remove('GIT_DIR')
    ..remove('GIT_WORK_TREE')
    ..remove('GIT_INDEX_FILE')
    ..['GIT_CONFIG_NOSYSTEM'] = '1'
    ..['GIT_CONFIG_GLOBAL'] = Platform.isWindows ? 'NUL' : '/dev/null';
  final result = await Process.run(
    'git',
    [
      if (Platform.isWindows) ...['-c', 'core.longpaths=true'],
      ...arguments,
    ],
    workingDirectory: directory.path,
    environment: environment,
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) throw RecordDependencyException('Cannot apply pinned source patch: ${result.stderr}');
}

Future<void> _extract(Uint8List compressed, Directory source, Set<String> wanted) async {
  final expanded = await _readStream(gzip.decoder.bind(Stream.value(compressed)), _maxExpandedBytes);
  final decoder = TarDecoder();
  final found = <String, Uint8List>{};
  final seen = <String>{};
  decoder.decodeBytes(
    expanded,
    verify: true,
    callback: (entry) {
      final name = entry.name.endsWith('/') ? entry.name.substring(0, entry.name.length - 1) : entry.name;
      _safePath(name);
      if (!seen.add(name.toLowerCase()) || seen.length > 10000) throw const RecordDependencyException('Duplicate or excessive archive paths.');
      final type = decoder.files.last.typeFlag;
      if (entry.isSymbolicLink || (type != '0' && type != '' && type != '5')) {
        throw const RecordDependencyException('Archive links and special files are not supported.');
      }
      if (!wanted.contains(name)) return;
      if (!entry.isFile || entry.size > _maxFileBytes) throw RecordDependencyException('Invalid archive source: $name');
      found[name] = _normalize(entry.content);
    },
  );
  for (final entry in found.entries) {
    final file = File.fromUri(source.uri.resolve(entry.key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value);
  }
}

Future<bool> _matchesTree(Directory source, Map<String, String> files, {Set<String> scaffolds = const {}, bool allowBuildOutputs = true}) async {
  if (await FileSystemEntity.type(source.path, followLinks: false) != FileSystemEntityType.directory) return false;
  final expectedDirectories = <String>{};
  for (final path in files.keys) {
    final parts = path.split('/');
    for (var i = 1; i < parts.length; i++) {
      expectedDirectories.add(parts.take(i).join('/'));
    }
  }
  final seen = <String>{};
  Future<bool> visit(Directory directory, String prefix) async {
    await for (final entity in directory.list(followLinks: false)) {
      final name = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
      final relative = '$prefix$name';
      if (entity is Directory) {
        if (allowBuildOutputs && _buildDirectories.contains(name)) continue;
        if (!expectedDirectories.contains(relative) || !await visit(entity, '$relative/')) return false;
      } else if (entity is File) {
        if (allowBuildOutputs && name == 'pubspec.lock' && !files.containsKey(relative)) continue;
        if (!files.containsKey(relative)) return false;
        final bytes = await _readFile(entity, _maxFileBytes);
        if (_hash(scaffolds.contains(relative) ? _normalize(bytes) : bytes) != files[relative]) return false;
        seen.add(relative);
      } else {
        return false;
      }
    }
    return true;
  }

  try {
    return await visit(source, '') && seen.length == files.length;
  } on FileSystemException {
    return false;
  } on RecordDependencyException {
    return false;
  }
}

class _Package {
  final String name;
  final String version;
  final Uri url;
  final String archiveHash;
  final Uint8List? patch;
  final Map<String, Uint8List> overlays;
  final Map<String, String> files;
  final Set<String> scaffolds;

  _Package(this.name, this.version, this.url, this.archiveHash, this.patch, this.overlays, this.files, this.scaffolds);
}

Future<List<_Package>> _readManifest(Directory root) async {
  final directory = Directory.fromUri(root.uri.resolve('dependencies/record/'));
  final Object? data = jsonDecode(utf8.decode(await _readFile(File.fromUri(directory.uri.resolve('UPSTREAM.json')), _maxMetadataBytes)));
  if (data is! Map<String, Object?> || data['schemaVersion'] != 1 || data['packages'] is! List<Object?>) {
    throw const RecordDependencyException('Invalid record UPSTREAM.json schema.');
  }
  final result = <_Package>[];
  final names = <String>{};
  for (final raw in data['packages'] as List<Object?>) {
    if (raw is! Map<String, Object?> || raw['name'] is! String || raw['version'] is! String || raw['url'] is! String || raw['sha256'] is! String) {
      throw const RecordDependencyException('Invalid record package entry.');
    }
    final name = raw['name'] as String;
    if (!RegExp(r'^record_[a-z0-9_]+$').hasMatch(name) || !names.add(name)) throw const RecordDependencyException('Invalid or duplicate record package name.');
    final url = Uri.parse(raw['url'] as String);
    if (url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        (url.scheme != 'https' && !(url.scheme == 'http' && (url.host == '127.0.0.1' || url.host == '::1')))) {
      throw const RecordDependencyException('Archive URL must use HTTPS (HTTP is allowed only for loopback tests).');
    }
    final archiveHash = raw['sha256'] as String;
    _checkHashFormat(archiveHash);
    final hashes = raw['files'];
    if (hashes is! Map<String, Object?> || hashes.isEmpty || hashes.length > 4096) throw const RecordDependencyException('Invalid source hash inventory.');
    final files = <String, String>{};
    final folded = <String>{};
    for (final entry in hashes.entries) {
      _safePath(entry.key);
      if (entry.value is! String || !folded.add(entry.key.toLowerCase())) throw const RecordDependencyException('Invalid or case-colliding source hash entry.');
      _checkHashFormat(entry.value as String);
      files[entry.key] = entry.value as String;
    }
    final scaffolds = <String>{};
    if (raw['scaffolds'] != null) {
      final paths = raw['scaffolds'];
      if (paths is! List<Object?>) throw const RecordDependencyException('Invalid scaffold inventory.');
      for (final path in paths) {
        if (path is! String || !files.containsKey(path) || !scaffolds.add(path)) {
          throw const RecordDependencyException('Scaffold must be a unique path in the source hash inventory.');
        }
      }
    }
    Uint8List? patch;
    if (raw['patch'] != null) {
      final path = raw['patch'];
      if (path is! String) throw const RecordDependencyException('Invalid patch path.');
      _safePath(path);
      patch = _normalize(await _readFile(File.fromUri(directory.uri.resolve(path)), _maxMetadataBytes));
    }
    final overlays = <String, Uint8List>{};
    if (raw['overlay'] != null) {
      final path = raw['overlay'];
      if (path is! String) throw const RecordDependencyException('Invalid overlay path.');
      _safePath(path);
      final overlay = Directory.fromUri(directory.uri.resolve('$path/'));
      if (await FileSystemEntity.type(overlay.path, followLinks: false) != FileSystemEntityType.directory) {
        throw RecordDependencyException('Overlay directory is missing or not a directory: $path');
      }
      await for (final entity in overlay.list(recursive: true, followLinks: false)) {
        if (entity is Directory) continue;
        final relative = entity.path
            .substring(overlay.path.length + (overlay.path.endsWith(Platform.pathSeparator) ? 0 : 1))
            .replaceAll(Platform.pathSeparator, '/');
        if (entity is! File || !files.containsKey(relative) || scaffolds.contains(relative)) {
          throw RecordDependencyException('Unexpected overlay entry: $relative');
        }
        final bytes = _normalize(await _readFile(entity, _maxFileBytes));
        if (_hash(bytes) != files[relative]) throw RecordDependencyException('Overlay SHA-256 mismatch: $relative');
        overlays[relative] = bytes;
      }
    }
    result.add(_Package(name, raw['version'] as String, url, archiveHash, patch, overlays, files, scaffolds));
  }
  if (result.isEmpty) throw const RecordDependencyException('No record packages in manifest.');
  return result;
}

void _safePath(String path) {
  if (path.length > 512 ||
      path
          .split('/')
          .any(
            (part) =>
                part.isEmpty ||
                part == '.' ||
                part == '..' ||
                !RegExp(r'^[a-zA-Z0-9_.+-]+$').hasMatch(part) ||
                part.endsWith('.') ||
                RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', caseSensitive: false).hasMatch(part),
          )) {
    throw RecordDependencyException('Unsafe source path: $path');
  }
}

void _checkHashFormat(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) throw const RecordDependencyException('Invalid SHA-256 in manifest.');
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

Uint8List _normalize(List<int> bytes) => Uint8List.fromList(utf8.encode(utf8.decode(bytes).replaceAll('\r\n', '\n')));

Future<Uint8List> _readFile(File file, int limit) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file) {
    throw RecordDependencyException('Missing or non-regular file: ${file.path}');
  }
  if (await file.length() > limit) throw RecordDependencyException('File exceeds its byte limit: ${file.path}');
  return _readStream(file.openRead(), limit);
}

Future<Uint8List> _readStream(Stream<List<int>> stream, int limit) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > limit) throw const RecordDependencyException('Source data exceeds its byte limit.');
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
