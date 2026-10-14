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

  @override
  ExtensionHost? get host => _host;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async => (
    items: [
      _spot('K1ABC', hookKey: 'pota'),
      _spot('W1AW', hookKey: 'sota'),
    ],
    succeeded: const ['pota', 'sota'],
    unreachable: const <String>[],
    failed: const <String>[],
  );

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
      for (final key in candidates.keys)
        key: {
          'notices': const <String>[],
          'alerts': const ['duplicate'],
        },
    };
  }

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
  }) async {
    lookedUp.add(call);
    if (unanswered.contains(call)) return null;
    return {'guess': <String, dynamic>{}};
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _FakeExtensions extensions;
  late HaLoServices services;
  late SpotBoardSubscription view;

  /// Called inside each test rather than from setUp: the board's scoring
  /// debounce is a timer, and a test can only drive it on a fake clock if
  /// everything that arms it was built inside that clock's zone.
  Future<void> openBoard() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    extensions = _FakeExtensions();
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    services = HaLoServices(db, settings, extensions: extensions);
    view = services.spotBoard.subscribe();
    addTearDown(view.cancel);
    await services.spots.refresh();
    await pumpEventQueue();
  }

  /// A fresh operation shown, its pass landed and nothing left pending.
  Future<Operation> show({String logRevision = 'r0'}) async {
    final operation = await services.operations.create(stationCall: 'N0DEV');
    view.show(operation, const [], logRevision: logRevision);
    await Future<void>.delayed(_debounce);
    return operation;
  }

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
      await pumpEventQueue();
      expect(services.spotBoard.callInfo.containsKey('K1ABC'), isFalse);
      extensions.unanswered.clear();
      await services.spots.refresh();
      await pumpEventQueue();
      expect(services.spotBoard.callInfo.containsKey('K1ABC'), isTrue);
    }),
  );

  test(
    'each spotted call is looked up once, however often the spots refresh',
    () => runOnFakeClock((_) async {
      await openBoard();
      await services.spots.refresh();
      await pumpEventQueue();
      expect(extensions.lookedUp..sort(), ['K1ABC', 'W1AW']);
    }),
  );
}
