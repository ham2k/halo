// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where Settings remembers its section folds: one prefs entry shared by every
// surface, so each surface's sections must stay apart in it.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/settings/settings_section_folds.dart';

void main() {
  Future<SharedPreferences> prefs([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    return SharedPreferences.getInstance();
  }

  // Two panels both calling a section "advanced" would otherwise fold
  // together.
  test("a surface's folds are its own", () async {
    final store = await prefs();
    SettingsSectionFolds(store, 'radio').remember('advanced', false);
    expect(SettingsSectionFolds(store, 'radio').isOpen('advanced'), isFalse);
    expect(SettingsSectionFolds(store, 'extension:pota/settings').isOpen('advanced'), isNull);
  });

  test('a later choice replaces the earlier one and keeps the others', () async {
    final store = await prefs();
    SettingsSectionFolds(store, 'radio')
      ..remember('keyer', false)
      ..remember('tuning', false)
      ..remember('keyer', true);
    expect(SettingsSectionFolds(store, 'radio').isOpen('keyer'), isTrue);
    expect(SettingsSectionFolds(store, 'radio').isOpen('tuning'), isFalse);
  });

  // A throw here would take down the Settings panel, for a preference about
  // how it looks.
  test('an unreadable entry is no memory at all, and the next fold starts it over', () async {
    final store = await prefs({SettingsSectionFolds.prefsKey: 'not json'});
    final folds = SettingsSectionFolds(store, 'radio');
    expect(folds.isOpen('keyer'), isNull);
    folds.remember('keyer', false);
    expect(folds.isOpen('keyer'), isFalse);
  });
}
