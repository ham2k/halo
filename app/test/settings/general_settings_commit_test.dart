// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every picker the General settings group DECLARES must also be a picker it
// COMMITS.
//
// `SettingsGroup.commit` switches on the field key and falls through in
// silence on anything it doesn't recognise, so declaring a `_select` without
// adding its case renders a perfectly good control that does nothing at all:
// the row highlights the tapped option, nothing is written, and the next
// rebuild reads the stored value back and snaps to the old one. Nothing
// fails, nothing logs, and the switch's non-exhaustiveness is invisible to
// the analyzer because it is a switch over strings.
//
// Written over EVERY select rather than one key on purpose: a test naming
// only today's fields is one someone has to remember to extend, and the
// failure it guards against is precisely a field nobody remembered.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/core_settings_groups.dart';

class _ExtensionServiceWithMockHost extends ExtensionService {
  @override
  Future<void> start() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GeneralSettingsGroup> generalGroup(SettingsService settings) async {
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    return GeneralSettingsGroup(settings, extensions);
  }

  Future<List<Map<String, dynamic>>> elementsOf(SettingsService settings) async =>
      (await generalGroup(settings)).buildElements();

  /// The value the group would render for [key] right now — read back through
  /// `buildElements` rather than out of prefs, because that is what the row
  /// shows, and a setter writing a key the getter doesn't read would still
  /// leave the control stuck.
  Future<dynamic> renderedValue(SettingsService settings, String key) async {
    for (final el in await elementsOf(settings)) {
      if (el['key'] == key) return el['value'];
    }
    return null;
  }

  test('every select the group offers actually lands when committed', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final group = await generalGroup(settings);

    final selects = [
      for (final el in await elementsOf(settings))
        if (el['fieldType'] == 'select') el,
    ];
    expect(selects, isNotEmpty, reason: 'the group is meant to have pickers; finding none means this tests nothing');

    for (final el in selects) {
      final key = el['key'] as String;
      final options = (el['options'] as List).cast<Map<String, dynamic>>();
      expect(options.length, greaterThan(1), reason: '$key offers nothing to switch between');

      for (final option in options) {
        final value = option['value'] as String;
        await group.commit(key, value);
        expect(
          await renderedValue(settings, key),
          value,
          reason: '"$key" renders a picker with no matching case in commit() — '
              'tapping "$value" would highlight and then snap back',
        );
      }
    }
  });

  test('Number Formatting, named rather than left to the sweep above', () async {
    // The generic test covers this by iteration, and an edit that narrows the
    // iteration would take the coverage with it silently.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final group = await generalGroup(settings);

    expect(settings.numberFormatStyle, NumberFormatStyle.locale, reason: 'the default follows the device');

    await group.commit('numberFormat', 'comma');
    expect(settings.numberFormatStyle, NumberFormatStyle.comma);

    await group.commit('numberFormat', 'period');
    expect(settings.numberFormatStyle, NumberFormatStyle.period);

    await group.commit('numberFormat', 'locale');
    expect(settings.numberFormatStyle, NumberFormatStyle.locale);
  });

  test('an unrecognised value leaves the setting alone rather than clearing it', () async {
    // `commit` is reachable from a settings COMMAND as well as the row, so a
    // typed value that names no option must not blank the setting.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final group = await generalGroup(settings);

    await group.commit('numberFormat', 'comma');
    await group.commit('numberFormat', 'decimal-point-please');
    expect(settings.numberFormatStyle, NumberFormatStyle.comma);
  });
}
