// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hook/src/source_cache.dart';

const _original = 'one\ntwo\nthree\n';
const _patched = 'one\nchanged\nthree\n';
const _patch = '''--- a/library/example.c
+++ b/library/example.c
@@ -1,3 +1,3 @@
 one
-two
+changed
 three
''';

void main() {
  late _Fixture fixture;
  setUp(() async {
    fixture = await _Fixture.create();
  });
  tearDown(() => fixture.dispose());

  test('downloads once, patches verified sources, and reuses them offline', () async {
    final source = await fixture.prepare();
    expect(await File.fromUri(source.resolve('library/example.c')).readAsString(), _patched);
    expect(await File.fromUri(source.resolve('include/example.h')).readAsString(), 'header\n');
    expect(await File.fromUri(source.resolve('tests/not-selected.c')).exists(), isFalse);
    expect(await fixture.prepare(offline: true), source);
    expect(fixture.requests, 1);
  });

  test('offline reconstructs from the verified archive when extracted source is absent', () async {
    final source = await fixture.prepare();
    await Directory.fromUri(source.resolve('../')).delete(recursive: true);
    final restored = await fixture.prepare(offline: true);
    expect(restored, source);
    expect(await File.fromUri(restored.resolve('library/example.c')).readAsString(), _patched);
    expect(fixture.requests, 1);
  });

  test('offline cold cache fails without making an HTTP request', () async {
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('Offline cache miss')));
    expect(fixture.requests, 0);
  });

  test('invalid gzip is rejected before source or archive publication', () async {
    fixture.responseBytes = utf8.encode('not the pinned archive');
    await expectLater(fixture.prepare(), throwsA(_errorContaining('Invalid gzip archive')));
    expect(await fixture.completedEntries(), isEmpty);
    expect(fixture.cache.listSync().whereType<File>().where((file) => file.path.endsWith('.tar.gz')), isEmpty);
  });

  test('archive packaging may change while selected source remains pinned', () async {
    // GitHub can change root names, entry ordering and unselected contents.
    // None of those bytes are compiled or belong to the integrity contract.
    final originalManifest = await File.fromUri(fixture.package.uri.resolve('UPSTREAM.json')).readAsString();
    await fixture.setArchive([
      ArchiveFile.string('different-root/tests/not-selected.c', 'different unselected contents\n'),
      ArchiveFile.string('different-root/library/example.c', _original),
      ArchiveFile.string('different-root/include/example.h', 'header\n'),
    ]);
    expect(await File.fromUri(fixture.package.uri.resolve('UPSTREAM.json')).readAsString(), originalManifest);
    final source = await fixture.prepare();
    expect(await File.fromUri(source.resolve('library/example.c')).readAsString(), _patched);
  });

  test('a missing allowlisted file cannot be published', () async {
    await fixture.setArchive([ArchiveFile.string('upstream/include/example.h', 'header\n')]);
    await expectLater(fixture.prepare(), throwsA(_errorContaining('missing allowlisted')));
    expect(await fixture.completedEntries(), isEmpty);
  });

  test('a changed selected file fails its pinned hash before archive publication', () async {
    await fixture.setArchive([ArchiveFile.string('upstream/include/example.h', 'wrong header'), ArchiveFile.string('upstream/library/example.c', _original)]);
    await expectLater(fixture.prepare(), throwsA(_errorContaining('SHA-256 mismatch: include/example.h')));
    expect(await fixture.completedEntries(), isEmpty);
    expect(fixture.cache.listSync().whereType<File>().where((file) => file.path.endsWith('.tar.gz')), isEmpty);
  });

  for (final name in ['upstream/../escape.c', '/absolute.c', 'upstream/library/CON.c', r'upstream\library\escape.c']) {
    test('rejects unsafe archive path $name, even outside the allowlist', () async {
      await fixture.setArchive([...fixture.standardFiles(), ArchiveFile.string(name, 'unsafe')]);
      await expectLater(fixture.prepare(), throwsA(_errorContaining('Unsafe source path')));
      expect(await fixture.completedEntries(), isEmpty);
    });
  }

  test('rejects case collisions on every platform', () async {
    await fixture.setArchive([...fixture.standardFiles(), ArchiveFile.string('upstream/INCLUDE/EXAMPLE.H', 'header\n')]);
    await expectLater(fixture.prepare(), throwsA(_errorContaining('case-colliding')));
  });

  test('rejects archive symlinks instead of following them', () async {
    await fixture.setArchive([...fixture.standardFiles(), ArchiveFile.symlink('upstream/link', '../outside')]);
    await expectLater(fixture.prepare(), throwsA(_errorContaining('links and special files')));
  });

  test('rejects tampered patch bytes even with a warm source cache', () async {
    await fixture.prepare();
    await fixture.patchFile.writeAsString('tampered');
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('SHA-256 mismatch: patches/change.patch')));
    expect(fixture.requests, 1);
  });

  test('strict patch application rejects wrong context without publishing', () async {
    await fixture.setPatch(_patch.replaceFirst('-two', '-different'), _patched);
    await expectLater(fixture.prepare(), throwsA(_errorContaining('Patch source context does not match')));
    expect(await fixture.completedEntries(), isEmpty);
  });

  test('patched output must match the separately pinned final hash', () async {
    await fixture.setPatch(_patch, 'different output\n');
    await expectLater(fixture.prepare(), throwsA(_errorContaining('SHA-256 mismatch: patched library/example.c')));
  });

  test('patch and manifest changes select a different completed source entry', () async {
    final before = await fixture.prepare();
    await fixture.setPatch(_patch.replaceFirst('+changed', '+updated'), 'one\nupdated\nthree\n');
    final after = await fixture.prepare(offline: true);
    expect(after, isNot(before));
    expect(await File.fromUri(after.resolve('library/example.c')).readAsString(), 'one\nupdated\nthree\n');
    expect(await File.fromUri(before.resolve('library/example.c')).readAsString(), _patched);
    expect(fixture.requests, 1);
  });

  test('rehashes a warm tree and rejects modified source', () async {
    final source = await fixture.prepare();
    await File.fromUri(source.resolve('library/example.c')).writeAsString('tampered');
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('SHA-256 mismatch: cached library/example.c')));
  });

  test('rejects missing and extra files in a completed tree', () async {
    final source = await fixture.prepare();
    final header = File.fromUri(source.resolve('include/example.h'));
    await header.delete();
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('incomplete')));
    await header.writeAsString('header\n');
    await File.fromUri(source.resolve('library/injected.c')).writeAsString('unexpected');
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('Unexpected source cache entry')));
  });

  test(
    'rejects a cached symlink even when its target has the right bytes',
    () async {
      final source = await fixture.prepare();
      final header = File.fromUri(source.resolve('include/example.h'));
      final target = File.fromUri(fixture.root.uri.resolve('outside.h'));
      await target.writeAsString('header\n');
      await header.delete();
      await Link(header.path).create(target.path);
      await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('Unexpected source cache entry')));
    },
    skip: Platform.isWindows ? 'Creating symlinks requires Windows developer mode or elevated privileges' : false,
  );

  test('validates selected files again during offline archive reconstruction', () async {
    final source = await fixture.prepare();
    await Directory.fromUri(source.resolve('../')).delete(recursive: true);
    final archive = fixture.cache.listSync().whereType<File>().singleWhere((file) => file.path.endsWith('.tar.gz'));
    await fixture.setArchive([ArchiveFile.string('upstream/include/example.h', 'tampered'), ArchiveFile.string('upstream/library/example.c', _original)]);
    await archive.writeAsBytes(fixture.responseBytes);
    await expectLater(fixture.prepare(offline: true), throwsA(_errorContaining('SHA-256 mismatch: include/example.h')));
  });

  test('cleans abandoned staging directories while preserving verified entries', () async {
    final source = await fixture.prepare();
    final abandoned = await Directory.fromUri(fixture.cache.uri.resolve('.staging-abandoned/')).create();
    await File.fromUri(abandoned.uri.resolve('partial.tar')).writeAsString('partial download');
    final unrelated = await Directory.fromUri(fixture.cache.uri.resolve('unrelated/')).create();
    expect(await fixture.prepare(offline: true), source);
    expect(await abandoned.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    expect(await Directory.fromUri(source).exists(), isTrue);
  });

  test('concurrent calls publish only one verified source tree', () async {
    final sources = await Future.wait(List.generate(4, (_) => fixture.prepare()));
    expect(sources.toSet(), hasLength(1));
    expect(fixture.requests, 1);
    expect(await fixture.completedEntries(), hasLength(1));
  });

  test('separate Dart processes share one locked download and atomic publication', () async {
    final packageConfig = File('.dart_tool/package_config.json').absolute;
    expect(await packageConfig.exists(), isTrue, reason: 'Run pub get before the source-cache process test');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final dart = flutterRoot == null ? 'dart' : '$flutterRoot/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
    final worker = File('test/support/source_cache_worker.dart').absolute;
    final ready = [Completer<void>(), Completer<void>()];
    final processes = <Process>[];
    final outputs = <Future<String>>[];
    final errors = <Future<String>>[];
    for (var i = 0; i < 2; i++) {
      final process = await Process.start(dart, [
        '--packages=${packageConfig.path}',
        worker.path,
        fixture.package.uri.toString(),
        fixture.cache.uri.toString(),
      ]);
      processes.add(process);
      addTearDown(() {
        process.kill();
      });
      errors.add(utf8.decoder.bind(process.stderr).join());
      outputs.add(
        utf8.decoder
            .bind(process.stdout)
            .transform(const LineSplitter())
            .map((line) {
              if (line == 'ready') ready[i].complete();
              return line;
            })
            .join('\n'),
      );
    }
    await Future.wait(ready.map((signal) => signal.future)).timeout(const Duration(seconds: 30));
    for (final process in processes) {
      process.stdin.writeln('go');
      await process.stdin.flush();
    }
    final exits = await Future.wait(processes.map((process) => process.exitCode)).timeout(const Duration(seconds: 30));
    final stderr = await Future.wait(errors);
    expect(exits, [0, 0], reason: stderr.join('\n'));
    final stdout = await Future.wait(outputs);
    expect(stdout[0], stdout[1]);
    expect(fixture.requests, 1);
    expect(await fixture.completedEntries(), hasLength(1));
  });
}

