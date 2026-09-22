// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `countAdifRecords` is the number an import cap is checked against, so it
// has to be the number the conversion would actually produce. An undercount
// lets an oversized file through; an overcount refuses one that fits.

import 'dart:convert';
import 'dart:io';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  test('agrees with the conversion across every logger in the corpus', () {
    for (final file in Directory('test/adif/samples').listSync().whereType<File>()) {
      final bytes = file.readAsBytesSync();
      final log = parseAdifLogBytes(bytes);
      expect(countAdifRecords(bytes), log.qsos.length + log.errors.length, reason: file.path);
    }
  });

  test('an <EOR> inside a field value is not a record boundary', () {
    // A raw scan for the marker would count three here; only the declared
    // length says the middle one is comment text.
    final bytes = utf8.encode('<EOH>\n<CALL:5>N0DEV<COMMENT:5><EOR><EOR>\n<CALL:4>W1AW<EOR>\n');
    expect(countAdifRecords(bytes), 2);
  });

  test('neither the header nor an empty record counts', () {
    final bytes = utf8.encode('<PROGRAMID:4>HaLo<EOH>\n<EOR>\n<CALL:5>N0DEV<EOR>\n');
    expect(countAdifRecords(bytes), 1);
  });
}
