// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `halo-ext --dev-server`: running hooks against the extension an author is
// editing, instead of the last thing they built
// (HALO-118, docs/extensions/development.md).
//
// The overlay is the interesting part. The dev server serves no kernel and only
// the extensions it was asked to watch, so this cannot replace the built index
// — it has to merge into it, the same way the app does.

import 'dart:convert';
import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  /// A built bundle directory with two extensions, as `npm run build` leaves it.
  Directory builtBundles() {
    final dir = Directory.systemTemp.createTempSync('halo-bundles');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/index.json').writeAsStringSync(
      jsonEncode({
        'kernel': 'kernel.js',
        'extensions': [
          {'key': 'pota', 'file': 'pota.js', 'core': false, 'name': 'Parks on the Air'},
          {'key': 'sota', 'file': 'sota.js', 'core': false, 'name': 'Summits on the Air'},
        ],
      }),
    );
    File('${dir.path}/kernel.js').writeAsStringSync('/* built kernel */');
    File('${dir.path}/pota.js').writeAsStringSync('/* built pota */');
    File('${dir.path}/sota.js').writeAsStringSync('/* built sota */');
    return dir;
  }

  MockClient devServer({
    int protocol = devServerProtocol,
    String server = 'halo-ext-dev',
    List<Map<String, dynamic>> extensions = const [
      {'key': 'pota', 'file': 'pota.js', 'core': false, 'name': 'Parks on the Air'},
    ],
  }) => MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/ping')) {
      return http.Response(jsonEncode({'server': server, 'protocol': protocol}), 200);
    }
    if (path.endsWith('/index.json')) return http.Response(jsonEncode({'extensions': extensions}), 200);
    if (path.endsWith('.js')) return http.Response('/* dev ${path.split('/').last} */', 200);
    return http.Response('not found', 404);
  });

  test('a dev-served extension replaces the built one', () async {
    final index = BundleIndex.load(dir: builtBundles());
    expect(index.sourceFor(index.extensions.firstWhere((e) => e.key == 'pota')), '/* built pota */');

    await index.overlayDevServer(Uri.parse('http://host:8787/'), httpClient: devServer());

    final pota = index.extensions.firstWhere((e) => e.key == 'pota');
    expect(index.sourceFor(pota), '/* dev pota.js */');
    expect(pota.fromDevServer, isTrue);
  });

  test('extensions the dev server does not serve keep coming from the build', () async {
    final index = BundleIndex.load(dir: builtBundles());

    await index.overlayDevServer(Uri.parse('http://host:8787/'), httpClient: devServer());

    // `npm run dev -- --only pota` is the normal case, and it must not take
    // every other extension away — the author is iterating on one thing inside
    // a working app.
    final sota = index.extensions.firstWhere((e) => e.key == 'sota');
    expect(index.sourceFor(sota), '/* built sota */');
    expect(sota.fromDevServer, isFalse);
  });

  test('the kernel always comes from the build', () async {
    final index = BundleIndex.load(dir: builtBundles());

    await index.overlayDevServer(Uri.parse('http://host:8787/'), httpClient: devServer());

    // The dev server deliberately serves no kernel: reloading one means
    // restarting the runtime, which is a different operation from swapping an
    // extension. So the built bundles remain a prerequisite, and an overlay
    // that tried to take the kernel too would have nothing to take.
    expect(index.kernelSource, '/* built kernel */');
  });

  test('an extension the build has never seen is appended', () async {
    final index = BundleIndex.load(dir: builtBundles());

    await index.overlayDevServer(
      Uri.parse('http://host:8787/'),
      httpClient: devServer(
        extensions: const [
          {'key': 'brandnew', 'file': 'brandnew.js', 'core': false, 'name': 'Brand New'},
        ],
      ),
    );

    final fresh = index.extensions.firstWhere((e) => e.key == 'brandnew');
    // It has no built file at all, so reading it through the directory would
    // throw — the in-memory source is the only thing that can answer.
    expect(index.sourceFor(fresh), '/* dev brandnew.js */');
    expect(index.extensions.map((e) => e.key), ['pota', 'sota', 'brandnew']);
  });

  group('what it refuses', () {
    Future<void> overlay(MockClient client) => BundleIndex.load(dir: builtBundles()).overlayDevServer(Uri.parse('http://host:8787/'), httpClient: client);

    test('a server that is not a dev server', () {
      expect(() => overlay(MockClient((_) async => http.Response('<html>hi</html>', 200))), throwsA(isA<DevServerUnreachable>()));
    });

    test('a protocol this build does not speak', () {
      expect(() => overlay(devServer(protocol: 99)), throwsA(isA<DevServerUnreachable>()));
    });

    test('nothing listening', () {
      expect(() => overlay(MockClient((_) async => throw http.ClientException('connection refused'))), throwsA(isA<DevServerUnreachable>()));
    });
  });

  group('normalizeDevServerUrl', () {
    test('accepts a bare host:port', () {
      expect(normalizeDevServerUrl('127.0.0.1:8787').toString(), 'http://127.0.0.1:8787/');
    });

    test('keeps an explicit scheme', () {
      expect(normalizeDevServerUrl('http://box.local:9000').toString(), 'http://box.local:9000/');
    });

    test('always ends in a slash', () {
      // The trap: `Uri.resolve('ping')` against a path-less base drops the
      // last segment, so the same address typed two ways would request two
      // different things.
      for (final input in ['h:1', 'http://h:1', 'http://h:1/']) {
        expect(normalizeDevServerUrl(input).resolve('ping').path, '/ping', reason: input);
      }
    });

    test('rejects an empty address', () {
      expect(() => normalizeDevServerUrl('   '), throwsA(isA<DevServerUnreachable>()));
    });
  });
}
