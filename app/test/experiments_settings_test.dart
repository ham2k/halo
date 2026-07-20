// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The experiments state contract on SettingsService: enabling stamps
// firstEnabledAtMillis exactly once (an experiment's "first tried" date must
// survive later toggles), disabling stamps lastDisabledAtMillis every time,
// and state for experiments no longer in the catalog is kept — the catalog
// defines what CAN toggle, the state remembers what DID.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
  });

  test('enable/disable round-trip with date stamps', () async {
    expect(settings.experimentEnabled('layouts'), isFalse);

    await settings.setExperimentEnabled('layouts', true);
    expect(settings.experimentEnabled('layouts'), isTrue);
    final state = (settings.experimentStates['layouts'] as Map).cast<String, dynamic>();
    final firstEnabled = state['firstEnabledAtMillis'] as int;
    expect(state['lastDisabledAtMillis'], isNull);

    await settings.setExperimentEnabled('layouts', false);
    expect(settings.experimentEnabled('layouts'), isFalse);
    final disabled = (settings.experimentStates['layouts'] as Map).cast<String, dynamic>();
    expect(disabled['firstEnabledAtMillis'], firstEnabled, reason: 'first-enabled stamp never moves');
    expect(disabled['lastDisabledAtMillis'], isA<int>());

    // Re-enabling keeps the ORIGINAL first-enabled stamp.
    await settings.setExperimentEnabled('layouts', true);
    final reenabled = (settings.experimentStates['layouts'] as Map).cast<String, dynamic>();
    expect(reenabled['firstEnabledAtMillis'], firstEnabled);
  });

  test('state persists for experiments no longer in the catalog', () async {
    await settings.setExperimentEnabled('retired', true);
    await settings.setExperimentEnabled('layouts', true);
    // Nothing prunes 'retired' just because the catalog stopped listing it —
    // the count is what filters to the current catalog instead.
    expect(settings.experimentEnabled('retired'), isTrue);
    expect(settings.enabledExperimentCount(['layouts']), 1);
    expect(settings.enabledExperimentCount(['layouts', 'retired']), 2);
  });
}
