// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:halo_build_tools/src/record_dependencies.dart';
import 'package:test/test.dart';

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

class _Fixture {
  final Directory temporary;
  final HttpServer server;
  late final repository = Directory('${temporary.path}/repository');
  late final cache = Directory('${temporary.path}/cache');
  late final archive = GZipEncoder().encode(
    TarEncoder().encode(
      Archive()
        ..add(ArchiveFile.string('pubspec.yaml', 'name: record_fixture\r\nversion: 1.2.3\r\n'))
        ..add(ArchiveFile.string('LICENSE', 'Upstream license\r\n'))
        ..add(ArchiveFile.string('lib/source.dart', "const input = 'upstream';\r\n"))
        ..add(ArchiveFile.string('example/main.dart', 'Unselected example source\n')),
    ),
  );
  late List<int> responseBytes = archive;
  int requests = 0;
  bool serverClosed = false;
  String patchedValue = 'verified';
  List<String> scaffoldPaths = const [];
  Future<void> Function()? onRequest;

  _Fixture(this.temporary, this.server);

  static Future<_Fixture> create() async {
    final temporary = await Directory.systemTemp.createTemp('halo-record-dependencies-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Fixture(temporary, server);
    server.listen((request) async {
      fixture.requests++;
      await fixture.onRequest?.call();
      request.response.add(fixture.responseBytes);
      await request.response.close();
    });
    await fixture.writeRecipe();
    return fixture;
  }

  Directory get generated => Directory('${repository.path}/packages/record_fixture_patched');
  File get cachedArchive => File('${cache.path}/${_hash(archive)}.tar.gz');
  File get patch => File('${repository.path}/dependencies/record/record_fixture.patch');
  File source(String path) => File('${generated.path}/$path');

  Map<String, String> get expected => {
    'pubspec.yaml': 'name: record_fixture\nversion: 1.2.3\n',
    'LICENSE': 'Upstream license\n',
    'lib/source.dart': "const input = '$patchedValue';\n",
    'lib/owned.dart': 'const owned = true;\n',
  };

  Future<void> writeRecipe({String value = 'verified', List<String>? scaffolds}) async {
    patchedValue = value;
    if (scaffolds != null) scaffoldPaths = scaffolds;
    await patch.parent.create(recursive: true);
    await patch.writeAsString('''
diff --git a/lib/source.dart b/lib/source.dart
--- a/lib/source.dart
+++ b/lib/source.dart
@@ -1 +1 @@
-const input = 'upstream';
+const input = '$value';
''');
    final overlay = File('${patch.parent.path}/overlays/record_fixture/lib/owned.dart');
    await overlay.parent.create(recursive: true);
    if (scaffoldPaths.contains('lib/owned.dart')) {
      if (await overlay.exists()) await overlay.delete();
    } else {
      await overlay.writeAsString('const owned = true;\r\n');
    }
    await File('${patch.parent.path}/UPSTREAM.json').writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'packages': [
          {
            'name': 'record_fixture',
            'version': '1.2.3',
            'url': 'http://127.0.0.1:${server.port}/archive.tar.gz',
            'sha256': _hash(archive),
            'patch': 'record_fixture.patch',
            'overlay': 'overlays/record_fixture',
            if (scaffoldPaths.isNotEmpty) 'scaffolds': scaffoldPaths,
            'files': {for (final entry in expected.entries) entry.key: _hash(utf8.encode(entry.value))},
          },
        ],
      }),
    );
  }

  Future<void> prepare({bool offline = false, bool prefetchOnly = false}) =>
      prepareRecordDependencies(repositoryRoot: repository, cacheDirectory: cache, offline: offline, prefetchOnly: prefetchOnly);

  Future<Map<String, List<int>>> writeScaffolds({bool crlf = false}) async {
    await writeRecipe(scaffolds: ['pubspec.yaml', 'lib/owned.dart']);
    final bytes = <String, List<int>>{};
    for (final path in scaffoldPaths) {
      final contents = expected[path]!;
      bytes[path] = utf8.encode(crlf ? contents.replaceAll('\n', '\r\n') : contents);
      await source(path).parent.create(recursive: true);
      await source(path).writeAsBytes(bytes[path]!);
    }
    return bytes;
  }

  Future<void> expectSources({Map<String, List<int>> scaffoldBytes = const {}}) async {
    for (final entry in expected.entries) {
      expect(await source(entry.key).readAsBytes(), scaffoldBytes[entry.key] ?? utf8.encode(entry.value), reason: entry.key);
    }
    expect(source('example/main.dart').existsSync(), isFalse, reason: 'the source inventory must exclude unselected upstream files');
  }

  Future<void> disconnect() async {
    if (serverClosed) return;
    serverClosed = true;
    await server.close(force: true);
  }

  Future<void> dispose() async {
    await disconnect();
    await temporary.delete(recursive: true);
  }
}

