// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking a file on Android goes through `FilePickChannel.kt`, and its three
// answers must stay three: a file, a cancel, a failure. `file_selector`
// collapses the last into the second, which is the defect this exists to
// keep out — a pick that failed reads as one the operator abandoned, and the
// app does nothing at all.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/file_pick.dart';

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
}
