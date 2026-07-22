// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/dev_fixture.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stubbedLookupResult', () {
    test('is deterministic and shaped like the real {guess, lookups} result', () {
      final a = stubbedLookupResult('w1aw');
      final b = stubbedLookupResult('W1AW');
      expect(a, b); // case-insensitive, so identical for the same call

      final guess = a['guess'] as Map;
      expect(guess['call'], 'W1AW');
      expect(guess['grid'], 'FN31pr');
      expect(guess['entityName'], 'United States');
      expect((a['lookups'] as List).single['source'], 'stub');
    });
  });

  test('fixtureQsos anchors timestamps to the base, oldest first', () {
    final seeds = fixtureQsos(1_000_000);
    expect(seeds.map((q) => (q['their'] as Map)['call']), ['W1AW', 'K2HAM', 'VE3ABC']);
    final times = seeds.map((q) => q['startAtMillis'] as int).toList();
    expect(times, [880000, 940000, 1000000]); // strictly increasing, within `base`
  });

  test('resetDevFixture wipes existing state, seeds the fixture, and resets known settings', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(db, settings);

    // Pre-existing clutter + non-default UI state the reset must clear.
    final stale = await services.operations.create(stationCall: 'OLD', title: 'Stale');
    await services.qsos.add(stale.uuid, {
      'their': {'call': 'ZZ9ZZ'},
      'startAtMillis': 1,
    });
    await services.settings.setFontScale(FontScale.largest);
    await services.settings.setDistanceUnits(DistanceUnits.miles);

    final result = await resetDevFixture(services);

    // Exactly the fixture operation remains, with the seed QSOs.
    final ops = await services.operations.watchAll().first;
    expect(ops, hasLength(1));
    expect(ops.single.uuid, result['uuid']);
    final qsoRows = await services.db.select(services.db.qsos).get();
    expect(qsoRows, hasLength(3));

    // The pre-reset data was backed up (recoverable), not hard-deleted.
    expect(result['backupId'], isNotNull);
    final opBackup = await services.db.select(services.db.operationsBackup).get();
    expect(opBackup.map((r) => r.uuid), contains(stale.uuid));
    final qsoBackup = await services.db.select(services.db.qsosBackup).get();
    expect(qsoBackup, hasLength(1)); // the one stale QSO
    expect(opBackup.every((r) => r.backupId == result['backupId']), isTrue);

    // Known UI state restored.
    expect(services.settings.fontScale, FontScale.normal);
    expect(services.settings.distanceUnits, DistanceUnits.kilometers);

    expect(result['qsoCount'], 3);
  });
}
