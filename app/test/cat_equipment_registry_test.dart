// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A definition's `overrides`/`restrictions` are plain data, checked by
// nothing at compile time — a typo'd key (`cvAddress` for `civAddress`) is
// silently ignored by both transport and driver, since "unrecognized key"
// and "hardcode this field" look identical from either one's side. This is
// the one place that gets caught: every definition's hints are checked
// against what its own transport/driver would actually declare, so a typo
// fails a test instead of quietly doing nothing for a radio nobody has
// tested yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

void main() {
  final registry = EquipmentRegistry();

  for (final type in registry.types) {
    group(type.key, () {
      // Every key the transport/driver actually reads — whether or not it
      // shows a field for it — and, separately, what the fields with
      // nothing hardcoded or narrowed would offer.
      final knownKeys = {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys};
      final unrestrictedFields = [
        ...type.transport.configElements(),
        ...type.driver.configElements(),
      ].where((e) => e['type'] == 'field').toList();

      test('every overridden key is a field its transport or driver actually declares', () {
        for (final key in type.overrides.keys) {
          expect(knownKeys, contains(key),
              reason: '"$key" is overridden, but neither the transport nor the driver '
                  'declares a field by that key — a typo here silently hardcodes nothing.');
        }
      });

      // The test above only proves the KEY is real; it says nothing about
      // whether the transport/driver actually honored the override by
      // hiding the field. That guard is hand-written per field, per
      // provider — nothing enforces it centrally — so this is the one
      // place a forgotten `overrides.containsKey(...)` check gets caught,
      // instead of shipping as a field a user can "edit" whose value
      // silently never takes (EquipmentType._merged clobbers it with the
      // override at connect/save time regardless of what the form showed).
      test('every overridden key is actually hidden from the assembled form', () {
        final renderedKeys =
            type.configElements().where((e) => e['type'] == 'field').map((e) => e['key'] as String).toSet();
        for (final key in type.overrides.keys) {
          expect(renderedKeys, isNot(contains(key)),
              reason: '"$key" is overridden (meant to be hardcoded and hidden), but still renders '
                  'as a field — the transport/driver is missing its containsKey(overrides) guard.');
        }
      });

      test('every restricted key is a field its transport or driver actually declares', () {
        for (final key in type.restrictions.keys) {
          expect(knownKeys, contains(key),
              reason: '"$key" is restricted, but neither the transport nor the driver '
                  'declares a field by that key — a typo here silently narrows nothing.');
        }
      });

      test('a restriction only narrows the field\'s own options, never adds to them', () {
        for (final entry in type.restrictions.entries) {
          final field = unrestrictedFields.where((e) => e['key'] == entry.key);
          if (field.isEmpty) continue; // caught by the test above
          final options = field.first['options'];
          final restricted = entry.value;
          if (options is! List || restricted is! List) continue;

          final allowedValues = options.map((o) => (o as Map)['value']).toSet();
          final restrictedValues = restricted.toSet();

          expect(restrictedValues, isNotEmpty, reason: '"${entry.key}" is restricted to nothing at all');
          expect(allowedValues.containsAll(restrictedValues), isTrue,
              reason: '"${entry.key}" is restricted to a value its transport/driver never offers');
        }
      });
    });
  }

  test('every type key is unique', () {
    final keys = registry.types.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'a duplicate key makes typeFor() find the wrong one');
  });

  // None of the 4 registered radios pass a non-empty `restrictions` map
  // today, so the per-type "narrows, never adds" checks above never
  // actually execute their assertions for any of them — that loop stays
  // green even if the narrowing logic itself is broken or deleted. This
  // exercises the one real implementation (serial baud rate) directly,
  // so the mechanism has to keep working whether or not a radio uses it
  // yet.
  group('restrictions narrowing, exercised directly (no registered radio uses this yet)', () {
    const transport = SerialTransport();

    test('an unrestricted baud-rate field offers the full supported list', () {
      final field = transport.configElements().firstWhere((e) => e['key'] == 'baudRate');
      final offered = [for (final o in field['options'] as List) (o as Map)['value']];
      expect(offered, containsAll([4800, 9600, 19200, 38400]));
    });

    test('a restricted baud-rate field narrows to exactly the allowed subset, in order', () {
      final field = transport
          .configElements(restrictions: {
            'baudRate': [9600, 4800],
          })
          .firstWhere((e) => e['key'] == 'baudRate');
      final offered = [for (final o in field['options'] as List) (o as Map)['value']];
      expect(offered, [4800, 9600], reason: 'narrowed to the allowed subset, in the transport\'s own order');
    });
  });

  group('expectedUpdateInterval', () {
    // Which drivers PUSH state as it changes and which have to ask, as each
    // one is BEFORE it has heard anything. Spelled out rather than derived,
    // because a driver answering the wrong one is invisible: readings arrive
    // either way. Smart VFO Snap adds the interval to its settle delay, so a
    // pusher that claims a cadence slows every snap on that radio by it, and
    // a poller that claims none settles during the silence between polls and
    // snaps mid-turn (docs/design/cat.md § Smart VFO Snap).
    //
    // CI-V belongs on the polling side HERE and only here: transceive can't
    // be read back, so a fresh session assumes the poll and drops the claim
    // once the radio announces on its own (cat_icom_civ_test.dart).
    const pushes = {'flexradio'};

    for (final type in registry.types) {
      test('${type.key} — ${pushes.contains(type.driver.key) ? 'pushes' : 'polls'}', () {
        final session = type.driver.createSession(_SilentSink(), type.defaultConfig);
        addTearDown(session.teardown);
        final interval = session.expectedUpdateInterval;

        if (pushes.contains(type.driver.key)) {
          expect(interval, isNull, reason: 'a pushing driver reports changes as they happen');
        } else {
          expect(interval, isNotNull, reason: 'a polling driver must say how long silence proves nothing');
          expect(interval, greaterThan(Duration.zero));
        }
      });
    }
  });
}

/// Enough of a sink to construct a session. Nothing here sends or reads —
/// these tests only ask a session to describe itself.
class _SilentSink implements EquipmentSink {
  @override
  void send(List<int> bytes) {}
  @override
  void report(VfoReading reading) {}
}
