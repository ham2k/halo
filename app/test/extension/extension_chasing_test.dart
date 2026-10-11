// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The chasing hook calls hold one program's failure to that program's own
// answer. A claim the host keeps from a broken answer, or a whole batch lost
// to one bad entry, would land on a checklist that syncs to every device.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_chasing.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_extension_host.dart';

Map<String, dynamic> _claim({String ref = '230', String? band, String level = 'worked'}) => {
  'holder': 'KI2D@291',
  'ref': ref,
  'band': band,
  'mode': null,
  'level': level,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a program with a malformed description is left out, and the others are not', () async {
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'chasing:*:program': [
          {
            'key': 'dxcc',
            'ok': true,
            'value': {'label': 'DXCC', 'version': 1, 'editions': 'lifetime'},
          },
          {
            'key': 'broken',
            'ok': true,
            'value': {'label': 'Broken', 'version': '1', 'editions': 'lifetime'},
          },
          {'key': 'threw', 'ok': false, 'error': 'boom'},
        ],
      }),
    );
    final backend = FakeErrorReportingBackend();
    late Map<String, ChasingProgram> programs;
    await withErrorHooks(() async => programs = await service.getChasingPrograms(), backend: backend);

    expect(programs.keys, ['dxcc']);
    expect(programs['dxcc']!.editions, ChasingEditions.lifetime);
    expect(backend.exceptions.map((e) => (e.error as ChasingHookFailure).programKey), [
      'broken',
    ], reason: 'a version that is not a number is a defect worth knowing about');
  });

  // A contact answered with a malformed entry is unknown, not "claims the
  // rest": kept with its good entries, it would read as no longer claiming
  // the slot the bad one was for, and take it off the checklist. The other
  // contacts in the batch say nothing wrong and keep their answers.
  test('a contact with a malformed claim is left out of the answer, and the rest of the batch stands', () async {
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'chasing:dxcc:claimsForQsos': {
          'q1': [
            _claim(),
            {'holder': 'KI2D@291', 'ref': '230', 'level': 'gold'},
          ],
          'q2': <Object>[],
          'q3': [_claim(), _claim(band: '20m')],
        },
      }),
    );
    final backend = FakeErrorReportingBackend();
    late Map<String, List<QsoClaim>>? claims;
    await withErrorHooks(
      () async => claims = await service.claimsForQsos('dxcc', [
        {'uuid': 'q1'},
        {'uuid': 'q2'},
        {'uuid': 'q3'},
      ]),
      backend: backend,
    );

    expect(claims!.containsKey('q1'), isFalse);
    expect(claims!['q2'], isEmpty, reason: 'a contact that claims nothing is an answer, not a failure');
    expect(claims!['q3'], [
      const QsoClaim(holder: 'KI2D@291', ref: '230', band: null, mode: null, level: ClaimLevel.worked),
      const QsoClaim(holder: 'KI2D@291', ref: '230', band: '20m', mode: null, level: ClaimLevel.worked),
    ]);
    expect(backend.exceptions.single.error, isA<ChasingHookFailure>());
  });

  // Null and empty mean different things to whoever keeps the checklist: an
  // empty answer may withdraw claims, a failure must withdraw nothing.
  test('a program that fails answers null, not an empty set of claims', () async {
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'chasing:broken:claimsForQsos': ExtensionHostException('boom'),
        'chasing:dxcc:claimsForQsos': {
          'q1': [_claim()],
        },
      }),
    );
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      expect(await service.claimsForQsos('broken', const []), isNull);
      expect((await service.claimsForQsos('dxcc', const []))!['q1'], hasLength(1));
    }, backend: backend);
    expect((backend.exceptions.single.error as ChasingHookFailure).programKey, 'broken');
  });
}
