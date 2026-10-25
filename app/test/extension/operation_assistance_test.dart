// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation that rules out assistance or self-spotting — the operator's
// own switch, or a contest ref's rules — is enforced at the hook boundary, so
// no extension has to know about it: every lookup is asked to stay local, and
// no source is even asked to self-spot. Spotting somebody else is neither, and
// must keep working under both.

import 'package:flutter_test/flutter_test.dart';

import '../support/fake_extension_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final lookups = <Map<dynamic, dynamic>>[];
  final spotQuestions = <String>[];
  Object? offered(String method) {
    spotQuestions.add(method);
    return [
      {
        'key': 'pota',
        'ok': true,
        'value': {'enabled': true, 'label': 'POTA'},
      },
    ];
  }

  final service = ExtensionServiceWithFakeHost(
    FakeExtensionHost({
      'lookupService:core:lookupCallInfo': (Object? args) {
        lookups.add(args! as Map);
        return {'lookups': const [], 'guess': const {}};
      },
      'spots:*:isSelfSpotEnabled': (Object? _) => offered('self'),
      'spots:*:isOtherSpotEnabled': (Object? _) => offered('other'),
    }),
  );

  setUp(() {
    lookups.clear();
    spotQuestions.clear();
  });

  const allowed = <String, dynamic>{'stationCall': 'KI2D'};
  const switchedOff = <String, dynamic>{'stationCall': 'KI2D', 'assistance': false, 'selfSpotting': false};
  const contest = <String, dynamic>{
    'stationCall': 'KI2D',
    'refs': [
      {'type': 'cqww', 'assistance': false, 'selfSpotting': false},
    ],
  };

  Map<String, dynamic> qso(String call) => {
    'their': {'call': call},
    'freq': 14250.0,
    'mode': 'SSB',
  };

  group('lookups', () {
    test('go online for an operation that allows assistance', () async {
      await service.lookupCall('K1ABC', qso: const {}, operation: allowed);
      expect(lookups.single['online'], isTrue);
    });

    for (final (label, operation) in [('switched off', switchedOff), ('ruled out by a ref', contest)]) {
      test('stay local when assistance is $label, even when asked to go online', () async {
        // The caller asking for `online: true` is the background enrichment
        // queue and the logging panel's second pass alike; neither is to
        // reach QRZ for this operation.
        await service.lookupCall('K1ABC', qso: const {}, operation: operation, online: true);
        expect(lookups.single['online'], isFalse);
      });
    }
  });

  group('a lookup confirmed despite assistance being off', () {
    test('goes online', () async {
      await service.lookupCallDespiteAssistance('K1ABC', qso: const {}, operation: contest);
      expect(lookups.single['online'], isTrue);
    });

    test('still stays local when asked to', () async {
      // Only the assistance rule is waived; a caller's own offline pass is not
      // turned into a network one.
      await service.lookupCallDespiteAssistance('K1ABC', qso: const {}, operation: contest, online: false);
      expect(lookups.single['online'], isFalse);
    });
  });

  group('spot sources', () {
    test('are offered for a self-spot when the operation allows it', () async {
      expect((await service.suggestSpotSources(operation: allowed)).map((s) => s['hookKey']), ['pota']);
    });

    for (final (label, operation) in [('switched off', switchedOff), ('ruled out by a ref', contest)]) {
      test('are not even asked about a self-spot when self-spotting is $label', () async {
        expect(await service.suggestSpotSources(operation: operation), isEmpty);
        expect(spotQuestions, isEmpty);
      });

      test('still offer spotting somebody else when self-spotting is $label', () async {
        final sources = await service.suggestSpotSources(operation: operation, qso: qso('K1ABC'));
        expect(sources.map((s) => s['hookKey']), ['pota']);
      });
    }
  });
}
