// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../services/settings_service.dart';

/// Which CW message (1-based, up to [SettingsService.cwMessageCount]) [key]
/// stands for — F1 is message 1 — or null for any other key.
///
/// Bare function keys, deliberately: they are what every contest logger
/// sends messages on, and nothing else in the app claims them. A modifier
/// held alongside is the caller's to check, so ⌘F1 (a system shortcut on
/// some desktops) is not read as a message.
int? cwMessageIndexForKey(LogicalKeyboardKey key) {
  const keys = [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
  ];
  assert(keys.length == SettingsService.cwMessageCount, 'one key per message, and no more');
  final index = keys.indexOf(key);
  return index < 0 ? null : index + 1;
}
