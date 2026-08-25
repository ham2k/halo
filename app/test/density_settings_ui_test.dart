// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings row is the only way to reach Layout Density without a
// keyboard, so it has to offer every level and its commit has to land. A
// mistyped field key would leave the row rendering perfectly and doing
// nothing at all — `SettingsGroup.commit` switches on that key and falls
// through silently on anything it doesn't recognise.
//
// Declaration-level like font_scale_settings_ui_test: `buildElements` reads
// only `settings`, so nothing has to be pumped.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
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

  Future<GeneralSettingsGroup> group(SettingsService settings) async {
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    return GeneralSettingsGroup(settings, extensions);
  }

  Future<Map<String, dynamic>> densityField(SettingsService settings) async {
    final elements = await (await group(settings)).buildElements();
    return elements.firstWhere((e) => e['key'] == 'layoutDensity');
  }

  Future<SettingsService> freshSettings() async {
    SharedPreferences.setMockInitialValues({});
    return SettingsService(await SharedPreferences.getInstance());
  }

  test('the picker offers every level, Auto first', () async {
    final settings = await freshSettings();
    final field = await densityField(settings);
    final options = (field['options'] as List).cast<Map<String, dynamic>>();

    expect(
      options.map((o) => o['value']),
      DensityPreference.values.map((p) => p.name),
      reason: 'a level missing here is a level only the keyboard can reach',
    );
    expect(options.first['value'], 'auto');
    // Labels come from i18n and must all resolve — a missing key surfaces as
    // the raw path rather than as a failure anywhere else.
    for (final option in options) {
      expect(option['label'], isNot(contains('layoutDensityOpts')));
      expect(option['label'], isNotEmpty);
    }
  });

  test('the row reports the stored preference, and follows it when it changes', () async {
    final settings = await freshSettings();
    expect((await densityField(settings))['value'], 'auto');

    await settings.setDensityPreference(DensityPreference.sparsest);
    final field = await densityField(settings);
    expect(field['value'], 'sparsest');
    // The description restates the CHOSEN option, nothing else: a description
    // that drifted back to prose about the option would still be non-empty.
    final options = (field['options'] as List).cast<Map<String, dynamic>>();
    final chosen = options.firstWhere((o) => o['value'] == 'sparsest');
    expect(field['description'], chosen['label']);
  });

  test('commit lands on the service, and ignores a value that is not a level', () async {
    final settings = await freshSettings();
    final general = await group(settings);

    await general.commit('layoutDensity', 'dense');
    expect(settings.densityPreference, DensityPreference.dense);

    // The switch falls through silently on an unknown key or a junk value —
    // the previous choice must survive rather than resetting to the default.
    await general.commit('layoutDensity', 'notADensity');
    expect(settings.densityPreference, DensityPreference.dense);
    await general.commit('layoutDensityTypo', 'sparse');
    expect(settings.densityPreference, DensityPreference.dense);
  });

  test('the group refreshes when the shortcuts change the preference', () async {
    // The ⌘⇧-/⌘⇧= shortcuts mutate this from outside the panel, so an open
    // Settings screen has to notice. `_SettingsGroupForm` caches its elements
    // and rebuilds off the group's listenable.
    final settings = await freshSettings();
    final general = await group(settings);
    expect(general.listenable, same(settings));

    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setDensityPreference(DensityPreference.densest);
    expect(notified, 1);
  });
}
