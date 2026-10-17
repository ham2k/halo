// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The kernel's one copy of a log (extensions/sdk/src/logCopy.ts), through the
// real runtime: the host call it follows, the API level the host declares for
// each bundle, and the full rescore that folds from it. The traps are a list
// staler than the call, an older extension's write reaching anyone else's
// QSOs, and a rescore folding an empty log because nothing filled it in.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

/// A bundle whose `read` reports what `ctx.getQsos` handed it, after trying
/// to write to it — in strict mode, so a frozen QSO throws rather than
/// ignoring the write.
String _probe(String key) =>
    '''
(function () {
'use strict'
__polo.defineExtension({
  key: '$key',
  name: 'Log probe',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: '$key', hook: {
      read: async function (args, ctx) {
        var log = await ctx.getQsos(args.operationUuid)
        if (log === null) return null
        var notes = log.map(function (q) { return q.notes || null })
        var threw = false
        if (log.length > 0) {
          try { log[0].notes = 'written by $key' } catch (e) { threw = true }
        }
        var uuids = log.map(function (q) { return q.uuid })
        log.reverse()
        return { uuids: uuids, frozen: log.length > 0 && Object.isFrozen(log[log.length - 1]), threw: threw, notes: notes }
      },
    }})
  },
})
})()
''';

/// A scorer that reports whether the contacts it was handed are frozen.
String _scorer(String key) =>
    '''
(function () {
'use strict'
__polo.defineExtension({
  key: '$key',
  name: 'Scorer probe',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('scoring', { key: '$key', hook: {
      scoreQsos: async function (args) { return { frozen: Object.isFrozen(args.qsos[0]) } },
    }})
  },
})
})()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late HaLoHarness harness;
  late Operation operation;

  setUp(() async {
    extensions = ExtensionService();
    harness = await makeHaLoServices(extensions: extensions);
    extensions
      ..operations = harness.services.operations
      ..qsos = harness.services.qsos;
    await startWithShippedExtensions(extensions);
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-older', source: _probe('dev-older'), api: 8));
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-newer', source: _probe('dev-newer'), api: 9));
    operation = await harness.services.operations.create(stationCall: 'KI2D');
  });

  Future<Qso> log(String call, int startAt) => harness.services.qsos.add(operation.uuid, {
    'their': {'call': call},
    'band': '20m',
    'mode': 'CW',
    'startAtMillis': startAt,
  });

  Future<Map<String, Object?>> read(String key) async =>
      ((await extensions.host!.invokeHook('bench', key: key, method: 'read', args: {'operationUuid': operation.uuid})) as Map).cast<String, Object?>();

  test('an extension at API 9 shares frozen QSOs; an older one gets its own, and its writes reach nobody', () async {
    await log('W1AW', 1000);

    final older = await read('dev-older');
    expect(older['frozen'], isFalse);
    expect(older['threw'], isFalse, reason: 'an extension built before the promise may still write to what it is handed');

    final newer = await read('dev-newer');
    expect(newer['frozen'], isTrue);
    expect(newer['threw'], isTrue);
    expect(newer['notes'], [null], reason: "the older extension's write stayed in its own copy");
    expect((await read('dev-older'))['notes'], [null], reason: 'and its next read is a fresh copy too');
  });

  test('every read is as current as the log: a contact logged, edited or deleted is there the next time', () async {
    final first = await log('W1AW', 1000);
    expect((await read('dev-newer'))['uuids'], [first.uuid]);

    final second = await log('K1ABC', 500);
    await harness.services.qsos.update(Qso(uuid: first.uuid, operationUuid: operation.uuid, data: {...first.data, 'notes': 'edited'}));
    expect((await read('dev-newer'))['uuids'], [second.uuid, first.uuid], reason: 'oldest first, as getQsos always answered');
    expect((await read('dev-newer'))['notes'], [null, 'edited']);

    await harness.services.qsos.softDelete(second);
    expect((await read('dev-older'))['uuids'], [first.uuid]);
  });

  test("a tail's contacts are frozen at API 9 as a full pass's are, so a scorer cannot fail on one kind of pass alone", () async {
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-scorer-older', source: _scorer('dev-scorer-older'), api: 8));
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-scorer-newer', source: _scorer('dev-scorer-newer'), api: 9));
    Future<Object?> tail(String key) async =>
        ((await extensions.host!.invokeHook(
              'scoring',
              key: key,
              method: 'scoreQsos',
              args: {
                'operation': {'uuid': operation.uuid},
                'qsos': [
                  {'uuid': 'tail'},
                ],
              },
            ))
            as Map)['frozen'];
    expect(await tail('dev-scorer-newer'), isTrue);
    expect(await tail('dev-scorer-older'), isFalse);
  });

  test('an installed extension that declares no api runs as the oldest level, as it installed', () {
    // The install check reads a missing `api` as 0. Held to the app's own
    // level instead, it would be handed frozen QSOs it was never promised.
    ExtensionInfo info(Map<String, dynamic> extra) => ExtensionInfo.fromJson({'key': 'x', 'name': 'X', ...extra});
    expect(info({'core': false}).runtimeApi, 0);
    expect(info({'core': false, 'api': 9}).runtimeApi, 9);
    expect(info({'core': true}).runtimeApi, isNull, reason: 'a built-in is at the app own level');
  });

  test('a full rescore folds every contact from the copy, though the host sends only their uuids', () async {
    for (var i = 0; i < 5; i++) {
      await log('K${i}ABC', 1000 + i * 60000);
    }

    await harness.services.scoring.rescoreOperation((await harness.services.operations.get(operation.uuid))!, full: true);

    final scored = await harness.services.qsos.forOperation(operation.uuid);
    expect(scored, hasLength(5));
    for (final qso in scored) {
      expect(qso.scoreCache, contains('"core"'), reason: '${qso.theirCall} was folded by the core scorer');
    }
  });
}
