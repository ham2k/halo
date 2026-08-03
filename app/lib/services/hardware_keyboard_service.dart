// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Whether a physical keyboard is attached decides whether mobile gets the
// desktop-style focus behavior (autofocus the callsign field, focus it on a
// spot tap) or the no-uninvited-virtual-keyboard carve-out
// (docs/design/logging-fields.md). Flutter has no API for keyboard
// *presence* — HardwareKeyboard only reports keys while they're pressed, and
// the viewInsets heuristic in keyboard_dismiss.dart can only answer while a
// field is already focused, strictly after the moment the answer is needed —
// so the native sides answer over this channel: iOS via GCKeyboard (14+),
// Android via InputDevice enumeration (see ios/Runner/AppDelegate.swift and
// android's MainActivity.kt, which serve it).

import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart' show hardwareKeyboardAttached, isMobilePlatform;

class HardwareKeyboardService {
  static const _channel = MethodChannel('ham2k/hardware_keyboard');

  /// Registers the receiving end of the channel and pulls the current state.
  /// Call once at startup. Native pushes arrive on attach/detach; the pull
  /// covers everything before the first transition (launch, hot restart).
  static void init() {
    if (!isMobilePlatform) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        hardwareKeyboardAttached.value = call.arguments as bool? ?? false;
      }
      return null;
    });
    _sync();
  }

  static Future<void> _sync() async {
    try {
      final attached = await _channel.invokeMethod<bool>('isAttached');
      if (attached != null) hardwareKeyboardAttached.value = attached;
    } on PlatformException {
      // Channel not ready; the next attach/detach push corrects.
    } on MissingPluginException {
      // Tests/embeddings without the native handler — the false default holds.
    }
  }
}
