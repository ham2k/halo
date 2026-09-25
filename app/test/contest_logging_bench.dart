// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Runs HALO-119's contest benchmark on the host and prints every band, so a
// developer gets the detailed data. The workload itself lives in
// `lib/tools/contest_bench.dart` — DEVBENCH runs the same code on a device,
// and a second copy here would drift from it silently.
//
// NOT part of the suite, deliberately: `scripts/test.sh` runs a bare
// `flutter test`, which collects only `*_test.dart`. The `_bench` suffix is
// what keeps a multi-minute run off the critical path — the same convention
// as boundary_bench.dart and data_file_perf_bench.dart. Run it by hand:
//
//   cd app && flutter test test/contest_logging_bench.dart          # 100, a smoke run
//   QSO_COUNT=5000 flutter test test/contest_logging_bench.dart
//   flutter test --dart-define=QSO_COUNT=5000 test/contest_logging_bench.dart
//
// Runs the extension core IN-PROCESS (isolates and FFI don't mix inside
// flutter_test), so it measures the bridge's transport and the scorers' work
// but NOT the queueing a real build sees behind one engine — that is
// HALO-492's instrument, on a real device.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/tools/contest_bench.dart';

/// `--dart-define=QSO_COUNT=n`, or `QSO_COUNT=n` in the environment.
int _qsoCount() {
  const define = String.fromEnvironment('QSO_COUNT');
  final raw = define.isNotEmpty ? define : (Platform.environment['QSO_COUNT'] ?? '');
  final parsed = int.tryParse(raw);
  // A misspelled value is a mistake worth failing on: silently running the
  // 100-QSO default when someone asked for 5000 wastes the run they meant.
  if (raw.isNotEmpty && (parsed == null || parsed < 1)) {
    throw ArgumentError('QSO_COUNT must be a positive integer, got "$raw"');
  }
  return parsed ?? 100;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CQ WW logging: per-QSO cost as the log grows', () async {
    final total = _qsoCount();

    SharedPreferences.setMockInitialValues({});
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final sequences = SequencesRepository(db);
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db, sequences: sequences);
    final lookups = LookupRepository(db);

    // `cqww` ships `enabledByDefault: false`, so without an override the
    // runtime loads no contest at all and the workload's own guard throws.
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExtensionOverrides({'cqww': true, 'call-history': true, 'call-notes': true});

    // The log AND the operations, or the runtime's `getQsos` answers null and
    // every cold fold is of an empty log — sub-millisecond, flat, and a lie.
    final extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings
      ..operations = operations
      ..qsos = qsos;
    await extensions.start();
    addTearDown(() async => extensions.host?.dispose());

    final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);

    final result = await runContestBench(
      qsos: qsos,
      operations: operations,
      extensions: extensions,
      scoring: scoring,
      qsoCount: total,
      purge: (uuid) => db.transaction(() async {
        await operations.purge(uuid);
        await qsos.purgeForOperation(uuid);
      }),
    );

    // `plainReport` already lists every band per phase, one phase per line —
    // which is the detailed data this harness exists to give, and stays
    // readable however many phases there are. A columns-per-band table does
    // not: the labels carry their units now, and five of them overflow any
    // sane width.
    print('\n${'=' * 76}');
    print(result.plainReport);
    print('=' * 76);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
