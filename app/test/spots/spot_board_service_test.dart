// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spot board works out once what the Spots Panel and every extension
// panel show about spots. Its traps are both directions of "when": a board
// that misses a change leaves an extension panel showing the 20m board after
// the radio moved to 40m, or a station struck after the log was edited; one
// that fires on everything re-renders every panel on every CAT frequency tick
// and every unrelated settings write.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_scoring.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spot_board.dart' show spotCandidateKey;
import 'package:ham2k_logger/services/spot_board_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_extension_host.dart';
import '../support/fake_clock.dart';

class _FakeExtensions extends ExtensionService {
  final List<Map<String, Map<String, dynamic>>> passes = [];
  final List<String> lookedUp = [];
  final ExtensionHost _host = FakeExtensionHost();

  /// While set, a scoring pass waits on it — a pass still in flight.
  Completer<void>? hold;

  /// Calls whose lookup answers null, as a runtime still booting does.
  final Set<String> unanswered = {};

  /// The calls scoring answers as duplicates; null for every one.
  Set<String>? duplicates;

  /// The chasing programs registered: none, unless a test registers some.
  Map<String, ChasingProgram> programs = const {};

  /// The state each call's lookup guesses.
  Map<String, String> states = const {};

  /// Each call's whole lookup guess, replacing the [states] one.
  Map<String, Object?> guesses = const {};

  /// The failure streaks the lookups were counted toward.
  final Set<String?> streakKeys = {};

  /// Every contact the programs were asked about.
  final List<Map<String, dynamic>> claimed = [];

  @override
  ExtensionHost? get host => _host;

  /// The spots every refresh reports; two stations unless a test sets more.
  List<Map<String, dynamic>> spotItems = [_spot('K1ABC', hookKey: 'pota'), _spot('W1AW', hookKey: 'sota')];

  /// How many times the spot sources were asked.
  int fetches = 0;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async {
    fetches++;
    return (items: spotItems, succeeded: const ['pota', 'sota'], unreachable: const <String>[], failed: const <String>[]);
  }

  @override
  Future<Map<String, Map<String, List<String>>>?> scoreCandidates({
    required Map<String, dynamic> operation,
    required String operationUuid,
    required Map<String, Map<String, dynamic>> candidates,
    List<Map<String, dynamic>>? segments,
    ScoringResume? resume,
    Future<Map<String, ScoringResume>> Function(List<Scorer> scorers)? resumesFor,
    Set<String> huntedRefTypes = const {},
  }) async {
    passes.add(candidates);
    await hold?.future;
    return {
      for (final MapEntry(:key, :value) in candidates.entries)
        key: {
          'notices': const <String>[],
          'alerts': [if (duplicates?.contains((value['their'] as Map)['call']) ?? true) 'duplicate'],
        },
    };
  }

  @override
  Future<Map<String, ChasingProgram>?> getChasingPrograms() async => programs;

  /// Every program's checklist is the calls worked, on any band and mode.
  @override
  Future<Map<String, List<QsoClaim>>?> claimsForQsos(String programKey, List<Map<String, dynamic>> qsos) async {
    claimed.addAll(qsos);
    return {
      for (final qso in qsos)
        qso['uuid'] as String: [QsoClaim(holder: 'ME', ref: (qso['their'] as Map)['call'] as String, band: null, mode: null, level: ClaimLevel.worked)],
    };
  }

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
    String? streakKey,
  }) async {
    lookedUp.add(call);
    streakKeys.add(streakKey);
    if (unanswered.contains(call)) return null;
    if (guesses.containsKey(call)) return {'guess': guesses[call]};
    return {
      'guess': <String, dynamic>{'state': ?states[call]},
    };
  }

  /// Every batch of calls looked up together, in the order asked.
  final List<List<String>> lookupBatches = [];

  /// While set, a batch waits on it — a lookup still out.
  Completer<void>? lookupHold;

  @override
  Future<List<Map<String, dynamic>?>> lookupCalls(
    List<({String call, Map<String, dynamic> qso})> requests, {
    required Map<String, dynamic> operation,
    bool online = true,
    required String streakKey,
  }) async {
    lookupBatches.add([for (final request in requests) request.call]);
    await lookupHold?.future;
    return [for (final request in requests) await lookupCall(request.call, qso: request.qso, operation: operation, online: online, streakKey: streakKey)];
  }
}

