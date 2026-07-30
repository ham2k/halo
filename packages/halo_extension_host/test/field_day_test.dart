// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL Field Day and Winter Field Day.
//
// The two are duplicates by choice (see either `scorer.ts`), which puts the
// burden here: nothing but these tests will notice if one drifts from the
// other on a rule they are supposed to share. So the shared rules are asserted
// against BOTH, and the differences are asserted as differences.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> hostFor(String key) => sharedHost([key], onHostCall: nullHostCall);

  /// A QSO carrying the contest's exchange ref.
  Map<String, dynamic> contestQso(
    String type,
    String call, {
    required String band,
    required String mode,
    String? theirClass,
    String? section,
    String? uuid,
    int day = 1,
  }) =>
      {
        'uuid': uuid ?? '$call-$band-$mode',
        'their': {'call': call},
        'band': band,
        'mode': mode,
        'startAtMillis': DateTime.utc(2026, 6, day, 18).millisecondsSinceEpoch,
        'refs': [
          {
            'type': type,
            if (theirClass != null) 'class': theirClass,
            if (section != null) 'location': section,
          },
        ],
      };

  Future<Map<String, dynamic>> score(
    ExtensionHost host,
    String type, {
    required Map<String, dynamic> setup,
    required List<Map<String, dynamic>> qsos,
  }) async {
    final ref = {'type': type, ...setup};
    final result = await host.invokeHook('scoring', key: type, method: 'scoreQsos', args: {
      'operation': {'uuid': 'op', 'stationCall': 'W1AW', 'refs': [ref]},
      'qsos': qsos,
      'ref': ref,
    }, timeout: const Duration(seconds: 20)) as Map;
    return result.cast<String, dynamic>();
  }

  Map<String, dynamic>? contestTally(Map<String, dynamic> result) =>
      ((result['operationSummary'] as Map?)?['contest'] as Map?)?.cast<String, dynamic>();

  group('the rules both contests share', () {
    for (final type in ['fd', 'wfd']) {
      test('$type: phone is one point, CW and data are two', () async {
        final host = await hostFor(type);
        final result = await score(host, type, setup: const {}, qsos: [
          contestQso(type, 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
          contestQso(type, 'K1BBB', band: '20m', mode: 'CW', uuid: 'b'),
          contestQso(type, 'K1CCC', band: '20m', mode: 'FT8', uuid: 'c'),
        ]);
        expect((result['qsoScores'] as Map)['a']['value'], 1);
        expect((result['qsoScores'] as Map)['b']['value'], 2);
        expect((result['qsoScores'] as Map)['c']['value'], 2);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('$type: the same station counts again on a new band or mode', () async {
        // The dupe rule is per band AND mode, which is what makes Field Day a
        // band-hopping contest. Getting this wrong either refuses real points
        // or awards points twice.
        final host = await hostFor(type);
        final result = await score(host, type, setup: const {}, qsos: [
          contestQso(type, 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
          contestQso(type, 'K1AAA', band: '40m', mode: 'SSB', uuid: 'b'),
          contestQso(type, 'K1AAA', band: '20m', mode: 'CW', uuid: 'c'),
          contestQso(type, 'K1AAA', band: '20m', mode: 'SSB', uuid: 'd'),
        ]);
        final scores = result['qsoScores'] as Map;
        expect(scores['b']['value'], 1, reason: 'new band');
        expect(scores['b']['notices'], contains('newBand'));
        expect(scores['c']['value'], 2, reason: 'new mode');
        expect(scores['c']['notices'], contains('newMode'));
        expect(scores['d']['value'], 0, reason: 'same band and mode');
        expect(scores['d']['dupe'], isTrue);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('$type: sections are tallied ARRL, RAC and other separately', () async {
        // Three tallies because the rules count them three ways. `DX` is a
        // valid thing to receive and is not a section.
        final host = await hostFor(type);
        final result = await score(host, type, setup: const {}, qsos: [
          contestQso(type, 'K1AAA', band: '20m', mode: 'SSB', section: 'ENY', uuid: 'a'),
          contestQso(type, 'VE3BBB', band: '20m', mode: 'SSB', section: 'ONS', uuid: 'b'),
          contestQso(type, 'G0CCC', band: '20m', mode: 'SSB', section: 'DX', uuid: 'c'),
        ]);
        expect(contestTally(result)!['longSummary'], contains('3 sections'));
      }, timeout: const Timeout(Duration(seconds: 60)));
    }
  });

  group('where they differ', () {
    test('BOTH exclude the WARC bands', () async {
      // This test used to assert that WFD scored 30m, which was wrong — both
      // contests exclude 12/17/30/60m. It is in the "shared rules" spirit now,
      // but kept here because the wrong version lived here and a reader
      // comparing the two files should land on the correction.
      for (final type in ['fd', 'wfd']) {
        final result = await score(await hostFor(type), type, setup: const {}, qsos: [
          contestQso(type, 'K1AAA', band: '30m', mode: 'CW', uuid: 'a'),
          contestQso(type, 'K1BBB', band: '20m', mode: 'CW', uuid: 'b'),
        ]);
        expect((result['qsoScores'] as Map)['a']['value'], 0, reason: '$type 30m');
        expect((result['qsoScores'] as Map)['a']['alerts'], contains('invalidBand'));
        expect((result['qsoScores'] as Map)['b']['value'], 2, reason: '$type 20m still counts');
      }
    }, timeout: const Timeout(Duration(seconds: 90)));

    test("FD's multiplier is power; QRP off batteries is five", () async {
      final host = await hostFor('fd');
      Future<int> totalWith(Map<String, dynamic> setup) async {
        final result = await score(host, 'fd', setup: setup, qsos: [
          contestQso('fd', 'K1AAA', band: '20m', mode: 'CW', uuid: 'a'),
        ]);
        return contestTally(result)!['total'] as int;
      }

      // 2 QSO points, times the multiplier.
      expect(await totalWith({'ourPower': '5W', 'ourPowerSource': 'BATTERIES'}), 10);
      expect(await totalWith({'ourPower': '5W', 'ourPowerSource': 'GENERATOR'}), 4);
      expect(await totalWith({'ourPower': '100W', 'ourPowerSource': 'GENERATOR'}), 4);
      expect(await totalWith({'ourPower': '500W', 'ourPowerSource': 'GENERATOR'}), 2);
      // Nothing declared is ×1, not ×0 — an unfinished setup must not zero a
      // real log.
      expect(await totalWith(const {}), 2);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group("FD's bonus checklist", () {
    test('the per-transmitter bonus needs emergency power, and is not doubled', () async {
      // This is the rule the first version got wrong in both directions: it
      // awarded 100/transmitter unconditionally AND again for emergency power.
      // The rules grant it only for running entirely on emergency power, once.
      final host = await hostFor('fd');
      Future<int> totalWith(Map<String, dynamic> setup) async {
        final result = await score(host, 'fd', setup: {'ourPower': '500W', ...setup}, qsos: [
          contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
        ]);
        return contestTally(result)!['total'] as int;
      }

      // 1 QSO point at x1 throughout, so the rest is bonus.
      expect(await totalWith({'bonusTransmitters': 3}), 1,
          reason: 'transmitters alone earn nothing without emergency power');
      expect(await totalWith({'bonusTransmitters': 3, 'bonusEmergencyPower': true}), 1 + 300,
          reason: '100 per transmitter, ONCE');
      // The rules cap it at 20 transmitters; a club may still record 25.
      expect(await totalWith({'bonusTransmitters': 25, 'bonusEmergencyPower': true}), 1 + 2000);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('the counted bonuses use their own rates and caps', () async {
      final host = await hostFor('fd');
      Future<int> totalWith(Map<String, dynamic> setup) async {
        final result = await score(host, 'fd', setup: {'ourPower': '500W', ...setup}, qsos: [
          contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
        ]);
        return contestTally(result)!['total'] as int;
      }

      expect(await totalWith({'bonusNTSMessages': 4}), 1 + 40, reason: '10 each');
      expect(await totalWith({'bonusNTSMessages': 40}), 1 + 100, reason: 'capped at 10 messages');
      expect(await totalWith({'bonusGotaQsos': 30}), 1 + 150, reason: '5 each, uncapped');
      expect(await totalWith({'bonusYouthParticipants': 2}), 1 + 40, reason: '20 each');
      expect(await totalWith({'bonusYouthParticipants': 9}), 1 + 100, reason: 'capped at 100');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('claimed bonuses are worth what the rules say, not a flat 100', () async {
      // Two of these are not 100, which is exactly what scoring them all as a
      // flat 100 got wrong.
      final host = await hostFor('fd');
      Future<int> totalWith(Map<String, dynamic> setup) async {
        final result = await score(host, 'fd', setup: {'ourPower': '500W', ...setup}, qsos: [
          contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
        ]);
        return contestTally(result)!['total'] as int;
      }

      expect(await totalWith(const {}), 1, reason: 'nothing claimed');
      expect(await totalWith({'bonusMediaPublicity': true}), 101);
      expect(await totalWith({'bonusWebSubmission': true}), 51, reason: 'web submission is 50');
      expect(await totalWith({'bonusSiteResponsibilities': true}), 51, reason: 'site duties are 50');
      expect(await totalWith({'bonusGotaCoach': true}), 101);
      expect(await totalWith({'bonusMediaPublicity': false}), 1, reason: 'unchecked is not a claim');
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('what the log carries', () {
    test('FD writes CONTEST_ID for every QSO of the operation', () async {
      // Keyed off the OPERATION, not the QSO: every contact made during a Field
      // Day operation is a Field Day contact, whether or not an exchange was
      // captured for it.
      final host = await hostFor('fd');
      final fields = await host.invokeHook('adifFields', key: 'fd', method: 'fieldsForOneQSO', args: {
        'qso': contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', theirClass: '2A', section: 'ENY'),
        'operation': {'refs': [{'type': 'fd', 'ourClass': '1D', 'ourSection': 'CT'}]},
      }, timeout: const Duration(seconds: 10)) as List;

      final flat = {for (final f in fields) (f as Map)['name']: f['value']};
      expect(flat, {'CONTEST_ID': 'ARRL-FIELD-DAY', 'CLASS': '2A', 'ARRL_SECT': 'ENY'});
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an operation that is not Field Day gets no Field Day fields', () async {
      final host = await hostFor('fd');
      final fields = await host.invokeHook('adifFields', key: 'fd', method: 'fieldsForOneQSO', args: {
        'qso': contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', theirClass: '2A'),
        'operation': const {'refs': []},
      }, timeout: const Duration(seconds: 10)) as List;
      expect(fields, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the Cabrillo line carries both stations, ours first', () async {
      final host = await hostFor('fd');
      final result = await host.invokeHook('export', key: 'fd', method: 'generateExport', args: {
        'exportType': 'cabrillo',
        'operation': {'stationCall': 'W1AW', 'refs': [{'type': 'fd', 'ourClass': '1D', 'ourSection': 'CT'}]},
        'qsos': [contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', theirClass: '2A', section: 'ENY')],
      }, timeout: const Duration(seconds: 20)) as Map;

      final content = result['content'] as String;
      // The registered CABRILLO name, not the ADIF CONTEST_ID — a checker does
      // not recognise 'ARRL-FIELD-DAY' in this header.
      expect(content, contains('CONTEST: ARRL-FD'));
      expect(content, contains('CALLSIGN: W1AW'));
      expect(content, contains('LOCATION: CT'));
      final qsoLine = content.split('\n').firstWhere((l) => l.startsWith('QSO:'));
      // ours: call class section, then theirs.
      expect(qsoLine, contains('W1AW'));
      expect(qsoLine, contains('1D'));
      expect(qsoLine, contains('K1AAA'));
      expect(qsoLine, contains('2A'));
      expect(qsoLine, contains('ENY'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the exchange controls', () {
    test('the section control ranks the sections in the caller\'s own call area', () async {
      // Ranking, never prefilling — §5.3 asks for that here because a guess
      // from a callsign is wrong often enough to be annoying.
      final host = await hostFor('fd');
      final controls = await host.invokeHook('activity', key: 'fd', method: 'loggingControls', args: {
        'operation': {'refs': [{'type': 'fd'}]},
        'qso': {'their': {'call': 'W1XYZ'}},
      }, timeout: const Duration(seconds: 10)) as List;

      final section = controls.cast<Map>().firstWhere((c) => c['key'] == 'fd/section');
      final input = section['input'] as Map;
      expect(input['kind'], 'options');
      // 14 RAC sections, not 15: RAC has made Yukon its own, but Field Day still
      // counts it inside TER, so YT is not a valid exchange here.
      expect((input['options'] as List).length, 85, reason: '71 ARRL + 14 RAC');
      // A W1 is in New England, not San Diego.
      expect(input['preferredCodes'], contains('EMA'));
      expect(input['preferredCodes'], isNot(contains('SDG')));
      // MX and DX are legal to receive and are not in the list.
      expect(input['allowFreeform'], isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a prefix that names its section outright wins over the call area', () async {
      // KL7 is Alaska and nothing else, so the call-area guess must not dilute
      // it with the whole of call area 7.
      final host = await hostFor('fd');
      final controls = await host.invokeHook('activity', key: 'fd', method: 'loggingControls', args: {
        'operation': {'refs': [{'type': 'fd'}]},
        'qso': {'their': {'call': 'KL7AA'}},
      }, timeout: const Duration(seconds: 10)) as List;

      final section = controls.cast<Map>().firstWhere((c) => c['key'] == 'fd/section');
      expect(((section['input'] as Map)['preferredCodes'] as List), ['AK']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the class control accepts a "please copy" prefix', () async {
      // `PC1A` is a legal exchange — a station asking you to copy the bulletin.
      // A pattern that refused it would tint every one of them as an error.
      final host = await hostFor('fd');
      final controls = await host.invokeHook('activity', key: 'fd', method: 'loggingControls', args: {
        'operation': {'refs': [{'type': 'fd'}]},
        'qso': {'their': {'call': 'W1XYZ'}},
      }, timeout: const Duration(seconds: 10)) as List;

      final klass = controls.cast<Map>().firstWhere((c) => c['key'] == 'fd/class');
      final pattern = RegExp((klass['input'] as Map)['pattern'] as String);
      expect(pattern.hasMatch('1A'), isTrue);
      expect(pattern.hasMatch('14F'), isTrue);
      expect(pattern.hasMatch('PC2B'), isTrue);
      expect(pattern.hasMatch('1Z'), isFalse);
      expect(pattern.hasMatch('0A'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('off-contest the controls contribute nothing', () async {
      final host = await hostFor('fd');
      final controls = await host.invokeHook('activity', key: 'fd', method: 'loggingControls', args: {
        'operation': const {'refs': []},
      }, timeout: const Duration(seconds: 10)) as List;
      expect(controls, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('finding them in the activity search', () {
    // Both events are found by name and ranked by nearness. The dates are a
    // RULE, not a data file, so this works for any year — including the ones
    // these tests will still be running in.
    Future<List<Map<String, dynamic>>> suggest(String key, String? term) async {
      final host = await hostFor(key);
      final result = await host.invokeHook('activity', key: key, method: 'suggest',
          args: {if (term != null) 'searchTerm': term},
          timeout: const Duration(seconds: 15)) as List;
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    test('an empty search offers both', () async {
      // Nothing typed is the nearby-suggestions case: the operator opened the
      // picker, and a contest that runs next weekend is worth surfacing.
      expect(await suggest('fd', null), hasLength(1));
      expect(await suggest('wfd', null), hasLength(1));
      expect(await suggest('fd', ''), hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('each is found by its own names', () async {
      for (final term in ['fd', 'FD', 'field day', 'FIELDDAY', 'arrl']) {
        expect(await suggest('fd', term), hasLength(1), reason: '"$term" should find FD');
      }
      for (final term in ['wfd', 'winter', 'Winter Field Day', 'winterfieldday']) {
        expect(await suggest('wfd', term), hasLength(1), reason: '"$term" should find WFD');
      }
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('"field day" finds BOTH — they are both field days', () async {
      // And so does "fd", since "WFD" contains it. Which one leads is left to
      // the date ranking rather than to the spelling.
      expect(await suggest('fd', 'field day'), hasLength(1));
      expect(await suggest('wfd', 'field day'), hasLength(1));
      expect(await suggest('wfd', 'fd'), hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('a search for something else finds neither', () async {
      // The picker fans out to every enabled extension, so a contest that
      // answered every query would push real hits down the list.
      for (final term in ['pota', 'US-0001', 'sota', 'zzz']) {
        expect(await suggest('fd', term), isEmpty, reason: 'FD should ignore "$term"');
        expect(await suggest('wfd', term), isEmpty, reason: 'WFD should ignore "$term"');
      }
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('the suggestion carries what the operation row will show', () async {
      // A suggestion is persisted VERBATIM and never runs through
      // `decorateRef`, so a missing label reads as a blank activity row.
      final suggestion = (await suggest('fd', 'field day')).single;
      expect(suggestion['type'], 'fd');
      expect(suggestion['shortLabel'], 'FD');
      expect(suggestion['name'], isNotEmpty);
      expect(suggestion['label'], contains(RegExp(r'20\d\d')));
      // The ref is the YEAR of the running — the picker's duplicate guard
      // compares type+ref, so without one the same event could be added twice.
      expect(suggestion['ref'], matches(RegExp(r'^20\d\d$')));
      expect(suggestion['relevance'], isA<num>());
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('what the review found', () {
    // Every test here pins a bug that shipped in the first version of these
    // extensions. They are grouped so the next reader can see, in one place,
    // what this port got wrong and what now holds it right.

    test('a day section reports THAT day, and counts the bonus once', () async {
      // Field Day always spans two UTC days, so this fires on every operation.
      // The first version reported the running total per day and re-added the
      // whole bonus to each one.
      final host = await hostFor('fd');
      final result = await score(host, 'fd', setup: {
        'ourPower': '500W', 'bonusTransmitters': 2, 'bonusEmergencyPower': true,
      }, qsos: [
        contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a', day: 27),
        contestQso('fd', 'K1BBB', band: '20m', mode: 'SSB', uuid: 'b', day: 28),
        contestQso('fd', 'K1CCC', band: '20m', mode: 'SSB', uuid: 'c', day: 28),
      ]);

      final days = (result['daySections'] as List).cast<Map>();
      expect(days, hasLength(2));
      int totalFor(int i) => ((days[i]['scores'] as Map)['contest'] as Map)['total'] as int;
      // Day one: its own 1 point. Day two: its own 2 — NOT the running 3.
      expect(totalFor(0), 1, reason: 'day one scores its own QSOs');
      expect(totalFor(1), 2, reason: 'day two scores its own, not the cumulative');
      // The 200-point bonus is claimed once for the entry, so it belongs to the
      // operation total and to neither day.
      expect(contestTally(result)!['total'], 3 + 200);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a QSO with no mode scores as phone, not as data', () async {
      // `superModeForMode('')` answers 'DATA', never nullish, so the original
      // `?? 'PHONE'` fallback was dead: a mode-less QSO scored 2 and dupe-keyed
      // as DATA, letting a later real SSB contact score again.
      final host = await hostFor('fd');
      final result = await score(host, 'fd', setup: const {}, qsos: [
        {
          'uuid': 'a', 'their': {'call': 'K1AAA'}, 'band': '20m', 'mode': '',
          'startAtMillis': DateTime.utc(2026, 6, 27, 18).millisecondsSinceEpoch,
          'refs': [{'type': 'fd'}],
        },
        contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'b', day: 27),
      ]);
      expect((result['qsoScores'] as Map)['a']['value'], 1, reason: 'phone rate, not the data rate');
      // It keeps its own dupe bucket rather than being silently filed as DATA:
      // we do not know the mode, so claiming it matches the later SSB contact
      // would be inventing a rule. What matters is that it is not worth 2.
      expect((result['qsoScores'] as Map)['b']['value'], 1,
          reason: 'the real SSB contact still scores on its own merits');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('WFD objectives carry their own weights, not one each', () async {
      // The whole multiplier for Winter Field Day, and it was flat-counted at
      // first — capping a well-equipped station at x8 instead of x33.
      final host = await hostFor('wfd');
      Future<int> totalWith(Map<String, dynamic> setup) async {
        final result = await score(host, 'wfd', setup: setup, qsos: [
          contestQso('wfd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a'),
        ]);
        return contestTally(result)!['total'] as int;
      }

      expect(await totalWith(const {}), 1, reason: 'x1 for taking part');
      expect(await totalWith({'objectiveAltPower': true}), 2, reason: 'x1');
      expect(await totalWith({'objectiveAwayFromHome': true}), 4, reason: 'x3');
      expect(await totalWith({'objectiveSixBands': true}), 7, reason: 'x6');
      expect(await totalWith({'objectiveQrp': true}), 5, reason: 'x4');
      // All twelve is the published maximum of 33.
      final all = {
        for (final k in [
          'objectiveAltPower','objectiveAwayFromHome','objectiveMultipleAntennas',
          'objectiveFmSatellite','objectiveSsbCwSatellite','objectiveWinlink',
          'objectiveSpecialBulletin','objectiveSixBands','objectiveTwelveBands',
          'objectiveMultipleModes','objectiveQrp','objectiveSixContinuousHours',
        ]) k: true,
      };
      expect(await totalWith(all), 33);
    }, timeout: const Timeout(Duration(seconds: 150)));

    test('WFD satellite contacts earn the multiplier but no QSO points', () async {
      final host = await hostFor('wfd');
      final result = await score(host, 'wfd', setup: const {}, qsos: [
        {
          'uuid': 'a', 'their': {'call': 'K1AAA'}, 'band': '2m', 'mode': 'SSB',
          'startAtMillis': DateTime.utc(2026, 1, 24, 19).millisecondsSinceEpoch,
          'refs': [{'type': 'wfd'}, {'type': 'satellite', 'ref': 'SO-50/145.85/fm'}],
        },
      ]);
      expect((result['qsoScores'] as Map)['a']['value'], 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('both add-paths give the ref the same identity', () async {
      // The worst of the lot: the setup form wrote no `ref` while `suggest`
      // wrote the year, so the picker's duplicate guard never matched and
      // adding from the search REPLACED a configured setup, silently losing
      // class, section, power and every bonus.
      final host = await hostFor('fd');
      final controls = await host.invokeHook('activity', key: 'fd', method: 'operationControls',
          args: {'operation': const {'refs': []}}, timeout: const Duration(seconds: 10)) as List;
      final elements = (((controls.single as Map)['input'] as Map)['form'] as Map)['elements'] as List;
      final refField = elements.cast<Map>().firstWhere(
          (e) => e['key'] == 'ref', orElse: () => throw StateError('the form must write `ref`'));
      final formYear = refField['value'] as String;

      final suggestions = await host.invokeHook('activity', key: 'fd', method: 'suggest',
          args: {'searchTerm': 'field day'}, timeout: const Duration(seconds: 10)) as List;
      expect((suggestions.single as Map)['ref'], formYear,
          reason: 'the form and the search must agree on which running this is');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the section notice is a key, and fires only on a new section', () async {
      // A display name pushed through the notice channel reaches a Spanish
      // operator in English and lands in the score cache that way.
      final host = await hostFor('fd');
      final result = await score(host, 'fd', setup: const {}, qsos: [
        contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', section: 'ENY', uuid: 'a'),
        contestQso('fd', 'K1BBB', band: '40m', mode: 'SSB', section: 'ENY', uuid: 'b'),
      ]);
      final scores = result['qsoScores'] as Map;
      expect(scores['a']['notices'], contains('newSection'));
      expect(scores['a']['notices'], isNot(contains('Eastern New York')));
      expect(scores['b']['notices'] ?? const [], isNot(contains('newSection')),
          reason: 'the second ENY contact is not news');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a DX callsign is not offered US sections', () async {
      final host = await hostFor('fd');
      Future<List> preferredFor(String call, String entity) async {
        final controls = await host.invokeHook('activity', key: 'fd', method: 'loggingControls', args: {
          'operation': {'refs': [{'type': 'fd'}]},
          'qso': {'their': {'call': call, 'entityPrefix': entity}},
        }, timeout: const Duration(seconds: 10)) as List;
        final section = controls.cast<Map>().firstWhere((c) => c['key'] == 'fd/section');
        return ((section['input'] as Map)['preferredCodes'] as List);
      }

      expect(await preferredFor('W1XYZ', 'K'), contains('EMA'));
      // Ontario is four sections, so offering one US guess was worse than none.
      expect(await preferredFor('VE3ABC', 'VE'), isEmpty);
      expect(await preferredFor('G0ABC', 'G'), isEmpty);
      // A prefix that names its section outright still wins.
      expect(await preferredFor('KL7AA', 'KL'), ['AK']);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('the exchange is written onto the QSO for the log column', () async {
      final host = await hostFor('fd');
      final patch = await host.invokeHook('activity', key: 'fd', method: 'processQsoBeforeSave', args: {
        'qso': contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', theirClass: '2A', section: 'ENY'),
        'operation': {'refs': [{'type': 'fd', 'ourClass': '1D'}]},
      }, timeout: const Duration(seconds: 10)) as Map?;
      expect((patch?['their'] as Map?)?['exchange'], '2A ENY');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('scores are rendered with thousands separators', () async {
      final host = await hostFor('fd');
      final result = await score(host, 'fd', setup: {
        'ourPower': '500W', 'bonusTransmitters': 20, 'bonusEmergencyPower': true,
      }, qsos: [contestQso('fd', 'K1AAA', band: '20m', mode: 'SSB', uuid: 'a')]);
      expect(contestTally(result)!['summary'], contains('2,001'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
