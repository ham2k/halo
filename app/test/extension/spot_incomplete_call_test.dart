// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A call logged with a `?` in it is one the operator did not fully copy, and
// every spot poster would send it as typed to a network other operators chase
// from. The refusal is the host's, in the one place both spot paths (the
// Spotting control and the SPOT commands) ask which sources are on offer —
// so no catalog poster has to know about it.

import 'package:flutter_test/flutter_test.dart';

import '../support/fake_extension_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final asked = <Object?>[];
  final service = ExtensionServiceWithFakeHost(
    FakeExtensionHost({
      'spots:*:isOtherSpotEnabled': (Object? args) {
        asked.add(args);
        return [
          {
            'key': 'pota',
            'ok': true,
            'value': {'enabled': true, 'label': 'POTA'},
          },
        ];
      },
    }),
  );

  setUp(asked.clear);

  Map<String, dynamic> qso(String call) => {
    'their': {'call': call},
    'freq': 14250.0,
    'mode': 'SSB',
  };

  test('a QSO with an incomplete call is offered no source to spot it on, and no poster is asked', () async {
    expect(await service.suggestSpotSources(operation: const {}, qso: qso('K1A?C')), isEmpty);
    expect(asked, isEmpty);
  });

  test('a complete call is offered the sources as before', () async {
    final sources = await service.suggestSpotSources(operation: const {}, qso: qso('K1ABC'));
    expect(sources.map((s) => s['hookKey']), ['pota']);
  });
}
