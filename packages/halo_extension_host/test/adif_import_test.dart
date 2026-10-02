// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `adifImport` hook against the real runtime — the inverse of
// nfer_export_test.dart. The core parser produces NO references at all, so
// these hooks are the only thing standing between "imported a POTA log" and
// "imported 72 contacts that no longer belong to any park".
//
// What this package holds is the part every program shares: the contract the
// Dart importer reads the answer by, and the `referenceActivity()` factory's
// import, which every factory-built program is a row of — differing only in
// its SIG value, its ref types and its reference pattern. The row here is
// `ham2k-wwff`, the factory-built program the app pre-loads; WWFF keeps a
// hand-written group as well, as the worked example of what a row abbreviates.
// Each program's own row, and each hand-written hook's rules, are tested with
// the program.
//
// The field maps below are shaped exactly as `parseAdifLog` produces them:
// names lowercased, values as written.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

/// What one reference program's exporter writes, and therefore what its
/// importer has to read back.
class _Program {
  const _Program({required this.key, required this.sig, required this.activationType, required this.reference, this.huntingType, this.refField});

  /// The extension key, which is also the hook key.
  final String key;

  /// The SIG/MY_SIG value this program's own exporter writes — `adifProgram`
  /// where the extension sets one, its label otherwise.
  final String sig;

  final String activationType;

  /// Null for an award that only recognises activations. Those deliberately
  /// ignore an incoming SIG_INFO rather than inventing a ref type for it.
  final String? huntingType;

  /// A well-formed reference for this program, matching its `referenceRegex`.
  final String reference;

  /// The program's own multi-reference field, lowercased. Only the programs
  /// that publish one have it.
  final String? refField;
}

/// `referenceActivity()`-based programs. Two things make a row worth
/// distrusting and so worth listing: the SIG value is what stops one program
/// claiming another's references, and the reference is what proves the
/// program's pattern is actually being applied as the import filter.
const _programs = [
  _Program(key: 'ham2k-wwff', sig: 'WWFF', activationType: 'wwffActivation', huntingType: 'wwff', reference: 'KFF-0001', refField: 'wwff_ref'),
];

