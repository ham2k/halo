// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who sent a link, as the native side recorded it. The trap: the native side
// keeps the link's raw string, and the app reads the link parsed — a `%2f`
// comes back `%2F` — so a lookup by string misses, and a sender the operator
// allowed or denied for good turns into "nobody named".

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ham2k/link_sender');

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  void recorded(List<Map<String, String>> senders) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => senders);

  test('finds the sender of a link whose raw string parsing rewrites', () async {
    const raw = 'com.ham2k:///operation?our.refs=sota:W6%2fCT-006';
    expect(Uri.parse(raw).toString(), isNot(raw), reason: 'the case under test');
    recorded([
      {'uri': raw, 'id': 'android-app://com.example.sotacat', 'label': 'SOTAcat'},
    ]);
    expect(await DeepLinkService().senderOf(Uri.parse(raw)), (id: 'android-app://com.example.sotacat', label: 'SOTAcat'));
  });

  test('the latest sender of the same link is the one that counts', () async {
    const raw = 'com.ham2k:///vfo?frequency=7030000&mode=CW';
    recorded([
      {'uri': raw, 'id': 'android-app://com.example.first', 'label': 'First'},
      {'uri': raw, 'id': 'android-app://com.example.second', 'label': 'Second'},
    ]);
    expect((await DeepLinkService().senderOf(Uri.parse(raw)))?.label, 'Second');
  });

  test('a native side that does not answer is an error, not "nobody named"', () async {
    await expectLater(DeepLinkService().senderOf(Uri.parse('com.ham2k:///vfo?frequency=7030000')), throwsA(isA<MissingPluginException>()));
  });
}
