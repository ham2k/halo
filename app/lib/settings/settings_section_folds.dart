// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which settings sections the operator left open or shut, across visits:
/// one prefs entry for every settings surface, each section named after the
/// surface that declares it, so two panels' "Advanced" never share a fold.
///
/// This device's alone, like the open category: how a screen was left is
/// not a setting, and a fold synced in from another device would rearrange
/// the screen under the operator.
class SettingsSectionFolds implements FormSectionFolds {
  SettingsSectionFolds(this.prefs, this.surface);

  final SharedPreferences prefs;

  /// The settings group's key, or an extension panel's, that the sections
  /// belong to.
  final String surface;

  static const prefsKey = 'settingsSectionFolds';

  Map<String, dynamic> _read() {
    try {
      final decoded = jsonDecode(prefs.getString(prefsKey) ?? '{}');
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  @override
  bool? isOpen(String section) => switch (_read()['$surface/$section']) {
    final bool open => open,
    _ => null,
  };

  @override
  void remember(String section, bool open) => prefs.setString(prefsKey, jsonEncode({..._read(), '$surface/$section': open}));
}
