// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/hardware_keyboard_service.dart';
import 'package:halo_widgets/halo_widgets.dart' show hardwareKeyboardAttached;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ham2k/hardware_keyboard');

  tearDown(() {
    hardwareKeyboardAttached.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('init pulls the current state, so a keyboard attached before launch is seen', () async {
    // The native side only pushes transitions — without the startup pull, a
    // keyboard that was already attached stays invisible until the operator
    // unplugs and replugs it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'isAttached' ? true : null;
    });
    HardwareKeyboardService.init();
    await pumpEventQueue();
    expect(hardwareKeyboardAttached.value, isTrue);
  });

  test('a native attach/detach push updates the notifier', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'isAttached' ? false : null;
    });
    HardwareKeyboardService.init();
    await pumpEventQueue();
    expect(hardwareKeyboardAttached.value, isFalse);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'ham2k/hardware_keyboard',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('changed', true)),
      (_) {},
    );
    expect(hardwareKeyboardAttached.value, isTrue);
  });
}
