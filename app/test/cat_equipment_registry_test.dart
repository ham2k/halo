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
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';
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

  // resolveIconName answers an unknown name with a puzzle-piece glyph — no
  // exception, no analyzer error, no log. A typo like 'usbport' for
  // 'usb-port' therefore ships as a jigsaw next to a radio and nothing
  // anywhere says so. This is the only thing that can catch it.
  test('every transport names an icon the codepoint table actually has', () {
    for (final type in registry.types) {
      // The one deliberate exception: NoneTransport moves no bytes, so it
      // has nothing to depict as "how it's plugged in" — the equipment
      // tile for its category never renders a transport glyph at all.
      if (type.transportKey == NoneTransport.transportKey) continue;
      final name = type.transportIconName;
      expect(name, isNotNull, reason: '${type.transportKey} has no icon, so its rows show nothing');
      expect(resolveIconName(name!), isNot(MdiIcons.puzzle),
          reason: '"$name" is not in the generated codepoint table — resolveIconName '
              'falls back to a puzzle piece rather than failing');
    }
  });

  // The section header is the operator's only clue about what is behind a
  // collapsed tile, and FormRenderer renders a missing one as an empty
  // string: a bare chevron with no label, silently.
  test('every variant with notes gives them a collapsible section with a title', () {
    for (final type in registry.types) {
      for (final note in type.notes) {
        if (note['type'] != 'markdown') continue;
        expect(note['collapsible'], isTrue, reason: '${type.key} renders notes open, burying its own fields');
        expect(note['title'], isA<String>().having((t) => t.isNotEmpty, 'is not empty', isTrue),
            reason: '${type.key} would render a chevron with no label at all');
        expect(note['text'], isA<String>().having((t) => t.isNotEmpty, 'is not empty', isTrue));
      }
    }
  });

  // A renamed key is the one change to this file that fails silently and
  // destructively: the stored record survives, resolves to nothing, and the
  // panel lists it as an unrecognized type with the operator's whole
  // configuration sealed inside. Every rename has to leave a forwarding
  // address, and every forwarding address has to point somewhere real.
  group('renamed keys still find their pairing', () {
    test('every old key maps to one the catalogue still has', () {
      for (final entry in renamedTypeKeys.entries) {
        expect(registry.typeFor(entry.value), isNotNull,
            reason: '"${entry.key}" forwards to "${entry.value}", which no longer exists');
        expect(registry.typeFor(entry.key), isNull,
            reason: '"${entry.key}" is still a live key, so nothing was actually renamed');
      }
    });

    test('a node stored under the old key loads as the new one', () {
      // The pre-rename record, exactly as a build from before it wrote one.
      final node = EquipmentNode.fromJson('radio-1', {
        'typeKey': 'icom-civ-serial',
        'name': 'The 7300',
        'config': {'port': '/dev/cu.usbserial', 'civAddress': '94'},
      });

      expect(node, isNotNull);
      expect(node!.typeKey, 'icom-generic-serial');
      expect(registry.typeFor(node.typeKey), isNotNull, reason: 'it has to resolve, not just be renamed');
      // And it keeps everything that made it worth migrating.
      expect(node.name, 'The 7300');
      expect(node.config['civAddress'], '94');
    });
  });

  // The equipment editor puts two of its own fields alongside whatever a
  // pairing declares — `name`, and `transport` when a radio offers more than
  // one — and strips both from the config on the way out. A transport or
  // driver declaring either name would have its value overwritten by the
  // editor's and then deleted at every save, silently: the config map is
  // free-form, so nothing else in the system can notice.
  test('nothing declares a config key the editor reserves for itself', () {
    for (final type in registry.types) {
      for (final key in {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys}) {
        expect(key, isNot(anyOf('name', 'transport')),
            reason: '${type.key} declares "$key", which the editor uses for its own field '
                'and removes before saving — the value would never survive');
      }
    }
  });

  test('every type key is unique', () {
    final keys = registry.types.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'a duplicate key makes typeFor() find the wrong one');
  });

  // A variant key is what a configured node stores. Renaming one does not
  // fail anywhere — the node simply stops resolving, and the panel shows it
  // as a type that no longer exists with everything the operator set up
  // still inside it. So the shipped set is written down, and changing it has
  // to be a deliberate edit here rather than a side effect of moving a
  // variant between models.
  test('the shipped variant keys are exactly these', () {
    expect(
      registry.types.map((t) => t.key).toSet(),
      {
        'flexradio-tcp',
        'ft891-serial',
        'yaesu-serial',
        'icom-generic-serial',
        'kenwood-serial',
        'ic705-network',
        'ic705-serial',
        'rigctld-tcp',
        'flrig-tcp',
        'fake-radio',
        'antenna-none',
        'key-none',
      },
    );
  });

  for (final model in registry.models) {
    group('model ${model.key}', () {
      test('has at least one way in', () => expect(model.variants, isNotEmpty));

      test('names each transport once', () {
        final keys = model.variants.map((v) => v.transportKey).toList();
        expect(keys.toSet().length, keys.length,
            reason: 'two variants on one transport make the editor offer the same choice twice, '
                'and variantForTransport pick whichever comes first');
      });

      // The editor renders EVERY variant's fields at once and narrows them
      // with `visibleWhen`, so two variants sharing a key share one field and
      // one controller. That is deliberate for a genuinely shared setting
      // (`host` on two network transports — type the address once). It is a
      // bug when the key means different things: `port` is a numeric TCP port
      // to one transport and a `/dev/cu.*` device path to another, and
      // switching transport would pour one into the other with no warning.
      // The editor seeds the form from EVERY variant's defaultConfig at once,
      // because that is what lets switching transport land on sensible values
      // with no re-seeding logic. The price is that a key two variants
      // disagree about has one box and can only show one of the two answers —
      // so they are not allowed to disagree. Caught here rather than in the
      // panel because there is no run-time symptom: the operator simply sees
      // a prefill that belongs to the other cable.
      test('two variants never prefill the same key with different values', () {
        final seen = <String, dynamic>{};
        for (final variant in model.variants) {
          for (final entry in variant.defaultConfig.entries) {
            expect(seen.putIfAbsent(entry.key, () => entry.value), entry.value,
                reason: '${model.key}\'s variants prefill "${entry.key}" differently, but the editor '
                    'renders one field for it — one of the two values can never be shown');
          }
        }
      });

      test('a field key shared between its variants means the same thing in each', () {
        final fieldTypes = <String, String>{};
        for (final variant in model.variants) {
          for (final element in [...variant.transport.configElements(), ...variant.driver.configElements()]) {
            if (element['type'] != 'field') continue;
            final key = element['key'] as String;
            final fieldType = element['fieldType'] as String;
            final seen = fieldTypes[key];
            expect(seen ?? fieldType, fieldType,
                reason: '"$key" is a $seen on one of ${model.key}\'s transports and a $fieldType on another — '
                    'they share a field in the editor, so one would overwrite the other');
            fieldTypes[key] = fieldType;
          }
        }
      });
    });
  }

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
    const pushes = {'flexradio', 'fake-radio'};

    // Antenna/Key have no live connection at all — see NoneTransport — so
    // createSession is documented to throw rather than answer either way.
    final connectable = [
      for (final type in registry.types)
        if (type.category == kCategoryTransceiver) type,
    ];

    for (final type in connectable) {
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
  @override
  void reportPower(num watts) {}
  @override
  void reportDiagnostic(String? note) {}
}
