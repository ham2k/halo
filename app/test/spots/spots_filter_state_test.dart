// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots panel's filters, driven without a panel: what is restored, what
// is saved, and which outside changes are worth a rebuild of the list.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spot_board.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _spot(String call, {String band = '20m', double freq = 14250, String mode = 'SSB', int ageMinutes = 1}) => {
  'their': {'call': call},
  'freq': freq,
  'band': band,
  'mode': mode,
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - ageMinutes * 60000, 'source': 'test'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late int notified;

  Future<SpotsFilterState> makeState({Map<String, dynamic>? stored}) async {
    services = (await makeHaLoServices()).services;
    if (stored != null) await services.settings.setSpottingFilters(stored);
    final state = SpotsFilterState(settings: services.settings, radio: services.radio);
    notified = 0;
    state.addListener(() => notified++);
    addTearDown(state.dispose);
    return state;
  }

  group('saved filters', () {
    test('come back as they were left', () async {
      final state = await makeState(
        stored: {
          'bandFilter': '40m',
          'modeFilter': 'CW',
          'ageMinutes': 30,
          'disabledSources': ['pota'],
          'disabledContinents': ['EU'],
          'sortBy': 'time',
          'groupByBand': false,
          'groupCallsWithNotes': true,
        },
      );

      expect(state.bandFilter, '40m');
      expect(state.modeFilter, 'CW');
      expect(state.ageMinutes, 30);
      expect(state.disabledSources, {'pota'});
      expect(state.disabledContinents, {'EU'});
      expect(state.sortBy, 'time');
      expect(state.groupByBand, isFalse);
      expect(state.groupCallsWithNotes, isTrue);
    });

    // Every change is saved as it is made: the panel has no "done" moment to
    // save at, and an extension's `getSpots` reads the same settings.
    test('every change is shown at once and saved for the next session', () async {
      final state = await makeState();
      state.setBandFilter('15m');
      state.setModeFilter('CW');
      state.setAgeMinutes(15);
      state.setSortBy('time');
      state.setGroupByBand(false);
      state.setGroupCallsWithNotes(true);
      state.toggleSource('sota');
      state.toggleContinent('AS');
      expect(notified, 8);
      await pumpEventQueue();

      final restored = SpotsFilterState(settings: services.settings, radio: services.radio);
      addTearDown(restored.dispose);
      expect(restored.filters.bandFilter, '15m');
      expect(restored.filters.modeFilter, 'CW');
      expect(restored.filters.ageMinutes, 15);
      expect(restored.filters.sortBy, 'time');
      expect(restored.filters.groupByBand, isFalse);
      expect(restored.filters.groupCallsWithNotes, isTrue);
      expect(restored.filters.disabledSources, {'sota'});
      expect(restored.filters.disabledContinents, {'AS'});
    });

    test('a source or continent toggled twice is back on', () async {
      final state = await makeState();
      state.toggleSource('sota');
      state.toggleSource('sota');
      state.toggleContinent('AS');
      state.toggleContinent('AS');
      await pumpEventQueue();

      expect(state.disabledSources, isEmpty);
      expect(state.disabledContinents, isEmpty);
      expect(SpotBoardFilters.fromSettings(services.settings).disabledSources, isEmpty);
    });
  });

  group('outside changes', () {
    // A CAT feed moves the frequency many times a second; each notify
    // re-runs the merge and filter pipeline over the whole board.
    test('the VFO moving within its band and mode costs nothing', () async {
      final state = await makeState();
      services.radio.setVfo('vfoA', freq: 14074, mode: 'FT8');
      final settled = notified;

      services.radio.setVfo('vfoA', freq: 14075);
      expect(notified, settled);

      services.radio.setVfo('vfoA', freq: 7074);
      expect(notified, settled + 1, reason: 'the "auto" band follows the VFO');
      services.radio.setVfo('vfoA', mode: 'CW');
      expect(notified, settled + 2, reason: 'the "auto" mode follows the VFO');
      expect(state.bandFilter, 'auto');
    });

    // Every settings write notifies, this state's own saves included; only
    // the band list reaches the filters.
    test('only an edit to the band list is worth a rebuild', () async {
      final state = await makeState();
      state.setSortBy('time');
      await pumpEventQueue();
      expect(notified, 1, reason: 'its own save notified the settings, and that is not a change');

      await services.settings.setSettingValue(SettingsService.loggingGroup, 'bands', ['20m', '40m']);
      expect(notified, 2);
      expect(state.enabledBands, {'20m', '40m'});
    });

    test('nothing reaches it once disposed', () async {
      services = (await makeHaLoServices()).services;
      final state = SpotsFilterState(settings: services.settings, radio: services.radio);
      state.dispose();

      // A listener left on either notifies a disposed ChangeNotifier, which
      // asserts — and the notifier that calls it catches that and reports it
      // rather than throwing, so the report is what has to be watched.
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      services.radio.setVfo('vfoA', freq: 7074);
      await services.settings.setSettingValue(SettingsService.loggingGroup, 'bands', ['20m']);
      expect(reported, isEmpty);
    });
  });

  group('what the panel shows', () {
    // The pinned self section exists to get back to where the operator
    // announced themselves — which is exactly when the filters would hide it.
    test("the operation's own spots are kept whatever the filters hide", () async {
      final state = await makeState(stored: {'bandFilter': '40m', 'modeFilter': 'any'});
      final own = _spot('N0CALL', ageMinutes: 5);
      final ownNewer = _spot('N0CALL/P', freq: 14260, ageMinutes: 2);
      final other = _spot('K1ABC', band: '40m', freq: 7200);

      final summary = state.summarize([own, ownNewer, other], ourBaseCalls: {'N0CALL'}, continentOf: (_) => null);

      expect(summary.selfSpots, [ownNewer, own], reason: 'newest first');
      expect(summary.filtered.map((s) => (s['their'] as Map)['call']), ['K1ABC']);
    });

    test('a band left out of Settings › Bands leaves the list', () async {
      final state = await makeState(stored: {'bandFilter': 'any', 'modeFilter': 'any'});
      await services.settings.setSettingValue(SettingsService.loggingGroup, 'bands', ['40m']);

      final summary = state.summarize(
        [_spot('K1ABC'), _spot('W2XYZ', band: '40m', freq: 7200)],
        ourBaseCalls: const {},
        continentOf: (_) => null,
      );

      expect(summary.filtered.map((s) => (s['their'] as Map)['call']), ['W2XYZ']);
    });

    test('a switched-off source is left out before anything is merged or counted', () async {
      final state = await makeState();
      state.toggleSource('sota');
      final bySource = {
        'pota': [_spot('K1ABC')],
        'sota': [_spot('W2XYZ', freq: 14300)],
      };

      expect(state.rawSpots(bySource).map((s) => (s['their'] as Map)['call']), ['K1ABC']);
      expect(state.mergedSpots(bySource).map((s) => (s['their'] as Map)['call']), ['K1ABC']);
    });

    test('isSingleBandFilter is false for the two filters that span bands', () async {
      final state = await makeState();
      expect(state.isSingleBandFilter, isFalse);
      state.setBandFilter('any');
      expect(state.isSingleBandFilter, isFalse);
      state.setBandFilter('20m');
      expect(state.isSingleBandFilter, isTrue);
    });
  });

  group('the filter dialog counts', () {
    // "Phone/CW" is offered as one choice, so it counts both.
    test('phone and CW spots also count toward Phone/CW', () {
      final counts = spotModeCounts([_spot('A'), _spot('B', mode: 'CW'), _spot('C', mode: 'FT8')]);
      expect(counts['Phone'], 1);
      expect(counts['CW'], 1);
      expect(counts[phoneCwModeFilter], 2);
      expect(counts['Digital'], 1);
    });

    test('each age counts the spots at most that old', () {
      final counts = spotAgeCounts([_spot('A', ageMinutes: 10), _spot('B', ageMinutes: 20), _spot('C', ageMinutes: 45)]);
      expect(counts[15], 1);
      expect(counts[30], 2);
      expect(counts[60], 3);
    });

    test('bands and continents are counted, and a spot with neither is not', () {
      final spots = [
        _spot('K1ABC'),
        _spot('JA1XYZ', band: '40m', freq: 7200),
        {..._spot('NOBAND')}..remove('band'),
      ];
      expect(spotBandCounts(spots), {'20m': 1, '40m': 1});
      expect(spotContinentCounts(spots, (call) => call == 'JA1XYZ' ? 'AS' : (call == 'K1ABC' ? 'NA' : null)), {'NA': 1, 'AS': 1});
    });

    // Call info is keyed by the normalised call the filter tests; a count
    // read off the raw field would disagree with what the filter keeps.
    test('continents are counted per operator, as the filter reads them', () {
      final spots = [_spot('k1abc/p'), _spot('W2XYZ,JA1XYZ'), _spot('W3AAA,W4BBB')];
      const continents = {'K1ABC/P': 'NA', 'W2XYZ': 'NA', 'JA1XYZ': 'AS', 'W3AAA': 'NA', 'W4BBB': 'NA'};
      expect(spotContinentCounts(spots, (call) => continents[call]), {'NA': 3, 'AS': 1}, reason: 'one count per continent per spot');
    });
  });
}