// Activation refs come back tagged `for: 'operation'`: ADIF flattens an
// activation onto every record, a hook only ever sees one record, so it says
// where the reference belongs and the importer moves it there.
void main() {
  requireBundles();

  Future<List<dynamic>> importRefsFrom(String key, List<Map<String, String>> records) async {
    final host = await sharedHost(['ham2k-pota', for (final p in _programs) p.key]);
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

  test('returns one result per record, nulls included', () async {
    // The Dart side matches these back by index; a hook that omitted its
    // empties would put one QSO's parks on another.
    final results = await importRefsFrom('ham2k-pota', [
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

  group('WWFF', () {
    // WWFF comes through the shared referenceActivity() factory rather than a
    // hand-written hook, so these also prove the factory wiring.
    test('reads WWFF_REF and the SIG pair', () async {
      final results = await importRefsFrom('ham2k-wwff', [
        {'sig': 'WWFF', 'sig_info': 'KFF-0001', 'my_sig': 'WWFF', 'my_sig_info': 'GFF-0002'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'KFF-0001'},
        {'type': 'wwffActivation', 'ref': 'GFF-0002', 'for': 'operation'},
      ]);
    });

    test('a multi-reference contact keeps every reference', () async {
      final results = await importRefsFrom('ham2k-wwff', [
        {'sig': 'WWFF', 'sig_info': 'KFF-0001', 'wwff_ref': 'KFF-0001,KFF-0002'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'KFF-0001'},
        {'type': 'wwff', 'ref': 'KFF-0002'},
      ]);
    });

    test("does not claim a reference from POTA's SIG_INFO", () async {
      // A well-formed WWFF reference under POTA's SIG. `K-1467` would fail
      // WWFF's own pattern, so it would never reach the guard being tested.
      final results = await importRefsFrom('ham2k-wwff', [
        {'sig': 'POTA', 'sig_info': 'KFF-0001'},
      ]);

      expect(results.single, isNull);
    });

    test('keeps a reference that does not match the program pattern', () async {
      // The SIG says WWFF, so the pattern's job here is to flag, not to
      // filter. Discarding would throw away recoverable text.
      final results = await importRefsFrom('ham2k-wwff', [
        {'sig': 'WWFF', 'sig_info': 'not a reference'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'NOT A REFERENCE'},
      ]);
    });
  });

  for (final program in _programs) {
    group(program.key, () {
      test('reads the activation it wrote', () async {
        final results = await importRefsFrom(program.key, [
          {'my_sig': program.sig, 'my_sig_info': program.reference},
        ]);

        expect(results.single['refs'], [
          {'type': program.activationType, 'ref': program.reference, 'for': 'operation'},
        ]);
      });

      test('reads a reference written in lower case', () async {
        // Files come from every logger there is, and the ref types are compared
        // as strings everywhere downstream — an unnormalized reference is a
        // reference that matches nothing it should.
        final results = await importRefsFrom(program.key, [
          {'my_sig': program.sig.toLowerCase(), 'my_sig_info': program.reference.toLowerCase()},
        ]);

        expect(results.single['refs'], [
          {'type': program.activationType, 'ref': program.reference, 'for': 'operation'},
        ]);
      });

      test("declines a record whose SIG names another program", () async {
        // The failure this whole table exists for. Every reference program
        // writes the same SIG/MY_SIG pair, so a hook that read the pair without
        // checking WHOSE it is invents a reference on every foreign record —
        // and the log looks perfectly fine afterwards.
        //
        // The reference is the program's OWN, deliberately: a foreign-LOOKING
        // one is rejected by `referenceRegex` before the SIG guard is ever
        // consulted, so the test would pass with the guard deleted and prove
        // only that the pattern works. Here the pattern accepts and the guard
        // is the single thing standing between these two fields and a
        // fabricated reference.
        final results = await importRefsFrom(program.key, [
          {'sig': 'POTA', 'sig_info': program.reference, 'my_sig': 'POTA', 'my_sig_info': program.reference},
        ]);

        expect(results.single, isNull);
      });

      test('keeps a reference that does not match its pattern', () async {
        // Malformed, not foreign — the SIG already named this program. The
        // pattern flags it for the operator via `decorateRef`; it does not
        // decide whether the reference survives the import.
        final results = await importRefsFrom(program.key, [
          {'my_sig': program.sig, 'my_sig_info': 'not a reference'},
        ]);

        expect(results.single['refs'], [
          {'type': program.activationType, 'ref': 'NOT A REFERENCE', 'for': 'operation'},
        ]);
      });

      if (program.huntingType case final huntingType?) {
        test('reads the other station\'s reference too', () async {
          final results = await importRefsFrom(program.key, [
            {'sig': program.sig, 'sig_info': program.reference, 'my_sig': program.sig, 'my_sig_info': program.reference},
          ]);

          // Same string, two ref types and two scopes: the hunted reference
          // stays on the contact, the activation is tagged for the operation.
          expect(results.single['refs'], [
            {'type': huntingType, 'ref': program.reference},
            {'type': program.activationType, 'ref': program.reference, 'for': 'operation'},
          ]);
        });
      } else {
        test('ignores a hunted reference, having no ref type for one', () async {
          // Deliberate, not an oversight: these awards recognise activations
          // only, so an incoming SIG_INFO describes something this program
          // cannot name. Importing it would invent a ref type.
          final results = await importRefsFrom(program.key, [
            {'sig': program.sig, 'sig_info': program.reference},
          ]);

          expect(results.single, isNull);
        });
      }

      if (program.refField case final refField?) {
        test('$refField keeps an n-fer an n-fer', () async {
          // SIG_INFO names only the primary reference, so a hook that preferred
          // it would quietly import a two-reference contact as a one-reference
          // one.
          final results = await importRefsFrom(program.key, [
            {'sig': program.sig, 'sig_info': program.reference, refField: '${program.reference},${program.reference}9'},
          ]);

          expect(results.single['refs'], [
            {'type': program.huntingType, 'ref': program.reference},
            {'type': program.huntingType, 'ref': '${program.reference}9'},
          ]);
        });

        test('my_$refField carries a multi-reference activation', () async {
          // The activation side has its own `MY_`-prefixed list field, built
          // separately from the hunted one — an award activated from two
          // references at once names both there.
          final results = await importRefsFrom(program.key, [
            {'my_$refField': '${program.reference},${program.reference}9'},
          ]);

          expect(results.single['refs'], [
            {'type': program.activationType, 'ref': program.reference, 'for': 'operation'},
            {'type': program.activationType, 'ref': '${program.reference}9', 'for': 'operation'},
          ]);
        });
      }
    });
  }
}
