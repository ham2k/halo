// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Measurement harness for APP-16. Splits the cost of getting one 5000-row
// data-file chunk into QuickJS, the way engine_runtime_io.invoke does.
//
// NOT part of the suite, and deliberately so: `scripts/test.sh` runs a bare
// `flutter test`, which collects only `*_test.dart`. The `_bench` suffix is
// what keeps this out of CI — renaming it would put a 25 MB fixture and a
// multi-minute run on the critical path. Run it by hand:
//
//   ./tool/build_host.sh          # the dylib this dlopens; CI does this too
//   curl -sL -o /tmp/sota_summits.csv https://www.sotadata.org.uk/summitslist.csv
//   SOTA_CSV=/tmp/sota_summits.csv flutter test test/boundary_bench.dart
//
// `flutter test`, not `dart test` — this imports package:flutter_test, and
// halo_quickjs has no `test` dev-dependency.
// ignore_for_file: avoid_print — a bench whose report is its output; stdout is the interface.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_quickjs/halo_quickjs.dart';

void main() {
  test('chunk transport cost breakdown', () {
    final path = Platform.environment['SOTA_CSV'] ?? '/tmp/sota_summits.csv';
    final lines = File(path).readAsLinesSync();
    final headers = lines[1].split(',');
    // 5000 rows, same shape DataFileManager builds (Map<String,String>).
    final rows = <Map<String, String>>[];
    for (var i = 2; i < 5002 && i < lines.length; i++) {
      final parts = lines[i].split(',');
      final m = <String, String>{};
      for (var j = 0; j < headers.length && j < parts.length; j++) {
        m[headers[j]] = parts[j];
      }
      rows.add(m);
    }

    final js = HaloQuickJs()..evalBudgetMs = 60000;

    // --- encode #1: what invokeHook does with args ---
    final sw1 = Stopwatch()..start();
    final argsJson = jsonEncode({'rows': rows});
    sw1.stop();

    // --- encode #2: what engine_runtime_io embeds into the source ---
    final sw2 = Stopwatch()..start();
    final escaped = jsonEncode(argsJson);
    sw2.stop();

    // --- QuickJS tokenizing that string literal (no JSON.parse yet) ---
    final sw3 = Stopwatch()..start();
    final r3 = js.eval('globalThis.__a = $escaped; globalThis.__a.length');
    sw3.stop();

    // --- JSON.parse of the already-resident string ---
    final sw4 = Stopwatch()..start();
    final r4 = js.eval('JSON.parse(globalThis.__a).rows.length');
    sw4.stop();

    // --- alternative: embed as a JS object literal, no escaping, no JSON.parse ---
    final sw5 = Stopwatch()..start();
    final r5 = js.eval('globalThis.__b = $argsJson; globalThis.__b.rows.length');
    sw5.stop();

    // --- what it would cost if the string were already a JS value (the ceiling
    //     a set-global-string API could reach): JSON.parse only, measured above.

    print('rows: ${rows.length}');
    print('argsJson bytes:            ${argsJson.length}');
    print('escaped-for-source bytes:  ${escaped.length}  (${(escaped.length / argsJson.length).toStringAsFixed(2)}x)');
    print('t1 jsonEncode(args):       ${sw1.elapsedMilliseconds} ms');
    print('t2 jsonEncode(argsJson):   ${sw2.elapsedMilliseconds} ms   <- pure waste');
    print('t3 eval string literal:    ${sw3.elapsedMilliseconds} ms   -> ${r3.text}');
    print('t4 JSON.parse:             ${sw4.elapsedMilliseconds} ms   -> ${r4.text}');
    print('t5 eval object literal:    ${sw5.elapsedMilliseconds} ms   -> ${r5.text}');
    print(
      'CURRENT total transport (t1+t2+t3+t4): '
      '${sw1.elapsedMilliseconds + sw2.elapsedMilliseconds + sw3.elapsedMilliseconds + sw4.elapsedMilliseconds} ms',
    );
    print('OBJECT-LITERAL total       (t1+t5):    ${sw1.elapsedMilliseconds + sw5.elapsedMilliseconds} ms');

    js.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
