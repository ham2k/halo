// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's pictures: an image layer, and a picture laid on the map by its
// corners. Where one may come from is the extension's own `assets/`, a
// `data:` URI, or an https host it declares — an address anywhere else
// would be a request made just by the operator looking at the pane, so it
// is never sent. A picture is held to a size in bytes and, before it is
// decoded, in pixels: a few kilobytes of PNG can decode to gigabytes. And a
// map overlay's picture falls evenly in latitude and longitude between its
// corners, so one given the edges of a plate carrée picture lands where it
// shows, in one piece across the antimeridian.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_requests.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_images.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_map_overlays.dart' show OverlayCorners, OverlaySheet;
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A real PNG of [width] by [height] pixels.
Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF3366CC));
  final image = await recorder.endRecording().toImage(width, height);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

Map<String, dynamic> layerScene(Map<String, dynamic> layer) => {
  'version': 1,
  'width': 100,
  'height': 100,
  'values': {},
  'layers': [
    {'id': 'pic', 'x': 0, 'y': 0, 'width': 100, 'height': 100, ...layer},
  ],
};

void main() {
  group('the document', () {
    test('an image comes from a data: URI, the extension\'s assets/ or https; anything else is refused before it is asked for', () {
      for (final ok in ['data:image/png;base64,iVBORw0K', 'assets/maps/muf.png', 'https://example.org/muf.jpg']) {
        expect(PanelScene(layerScene({'image': ok})).layers.single.image, ok);
      }
      for (final (why, bad) in [
        ('an svg is a layer of its own', 'data:image/svg+xml;base64,PHN2Zz4='),
        ('plain http crosses the network in the clear', 'http://example.org/muf.png'),
        ('a file of the operator\'s', 'file:///etc/passwd'),
        ('out of the bundle', 'assets/../../secrets.png'),
        ('not in assets/', 'images/muf.png'),
        ('not a picture', 'assets/data.json'),
      ]) {
        expect(() => PanelScene(layerScene({'image': bad})), throwsFormatException, reason: why);
      }
      expect(PanelScene(layerScene({'image': 'assets/a.png', 'fit': 'cover'})).layers.single.imageFit, BoxFit.cover);
      expect(() => PanelScene(layerScene({'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>', 'fit': 'cover'})), throwsFormatException);
      expect(() => PanelScene(layerScene({'image': 'assets/a.png', 'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>'})), throwsFormatException);
    });

    test('a map overlay is placed by four corners or by bounds, and an east short of the west crosses the antimeridian', () {
      SceneMapOverlay overlay(Map<String, dynamic> json) => SceneMapOverlay({'id': 'o', 'image': 'assets/o.png', ...json});
      final boxed = overlay({
        'bounds': {'north': 10, 'south': -10, 'west': 170, 'east': -170},
      });
      expect(boxed.corners.first, (lat: 10.0, lon: 170.0));
      expect(boxed.corners[1], (lat: 10.0, lon: 190.0));
      expect(() => overlay({}), throwsFormatException, reason: 'placed nowhere');
      expect(
        () => overlay({
          'corners': [
            {'lat': 0, 'lon': 0},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => overlay({
          'bounds': {'north': 0, 'south': 10, 'west': 0, 'east': 10},
        }),
        throwsFormatException,
      );
    });
  });

  group('loading', () {
    setUp(ExtensionSceneImages.debugForget);

    ExtensionSceneImages images({List<String> domains = const ['maps.example'], http.Client? client}) => ExtensionSceneImages(
      extensionKey: 'ext',
      store: null,
      grant: ExtensionNetworkGrant(extensionKey: 'ext', domains: domains),
      clients: ({required bool guarded}) => client ?? MockClient((_) async => fail('nothing should be requested')),
    );

    test('a data: URI decodes, and the picture is kept for the next showing', () async {
      final bytes = await png(8, 4);
      final source = 'data:image/png;base64,${base64Encode(bytes)}';
      final images0 = images();
      final image = await images0.load(source);
      expect((image.width, image.height), (8, 4));
      expect(identical(await images0.load(source), image), isTrue);
    });

    test('an https picture on a host the extension declares is fetched; one on any other is never asked for', () async {
      final bytes = await png(2, 2);
      final asked = <Uri>[];
      final client = MockClient((request) async {
        asked.add(request.url);
        return http.Response.bytes(bytes, 200);
      });
      expect((await images(client: client).load('https://maps.example/muf.png')).width, 2);
      await expectLater(images(client: client).load('https://elsewhere.example/pixel.png'), throwsA(isA<ExtensionUrlRefused>()));
      expect(asked, [Uri.parse('https://maps.example/muf.png')]);
    });

    test('a picture past the size in bytes is cut off as it arrives, and one past the pixels before it is decoded', () async {
      final big = MockClient((request) async => http.Response.bytes(Uint8List(sceneImageMaxBytes + 1), 200));
      await expectLater(
        images(client: big).load('https://maps.example/big.png'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('bytes'))),
      );
      // Read from the header before the pixels: the cap at a size a test can afford to draw.
      await expectLater(decodeSceneImage(await png(10, 4), maxSide: 9), throwsFormatException);
      expect((await decodeSceneImage(await png(9, 9), maxSide: 9)).width, 9);
      await expectLater(decodeSceneImage(Uint8List.fromList(utf8.encode('not a picture'))), throwsFormatException);
    });

    // A browser build reads the size itself: its `ImageDescriptor` gives
    // none, and with no size every picture there would fail.
    test('each format\'s size is read from its header, and anything else is not a picture', () async {
      final pngBytes = await png(300, 200);
      Uint8List bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(32, 0)]);
      final gif = bytes([...'GIF89a'.codeUnits, 44, 1, 200, 0, 0, 0, 0, 0x2C, 0, 0, 0, 0, 44, 1, 200, 0, 0]);
      final jpeg = bytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 4, 0, 0, 0xFF, 0xC2, 0, 11, 8, 0, 200, 1, 44]);
      ByteData le(int bytes, int value) => ByteData(bytes)..setUint32(0, value, Endian.little);
      List<int> riff(String chunk, List<int> body) => [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, ...chunk.codeUnits, 0, 0, 0, 0, ...body];
      final lossy = bytes(riff('VP8 ', [0, 0, 0, 0x9D, 0x01, 0x2A, 44, 1, 200, 0]));
      final lossless = bytes(riff('VP8L', [0x2F, ...le(4, 299 | (199 << 14)).buffer.asUint8List()]));
      final extended = bytes(riff('VP8X', [0, 0, 0, 0, 43, 1, 0, 199, 0, 0]));
      for (final (name, b) in [('png', pngBytes), ('gif', gif), ('jpeg', jpeg), ('webp', lossy), ('webp lossless', lossless), ('webp extended', extended)]) {
        expect(sceneImageSize(b), (width: 300, height: 200), reason: name);
      }
      expect(sceneImageSize(Uint8List.fromList(utf8.encode('not a picture at all, just words'))), isNull);
      expect(sceneImageSize(pngBytes.sublist(0, 20)), isNull, reason: 'cut short');
      expect(sceneImageSize(extended.sublist(0, 30)), isNull, reason: 'cut short');
    });

    // A file that shows the reader one size and the decoder another slips the
    // cap: the reader walks it as the decoder does.
    test('a header is read as the decoder reads it, so a decoy size cannot hide the real one', () {
      // A restart marker has no length: read as one, the walk jumps the real
      // frame header and lands on the decoy hidden in a comment.
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xD0, 0x00, 0x10, //
        0xFF, 0xC0, 0, 11, 8, 0x75, 0x30, 0x75, 0x30, 1, 1, //
        0xFF, 0xFE, 0, 11, 0xFF, 0xC0, 0, 11, 8, 0, 10, 0, 10, 0, 0,
      ]);
      expect(sceneImageSize(jpeg), (width: 30000, height: 30000));
      // A first frame past its screen grows the picture to it.
      final gif = Uint8List.fromList([
        ...'GIF89a'.codeUnits, 1, 0, 1, 0, 0, 0, 0, //
        0x21, 0xF9, 4, 0, 0, 0, 0, 0, //
        0x2C, 0, 0, 0, 0, 0x20, 0x4E, 0x20, 0x4E, 0, //
      ]);
      expect(sceneImageSize(gif), (width: 20000, height: 20000));
    });

    test('an https picture that does not arrive in time is dropped', () async {
      final never = MockClient((_) => Completer<http.Response>().future);
      final slow = ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext', domains: ['maps.example']),
        clients: ({required bool guarded}) => never,
        fetchTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(slow.load('https://maps.example/stuck.png'), throwsA(isA<TimeoutException>()));
    });

    // Without it, a pane closed on a picture still downloading keeps the
    // download, and its 30-second watchdog, running for no one.
    test('a download nothing wants any more is dropped, once the last that asked for it lets go', () async {
      var calls = 0;
      final never = MockClient((_) {
        calls++;
        return Completer<http.Response>().future;
      });
      final images0 = images(client: never);
      const source = 'https://maps.example/stuck.png';
      final first = images0.load(source), second = images0.load(source);
      expect(identical(first, second), isTrue, reason: 'one download for both');
      var dropped = false;
      unawaited(first.then<void>((_) {}, onError: (Object e) => dropped = e is SceneImageUnavailable));
      images0.release(source, first);
      await pumpEventQueue();
      expect(dropped, isFalse, reason: 'the second still wants it');
      images0.release(source, second);
      await pumpEventQueue();
      expect(dropped, isTrue);
      final again = images0.load(source);
      unawaited(again.then<void>((_) {}, onError: (Object _) {}));
      await pumpEventQueue();
      expect(calls, 2, reason: 'a dropped download is not kept: asked for again, it is fetched again');
      // A pane's loader lets go of what it asked for when it closes.
      final loader = SceneImageLoader(() {});
      loader.want(images0, {0: source});
      images0.release(source, again);
      loader.dispose();
      await expectLater(again.timeout(const Duration(seconds: 2)), throwsA(isA<SceneImageUnavailable>()));
    });

    // A `data:` URI is its own key: a few of megabytes each, uncounted, would
    // be kept past the budget however few pixels they decode to.
    test('the pictures kept count their keys against the budget, not only their pixels', () async {
      final keptBytes = ExtensionSceneImages.keptBytes;
      addTearDown(() => ExtensionSceneImages.keptBytes = keptBytes);
      ExtensionSceneImages.keptBytes = 1500;
      final bytes = base64Encode(await png(1, 1));
      String source(String name) => 'data:image/png;name=$name${'x' * 1000};base64,$bytes';
      final images0 = images();
      await images0.load(source('a'));
      expect(images0.loaded(source('a')), isNotNull);
      await images0.load(source('b'));
      expect(images0.loaded(source('a')), isNull, reason: 'two keys of a kilobyte each are past 1,500 bytes');
      expect(images0.loaded(source('b')), isNotNull);
    });
  });

  group('a scene\'s loader', () {
    setUp(ExtensionSceneImages.debugForget);

    test('takes a picture asked for after its images were replaced by equal ones, and lets go of those it no longer shows', () async {
      final bytes = await png(2, 2);
      ExtensionSceneImages images() => ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext'),
      );
      final first = 'data:image/png;base64,${base64Encode(bytes)}';
      final second = 'data:image/png;base64,${base64Encode(await png(3, 3))}';
      var loaded = Completer<void>();
      final loader = SceneImageLoader(() => loaded.complete());
      loader.want(images(), {'a': first});
      await loaded.future;
      // A dock rebuild hands the scene an equal, new, SceneImages: a picture
      // asked of it is still the scene's.
      loaded = Completer<void>();
      loader.want(images(), {'a': first, 'b': second});
      await loaded.future;
      expect(loader['b']?.width, 3);
      loader.want(images(), {'b': second});
      expect(loader['a'], isNull, reason: 'no longer shown, so not held');
    });

    // Without the hold, a picture an extension moves to a new address (the
    // next radar frame) blinks out for as long as the new one downloads.
    test('a slot given a new source shows the picture it had until the new one arrives, and nothing if it fails', () async {
      final frame = await png(2, 2), next = await png(3, 3);
      final answers = <String, Completer<http.Response>>{};
      final client = MockClient((request) => (answers[request.url.path] = Completer()).future);
      final images = ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext', domains: ['maps.example']),
        clients: ({required bool guarded}) => client,
      );
      var changes = 0;
      final loader = SceneImageLoader(() => changes++);
      addTearDown(loader.dispose);
      Future<void> answer(String path, http.Response response) async {
        for (var i = 0; i < 20 && answers[path] == null; i++) {
          await pumpEventQueue();
        }
        answers[path]!.complete(response);
        final before = changes;
        for (var i = 0; i < 50 && changes == before; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }

      loader.want(images, {'radar': 'https://maps.example/1.png'});
      await answer('/1.png', http.Response.bytes(frame, 200));
      expect(loader['radar']?.width, 2);
      loader.want(images, {'radar': 'https://maps.example/2.png'});
      expect(loader['radar']?.width, 2, reason: 'the last frame stays while the next downloads');
      await answer('/2.png', http.Response.bytes(next, 200));
      expect(loader['radar']?.width, 3);
      loader.want(images, {'radar': 'https://maps.example/3.png'});
      await answer('/3.png', http.Response('gone', 404));
      expect(loader['radar'], isNull, reason: 'a picture that cannot be had is not covered by an old one');
      expect(loader.failed('radar'), isTrue);
    });

    // Without it, a pane shown again draws its first frame empty, and the
    // picture pops in on the next.
    test('a picture already decoded is there as soon as it is asked for', () async {
      final source = 'data:image/png;base64,${base64Encode(await png(2, 2))}';
      final images = ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext'),
      );
      await images.load(source);
      final loader = SceneImageLoader(() {});
      loader.want(images, {0: source});
      expect(loader[0]?.width, 2);
      loader.dispose();
    });

    test('asks again for an https picture that failed, and says why on the console once', () async {
      final bytes = await png(2, 2);
      var calls = 0;
      final flaky = MockClient((_) async => ++calls <= 2 ? http.Response('down', 503) : http.Response.bytes(bytes, 200));
      final images = ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext', domains: ['maps.example']),
        clients: ({required bool guarded}) => flaky,
      );
      const source = 'https://maps.example/muf.png';
      final printed = <String>[];
      final print0 = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = print0);
      late SceneImageLoader loader;
      var changed = Completer<void>();
      loader = SceneImageLoader(() {
        // As a build does on each change.
        loader.want(images, {0: source});
        if (!changed.isCompleted) changed.complete();
      }, retryAfter: const Duration(milliseconds: 10));
      loader.want(images, {0: source});
      await changed.future;
      expect(loader.failed(0), isTrue);
      expect(printed.single, allOf(contains('ext'), contains('HTTP 503')));
      for (var i = 0; i < 50 && loader[0] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(loader[0]?.width, 2);
      expect(loader.failed(0), isFalse);
      expect(calls, 3, reason: 'failed twice, then had');
      expect(printed, hasLength(1), reason: 'said once, however often it failed');
      loader.dispose();
    });

    test('never asks again for an https picture refused for what it is', () async {
      var calls = 0;
      final missing = MockClient((_) async {
        calls++;
        return http.Response('gone', 404);
      });
      final images = ExtensionSceneImages(
        extensionKey: 'ext',
        store: null,
        grant: const ExtensionNetworkGrant(extensionKey: 'ext', domains: ['maps.example']),
        clients: ({required bool guarded}) => missing,
      );
      const source = 'https://maps.example/gone.png';
      late SceneImageLoader loader;
      loader = SceneImageLoader(() => loader.want(images, {0: source}), retryAfter: const Duration(milliseconds: 5));
      loader.want(images, {0: source});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(loader.failed(0), isTrue);
      expect(calls, 1, reason: 'a 404 is a 404 the next minute too: asked again, it is the whole picture each time');
      loader.dispose();
    });
  });

  testWidgets('an image layer shows its picture once it has loaded', (tester) async {
    final bytes = await tester.runAsync(() => png(4, 4));
    final source = 'data:image/png;base64,${base64Encode(bytes!)}';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: SceneImageScope(
            images: ExtensionSceneImages(
              extensionKey: 'ext',
              store: null,
              grant: const ExtensionNetworkGrant(extensionKey: 'ext'),
            ),
            child: SizedBox(width: 100, height: 100, child: PanelSceneView(scene: PanelScene(layerScene({'image': source})))),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20 && tester.widget<RawImage>(find.byType(RawImage)).image == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  group('a map overlay', () {
    Offset corner(Float32List positions, int index) => Offset(positions[2 * index], positions[2 * index + 1]);
    const n = 33; // points a side
    OverlayCorners quad(List<({double lat, double lon})> c) => (c[0], c[1], c[2], c[3]);

    test('lands its corners on theirs, and falls evenly in latitude and longitude between them', () {
      const mercator = MercatorProjection(0);
      final corners = [(lat: 60.0, lon: -30.0), (lat: 60.0, lon: 30.0), (lat: -20.0, lon: 30.0), (lat: -20.0, lon: -30.0)];
      final mesh = OverlaySheet(quad(corners)).placeIn(mercator).single;
      void at(int index, double lat, double lon) {
        final want = mercator.toMap(lat, lon)!;
        expect(corner(mesh.positions, index).dx, closeTo(want.dx, 1e-6));
        expect(corner(mesh.positions, index).dy, closeTo(want.dy, 1e-6));
      }

      at(0, 60, -30);
      at(n - 1, 60, 30);
      at(n * n - 1, -20, 30);
      // The middle row is the middle latitude, 20°, not the middle of the picture's Mercator height.
      final middle = corner(mesh.positions, (n ~/ 2) * n);
      expect(middle.dy, closeTo(mercator.toMap(20, -30)!.dy, 1e-6));
    });

    test('across the antimeridian is one piece, laid again a turn the other way', () {
      final corners = [(lat: 10.0, lon: 170.0), (lat: 10.0, lon: 190.0), (lat: -10.0, lon: 190.0), (lat: -10.0, lon: 170.0)];
      final meshes = OverlaySheet(quad(corners)).placeIn(const EquirectangularProjection(0));
      expect(meshes, hasLength(2));
      for (final mesh in meshes) {
        final xs = [for (var i = 0; i < mesh.positions.length; i += 2) mesh.positions[i]];
        expect(
          xs.reduce((a, b) => b > a ? b : a) - xs.reduce((a, b) => b < a ? b : a),
          closeTo(20 * 3.141592653589793 / 180, 1e-6),
          reason: 'twenty degrees wide, never the world',
        );
      }
    });

    test('of the whole world spans it, -180 to 180, rather than nothing', () {
      final world = [(lat: 85.0, lon: -180.0), (lat: 85.0, lon: 180.0), (lat: -85.0, lon: 180.0), (lat: -85.0, lon: -180.0)];
      final mesh = OverlaySheet(quad(world)).placeIn(const EquirectangularProjection(0)).first;
      expect(corner(mesh.positions, n - 1).dx - corner(mesh.positions, 0).dx, closeTo(2 * 3.141592653589793, 1e-5));
    });

    // Left out whole, a cell near the rim leaves a ragged hole from about
    // nine tenths of the way out; drawn whole, it cuts across the disc.
    test('on the disc, a picture of the whole world follows the rim, and never reaches across it', () {
      final world = [(lat: 85.0, lon: -180.0), (lat: 85.0, lon: 180.0), (lat: -85.0, lon: 180.0), (lat: -85.0, lon: -180.0)];
      final disc = AzimuthalProjection(const GridLocation(40, -74));
      final mesh = OverlaySheet(quad(world)).placeIn(disc).single;
      final p = mesh.positions;
      final triangles = [for (var k = 0; k < p.length; k += 6) (corner(p, k ~/ 2), corner(p, k ~/ 2 + 1), corner(p, k ~/ 2 + 2))];
      for (final (a, b, c) in triangles) {
        for (final side in [a - b, b - c, c - a]) {
          expect(side.distance, lessThanOrEqualTo(disc.longestStep));
        }
      }
      double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
      bool covered(Offset q) => triangles.any((t) {
        final (a, b, c) = t;
        final d1 = cross(q, a, b), d2 = cross(q, b, c), d3 = cross(q, c, a);
        return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
      });
      for (var bearing = 0; bearing < 360; bearing += 15) {
        final q = Offset.fromDirection(bearing * 3.141592653589793 / 180, 0.93);
        expect(covered(q), isTrue, reason: 'at $bearing°, 0.93 of the way to the rim');
      }
    });
  });
}