Matcher _errorContaining(String message) => isA<MbedTlsSourceException>().having((error) => error.message, 'message', contains(message));

class _Fixture {
  final Directory root;
  final Directory package;
  final Directory cache;
  final HttpServer server;
  final Map<String, dynamic> manifest = {};
  late List<int> responseBytes;
  int requests = 0;
  _Fixture(this.root, this.package, this.cache, this.server);
  File get patchFile => File.fromUri(package.uri.resolve('patches/change.patch'));

  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('halo-tls-source-test-');
    final package = await Directory.fromUri(root.uri.resolve('package/')).create();
    final cache = Directory.fromUri(root.uri.resolve('cache/'));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Fixture(root, package, cache, server);
    server.listen((request) async {
      fixture.requests++;
      request.response.add(fixture.responseBytes);
      await request.response.close();
    });
    fixture.manifest.addAll({
      'archive': 'http://127.0.0.1:${server.port}/source.tar.gz',
      'files': {'include/example.h': _hash('header\n'), 'library/example.c': _hash(_original)},
      'patches': <Object>[],
    });
    await fixture.setArchive(fixture.standardFiles());
    await fixture.setPatch(_patch, _patched);
    return fixture;
  }

  List<ArchiveFile> standardFiles() => [
    ArchiveFile.directory('upstream/'),
    ArchiveFile.string('upstream/include/example.h', 'header\n'),
    ArchiveFile.string('upstream/library/example.c', _original),
    ArchiveFile.string('upstream/tests/not-selected.c', 'not compiled\n'),
  ];

  Future<void> setArchive(List<ArchiveFile> files) async {
    final archive = Archive();
    for (final file in files) {
      archive.add(file);
    }
    responseBytes = gzip.encode(TarEncoder().encodeBytes(archive));
    await saveManifest();
  }

  Future<void> setPatch(String patch, String result) async {
    await patchFile.parent.create(recursive: true);
    await patchFile.writeAsString(patch);
    manifest['patches'] = [
      {
        'file': 'patches/change.patch',
        'sha256': _hash(patch),
        'modified_files': {'library/example.c': _hash(result)},
      },
    ];
    await saveManifest();
  }

  Future<void> saveManifest() => File.fromUri(package.uri.resolve('UPSTREAM.json')).writeAsString(jsonEncode(manifest));
  Future<Uri> prepare({bool offline = false}) => prepareMbedTls(packageRoot: package.uri, cacheDirectory: cache.uri, offline: offline);
  Future<List<Directory>> completedEntries() async => await cache.exists()
      ? (await cache.list().toList()).whereType<Directory>().where((entry) => !entry.path.split(Platform.pathSeparator).last.startsWith('.')).toList()
      : [];
  Future<void> dispose() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  }

  static String _hash(String text) => sha256.convert(utf8.encode(text)).toString();
}
