// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings Font Scale picker offers only the five everyday levels, but
// must still tell the truth when a keyboard shortcut has pushed the app into
// one of the four shortcut-only extremes: the nearest listed row takes the
// extreme's label ("Largest++") and selecting it commits the plain level it
// stands for. Without that, Settings would read "Largest" at 1.90 and there'd
// be no way back to a standard size except more shortcuts.

import 'package:flutter_test/flutter_test.dart';
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

  // The General group's buildElements only reads `settings`; the extension
  // service is just constructor ballast, so a start-suppressed stub is enough.
  Future<Map<String, dynamic>> fontScaleField(SettingsService settings) async {
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    final elements = await GeneralSettingsGroup(settings, extensions).buildElements();
    return elements.firstWhere((e) => e['key'] == 'fontScale');
  }

  List<Map<String, dynamic>> optionsOf(Map<String, dynamic> field) => (field['options'] as List).cast<Map<String, dynamic>>();

  test('picker lists exactly the five selectable levels, in order', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());

    final options = optionsOf(await fontScaleField(settings));
    expect(options.map((o) => o['value']), ['smallest', 'smaller', 'normal', 'larger', 'largest']);
    expect(options.map((o) => o['label']), ['Smallest', 'Smaller', 'Normal', 'Larger', 'Largest']);
  });

  test('at an extended scale the nearest row is relabelled and selected', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setFontScale(FontScale.largestPlusPlus);

    final field = await fontScaleField(settings);
    final options = optionsOf(field);

    // The Largest row now reads "Largest++" and is the selected value, so the
    // control reports 1.90 rather than silently showing "Largest".
    final largest = options.firstWhere((o) => o['value'] == 'largest');
    expect(largest['label'], 'Largest++');
    expect(field['value'], 'largest');
    expect(field['description'], 'Largest++');

    // The other rows are untouched, and no extra row appears for the extreme.
    expect(options.map((o) => o['value']), ['smallest', 'smaller', 'normal', 'larger', 'largest']);
    expect(options.where((o) => o['label'] == 'Largest'), isEmpty);
  });

  test('the low extreme relabels the Smallest row', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setFontScale(FontScale.smallestMinus);

    final options = optionsOf(await fontScaleField(settings));
    expect(options.firstWhere((o) => o['value'] == 'smallest')['label'], 'Smallest-');
  });
}
