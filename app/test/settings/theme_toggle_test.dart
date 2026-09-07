// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ⌘⇧D light/dark hotkey (main.dart) flips to the opposite of what's on
// screen, resolving ThemeMode.system against the platform brightness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  test('toggledThemeMode flips to the opposite of what is shown', () {
    expect(toggledThemeMode(ThemeMode.dark, Brightness.dark), ThemeMode.light);
    expect(toggledThemeMode(ThemeMode.light, Brightness.light), ThemeMode.dark);

    // System follows the platform, so the toggle flips away from it.
    expect(toggledThemeMode(ThemeMode.system, Brightness.dark), ThemeMode.light);
    expect(toggledThemeMode(ThemeMode.system, Brightness.light), ThemeMode.dark);
  });
}
