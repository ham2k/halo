// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The activation an ADIF file recorded, added to the operation it is imported
// into: decorated like a reference added by hand, in one bridge crossing for
// however many references the file carries.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/adif_import_flow.dart';

import '../support/halo_test_support.dart';

void main() {
  test('fifty references are decorated in ONE crossing, and land on the operation named', () async {
    // Awaited one at a time, each reference would wait out the one before it
    // — up to a ten-second budget apiece, while the operator watches the import.
    final host = FakeExtensionHost({
      'ref:potaActivation:null:decorateRef': (Object? args) => {...((args! as Map)['ref'] as Map), 'name': 'Park ${((args as Map)['ref'] as Map)['ref']}'},
    });
    final HaLoHarness(:services) = await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(host));
    final created = await services.operations.create(stationCall: 'N0DEV');

    await addActivationToOperation(services, created, [
      for (var i = 0; i < 50; i++) {'type': 'potaActivation', 'ref': 'US-$i'},
    ]);

    // Saving the refs also re-titles the operation, in a batch of its own.
    final decorating = [
      for (final batch in host.batches)
        if (batch.first.method == 'decorateRef') batch,
    ];
    expect(decorating, hasLength(1));
    expect(decorating.single, hasLength(50));
    final saved = (await services.operations.get(created.uuid))!;
    expect([for (final ref in saved.refs) ref['name']], [for (var i = 0; i < 50; i++) 'Park US-$i']);
  });

  test('a reference the operation already carries is neither asked about nor added twice', () async {
    final host = FakeExtensionHost({
      'ref:potaActivation:null:decorateRef': (Object? args) => {...((args! as Map)['ref'] as Map), 'name': 'Decorated'},
    });
    final HaLoHarness(:services) = await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(host));
    final created = await services.operations.create(stationCall: 'N0DEV');
    await services.operations.saveData(
      Operation(
        uuid: created.uuid,
        data: {
          ...created.data,
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-1', 'name': 'Named by hand'},
          ],
        },
      ),
    );
    final current = (await services.operations.get(created.uuid))!;

    await addActivationToOperation(services, current, [
      {'type': 'potaActivation', 'ref': 'US-1'},
      {'type': 'potaActivation', 'ref': 'US-2'},
    ]);

    final decorating = [
      for (final batch in host.batches)
        if (batch.first.method == 'decorateRef') batch,
    ];
    expect(decorating.single, hasLength(1), reason: 'only the new reference is decorated');
    final saved = (await services.operations.get(created.uuid))!;
    expect([for (final ref in saved.refs) (ref['ref'], ref['name'])], [('US-1', 'Named by hand'), ('US-2', 'Decorated')]);
  });
}
