// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Whether a radio is a keyer is a fact about its NODE, not its driver: a
// generic Icom entry serves rigs with and without a CW keyer, and the
// service must read the node's own config (the developer-mode field) when
// offering it as the key in use. A service reading the driver's bare
// getter would offer every generic Icom, and key nothing on half of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    final settings = harness.settings;
    services = harness.services;
    await settings.setExperimentEnabled('keyer', true);
  });

  test('a generic Icom keys only when its node says so, and the pick follows an edit', () async {
    final cat = services.cat;
    final type = EquipmentRegistry().typeFor('icom-generic-serial')!;
    final node = await cat.addNode(
      typeKey: 'icom-generic-serial',
      name: 'Mystery Icom',
      config: {...type.defaultConfig, 'port': '/dev/tty.fake'},
    );
    expect(cat.keyerCandidates, isEmpty, reason: 'prefilled off: not offered as the key in use');
    expect(cat.designatedKeyIsKeyer, isFalse, reason: 'and not designated by default either');

    await cat.updateNode(node.copyWith(config: {...node.config, 'cwKeyer': true}));
    expect(cat.keyerCandidates.map((n) => n.uuid), [node.uuid]);
    expect(cat.designatedKeyIsKeyer, isTrue, reason: 'a radio whose CAT keys is its own key by default');

    await cat.updateNode(node.copyWith(config: {...node.config, 'cwKeyer': false}));
    expect(cat.keyerCandidates, isEmpty);
    expect(cat.designatedKeyIsKeyer, isFalse);
  });

  test('a named entry keys on its pin alone; a node stored before the field existed keys as it always did', () async {
    final cat = services.cat;
    final ic7300 = await cat.addNode(typeKey: 'ic7300-serial', name: 'IC-7300', config: {'port': '/dev/tty.fake'});
    expect(cat.keyerCandidates.map((n) => n.uuid), contains(ic7300.uuid));
    final old = await cat.addNode(typeKey: 'icom-generic-serial', name: 'Old node', config: {'civAddress': '94', 'port': '/dev/tty.x'});
    expect(cat.keyerCandidates.map((n) => n.uuid), contains(old.uuid), reason: 'no cwKeyer key at all means the driver default');
    final ic706 = await cat.addNode(typeKey: 'ic706mkiig-serial', name: 'IC-706', config: {'port': '/dev/tty.y'});
    expect(cat.keyerCandidates.map((n) => n.uuid), isNot(contains(ic706.uuid)), reason: 'pinned off');
    expect(cat.nodes, hasLength(3), reason: 'sanity');
  });
}
