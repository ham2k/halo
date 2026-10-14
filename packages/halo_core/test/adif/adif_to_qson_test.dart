// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Real files from ten different loggers. The corpus is the point: ADIF is a
// standard that every program implements slightly differently, and no
// hand-written fixture would have caught LoTW's own timestamp format, QRZ's
// three overlapping confirmation blocks, or LogHK's ordering. Each `expect`
// below is a dialect difference, not a restatement of the mapper.
//
// Ported from web-kitchen's `qson-adif.spec.ts`, minus every reference
// assertion: refs belong to the `adifImport` hook, not to this layer.

import 'dart:convert';
import 'dart:io';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// Loggers write whatever their platform's encoding is and rarely declare it.
/// Malformed bytes must not cost the whole file.
AdifLog _load(String name) => parseAdifLog(const Utf8Decoder(allowMalformed: true).convert(File('test/adif/samples/$name').readAsBytesSync()));

int _at(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

/// Reads the file's own answer, so the expectation comes from the ADIF rather
/// than from a copy of the mapper's logic.
bool _confirmedInFile(String? qslRcvd) {
  final v = qslRcvd?.toUpperCase();
  return v == 'Y' || v == 'V';
}

Map<String, dynamic> _our(AdifRecord r) => r.qso['our'] as Map<String, dynamic>;
Map<String, dynamic> _their(AdifRecord r) => r.qso['their'] as Map<String, dynamic>;
Map<String, dynamic>? _qsl(AdifRecord r) => r.qso['qsl'] as Map<String, dynamic>?;

void main() {
  group('LoTW', () {
    late AdifLog log;
    setUpAll(() => log = _load('ki2d-lotw.adi'));

    test('reorders out-of-order records by time while keeping file position', () {
      // This file is genuinely out of order, which is what makes it the one
      // that proves the sort runs at all.
      final numbers = log.qsos.map((q) => q.number).toList();
      expect(numbers, isNot(orderedEquals([...numbers]..sort())));

      final times = log.qsos.map((q) => q.qso['startAtMillis'] as int).toList();
      expect(times, orderedEquals([...times]..sort()));
    });

    test('maps a QSO in full', () {
      expect(log.qsos, hasLength(13));
      final q = log.qsos[5];

      expect(q.number, 3);
      expect(q.qso['startAtMillis'], _at('2021-07-05T13:34:00Z'));
      expect(q.qso['freq'], 14075.9);
      expect(q.qso['band'], '20m');
      expect(q.qso['mode'], 'FT8');
      expect(_our(q)['call'], 'KI2D');
      expect(_our(q)['dxccCode'], 291);
      expect(_our(q)['county'], 'US/NY/SULLIVAN');
      expect(_our(q)['grid'], 'FN21RQ');
      expect(_our(q)['ituZone'], 8);
      expect(_our(q)['cqZone'], 5);
      expect(_their(q)['call'], 'WD4CVK');
      expect(_their(q)['dxccCode'], 291);
      expect(_their(q)['county'], 'US/GA/UNION');
      expect(_their(q)['grid'], 'EM74XU');
    });

    test("reads LoTW's own APP_LOTW_RXQSL stamp, which is not an ADIF date", () {
      final lotw = _qsl(log.qsos[5])!['lotw'] as Map<String, dynamic>;
      expect(lotw['receivedOn'], _at('2021-07-06T12:59:09Z'));
      expect(lotw['sentOn'], _at('2021-07-06T12:59:09Z'));
    });

    test('does not invent a paper QSL from the generic fields', () {
      // LoTW writes its own confirmation into QSL_RCVD/QSLRDATE. Trusting
      // those would claim the operator received a card they never got.
      expect(log.headers['programid'], 'LoTW');
      for (final q in log.qsos) {
        expect(_qsl(q)?.containsKey('qsl') ?? false, isFalse);
      }
    });
  });

  group('QRZ', () {
    late AdifLog log;
    setUpAll(() => log = _load('ki2d-qrz.adi'));

    test('maps a QSO in full', () {
      expect(log.qsos, hasLength(32));
      final q = log.qsos[5];

      expect(q.number, 6);
      expect(q.qso['startAtMillis'], _at('2021-05-04T10:59:00Z'));
      expect(q.qso['freq'], 7075.82);
      expect(q.qso['band'], '40m');
      expect(q.qso['mode'], 'FT8');
      expect(_our(q)['call'], 'KI2D');
      expect(_our(q)['country'], 'United States');
      expect(_our(q)['county'], 'US/NY/Sullivan');
      expect(_their(q)['call'], 'PJ4EL');
      expect(_their(q)['dxccCode'], 520);
      expect(_their(q)['country'], 'Bonaire');
      expect(_their(q)['continent'], 'SA');
      expect(_their(q)['cqZone'], 9);
    });

    test('a non-US country gets no invented county scheme', () {
      expect(_their(log.qsos[5]).containsKey('county'), isFalse);
    });

    test('carries all three confirmation services a QRZ download reports', () {
      // QRZ re-exports LoTW's dates alongside its own and the paper card's,
      // so this file is what proves the blocks are independent rather than
      // one winning.
      expect(_qsl(log.qsos[5]), {
        'qrz': {'received': true, 'id': '629033963', 'receivedOn': _at('2021-05-09T00:00:00Z')},
        'lotw': {'received': true, 'receivedOn': _at('2021-05-10T00:00:00Z'), 'sentOn': _at('2021-05-10T00:00:00Z')},
        'qsl': {'received': true, 'receivedOn': _at('2021-05-22T00:00:00Z'), 'sentOn': _at('2021-05-25T00:00:00Z')},
        'received': true,
      });
    });
  });

  group('N1MM', () {
    late AdifLog log;
    setUpAll(() => log = _load('ki2d-n1mm.adi'));

    test('maps a contest QSO, refs excluded', () {
      expect(log.qsos, hasLength(25));
      final q = log.qsos[5];

      expect(q.qso['startAtMillis'], _at('2022-02-19T13:21:06Z'));
      expect(q.qso['freq'], 14065.4);
      expect(q.qso['band'], '20m');
      expect(q.qso['mode'], 'CW');
      expect(_our(q)['call'], 'KI2D');
      expect(q.qso['power'], 100);
      expect(_their(q)['call'], 'HG5D');
      expect(_their(q)['cqZone'], 15);
      expect(_their(q)['sent'], '599');
      expect(_qsl(q), isNull);
    });

    test('CONTEST_ID produces no ref — the extension owns that', () {
      // The field is present in the file and preserved for the hook; the core
      // must not turn it into a ref itself.
      expect(log.qsos[5].fields['contest_id'], 'ARRL-DX-CW');
      expect(log.qsos[5].qso.containsKey('refs'), isFalse);
    });
  });

  group('Club Log', () {
    late AdifLog log;
    setUpAll(() => log = _load('ki2d-clublog.adi'));

    test('maps a QSO with no station callsign of our own', () {
      expect(log.qsos, hasLength(14));
      final q = log.qsos[5];

      expect(q.qso['startAtMillis'], _at('2020-05-20T01:25:00Z'));
      expect(q.qso['freq'], 14075.2);
      expect(q.qso['band'], '20m');
      expect(q.qso['mode'], 'FT8');
      expect(_our(q).containsKey('call'), isFalse);
      expect(_their(q)['call'], 'AF4MT');
      expect(_their(q)['dxccCode'], 291);
      expect(_their(q)['sent'], '599');
      expect((_qsl(q)!['qsl'] as Map)['receivedOn'], _at('2020-09-04T00:00:00Z'));
      expect(_qsl(q)!['received'], isTrue);
    });
  });

  group('MixW', () {
    late AdifLog log;
    setUpAll(() => log = _load('wo7r-mixw2.adi'));

    test('keeps a distinct end time', () {
      // Most loggers write only TIME_ON. This one records both, which is the
      // only case that exercises the end-time mapping.
      expect(log.qsos, hasLength(14));
      final q = log.qsos[5];

      expect(q.qso['startAtMillis'], _at('2023-04-02T00:08:58Z'));
      expect(q.qso['endAtMillis'], _at('2023-04-02T00:09:57Z'));
      expect(q.qso['freq'], 144116);
      expect(q.qso['band'], '2m');
      expect(q.qso['mode'], 'JT65');
      expect(_our(q)['call'], 'WO7R');
      expect(_their(q)['call'], 'G8RWG');
      expect(_their(q)['ituZone'], 27);
      expect(_their(q)['grid'], 'IO91');
      expect(_their(q)['entityName'], 'England');
      expect(_their(q)['dxccCode'], 223);
    });
  });

  group('HamRS POTA', () {
    late AdifLog log;
    setUpAll(() => log = _load('ki2d-pota.adi'));

    test('maps the QSO and leaves SIG_INFO to the hook', () {
      expect(log.qsos, hasLength(72));
      final q = log.qsos[0];

      expect(q.qso['startAtMillis'], _at('2023-09-07T23:27:27Z'));
      expect(q.qso['freq'], 14290);
      expect(q.qso['mode'], 'SSB');
      expect(_our(q)['grid'], 'FN54ui');
      expect(_their(q)['call'], 'AC9OT');
      expect(_their(q)['grid'], 'EN52es');

      expect(q.fields['sig_info'], 'K-1467');
      expect(q.fields['my_sig_info'], 'K-0001');
      expect(q.qso.containsKey('refs'), isFalse);
    });
  });

  group('Logger32', () {
    late AdifLog log;
    setUpAll(() => log = _load('k0xm-logger32.adi'));

    test('handles a thousand-QSO file', () {
      expect(log.qsos, hasLength(1015));
      final q = log.qsos[5];

      expect(q.qso['startAtMillis'], _at('2023-01-11T01:41:19Z'));
      expect(q.qso['freq'], 14076.11);
      expect(_our(q)['call'], 'K0XM');
      expect(_their(q)['call'], '4S7AVR');
      expect(_their(q)['dxccCode'], 315);
      // A digital signal report, not an RST — it must survive as written.
      expect(_their(q)['sent'], '-19');
    });
  });

  group('LogHK', () {
    late AdifLog log;
    setUpAll(() => log = _load('r6yy-loghk.adi'));

    test('maps consecutive records', () {
      expect(log.qsos, hasLength(423));

      expect(log.qsos[5].qso['startAtMillis'], _at('2024-01-01T04:00:00Z'));
      expect(log.qsos[5].qso['freq'], 3576.37);
      expect(log.qsos[5].qso['band'], '80m');
      expect(log.qsos[5].qso['mode'], 'FT4');
      expect(_their(log.qsos[5])['sent'], '+05');
      expect(log.qsos[6].qso['startAtMillis'], _at('2024-01-01T04:04:00Z'));
    });
  });

  group('LOGic', () {
    late AdifLog log;
    setUpAll(() => log = _load('nu4b-logic.adi'));

    test('maps consecutive records', () {
      expect(log.qsos, hasLength(139));

      expect(log.qsos[5].qso['startAtMillis'], _at('2025-01-03T18:15:27Z'));
      expect(log.qsos[5].qso['freq'], 28024);
      expect(log.qsos[5].qso['band'], '10m');
      expect(log.qsos[5].qso['mode'], 'CW');
      expect(_their(log.qsos[5])['dxccCode'], 50);
      expect(log.qsos[6].qso['startAtMillis'], _at('2025-01-03T20:06:45Z'));
    });
  });

  group('Station Master Pro', () {
    test('parses every record', () {
      expect(_load('ve9cf-smp.adi').qsos, hasLength(89));
    });
  });

  group('every sample', () {
    test('parses without a single record failing', () {
      // A file that produces errors is a mapping bug, not a bad file — these
      // ten all came out of shipping software. This can now actually fail:
      // `errors` is filled by an explicit viability predicate, not by a
      // catch block with no reachable throw.
      for (final name in Directory('test/adif/samples').listSync().map((e) => e.uri.pathSegments.last)) {
        final log = _load(name);
        expect(log.errors, isEmpty, reason: '$name produced errors');
        expect(log.qsos, isNotEmpty, reason: '$name produced no QSOs');
      }
    });

    test('ten real logs parse with no warnings at all', () {
      // A channel that fires on everything is worth as little as one that
      // cannot fire at all, and these files came out of shipping software:
      // every length anomaly in them is one the parser recovers. A warning
      // appearing here means either a real regression or a new dialect —
      // both worth stopping for.
      var qsos = 0;
      var warnings = 0;
      for (final name in Directory('test/adif/samples').listSync().map((e) => e.uri.pathSegments.last)) {
        final log = _load(name);
        qsos += log.qsos.length;
        warnings += log.warnings.length;
      }
      expect(qsos, greaterThan(1500));
      expect(warnings, isZero);
    });

    test('a character-counted value is recovered whole, not left a byte short', () {
      // ki2d-pota.adi (HamRS) writes `<qth:15>Tía Juana Zulia` — 15 characters,
      // 16 bytes. Reading the spec's byte count stops one byte short, so the
      // value must be re-cut as characters or every accented field in the file
      // loses its last letter. Asserting the WHOLE value: a length-only check
      // would pass on the truncated reading too.
      final log = _load('ki2d-pota.adi');
      final cities = log.qsos.map((q) => _their(q)['city']).whereType<String>();
      final names = log.qsos.map((q) => _their(q)['name']).whereType<String>();

      expect(cities, contains('Tía Juana Zulia'));
      expect(names, contains('MARIANO ORDOÑEZ TERRON'));
      expect(names, contains('RICARDO IBAÑEZ BURGUET'));
    });

    test('a recovered length is not reported as suspect', () {
      // The value came out right. Warning about it would train the operator to
      // ignore the channel, which is what the channel exists to avoid.
      final log = _load('ki2d-pota.adi');

      expect(log.warnings, isEmpty);
      expect(log.errors, isEmpty);
    });
  });

  group('viability', () {
    // The whole point of this group: before it existed, every case below
    // imported as a clean, successful QSO and `errors` was structurally
    // incapable of filling.

    test('a record with no callsign is an error, not a contact', () {
      final log = parseAdifLog('<EOH>\n<BAND:3>20m<QSO_DATE:8>20240723<EOR>');

      expect(log.qsos, isEmpty);
      expect(log.errors.single.problems, contains(AdifRecordProblem.noCallsign));
      // The record is still carried, so an operator can see what was read.
      expect(log.errors.single.fields['band'], '20m');
    });

    test('a header-only file with no EOH yields no phantom QSO', () {
      final log = parseAdifLog('<ADIF_VER:5>3.1.4<PROGRAMID:7>Logger1');

      expect(log.qsos, isEmpty);
    });

    test('an undated contact imports, but says so', () {
      // app-polo's own logs can carry undated contacts, so this is importable
      // — it just cannot be placed in the timeline, deduped or scored.
      final log = parseAdifLog('<EOH>\n<CALL:4>W1AW<EOR>');

      expect(log.qsos, hasLength(1));
      expect(log.warnings.single.problems, [AdifRecordProblem.noTimestamp]);
    });

    test('a record whose field length overran is imported and flagged', () {
      final log = parseAdifLog('<EOH>\n<CALL:6>W1AW<BAND:3>20m<QSO_DATE:8>20240723<EOR>');

      expect(log.warnings.single.problems, contains(AdifRecordProblem.suspectFieldLength));
    });

    test('a clean record produces no warning at all', () {
      // Guards the group above: if everything warned, none of it would mean
      // anything.
      final log = parseAdifLog('<EOH>\n<CALL:4>W1AW<QSO_DATE:8>20240723<TIME_ON:6>120000<EOR>');

      expect(log.qsos, hasLength(1));
      expect(log.warnings, isEmpty);
      expect(log.errors, isEmpty);
    });

    test('the record number stays a position in the file', () {
      // It is documented as the handle an operator gets for finding the bad
      // line, so an empty <EOR> must not shift it.
      final log = parseAdifLog('<EOH>\n<EOR>\n<CALL:4>W1AW<QSO_DATE:8>20240723<EOR>');

      expect(log.qsos.single.number, 2);
    });
  });

  group('the city fields', () {
    // ADIF names the contacted station's city `QTH` and our own `MY_CITY` —
    // asymmetric in the spec itself. Both sides land in QSON `city`, and the
    // ORDER of the `_set` calls is what decides a record carrying both
    // spellings. Nothing else pins that, so a reordering would be silent.
    AdifRecord only(String record) {
      final log = parseAdifLog('<EOH>\n$record<EOR>\n');
      return log.qsos.single;
    }

    test('QTH is the contacted station\'s city, not a separate key', () {
      // The round trip HaLo's own exporter needs: it writes QTH from
      // `their.city`, so reading it back anywhere else loses the value —
      // nothing in the app reads a `their.qth`.
      final r = only('<CALL:5>W1ABC<QTH:6>Berlin');

      expect(_their(r)['city'], 'Berlin');
      expect(_their(r).containsKey('qth'), isFalse);
    });

    test('an explicit CITY wins over QTH', () {
      // CITY is not an ADIF field, but software invents it. A file that writes
      // both means the more specific one.
      final r = only('<CALL:5>W1ABC<QTH:37>Kralendijk, Bonaire, Dutch Caribbean<CITY:10>Kralendijk');

      expect(_their(r)['city'], 'Kralendijk');
    });

    test('MY_CITY wins over MY_QTH, the standard field beating the invention', () {
      // Our side inverts which spelling is the standard one, so the precedence
      // rule is "ADIF's field wins", not "the second one wins".
      final r = only('<CALL:5>W1ABC<MY_QTH:8>Woodland<MY_CITY:9>Woodridge');

      expect(_our(r)['city'], 'Woodridge');
    });

    test('MY_QTH alone still lands somewhere readable', () {
      final r = only('<CALL:5>W1ABC<MY_QTH:9>Woodridge');

      expect(_our(r)['city'], 'Woodridge');
    });
  });

  group('power', () {
    AdifRecord only(String record) {
      final log = parseAdifLog('<EOH>\n$record<EOR>\n');
      return log.qsos.single;
    }

    test('TX_PWR lands top-level, alongside freq/band/mode — not under our', () {
      final r = only('<CALL:5>W1ABC<TX_PWR:3>100');

      expect(r.qso['power'], 100);
      expect(_our(r).containsKey('power'), isFalse);
    });

    test('RX_PWR lands under their — the other station\'s power, not ours', () {
      final r = only('<CALL:5>W1ABC<RX_PWR:2>50');

      expect(_their(r)['power'], 50);
      expect(r.qso.containsKey('power'), isFalse);
    });
  });

  // A sponsor's credit is the strongest level a chasing program can read
  // (docs/design/claims.md §4), so a credit dropped here leaves the contact
  // merely confirmed, and one filed under the wrong program verifies a slot
  // the sponsor never credited.
  group('award credit', () {
    Map<String, dynamic>? creditsOf(String granted) {
      final record = parseAdifLog('<EOH>\n<CALL:5>W1ABC<CREDIT_GRANTED:${granted.length}>$granted<EOR>\n').qsos.single;
      return record.qso['credits'] as Map<String, dynamic>?;
    }

    test('DXCC credit is the DXCC program\'s, with each award it was granted for', () {
      expect(creditsOf('DXCC:card&lotw,DXCC_BAND:lotw'), {
        'dxcc': {
          'level': 'verified',
          'by': 'lotw',
          'awards': ['DXCC', 'DXCC_BAND'],
        },
      });
    });

    test('a card counts as what verified it when it is the only medium named', () {
      expect((creditsOf('dxcc_mode:CARD')!['dxcc'] as Map)['by'], 'qsl');
    });

    test('a credit naming no medium is still a credit', () {
      expect(creditsOf('DXCC'), {
        'dxcc': {
          'level': 'verified',
          'awards': ['DXCC'],
        },
      });
    });

    test('WAS credit is the WAS program\'s, beside DXCC\'s from the same list', () {
      expect(creditsOf('WAS:lotw,DXCC:card,WAS_MODE:lotw'), {
        'ham2k-was': {
          'level': 'verified',
          'by': 'lotw',
          'awards': ['WAS', 'WAS_MODE'],
        },
        'dxcc': {
          'level': 'verified',
          'by': 'qsl',
          'awards': ['DXCC'],
        },
      });
    });

    test('awards no program chases are left out, and a list of only those leaves no credits', () {
      expect(creditsOf('WAZ:lotw,IOTA:card'), isNull);
    });
  });

  group('lengths that over-declare', () {
    test('trailing whitespace dragged in by an over-declared length is stripped', () {
      // ki2d-qrz.adi really writes <qth:37> for a 36-byte value.
      final log = _load('ki2d-qrz.adi');
      final withQth = log.qsos.firstWhere((q) => q.fields['qth'] == 'Kralendijk, Bonaire, Dutch Caribbean');

      expect((_their(withQth)['city'] as String).endsWith('\n'), isFalse);
    });

    test("a PROGRAMID with a swallowed newline still identifies the logger", () {
      // ve9cf-smp.adi writes <PROGRAMID:19> for 18 bytes. _genericQslFor
      // compares this header, so an untrimmed value silently takes the wrong
      // branch and invents paper QSLs on a LoTW file.
      expect(_load('ve9cf-smp.adi').headers['programid'], 'Station Master Pro');

      final log = parseAdifLog(
        '<PROGRAMID:5>LoTW\n<EOH>\n'
        '<CALL:4>W1AW<QSO_DATE:8>20240723<QSL_RCVD:1>Y<EOR>',
      );
      expect(log.headers['programid'], 'LoTW');
      expect(log.qsos.single.qso['qsl'], isNull);
    });
  });

  group('empty fields', () {
    // Loggers write them: ve9cf-smp.adi carries 14 <COMMENT:0>, plus
    // <MY_IOTA:0>, <PROP_MODE:0>, <SAT_NAME:0>, <STX_STRING:0>.

    test('an empty SUBMODE does not erase the mode', () {
      // `??` only skips null, so an empty submode wins over a real mode and
      // leaves the QSO mode-less — and the ADIF exporter defaults a mode-less
      // QSO to SSB, so this FT8 contact round-trips out as SSB.
      final log = parseAdifLog('<CALL:4>W1AW<MODE:3>FT8<SUBMODE:0><EOR>');

      expect(log.qsos.single.qso['mode'], 'FT8');
    });

    test('an empty confirmation date does not mark the QSO confirmed', () {
      final log = parseAdifLog('<CALL:4>W1AW<LOTW_QSLRDATE:0><EOR>');

      expect(log.qsos.single.qso['qsl'], isNull);
    });

    test('an empty NOTES falls through to COMMENT', () {
      final log = parseAdifLog('<CALL:4>W1AW<NOTES:0><COMMENT:5>hello<EOR>');

      expect(log.qsos.single.qso['notes'], 'hello');
    });

    test('an empty TIME_ON falls through to TIME_OFF', () {
      final log = parseAdifLog('<CALL:4>W1AW<QSO_DATE:8>20240723<TIME_ON:0><TIME_OFF:6>123456<EOR>');

      expect(log.qsos.single.qso['startAtMillis'], _at('2024-07-23T12:34:56Z'));
    });
  });

  group('dates', () {
    test('an impossible date is no date, not a confident wrong one', () {
      // DateTime.utc normalizes rather than rejecting: Feb 30 would become
      // March, putting the QSO on the wrong day, in the wrong contest period,
      // sorted among the wrong contacts.
      final log = parseAdifLog('<EOH>\n<CALL:4>W1AW<QSO_DATE:8>20250230<TIME_ON:6>995959<EOR>');

      expect(log.qsos.single.qso.containsKey('startAtMillis'), isFalse);
      expect(log.warnings.single.problems, contains(AdifRecordProblem.noTimestamp));
    });

    test('a month-end overflow is rejected too', () {
      final log = parseAdifLog('<CALL:4>W1AW<QSO_DATE:8>20250431<EOR>');

      expect(log.qsos.single.qso.containsKey('startAtMillis'), isFalse);
    });

    test('a real leap day is accepted', () {
      // Guards the check above from being too strict.
      final log = parseAdifLog('<CALL:4>W1AW<QSO_DATE:8>20240229<EOR>');

      expect(log.qsos.single.qso['startAtMillis'], _at('2024-02-29T00:00:00Z'));
    });

    test('a garbled time is no time, rather than midnight', () {
      final log = parseAdifLog('<CALL:4>W1AW<QSO_DATE:8>20240723<TIME_ON:6>12AB00<EOR>');

      expect(log.qsos.single.qso.containsKey('startAtMillis'), isFalse);
    });

    test('LOTW_QSLRDATE written as a timestamp still yields a date', () {
      // Station Master Pro writes this form in 27 of ve9cf-smp.adi's records,
      // alongside 30 in the plain YYYYMMDD form.
      final log = parseAdifLog('<CALL:4>W1AW<LOTW_QSLRDATE:19>2026-05-12 11:15:41<EOR>');
      final lotw = (log.qsos.single.qso['qsl'] as Map)['lotw'] as Map;

      expect(lotw['receivedOn'], _at('2026-05-12T11:15:41Z'));
    });

    // The ADIF field is EQSL_QSLRDATE, and it is what the ADIF export writes:
    // reading any other name loses the date on every round trip.
    test('an eQSL confirmation keeps its date', () {
      final log = parseAdifLog('<CALL:4>W1AW<EQSL_QSL_RCVD:1>Y<EQSL_QSLRDATE:8>20260512<EOR>');
      final eqsl = (log.qsos.single.qso['qsl'] as Map)['eqsl'] as Map;

      expect(eqsl['receivedOn'], _at('2026-05-12T00:00:00Z'));
    });

    test('every LoTW confirmation in the SMP file resolves a date', () {
      final log = _load('ve9cf-smp.adi');
      final confirmed = log.qsos.where((q) => ((q.qso['qsl'] as Map?)?['lotw'] as Map?) != null);

      expect(confirmed, isNotEmpty);
      for (final q in confirmed) {
        final lotw = (q.qso['qsl'] as Map)['lotw'] as Map;
        expect(lotw['receivedOn'], isNotNull, reason: 'record ${q.number} lost its LoTW date');
      }
    });
  });

  group('QSL enumerations', () {
    test("'V' means verified, which is a confirmation", () {
      // ki2d-clublog.adi writes V on 8 of its 14 records — dropping it
      // discards the strongest evidence a log carries.
      final log = parseAdifLog('<PROGRAMID:4>N1MM<eoh><CALL:4>W1AW<QSL_RCVD:1>V<EOR>');

      expect(((log.qsos.single.qso['qsl'] as Map)['qsl'] as Map)['received'], isTrue);
    });

    test('the value is matched case-insensitively, like every ADIF enumeration', () {
      // Tag NAMES are normalized; values are not, and loggers lowercase them.
      final log = parseAdifLog('<PROGRAMID:4>N1MM<eoh><CALL:4>W1AW<QSL_RCVD:1>y<EOR>');

      expect(log.qsos.single.qso['qsl'], isNotNull);
    });

    test('N and R are not confirmations', () {
      // Guards the two above from simply accepting anything.
      for (final value in ['N', 'R', 'I']) {
        final log = parseAdifLog('<PROGRAMID:4>N1MM<eoh><CALL:4>W1AW<QSL_RCVD:1>$value<EOR>');

        expect(log.qsos.single.qso['qsl'], isNull, reason: value);
      }
    });

    test('every confirmed Club Log record carries a QSL', () {
      // 6 Y plus 8 V in that file; before this, the 8 imported unconfirmed.
      final log = _load('ki2d-clublog.adi');
      final confirmed = log.qsos.where((q) => _confirmedInFile(q.fields['qsl_rcvd']));

      expect(confirmed, hasLength(14));
      for (final q in confirmed) {
        expect(q.qso['qsl'], isNotNull, reason: 'record ${q.number}');
      }
    });
  });

  group('missing EOH', () {
    test('a LoTW file without EOH does not invent paper QSL cards', () {
      // headers is filled only from an EOH-closed segment, so without one the
      // writing program can be identified solely from the record's own fields
      // — and getting this wrong invents a card the operator never received.
      const body = '<CALL:4>W1AW<QSO_DATE:8>20250201<QSL_RCVD:1>Y<QSLRDATE:8>20250201<EOR>';
      final log = parseAdifLog('<ADIF_VER:5>3.1.4<PROGRAMID:4>LoTW\n$body');

      expect(log.qsos.single.qso['qsl'], isNull);
    });

    test('a non-LoTW file without EOH still records its paper QSL', () {
      const body = '<CALL:4>W1AW<QSO_DATE:8>20250201<QSL_RCVD:1>Y<QSLRDATE:8>20250201<EOR>';
      final log = parseAdifLog('<PROGRAMID:3>N1MM\n$body');

      expect(((log.qsos.single.qso['qsl'] as Map)['qsl'] as Map)['received'], isTrue);
    });
  });

  group('malformed input', () {
    test('recovers brackets and length-less tags', () {
      final log = parseAdifLog('''
Header text <PROGRAMID>Ham2K LoKi
<PROGRAMVERSION>1.0.0
<EOH>
<CALL:6>WD4CVK
<BAND:3>20m
<my_gridsquare:6>EM10CM
<operator:6>KJ5BYC
<qso_date_off:8
20240723 <EOR>
''');

      expect(log.headers['programid'], 'Ham2K LoKi');
      expect(log.headers['programversion'], '1.0.0');
      expect(log.qsos, hasLength(1));
      expect(_their(log.qsos[0])['call'], 'WD4CVK');
      expect(log.qsos[0].qso['band'], '20m');
      expect(_our(log.qsos[0])['call'], 'KJ5BYC');
    });

    test('a record with no date still maps, and sorts first', () {
      final log = parseAdifLog(
        '<CALL:4>W1AW<QSO_DATE:8>20240723<TIME_ON:6>120000<EOR>'
        '<CALL:4>K1AA<EOR>',
      );

      expect(log.qsos, hasLength(2));
      expect(_their(log.qsos[0])['call'], 'K1AA');
      expect(log.qsos[0].qso.containsKey('startAtMillis'), isFalse);
    });

    test('a contact crossing midnight ends the next day, not before it began', () {
      final log = parseAdifLog('<CALL:4>W1AW<QSO_DATE:8>20240723<TIME_ON:6>235800<TIME_OFF:6>000200<EOR>');

      expect(log.qsos[0].qso['startAtMillis'], _at('2024-07-23T23:58:00Z'));
      expect(log.qsos[0].qso['endAtMillis'], _at('2024-07-24T00:02:00Z'));
    });

    test('NaN and Infinity are dropped, not thrown on', () {
      // double.tryParse accepts both literals and .round() on either throws,
      // which would abort the import over one garbage field.
      for (final garbage in ['NaN', 'Infinity', '-Infinity']) {
        final log = parseAdifLog('<CALL:4>W1AW<FREQ:${garbage.length}>$garbage<BAND:3>20m<EOR>');

        expect(log.qsos.single.qso.containsKey('freq'), isFalse, reason: garbage);
        expect(log.qsos.single.qso['band'], '20m');
      }
    });

    test('a truncated file reports the record as suspect', () {
      // The counterpart to the parser's truncation test: a short value must
      // reach the operator as a warning, not as clean data.
      final log = parseAdifLog('<EOH>\n<CALL:4>W1AW<QSO_DATE:8>20240723<NAME:9>ééé');

      expect(log.warnings.single.problems, contains(AdifRecordProblem.suspectFieldLength));
    });

    test('a non-numeric frequency is dropped rather than coerced', () {
      // QSON types `freq` as a number; a band written alongside still lands.
      final log = parseAdifLog('<CALL:4>W1AW<FREQ:7>unknown<BAND:3>20m<EOR>');

      expect(log.qsos[0].qso.containsKey('freq'), isFalse);
      expect(log.qsos[0].qso['band'], '20m');
    });

    test('SUBMODE wins over MODE', () {
      final log = parseAdifLog('<CALL:4>W1AW<MODE:4>MFSK<SUBMODE:3>FT4<EOR>');

      expect(log.qsos[0].qso['mode'], 'FT4');
    });

    test('HTML-escaped text is decoded, a bare ampersand is left alone', () {
      final log = parseAdifLog('<CALL:4>W1AW<NOTES:27>Bell &amp; Howell &#65; & B<EOR>');

      expect(log.qsos[0].qso['notes'], 'Bell & Howell A & B');
    });
  });

  group('coordinates', () {
    test("a real file's LAT/MY_LAT arrive as numbers, in the degrees QSON stores", () {
      // ki2d-qrz.adi carries QRZ's own `<lat:11>N010 29.466` — ADIF states a
      // coordinate in degrees and decimal MINUTES, so a mapper that copies the
      // field verbatim (or reads 10.29466 out of it) puts the station tens of
      // kilometres away, or in a type nothing downstream can measure with.
      final log = _load('ki2d-qrz.adi');
      final withLat = log.qsos.firstWhere((q) => q.fields['lat'] == 'N010 29.466');

      expect(_their(withLat)['lat'], closeTo(10.4911, 1e-4));
      expect(_our(withLat)['lat'], closeTo(41.6875, 1e-4));
    });

    test('a southern hemisphere letter reads as a negative latitude', () {
      final log = _load('ki2d-qrz.adi');
      final southern = log.qsos.firstWhere((q) => q.fields['lat'] == 'S035 14.574');

      expect(_their(southern)['lat'], closeTo(-35.2429, 1e-4));
    });

    test('parses the ADIF Location format on both axes', () {
      expect(parseAdifCoordinate('N041 22.500', latitude: true), closeTo(41.375, 1e-9));
      expect(parseAdifCoordinate('W074 27.000', latitude: false), closeTo(-74.45, 1e-9));
      expect(parseAdifCoordinate('S033 51.600', latitude: true), closeTo(-33.86, 1e-9));
      expect(parseAdifCoordinate('E151 12.600', latitude: false), closeTo(151.21, 1e-9));
    });

    test('accepts the widths other loggers actually write, not only the padded form', () {
      expect(parseAdifCoordinate('N41 22.5', latitude: true), closeTo(41.375, 1e-9));
      expect(parseAdifCoordinate(' n041 22.500 ', latitude: true), closeTo(41.375, 1e-9));
    });

    test('accepts bare decimal degrees, which several exporters write instead', () {
      expect(parseAdifCoordinate('41.375', latitude: true), closeTo(41.375, 1e-9));
      expect(parseAdifCoordinate('-74.45', latitude: false), closeTo(-74.45, 1e-9));
    });

    test('refuses a hemisphere letter belonging to the other axis', () {
      // A file with LAT and LON swapped is likelier than a station at `E041`
      // latitude, and importing it silently would put the QSO somewhere
      // nobody was.
      expect(parseAdifCoordinate('E041 22.500', latitude: true), isNull);
      expect(parseAdifCoordinate('N074 27.000', latitude: false), isNull);
    });

    test('refuses values no coordinate can hold', () {
      expect(parseAdifCoordinate('N091 00.000', latitude: true), isNull);
      expect(parseAdifCoordinate('E181 00.000', latitude: false), isNull);
      expect(parseAdifCoordinate('N041 60.000', latitude: true), isNull, reason: 'sixty minutes is a degree');
      expect(parseAdifCoordinate('', latitude: true), isNull);
      expect(parseAdifCoordinate('not a coordinate', latitude: true), isNull);
    });

    test('a longitude past 90 is in range — the axes have different limits', () {
      expect(parseAdifCoordinate('E120 30.000', latitude: false), closeTo(120.5, 1e-9));
    });
  });

  group('the operator and the position', () {
    test('OPERATOR is who was at the key, and never overwrites the station call', () {
      // Two different facts sharing one field in most files: a logger that
      // writes only OPERATOR means it as the station call too, but where
      // STATION_CALLSIGN is also present it wins — importing K0XM's guest
      // operator as the transmitted call would misattribute the whole log.
      final log = parseAdifLog(
        '<EOH>\n'
        '<CALL:4>W1AW<QSO_DATE:8>20240723<STATION_CALLSIGN:6>KI2D/P<OPERATOR:4>K0XM<EOR>\n'
        '<CALL:5>K1ABC<QSO_DATE:8>20240723<OPERATOR:4>K0XM<EOR>',
      );

      expect(_our(log.qsos[0]), containsPair('call', 'KI2D/P'));
      expect(_our(log.qsos[0]), containsPair('operatorCall', 'K0XM'));
      // Nothing else said which call went out, so OPERATOR is both.
      expect(_our(log.qsos[1]), containsPair('call', 'K0XM'));
      expect(_our(log.qsos[1]), containsPair('operatorCall', 'K0XM'));
    });

    test('our own position field round-trips, and another program\'s does not', () {
      // ADIF names no field for a multi-station operating position, so ours
      // is app-defined. `APP_N1MM_RADIO_NR` counts radios at N1MM's station
      // and means nothing here — reading it would invent a position.
      final log = parseAdifLog(
        '<EOH>\n'
        '<CALL:4>W1AW<QSO_DATE:8>20240723<APP_HAM2K_POSITION:1>2<EOR>\n'
        '<CALL:5>K1ABC<QSO_DATE:8>20240723<APP_N1MM_RADIO_NR:1>2<EOR>',
      );

      expect(_our(log.qsos[0]), containsPair('multiIdentifier', '2'));
      expect(_our(log.qsos[1]), isNot(contains('multiIdentifier')));
    });

    test('a real file names its operator', () {
      expect(_our(_load('k0xm-logger32.adi').qsos.first), containsPair('operatorCall', 'K0XM'));
    });
  });
}
