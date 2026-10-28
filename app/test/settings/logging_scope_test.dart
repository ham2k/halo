// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingScope: the Chasing view arranges its logging panel apart from every
// operation's — which fields show, which pills in what order — while how the
// operator logs stays shared. A leak either way is invisible until someone
// opens the other view and finds it rearranged.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/logging_scope.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/core_settings_groups.dart';
import 'package:ham2k_logger/settings/settings_scan.dart';

import '../support/halo_harness.dart';

Future<SettingsService> _freshSettings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsService(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Chasing view starts from the operation defaults, and a change to either leaves the other alone', () async {
    final settings = await _freshSettings();
    for (final key in loggingScopedKeys) {
      expect(settings.loggingDisplay(key, LoggingScope.chase), settings.loggingDisplay(key, LoggingScope.operation), reason: '$key starts the same in both');
    }
    expect(
      settings.loggingDisplay('showRSTFields', LoggingScope.operation),
      settings.showRSTFields,
      reason: 'the operation scope reads what operations always read',
    );

    await settings.setSettingValue(loggingGroupFor('showGridField', LoggingScope.chase), 'showGridField', true);
    expect(settings.loggingDisplay('showGridField', LoggingScope.chase), isTrue);
    expect(settings.showGridField, isFalse, reason: 'turning Grid on while chasing must not add it to every operation');

    await settings.setShowRSTFields(false);
    expect(settings.loggingDisplay('showRSTFields', LoggingScope.chase), isTrue, reason: 'and an operation hiding RST leaves the Chasing row as it was');
  });

  test('a setting about how the operator logs is shared, whichever scope writes it', () {
    expect(loggingGroupFor('jumpAfterRST', LoggingScope.chase), SettingsService.loggingGroup);
    expect(loggingGroupFor('defaultReportCW', LoggingScope.chase), SettingsService.loggingGroup);
    expect(loggingGroupFor('showRSTFields', LoggingScope.chase), chaseLoggingGroup);
  });

  test('each scope keeps its own pill order and hidden set', () async {
    final settings = await _freshSettings();
    await settings.setSecondaryControlsOrderFor(LoggingScope.chase, ['time', 'radio', 'pota/hunter', 'spotting', 'more']);
    await settings.setHiddenSecondaryControlsFor(LoggingScope.chase, {'notes'});

    expect(settings.secondaryControlsOrderFor(LoggingScope.chase), ['time', 'radio', 'pota/hunter', 'spotting', 'more']);
    expect(settings.hiddenSecondaryControlsFor(LoggingScope.chase), {'notes'});
    expect(settings.secondaryControlsOrder, isEmpty, reason: 'the operation row keeps its own (default) order');
    expect(settings.hiddenSecondaryControls, isEmpty);

    await settings.setSecondaryControlsOrderFor(LoggingScope.operation, ['more', 'time']);
    expect(settings.secondaryControlsOrder, ['more', 'time'], reason: 'the operation scope is the storage operations always had');
    expect(settings.secondaryControlsOrderFor(LoggingScope.chase).first, 'time');
  });

  test("the Chasing view's settings group shows and writes the Chasing copy, and the shared settings in place", () async {
    final settings = await _freshSettings();
    final chase = LoggingSettingsGroup(settings, scope: LoggingScope.chase);

    await chase.commit('showStateField', true);
    expect(settings.loggingDisplay('showStateField', LoggingScope.chase), isTrue);
    expect(settings.showStateField, isFalse, reason: 'the dialog opened from the Chasing log edits the Chasing copy');

    await chase.commit('jumpAfterRST', true);
    expect(settings.jumpAfterRST, isTrue, reason: 'a shared setting edited from the Chasing dialog is the shared one');

    final elements = await chase.buildElements();
    expect(elements.firstWhere((e) => e['key'] == 'showStateField')['value'], isTrue, reason: 'and the dialog shows the Chasing value, not the operation one');
  });

  // Show Deleted QSOs is scoped but lives in the User Interface group, which
  // the Chasing view has to override as well: without that, the toggle in
  // its tune dialog would hide deleted QSOs in every operation instead.
  test("the User Interface group's Chasing copy writes the Chasing Show Deleted QSOs, and the shared Show Deleted Operations", () async {
    final settings = await _freshSettings();
    final chase = GeneralSettingsGroup(settings, ExtensionService(), scope: LoggingScope.chase);

    await chase.commit('showDeletedQSOs', true);
    expect(settings.loggingDisplay('showDeletedQSOs', LoggingScope.chase), isTrue);
    expect(settings.loggingDisplay('showDeletedQSOs', LoggingScope.operation), isFalse);
    expect((await chase.buildElements()).firstWhere((e) => e['key'] == 'showDeletedQSOs')['value'], isTrue);

    await chase.commit('showDeletedOps', true);
    expect(settings.showDeletedOps, isTrue, reason: 'the Home list is one list, whichever view sets it');
  });

  // SET/SHOW/HIDE scan the registry with no overrides of their own. Without
  // the front overrides, HIDE RST typed while chasing would report success
  // and hide RST in every OPERATION instead.
  test('settings commands follow the Chasing copy while Chasing is in front, and never with an operation open over it', () async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    final owner = Object();
    frontSettingsOverrides.set(owner, {'logging': LoggingSettingsGroup(settings, scope: LoggingScope.chase)});
    addTearDown(() => frontSettingsOverrides.clear(owner));

    final scanned = (await scanSettings(services)).firstWhere((s) => s.key == 'showGridField');
    await scanned.group!.commit('showGridField', true);
    expect(settings.loggingDisplay('showGridField', LoggingScope.chase), isTrue);
    expect(settings.showGridField, isFalse);

    final context = services.openOperationContext('op-1');
    addTearDown(() => services.closeOperationContext(context));
    final overOperation = (await scanSettings(services)).firstWhere((s) => s.key == 'showGridField');
    await overOperation.group!.commit('showGridField', true);
    expect(settings.showGridField, isTrue, reason: 'an operation open on top is where the operator is logging');

    final other = Object();
    frontSettingsOverrides.clear(other);
    services.closeOperationContext(context);
    final stillChasing = (await scanSettings(services)).firstWhere((s) => s.key == 'showQsoNumbers');
    await stillChasing.group!.commit('showQsoNumbers', false);
    expect(settings.loggingDisplay('showQsoNumbers', LoggingScope.chase), isFalse, reason: "a view that never set them can't take another's overrides away");
    expect(settings.showQsoNumbers, isTrue);
  });
}
