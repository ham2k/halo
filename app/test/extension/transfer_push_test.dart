// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A push through a real `transfer` hook (docs/design/transfer.md). The traps:
// a push whose write-back reads as an edit marks its own operation stale; a
// record sent again unchanged costs the operator a duplicate at the service;
// a delete that never reaches the service leaves a contact there the log no
// longer has; and a hook pushing to a service it does not declare would overwrite
// another extension's records.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/transfer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

/// Sends to `echo`, answering an id per record and refusing FAIL1's. Offers
/// a logbook per station call: none for N0NONE, two for N0TWO, and throws
/// for N0FAIL. `bench.call` answers what it was last sent and asked.
const _echo = '''
  let last = null
  let asked = null
  globalThis.__halo.defineExtension({
    key: 'echo',
    name: 'Echo',
    version: '0.0.1',
    onActivation({ registerHook, timers }) {
      registerHook('transfer', { key: 'echo', hook: {
        label: 'Echo Log',
        description: 'Every contact, as logged',
        services: [{ key: 'echo' }],
        async suggestDestinations(args) {
          asked = args
          if (args.stationCalls.includes('N0FAIL')) throw new Error('Echo is down for N0FAIL')
          return args.stationCalls.filter((c) => c !== 'N0NONE').flatMap((c) => c === 'N0TWO'
            ? [{ id: 'N0TWO-A', label: 'Book A', stationCall: c }, { id: 'N0TWO-B', label: 'Book B', stationCall: c }]
            : [{ id: c, label: 'Echo ' + c, stationCall: c }])
        },
        async suggestPushes() {
          return [
            { key: 'new', service: 'echo', label: 'Push to Echo', select: { notSentTo: 'echo' } },
            { key: 'updates', service: 'echo', select: { changedSince: 'echo' } },
            { key: 'stolen', service: 'other', label: 'Push to a service echo does not declare', select: { notSentTo: 'other' } },
            { key: 'everything', service: 'echo', label: 'Every contact, every time' },
            { key: 'elsewhere', service: 'echo', label: 'Whatever QRZ lacks', select: { notSentTo: 'qrz' } },
          ]
        },
        async push(args) {
          last = args
          if (args.records.some((r) => r.adif.join('').includes('<CALL:5>SLOW1'))) await new Promise((resolve) => timers.set(resolve, 3000, false, []))
          if (args.records.some((r) => r.adif.join('').includes('<CALL:6>THROW1'))) throw new Error('Echo crashed')
          return args.records.map((r) => ({
            uuid: r.uuid,
            id: r.deleted ? undefined : 'id-' + r.uuid,
            error: r.adif.join('').includes('<CALL:5>FAIL1') ? 'refused' : r.adif.join('').includes('<CALL:5>FAIL2') ? new Error('refused') : undefined,
          }))
        },
      } })
      registerHook('transfer', { key: 'pull-only', hook: {
        label: 'Pull Only',
        services: [{ key: 'pulled', label: 'Pulled Log' }],
        async suggestDestinations() { return [{ id: 'main' }] },
        async suggestPushes() { return [{ key: 'new', service: 'pulled', label: 'Push to Pulled', select: { notSentTo: 'pulled' } }] },
      } })
      registerHook('bench', { key: 'echo', hook: { call: async () => ({ last, asked }) } })
    },
  })
''';

