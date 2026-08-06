// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA's `adifImport` hook against the real runtime — the inverse of
// nfer_export_test.dart. The core parser produces NO references at all, so
// this hook is the only thing standing between "imported a POTA log" and
// "imported 72 contacts that no longer belong to any park".
//
// The field maps below are shaped exactly as `parseAdifLog` produces them:
// names lowercased, values as written.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

// Activation refs come back tagged `for: 'operation'`: ADIF flattens an
// activation onto every record, a hook only ever sees one record, so it says
// where the reference belongs and the importer moves it there.
void main() {
  requireBundles();

  Future<List<dynamic>> importRefsFrom(String key, List<Map<String, String>> records) async {
    final host = await sharedHost(['pota', 'sota', 'wwff']);
    final result = await host.invokeHook(
      'adifImport',
      key: key,
      method: 'refsForRecords',
      args: {
        'records': [
          for (final fields in records) {'fields': fields},
        ],
      },
      timeout: const Duration(seconds: 20),
    );
    return (result as List);
  }

  Future<List<dynamic>> importRefs(List<Map<String, String>> records) => importRefsFrom('pota', records);

  test('recovers hunted and activated parks from a HamRS-style record', () async {
    final results = await importRefs([
      {'call': 'AC9OT', 'sig': 'POTA', 'sig_info': 'K-1467', 'my_sig': 'POTA', 'my_sig_info': 'K-0001'},
    ]);

    expect(results.single['refs'], [
      {'type': 'pota', 'ref': 'K-1467'},
      {'type': 'potaActivation', 'ref': 'K-0001', 'for': 'operation'},
    ]);
  });

  test('POTA_REF keeps an n-fer an n-fer', () async {
    // SIG_INFO names only the primary park. A hook that read it in preference
    // would import a two-park contact as a one-park one, and the log would
    // look perfectly fine.
    final results = await importRefs([
      {'sig': 'POTA', 'sig_info': 'K-1467', 'pota_ref': 'K-1467,K-9999'},
    ]);

    expect(results.single['refs'], [
      {'type': 'pota', 'ref': 'K-1467'},
      {'type': 'pota', 'ref': 'K-9999'},
    ]);
  });

  test('normalizes a reference written without its dash', () async {
    final results = await importRefs([
      {'sig': 'POTA', 'sig_info': 'us1234'},
    ]);

    expect(results.single['refs'], [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);
  });

  test("does not claim another program's SIG_INFO", () async {
    // Every reference program writes SIG/SIG_INFO. Without the SIG check a
    // WWFF reference would import as a park that does not exist.
    final results = await importRefs([
      {'sig': 'WWFF', 'sig_info': 'KFF-1234'},
    ]);

    expect(results.single, isNull);
  });

  test('drops a SIG_INFO that is not a well-formed park', () async {
    final results = await importRefs([
      {'sig': 'POTA', 'sig_info': 'not a park'},
    ]);

    expect(results.single, isNull);
  });

  test('returns one result per record, nulls included', () async {
    // The Dart side matches these back by index; a hook that omitted its
    // empties would put one QSO's parks on another.
    final results = await importRefs([
      {'pota_ref': 'K-0001'},
      {'call': 'W1AW'},
      {'pota_ref': 'K-0002'},
    ]);

    expect(results, hasLength(3));
    expect(results[0]['refs'], [
      {'type': 'pota', 'ref': 'K-0001'},
    ]);
    expect(results[1], isNull);
    expect(results[2]['refs'], [
      {'type': 'pota', 'ref': 'K-0002'},
    ]);
  });

  group('SOTA', () {
    test('reads its own SOTA_REF, which carries no SIG at all', () async {
      // SOTA's exporter writes only SOTA_REF/MY_SOTA_REF. A hook that
      // required a matching SIG would import none of SOTA's own files.
      final results = await importRefsFrom('sota', [
        {'sota_ref': 'W2/GC-001', 'my_sota_ref': 'G/LD-001'},
      ]);

      expect(results.single['refs'], [
        {'type': 'sota', 'ref': 'W2/GC-001'},
        {'type': 'sotaActivation', 'ref': 'G/LD-001', 'for': 'operation'},
      ]);
    });

    test('reads a summit other software wrote as SIG_INFO', () async {
      final results = await importRefsFrom('sota', [
        {'sig': 'SOTA', 'sig_info': 'w2/gc-001'},
      ]);

      expect(results.single['refs'], [
        {'type': 'sota', 'ref': 'W2/GC-001'},
      ]);
    });

    test('merges SOTA_REF and SIG_INFO rather than preferring either', () async {
      // HaLo writes no SIG for SOTA, but a file may carry both spellings from
      // different tools in the chain. Reading only one silently drops summits.
      final results = await importRefsFrom('sota', [
        {'sota_ref': 'W2/GC-001', 'sig': 'SOTA', 'sig_info': 'W2/GC-002'},
      ]);

      expect(results.single['refs'], [
        {'type': 'sota', 'ref': 'W2/GC-001'},
        {'type': 'sota', 'ref': 'W2/GC-002'},
      ]);
    });

    test('the same summit in both fields lands once', () async {
      final results = await importRefsFrom('sota', [
        {'sota_ref': 'W2/GC-001', 'sig': 'SOTA', 'sig_info': 'w2/gc-001'},
      ]);

      expect(results.single['refs'], [
        {'type': 'sota', 'ref': 'W2/GC-001'},
      ]);
    });

    test('reads the activation side from MY_SIG when MY_SOTA_REF is absent', () async {
      final results = await importRefsFrom('sota', [
        {'sota_ref': 'W2/GC-001', 'my_sig': 'SOTA', 'my_sig_info': 'G/LD-001'},
      ]);

      expect(results.single['refs'], [
        {'type': 'sota', 'ref': 'W2/GC-001'},
        {'type': 'sotaActivation', 'ref': 'G/LD-001', 'for': 'operation'},
      ]);
    });

    test('leaves a POTA record alone', () async {
      final results = await importRefsFrom('sota', [
        {'sig': 'POTA', 'sig_info': 'K-1467', 'pota_ref': 'K-1467'},
      ]);

      expect(results.single, isNull);
    });
  });

  group('WWFF', () {
    // WWFF comes through the shared referenceActivity() factory rather than a
    // hand-written hook, so these also prove the factory wiring.
    test('reads WWFF_REF and the SIG pair', () async {
      final results = await importRefsFrom('wwff', [
        {'sig': 'WWFF', 'sig_info': 'KFF-0001', 'my_sig': 'WWFF', 'my_sig_info': 'GFF-0002'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'KFF-0001'},
        {'type': 'wwffActivation', 'ref': 'GFF-0002', 'for': 'operation'},
      ]);
    });

    test('a multi-reference contact keeps every reference', () async {
      final results = await importRefsFrom('wwff', [
        {'sig': 'WWFF', 'sig_info': 'KFF-0001', 'wwff_ref': 'KFF-0001,KFF-0002'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'KFF-0001'},
        {'type': 'wwff', 'ref': 'KFF-0002'},
      ]);
    });

    test("does not claim a park from POTA's SIG_INFO", () async {
      final results = await importRefsFrom('wwff', [
        {'sig': 'POTA', 'sig_info': 'K-1467'},
      ]);

      expect(results.single, isNull);
    });

    test('drops a reference that does not match the program pattern', () async {
      // referenceRegex doubles as the import filter — without it, a
      // WWFF-flagged record naming anything at all would become a reference.
      final results = await importRefsFrom('wwff', [
        {'sig': 'WWFF', 'sig_info': 'not a reference'},
      ]);

      expect(results.single, isNull);
    });
  });
}
