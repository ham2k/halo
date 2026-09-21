// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What `ExtensionService.sendSpot` puts on the wire as the mode. The VFO
// holds a resolved sideband, so without this every phone self-spot reaches
// POTA, WWFF and the GMA family as `USB` or `LSB` where every other spotter
// says `SSB`. The rule is `displayMode`'s — see `docs/design/cat.md`
// §"Showing it back" — and the trap is that it has to reach BOTH spot paths:
// spotting someone else's QSO carries no `mode` argument at all, so the
// posters read it off the QSO this builds.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';

import '../support/fake_extension_host.dart';

const _source = [
  {'hookKey': 'pota'}
];

const _operation = {'stationCall': 'N0DEV'};

/// Captures the args one `spots` hook is called with.
({ExtensionService service, List<Map<String, dynamic>> calls}) serviceCapturing(String method) {
  final calls = <Map<String, dynamic>>[];
  final host = FakeExtensionHost({
    'spots:pota:$method': (Object? args) {
      calls.add((args as Map).cast<String, dynamic>());
      return {'ok': true};
    },
  });
  return (service: ExtensionServiceWithFakeHost(host), calls: calls);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a self-spot on the sideband its band runs goes out as SSB', () async {
    // The whole point. 40 m phone is logged and transmitted as LSB, and a
    // board full of `SSB` spots with one `LSB` among them reads as a
    // different mode rather than as the same operator on the same band.
    final captured = serviceCapturing('postSelfSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      freq: 7185,
      mode: 'LSB',
    );

    expect(captured.calls.single['mode'], 'SSB');
  });

  test('a self-spot on the sideband its band does NOT run still says so', () async {
    // The one fact a reader cannot derive from the frequency beside it, so
    // it is the one the spot has to carry. Collapsing this to `SSB` would
    // send every reader to the wrong sideband.
    final captured = serviceCapturing('postSelfSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      freq: 14250,
      mode: 'LSB',
    );

    expect(captured.calls.single['mode'], 'LSB');
  });

  test('a self-spot on a non-voice mode is untouched', () async {
    // The rule is about sidebands only. Anything that folded `FT8` or `CW`
    // would be spotting a mode nobody is on.
    final captured = serviceCapturing('postSelfSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      freq: 7074,
      mode: 'FT8',
    );

    expect(captured.calls.single['mode'], 'FT8');
  });

  test("spotting someone else's QSO normalizes the mode on the QSO itself", () async {
    // The path with no `mode` argument to fix: each poster reads `qso.mode`
    // JS-side, so the QSO sent has to already carry the spotted mode. A fix
    // applied only to the self-spot argument leaves this one posting `USB`.
    final captured = serviceCapturing('postOtherSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      qso: {
        'freq': 14250.0,
        'band': '20m',
        'mode': 'USB',
        'their': {'call': 'K1ABC'}
      },
    );

    final qso = (captured.calls.single['qso'] as Map).cast<String, dynamic>();
    expect(qso['mode'], 'SSB');
    expect(qso['their'], {'call': 'K1ABC'}, reason: 'the rest of the QSO reaches the poster intact');
  });

  test('a QSO stating only a band is normalized against that band', () async {
    // A spot derived from an edited contact can reach here with no
    // frequency. The band answers on its own, and reading only `freq` would
    // fall through to `SSB` for a deliberate far sideband — silently
    // dropping the one case worth spelling out.
    final captured = serviceCapturing('postOtherSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      qso: {'band': '20m', 'mode': 'LSB'},
    );

    expect(((captured.calls.single['qso'] as Map)['mode']), 'LSB');
  });

  test('a QSO whose frequency arrived as a string still spots, and spots correctly', () async {
    // A QSON blob is probed, never cast — the shape `asQsonNum` exists for,
    // and one polo and older ADIF imports really produce. A hard cast here
    // sits OUTSIDE the per-source guard, so it would not fail one source: it
    // would throw the whole spot away with a raw TypeError.
    final captured = serviceCapturing('postOtherSpot');

    await captured.service.sendSpot(
      sources: _source,
      operation: _operation,
      qso: {'freq': '7185', 'mode': 'LSB'},
    );

    expect(((captured.calls.single['qso'] as Map)['mode']), 'SSB');
  });
}
