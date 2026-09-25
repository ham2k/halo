// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification of the SEED call-field command (dev-commands
// extension) against the real extension runtime AND real repositories:
// "SEED" defaults to 10 generated QSOs, "SEED 5" counts, "SEED 15 3H"
// spreads them over a time window ending now — or ending at the earliest
// existing QSO when the existing log spans less than a third of that
// window. The extension reads the existing log itself through the
// runtime's `ctx.getQsos` (backed by the `getQsos` host call and
// QsosRepository), so these tests also cover that whole path. Generated
// QSOs must look like real ones: callsign-shaped calls, RSTs shaped for
// the mode, and the lookup service's `their.guess` decoration.
//
// `interpret()` also runs on the call field's typing debounce for the live
// describe preview — not just once on submit — so the expensive part (the
// getQsos read and the per-QSO lookups) only runs when `execute: true` is
// passed, mirroring the host's real "about to actually run this" signal
// (ExtensionService.interpretCommand's `execute` param). Most tests below
// pass it explicitly to exercise full generation; the dedicated tests near
// the bottom cover the `execute: false`/omitted preview path itself.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late ExtensionService extensions;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    extensions = ExtensionService()
      ..lookups = LookupRepository(db)
      ..operations = operations
      ..qsos = qsos;
    await extensions.start();
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, dynamic>?> interpret(String input, {Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false}) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {'input': input, 'operation': ?operation, 'qso': ?qso, if (execute) 'execute': true},
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  /// A real operation row, so ctx.getQsos has something to read.
  Future<Map<String, dynamic>> makeOperation() async {
    final operation = await operations.create(stationCall: 'KI2D');
    // What the logging panel passes to interpret: QSON with uuid folded in.
    return {...operation.data, 'uuid': operation.uuid};
  }

  List<Map<String, dynamic>> addQsosOf(Map<String, dynamic> result) =>
      (result['commands'] as List).map((c) => ((c as Map)['addQso'] as Map).cast<String, dynamic>()).toList();

  group('SEED command interpretation (real dev-commands extension)', () {
    test('bare "SEED" seeds 10 QSOs with plausible calls, RSTs, and lookup guesses', () async {
      final result = await interpret('SEED', operation: await makeOperation(), execute: true);
      expect(result, isNotNull);
      // mixedCase (not expectsParams) is what keeps Space literal so the
      // command stays extendable to "SEED 15 3H" while already executable.
      expect(result!['mixedCase'], true);
      expect(result['expectsParams'], isNot(true));
      // SEED's calls are fabricated, so its own offline guess is all they'll
      // ever get — the host must not queue them for a real online lookup.
      expect(result['skipOnlineLookup'], true);

      final seeded = addQsosOf(result);
      expect(seeded.length, 10);
      int? previous;
      for (final qso in seeded) {
        final their = (qso['their'] as Map).cast<String, dynamic>();
        expect(their['call'], matches(RegExp(r'^[A-Z0-9]*\d[A-Z]+$')));
        expect(their['sent'], matches(RegExp(r'^[3-5][2-9]$'))); // SSB default
        expect(their['guess'], isA<Map>()); // lookup service decoration ran
        expect((qso['our'] as Map)['call'], 'KI2D');
        expect(qso['band'], '20m');
        expect(qso['mode'], 'SSB');
        final at = qso['startAtMillis'] as int;
        if (previous != null) expect(at, greaterThanOrEqualTo(previous));
        previous = at;
      }
      expect(previous, lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch));
    });

    test('"SEED 5" seeds 5, inheriting band/mode from the in-progress QSO (CW gets 3-digit RSTs)', () async {
      final result = await interpret('SEED 5', operation: await makeOperation(), qso: {'band': '40m', 'mode': 'CW', 'freq': 7030.0}, execute: true);
      final seeded = addQsosOf(result!);
      expect(seeded.length, 5);
      for (final qso in seeded) {
        expect(qso['band'], '40m');
        expect(qso['mode'], 'CW');
        expect(qso['freq'], 7030.0);
        expect((qso['their'] as Map)['sent'], matches(RegExp(r'^[3-5][2-9]9$')));
      }
    });

    test('"SEED 15 3H" spreads over the 3 hours up to now when the log is empty', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = await interpret('SEED 15 3H', operation: await makeOperation(), execute: true);
      final after = DateTime.now().millisecondsSinceEpoch;
      final seeded = addQsosOf(result!);
      expect(seeded.length, 15);
      for (final qso in seeded) {
        final at = qso['startAtMillis'] as int;
        expect(at, greaterThanOrEqualTo(before - 3 * 3600 * 1000));
        expect(at, lessThanOrEqualTo(after));
      }
    });

    test('"SEED 15 3H" backfills before the earliest QSO when the log spans under 1/3 of the spread', () async {
      final operation = await makeOperation();
      final uuid = operation['uuid'] as String;
      final now = DateTime.now().millisecondsSinceEpoch;
      final earliest = now - 30 * 60 * 1000;
      // An event marker even earlier than the QSOs — it rides the timeline
      // but must not anchor the backfill window.
      await qsos.addEvent(uuid, kind: 'start', atMillis: earliest - 5 * 60 * 1000);
      // 10 minutes of QSOs — well under an hour (a third of 3h). The
      // extension discovers them itself via ctx.getQsos.
      for (var i = 0; i < 4; i++) {
        await qsos.add(uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': earliest + i * 200 * 1000,
        });
      }
      final result = await interpret('SEED 15 3H', operation: operation, execute: true);
      expect(result!['describe'], contains('before your earliest QSO'));
      for (final qso in addQsosOf(result)) {
        final at = qso['startAtMillis'] as int;
        expect(at, lessThanOrEqualTo(earliest));
        expect(at, greaterThanOrEqualTo(earliest - 3 * 3600 * 1000));
      }
    });

    test('"SEED 15 3H" stays anchored to now when the log already spans enough of the spread', () async {
      final operation = await makeOperation();
      final uuid = operation['uuid'] as String;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Two hours of QSOs — more than a third of 3h.
      for (var i = 0; i < 4; i++) {
        await qsos.add(uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': now - 2 * 3600 * 1000 + i * 30 * 60 * 1000,
        });
      }
      final result = await interpret('SEED 15 3H', operation: operation, execute: true);
      expect(result!['describe'], isNot(contains('before your earliest QSO')));
      for (final qso in addQsosOf(result)) {
        final at = qso['startAtMillis'] as int;
        expect(at, greaterThanOrEqualTo(now - 3 * 3600 * 1000));
        expect(at, lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch));
      }
    });

    test('"SEED 15 3" (unit still missing) expects params rather than executing', () async {
      final result = await interpret('SEED 15 3', operation: await makeOperation());
      expect(result, {'expectsParams': true, 'mixedCase': true});
    });

    test('without an operation (home quick search), SEED is an error, not a silent non-match', () async {
      expect(await interpret('SEED'), {'error': 'SEED needs an open operation'});
      expect(await interpret('SEED 5'), {'error': 'SEED needs an open operation'});
    });

    group('the typing-debounce preview (execute omitted) skips the expensive work', () {
      test('a bare complete command returns a cheap describe with no commands to dispatch', () async {
        final result = await interpret('SEED 20', operation: await makeOperation());
        expect(result, isNotNull);
        expect(result!['mixedCase'], true);
        expect(result['describe'], 'Seed the log with 20 random QSOs?');
        // No `commands` key at all — not even an empty list — so a caller
        // that (incorrectly) dispatched a preview result would do nothing,
        // rather than seeding QSOs no one asked for yet.
        expect(result.containsKey('commands'), isFalse);
        expect(result.containsKey('confirm'), isFalse);
      });

      test('does not read the existing log, so it cannot report the backfill-before-earliest-QSO detail', () async {
        final operation = await makeOperation();
        final uuid = operation['uuid'] as String;
        final now = DateTime.now().millisecondsSinceEpoch;
        final earliest = now - 30 * 60 * 1000;
        // A log that WOULD qualify for backfill (spans well under 1/3 of
        // 3h) if getQsos were consulted — see the execute:true version of
        // this scenario above, which does report it.
        await qsos.add(uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': earliest,
        });

        final result = await interpret('SEED 15 3H', operation: operation);
        expect(result!['describe'], 'Seed the log with 15 random QSOs over 3H?');
        expect(result['describe'], isNot(contains('before your earliest QSO')));
        expect(result.containsKey('commands'), isFalse);
      });

      test('a spread is echoed in the preview describe text even though its precise placement is not yet resolved', () async {
        final result = await interpret('SEED 5 90M', operation: await makeOperation());
        expect(result!['describe'], 'Seed the log with 5 random QSOs over 90M?');
      });
    });

    test('execute:true after an execute:false preview generates the real commands (the logging panel\'s two-step flow)', () async {
      final operation = await makeOperation();
      final preview = await interpret('SEED 10', operation: operation);
      expect(preview!.containsKey('commands'), isFalse);

      final executed = await interpret('SEED 10', operation: operation, execute: true);
      expect(addQsosOf(executed!).length, 10);
    });
  });

  test('ctx.getOperation and ctx.getQsos host calls return QSON shapes (and nulls for unknowns)', () async {
    final operation = await makeOperation();
    final uuid = operation['uuid'] as String;
    await qsos.add(uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });

    // Straight through the same handler the runtime's ctx functions hit
    // (ExtensionHost.onHostCall is the service's _ExtensionHostCalls.handle).
    final hostCall = extensions.host!.onHostCall!;
    final fetchedOp = await hostCall('getOperation', {'uuid': uuid});
    expect(fetchedOp, isA<Map>());
    expect((fetchedOp as Map)['uuid'], uuid);
    expect(fetchedOp['stationCall'], 'KI2D');
    expect(await hostCall('getOperation', {'uuid': 'nope'}), isNull);

    final fetchedQsos = await hostCall('getQsos', {'operationUuid': uuid});
    expect(fetchedQsos, isA<List>());
    expect(((fetchedQsos as List).single as Map)['startAtMillis'], 1000);
    // Unknown operation -> null, NOT an empty list — "no such operation"
    // must stay distinguishable from "operation with no QSOs yet".
    expect(await hostCall('getQsos', {'operationUuid': 'nope'}), isNull);

    // An operation that exists but has no QSOs is the empty list.
    final emptyOp = await operations.create(stationCall: 'KI2D');
    expect(await hostCall('getQsos', {'operationUuid': emptyOp.uuid}), isEmpty);
  });
}
