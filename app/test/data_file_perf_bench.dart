// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Measurement harness for APP-16 (data file loading speed). Splits the import
// into its stages so we optimize the one that actually costs.
//
// NOT part of the suite, and deliberately so: `scripts/test.sh` runs a bare
// `flutter test`, which collects only `*_test.dart`. The `_bench` suffix is
// what keeps this out of CI — renaming it would put a 25 MB fixture and a
// multi-minute run on the critical path. Run it by hand:
//
//   curl -sL -o /tmp/sota_summits.csv https://www.sotadata.org.uk/summitslist.csv
//   SOTA_CSV=/tmp/sota_summits.csv flutter test test/data_file_perf_bench.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SOTA import stage timings', () async {
    final path = Platform.environment['SOTA_CSV'] ?? '/tmp/sota_summits.csv';
    final body = await File(path).readAsString();
    print('CSV bytes: ${body.length}');

    final db = HaLoDatabase(NativeDatabase.memory());
    final lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    final extensions = ExtensionService()..lookups = lookups;
    await extensions.start();
    final host = extensions.host!;

    // Asserts the real SOTA bundle is loaded — the mapper below is its own.
    final defs = await host.invokeHookAll('dataFile', method: 'getDefinition');
    expect(defs.any((e) => (e['value'] as Map?)?['key'] == 'sota-all-summits'), isTrue);

    // ---- Stage A: Dart-side CSV parse (what _processCsv does) ----
    final swA = Stopwatch()..start();
    final lines = const LineSplitter().convert(body);
    final parsedRows = <dynamic>[];
    List<String>? headers;
    for (var i = 0; i < lines.length; i++) {
      if (i < 1) continue; // skipRows: 1
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parsed = parseCsvRow(line, ',');
      if (headers == null) {
        headers = parsed;
        continue;
      }
      parsedRows.add(parsed);
    }
    swA.stop();
    print('STAGE A  csv parse (Dart, main isolate): ${swA.elapsedMilliseconds} ms  -> ${parsedRows.length} rows');

    // ---- Stage B: cross to JS + map, per 5000-row chunk ----
    // ---- Stage C: jsonEncode of `data` + Drift batch insert ----
    var msB = 0, msC = 0, imported = 0, msEnc = 0, msIns = 0;
    var argsJsonBytes = 0, respJsonBytes = 0;
    final updatedFlag = DateTime.now().millisecondsSinceEpoch;
    const chunkSize = 5000;
    final swTotal = Stopwatch()..start();
    for (var start = 0; start < parsedRows.length; start += chunkSize) {
      final end = start + chunkSize < parsedRows.length ? start + chunkSize : parsedRows.length;
      final chunk = parsedRows.sublist(start, end);

      if (start == 0) argsJsonBytes = jsonEncode({'rows': chunk, 'headers': headers}).length;

      final swB = Stopwatch()..start();
      final dynamic response = await host.invokeHook(
        'dataFile',
        key: 'sota-all-summits',
        method: 'mapCsvBatch',
        args: {'rows': chunk, 'headers': headers},
        timeout: const Duration(seconds: 120),
      );
      swB.stop();
      msB += swB.elapsedMilliseconds;

      // Outside the stage-C stopwatch below: this encode is instrumentation,
      // not work the real import does, and inside it, it inflated the first
      // chunk's stage C by ~22 ms.
      if (start == 0 && response is List) respJsonBytes = jsonEncode(response).length;

      final swC = Stopwatch()..start();
      if (response is List) {
        final swEnc = Stopwatch()..start();
        final lookupRows = <LookupRow>[];
        for (final item in response) {
          if (item is Map) {
            final entryKey = item['key'] as String?;
            if (entryKey != null) {
              lookupRows.add(
                LookupRow(
                  category: 'sota',
                  subCategory: item['subCategory'] as String?,
                  key: entryKey,
                  name: item['name'] as String?,
                  lat: (item['lat'] as num?)?.toDouble(),
                  lon: (item['lon'] as num?)?.toDouble(),
                  flags: item['flags'] as int?,
                  data: item['data'] != null ? jsonEncode(item['data']) : null,
                  updated: updatedFlag,
                ),
              );
            }
          }
        }
        swEnc.stop();
        msEnc += swEnc.elapsedMilliseconds;
        final swIns = Stopwatch()..start();
        if (lookupRows.isNotEmpty) {
          await lookups.insertLookupBatch(lookupRows);
          imported += lookupRows.length;
        }
        swIns.stop();
        msIns += swIns.elapsedMilliseconds;
      }
      swC.stop();
      msC += swC.elapsedMilliseconds;
    }
    swTotal.stop();

    final swD = Stopwatch()..start();
    await lookups.deleteCategoryStale('sota', updatedFlag);
    swD.stop();

    print('STAGE B  JS boundary + mapper:          $msB ms');
    print('STAGE C  jsonEncode + Drift insert:     $msC ms  -> $imported rows');
    print('STAGE D  deleteCategoryStale:           ${swD.elapsedMilliseconds} ms');
    print('B+C+D total:                            ${swTotal.elapsedMilliseconds + swD.elapsedMilliseconds} ms');
    print('GRAND TOTAL (A+B+C+D):                  ${swA.elapsedMilliseconds + swTotal.elapsedMilliseconds + swD.elapsedMilliseconds} ms');
    print('argsJson bytes for one 5000-row chunk:  $argsJsonBytes');
    print('RESPONSE bytes for one 5000-row chunk:  $respJsonBytes');
    print('  of STAGE C: LookupRow build + jsonEncode(data): $msEnc ms');
    print('  of STAGE C: Drift insertLookupBatch:            $msIns ms');

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