void main() {
  late _Fixture fixture;
  setUp(() async => fixture = await _Fixture.create());
  tearDown(() => fixture.dispose());

  test('Windows cache uses LOCALAPPDATA with its drive and spaces intact', () {
    final cache = defaultRecordCacheDirectory(
      operatingSystem: 'windows',
      environment: {'LOCALAPPDATA': r'D:\Local Cache', 'USERPROFILE': r'C:\Users\Radio Operator'},
    );

    expect(cache.uri, Uri.parse('file:///D:/Local%20Cache/ham2k/record/'));
  });

  test('Windows cache falls back to the user profile when LOCALAPPDATA is absent', () {
    final cache = defaultRecordCacheDirectory(operatingSystem: 'windows', environment: {'USERPROFILE': r'C:\Users\Radio Operator'});

    expect(cache.uri, Uri.parse('file:///C:/Users/Radio%20Operator/AppData/Local/ham2k/record/'));
  });

  test('loopback fixtures never consult the external proxy configuration', () async {
    await HttpOverrides.runZoned(
      fixture.prepare,
      findProxyFromEnvironment: (_, _) => throw StateError('Loopback downloads must stay on this machine regardless of HTTP_PROXY.'),
    );

    await fixture.expectSources();
    expect(fixture.requests, 1);
  });

  for (final crlf in [false, true]) {
    test('a scaffold-only checkout with ${crlf ? 'CRLF' : 'LF'} inputs becomes a complete package without rewriting tracked bytes', () async {
      final scaffolds = await fixture.writeScaffolds(crlf: crlf);
      expect(fixture.source('lib/source.dart').existsSync(), isFalse);
      expect(fixture.source('LICENSE').existsSync(), isFalse);

      await fixture.prepare();

      await fixture.expectSources(scaffoldBytes: scaffolds);
      expect(fixture.requests, 1);
      await fixture.disconnect();
      await fixture.prepare(offline: true);
      await fixture.expectSources(scaffoldBytes: scaffolds);
      expect(fixture.requests, 1, reason: 'tracked checkout line endings must not cause repeated downloads or source replacement');
    });
  }

  for (final path in ['pubspec.yaml', 'lib/owned.dart']) {
    for (final alreadyPrepared in [false, true]) {
      test('an edited $path scaffold is protected in a ${alreadyPrepared ? 'prepared' : 'fresh'} checkout', () async {
        await fixture.writeScaffolds();
        if (alreadyPrepared) await fixture.prepare();
        final edited = utf8.encode('local scaffold work must survive\n');
        await fixture.source(path).writeAsBytes(edited);

        await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>().having((error) => error.message, 'message', contains(path))));

        expect(await fixture.source(path).readAsBytes(), edited, reason: 'automatic preparation must never discard edits to tracked inputs');
        expect(fixture.source('lib/source.dart').existsSync(), alreadyPrepared, reason: 'a rejected scaffold must not publish generated files');
        expect(fixture.requests, alreadyPrepared ? 1 : 0, reason: 'validate checked-in inputs before archive work');
      });
    }
  }

  for (final directory in [false, true]) {
    test('a ${directory ? 'non-file' : 'deleted'} tracked scaffold is not silently reconstructed', () async {
      final scaffolds = await fixture.writeScaffolds();
      final owned = fixture.source('lib/owned.dart');
      await owned.delete();
      if (directory) await Directory(owned.path).create();

      await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>()));

      expect(await fixture.source('pubspec.yaml').readAsBytes(), scaffolds['pubspec.yaml']);
      expect(await FileSystemEntity.type(owned.path), directory ? FileSystemEntityType.directory : FileSystemEntityType.notFound);
      expect(fixture.source('lib/source.dart').existsSync(), isFalse);
      expect(fixture.requests, 0, reason: 'tracked deletions and unexpected file types require the developer to resolve the checkout');
    });
  }

  test('a scaffold edit during archive download prevents publication and survives intact', () async {
    await fixture.writeScaffolds();
    final owned = fixture.source('lib/owned.dart');
    final edited = utf8.encode('local edit made while preparation is downloading\n');
    fixture.onRequest = () async {
      await owned.writeAsBytes(edited);
    };

    await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>()));

    expect(await owned.readAsBytes(), edited, reason: 'an initial validation cannot authorize overwriting a later edit');
    expect(fixture.source('lib/source.dart').existsSync(), isFalse);
    expect(fixture.source('LICENSE').existsSync(), isFalse);
    expect(fixture.requests, 1, reason: 'the edit happens after input validation but before staged publication');
  });

  test('a verified archive becomes the exact patched package and can rebuild offline', () async {
    await fixture.prepare();
    await fixture.expectSources();
    expect(fixture.requests, 1);
    expect(await fixture.cachedArchive.readAsBytes(), fixture.archive, reason: 'the shared cache holds pristine archive bytes, not a mutable patched tree');

    await fixture.generated.delete(recursive: true);
    await fixture.disconnect();
    await fixture.prepare(offline: true);
    await fixture.expectSources();
    expect(fixture.requests, 1);
  });

  test('a changed patch recipe rebuilds from the same verified offline archive', () async {
    await fixture.prepare();
    await fixture.writeRecipe(value: 'revised');
    await fixture.disconnect();

    await fixture.prepare(offline: true);

    await fixture.expectSources();
    expect(await fixture.source('lib/source.dart').readAsString(), contains("'revised'"));
    expect(fixture.requests, 1, reason: 'our patch can change without downloading the unchanged upstream release again');
  });

  test('a downloaded checksum mismatch publishes neither a package nor a trusted cache entry', () async {
    fixture.responseBytes = utf8.encode('unexpected archive response');

    await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>()));

    expect(fixture.generated.existsSync(), isFalse);
    expect(fixture.cachedArchive.existsSync(), isFalse);
    expect(fixture.requests, 1);
  });

  test('offline mode rejects a corrupted cached archive without publishing partial sources', () async {
    await fixture.prepare(prefetchOnly: true);
    await fixture.cachedArchive.writeAsString('corrupted cache');
    await fixture.disconnect();

    await expectLater(fixture.prepare(offline: true), throwsA(isA<RecordDependencyException>()));

    expect(fixture.generated.existsSync(), isFalse);
    expect(fixture.requests, 1);
  });

  test('patch output must match the pinned final source hashes', () async {
    await fixture.patch.writeAsString((await fixture.patch.readAsString()).replaceFirst("+const input = 'verified'", "+const input = 'tampered'"));

    await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>()));

    expect(fixture.generated.existsSync(), isFalse, reason: 'an edited patch cannot publish a different source than the manifest reviewed');
  });

  test('a patch with the wrong original context cannot publish a package', () async {
    await fixture.patch.writeAsString((await fixture.patch.readAsString()).replaceFirst("-const input = 'upstream'", "-const input = 'another release'"));

    await expectLater(fixture.prepare(), throwsA(isA<RecordDependencyException>()));

    expect(fixture.generated.existsSync(), isFalse, reason: 'patches must apply exactly to the pinned release');
  });

  test('a rejected replacement leaves the previously verified package intact', () async {
    await fixture.prepare();
    final previous = {for (final path in fixture.expected.keys) path: await fixture.source(path).readAsBytes()};
    await fixture.writeRecipe(value: 'revised');
    await fixture.patch.writeAsString((await fixture.patch.readAsString()).replaceFirst("+const input = 'revised'", "+const input = 'tampered'"));
    await fixture.disconnect();

    await expectLater(fixture.prepare(offline: true), throwsA(isA<RecordDependencyException>()));

    for (final entry in previous.entries) {
      expect(await fixture.source(entry.key).readAsBytes(), entry.value, reason: 'failed staging must not replace ${entry.key}');
    }
    expect(fixture.requests, 1);
  });

  for (final missing in [true, false]) {
    test('${missing ? 'missing' : 'tampered'} generated source is repaired from the verified offline cache', () async {
      await fixture.prepare();
      final source = fixture.source('lib/source.dart');
      if (missing) {
        await source.delete();
      } else {
        await source.writeAsString('unreviewed local source\n');
      }
      await fixture.disconnect();

      await fixture.prepare(offline: true);

      await fixture.expectSources();
      expect(fixture.requests, 1, reason: 'a completion marker alone cannot establish that generated source remains intact');
    });
  }

  test('concurrent preparations converge on one complete package and one archive download', () async {
    await Future.wait(List.generate(8, (_) => fixture.prepare()));

    await fixture.expectSources();
    expect(fixture.requests, 1, reason: 'simultaneous builds must share the download without racing staged publication');
  });

  test('a valid source cache hit preserves platform build outputs', () async {
    await fixture.prepare();
    final buildOutput = fixture.source('.cxx/debug/build.ninja');
    await buildOutput.parent.create(recursive: true);
    await buildOutput.writeAsString('incremental native build state');
    await fixture.disconnect();

    await fixture.prepare(offline: true);

    await fixture.expectSources();
    expect(await buildOutput.readAsString(), 'incremental native build state', reason: 'routine preparation must not invalidate a correct native build cache');
    expect(fixture.requests, 1);
  });

  test('prefetch warms only verified archives for a later offline package build', () async {
    await fixture.prepare(prefetchOnly: true);
    expect(fixture.generated.existsSync(), isFalse);
    expect(await fixture.cachedArchive.readAsBytes(), fixture.archive);
    await fixture.disconnect();

    await fixture.prepare(offline: true);

    await fixture.expectSources();
    expect(fixture.requests, 1);
  });
}
