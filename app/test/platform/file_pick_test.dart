// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking a file on Android goes through `FilePickChannel.kt`, and its three
// answers must stay three: a file, a cancel, a failure. `file_selector`
// collapses the last into the second, which is the defect this exists to
// keep out — a pick that failed reads as one the operator abandoned, and the
// app does nothing at all.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/file_pick.dart';
import 'package:ham2k_logger/services/file_pick_discard_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ham2k/file_pick');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  void answer(Object? Function() reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pickFile');
      return reply();
    });
  }

  test("a pick answers the channel's copy, named as the channel named it", () async {
    // The Dart half only: the copy's NAME is chosen in Kotlin, and the name
    // is what the import checks and every notice shows — so it must reach the
    // caller untouched. Whether Kotlin names it after the provider's display
    // name is checked on a device, not here.
    answer(() => '/data/cache/picked/1/FT8CN log.adi');
    final file = await pickFile();
    expect(file!.path, '/data/cache/picked/1/FT8CN log.adi');
    expect(file.name, 'FT8CN log.adi');
  });

  test('a cancel answers null', () async {
    answer(() => null);
    expect(await pickFile(), isNull);
  });

  test('a failed pick throws rather than reading as a cancel', () async {
    answer(() => throw PlatformException(code: 'pick_failed', message: 'provider went away'));
    // Its text is what the caller's notice shows the operator, so it is the
    // platform's sentence and not `PlatformException(pick_failed, …)`.
    await expectLater(pickFile(), throwsA(isA<FilePickException>().having((e) => '$e', 'shown as', 'provider went away')));
  });

  group('readPickedFile', () {
    test('refuses past the cap as it reads, whatever size the file claims', () async {
      // A provider may report no size or a wrong one; trusting it would let a
      // file the reader cannot hold be read whole first.
      final lying = XFile.fromData(Uint8List(2048), name: 'big.p12', length: 10);
      await expectLater(readPickedFile(lying, maxBytes: 1024), throwsA(isA<PickedFileTooLarge>()));
      expect(await readPickedFile(XFile.fromData(Uint8List(1024), name: 'ok.p12'), maxBytes: 1024), hasLength(1024));
    });
  });

  group('discardPickedCopy', () {
    // Every path here sits in a temp directory of its own, so a guard that
    // regresses deletes nothing outside it.
    late Directory root;
    late String cache;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('file_pick_test');
      cache = '${root.path}/cache';
    });
    tearDown(() => root.delete(recursive: true));

    File make(String path) => File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    test("removes the channel's copy, the directory it was copied into with it", () async {
      final copy = make('$cache/picked/12345/N0DEV.p12');
      await discardPickedCopy(copy.path, cacheDir: cache);
      // The credential the operator picked does not outlive the read.
      expect(copy.parent.existsSync(), isFalse);
      expect(Directory('$cache/picked').existsSync(), isTrue);
    });

    test("removes iOS's imported copy, and only that file", () async {
      // The document picker's import mode copies into the container's tmp,
      // beside the Library/Caches path_provider reports as temporary.
      final iosCache = '${root.path}/container/Library/Caches';
      final copy = make('${root.path}/container/tmp/com.ham2k.logger-Inbox/N0DEV.p12');
      final other = make('${root.path}/container/tmp/com.ham2k.logger-Inbox/other.adi');
      await discardPickedCopy(copy.path, cacheDir: iosCache);
      expect(copy.existsSync(), isFalse);
      // The Inbox is shared: another pick's file stays.
      expect(other.existsSync(), isTrue);

      // Named like an Inbox, but not in this container's tmp.
      final elsewhere = make('${root.path}/elsewhere/tmp/com.ham2k.logger-Inbox/N0DEV.p12');
      // In tmp, but not an Inbox.
      final scratch = make('${root.path}/container/tmp/scratch/N0DEV.p12');
      for (final file in [elsewhere, scratch]) {
        await discardPickedCopy(file.path, cacheDir: iosCache);
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });

    test('leaves every file that is not that copy alone', () async {
      // The operator's own file, which on every platform but Android is what
      // a pick hands back: deleting its directory takes their documents.
      final own = make('${root.path}/Documents/N0DEV.p12');
      // Shaped like a copy, under a directory named the same, but not the
      // app's cache: a check by name alone would empty it.
      final lookalike = make('${root.path}/elsewhere/picked/12345/N0DEV.p12');
      // A copy's own directory one level up, not in a pick's.
      final shallow = make('$cache/picked/N0DEV.p12');
      for (final file in [own, lookalike, shallow]) {
        await discardPickedCopy(file.path, cacheDir: cache);
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });

    test('leaves a relative path alone, even one shaped like a copy', () async {
      // An in-memory pick has no path, or a bare name, and its "directory" is
      // wherever the app runs. Run from the temp dir, so a guard that
      // regresses empties that and not the checkout. `picked/1/…` against a
      // cache of `.` passes the anchor check: only the relative-path guard
      // keeps it.
      final copy = make('${root.path}/picked/1/N0DEV.p12');
      final cwd = Directory.current;
      Directory.current = root;
      try {
        await discardPickedCopy('picked/1/N0DEV.p12', cacheDir: '.');
        await discardPickedCopy('N0DEV.p12', cacheDir: '.');
        await discardPickedCopy('', cacheDir: '.');
      } finally {
        Directory.current = cwd;
      }
      expect(copy.existsSync(), isTrue);
    });
  });
}
