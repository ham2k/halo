// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every activity's `adifImport` hook against the real runtime — the inverse of
// nfer_export_test.dart. The core parser produces NO references at all, so
// these hooks are the only thing standing between "imported a POTA log" and
// "imported 72 contacts that no longer belong to any park".
//
// POTA and SOTA are hand-written hooks and get hand-written groups. Every other
// reference program comes through `referenceActivity()`, differing only in its
// SIG value, its ref types and its reference pattern — so they are a TABLE, and
// adding a program is a row. WWFF keeps a hand-written group as well, as the
// worked example of what a row abbreviates.
//
// `satellites` is deliberately absent: it writes SAT_NAME/BAND_RX and no SIG at
// all, and its import needs the bird table stubbed, so it lives with the rest
// of its fixtures in satellites_test.dart. `custom` registers no hook by design
// — see the comment at its `onActivation`.
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
  /// where the extension sets one, its label otherwise. SiOTA is the one that
  /// differs from its label.
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

/// Every `referenceActivity()`-based program. Two things make a row worth
/// distrusting and so worth listing: the SIG value is what stops one program
/// claiming another's references, and the reference is what proves the
/// program's pattern is actually being applied as the import filter.
const _programs = [
  _Program(key: 'bca', sig: 'BCA', activationType: 'bcaActivation', reference: 'ON-00558'),
  _Program(key: 'blha', sig: 'BLHA', activationType: 'blhaActivation', reference: 'BEL 001'),
  _Program(key: 'eca', sig: 'ECA', activationType: 'ecaActivation', reference: 'G-00001'),
  _Program(key: 'ela', sig: 'ELA', activationType: 'elaActivation', reference: 'ENG 001'),
  _Program(key: 'gma', sig: 'GMA', activationType: 'gmaActivation', huntingType: 'gma', reference: 'DL/AL-001'),
  _Program(key: 'llota', sig: 'LLOTA', activationType: 'llotaActivation', huntingType: 'llota', reference: 'LLUS-0001', refField: 'llota_ref'),
  _Program(key: 'mota', sig: 'MOTA', activationType: 'motaActivation', huntingType: 'mota', reference: 'X00001'),
  _Program(key: 'pga', sig: 'PGA', activationType: 'pgaActivation', reference: 'AB12'),
  // `adifProgram: 'SIOTA'` — the award styles itself SiOTA but its ADIF is
  // upper-case, and importing on the label would read none of its own files.
  _Program(key: 'siota', sig: 'SIOTA', activationType: 'siotaActivation', huntingType: 'siota', reference: 'VK-ABC123'),
  _Program(key: 'tota', sig: 'TOTA', activationType: 'totaActivation', huntingType: 'tota', reference: 'OKR-0001'),
  _Program(key: 'wca', sig: 'WCA', activationType: 'wcaActivation', reference: 'ON-00558'),
  _Program(key: 'wwbota', sig: 'WWBOTA', activationType: 'wwbotaActivation', huntingType: 'wwbota', reference: 'B/G-0001'),
  _Program(key: 'zlota', sig: 'ZLOTA', activationType: 'zlotaActivation', huntingType: 'zlota', reference: 'ZLH/AA-001'),
];

// Activation refs come back tagged `for: 'operation'`: ADIF flattens an
// activation onto every record, a hook only ever sees one record, so it says
// where the reference belongs and the importer moves it there.
void main() {
  requireBundles();

  Future<List<dynamic>> importRefsFrom(String key, List<Map<String, String>> records) async {
    final host = await sharedHost(['pota', 'sota', 'wwff', for (final p in _programs) p.key]);
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

  test('keeps a SIG_INFO that is not a well-formed park', () async {
    // The record says POTA, so this is a MALFORMED park, not another
    // program's reference — the SIG check already settled whose it is.
    // Dropping it would lose the only text a correction could work from,
    // and lose it silently. It imports flagged invalid instead.
    final results = await importRefs([
      {'sig': 'POTA', 'sig_info': 'not a park'},
    ]);

    expect(results.single['refs'], [
      {'type': 'pota', 'ref': 'NOT A PARK'},
    ]);
  });

  test('a dashless park is still repaired on the way in', () async {
    // Keeping the malformed must not cost the repair: `normalizeReference`
    // still runs, and only its null answer falls back to the raw text.
    final results = await importRefs([
      {'sig': 'POTA', 'sig_info': 'us1234'},
    ]);

    expect(results.single['refs'], [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);
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
      // SIG_INFO carries a well-formed SUMMIT under POTA's SIG — the shape that
      // reaches the guard. A park reference here would be turned away by
      // SOTA's own pattern first, and the test would pass with no guard at all.
      final results = await importRefsFrom('sota', [
        {'sig': 'POTA', 'sig_info': 'W2/GC-001', 'pota_ref': 'K-1467'},
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

    test("does not claim a reference from POTA's SIG_INFO", () async {
      // A well-formed WWFF reference under POTA's SIG. `K-1467` would fail
      // WWFF's own pattern, so it would never reach the guard being tested.
      final results = await importRefsFrom('wwff', [
        {'sig': 'POTA', 'sig_info': 'KFF-0001'},
      ]);

      expect(results.single, isNull);
    });

    test('keeps a reference that does not match the program pattern', () async {
      // The SIG says WWFF, so the pattern's job here is to flag, not to
      // filter. Discarding would throw away recoverable text.
      final results = await importRefsFrom('wwff', [
        {'sig': 'WWFF', 'sig_info': 'not a reference'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wwff', 'ref': 'NOT A REFERENCE'},
      ]);
    });
  });

  group('programs whose reference patterns genuinely overlap', () {
    // The table above proves the guard generically. These are the three real
    // collisions in the shipped patterns, where one program's regex accepts
    // another's references verbatim — so the SIG value is the ONLY thing
    // telling them apart, and a log carrying one would silently gain a
    // reference in the other program.
    test("WCA's pattern accepts a BCA castle, so only the SIG separates them", () async {
      // WCA is `^[A-Z0-9]+-[0-9]{5}$`; BCA's `ON-00558` matches it exactly.
      final results = await importRefsFrom('wca', [
        {'sig': 'BCA', 'sig_info': 'ON-00558', 'my_sig': 'BCA', 'my_sig_info': 'ON-00558'},
      ]);

      expect(results.single, isNull);
    });

    test("WCA's pattern accepts an ECA castle too", () async {
      final results = await importRefsFrom('wca', [
        {'my_sig': 'ECA', 'my_sig_info': 'G-00001'},
      ]);

      expect(results.single, isNull);
    });

    test("GMA's pattern accepts a SOTA summit", () async {
      // GMA is a superset award and its pattern matches SOTA references, so a
      // summit activation would import as a GMA reference as well.
      final results = await importRefsFrom('gma', [
        {'sig': 'SOTA', 'sig_info': 'W2/GC-001', 'sota_ref': 'W2/GC-001'},
      ]);

      expect(results.single, isNull);
    });

    test('WCA still reads its own castle at that same shape', () async {
      // The other side of the guard: rejecting by SIG must not reject WCA's
      // own references, which look identical to BCA's.
      final results = await importRefsFrom('wca', [
        {'my_sig': 'WCA', 'my_sig_info': 'ON-00558'},
      ]);

      expect(results.single['refs'], [
        {'type': 'wcaActivation', 'ref': 'ON-00558', 'for': 'operation'},
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
