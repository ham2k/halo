// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The background lookup queue exists so logging never waits on the network:
// QSOs are saved bare, then enriched one lookup at a time. These tests
// verify the contract that matters — results are merged onto the *current*
// stored record (never clobbering later edits, resurrecting deletions, or
// attaching data for a corrected callsign), a degraded/offline result never
// wipes richer stored data, unchanged results don't dirty sync, failures
// don't stall the rest of the queue, and the status bar reflects batch
// progress. The lookup function is injected, so no JS runtime here; the
// real pipeline behind it is covered by seed_command_test and the
// extension-host integration tests.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show CallLookup;
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late StatusBarService statusBar;
  late Operation operation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    statusBar = StatusBarService(await SharedPreferences.getInstance());
    operation = await operations.create(stationCall: 'KI2D');
  });

  tearDown(() async {
    await db.close();
  });

  LookupQueueService service(CallLookup lookup, {bool Function()? lookupReady, Duration? waitBudget}) =>
      LookupQueueService(
        lookup: lookup,
        qsos: qsos,
        operations: operations,
        statusBar: statusBar,
        lookupReady: lookupReady,
        runtimeWaitBudget: waitBudget ?? const Duration(seconds: 20),
      );

  test('processes queued QSOs one at a time and merges guess/lookups onto the stored record', () async {
    final a = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final b = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});

    final order = <String>[];
    var concurrent = 0, maxConcurrent = 0;
    final queue = service((call, {required qso, required operation, bool online = true}) async {
      concurrent += 1;
      maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      order.add(call);
      concurrent -= 1;
      return {
        'guess': {'name': 'Name for $call'},
        'lookups': [
          {'source': 'test', 'name': 'Name for $call'}
        ],
      };
    });

    queue.enqueue(a);
    queue.enqueue(b);
    await queue.idle;

    // Strictly sequential — each lookup is its own small bridge call, so a
    // long queue never monopolizes the extension runtime.
    expect(order, ['W1AW', 'K1ABC']);
    expect(maxConcurrent, 1);

    final storedA = (await qsos.get(a.uuid))!;
    final storedB = (await qsos.get(b.uuid))!;
    expect(storedA.theirName, 'Name for W1AW');
    expect(storedB.theirName, 'Name for K1ABC');
    // Nested under their.guess/their.lookups (AnnotatedCallInfo
    // convention), never flattened onto `their` itself.
    expect((storedA.data['their'] as Map)['name'], isNull);
    expect(((storedA.data['their'] as Map)['lookups'] as List), hasLength(1));
  });

  test('merges onto the freshest record: an edit made while the lookup was in flight survives', () async {
    final qso = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}, 'freq': 7100.0});

    // The lookup fn itself edits the QSO before returning — simulating the
    // operator changing the record while the network round-trip is running.
    final editingQueue = service((call, {required qso, required operation, bool online = true}) async {
      final current = (await qsos.get(qso['uuid'] as String))!;
      await qsos.update(Qso(
        uuid: current.uuid,
        operationUuid: current.operationUuid,
        data: {...current.data, 'notes': 'edited mid-lookup'},
      ));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    editingQueue.enqueue(qso);
    await editingQueue.idle;

    final stored = (await qsos.get(qso.uuid))!;
    expect(stored.notes, 'edited mid-lookup');
    expect(stored.theirName, 'ARRL HQ');
  });

  test('a result for a callsign corrected mid-flight is discarded, not stamped onto the new call', () async {
    final qso = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});

    // The operator fixes a busted call while the (slow) lookup runs: the
    // returned data belongs to the OLD call and must not decorate the new
    // one — displays fall back to their.guess, so a stale merge would show
    // the wrong station's name with no visible hint.
    final queue = service((call, {required qso, required operation, bool online = true}) async {
      final current = (await qsos.get(qso['uuid'] as String))!;
      await qsos.update(Qso(
        uuid: current.uuid,
        operationUuid: current.operationUuid,
        data: {
          ...current.data,
          'their': {...(current.data['their'] as Map).cast<String, dynamic>(), 'call': 'K9ABC'},
        },
      ));
      return {'guess': {'name': 'W1AW Station'}};
    });

    queue.enqueue(qso);
    await queue.idle;

    final stored = (await qsos.get(qso.uuid))!;
    expect(stored.theirCall, 'K9ABC');
    expect(stored.theirName, isNull);
  });

  test('a degraded (offline) result never wipes richer stored lookup data, and an identical result does not dirty the record', () async {
    final enriched = {
      'guess': {'name': 'ARRL HQ', 'grid': 'FN31pr'},
      'lookups': [
        {'source': LookupQueueService.annotationSource, 'entityPrefix': 'K'},
        {'source': 'qrz.com', 'name': 'ARRL HQ', 'grid': 'FN31pr'},
      ],
    };
    final degraded = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW', ...enriched},
    });
    final unchanged = await qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC', ...enriched},
    });
    final degradedStampBefore = (await qsos.get(degraded.uuid))!.updatedAtMillis;
    final unchangedStampBefore = (await qsos.get(unchanged.uuid))!.updatedAtMillis;

    final queue = service((call, {required qso, required operation, bool online = true}) async {
      if (call == 'W1AW') {
        // Offline/erroring sources: the pipeline still returns the
        // annotation-only entry — QRZ's stored data must survive.
        return {
          'guess': {'entityPrefix': 'K'},
          'lookups': [
            {'source': LookupQueueService.annotationSource, 'entityPrefix': 'K'},
          ],
        };
      }
      // Byte-identical to what's stored: writing would restamp the row,
      // re-sync it, and could even beat another device's real edit in the
      // last-write-wins merge — so it must be skipped.
      return {
        'guess': Map<String, dynamic>.from(enriched['guess'] as Map),
        'lookups': [
          for (final l in enriched['lookups'] as List) Map<String, dynamic>.from(l as Map),
        ],
      };
    });

    // force (the "Lookup all QSOs" path) so the already-enriched records
    // are processed at all.
    queue.enqueueAll([degraded, unchanged]);
    await queue.idle;

    final storedDegraded = (await qsos.get(degraded.uuid))!;
    expect(storedDegraded.theirName, 'ARRL HQ');
    expect(storedDegraded.updatedAtMillis, degradedStampBefore);
    final storedUnchanged = (await qsos.get(unchanged.uuid))!;
    expect(storedUnchanged.theirName, 'ARRL HQ');
    expect(storedUnchanged.updatedAtMillis, unchangedStampBefore);
  });

  test('enqueue skips QSOs that already have online lookup data; enqueueAll (force) re-runs them', () async {
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'ARRL HQ'},
        'lookups': [
          {'source': 'qrz.com', 'name': 'ARRL HQ'},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true}) async {
      calls += 1;
      return {
        'guess': {'name': 'Refreshed'},
        'lookups': [
          {'source': 'qrz.com', 'name': 'Refreshed'},
        ],
      };
    });

    // Ordinary enqueue (the after-save path): already enriched, nothing to do.
    queue.enqueue(qso);
    await queue.idle;
    expect(calls, 0);

    // Explicit refresh: processed despite the stored data.
    queue.enqueueAll([qso]);
    await queue.idle;
    expect(calls, 1);
    expect((await qsos.get(qso.uuid))!.theirName, 'Refreshed');
  });

  test('a deleted QSO is left alone, and a failed or empty lookup does not stall the queue', () async {
    final deleted = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final failing = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});
    final empty = await qsos.add(operation.uuid, {'their': {'call': 'N2XYZ'}});
    final ok = await qsos.add(operation.uuid, {'their': {'call': 'W2AAA'}});

    final queue = service((call, {required qso, required operation, bool online = true}) async {
      if (call == 'W1AW') fail('deleted QSOs must not be looked up');
      if (call == 'K1ABC') throw StateError('network down');
      if (call == 'N2XYZ') return null;
      return {'guess': {'name': 'Fine'}};
    });

    await qsos.softDelete(deleted);
    queue.enqueue(await qsos.get(deleted.uuid) ?? deleted);
    queue.enqueue(failing);
    queue.enqueue(empty);
    queue.enqueue(ok);
    await queue.idle;

    // The failure and the empty result left their records untouched, and
    // the queue still reached the last entry.
    expect((await qsos.get(empty.uuid))!.theirName, isNull);
    expect((await qsos.get(ok.uuid))!.theirName, 'Fine');
  });

  test('dedupes a QSO still waiting in the queue, but a re-request for one already in flight runs again', () async {
    final a = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final b = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});
    final event = await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 1000);

    final calls = <String>[];
    final queue = service((call, {required qso, required operation, bool online = true}) async {
      calls.add(call);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    queue.enqueue(a); // starts processing immediately (in flight)
    queue.enqueue(b); // waiting behind a
    queue.enqueue(b); // still waiting — dropped as a duplicate
    queue.enqueue(a); // a is in flight, not waiting — an explicit
    //                   re-request must run again (its first attempt might
    //                   be failing right now), not be silently discarded
    queue.enqueue(event); // not a real contact — dropped
    await queue.idle;

    expect(calls, ['W1AW', 'K1ABC', 'W1AW']);
  });

  test('holds processing while the extension runtime is not ready instead of burning the queue on null lookups', () async {
    final qso = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});

    var ready = false;
    var readyWhenCalled = false;
    Future<void>.delayed(const Duration(milliseconds: 100)).then((_) => ready = true);

    final queue = service(
      (call, {required qso, required operation, bool online = true}) async {
        readyWhenCalled = ready;
        return {'guess': {'name': 'ARRL HQ'}};
      },
      lookupReady: () => ready,
      waitBudget: const Duration(seconds: 5),
    );

    queue.enqueue(qso);
    await queue.idle;

    // A batch queued at app launch (runtime still booting) must wait for
    // the runtime rather than draining instantly with "N of N" done and
    // zero lookups performed.
    expect(readyWhenCalled, isTrue);
    expect((await qsos.get(qso.uuid))!.theirName, 'ARRL HQ');
  });

  test('reports batch progress in the status bar and completes it when the queue drains', () async {
    final a = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final b = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});

    final queue = service((call, {required qso, required operation, bool online = true}) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    queue.enqueueAll([a, b]);
    await queue.idle;

    final item = statusBar.items.firstWhere((i) => i.key == LookupQueueService.statusKey);
    expect(item.text, '2 of 2');
    expect(item.progressValue, 1.0);
  });
}
