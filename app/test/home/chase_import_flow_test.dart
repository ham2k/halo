// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the chasing import picker asks for, and the text a program is handed.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/chase_import_flow.dart';

void main() {
  const importer = ChasingImporter(key: 'hunted-parks', label: 'Hunted Parks', extensions: ['csv']);

  group('the picker filter', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    // The import button is the only way to import on a phone: there is no
    // file to drop. A group with no UTIs makes the iOS picker throw.
    test('iOS gets a UTI it accepts', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(chaseImportTypeGroups(importer).single.uniformTypeIdentifiers, isNotEmpty);
    });

    test('desktop filters to the extensions the importer takes', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(chaseImportTypeGroups(importer).single.extensions, ['csv']);
    });
  });

  // A spreadsheet writes a byte order mark ahead of the header row: left in,
  // the first column's name no longer matches, and every record is skipped.
  test("the text drops a spreadsheet's byte order mark, and survives bytes that are not UTF-8", () {
    expect(chaseImportText([0xEF, 0xBB, 0xBF, ...utf8.encode('"Reference"')]), '"Reference"');
    expect(chaseImportText([...utf8.encode('Caf'), 0xE9]), startsWith('Caf'));
  });
}
