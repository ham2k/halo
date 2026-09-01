// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('QSON type probes', () {
    test('a string field refuses to invent a value out of a non-string', () {
      // The trap: stringifying would turn `mode: true` into the mode 'true',
      // which then reaches exports, scoring and the ADIF writer looking
      // exactly like something an operator typed. Absent is recoverable;
      // invented is not.
      expect(asQsonString(true), isNull);
      expect(asQsonString(14074), isNull);
      expect(asQsonString('SSB'), 'SSB');
    });

    test('a number field parses a numeric string, because older records really carry them', () {
      expect(asQsonNum('14074.5'), 14074.5);
      expect(asQsonNum(14074.5), 14074.5);
      expect(asQsonNum('SSB'), isNull);
      expect(asQsonNum(true), isNull);
    });

    test('a non-finite number is refused, never manufactured from a string', () {
      // The trap, and the reason this is not just `num.tryParse`: tryParse
      // ACCEPTS the literals 'NaN' and 'Infinity' and overflows '1e400' to
      // Infinity — which is what a JS peer sends for a NaN. jsonEncode
      // refuses to encode either and .toInt() on either throws, so coercing
      // one INTO a record aborts the transaction that stores the record,
      // and the device retries the same record forever. That is the exact
      // failure this module exists to prevent, arriving through the repair.
      expect(asQsonNum('NaN'), isNull);
      expect(asQsonNum('Infinity'), isNull);
      expect(asQsonNum('-Infinity'), isNull);
      expect(asQsonNum('1e400'), isNull);
      expect(asQsonNum(double.nan), isNull);
      expect(asQsonNum(double.infinity), isNull);
    });

    test('a map field accepts a dynamically-keyed map, which a cast rejects', () {
      // jsonDecode yields Map<String, dynamic>, but a map built in Dart or
      // handed over the extension bridge is Map<dynamic, dynamic> — and
      // `as Map<String, dynamic>?` throws on it even though every key is a
      // string.
      final dynamicKeyed = <dynamic, dynamic>{'call': 'W1AW'};
      expect(asQsonMap(dynamicKeyed), {'call': 'W1AW'});
      expect(asQsonMap('W1AW'), isNull);
    });
  });

  group('normalizeQsoQson', () {
    test('leaves a clean record untouched, and does not copy it', () {
      // Identity, not equality: every write goes through here, so a record
      // with nothing wrong must not pay for a rebuilt map.
      final data = <String, dynamic>{
        'freq': 14074.0,
        'mode': 'FT8',
        'their': {'call': 'W1AW'},
      };
      expect(identical(normalizeQsoQson(data), data), isTrue);
    });

    test('parses a String freq, the value that crashes every render of the QSO list', () {
      // `freq` is not read at write time, so a String sails into the
      // database and only throws later, in _computeMetrics, on every frame —
      // leaving the operator no way to reach the record, because the view
      // that would show it is the one crashing.
      final normalized = normalizeQsoQson({'freq': '14074.5'});
      expect(normalized['freq'], 14074.5);
    });

    test('drops a bool mode, the value that wedges sync', () {
      // `mode` IS read at write time — it is an indexed column — so a bool
      // throws out of _companionFor, rolling back the whole mergeFromSync
      // transaction, and the identical record is retried forever. Dropping
      // it lets the round commit.
      final normalized = normalizeQsoQson({'mode': true, 'band': '20m'});
      expect(normalized.containsKey('mode'), isFalse);
      expect(normalized['band'], '20m', reason: 'the rest of the record survives');
    });

    test('normalizes inside our/their, and inside their.guess', () {
      final normalized = normalizeQsoQson({
        'our': {'call': 'N0DEV', 'rig': 42},
        'their': {
          'call': 'W1AW',
          'power': '5',
          'guess': {'name': false, 'grid': 'FN31pr'},
        },
      });
      expect((normalized['our'] as Map).containsKey('rig'), isFalse);
      expect((normalized['their'] as Map)['power'], 5);
      final guess = (normalized['their'] as Map)['guess'] as Map;
      expect(guess.containsKey('name'), isFalse);
      expect(guess['grid'], 'FN31pr');
    });

    test('does not touch the original record', () {
      // The caller may still be holding the map it passed in — a normalizer
      // that mutated its argument would change a Qso out from under whoever
      // constructed it.
      final data = <String, dynamic>{'mode': true};
      normalizeQsoQson(data);
      expect(data['mode'], isTrue);
    });

    test('leaves keys no getter reads exactly as they are', () {
      // QSON is forward-compatible because unknown keys survive a round
      // trip. Normalizing a key we do not understand would rewrite a payload
      // whose shape is a newer client's business, not ours.
      final normalized = normalizeQsoQson({'mode': true, 'somethingNewer': {'a': 1}});
      expect(normalized['somethingNewer'], {'a': 1});
    });

    test('a normalized record always survives jsonEncode', () {
      // The normalizer runs on the write path, one line before jsonEncode,
      // inside a transaction. Anything it can emit that jsonEncode refuses
      // rolls that transaction back — so "is it encodable" is the real
      // post-condition, not "is it the right Dart type".
      final normalized = normalizeQsoQson({
        'freq': 'NaN',
        'power': '1e400',
        'startAtMillis': 'Infinity',
        'their': {'call': 'W1AW', 'lat': 'NaN'},
      });
      expect(() => jsonEncode(normalized), returnsNormally);
    });

    test('a clean record records no violations at all', () {
      // Guards the report itself: `_isClean` disagreeing with the probes by
      // even one shape (a dynamically-keyed map is normal off the bridge)
      // would upload well-formed records as malformed, and the one signal
      // that can name the upstream writer becomes noise.
      final violations = <QsonTypeViolation>[];
      normalizeQsoQson({
        'freq': 14074.0,
        'mode': 'FT8',
        'refs': const [],
        'their': <dynamic, dynamic>{'call': 'W1AW', 'guess': {'name': 'Hiram'}},
      }, violations: violations);
      expect(violations, isEmpty);
    });

    test('an explicit null is an ordinary absence, not a violation', () {
      final violations = <QsonTypeViolation>[];
      normalizeQsoQson({'mode': null}, violations: violations);
      expect(violations, isEmpty);
    });

    test('a value that coerces cleanly is not reported, however wrong its type', () {
      // `asQsonNum` takes a numeric string on purpose — `power: '5'` and
      // `freq: '14.074'` are documented as shapes that legitimately reach us
      // from older imports and from polo. Reporting those sent every device
      // holding one to the crash backend, burying the drops this exists to
      // catch under records behaving exactly as specified.
      final violations = <QsonTypeViolation>[];
      final normalized = normalizeQsoQson({
        'power': '5',
        'freq': '14.074',
        'our': {'lat': '41.71'},
      }, violations: violations);

      expect(violations, isEmpty, reason: 'a lossless coercion is not a defect to report');
      // The coercion itself must still happen — silence here has to mean
      // "handled", never "ignored".
      expect(normalized['power'], 5);
      expect(normalized['freq'], 14.074);
      expect((normalized['our'] as Map)['lat'], 41.71);
    });

    test('reports each wrong-typed field by dotted path, without the value', () {
      // The path is what lets a report name the field; the value is withheld
      // deliberately — these fields carry callsigns, names and notes, and a
      // report travels to the crash backend.
      final violations = <QsonTypeViolation>[];
      normalizeQsoQson({
        'mode': true,
        'their': {'guess': {'name': 7}},
      }, violations: violations);
      expect(violations.map((v) => v.path), containsAll(['mode', 'their.guess.name']));
      expect(violations.first.toString(), isNot(contains('true')));
    });
  });

  group('normalizeOperationQson', () {
    test("parses polo's legacy *OnMillis spellings too", () {
      // Operation.createdAtMillis falls back to these, so leaving them
      // un-normalized would let a String stamp reach the same cast.
      final normalized = normalizeOperationQson({'createdOnMillis': '1721736000000'});
      expect(normalized['createdOnMillis'], 1721736000000);
    });

    test('drops a refs value that is not a list', () {
      expect(normalizeOperationQson({'refs': 'POTA'}).containsKey('refs'), isFalse);
    });
  });
}
