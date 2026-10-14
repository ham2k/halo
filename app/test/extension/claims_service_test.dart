// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which device may change which claims (docs/design/claims.md §6). Any
// device raises a slot from a contact it sees. Only one holding the whole log
// lowers one, because lowering needs the runner-up: a device that lowered a
// slot from part of the log would publish a checklist missing every slot the
// rest of the log holds.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/claims_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_secure_storage.dart';
import '../support/fake_extension_host.dart';

class _Settings extends ChangeNotifier {
  bool enabled = true;
  bool whole = true;
  Map<String, int> _built = {};
  int builtReads = 0;
  bool pending = false;

  Map<String, int> get built {
    builtReads++;
    return _built;
  }

  set built(Map<String, int> value) => _built = value;

  void set({bool? enabled, bool? whole}) {
    this.enabled = enabled ?? this.enabled;
    this.whole = whole ?? this.whole;
    notifyListeners();
  }
}

/// A program whose checklist is the calls worked: one slot per call, on
/// any band, confirmed by LoTW.
List<Map<String, dynamic>> _claimsOf(Map<String, dynamic> qso) {
  if (qso['band'] == 'event') return const [];
  final their = qso['their'] as Map;
  final lotw = ((qso['qsl'] as Map?)?['lotw'] as Map?)?['received'] == true;
  return [
    {'holder': 'ME', 'ref': their['call'], 'band': null, 'mode': null, 'level': lotw ? 'confirmed' : 'worked'},
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late QsosRepository qsos;
  late OperationsRepository operations;
  late ClaimsRepository claims;
  late _Settings settings;
  late Map<String, Object?> stubs;
  late ExtensionServiceWithFakeHost extensions;
  late ClaimsService service;
  late int version;
  late int calls;
  late bool absent;
  late int askedForPrograms;
  late bool listingFails;
  late int asked;

  ClaimsService newService({StatusBarService? statusBar, int progressAbove = kClaimsProgressAbove, Duration debounce = Duration.zero}) => ClaimsService(
    extensions: extensions,
    qsos: qsos,
    operations: operations,
    claims: claims,
    isEnabled: () => settings.enabled,
    holdsWholeLog: () => settings.whole,
    builtVersions: () => settings.built,
    saveBuiltVersions: (built) async => settings.built = built,
    changesPending: () => settings.pending,
    saveChangesPending: (pending) async => settings.pending = pending,
    settingsChanges: settings,
    statusBar: statusBar,
    debounce: debounce,
    progressAbove: progressAbove,
  );

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    qsos = QsosRepository(db);
    operations = OperationsRepository(db);
    claims = ClaimsRepository(db);
    settings = _Settings();
    version = 1;
    calls = 0;
    absent = false;
    askedForPrograms = 0;
    listingFails = false;
    asked = 0;
    stubs = {
      'chasing:*:program': (_) {
        askedForPrograms++;
        if (listingFails) throw ExtensionHostException('timed out');
        return [
          if (!absent)
            {
              'key': 'calls',
              'ok': true,
              'value': {'label': 'Calls', 'version': version, 'editions': 'lifetime'},
            },
        ];
      },
      'chasing:calls:claimsForQsos': (Object? args) {
        calls++;
        final sent = ((args as Map)['qsos'] as List).cast<Map<String, dynamic>>();
        asked += sent.length;
        return {for (final qso in sent) qso['uuid']: _claimsOf(qso)};
      },
    };
    extensions = ExtensionServiceWithFakeHost(FakeExtensionHost(stubs));
    service = newService();
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });

  /// Lets the change stream deliver, the debounce fire, and every queued
  /// pass finish — twice, since a queued step (an operation deletion's
  /// lookup) can itself schedule a pass, after the first wait was over.
  Future<void> settle() async {
    for (var round = 0; round < 2; round++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await service.idle;
    }
  }

  Future<Qso> log(String call, {int at = 1000, bool lotw = false}) => qsos.add('', {
    'their': {'call': call},
    'band': '20m',
    'mode': 'CW',
    'startAtMillis': at,
    if (lotw)
      'qsl': {
        'lotw': {'received': true},
      },
  });

  Future<Map<String, (ClaimLevel, String?)>> checklist() async => {
    for (final claim in await claims.checklist('calls', 'ME')) claim.ref: (claim.level, claim.qso),
  };

  test('a whole-log device builds every program from the log it already holds, once', () async {
    final first = await log('W1AW');
    service.start();
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, first.uuid)});
    expect(settings.built, {'calls': 1});

    calls = 0;
    service.dispose();
    service = newService()..start();
    await settle();
    expect(calls, 0, reason: 'a program already built at its version is not rescanned on every launch');
  });

  test('a contact logged or confirmed raises its slot', () async {
    service.start();
    await settle();
    final early = await log('W1AW', at: 1000);
    await log('W1AW', at: 2000);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, early.uuid)});

    final confirmed = await log('W1AW', at: 3000, lotw: true);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.confirmed, confirmed.uuid)});
  });

  test('deleting the contact that holds a slot hands it to the runner-up on a whole-log device', () async {
    final confirmed = await log('W1AW', at: 3000, lotw: true);
    final runnerUp = await log('W1AW', at: 1000);
    final only = await log('K1ABC');
    service.start();
    await settle();

    await qsos.softDelete(confirmed);
    await qsos.softDelete(only);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, runnerUp.uuid)});
  });

  test('a device holding part of the log raises slots but never lowers one', () async {
    settings.whole = false;
    await log('N0OLD');
    service.start();
    await settle();
    expect(await checklist(), isEmpty, reason: 'a partial device cannot build a checklist from what it happens to hold');

    final confirmed = await log('W1AW', lotw: true);
    await settle();
    await qsos.softDelete(confirmed);
    final logged = await log('K1ABC');
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.confirmed, confirmed.uuid), 'K1ABC': (ClaimLevel.worked, logged.uuid)});
  });

  test('a device that comes to hold the whole log rebuilds, withdrawing what it could not before', () async {
    settings.whole = false;
    service.start();
    final gone = await log('W1AW');
    await settle();
    await qsos.softDelete(gone);
    await settle();
    expect((await checklist()).keys, ['W1AW']);

    settings.set(whole: true);
    await settle();
    expect(await checklist(), isEmpty);
  });

  test('a new version of a program rebuilds its checklist when its runtime arrives', () async {
    await log('W1AW');
    service.start();
    await settle();

    version = 2;
    extensions.runtimeGeneration.value++;
    await settle();
    expect((await claims.checklist('calls', 'ME')).single.version, 2);
    expect(settings.built, {'calls': 2});
  });

  // A rescan that wrote what it had read before the failure would withdraw
  // every slot held by the contacts it never reached.
  test('a program failing mid-rescan withdraws nothing, and is rebuilt once a runtime answers', () async {
    final gone = await log('W1AW');
    await log('BAD');
    var failing = true;
    final working = stubs['chasing:calls:claimsForQsos']! as Object? Function(Object?);
    stubs['chasing:calls:claimsForQsos'] = (Object? args) {
      final sent = ((args! as Map)['qsos'] as List).cast<Map<String, dynamic>>();
      if (failing && sent.any((qso) => (qso['their'] as Map)['call'] == 'BAD')) throw ExtensionHostException('boom');
      return working(args);
    };
    failing = false;
    service.start();
    await settle();
    failing = true;

    await withErrorHooks(() async {
      await qsos.softDelete(gone);
      await settle();
    }, backend: FakeErrorReportingBackend());
    expect((await checklist()).keys, unorderedEquals(['W1AW', 'BAD']));
    expect(settings.built, isEmpty);

    failing = false;
    extensions.runtimeGeneration.value++;
    await settle();
    expect((await checklist()).keys, ['BAD']);
    expect(settings.built, {'calls': 1});
  });

  test('nothing is kept while chasing is off, and turning it on builds from the whole log', () async {
    settings.enabled = false;
    service.start();
    final logged = await log('W1AW');
    await settle();
    expect(await checklist(), isEmpty);
    expect(calls, 0);

    settings.set(enabled: true);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, logged.uuid)});
  });

  test('turning chasing off and on again rebuilds, since changes went unfollowed in between', () async {
    final logged = await log('W1AW');
    service.start();
    await settle();

    settings.set(enabled: false);
    await qsos.softDelete(logged);
    await settle();
    settings.set(enabled: true);
    await settle();
    expect(await checklist(), isEmpty);
  });

  // A bar left behind by a pass that finished, or failed, sits in the footer
  // for the rest of the session; one shown for every small pass flashes on
  // each contact logged.
  test('a pass over more contacts than the threshold shows its progress in the footer while it runs', () async {
    SharedPreferences.setMockInitialValues({});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    final shown = <String?>{};
    statusBar.addListener(() => shown.add(statusBar.itemForKey('claims')?.title));
    for (final call in ['W1AW', 'K1ABC', 'N0CALL']) {
      await log(call);
    }
    service = newService(statusBar: statusBar, progressAbove: 2)..start();
    await settle();
    expect(shown, contains('Checking the log for Calls'));
    expect(statusBar.itemForKey('claims'), isNull);

    shown.clear();
    await qsos.writeBatch(
      operationUuid: '',
      inserts: [
        for (final call in ['AA1A', 'BB2B', 'CC3C'])
          {
            'their': {'call': call},
            'band': '20m',
            'mode': 'CW',
            'startAtMillis': 1000,
          },
      ],
    );
    await settle();
    expect(shown, contains('Checking QSOs for chasing'), reason: 'an import lands as one write naming every contact it added');
    expect(statusBar.itemForKey('claims'), isNull);

    shown.clear();
    await log('DD4D');
    await settle();
    expect(shown, isEmpty);
    expect((await checklist()).length, 7);
  });

  test('deleting an operation withdraws what only its contacts claimed, and restoring it brings them back', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final inOperation = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': 1000,
    });
    final loose = await log('K1ABC');
    service.start();
    await settle();

    await operations.softDelete(op.uuid);
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, loose.uuid)});

    await operations.undelete(op.uuid);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, inOperation.uuid), 'K1ABC': (ClaimLevel.worked, loose.uuid)});
  });

  // A malformed answer leaves its contact out. A rescan that read the
  // omission as "claims nothing" would withdraw every slot that contact
  // holds, under an epoch that outranks every other device; one that gave up
  // instead would never let the program be rebuilt at all.
  test('a rescan keeps what a contact the program could not answer for holds, and still lowers the rest', () async {
    final gone = await log('W1AW');
    await log('BAD');
    var malformed = false;
    final working = stubs['chasing:calls:claimsForQsos']! as Object? Function(Object?);
    stubs['chasing:calls:claimsForQsos'] = (Object? args) {
      final answer = (working(args)! as Map).cast<String, Object?>();
      final sent = ((args! as Map)['qsos'] as List).cast<Map<String, dynamic>>();
      return {
        for (final MapEntry(:key, :value) in answer.entries)
          key: malformed && sent.any((qso) => qso['uuid'] == key && (qso['their'] as Map)['call'] == 'BAD')
              ? [
                  {'not': 'a claim'},
                ]
              : value,
      };
    };
    service.start();
    await settle();
    malformed = true;

    await withErrorHooks(() async {
      await qsos.softDelete(gone);
      await settle();
    }, backend: FakeErrorReportingBackend());
    expect((await checklist()).keys, ['BAD']);
    expect(settings.built, {'calls': 1});
  });

  // Built versions vouch that every change reached the program. One that
  // was away when a change arrived never saw it, and would be trusted.
  test('a program away when contacts change is rebuilt once it is back', () async {
    service.start();
    await settle();
    expect(settings.built, {'calls': 1});

    absent = true;
    extensions.runtimeGeneration.value++;
    final logged = await log('K1ABC');
    await settle();
    expect(settings.built, isEmpty);

    absent = false;
    extensions.runtimeGeneration.value++;
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, logged.uuid)});
  });

  test('a device holding part of the log raises slots from contacts named alongside a change to the whole log', () async {
    settings.whole = false;
    service = newService(debounce: const Duration(milliseconds: 50))..start();
    Future<void> settleDebounced() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await service.idle;
    }

    await qsos.add('op', {
      'their': {'call': 'N0OLD'},
      'band': '20m',
    });
    await settleDebounced();

    await qsos.hardDeleteAllForOperation('op');
    final logged = await log('W1AW');
    await settleDebounced();
    expect((await checklist())['W1AW'], (ClaimLevel.worked, logged.uuid));
  });

  // The changes a pass has not reached yet live only in memory, while the
  // built versions on disk go on vouching for the rows.
  test('changes a quit left unprocessed are caught up by a rebuild on the next launch', () async {
    service = newService(debounce: const Duration(hours: 1))..start();
    await settle();
    expect(settings.built, {'calls': 1});
    final logged = await log('K1ABC');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    service.dispose();

    service = newService()..start();
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, logged.uuid)});
    expect(settings.pending, isFalse);
  });

  test('contacts that arrive before the service starts are not lost', () async {
    settings.built = {'calls': 1};
    service.listen();
    final logged = await log('K1ABC');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(calls, 0, reason: 'nothing asks a program before the runtime is up');

    service.start();
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, logged.uuid)});
  });

  test('a program that fails on a pass is rebuilt once, in the same session', () async {
    service.start();
    await settle();
    var failures = 1;
    final working = stubs['chasing:calls:claimsForQsos']! as Object? Function(Object?);
    stubs['chasing:calls:claimsForQsos'] = (Object? args) {
      if (failures-- > 0) throw ExtensionHostException('boom');
      return working(args);
    };

    late Qso logged;
    await withErrorHooks(() async {
      logged = await log('K1ABC');
      await settle();
    }, backend: FakeErrorReportingBackend());
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, logged.uuid)});
    expect(settings.built, {'calls': 1});
  });

  // Asking on every pass is a crossing into every extension per contact
  // logged, and one that times out answers no programs at all.
  test('the programs are asked for once per runtime, not once per pass', () async {
    service.start();
    await settle();
    for (final call in ['W1AW', 'K1ABC', 'N0CALL']) {
      await log(call);
      await settle();
    }
    expect(askedForPrograms, 1);

    extensions.runtimeGeneration.value++;
    await log('AA1A');
    await settle();
    expect(askedForPrograms, 2);
  });

  StoredClaim heldClaim(String call, {required String qso, ClaimLevel level = ClaimLevel.confirmed, int epoch = 0}) => StoredClaim(
    uuid: claimUuid(program: 'calls', holder: 'ME', edition: '', ref: call, band: null, mode: null, source: kClaimSourceLog),
    program: 'calls',
    holder: 'ME',
    edition: '',
    ref: call,
    band: null,
    mode: null,
    source: kClaimSourceLog,
    level: level,
    atMillis: 1000,
    qso: qso,
    version: 1,
    epoch: epoch,
    data: const {},
    deleted: false,
    updatedAtMillis: 1000,
  );

  // Sync lag: the contact holding a slot on another device may not have
  // reached this one, and a rescan that read its absence as "nobody claims
  // this" would withdraw the slot for every device, under a raised epoch.
  test('a rescan leaves alone a slot held by a contact that has not arrived here', () async {
    await claims.mergeFromSync([heldClaim('W1AW', qso: 'on-its-way').toRecord()]);
    final gone = await log('K1ABC');
    service.start();
    await settle();

    await qsos.softDelete(gone);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.confirmed, 'on-its-way')});
  });

  // A device that has not heard of a deletion can send back, at a higher
  // epoch, the claim the deleted contact used to hold. Only the whole log
  // has the runner-up.
  test('a synced row naming a contact deleted here is corrected on a whole-log device', () async {
    final confirmed = await log('W1AW', at: 3000, lotw: true);
    final runnerUp = await log('W1AW', at: 1000);
    service.start();
    await settle();
    await qsos.softDelete(confirmed);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, runnerUp.uuid)});

    await claims.mergeFromSync([heldClaim('W1AW', qso: confirmed.uuid, epoch: 9).toRecord()]);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, runnerUp.uuid)});
  });

  test('a device holding part of the log takes such a row as it is', () async {
    settings.whole = false;
    final gone = await log('W1AW');
    await qsos.softDelete(gone);
    service.start();
    await settle();

    await claims.mergeFromSync([heldClaim('W1AW', qso: gone.uuid, epoch: 9).toRecord()]);
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.confirmed, gone.uuid)});
  });

  // Emptied for another account: the built versions vouched for rows that
  // are gone, and would stop the rebuild.
  test('claims cleared away are rebuilt', () async {
    final logged = await log('W1AW');
    service.start();
    await settle();
    expect(settings.built, {'calls': 1});

    await claims.clearAll();
    await settle();
    expect(settings.built, isEmpty);
    extensions.runtimeGeneration.value++;
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, logged.uuid)});
  });

  group('claim records', () {
    Map<String, dynamic> record(String ref, {String program = 'calls', ClaimLevel level = ClaimLevel.verified}) => claimEventQson(
      program: program,
      importer: 'credits',
      imported: ImportedClaim(QsoClaim(holder: 'ME', ref: ref, band: null, mode: null, level: level), atMillis: 500),
      fallbackMillis: 9000,
    );

    // The program made these claims when the file was imported; asking it
    // again about an event row gets nothing, which would withdraw them.
    test('an imported claim fills its slot from the log, without asking the program', () async {
      service.start();
      await settle();
      final before = asked;
      await qsos.replaceClaimEvents('calls', 'credits', [record('W1AW'), record('K1ABC', program: 'other')]);
      await settle();
      final held = await checklist();
      expect(held.keys, ['W1AW'], reason: "another program's record claims nothing under this one");
      expect(held['W1AW']!.$1, ClaimLevel.verified);
      expect(asked, before);
    });

    // The reason imports live in the log: a device joining an account empties
    // the claims table, and only what the log holds comes back.
    test('imported claims come back when the claims table is rebuilt', () async {
      await qsos.replaceClaimEvents('calls', 'credits', [record('W1AW')]);
      service.start();
      await settle();
      await claims.clearAll();
      await settle();
      extensions.runtimeGeneration.value++;
      await settle();
      expect((await checklist())['W1AW']?.$1, ClaimLevel.verified);
    });

    test('a park the next file no longer lists gives up its slot', () async {
      final contact = await log('W1AW');
      await qsos.replaceClaimEvents('calls', 'credits', [record('W1AW'), record('K1ABC')]);
      service.start();
      await settle();
      await qsos.replaceClaimEvents('calls', 'credits', [record('K1ABC')]);
      await settle();
      final held = await checklist();
      expect(held['W1AW'], (ClaimLevel.worked, contact.uuid), reason: 'the contact in the log holds the slot again');
      expect(held['K1ABC']?.$1, ClaimLevel.verified);
    });
  });

  test('a synced row naming a deleted contact is checked even when it arrives before the service starts', () async {
    final confirmed = await log('W1AW', at: 3000, lotw: true);
    final runnerUp = await log('W1AW', at: 1000);
    await qsos.softDelete(confirmed);
    settings.built = {'calls': 1};
    await claims.applyUpgrades([heldClaim('W1AW', qso: runnerUp.uuid, level: ClaimLevel.worked)]);
    service.listen();

    await claims.mergeFromSync([heldClaim('W1AW', qso: confirmed.uuid, epoch: 9).toRecord()]);
    await Future<void>.delayed(Duration.zero);
    service.start();
    await settle();
    expect(await checklist(), {'W1AW': (ClaimLevel.worked, runnerUp.uuid)});
  });

  // Epochs only rank rows within one history. A device that linked an
  // account and stopped syncing before its backfill finished holds part of
  // that history, and a rebuild from it would withdraw the rest.
  test('only a device that finished its backfill, or never linked an account, holds the whole log', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    await prefs.setSyncEnabled(false);
    expect(deviceHoldsWholeLog(prefs), isTrue, reason: 'a log that never left this device is all there is');

    await prefs.setSyncState({'lastSyncAccountUUID': 'acct-1'});
    expect(deviceHoldsWholeLog(prefs), isFalse, reason: 'sync off after a partial backfill');
    await prefs.setSyncEnabled(true);
    expect(deviceHoldsWholeLog(prefs), isFalse);

    await prefs.setSyncState({'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true});
    expect(deviceHoldsWholeLog(prefs), isTrue);
    await prefs.setSyncEnabled(false);
    expect(deviceHoldsWholeLog(prefs), isTrue);
  });

  // "No programs" read from a runtime that could not answer would forget every
  // program's bookkeeping and drop the changes in hand, for the rest of the
  // runtime: the answer is kept per runtime.
  test('a runtime that cannot list the programs holds the changes until one can', () async {
    service.start();
    await settle();
    listingFails = true;
    extensions.runtimeGeneration.value++;
    final first = await log('K1ABC');
    await settle();
    expect(settings.built, {'calls': 1}, reason: 'nothing says a program went away');
    expect(settings.pending, isTrue);

    listingFails = false;
    final second = await log('N0CALL');
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, first.uuid), 'N0CALL': (ClaimLevel.worked, second.uuid)});
  });

  // The next runtime only refreshes programs whose version moved; nothing
  // else drains what the failed pass held. The contact would wait for an
  // unrelated write, and the Chasing view call its entity new meanwhile.
  test('changes held for a runtime that could not list the programs pass when the next runtime arrives', () async {
    service.start();
    await settle();
    listingFails = true;
    extensions.runtimeGeneration.value++;
    final logged = await log('K1ABC');
    await settle();
    expect(await checklist(), isEmpty);

    listingFails = false;
    extensions.runtimeGeneration.value++;
    await settle();
    expect(await checklist(), {'K1ABC': (ClaimLevel.worked, logged.uuid)});
    expect(settings.pending, isFalse);
  });

  // Deleting a slot's only holder is undone by the rescan that follows. A
  // quit during it, with the marker already cleared and the built version
  // still matching, leaves the slot to a deleted contact for good.
  test('the pending marker stays set until the rescan that lowers a slot is done', () async {
    final gone = await log('W1AW');
    await log('K1ABC');
    service.start();
    await settle();
    final pendingWhileAsked = <bool>[];
    final answer = stubs['chasing:calls:claimsForQsos']! as Object? Function(Object?);
    stubs['chasing:calls:claimsForQsos'] = (Object? args) {
      pendingWhileAsked.add(settings.pending);
      return answer(args);
    };

    await qsos.softDelete(gone);
    await settle();
    expect(pendingWhileAsked, isNotEmpty);
    expect(pendingWhileAsked.last, isTrue);
    expect(settings.pending, isFalse);
  });

  // A rebuild keeps rows it cannot judge, at whatever version they carry; a
  // launch that read them as owed a rebuild would rescan the whole log every
  // time.
  test('rows a rebuild could not judge ask for no rebuild on the next launch', () async {
    await log('W1AW');
    await log('BAD');
    final working = stubs['chasing:calls:claimsForQsos']! as Object? Function(Object?);
    var malformed = false;
    stubs['chasing:calls:claimsForQsos'] = (Object? args) {
      final answer = (working(args)! as Map).cast<String, Object?>();
      final sent = ((args! as Map)['qsos'] as List).cast<Map<String, dynamic>>();
      return {
        for (final MapEntry(:key, :value) in answer.entries)
          if (!(malformed && sent.any((qso) => qso['uuid'] == key && (qso['their'] as Map)['call'] == 'BAD'))) key: value,
      };
    };
    service.start();
    await settle();

    malformed = true;
    version = 2;
    await withErrorHooks(() async {
      extensions.runtimeGeneration.value++;
      await settle();
    }, backend: FakeErrorReportingBackend());
    expect(settings.built, {'calls': 2});

    calls = 0;
    service.dispose();
    service = newService()..start();
    await settle();
    expect(calls, 0);
  });

  test('a row an older version computed elsewhere, from a contact here, is rebuilt when it arrives', () async {
    version = 2;
    final logged = await log('W1AW');
    service.start();
    await settle();

    await claims.mergeFromSync([heldClaim('W1AW', qso: logged.uuid, epoch: 9).toRecord()]);
    await settle();
    final row = (await claims.checklist('calls', 'ME')).single;
    expect([row.version, row.level], [2, ClaimLevel.worked]);
  });

  // Settings change on every sync round, chasing on or off.
  test('a settings change asks for no pass once there is nothing left to forget', () async {
    settings.enabled = false;
    service.start();
    await settle();
    final reads = settings.builtReads;

    for (var i = 0; i < 5; i++) {
      settings.set();
    }
    await settle();
    expect(settings.builtReads, reads);
  });

  // A restore can only raise slots, and a deletion lowers only what its own
  // contacts held: neither needs every program to read the whole log.
  test('deleting or restoring an operation asks only about its own contacts', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'startAtMillis': 1000,
    });
    for (final call in ['K1ABC', 'N0CALL', 'AA1A']) {
      await log(call);
    }
    service.start();
    await settle();

    await operations.softDelete(op.uuid);
    await settle();
    expect((await checklist()).keys, unorderedEquals(['K1ABC', 'N0CALL', 'AA1A']));

    asked = 0;
    await operations.undelete(op.uuid);
    await settle();
    expect((await checklist()).keys, contains('W1AW'));
    expect(asked, 1);
  });
}
