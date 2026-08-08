// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `disabledSpotSources` is the contract between the Spots Panel (which
// persists the filter) and the spots status reporter (which subtracts it
// from outage messages). Both sides are injected in their own tests, so
// only this file catches the two drifting apart: a renamed key or a
// reshaped slice would otherwise silently revert the reporter to nagging
// about sources the operator switched off.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> settingsWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    return SettingsService(await SharedPreferences.getInstance());
  }

  test('disabledSpotSources reads back what the panel persists', () async {
    final settings = await settingsWith({});
    // Through the same write the panel uses, not a hand-planted pref: the
    // key and shape under test are exactly the ones production writes.
    await settings.setSpottingFilters({
      'bandFilter': 'auto',
      'disabledSources': ['sota', 'pota'],
    });

    expect(settings.disabledSpotSources, {'sota', 'pota'});
  });

  test('no persisted filters means nothing disabled', () async {
    final settings = await settingsWith({});
    expect(settings.disabledSpotSources, isEmpty);
  });

  test('a wrong-typed slice reads as nothing disabled instead of throwing', () async {
    // The reporter's whole evaluation — retraction included — runs behind
    // this read. A throw here would pin an already-posted outage message
    // for the session, so tolerance is the contract.
    final settings = await settingsWith({
      'spottingFilters': jsonEncode({'disabledSources': 'sota'}),
    });
    expect(settings.disabledSpotSources, isEmpty);

    final mixed = await settingsWith({
      'spottingFilters': jsonEncode({'disabledSources': ['sota', 7]}),
    });
    expect(mixed.disabledSpotSources, {'sota'});
  });
}
