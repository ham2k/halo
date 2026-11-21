// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/views/k4_diversity_control.dart';
import 'package:ham2k_logger/views/station_panel.dart';

import '../support/halo_test_support.dart';

class _Session extends Fake implements K4DiversitySession {
  final requests = <bool>[];

  @override
  void setDiversity(bool enabled) => requests.add(enabled);
}

class _Cat extends CatService {
  _Cat(super.settings);

  final session = _Session();
  EquipmentState reported = const EquipmentState(status: EquipmentStatus.connected);

  @override
  EquipmentState stateFor(String uuid) => nodeFor(uuid)?.typeKey == 'k4-remote' ? reported : super.stateFor(uuid);

  @override
  EquipmentSession? connectedSession(String uuid) => nodeFor(uuid)?.typeKey == 'k4-remote' ? session : super.connectedSession(uuid);

  void hear(EquipmentState state) {
    reported = state;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shared DIV control waits for readback and appears once for Main and Sub', (tester) async {
    late _Cat cat;
    final h = await makeHaLoServices(cat: (settings) => cat = _Cat(settings));
    await h.settings.setExperimentEnabled('audio', true);
    await h.settings.setExperimentEnabled('so2r', true);
    final main = await cat.addNode(typeKey: 'k4-remote', name: 'K4');
    final sub = cat.nodes.singleWhere((node) => node.uuid != main.uuid);
    await cat.setRadio1(LocalRadio(main.uuid));
    await cat.setRadio2(sub.uuid);
    cat.hear(cat.reported.copyWith(k4Diversity: false));

    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: StationPanel(services: services, compact: true, onMoreSettings: () {}),
      ),
      harness: h,
      size: const Size(1000, 1600),
    );
    await tester.pumpAndSettle();
    final headings = find.text(t.settings.station.configurationSection).evaluate().length;
    for (var i = 0; i < headings; i++) {
      final heading = find.text(t.settings.station.configurationSection).at(i);
      await tester.ensureVisible(heading);
      await tester.tap(heading);
      await tester.pumpAndSettle();
    }
    expect(find.byType(K4DiversityControl), findsOneWidget, reason: 'Main and Sub share one device-wide setting');
    final toggle = find.descendant(of: find.byType(K4DiversityControl), matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(cat.session.requests, [true]);
    expect(tester.widget<Switch>(toggle).value, isFalse, reason: 'sending a command is not evidence the K4 accepted it');

    cat.hear(cat.reported.copyWith(k4Diversity: true));
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(find.text(t.settings.station.k4DiversityFollowing), findsOneWidget);
    cat.hear(const EquipmentState());
    await tester.pump();
    expect(find.byType(K4DiversityControl), findsNothing, reason: 'a disconnected radio has no confirmed current mode');
  });

  testWidgets('the DIV control needs the experiment and a confirmed compatible session', (tester) async {
    late _Cat cat;
    final h = await makeHaLoServices(cat: (settings) => cat = _Cat(settings));
    final node = await cat.addNode(typeKey: 'k4-remote', name: 'K4');
    cat.hear(cat.reported.copyWith(k4Diversity: false));
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: StationPanel(services: services, compact: true, onMoreSettings: () {}),
      ),
      harness: h,
    );
    await tester.pumpAndSettle();
    expect(find.byType(K4DiversityControl, skipOffstage: false), findsNothing, reason: 'DIV remains part of EXP AUDIO');

    await h.settings.setExperimentEnabled('audio', true);
    cat.hear(const EquipmentState(status: EquipmentStatus.connected));
    await tester.pump();
    expect(find.byType(K4DiversityControl, skipOffstage: false), findsNothing, reason: 'unknown DV is not a guessed off state');
    cat.setNodeK4Diversity(node.uuid, true);
    expect(cat.session.requests, isEmpty);

    cat.hear(const EquipmentState(status: EquipmentStatus.connected, k4Diversity: false, stale: true));
    cat.setNodeK4Diversity(node.uuid, true);
    expect(cat.session.requests, isEmpty, reason: 'stale readback cannot authorize a change');
    expect(find.byType(K4DiversityControl, skipOffstage: false), findsNothing);
    final serial = await cat.addNode(typeKey: 'k4-serial');
    cat.setNodeK4Diversity(serial.uuid, true);
    expect(cat.session.requests, isEmpty, reason: 'local CAT has no shared receiver control');
  });
}
