// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The per-ref title phrases, asked of every ref's program in one crossing:
// each ref's phrase stands or falls on its own.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;

import '../support/halo_test_support.dart';

void main() {
  Future<HaLoHarness> harness() => makeHaLoServices(
    extensions: ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'ref:potaActivation:null:suggestOperationTitle': (Object? args) => {'at': ((args! as Map)['ref'] as Map)['ref']},
        'ref:sotaActivation:null:suggestOperationTitle': ExtensionHostException('SOTA is down'),
      }),
    ),
  );

  Operation withRefs(List<Map<String, dynamic>> refs) => Operation(uuid: 'op-title', data: {'refs': refs});

  test('a program that fails costs its own phrase, and says the sentence is incomplete', () async {
    // `complete` is what keeps a segment row from persisting a description
    // with a phrase missing; the other refs' phrases must still arrive.
    final HaLoHarness(:services) = await harness();

    final result = await services.operationTitles.suggestForRefs(
      withRefs([
        {'type': 'sotaActivation', 'ref': 'W2/GC-116'},
        {'type': 'potaActivation', 'ref': 'US-0001'},
      ]),
    );

    expect([for (final s in result!.suggestions) s.atText], ['US-0001']);
    expect(result.complete, false);
  });

  test('a malformed reference is not asked about, and costs no other phrase', () async {
    // Its type routes to no program, so nothing can ever answer for it — the
    // sentence is as complete as it will get, and the rest of it must arrive.
    final HaLoHarness(:services) = await harness();

    final result = await services.operationTitles.suggestForRefs(
      withRefs([
        {'type': 42, 'ref': 'US-0001'},
        {'type': 'potaActivation', 'ref': 'US-0002'},
      ]),
    );

    expect([for (final s in result!.suggestions) s.atText], ['US-0002']);
    expect(result.complete, true);
  });

  test('a type no program handles leaves the sentence incomplete', () async {
    // A program switched on later can still answer for it, and a description
    // persisted now would lack its phrase for good.
    final HaLoHarness(:services) = await harness();

    final result = await services.operationTitles.suggestForRefs(
      withRefs([
        {'type': 'wwffActivation', 'ref': 'KFF-0001'},
        {'type': 'potaActivation', 'ref': 'US-0003'},
      ]),
    );

    expect([for (final s in result!.suggestions) s.atText], ['US-0003']);
    expect(result.complete, false);
  });
}
