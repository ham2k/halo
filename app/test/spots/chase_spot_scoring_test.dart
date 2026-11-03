// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
//
// Chasing's stand-in operation has no stored log to read by operation ID.
// The shipped scorers must see the station and period's filtered contacts
// through the board's checkpoints, or every spot reads as unworked forever.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/spot_board.dart';
import 'package:ham2k_logger/services/spot_board_service.dart' show SpotScore;

import '../support/halo_test_support.dart';

Map<String, dynamic> _spot(String call, {String band = '20m', String mode = 'CW', String? park}) => {
  'their': {'call': call},
  'band': band,
  'mode': mode,
  'refs': [
    if (park != null) {'type': 'pota', 'ref': park},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chasing strikes logged spots and restores them after corrections, without hiding a new band, mode or park', () async {
    final harness = await makeHaLoServices(extensions: ExtensionService());
    final services = harness.services;
    await startWithShippedExtensions(harness.extensions);
    final operation = Operation(uuid: '', data: const {'stationCall': 'N1RWJ'});
    final now = nowMillis();
    final board = {
      'workedPark': _spot('K1NW', park: 'US-6987'),
      'otherStation': _spot('W4LOO'),
      'newBand': _spot('K1NW', band: '40m', park: 'US-6987'),
      'newMode': _spot('K1NW', mode: 'SSB', park: 'US-6987'),
      'newPark': _spot('K1NW', park: 'US-3654'),
    };
    final candidates = {
      for (final spot in board.values)
        spotCandidateKey((spot['their'] as Map)['call'] as String, spot): spotCandidateQso((spot['their'] as Map)['call'] as String, spot, now: now),
    };

    Future<Qso> log(String station, String key, int at) => services.qsos.add('', {
      ...board[key]!,
      'our': {'call': station},
      'startAtMillis': at,
    });

    Future<Map<String, bool>> worked(List<Qso> shown) async {
      final scored = await harness.extensions.scoreCandidates(
        operation: operation.data,
        operationUuid: '',
        candidates: candidates,
        resumesFor: (scorers) => services.scoring.candidateResumesFor(operation, shown, scorers),
      );
      expect(scored, isNotNull, reason: 'the shipped scorers must answer');
      final scores = <String, SpotScore>{
        for (final MapEntry(:key, :value) in scored!.entries)
          key: services.chase.withNotices((notices: value['notices'] ?? const [], alerts: value['alerts'] ?? const []), const [], chasing: true),
      };
      return {for (final MapEntry(:key, value: spot) in board.entries) key: spotDisplayFlags(spot, scores: scores).worked};
    }

    // The loose bucket contains other stations and older contacts too; they
    // must not enter the checkpoint merely because they share its empty ID.
    await log('W1AW', 'otherStation', now - 1000);
    await log('N1RWJ', 'otherStation', now - const Duration(days: 1).inMilliseconds);
    final first = await log('N1RWJ', 'workedPark', now);
    expect(await worked([first]), {'workedPark': true, 'otherStation': false, 'newBand': false, 'newMode': false, 'newPark': false});

    final second = await log('N1RWJ', 'otherStation', now + 1000);
    expect((await worked([first, second]))['otherStation'], isTrue, reason: 'a newly logged station strikes before any operation rescore');

    await services.qsos.update(
      Qso(
        uuid: first.uuid,
        operationUuid: '',
        data: {
          ...first.data,
          'their': {'call': 'K2XYZ'},
        },
      ),
    );
    final edited = (await services.qsos.forOperation('')).firstWhere((qso) => qso.uuid == first.uuid);
    final afterEdit = await worked([edited, second]);
    expect(afterEdit['workedPark'], isFalse, reason: 'correcting a logged callsign must restore its old spot');
    expect(afterEdit['otherStation'], isTrue);

    await services.qsos.softDelete(second);
    final deleted = (await services.qsos.forOperation('', includeDeleted: true)).firstWhere((qso) => qso.uuid == second.uuid);
    expect((await worked([edited, deleted]))['otherStation'], isFalse, reason: 'a deleted contact must restore its spot, even while Show deleted QSOs is on');
    expect((await worked(const [])).values, everyElement(isFalse), reason: 'an empty period has no worked spots');
  });
}