/// A `transfer` hook whose `services` throws.
const _broken = '''
  globalThis.__halo.defineExtension({
    key: 'broken',
    name: 'Broken',
    version: '0.0.1',
    onActivation({ registerHook }) {
      registerHook('transfer', { key: 'broken', hook: {
        label: 'Broken',
        services() { throw new Error('Broken is down') },
        async suggestDestinations() { return [{ id: 'main' }] },
        async suggestPushes() { return [{ key: 'new', service: 'broken', label: 'Push to Broken', select: { notSentTo: 'broken' } }] },
        async push(args) { return [] },
      } })
    },
  })
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await settings.setExperimentEnabled(kPushExperiment, true);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionService();
    services = HaLoServices(db, settings, extensions: extensions);
    prepareExtensionServiceForTest(extensions);
    await extensions.setDevBundles({
      'echo': (source: _echo, info: const ExtensionInfo(key: 'echo', file: 'echo.js', source: ExtensionSource.dev, core: true, name: 'Echo')),
    });
    operation = await services.operations.create(stationCall: 'N0DEV');
  });

  Future<Qso> log(String call) => services.qsos.add(operation.uuid, {
    'band': '20m',
    'mode': 'CW',
    'startAtMillis': 1794000000000,
    'their': {'call': call},
  });

  Future<Operation> stored() async => (await services.operations.get(operation.uuid))!;
  Future<List<PushServiceStatus>> rows() async => services.transfers.servicesFor(OperationPushScope(await stored()));
  Future<PushServiceStatus> echo() async => (await rows()).single;
  Future<List<PushSuggestion>> suggestions() async => (await echo()).due;
  Future<PushSuggestion?> suggestion(String key) async => (await suggestions()).where((s) => s.key == key).firstOrNull;
  const n0dev = TransferDestination(id: 'N0DEV', label: 'Echo N0DEV', stationCall: 'N0DEV');
  // One suggestion as the row the panel would push it from.
  Future<PushOutcome> pushTo(PushSuggestion suggestion, TransferDestination destination) async => services.transfers.push(
    OperationPushScope(await stored()),
    PushServiceStatus(hookKey: suggestion.hookKey, service: suggestion.service, label: suggestion.label, due: [suggestion], sent: 0, destination: destination),
  );
  Future<PushOutcome> push(PushSuggestion suggestion) => pushTo(suggestion, n0dev);
  Future<Map<String, dynamic>?> bench() async => asQsonMap(await services.extensions.host!.invokeHook('bench', key: 'echo', method: 'call'));
  Future<Map<String, dynamic>?> lastSent() async => asQsonMap((await bench())?['last']);

  test('a first push sends every contact once, records it, and leaves the operation processed', () async {
    final w1aw = await log('W1AW');
    await log('K1ABC');

    final offered = await suggestions();
    expect(
      [for (final s in offered) s.key],
      ['new'],
      reason: "nothing is behind yet, and one selecting by no record, or another service's, would never be done",
    );
    expect((await rows()).map((r) => r.service), [
      'echo',
    ], reason: 'a service the hook does not declare is never offered, and a hook with no push offers no row');
    final outcome = await push(offered.single);

    expect(outcome.sent, 2);
    expect(outcome.failures, isEmpty);
    final record = transferRecordOf((await services.qsos.get(w1aw.uuid))!.data, 'echo:n0dev')!;
    expect(record['id'], 'id-${w1aw.uuid}');
    expect((await stored()).status, OperationStatus.processed, reason: "the push's own write-back is not an edit");
    final adif = ((await lastSent())!['records'] as List).map((r) => ((r as Map)['adif'] as List).join()).join();
    expect(adif, contains('<CALL:4>W1AW'));
    expect(adif, isNot(contains('<EOH>')));
    expect((await echo()).completed, isTrue, reason: 'everything is sent and nothing changed');
    expect(asQsonMap(asQsonMap((await stored()).data[qsoTransferKey])?['echo:n0dev'])?['sentCount'], 2);
  }, timeout: const Timeout(Duration(seconds: 90)));

  // The panel's one Push runs every suggestion due in turn, each counted
  // when the panel opened: one reading the contacts as they were then sends
  // again what the push before it just sent, with no id, and the service
  // makes a copy.
  test('a push reads its contacts as stored, so what a push just before it sent is not sent again', () async {
    final w1aw = await log('W1AW');
    final first = (await suggestion('new'))!;
    final stale = (await suggestion('new'))!;
    await push(first);

    final again = await push(stale);
    expect((sent: again.sent, unchanged: again.unchanged), (sent: 0, unchanged: 1));

    await services.qsos.softDelete((await services.qsos.get(w1aw.uuid))!);
    final delete = (await suggestion('updates'))!;
    expect((await push(delete)).deleted, 1);
    final twice = await push(delete);
    expect((deleted: twice.deleted, failures: twice.failures.length), (deleted: 0, failures: 0), reason: 'the record is gone: nothing is left to delete');
  }, timeout: const Timeout(Duration(seconds: 90)));

  // The hook decides where an operation's contacts can go: a destination it
  // does not offer must not appear, and two it offers must not merge into
  // one push. A contact goes to a destination by the call its segment was on
  // the air with, as the file export files it: by the operation's first call
  // it would land in the logbook of a station that was not on the air for it.
  test('each destination the hook offers for the operation is a push of its own, taking its station call\'s contacts', () async {
    await services.qsos.addEvent(operation.uuid, kind: 'start', atMillis: 1000, operation: {'stationCall': 'N0NONE'});
    await services.qsos.addEvent(operation.uuid, kind: 'break', atMillis: 3000, operation: {'stationCall': 'N0TWO'});
    await services.qsos.addEvent(operation.uuid, kind: 'break', atMillis: 5000, operation: {'stationCall': 'N0DEV'});
    Future<Qso> at(int millis, String call) => services.qsos.add(operation.uuid, {
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': millis,
      'their': {'call': call},
    });
    await at(2000, 'W1AW');
    final two = await at(4000, 'K1ABC');
    final dev = await at(6000, 'W2XYZ');

    final offered = await rows();
    expect([for (final r in offered) (r.destination!.id, r.toSend)], [('N0TWO-A', 1), ('N0TWO-B', 1), ('N0DEV', 1)]);
    final asked = asQsonMap((await bench())!['asked'])!;
    expect(asked['stationCalls'], ['N0NONE', 'N0TWO', 'N0DEV']);
    expect(asQsonMap(asQsonMap(asked['scope'])?['operation'])?['uuid'], operation.uuid, reason: 'the hook decides from the operation');

    final row = offered.last;
    await pushTo(row.due.single, row.destination!);
    expect(((await lastSent())!['records'] as List).map((r) => (r as Map)['uuid']), [dev.uuid]);
    expect(transferRecordOf((await services.qsos.get(dev.uuid))!.data, 'echo:n0dev'), isNotNull);
    expect((await services.qsos.get(two.uuid))!.data[qsoTransferKey], isNull, reason: "N0TWO's logbooks are pushed on their own");
    expect([for (final r in await rows()) r.completed], [false, false, true]);

    // One contact in two logbooks of one service: each keeps its own record,
    // and sending it to one leaves it due to the other.
    final bookA = (await rows()).first;
    await pushTo(bookA.due.single, bookA.destination!);
    expect([for (final r in await rows()) r.completed], [true, false, true], reason: 'Book B has not been sent it');
    final bookB = (await rows())[1];
    await pushTo(bookB.due.single, bookB.destination!);
    final records = asQsonMap((await services.qsos.get(two.uuid))!.data[qsoTransferKey])!;
    expect(records.keys, unorderedEquals(['echo:n0two-a', 'echo:n0two-b']));
    expect([for (final r in await rows()) (r.completed, r.sent)], [(true, 1), (true, 1), (true, 1)]);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a hook that cannot name a destination says why, in place of its pushes', () async {
    operation = await services.operations.create(stationCall: 'N0FAIL');
    await log('W1AW');
    final row = await echo();
    expect(row.problem, contains('Echo is down for N0FAIL'));
    expect(
      (completed: row.completed, destination: row.destination, due: row.due.length),
      (completed: false, destination: null, due: 0),
      reason: 'nothing to push, and not done either',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  // The panel shows a service as done from this: a service dropped once
  // nothing is due would vanish instead of showing its check, and one
  // counted done while an update waits would hide the update.
  test('a service is due until everything is sent, and done after, holding what it was sent', () async {
    final w1aw = await log('W1AW');
    await log('K1ABC');
    final before = await echo();
    expect((completed: before.completed, toSend: before.toSend, sent: before.sent), (completed: false, toSend: 2, sent: 0));

    await push((await suggestion('new'))!);
    final after = await echo();
    expect((completed: after.completed, sent: after.sent), (completed: true, sent: 2));

    await services.qsos.update(Qso(uuid: w1aw.uuid, operationUuid: operation.uuid, data: {...(await services.qsos.get(w1aw.uuid))!.data, 'band': '17m'}));
    final edited = await echo();
    expect((completed: edited.completed, toSend: edited.toSend), (completed: false, toSend: 1), reason: 'the update is due again');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('an edit after the push offers the update, and sends only the contact that changed', () async {
    final w1aw = await log('W1AW');
    await log('K1ABC');
    await push((await suggestion('new'))!);

    await services.qsos.update(Qso(uuid: w1aw.uuid, operationUuid: operation.uuid, data: {...(await services.qsos.get(w1aw.uuid))!.data, 'band': '17m'}));

    expect((await stored()).status, OperationStatus.completed, reason: 'the edit is what tells the operator the push is stale');
    final updates = (await suggestion('updates'))!;
    expect(updates.count, 1);
    expect(
      (label: updates.label, description: updates.description),
      (label: 'Echo Log', description: 'Every contact, as logged'),
      reason: "a suggestion with no label of its own shows its hook's, through a service that names none",
    );
    final outcome = await push(updates);
    expect(outcome.sent, 1);
    expect([for (final r in (await lastSent())!['records'] as List) (r as Map)['id']], ['id-${w1aw.uuid}'], reason: 'an update names the id the service gave');
    expect(
      asQsonMap(asQsonMap((await stored()).data[qsoTransferKey])?['echo:n0dev'])?['sentCount'],
      2,
      reason: 'what the service holds, not what this push sent',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  // An operation edit rewrites every contact's record without touching any
  // contact: compared only by the contact's own revision, a corrected park
  // or grid never reaches the service. Compared by the operation's raw
  // timestamp instead, every status change (logging, finishing, the push
  // itself) would make the whole operation due again.
  test("an edit to the operation offers its contacts again; its status changing and new contacts do not", () async {
    await log('W1AW');
    await log('K1ABC');
    await push((await suggestion('new'))!);

    await services.operations.setStatus(operation.uuid, OperationStatus.completed);
    await log('W2XYZ');
    expect([for (final s in await suggestions()) (s.key, s.count)], [('new', 1)], reason: 'logging and finishing change no record already sent');
    await push((await suggestion('new'))!);
    expect((await echo()).completed, isTrue);

    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...(await stored()).data, 'grid': 'FN31pr'}));
    final updates = (await suggestion('updates'))!;
    expect(updates.count, 3);
    final outcome = await push(updates);
    expect(outcome.sent, 3);
    expect(((await lastSent())!['records'] as List).map((r) => ((r as Map)['adif'] as List).join()).join(), contains('<MY_GRIDSQUARE:6>FN31pr'));
    expect((await echo()).completed, isTrue);

    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...(await stored()).data, 'userTitle': 'Renamed'}));
    final renamed = await push((await suggestion('updates'))!);
    expect((sent: renamed.sent, unchanged: renamed.unchanged), (sent: 0, unchanged: 3), reason: 'the title is in no record');
    expect((await echo()).completed, isTrue, reason: 'checked against the new content, the records are current');
  }, timeout: const Timeout(Duration(seconds: 90)));

  // The record is built from the contact as read before the hook call; the
  // write-back lands after it. Stamped with the write's revision, an edit
  // made in between reads as sent and never goes.
  test('an edit made while its push is out stays due, keeping the id the service gave', () async {
    final slow = await log('SLOW1');
    final pushed = push((await suggestion('new'))!);
    while (await lastSent() == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await services.qsos.update(Qso(uuid: slow.uuid, operationUuid: operation.uuid, data: {...(await services.qsos.get(slow.uuid))!.data, 'band': '17m'}));
    expect((await pushed).sent, 1);

    final record = transferRecordOf((await services.qsos.get(slow.uuid))!.data, 'echo:n0dev');
    expect(record?['id'], 'id-${slow.uuid}', reason: 'without it, the next push makes a copy');
    expect((await suggestion('updates'))?.count, 1, reason: 'the band the service has not seen');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a contact whose record did not change is not sent again', () async {
    final w1aw = await log('W1AW');
    await push((await suggestion('new'))!);

    // A write that moves the revision without changing what the record says.
    await services.qsos.update((await services.qsos.get(w1aw.uuid))!, operatorEdit: false);

    final updates = (await suggestion('updates'))!;
    expect(updates.count, 1, reason: 'the count is an upper bound');
    final outcome = await push(updates);
    expect(outcome.sent, 0);
    expect(outcome.unchanged, 1);
    expect((await echo()).completed, isTrue, reason: 'an unchanged record left behind the contact is selected again on every count');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a deleted contact the service holds is pushed as a delete, and its record goes', () async {
    final w1aw = await log('W1AW');
    await push((await suggestion('new'))!);

    await services.qsos.softDelete((await services.qsos.get(w1aw.uuid))!);

    final delete = (await suggestion('updates'))!;
    expect(delete.contacts, isEmpty);
    expect(delete.deletes.map((q) => q.uuid), [w1aw.uuid]);
    final outcome = await push(delete);
    expect(outcome.deleted, 1);
    final sent = ((await lastSent())!['records'] as List).single as Map;
    expect(sent['deleted'], isTrue);
    expect(sent['id'], 'id-${w1aw.uuid}');
    expect(transferRecordOf((await services.qsos.get(w1aw.uuid))!.data, 'echo:n0dev'), isNull);
    expect(await suggestions(), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a record the service refuses stays unsent, to go again next time', () async {
    final failing = await log('FAIL1');
    await log('K1ABC');

    final outcome = await push((await suggestion('new'))!);

    expect(outcome.sent, 1);
    expect(outcome.failures.keys, [failing.uuid]);
    expect((await suggestion('new'))!.contacts.map((q) => q.uuid), [failing.uuid]);
    expect((await stored()).status, isNot(OperationStatus.processed), reason: 'a contact the service refused is not sent, so neither is the log');
  }, timeout: const Timeout(Duration(seconds: 90)));

  // A push the host gave up on may still be running in the hook, and the
  // service may already hold what it sent with no id saved here: going on,
  // or counting the chunk as refused and retrying it, makes copies.
  test('a push the service takes too long on stops there, records nothing for that chunk, and leaves the log unsent', () async {
    final previous = TransferService.pushTimeout;
    TransferService.pushTimeout = const Duration(milliseconds: 500);
    addTearDown(() => TransferService.pushTimeout = previous);
    final slow = await log('SLOW1');
    final pushed = push((await suggestion('new'))!);

    await expectLater(pushed, throwsA(isA<PushTimedOut>()));
    expect(transferRecordOf((await services.qsos.get(slow.uuid))!.data, 'echo:n0dev'), isNull);
    expect((await stored()).status, isNot(OperationStatus.processed));
    expect((await echo()).toSend, 1, reason: 'still due, to go again when the operator pushes');
  }, timeout: const Timeout(Duration(seconds: 90)));

  // A JS Error crosses the bridge as `{}`: read as no error, the contact is
  // recorded as sent and never goes again.
  test('an error that is not a string still leaves the contact unsent', () async {
    final failing = await log('FAIL2');
    final outcome = await push((await suggestion('new'))!);
    expect(outcome.failures.keys, [failing.uuid]);
    expect(transferRecordOf((await services.qsos.get(failing.uuid))!.data, 'echo:n0dev'), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));

  // A hook that throws may have sent part of the chunk: going on, or
  // counting the chunk refused and retrying it, sends those contacts again
  // with no id, and the service makes copies.
  test('a hook that throws stops the push there, and the log stays unsent', () async {
    await log('THROW1');
    await expectLater(push((await suggestion('new'))!), throwsA(isA<ExtensionHostException>()));
    expect((await stored()).status, isNot(OperationStatus.processed));
    expect((await echo()).toSend, 1);
  }, timeout: const Timeout(Duration(seconds: 90)));

  // Dropped, a hook that cannot list its services leaves no row: the
  // operator reads that as nothing to push there.
  group('beyond one operation', () {
    // The Chasing and Logs views push the whole log under their station:
    // contacts of every operation and of none. A scope that missed one would
    // leave the service short of a contact the operator logged; one that took
    // another station's would send it to the wrong logbook.
    Future<Qso> logUnder(String operationUuid, String ourCall, String theirCall) => services.qsos.add(operationUuid, {
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': 1794000000000,
      'our': {'call': ourCall},
      'their': {'call': theirCall},
    });
    PushServiceStatus rowFor(List<PushServiceStatus> rows, String id) => rows.singleWhere((row) => row.destination?.id == id);
    Future<PushOutcome> pushRow(PushScope scope, PushServiceStatus row) => services.transfers.push(
      scope,
      PushServiceStatus(hookKey: row.hookKey, service: row.service, label: row.label, due: row.due, sent: 0, destination: row.destination),
    );

    test("the Chasing scope pushes the station's contacts logged outside any operation, and no operation's", () async {
      final chased = await logUnder('', 'N0DEV', 'W1AW');
      await logUnder('', 'K1OTHER', 'W2AW');
      await logUnder(operation.uuid, 'N0DEV', 'W3AW');

      const scope = ChasingPushScope('N0DEV');
      final row = rowFor(await services.transfers.servicesFor(scope), 'N0DEV');
      final due = row.due.singleWhere((s) => s.key == 'new');
      expect(due.contacts.map((q) => q.uuid), [chased.uuid]);
      expect(asQsonMap((await bench())?['asked'])?['scope'], {'kind': 'chasing', 'stationCall': 'N0DEV'});

      final outcome = await pushRow(scope, row);
      expect(outcome.sent, 1);
      expect(transferRecordOf((await services.qsos.get(chased.uuid))!.data, 'echo:n0dev'), isNotNull);
      expect(rowFor(await services.transfers.servicesFor(scope), 'N0DEV').completed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test("the Logs scope pushes the callsign's whole log, every operation's and none's, deletes included", () async {
      final other = await services.operations.create(stationCall: 'N0DEV');
      final first = await logUnder(operation.uuid, 'N0DEV', 'W1AW');
      final second = await logUnder(other.uuid, 'N0DEV', 'W2AW');
      final loose = await logUnder('', 'N0DEV', 'W3AW');
      await logUnder(other.uuid, 'K1OTHER', 'W4AW');

      const scope = LogPushScope('N0DEV');
      var row = rowFor(await services.transfers.servicesFor(scope), 'N0DEV');
      expect(row.due.singleWhere((s) => s.key == 'new').contacts.map((q) => q.uuid), unorderedEquals([first.uuid, second.uuid, loose.uuid]));
      expect(asQsonMap((await bench())?['asked'])?['scope'], {'kind': 'log', 'stationCall': 'N0DEV'});

      for (final uuid in [operation.uuid, other.uuid]) {
        await services.operations.setStatus(uuid, OperationStatus.completed);
      }
      row = rowFor(await services.transfers.servicesFor(scope), 'N0DEV');
      await pushRow(scope, row);
      // Each operation keeps its summary; neither is marked processed, as no
      // operation was the one being sent.
      for (final uuid in [operation.uuid, other.uuid]) {
        final stored = (await services.operations.get(uuid))!;
        expect(asQsonMap(stored.data[qsoTransferKey])?['echo:n0dev'], isNotNull);
        expect(stored.status, OperationStatus.completed);
      }

      await services.qsos.softDelete((await services.qsos.get(second.uuid))!);
      row = rowFor(await services.transfers.servicesFor(scope), 'N0DEV');
      expect(row.due.singleWhere((s) => s.key == 'updates').deletes.map((q) => q.uuid), [second.uuid], reason: 'the service still holds it');
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('a purged contact the service holds is still owed its delete from the Logs view', () async {
      // Purged test contacts stay as tombstones until sync carries them; the
      // operation and Chasing scopes send their deletes, and a Logs push that
      // left them out would leave them at the service for good.
      const scope = LogPushScope('N0DEV/T');
      final test = await logUnder('', 'N0DEV/T', 'W1AW');
      await pushRow(scope, rowFor(await services.transfers.servicesFor(scope), 'N0DEV/T'));

      expect(await services.qsos.purgeQsos([test.uuid]), 1);
      final row = rowFor(await services.transfers.servicesFor(scope), 'N0DEV/T');
      expect(row.due.singleWhere((s) => s.key == 'updates').deletes.map((q) => q.uuid), [test.uuid]);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('the Logs scope over every callsign offers each its own logbook', () async {
      await logUnder(operation.uuid, 'N0DEV', 'W1AW');
      await logUnder('', 'N0TWO', 'W2AW');

      final rows = await services.transfers.servicesFor(const LogPushScope(null));
      expect(rows.map((row) => row.destination?.id), unorderedEquals(['N0DEV', 'N0TWO-A', 'N0TWO-B']));
      expect(asQsonMap((await bench())?['asked'])?['scope'], {'kind': 'log'});
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  test('a hook that cannot list its services shows its error in a row of its own', () async {
    await services.extensions.setDevBundles({
      'echo': (source: _echo, info: const ExtensionInfo(key: 'echo', file: 'echo.js', source: ExtensionSource.dev, core: true, name: 'Echo')),
      'broken': (source: _broken, info: const ExtensionInfo(key: 'broken', file: 'broken.js', source: ExtensionSource.dev, core: true, name: 'Broken')),
    });
    await log('W1AW');
    final broken = (await rows()).where((r) => r.hookKey == 'broken').single;
    expect((broken.service, broken.completed, broken.problem), ('broken', false, 'Broken is down'), reason: 'the error, without the stack under it');
  }, timeout: const Timeout(Duration(seconds: 90)));

  // Refused at the write-back instead, the service would hold the contacts
  // with no id saved here, and the next push would make copies.
  test('with the clock travelling, a push of a real operation is refused before anything is sent', () async {
    await log('W1AW');
    final offered = (await suggestion('new'))!;
    AppClock.instance.travel(delta: const Duration(days: 1));
    addTearDown(AppClock.instance.reset);
    await expectLater(push(offered), throwsA(isA<WriteRefused>()));
    expect(await lastSent(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('with EXP PUSH off, no transfer hook is asked anything and nothing can be pushed', () async {
    await log('W1AW');
    final offered = await suggestions();
    expect(offered, isNotEmpty);

    await services.settings.setExperimentEnabled(kPushExperiment, false);

    expect(await rows(), isEmpty);
    await expectLater(push(offered.single), throwsStateError);
    expect(await lastSent(), isNull, reason: 'the hook never heard of the push');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
