// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The parsing that decides what reaches an extension's mapper. Every case
// here is one the published data files actually contain.

import 'dart:convert';

import 'package:halo_cli/src/data_files.dart';
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

    test('a doubled quote inside a quoted field is one literal quote', () {
      expect(parseCsvRow('US-1,"The ""Big"" Park",US-CA', ','), ['US-1', 'The "Big" Park', 'US-CA']);
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
      expect(resolveRootPath({'data': {'rows': [1, 2]}}, 'data.rows'), [1, 2]);
    });

    test('a numeric segment indexes a list', () {
      // ECA and ELA publish `[meta, meta, {data: […]}]` — rootPath `2.data`.
      final payload = jsonDecode('[{"m":1},{"m":2},{"data":[{"key":"X"}]}]');
      expect(resolveRootPath(payload, '2.data'), [
        {'key': 'X'}
      ]);
    });

    test('a miss is null, not a crash', () {
      expect(resolveRootPath({'data': 1}, 'data.rows'), isNull);
      expect(resolveRootPath([1, 2], '9'), isNull);
      expect(resolveRootPath({'a': 1}, 'b'), isNull);
    });

    test('an empty path returns the whole payload', () {
      expect(resolveRootPath({'a': 1}, null), {'a': 1});
      expect(resolveRootPath({'a': 1}, ''), {'a': 1});
    });
  });

  group('decoding', () {
    test("the definition's encoding overrides the server's header", () {
      // The override exists precisely because some servers declare the wrong
      // charset; letting the header win would defeat it.
      expect(resolveDataFileEncoding('latin1', 'text/csv; charset=utf-8'), 'latin1');
      expect(resolveDataFileEncoding(null, 'text/csv; charset=iso-8859-1'), 'iso-8859-1');
      expect(resolveDataFileEncoding(null, null), isNull);
      expect(resolveDataFileEncoding(null, 'nonsense'), isNull);
    });

    test('a charset-less body decodes as UTF-8, not latin1', () {
      // package:http's own `.body` defaults to latin1 here, which garbles
      // every accented park name in the file.
      final bytes = utf8.encode('Parque Nacional Doñana');
      expect(decodeDataFileBody(bytes, encoding: resolveDataFileEncoding(null, 'text/csv')),
          'Parque Nacional Doñana');
    });

    test('a malformed byte is replaced, never thrown', () {
      // One bad byte must not fail a 181k-row file.
      expect(decodeDataFileBody([0x41, 0xC3, 0x28]), contains('A'));
    });
  });
}