Map<String, dynamic> _spot(String call, {required String hookKey}) => {
  'their': {'call': call},
  'freq': 14250.0,
  'band': '20m',
  'mode': 'SSB',
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - 60000, 'source': hookKey},
  'hookKey': hookKey,
};

/// Longer than the board's scoring debounce.
const _debounce = Duration(milliseconds: 700);

/// Longer than the board waits before looking up a refresh's new calls.
const _lookupWait = Duration(milliseconds: 1600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _FakeExtensions extensions;
  late HaLoServices services;
  late SpotBoardSubscription view;

  /// Called inside each test rather than from setUp: the board's scoring
  /// debounce is a timer, and a test can only drive it on a fake clock if
  /// everything that arms it was built inside that clock's zone.
  Future<void> openBoard({Map<String, Object?> guesses = const {}, bool fetch = true}) async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    extensions = _FakeExtensions()..guesses = guesses;
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    services = HaLoServices(db, settings, extensions: extensions);
    view = services.spotBoard.subscribe();
    addTearDown(view.cancel);
    if (!fetch) return;
    await services.spots.refresh();
    await Future<void>.delayed(_lookupWait);
  }

  /// A fresh operation shown, its pass landed and nothing left pending.
  Future<Operation> show({String logRevision = 'r0'}) async {
    final operation = await services.operations.create(stationCall: 'N0DEV');
    view.show(operation, const [], logRevision: logRevision);
    await Future<void>.delayed(_debounce);
    return operation;
  }

  // An operation without assistance (`Operation.assistance`) calls no spot
  // hook. The board is what polls the sources, so the rule lives here: a
  // panel that merely hid the spots would still be fetching them.
  group('an operation without assistance', () {
    Future<Operation> create({bool assistance = true}) async {
      final operation = await services.operations.create(stationCall: 'N0DEV');
      return Operation(uuid: operation.uuid, data: {...operation.data, 'assistance': ?(assistance ? null : false)});
    }

    test('asks no spot source while it is shown, and the next operation that allows it does', () async {
      await openBoard(fetch: false);
      expect(extensions.fetches, 0, reason: 'nothing is shown yet, so nothing says spots are allowed');

      view.show(await create(assistance: false), const [], logRevision: 'r0');
      await pumpEventQueue();
      expect(extensions.fetches, 0);

      view.show(await create(), const [], logRevision: 'r0');
      await pumpEventQueue();
      expect(extensions.fetches, 1);
    });

    test('asks none when a contest ref rules assistance out', () async {
      await openBoard(fetch: false);
      final operation = await services.operations.create(stationCall: 'N0DEV');
      view.show(
        Operation(
          uuid: operation.uuid,
          data: {
            ...operation.data,
            'refs': [
              {'type': 'cqww', 'assistance': false},
            ],
          },
        ),
        const [],
        logRevision: 'r0',
      );
      await pumpEventQueue();
      expect(extensions.fetches, 0);
    });

    test(
      'stops the polling when the open operation is edited to rule it out',
      () => runOnFakeClock((_) async {
        await openBoard(fetch: false);
        final operation = await create();
        view.show(operation, const [], logRevision: 'r0');
        await Future<void>.delayed(Duration.zero);
        expect(extensions.fetches, 1);

        view.show(
          Operation(uuid: operation.uuid, data: {...operation.data, 'assistance': false}),
          const [],
          logRevision: 'r0',
        );
        await Future<void>.delayed(services.spots.refreshInterval * 3);
        expect(extensions.fetches, 1, reason: 'the refresh timer belongs to the subscription the board let go of');
      }),
    );
  });

  group('revision', () {
    test('moves with the radio\'s band and mode, not with every frequency it reports', () async {
      await openBoard();
      final board = services.spotBoard;
      services.radio.setVfo('vfoA', freq: 14074.0, mode: 'USB');
      final before = board.revision;
      services.radio.setVfo('vfoA', freq: 14075.5);
      expect(board.revision, before, reason: 'a CAT feed retuning within a band would re-render every spots panel');
      services.radio.setVfo('vfoA', freq: 7074.0);
      expect(board.revision, greaterThan(before), reason: "an 'auto' band filter now admits other spots");
      final afterBand = board.revision;
      services.radio.setVfo('vfoA', mode: 'CW');
      expect(board.revision, greaterThan(afterBand));
    });

    test('moves with the operator\'s spot filters, not with every settings write', () async {
      await openBoard();
      final board = services.spotBoard;
      final before = board.revision;
      await settings.setKeepDeviceAwake(true);
      expect(board.revision, before);
      await settings.setSpottingFilters({'bandFilter': '40m'});
      expect(board.revision, greaterThan(before));
    });
  });

  test(
    'a moved log is rescored; an unchanged one is not',
    () => runOnFakeClock((_) async {
      await openBoard();
      final operation = await show();
      final passes = extensions.passes.length;

      view.show(operation, const [], logRevision: 'r0');
      await Future<void>.delayed(_debounce);
      expect(extensions.passes, hasLength(passes));

      view.show(operation, const [], logRevision: 'r1');
      await Future<void>.delayed(_debounce);
      expect(extensions.passes, hasLength(passes + 1));
    }),
  );

  // Which sources are on decides which reports merge, so which questions the
  // scorers are asked: a spot only one source carried would otherwise stay
  // unscored until the next refresh.
  test(
    'switching a source off rescores the board',
    () => runOnFakeClock((_) async {
      await openBoard();
      await show();
      final passes = extensions.passes.length;
      await settings.setSpottingFilters({
        'disabledSources': ['sota'],
      });
      await Future<void>.delayed(_debounce);
      expect(extensions.passes, hasLength(passes + 1));
    }),
  );

  test(
    'one operation\'s verdicts are never served for another',
    () => runOnFakeClock((_) async {
      await openBoard();
      final first = await show();
      expect(services.spotBoard.scoresFor(first.uuid), isNotEmpty);
      await show();
      expect(services.spotBoard.scoresFor(first.uuid), isNull);
    }),
  );

  // Operation Views stack: ⌘K and deep links push one over another.
  group('stacked viewers', () {
    late SpotBoardSubscription covered;
    late Operation a;
    late Operation b;

    Future<void> stack() async {
      await openBoard();
      a = await services.operations.create(stationCall: 'N0DEV');
      b = await services.operations.create(stationCall: 'N0DEV');
      view.show(a, const [], logRevision: 'r0');
      await Future<void>.delayed(_debounce);
      covered = view;
      view = services.spotBoard.subscribe();
      addTearDown(view.cancel);
      view.show(b, const [], logRevision: 'r0');
      await Future<void>.delayed(_debounce);
    }

    test(
      'the view on top decides, whatever the one beneath it writes',
      () => runOnFakeClock((_) async {
        await stack();
        covered.show(a, const [], logRevision: 'r1');
        await Future<void>.delayed(_debounce);
        expect(services.spotBoard.operation?.uuid, b.uuid);
        expect(services.spotBoard.scoresFor(b.uuid), isNotEmpty, reason: 'a sync write to a covered operation must not take the board');
      }),
    );

    // A covered view's Spots Panel mounts on a delay, after the view in front
    // has subscribed; landing on top, it would judge an operation nobody sees.
    test(
      'a covered view\'s panel subscribing late does not take the board',
      () => runOnFakeClock((_) async {
        await stack();
        final panel = services.spotBoard.subscribe(follower: true);
        addTearDown(panel.cancel);
        panel.show(a, const [], logRevision: 'r0');
        await Future<void>.delayed(_debounce);
        expect(services.spotBoard.operation?.uuid, b.uuid);
        expect(services.spotBoard.scoresFor(b.uuid), isNotEmpty);
      }),
    );

    test(
      'closing the top view hands the board back, judged at once',
      () => runOnFakeClock((_) async {
        await stack();
        view.cancel();
        await pumpEventQueue();
        expect(services.spotBoard.operation?.uuid, a.uuid);
        expect(services.spotBoard.scoresFor(a.uuid), isNotEmpty, reason: 'without it the operation underneath shows no strikes until its log moves');
      }),
    );
  });

  test(
    'switching operation while a pass is in flight still scores the new one',
    () => runOnFakeClock((_) async {
      await openBoard();
      final first = await services.operations.create(stationCall: 'N0DEV');
      final second = await services.operations.create(stationCall: 'N0DEV');
      extensions.hold = Completer<void>();
      view.show(first, const [], logRevision: 'r0');
      await pumpEventQueue();
      view.show(second, const [], logRevision: 'r0');
      await pumpEventQueue();
      extensions.hold!.complete();
      await pumpEventQueue();
      expect(services.spotBoard.scoresFor(second.uuid), isNotEmpty);
    }),
  );

  // Null is no answer — a runtime still booting, a lookup timed out.
  // Cached, the call would keep no note or emoji for the rest of the session.
  test(
    'a call whose lookup did not answer is asked again on the next refresh',
    () => runOnFakeClock((_) async {
      await openBoard();
      // Released by everyone, the board forgets what it knew.
      view.cancel();
      extensions.unanswered.add('K1ABC');
      view = services.spotBoard.subscribe();
      addTearDown(view.cancel);
      await services.spots.refresh();
      await Future<void>.delayed(_lookupWait);
      expect(services.spotBoard.callInfo.containsKey('K1ABC'), isFalse);
      extensions.unanswered.clear();
      await services.spots.refresh();
      await Future<void>.delayed(_lookupWait);
      expect(services.spotBoard.callInfo.containsKey('K1ABC'), isTrue);
    }),
  );

  // Lookup guesses come from extensions, so no field's type is guaranteed. A
  // cast on one call's answer throws for the whole batch: no call on the
  // board gets its emoji, continent or entity, and every refresh throws again.
  test(
    'a wrong-typed lookup field reads as absent, and costs no other call its info',
    () => runOnFakeClock((_) async {
      await openBoard(
        guesses: {
          'K1ABC': <String, dynamic>{'emoji': true, 'note': 42, 'continent': 4, 'entityPrefix': 291},
          'W1AW': <dynamic, dynamic>{'emoji': '🎉', 'continent': 'NA', 'entityPrefix': 'K'},
        },
      );

      final info = services.spotBoard.callInfo;
      expect(info['K1ABC'], (hasNote: false, emoji: null, continent: null, entityPrefix: null));
      expect(info['W1AW'], (hasNote: true, emoji: '🎉', continent: 'NA', entityPrefix: 'K'));
    }),
  );

  // The board marks a call as noted, and the call-info area shows that note;
  // a mark with nothing behind it sends the operator to look for a note that
  // is not there.
  test(
    'an empty note does not mark the call as noted',
    () => runOnFakeClock((_) async {
      await openBoard(
        guesses: {
          'K1ABC': <String, dynamic>{'note': ''},
        },
      );
      expect(services.spotBoard.callInfo['K1ABC']?.hasNote, isFalse);
    }),
  );

  test(
    'a lookup whose guess is not a map knows nothing about the call',
    () => runOnFakeClock((_) async {
      await openBoard(guesses: {'K1ABC': 'DL'});

      expect(services.spotBoard.callInfo['K1ABC'], (hasNote: false, emoji: null, continent: null, entityPrefix: null));
      expect(services.spotBoard.callInfo, contains('W1AW'));
    }),
  );

  test(
    'each spotted call is looked up once, however often the spots refresh',
    () => runOnFakeClock((_) async {
      await openBoard();
      await services.spots.refresh();
      await Future<void>.delayed(_lookupWait);
      expect(extensions.lookedUp..sort(), ['K1ABC', 'W1AW']);
    }),
  );

  // A contest cluster changes the board several times a second, and each
  // call's lookup reads the database. Asked once per change, per call and all
  // at once, those reads queue for seconds — long enough that every other
  // reader of the database, the activity search's nearby parks among them,
  // times out behind the board.
  group('lookups under a busy cluster', () {
    List<Map<String, dynamic>> board(int count) => [for (var i = 0; i < count; i++) _spot('N${i}XYZ', hookKey: 'pota')];

    test(
      'a board of many calls is looked up in small batches, one at a time',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.spotItems = board(45);
        extensions.lookupBatches.clear();
        extensions.lookupHold = Completer<void>();
        await services.spots.refresh();
        await Future<void>.delayed(_lookupWait);
        expect(extensions.lookupBatches, hasLength(1), reason: 'the next batch waits for this one to answer');
        expect(extensions.lookupBatches.single, hasLength(spotLookupBatchSize));

        extensions.lookupHold!.complete();
        extensions.lookupHold = null;
        await pumpEventQueue();
        expect([for (final batch in extensions.lookupBatches) batch.length], [20, 20, 5]);
        expect(services.spotBoard.callInfo.keys, containsAll([for (var i = 0; i < 45; i++) 'N${i}XYZ']));
      }),
    );

    // A call too short to be a callsign is never answered, so asked it holds a
    // batch's place, and a batch of them answers nothing and stops the pass —
    // every pass, since nothing caches them.
    test(
      'a call too short to be a callsign is not asked',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.spotItems = [_spot('K1', hookKey: 'pota'), _spot('N0XYZ', hookKey: 'pota')];
        extensions.lookedUp.clear();
        await services.spots.refresh();
        await Future<void>.delayed(_lookupWait);
        expect(extensions.lookedUp, ['N0XYZ']);
      }),
    );

    // On a stalled runtime, every batch after one that answered nothing
    // queues behind it for its whole timeout, one after another.
    test(
      'a pass stops at a batch that answered nothing, and the next refresh asks again',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.spotItems = board(45);
        extensions.unanswered.addAll([for (var i = 0; i < 45; i++) 'N${i}XYZ']);
        extensions.lookupBatches.clear();
        await services.spots.refresh();
        await Future<void>.delayed(_lookupWait);
        expect(extensions.lookupBatches, hasLength(1));

        extensions.unanswered.clear();
        await services.spots.refresh();
        await Future<void>.delayed(_lookupWait);
        expect([for (final batch in extensions.lookupBatches) batch.length], [20, 20, 20, 5]);
      }),
    );

    test(
      'a burst of changes is looked up once, and a call still out is not asked for again',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.spotItems = board(3);
        extensions.lookedUp.clear();
        extensions.lookupHold = Completer<void>();
        for (var i = 0; i < 5; i++) {
          await services.spots.refresh();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await Future<void>.delayed(_lookupWait);
        // Changes keep landing while the lookup is out.
        for (var i = 0; i < 3; i++) {
          await services.spots.refresh();
          await Future<void>.delayed(_lookupWait);
        }
        extensions.lookupHold!.complete();
        await pumpEventQueue();
        expect(extensions.lookedUp..sort(), ['N0XYZ', 'N1XYZ', 'N2XYZ']);
      }),
    );
  });

  group('chasing', () {
    final callsProgram = {'calls': const ChasingProgram(key: 'calls', label: 'Calls', version: 1, editions: ChasingEditions.lifetime)};
    String keyOf(String call) => spotCandidateKey(call, _spot(call, hookKey: 'pota'));
    List<ChaseVerdict> verdictsOf(SpotScore? score) => [for (final key in score?.notices ?? const <String>[]) ?ChaseNotice.tryParse(key)?.verdict];

    /// The Chasing view's board: its stand-in operation, shown as chasing.
    Future<void> chase() async {
      await openBoard();
      extensions.programs = callsProgram;
      // Programs are asked for once per runtime: registering one is a new one.
      extensions.runtimeGeneration.value++;
      extensions.duplicates = {'W1AW'};
      view.show(
        Operation(uuid: '', data: const {'stationCall': 'ME'}),
        const [],
        logRevision: 'r0',
        chasing: true,
      );
      await Future<void>.delayed(_debounce);
      await pumpEventQueue();
    }

    // The Chasing view ranks by what the checklist lacks; the period's own
    // scoring only says what was already worked today.
    test(
      'a station the checklist lacks carries its verdict, and one worked this period stays struck with none',
      () => runOnFakeClock((_) async {
        await chase();
        final scores = services.spotBoard.scoresFor('')!;
        expect(verdictsOf(scores[keyOf('K1ABC')]), [ChaseVerdict.newRef]);
        expect(scores[keyOf('K1ABC')]!.alerts, isEmpty);
        expect(scores[keyOf('W1AW')]!.notices, isEmpty, reason: 'a notice beside the dupe would un-strike it');
        expect(scores[keyOf('W1AW')]!.alerts, ['duplicate']);
      }),
    );

    // Logging the station fills its slot; the spot must stop reading "new"
    // then, not at the next spots refresh or scoring pass.
    test(
      'a slot filled re-judges the board, without a scoring pass',
      () => runOnFakeClock((_) async {
        await chase();
        final passes = extensions.passes.length;
        await services.claims.applyUpgrades([
          StoredClaim.fromQso(
            program: 'calls',
            version: 1,
            claim: const QsoClaim(holder: 'ME', ref: 'K1ABC', band: null, mode: null, level: ClaimLevel.worked),
            qso: 'q1',
            atMillis: 1,
          ),
        ]);
        await Future<void>.delayed(const Duration(seconds: 1));
        await pumpEventQueue();
        expect(verdictsOf(services.spotBoard.scoresFor('')![keyOf('K1ABC')]), [ChaseVerdict.unconfirmed]);
        expect(extensions.passes, hasLength(passes));
      }),
    );

    test(
      'an operation reads its own scoring, with chasing notices only under EXP CHASE and only those alerting',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.programs = callsProgram;
        extensions.runtimeGeneration.value++;
        extensions.duplicates = const {};
        final operation = await show();
        expect(verdictsOf(services.spotBoard.scoresFor(operation.uuid)![keyOf('K1ABC')]), isEmpty);
        await settings.setExperimentEnabled('chase', true);
        view.show(operation, const [], logRevision: 'r1');
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        expect(verdictsOf(services.spotBoard.scoresFor(operation.uuid)![keyOf('K1ABC')]), [ChaseVerdict.newRef]);
      }),
    );

    // The new operation's scores land before its judging does. Merged with
    // the verdicts judged for the Chasing view's station, its spots would
    // read new to a checklist the operation is not chasing, if only briefly.
    test(
      'an operation shown after the Chasing view never carries the Chasing view\'s verdicts',
      () => runOnFakeClock((_) async {
        await chase();
        expect(verdictsOf(services.spotBoard.scoresFor('')![keyOf('K1ABC')]), [ChaseVerdict.newRef]);
        final operation = await services.operations.create(stationCall: 'N0DEV');
        final seen = <List<ChaseVerdict>>[];
        void record() => seen.add(verdictsOf(services.spotBoard.scoresFor(operation.uuid)?[keyOf('K1ABC')]));
        services.spotBoard.addListener(record);
        addTearDown(() => services.spotBoard.removeListener(record));
        view.show(operation, const [], logRevision: 'r0');
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        expect(seen, isNotEmpty);
        expect(seen.expand((verdicts) => verdicts), isEmpty);
      }),
    );

    // A spot carries no state of its own: without the lookup's guess, a
    // program that chases states (WAS) judges no spot at all. And without
    // the station's place, one that keeps a checklist per place judges every
    // spot against the bare call's. A multi-call operation's whole field is
    // no callsign: a holder built from it is one no logged contact claims
    // under, and every spot would read new.
    test(
      "a candidate carries its lookup's state as a guess, and the station's first call and place",
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.programs = callsProgram;
        extensions.runtimeGeneration.value++;
        extensions.states = {'K1ABC': 'CT'};
        view.show(
          Operation(uuid: '', data: const {'stationCall': 'ME, YOU', 'grid': 'FN31pr'}),
          const [],
          logRevision: 'r0',
          chasing: true,
        );
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        Map<String, dynamic> askedAbout(String call) => extensions.claimed.lastWhere((qso) => (qso['their'] as Map)['call'] == call);
        expect((askedAbout('K1ABC')['their'] as Map)['guess'], {'state': 'CT'});
        expect((askedAbout('W1AW')['their'] as Map).containsKey('guess'), isFalse, reason: 'a lookup that knew no state adds none');
        expect(askedAbout('K1ABC')['our'], {'call': 'ME', 'grid': 'FN31pr'});
      }),
    );

    // A lookup that knew no state may have answered before the parks list
    // downloaded, or while a hook was failing: cached for the session, that
    // spot would never be judged for a state. Asked on every refresh, each
    // of a board's hundreds of DX stations, which no lookup will ever place,
    // is a crossing into the runtime per pass. And a restarted runtime may
    // answer differently from the one that filled the cache.
    test(
      'a lookup that knew no state is asked again after a while, not on every refresh, and a restarted runtime is asked about every spot',
      () => runOnFakeClock((async) async {
        await openBoard();
        extensions.programs = callsProgram;
        extensions.runtimeGeneration.value++;
        view.show(
          Operation(uuid: '', data: const {'stationCall': 'ME'}),
          const [],
          logRevision: 'r0',
          chasing: true,
        );
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        Object? guessFor(String call) => (extensions.claimed.lastWhere((qso) => (qso['their'] as Map)['call'] == call)['their'] as Map)['guess'];
        expect(guessFor('W1AW'), isNull);

        extensions.states = {'W1AW': 'NY'};
        await services.spots.refresh();
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        expect(guessFor('W1AW'), isNull, reason: 'a refresh right away does not ask again');

        async.elapseBlocking(const Duration(minutes: 5));
        await services.spots.refresh();
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        expect(guessFor('W1AW'), {'state': 'NY'});

        extensions.states = {'W1AW': 'NJ'};
        extensions.runtimeGeneration.value++;
        await services.spots.refresh();
        await Future<void>.delayed(_debounce);
        await pumpEventQueue();
        expect(guessFor('W1AW'), {'state': 'NJ'}, reason: 'a state is kept across spot refreshes only until the runtime restarts');
        expect(extensions.streakKeys, {'extensions:lookup-call:spot-board'}, reason: "the board's lookups are not the operator's");
      }),
    );

    // Claims sync with chasing off too, and every write tells the chase
    // service. A board with nothing judged has nothing to rebuild for it.
    test(
      'with chasing off, a write to the checklists leaves the board alone',
      () => runOnFakeClock((_) async {
        await openBoard();
        extensions.programs = callsProgram;
        extensions.runtimeGeneration.value++;
        await show();
        var told = 0;
        void count() => told++;
        services.spotBoard.addListener(count);
        addTearDown(() => services.spotBoard.removeListener(count));
        await services.claims.applyUpgrades([
          StoredClaim.fromQso(
            program: 'calls',
            version: 1,
            claim: const QsoClaim(holder: 'ME', ref: 'K1ABC', band: null, mode: null, level: ClaimLevel.worked),
            qso: 'q1',
            atMillis: 1,
          ),
        ]);
        await Future<void>.delayed(const Duration(seconds: 1));
        await pumpEventQueue();
        expect(told, 0);
      }),
    );
  });
}
