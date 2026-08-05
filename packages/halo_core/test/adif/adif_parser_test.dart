// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The tokenizer's own tests. Every case here is a shape that desynchronizes a
// strict length-prefixed reader — once the parser loses its place, every byte
// after it is garbage, so these are about the parser NOT giving up rather than
// about any particular field's value.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

List<AdifSegment> _segments(String text) => parseAdifSegments(text).toList();

Map<String, String> _values(AdifSegment segment) => {
      for (final f in segment.fields) f.name.toLowerCase(): f.value,
    };

void main() {
  group('parseAdifSegments', () {
    test('splits header and records on their end markers', () {
      final segments = _segments('Comment\n<ADIF_VER:5>3.1.5<EOH>\n<CALL:4>KI2D<EOR>\n<CALL:4>W1AW<EOR>\n');

      expect(segments.map((s) => s.type), [
        AdifSegmentType.header,
        AdifSegmentType.record,
        AdifSegmentType.record,
      ]);
      expect(segments[0].preamble, 'Comment\n');
      expect(_values(segments[1])['call'], 'KI2D');
      expect(_values(segments[2])['call'], 'W1AW');
    });

    test('markers and tag names are case-insensitive', () {
      final segments = _segments('<adif_ver:5>3.1.5<eoh><Call:4>W1AW<eor>');

      expect(segments[0].type, AdifSegmentType.header);
      expect(segments[1].type, AdifSegmentType.record);
      expect(_values(segments[1])['call'], 'W1AW');
    });

    test('reads the declared length, not up to the next tag', () {
      // The value contains a `<` and a `>` of its own. A parser that scanned
      // for delimiters instead of honouring the length would truncate here and
      // then read the rest of the value as a tag.
      final segments = _segments('<NOTES:11>a <b> c d e<EOR>');

      expect(_values(segments[0])['notes'], 'a <b> c d e');
    });

    test('a declared length past the end of the file truncates', () {
      // A log cut mid-write. The bytes that did arrive are still a QSO.
      final segments = _segments('<CALL:20>KI2D');

      expect(segments, hasLength(1));
      expect(_values(segments[0])['call'], 'KI2D');
      expect(segments[0].fields.single.length, 20);
    });

    test('recovers a tag missing its closing bracket', () {
      // The newline stood in for the `>`, so it must not become the value's
      // first character.
      final segments = _segments('<CALL:4>W1AW\n<QSO_DATE_OFF:8\n20240723 <EOR>');

      expect(_values(segments[0]), containsPair('qso_date_off', '20240723'));
    });

    test('reads PROGRAMID and PROGRAMVERSION written without a length', () {
      final segments = _segments('<PROGRAMID>Ham2K LoKi\n<PROGRAMVERSION>1.0.0\n<EOH>');

      expect(_values(segments[0]), {'programid': 'Ham2K LoKi', 'programversion': '1.0.0'});
    });

    test('a length-less PROGRAMID ends at the next tag on the same line', () {
      final segments = _segments('<PROGRAMID>LoKi<EOH>');

      expect(_values(segments[0])['programid'], 'LoKi');
      expect(segments[0].endMarker, 'EOH');
    });

    test('a bare tag that is not PROGRAMID stays a literal', () {
      // Generalizing the length-less rule would silently corrupt QSO data:
      // there is no way to know where such a value ends. Losing the text is
      // the safe failure.
      final segments = _segments('<CALL>W1AW<EOR>');

      expect(segments.single.fields, isEmpty);
      expect(segments.single.preamble, '<CALL>W1AW');
    });

    test('a stray angle bracket is a literal character, not a lost record', () {
      final segments = _segments('2 < 3 <CALL:4>W1AW<EOR>');

      expect(_values(segments[0])['call'], 'W1AW');
      expect(segments[0].preamble, '2 < 3 ');
    });

    test('fields left open at end of file are still yielded', () {
      final segments = _segments('<CALL:4>KI2D<EOR><CALL:4>W1AW<BAND:3>20m');

      expect(segments, hasLength(2));
      expect(segments[1].endMarker, isEmpty);
      expect(_values(segments[1])['band'], '20m');
    });

    test('trailing text after a value lands on that field, not the next record', () {
      final segments = _segments('<CALL:4>W1AW   \n<EOR>');

      expect(segments[0].fields.single.extraData, '   \n');
    });

    test('an optional type indicator is captured and not eaten by the value', () {
      final segments = _segments('<QSO_DATE:8:D>20240723<EOR>');

      final field = segments[0].fields.single;
      expect(field.type, 'D');
      expect(field.value, '20240723');
    });

    test('a declared length counts BYTES, not characters', () {
      // The ADIF spec counts bytes. Dart string indices are UTF-16 code
      // units, so reading this as characters consumes one unit too many —
      // which eats the '<' of the next tag, merges two records into one, and
      // loses a contact outright with nothing reported.
      final segments = _segments('<CALL:4>W1AW<NAME:5>José<EOR>\n<CALL:5>K1ABC<EOR>');

      expect(segments, hasLength(2));
      expect(_values(segments[0]), {'call': 'W1AW', 'name': 'José'});
      expect(_values(segments[1])['call'], 'K1ABC');
    });

    test('a multi-byte value is decoded whole', () {
      // 'Москва' is 6 characters and 12 bytes.
      final segments = _segments('<QTH:12>Москва<EOR>');

      expect(_values(segments[0])['qth'], 'Москва');
      expect(segments[0].fields.single.anomaly, isNull);
    });

    test('malformed bytes cost their own character, not the file', () {
      final segments = parseAdifBytes([
        ...'<CALL:4>W1AW<QTH:2>'.codeUnits,
        0xff, 0xfe, // not valid UTF-8
        ...'<EOR>'.codeUnits,
      ]).toList();

      expect(_values(segments[0])['call'], 'W1AW');
      expect(segments[0].fields.last.value, isNotEmpty);
    });

    test('a character-counted length is re-read as characters', () {
      // 'Tía Juana Zulia' is 15 characters and 16 bytes. HamRS writes the
      // character count, so the byte reading stops one short — on 'a', which
      // is not where an ADIF value may end.
      final segments = _segments('<QTH:15>Tía Juana Zulia<EOR>');

      expect(_values(segments[0])['qth'], 'Tía Juana Zulia');
      expect(segments[0].fields.single.anomaly, AdifFieldAnomaly.characterCount);
    });

    test('a human-readable annotation after a value is not damage', () {
      // LoTW writes commentary between a value and the next tag. Judging the
      // boundary by scanning ahead to the next '<' reads every one of those as
      // an over-read and flags a clean file end to end — the value ends on
      // whitespace, and that is the whole test.
      final segments = _segments('<CNTY:12>US,NY,ORANGE // New York\n<EOR>');

      expect(_values(segments[0])['cnty'], 'US,NY,ORANGE');
      expect(segments[0].fields.single.anomaly, isNull);
      expect(segments[0].fields.single.extraData, ' // New York\n');
    });

    test('a bad length never swallows the next tag', () {
      // Both readings overrun here (ASCII, so they agree), and the overrun
      // eats the '<' that opens BAND. Keeping it would lose the whole field;
      // the value is handed back at the tag opener instead, and still flagged.
      final segments = _segments('<CALL:6>W1AW<BAND:3>20m<EOR>');

      expect(segments.single.fields.first.anomaly, AdifFieldAnomaly.unterminated);
      expect(segments.single.fields.first.value, 'W1AW');
      expect(_values(segments[0])['band'], '20m');
    });

    test('an over-declared length does not eat an EOR and merge two contacts', () {
      // <CALL:5> for a 4-byte value with no whitespace before <eor>. Swallowing
      // the marker merges the records into one segment, where the second's
      // fields overwrite the first's — and a contact disappears from the log
      // with only a warning on the survivor to show for it.
      final segments = _segments(
        '<eoh><QSO_DATE:8>20240101<CALL:5>W1AW<eor><QSO_DATE:8>20240102<CALL:4>W2AW<eor>',
      );

      expect(segments.map((s) => s.type), [
        AdifSegmentType.header,
        AdifSegmentType.record,
        AdifSegmentType.record,
      ]);
      expect(_values(segments[1])['call'], 'W1AW');
      expect(_values(segments[2])['call'], 'W2AW');
    });

    test('a value that legitimately contains a tag opener is left alone', () {
      // Guards the clamp above from firing on a correct length: this one lands
      // on the next '<', so nothing is wrong and nothing is trimmed.
      final segments = _segments('<NOTES:11>a <b> c d e<EOR>');

      expect(_values(segments[0])['notes'], 'a <b> c d e');
      expect(segments[0].fields.single.anomaly, isNull);
    });

    test('an astral character counts as two, the way a JS writer counted it', () {
      // '😀' is one code point, two UTF-16 code units, four bytes — so a
      // logger using String.length wrote 5 for 'ab😀c'.
      final segments = _segments('<NOTES:5>ab😀c<EOR>');

      expect(_values(segments[0])['notes'], 'ab😀c');
      expect(segments[0].fields.single.anomaly, AdifFieldAnomaly.characterCount);
    });

    test('a correct byte count is never second-guessed', () {
      // Guards the recovery from firing on conformant files: 'José' is 5
      // bytes, the length says 5, and it lands cleanly.
      final segments = _segments('<NAME:5>José<EOR>');

      expect(_values(segments[0])['name'], 'José');
      expect(segments[0].fields.single.anomaly, isNull);
    });

    test('a length that overruns into the next tag is flagged, not accepted quietly', () {
      // Recovery and corruption are indistinguishable from the outside unless
      // the parser says which it did.
      // Declared 6 for a 4-byte value: the read ends inside `<BAND:3>`.
      final segments = _segments('<CALL:6>W1AW<BAND:3>20m<EOR>');

      expect(segments.single.fields.first.anomaly, AdifFieldAnomaly.unterminated);
    });

    test('a length past the end of the file is flagged as truncated', () {
      final segments = _segments('<CALL:20>KI2D');

      expect(segments.single.fields.single.anomaly, AdifFieldAnomaly.truncated);
      expect(_values(segments[0])['call'], 'KI2D');
    });

    test('a length that lands on a separator or the next tag is not flagged', () {
      final clean = _segments('<CALL:4>W1AW <BAND:3>20m<EOR>');

      expect(clean[0].fields.every((f) => f.anomaly == null), isTrue);
    });

    test('an over-declared length that stops at the newline is not flagged', () {
      // ki2d-qrz.adi really does this: <qth:37> for a 36-byte value. The
      // value swallows the newline but still ends at the next '<', so it is
      // recoverable by trimming rather than a desync.
      final segments = _segments('<QTH:5>abcd\n<EOR>');

      expect(segments[0].fields.single.anomaly, isNull);
      expect(segments[0].fields.single.value, 'abcd\n');
    });

    test('an absurd declared length does not throw', () {
      // A corrupt byte run in a length field is exactly the malformed input
      // this parser exists to survive; int.parse throws past 2^63 and would
      // take the whole import down instead of losing one field.
      final segments = _segments('<CALL:99999999999999999999>N0CALL <EOR>');

      expect(segments.single.fields.single.anomaly, AdifFieldAnomaly.truncated);
    });

    test('a file that ends mid-value is truncated, not "recovered"', () {
      // 5 declared, 3 characters present. The code-unit re-read runs out of
      // data, and clamping it to EOF would make the boundary test pass
      // trivially — handing back a short value dressed as a correct one.
      final segments = _segments('<CALL:6>N0CALL <NAME:5>ééé');

      expect(segments.single.fields.last.anomaly, AdifFieldAnomaly.truncated);
    });

    test('a segment with no fields is still emitted', () {
      // The caller decides what an empty record means; swallowing it here
      // would hide a file that is systematically producing them.
      final segments = _segments('<EOR><CALL:4>W1AW<EOR>');

      expect(segments, hasLength(2));
      expect(segments[0].fields, isEmpty);
    });
  });
}
