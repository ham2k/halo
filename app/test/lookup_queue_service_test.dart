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
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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

  test('a wrong-typed lookup result enriches what it can instead of throwing out of the queue', () async {
    // The trap: `guess` and `lookups` come back over the extension bridge,
    // which enforces no types at all, and this service reaches INTO both.
    // A cast there does not degrade one field — it throws out of the queue
    // run, so the QSO stays bare AND every call queued behind it is stranded.
    // Same class of bug as the model getters; see qson_values.dart.
    final bad = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final after = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      if (call == 'W1AW') {
        return {
          'guess': {'name': true, 'grid': 'FN31pr'},
          // Not a list — the shape `lookups` is dereferenced as.
          'lookups': 'not-a-list',
        };
      }
      return {'guess': {'name': 'Name for $call'}};
    });

    queue.enqueue(bad);
    queue.enqueue(after);
    await queue.idle;

    final storedBad = (await qsos.get(bad.uuid))!;
    expect(storedBad.theirName, isNull, reason: 'an unusable name is absent, never the string "true"');
    expect(storedBad.theirGrid, 'FN31pr', reason: 'the usable half of the same guess still lands');

    // Not merely "it did not throw": an unusable `lookups` must not be
    // STORED either. Persisting it would hand the same bad shape to the
    // call-info panel, which dereferences their.lookups as a list during
    // build — moving the crash rather than fixing it.
    expect(asQsonList((storedBad.data['their'] as Map)['lookups']), anyOf(isNull, isEmpty));

    // The point of the test: the queue kept going.
    expect((await qsos.get(after.uuid))!.theirName, 'Name for K1ABC');
  });

  test('merges onto the freshest record: an edit made while the lookup was in flight survives', () async {
    final qso = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}, 'freq': 7100.0});

    // The lookup fn itself edits the QSO before returning — simulating the
    // operator changing the record while the network round-trip is running.
    final editingQueue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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

  test('a crossed result — a guess for a different call than requested — is dropped, never written', () async {
    // The field report this guards: an earlier QSO showing a later QSO's
    // name. The merged guess is always seeded with the callsign it was
    // looked up for (annotate.ts sets guess.call), so a guess.call that
    // disagrees with the QSO is a result that got mixed up in flight and must
    // never decorate this record — displays fall back to their.guess, so a
    // crossed merge would silently show the wrong station.
    final qso = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      // A well-formed result, but for a different station than asked for.
      return {
        'guess': {'call': 'K1ABC', 'name': 'Wrong Station'},
        'lookups': [
          {'source': 'test', 'call': 'K1ABC', 'name': 'Wrong Station'}
        ],
      };
    });

    queue.enqueue(qso);
    await queue.idle;

    final stored = (await qsos.get(qso.uuid))!;
    expect(stored.theirName, isNull, reason: 'the crossed name must not be written');
    expect((stored.data['their'] as Map)['guess'], isNull, reason: 'no guess persisted at all');
  });

  test('a degraded (offline) result never wipes richer stored lookup data, and an identical result does not dirty the record', () async {
    final enriched = {
      'guess': {'name': 'ARRL HQ', 'grid': 'FN31pr'},
      'lookups': [
        {'source': 'callsign-annotation', 'entityPrefix': 'K'},
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

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      if (call == 'W1AW') {
        // Offline/erroring sources: the pipeline still returns the
        // annotation-only entry — QRZ's stored data must survive.
        return {
          'guess': {'entityPrefix': 'K'},
          'lookups': [
            {'source': 'callsign-annotation', 'entityPrefix': 'K'},
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

  test('an offline lookup entry never counts as "already looked up online" — checked generically, by an `online` flag, never by source name', () async {
    // Any lookup source can answer offline (the log itself, a local
    // reference-data cache, notes files…) — this queue must not need to
    // know any of them by name to tell an offline answer from a real one.
    // `call-history` (extensions/lookups/call-history) is one concrete
    // example: it answers on essentially every repeat contact, so treating
    // its presence as proof of real enrichment would mean a worked-before
    // QSO never reaches QRZ/Ham2K Lookup at all — but the mechanism this
    // pins is general, not specific to it.
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'From Last Time'},
        'lookups': [
          // No `online: true` — an entirely made-up source name, to prove
          // nothing here is special-cased by which source answered.
          {'source': 'Some Future Offline Source', 'name': 'From Last Time'},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {
        'guess': {'name': 'From QRZ'},
        'lookups': [
          {'source': 'Some Future Offline Source', 'name': 'From Last Time'},
          {'source': 'qrz.com', 'name': 'From QRZ', 'online': true},
        ],
      };
    });

    queue.enqueue(qso);
    await queue.idle;
    expect(calls, 1);
    expect((await qsos.get(qso.uuid))!.theirName, 'From QRZ');
  });

  test('an `online: true` entry DOES count as "already looked up online", whatever it is named', () async {
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'From Network'},
        'lookups': [
          {'source': 'Some Future Network Source', 'name': 'From Network', 'online': true},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {'guess': {'name': 'Refetched'}};
    });

    queue.enqueue(qso);
    await queue.idle;
    expect(calls, 0);
  });

  test('a legacy QSO from before the `online` flag existed is not silently re-queued', () async {
    // A QSO enriched before this flag shipped has no `online` key on ANY of
    // its stored lookups — without the closed backward-compat fallback,
    // every already-enriched QSO in an existing log would look unenriched
    // the moment it was next opened (logging_controls.dart's initState
    // enqueues on edit-open, not just on an explicit refresh), and this
    // queue would silently re-hit QRZ for someone's entire log.
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'ARRL HQ'},
        'lookups': [
          {'source': 'callsign-annotation', 'entityPrefix': 'K'},
          {'source': 'qrz.com', 'name': 'ARRL HQ'}, // no `online` key — pre-flag shape
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {'guess': {'name': 'Refetched'}};
    });

    queue.enqueue(qso);
    await queue.idle;
    expect(calls, 0);
  });

  test('a legacy QSO whose only real source is NOT in the closed backward-compat set still gets a fresh look', () async {
    // POTA/SOTA never proved online-ness even before this flag existed
    // (their local-cache-hit answers were always ambiguous) — a QSO whose
    // only pre-flag lookup came from one of those is correctly treated as
    // not-yet-proven-online, same as it would be going forward.
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'grid': 'FN31pr'},
        'lookups': [
          {'source': 'pota', 'grid': 'FN31pr'},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {'guess': {'name': 'From QRZ'}};
    });

    queue.enqueue(qso);
    await queue.idle;
    expect(calls, 1);
  });

  test('enqueue skips QSOs that already have online lookup data; enqueueAll (force) re-runs them', () async {
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'ARRL HQ'},
        'lookups': [
          {'source': 'qrz.com', 'name': 'ARRL HQ', 'online': true},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {
        'guess': {'name': 'Refreshed'},
        'lookups': [
          {'source': 'qrz.com', 'name': 'Refreshed', 'online': true},
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

  test('enqueueAll(force: false) — the SEED path — still skips already-enriched QSOs', () async {
    final qso = await qsos.add(operation.uuid, {
      'their': {
        'call': 'W1AW',
        'guess': {'name': 'ARRL HQ'},
        'lookups': [
          {'source': 'qrz.com', 'name': 'ARRL HQ', 'online': true},
        ],
      },
    });

    var calls = 0;
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      calls += 1;
      return {'guess': {'name': 'Refreshed'}};
    });

    // Unlike the explicit "Lookup all QSOs" refresh (which forces), a SEED
    // batch has no reason to re-fetch a QSO that already carries real
    // lookup data — force: false keeps that skip in place while still
    // reporting batch progress.
    queue.enqueueAll([qso], force: false);
    await queue.idle;
    expect(calls, 0, reason: 'force: false must still honor the already-enriched skip');
  });

  test('a deleted QSO is left alone, and a failed or empty lookup does not stall the queue', () async {
    final deleted = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final failing = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});
    final empty = await qsos.add(operation.uuid, {'their': {'call': 'N2XYZ'}});
    final ok = await qsos.add(operation.uuid, {'their': {'call': 'W2AAA'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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
    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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
      (call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
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

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    queue.enqueueAll([a, b]);
    await queue.idle;

    final item = statusBar.items.firstWhere((i) => i.key == LookupQueueService.statusKey);
    expect(item.text, '2 of 2');
    expect(item.progressValue, 1.0);
  });

  test('plain enqueue() never touches the status bar, even with several queued together', () async {
    final a = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final b = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});
    final c = await qsos.add(operation.uuid, {'their': {'call': 'N0CALL'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    // Ordinary background enrichment — a callsign typed into the logging
    // field, a QSO just saved — must never surface the "Callsign lookups"
    // bar, however many happen to land close together and look, from the
    // queue's perspective, like a batch.
    queue.enqueue(a);
    queue.enqueue(b);
    queue.enqueue(c);
    await queue.idle;

    expect(
      statusBar.items.where((i) => i.key == LookupQueueService.statusKey),
      isEmpty,
      reason: 'regular lookups are silent — only "Lookup all QSOs" and SEED batches (via enqueueAll) show progress',
    );
  });

  test('enqueueAll reports progress for the whole batch — the SEED path', () async {
    final a = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final b = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    // Mirrors how a SEED batch reaches the queue (logging_controls.dart's
    // addQso command handling collects the whole batch and hands it to
    // enqueueAllLookups, wired to enqueueAll) — a bulk insert, not a single
    // typed callsign, so it's opted into progress.
    queue.enqueueAll([a, b]);
    await queue.idle;

    final item = statusBar.items.firstWhere((i) => i.key == LookupQueueService.statusKey);
    expect(item.text, '2 of 2');
    expect(item.progressValue, 1.0);
  });

  test('a silent lookup in flight alongside a progress-worthy one does not inflate its count', () async {
    final silent = await qsos.add(operation.uuid, {'their': {'call': 'W1AW'}});
    final tracked = await qsos.add(operation.uuid, {'their': {'call': 'K1ABC'}});

    final queue = service((call, {required qso, required operation, bool online = true, bool recentContext = false}) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return {'guess': {'name': 'ARRL HQ'}};
    });

    queue.enqueue(silent);
    queue.enqueueAll([tracked]);
    await queue.idle;

    final item = statusBar.items.firstWhere((i) => i.key == LookupQueueService.statusKey);
    expect(item.text, '1 of 1', reason: 'the silent lookup must not count toward the displayed total');
  });
}
