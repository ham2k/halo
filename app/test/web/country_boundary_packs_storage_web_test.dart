// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

@TestOn('browser')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/country_boundary_packs_storage_web.dart';

void main() {
  test('a browser reload sees the last complete pack and a removal', () async {
    final database = 'halo-country-boundary-packs-test-${Random().nextInt(1 << 30)}';
    IndexedDbCountryBoundaryPackStorage open() => IndexedDbCountryBoundaryPackStorage(databaseName: database);

    final first = open();
    expect(await first.read('US'), isNull);
    await first.replace('US', Uint8List.fromList([0, 17, 255]));
    final second = open();
    expect(await second.read('US'), [0, 17, 255]);
    await second.replace('US', Uint8List.fromList([128, 19]));
    expect(await open().read('US'), [128, 19]);
    await first.remove('US');
    expect(await open().read('US'), isNull);
  });
}
