// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/operation_setup_service.dart';

import '../support/fake_extension_host.dart';

Map<String, dynamic> _activity(String key, String type, {bool allowsMultiple = false, String? pattern}) => {
  'key': key,
  'ok': true,
  'value': [
    {
      'key': '$key/activation',
      'allowsMultiple': allowsMultiple,
      'input': {'kind': 'refList', 'refType': type, 'pattern': ?pattern},
    },
  ],
};

Object _parkValidation(Object? args) {
  final raw = (args as Map)['ref']['ref'] as String;
  final match = RegExp(r'^(?:US-)?([0-9]{1,4})$', caseSensitive: false).firstMatch(raw.trim());
  return {if (match != null) 'normalized': 'US-${match[1]!.padLeft(4, '0')}', 'valid': match != null};
}

Object _forestValidation(Object? args) {
  final raw = (args as Map)['ref']['ref'] as String;
  final normalized = raw.trim().toUpperCase();
  return {'valid': RegExp(r'^KFF-[0-9]{4}$').hasMatch(normalized), 'normalized': normalized};
}

Object _decoratePark(Object? args) => {...((args as Map)['ref'] as Map), 'name': 'Park', 'lat': 41.2, 'lon': -73.8};
Object _decorateForest(Object? args) => {...((args as Map)['ref'] as Map), 'name': 'Forest'};

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late OperationSetupService setup;
  late List<Operation> saves;
  late Map<String, Object?> hooks;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    saves = [];
    operations = OperationsRepository(db, onLocalSave: (_, saved) async => saves.add(saved));
    hooks = {
      'activity:*:operationControls': [_activity('ham2k-pota', 'potaActivation', allowsMultiple: true), _activity('ham2k-wwff', 'wwffActivation')],
      'ref:potaActivation:null:validateRef': _parkValidation,
      'ref:potaActivation:null:decorateRef': _decoratePark,
      'ref:wwffActivation:null:validateRef': _forestValidation,
      'ref:wwffActivation:null:decorateRef': _decorateForest,
    };
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost(hooks));
    setup = OperationSetupService(operations: operations, extensions: extensions);
  });

  tearDown(() => db.close());

  test('a preset adds overlapping references once and saves the stated location with them', () async {
    const contest = {'type': 'contest', 'exchange': 'ABC', 'assistance': false};
    const existingPark = {'type': 'potaActivation', 'ref': 'US-0012', 'name': 'Operator label', 'selfSpotting': false};
    final op = await operations.createFromData({
      'stationCall': 'KI2D',
      'userTitle': 'Previous title',
      'notes': 'Bring the low antenna',
      'refs': [contest, existingPark],
      'grid': 'FN31',
      'gridSource': refsGridSource,
      'lat': 41.2,
      'lon': -73.8,
    });
    const patch = {
      'addActivationRefs': [
        {'activityKey': 'POTA', 'ref': '12'},
        {'activityKey': 'ham2k-pota', 'ref': ' 34 '},
        {'activityKey': 'pota', 'ref': 'us-0034'},
        {'activityKey': 'wwff', 'ref': 'kff-0042'},
      ],
      'location': {'grid': 'FM18ab', 'state': 'VA', 'county': 'Arlington'},
      'userTitle': 'North Trailhead',
    };

    expect(await setup.apply(op.uuid, patch), isNull);
    final updated = (await operations.get(op.uuid))!;
    expect(updated.refs, [
      contest,
      existingPark,
      {'type': 'potaActivation', 'ref': 'US-0034', 'name': 'Park', 'lat': 41.2, 'lon': -73.8},
      {'type': 'wwffActivation', 'ref': 'KFF-0042', 'name': 'Forest'},
    ]);
    expect(updated.userTitle, 'North Trailhead');
    expect(updated.data['notes'], 'Bring the low antenna');
    expect(updated.data['state'], 'VA');
    expect(updated.data['county'], 'Arlington');
    expect(updated.grid?.toUpperCase(), 'FM18AB');
    expect(updated.exactLocation, locationForStatedGrid('FM18ab'));
    expect(saves.single.refs, updated.refs);
    expect(saves.single.location, updated.location);

    expect(await setup.apply(op.uuid, patch), isNull);
    expect((await operations.get(op.uuid))!.refs, updated.refs);
    expect(saves, hasLength(1), reason: 'reapplying a preset does not dirty the operation for sync');
  });

  for (final (reason, key, code) in [
    ('an invalid code', 'pota', 'NOT-A-PARK'),
    ('an unavailable program', 'uninstalled', 'XY-0001'),
    ('a conflicting single-reference activity', 'wwff', 'KFF-0002'),
  ]) {
    test('$reason leaves every operation field as it was', () async {
      final op = await operations.createFromData({
        'stationCall': 'KI2D',
        'notes': 'Before',
        'refs': [
          {'type': 'wwffActivation', 'ref': 'KFF-0001', 'name': 'Original forest'},
        ],
      });
      final before = (await operations.get(op.uuid))!;
      final result = await setup.apply(op.uuid, {
        'addActivationRefs': [
          {'activityKey': 'pota', 'ref': '12'},
          {'activityKey': key, 'ref': code},
        ],
        'location': {'grid': 'FM18ab'},
        'userTitle': 'After',
        'notes': 'After',
        'operatorCall': 'W1AW',
        'multiIdentifier': '2',
      });

      expect(result?.failed, isTrue);
      expect(result?.text, contains(code));
      final after = (await operations.get(op.uuid))!;
      expect(after.data, before.data);
      expect(after.localData, before.localData);
      expect(saves, isEmpty);
    });
  }

  test('a malformed location refuses an otherwise valid activation', () async {
    final op = await operations.create(stationCall: 'KI2D');
    for (final location in [
      {'grid': 'FN31ZZ'},
      {'latitude': '41.2', 'longitude': -73.8},
      {'grid': 'FM18ab', 'latitude': 41.2, 'longitude': -73.8},
    ]) {
      final result = await setup.apply(op.uuid, {
        'addActivationRefs': [
          {'activityKey': 'pota', 'ref': '12'},
        ],
        'location': location,
      });

      expect(result?.failed, isTrue, reason: '$location');
    }
    expect((await operations.get(op.uuid))!.refs, isEmpty);
    expect(saves, isEmpty);
  });

  test('a program without a validation hook still checks its declared reference pattern', () async {
    hooks['activity:*:operationControls'] = [_activity('wwff', 'wwffActivation', pattern: r'KFF-[0-9]{4}')];
    hooks.remove('ref:wwffActivation:null:validateRef');
    final op = await operations.create(stationCall: 'KI2D');
    Future<bool> tryRef(String ref) async {
      final outcome = await setup.apply(op.uuid, {
        'addActivationRefs': [
          {'activityKey': 'wwff', 'ref': ref},
        ],
      });
      return outcome == null;
    }

    expect(await tryRef('not-kff-0001'), isFalse, reason: 'the pattern describes the whole code');
    expect(await tryRef(' kff-0001 '), isTrue);
    expect((await operations.get(op.uuid))!.refs.single['ref'], 'KFF-0001');
    expect(saves, hasLength(1));
  });

  test('a preset preserves an operator edit made while the program is answering', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final validating = Completer<void>();
    final resume = Completer<void>();
    hooks['ref:potaActivation:null:validateRef'] = (Object? args) async {
      validating.complete();
      await resume.future;
      return _parkValidation(args);
    };
    final applying = setup.apply(op.uuid, {
      'addActivationRefs': [
        {'activityKey': 'pota', 'ref': '12'},
      ],
    });
    // If apply exits before validation, surface that failure instead of
    // waiting for the hook that would have signaled it was called.
    await Future.any([validating.future, applying]);
    expect(validating.isCompleted, isTrue);
    const forest = {'type': 'wwffActivation', 'ref': 'KFF-0001'};
    await operations.saveData(
      Operation(
        uuid: op.uuid,
        data: {
          ...op.data,
          'refs': [forest],
          'notes': 'Bring the low antenna',
        },
      ),
    );
    resume.complete();

    expect(await applying, isNull);
    final updated = (await operations.get(op.uuid))!;
    expect(updated.refs.first, forest);
    expect(updated.refs.map((ref) => ref['ref']), ['KFF-0001', 'US-0012']);
    expect(updated.data['notes'], 'Bring the low antenna');
  });

  test('the normal save follows reference locations until a preset supplies coordinates', () async {
    final op = await operations.create(stationCall: 'KI2D', userTitle: 'Existing title');
    expect(
      await setup.apply(op.uuid, {
        'addActivationRefs': [
          {'activityKey': 'pota', 'ref': '12'},
        ],
      }),
      isNull,
    );
    final placed = (await operations.get(op.uuid))!;
    expect(placed.data['gridSource'], refsGridSource);
    expect(placed.exactLocation, const GridLocation(41.2, -73.8));

    const trailhead = GridLocation(41.234567, -73.876543);
    expect(
      await setup.apply(op.uuid, {
        'location': {'latitude': trailhead.latitude, 'longitude': trailhead.longitude},
        'notes': 'Gate opens at sunrise',
      }),
      isNull,
    );
    final stated = (await operations.get(op.uuid))!;
    expect(stated.exactLocation, trailhead);
    expect(stated.userTitle, 'Existing title');
    expect(stated.data['notes'], 'Gate opens at sunrise');
    expect(stated.refs, placed.refs);
  });

  test('legacy operator and position fields write to the destination seat', () async {
    final op = await operations.createFromData({'stationCall': 'KI2D', 'operator1': 'W1AW', 'operator2': 'K1ABC'});
    await operations.updateLocalData(op.uuid, {multiIdentifierKey: '1'});

    expect(await setup.apply(op.uuid, {'operatorCall': ' w1aw ', 'multiIdentifier': '02'}), isNull);
    final seated = (await operations.get(op.uuid))!;
    expect(multiIdentifierFor(seated), '2');
    expect(seated.data['operator1'], 'W1AW');
    expect(seated.data['operator2'], 'W1AW');
    expect(seated.data, isNot(contains(multiIdentifierKey)));

    expect(await setup.apply(op.uuid, {'multiIdentifier': '0'}), isNull);
    expect(multiIdentifierFor((await operations.get(op.uuid))!), isEmpty);
    expect(saves, hasLength(1), reason: 'moving seats alone is device-local');
  });
}
