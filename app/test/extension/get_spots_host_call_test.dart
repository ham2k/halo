// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getSpots` hands an extension's panel the spots board. What it must never
// do is disagree with the operator's own Spots Panel while claiming to be
// that board — show a source they switched off, a band they are not on, a
// station on a continent they hid — or call a station worked that the panel
// shows as new. Nor may it do that work itself: it answers from inside panel
// renders and lookups, which can wait on neither a scorer pass nor a fan-out
// of lookups, so every verdict and continent it hands out is one the spot
// board already worked out. The scoring itself is the runtime's
// (scoreCandidates.test.ts).

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

class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board);

  final List<Map<String, dynamic>> board;

  /// Each scorer verdict, by the callsign it is about.
  final Map<String, Map<String, List<String>>> verdicts = {};
  final List<Map<String, Map<String, dynamic>>> scored = [];

  /// No scorer applies, so a pass answers nothing at all.
  bool noScorer = false;

  final Map<String, String> continents = {};
  final List<String> lookedUp = [];

  final ExtensionHost _host = FakeExtensionHost();

  @override
  ExtensionHost? get host => _host;

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async =>
      (items: board, succeeded: {for (final spot in board) spot['hookKey'] as String}.toList(), unreachable: const <String>[], failed: const <String>[]);

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
    scored.add(candidates);
    if (noScorer) return null;
    return {for (final entry in candidates.entries) entry.key: ?verdicts[(entry.value['their'] as Map)['call']]};
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
    return {
      'guess': {'continent': continents[call]},
    };
  }
}

Map<String, dynamic> _spot(String call, {required String band, required String mode, required double freq, String hookKey = 'pota', int ageMinutes = 5}) => {
  'their': {'call': call},
  'freq': freq,
  'band': band,
  'mode': mode,
  'refs': const <Map<String, dynamic>>[],
  'spot': {'timeInMillis': nowMillis() - ageMinutes * Duration.millisecondsPerMinute, 'source': hookKey},
  'hookKey': hookKey,
};

