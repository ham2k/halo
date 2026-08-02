// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-55: LoggingSettingsGroup's target tagging — the five toggles the old
// operation-view popup menu had must stay `target: 'logging'` (the
// tune-icon dialog's always-visible set); everything newer must be
// `target: 'logging-extended'` (behind that dialog's "show more settings").
// Mistagging a field here is silent everywhere else — it just quietly
// stops showing up in (or starts cluttering) the dialog.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/settings/core_settings_groups.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoggingSettingsGroup target tagging', () {
    const baseKeys = {'showRSTFields', 'showStateField', 'showGridField', 'showDeletedQSOs', 'showQsoNumbers'};

    test('exactly the five legacy toggles are target: "logging"', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();

      final loggingKeys = {
        for (final el in elements)
          if (elementMatchesTarget(el, 'logging')) el['key'] as String,
      };
      expect(loggingKeys, baseKeys);
    });

    test('every other declared field is target: "logging-extended", not left untargeted', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();

      for (final el in elements) {
        final key = el['key'] as String;
        if (baseKeys.contains(key)) continue;
        expect(
          elementMatchesTarget(el, 'logging-extended'),
          isTrue,
          reason: '"$key" is neither a base toggle nor tagged logging-extended — it would be unreachable '
              'from the tune-icon dialog entirely',
        );
      }
    });

    test('commit writes an extended boolean field through to SettingsService, same path as a base toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final group = LoggingSettingsGroup(settings);

      expect(settings.leftieMode, isFalse);
      await group.commit('leftieMode', true);
      expect(settings.leftieMode, isTrue);
    });
  });
}
