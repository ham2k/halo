// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The parsing that decides what reaches an extension's mapper — for BOTH
// hosts. Every case here is one the published data files actually contain, and
// this is the only suite covering them: the app and the CLI each used to carry
// their own copy of these functions and their own half of these cases.

import 'dart:convert';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseCsvRow', () {
    test('a quoted field keeps its delimiters', () {
      // Park names carry commas ("Smith, John State Park"). Splitting on the
      // delimiter alone shifts every later column by one, so the mapper reads
      // the latitude out of the state column and the row lands somewhere in
      // the ocean.
      expect(parseCsvRow('US-1234,"Smith, John State Park",US-NY', ','),
          ['US-1234', 'Smith, John State Park', 'US-NY']);
    });

    test('an unquoted row splits on every delimiter', () {
      expect(parseCsvRow('val1,val2,val3', ','), ['val1', 'val2', 'val3']);
    });

    test('a doubled quote inside a quoted field is one literal quote', () {
      expect(parseCsvRow('US-1,"The ""Big"" Park",US-CA', ','), ['US-1', 'The "Big" Park', 'US-CA']);
      expect(parseCsvRow('val1,"val2 ""nested"" quotes",val3', ','), ['val1', 'val2 "nested" quotes', 'val3']);
    });

    test('an empty trailing field is still a field', () {
      // Dropping it shortens the row, and the kernel zips rows against
      // headers positionally — a short row silently renames every column
      // after the gap.
      expect(parseCsvRow('a,b,', ','), ['a', 'b', '']);
    });

    test('honors a non-comma delimiter', () {
      expect(parseCsvRow('a;b;c', ';'), ['a', 'b', 'c']);
    });
  });

  group('resolveRootPath', () {
    test('walks object keys', () {
      expect(
          resolveRootPath({
            'data': {'rows': 1}
          }, 'data.rows'),
          1);
      expect(
          resolveRootPath({
            'metadata': {'version': '1.0'},
            'results': [
              {'id': 1},
              {'id': 2}
            ],
          }, 'results'),
          [
            {'id': 1},
            {'id': 2}
          ]);
    });

    test('a numeric segment indexes a list', () {
      // ECA and ELA publish `[meta, meta, {data: […]}]` — rootPath `2.data`.
      // Without list indexing their rows are simply unreachable.
      final payload = jsonDecode('[{"m":1},{"m":2},{"data":[{"WCA":"G-00001"}]}]');
      expect(resolveRootPath(payload, '2.data'), [
        {'WCA': 'G-00001'}
      ]);
    });

    test('a miss is null, not a crash', () {
      // A published list that changes shape should degrade to "no rows", which
      // the caller already reports, rather than take down the refresh.
      expect(resolveRootPath({'data': 1}, 'data.rows'), isNull);
      expect(resolveRootPath([1, 2], '9'), isNull);
      expect(resolveRootPath({'a': 1}, 'b'), isNull);
      expect(resolveRootPath({'a': 1}, 'nonexistent.path'), isNull);
      // A non-numeric or negative segment against a list is a miss too.
      expect(
          resolveRootPath([
            {'data': 1}
          ], 'data'),
          isNull);
      expect(
          resolveRootPath([
            {'data': 1}
          ], '-1.data'),
          isNull);
    });

    test('an empty path returns the whole payload', () {
      expect(resolveRootPath({'a': 1}, null), {'a': 1});
      expect(resolveRootPath({'a': 1}, ''), {'a': 1});
    });
  });

  group('resolveDataFileEncoding', () {
    test("the definition's encoding overrides the server Content-Type charset", () {
      // The override exists precisely because some servers declare the wrong
      // charset; letting the header win would defeat it.
      expect(resolveDataFileEncoding('latin1', 'text/csv; charset=utf-8'), 'latin1');
    });

    test('honors the server charset when the definition declares none', () {
      expect(resolveDataFileEncoding(null, 'text/csv; charset=iso-8859-1'), 'iso-8859-1');
    });

    test('an empty definition encoding is treated as absent (server charset wins)', () {
      expect(resolveDataFileEncoding('', 'text/plain; charset=latin1'), 'latin1');
    });

    test('null when the server sends no charset — decode then defaults to UTF-8', () {
      expect(resolveDataFileEncoding(null, 'application/json'), isNull);
    });

    test('null when there is no Content-Type header at all', () {
      expect(resolveDataFileEncoding(null, null), isNull);
    });

    test('an unparseable header is null, not a throw', () {
      expect(resolveDataFileEncoding(null, 'nonsense'), isNull);
    });
  });

  group('decodeDataFileBody', () {
    // "Jærstrendene" — POTA NO-2526. The 'æ' is U+00E6, two bytes in UTF-8.
    final utf8Bytes = utf8.encode('Jærstrendene');
    final latin1Bytes = latin1.encode('Jærstrendene'); // single 0xE6 byte

    test('defaults to UTF-8 when no encoding is given', () {
      expect(decodeDataFileBody(utf8Bytes), 'Jærstrendene');
    });

    test('a charset-less body decodes as UTF-8, not latin1', () {
      // package:http's own `.body` defaults to latin1 here, which garbles
      // every accented park name in the file: latin1-decoding these UTF-8
      // bytes yields "JÃ¦rstrendene".
      expect(latin1.decode(utf8Bytes), 'JÃ¦rstrendene');
      expect(decodeDataFileBody(utf8Bytes, encoding: resolveDataFileEncoding(null, 'text/csv')), 'Jærstrendene');
      expect(decodeDataFileBody(utf8.encode('Parque Nacional Doñana'), encoding: resolveDataFileEncoding(null, 'text/csv')),
          'Parque Nacional Doñana');
    });

    test('a declared latin1/iso-8859-1 encoding decodes a genuinely latin1 file', () {
      expect(decodeDataFileBody(latin1Bytes, encoding: 'latin1'), 'Jærstrendene');
      expect(decodeDataFileBody(latin1Bytes, encoding: 'ISO-8859-1'), 'Jærstrendene');
    });

    test('an unknown encoding falls back to UTF-8', () {
      expect(decodeDataFileBody(utf8Bytes, encoding: 'windows-1252'), 'Jærstrendene');
    });

    test('malformed bytes are replaced, never thrown', () {
      // One bad byte must not fail a 181k-row file.
      expect(() => decodeDataFileBody([0xFF, 0xFE, 0x41]), returnsNormally);
      expect(decodeDataFileBody([0x41, 0xFF, 0x42]), contains('A'));
      expect(decodeDataFileBody([0x41, 0xC3, 0x28]), contains('A'));
    });
  });

  group('redactUrlForLog', () {
    test('a logged fetch URL keeps no query string', () {
      // Some award programs carry their API key as a query parameter — TOTA's
      // list is `tower.php?key=<secret>` — and `debugPrint` is not stripped
      // from release builds, so logging the URL whole would put a real secret
      // in the device log on every refresh.
      expect(
        redactUrlForLog('https://www.rozhledny.eu/apidata/tower.php?key=s3cret'),
        'https://www.rozhledny.eu/apidata/tower.php?…',
      );
    });

    test('enough is kept to say WHICH file was fetched', () {
      expect(redactUrlForLog('https://pota.app/all_parks_ext.csv'), 'https://pota.app/all_parks_ext.csv');
    });

    test('a fragment is cut too, and leaves no stray marker', () {
      // Cutting the string rather than rebuilding through
      // `Uri.replace(query: '')` is what keeps this from coming out as
      // `https://example.com/a??…`.
      expect(redactUrlForLog('https://example.com/a?k=1#tok'), 'https://example.com/a?…');
      expect(redactUrlForLog('https://example.com/a#tok'), 'https://example.com/a?…');
    });

    test('something that is not a URL says so rather than being logged raw', () {
      expect(redactUrlForLog('::: not a url'), '(unparseable url)');
      // Uri.tryParse accepts a bare path, so the scheme check is what catches
      // it — without that, a secret-bearing string that isn't a URL at all
      // would be logged whole.
      expect(redactUrlForLog('not-a-url'), '(unparseable url)');
    });
  });
}
