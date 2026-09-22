// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Files the OS hands the app to open (HALO-422).
//
// The native half queues anything that arrives before the engine exists and
// flushes it when the channel is set, so this side only has to deliver what
// it is given — but delivering it is the part that, missing, makes a
// registered document type an app that opens and does nothing.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/opened_files_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ham2k/open_file');

  /// Invokes the channel the way AppDelegate does.
  Future<void> nativeOpens(List<String> paths) => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('openFiles', {'paths': paths})),
    (_) {},
  );

  test('a path the native side sends arrives on the stream', () async {
    final service = OpenedFilesService();
    addTearDown(service.dispose);
    final seen = <String>[];
    service.openedFiles.listen(seen.add);

    await nativeOpens(['/tmp/ki2d-my-clock.h2kext']);
    await pumpEventQueue();

    expect(seen, ['/tmp/ki2d-my-clock.h2kext']);
  });

  test('several opens all arrive, in order', () async {
    // The native side sends ONE call carrying every path, because Flutter's
    // channel buffer holds a single message until this handler exists — a
    // cold launch opening several documents would otherwise keep one.
    final service = OpenedFilesService();
    addTearDown(service.dispose);
    final seen = <String>[];
    service.openedFiles.listen(seen.add);

    await nativeOpens(['/tmp/a.h2kext', '/tmp/b.h2kext']);
    await pumpEventQueue();

    expect(seen, ['/tmp/a.h2kext', '/tmp/b.h2kext']);
  });

  test('a call with no usable path is ignored rather than emitted', () async {
    final service = OpenedFilesService();
    addTearDown(service.dispose);
    final seen = <String>[];
    service.openedFiles.listen(seen.add);

    await nativeOpens(['']);
    await pumpEventQueue();

    expect(seen, isEmpty);
  });
}
