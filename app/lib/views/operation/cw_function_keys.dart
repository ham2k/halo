// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;

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

/// Which CW message [key] stands for as the digit of a ⌥1-⌥8 (Alt+1-8)
/// chord — the function keys' stand-in on a keyboard that has none (a
/// laptop's needs Fn, a tablet's has no row at all) — or null. PHYSICAL
/// keys: Option turns the digits into '¡™£¢∞§¶•' on a Mac, and the logical
/// key a browser reports is that character. The modifier is the caller's to
/// check, as with [cwMessageIndexForKey].
int? cwMessageIndexForDigit(PhysicalKeyboardKey key) {
  const keys = [
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
    PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6,
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
  ];
  assert(keys.length == SettingsService.cwMessageCount, 'one key per message, and no more');
  final index = keys.indexOf(key);
  return index < 0 ? null : index + 1;
}