List<String?> _calls(Object? spots) => [for (final spot in spots! as List) ((spot as Map)['their'] as Map)['call'] as String?];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late _FakeExtensions extensions;
  late HaLoServices services;
  late SpotBoardSubscription view;

  /// Spots fetched and the board worked out over them, as an open Operation
  /// View keeps it.
  Future<void> boot(List<Map<String, dynamic>> board, {Map<String, dynamic> filters = const {}, Map<String, String> continents = const {}}) async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', ...filters});
    extensions = _FakeExtensions(board)..continents.addAll(continents);
    db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    services = HaLoServices(db, settings, extensions: extensions);
    view = services.spotBoard.subscribe();
    addTearDown(view.cancel);
    await services.spots.refresh();
    await services.spotBoard.refreshCallInfo();
  }

  /// The board judging a fresh operation, with its first pass landed.
  Future<Operation> showOperation() async {
    final operation = await services.operations.create(stationCall: 'N0DEV');
    view.show(operation, const [], logRevision: 'r0');
    await pumpEventQueue();
    return operation;
  }

  Future<Object?> getSpots([Map<String, dynamic> params = const {}]) => extensions.debugHandleHostCall('getSpots', params);

  final board = [
    _spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0, ageMinutes: 4),
    // The same activator reported by a second source: one row on the panel.
    _spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.2, hookKey: 'sota', ageMinutes: 3),
    _spot('W1AW', band: '40m', mode: 'CW', freq: 7030.0, ageMinutes: 2),
    _spot('N0XYZ', band: '20m', mode: 'FT8', freq: 14074.0, hookKey: 'rbn', ageMinutes: 1),
  ];

  test('by default it is the operator\'s board: their sources and band, merged as the panel merges', () async {
    await boot(
      board,
      filters: {
        'bandFilter': '20m',
        'disabledSources': ['rbn'],
      },
    );
    expect(_calls(await getSpots()), ['K1ABC']);
  });

  test('an "auto" band follows the radio, as the panel\'s does', () async {
    await boot(board, filters: {'bandFilter': 'auto'});
    services.radio.setVfo('vfoA', band: '40m');
    expect(_calls(await getSpots()), ['W1AW']);
  });

  test("'all' is every held spot, unmerged and newest first, whatever the operator filters", () async {
    await boot(
      board,
      filters: {
        'bandFilter': '20m',
        'disabledSources': ['rbn'],
      },
    );
    expect(_calls(await getSpots({'filter': 'all'})), ['N0XYZ', 'W1AW', 'K1ABC', 'K1ABC']);
  });

  test('the caller\'s options narrow the board further', () async {
    await boot(board);
    expect(_calls(await getSpots({'filter': 'all', 'source': 'pota', 'mode': 'CW'})), ['W1AW']);
    expect(_calls(await getSpots({'mode': 'Phone'})), ['K1ABC']);
  });

  // A merged spot keeps one report's hookKey: filtered after the merge, the
  // station both sources spotted would vanish from the answer for one of them.
  test('source narrows before the merge, so a station two sources spotted answers to either', () async {
    await boot(board);
    expect(_calls(await getSpots({'source': 'sota'})), ['K1ABC']);
    expect(_calls(await getSpots({'source': 'pota', 'band': '20m'})), ['K1ABC']);
  });

  test('a hidden continent hides its stations', () async {
    await boot(
      [_spot('DL1ABC', band: '20m', mode: 'SSB', freq: 14200.0), _spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0)],
      filters: {
        'disabledContinents': ['EU'],
      },
      continents: {'DL1ABC': 'EU', 'K1ABC': 'NA'},
    );
    expect(_calls(await getSpots()), ['K1ABC']);
  });

  // A panel render has a few seconds to answer, and a lookup hook calling
  // getSpots would otherwise re-enter the lookup pipeline once per spotted
  // call — each of those lookups free to call getSpots again.
  test('answering never runs a lookup or a scoring pass', () async {
    await boot(
      board,
      filters: {
        'disabledContinents': ['EU'],
      },
    );
    final operation = await showOperation();
    final lookups = extensions.lookedUp.length;
    final passes = extensions.scored.length;

    await getSpots();
    await getSpots({'filter': 'all', 'operationUuid': operation.uuid});

    expect(extensions.lookedUp, hasLength(lookups));
    expect(extensions.scored, hasLength(passes));
  });

  group('annotations', () {
    test('judge each spot against the open operation\'s log, as the panel strikes and accents it', () async {
      await boot([
        _spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0),
        _spot('W1AW', band: '20m', mode: 'SSB', freq: 14260.0),
        _spot('N0DEV', band: '20m', mode: 'SSB', freq: 14270.0),
      ]);
      extensions.verdicts
        ..['K1ABC'] = {
          'notices': [],
          'alerts': ['duplicate'],
        }
        ..['W1AW'] = {
          'notices': ['newBand'],
          'alerts': [],
        };
      final operation = await showOperation();

      final spots = (await getSpots({'operationUuid': operation.uuid}) as List).cast<Map<String, dynamic>>();
      final byCall = {for (final spot in spots) (spot['their'] as Map)['call']: spot['annotations'] as Map};

      expect(byCall['K1ABC'], {'worked': true, 'isSelf': false, 'notices': <String>[]});
      expect(byCall['W1AW'], {
        'worked': false,
        'isSelf': false,
        'notices': ['newBand'],
      });
      expect(byCall['N0DEV']?['isSelf'], isTrue);
      // The cache is shared with the Spots Panel and every other reader: one
      // operation's verdicts written into it would show on another's board.
      // 'all' is the board that hands out the cache's own maps — the default
      // one is built of merged copies, and would pass this either way.
      await getSpots({'filter': 'all', 'operationUuid': operation.uuid});
      for (final list in services.spots.spotsBySource.values) {
        for (final spot in list) {
          expect(spot.containsKey('annotations'), isFalse);
        }
      }
    });

    // A lookup reading the board once has no repaint to correct it, so
    // "worked: false" before any verdict would be read as a verdict.
    test('wait for a verdict: none are made before the board has judged the operation', () async {
      await boot([_spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0)]);
      extensions.noScorer = true;
      final operation = await showOperation();
      final spots = await getSpots({'operationUuid': operation.uuid}) as List;
      expect((spots.single as Map).containsKey('annotations'), isFalse);
    });

    test('a spot no scorer answered for is never called worked', () async {
      await boot([_spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0)]);
      final operation = await showOperation();
      final spots = await getSpots({'operationUuid': operation.uuid}) as List;
      expect(((spots.single as Map)['annotations'] as Map)['worked'], isFalse);
    });

    test('are not made without the open operation, nor when the caller declines them', () async {
      await boot([_spot('K1ABC', band: '20m', mode: 'SSB', freq: 14250.0)]);
      final operation = await showOperation();
      final other = await services.operations.create(stationCall: 'N0DEV');

      for (final params in <Map<String, dynamic>>[
        {},
        {'operationUuid': operation.uuid, 'annotate': false},
        // Judged against the operation on screen, these would be that
        // operation's verdicts under another's name.
        {'operationUuid': other.uuid},
      ]) {
        final spots = await getSpots(params) as List;
        expect((spots.single as Map).containsKey('annotations'), isFalse, reason: '$params');
      }
    });
  });

  test('a malformed option rejects the call rather than answering the whole board', () async {
    await boot(board);
    expect(() => getSpots({'bands': '20m'}), throwsFormatException);
  });

  test('a host with nothing wired answers an empty board, but still rejects a malformed option', () async {
    final bare = ExtensionService();
    expect(await bare.debugHandleHostCall('getSpots', const {}), isEmpty);
    expect(() => bare.debugHandleHostCall('getSpots', const {'bands': '20m'}), throwsFormatException);
  });
}
