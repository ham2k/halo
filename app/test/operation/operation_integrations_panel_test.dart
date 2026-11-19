// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Integrations panel. The Captured QSOs band is built inside the StreamBuilder
// that watches the captures, where the SectionedListView around it cannot
// see it — so the panel must cut that section itself. Handed over as a plain
// row instead, the band trips SectionHeader's debug assertion and the panel
// shows an error box where the captures belong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/inbound_qso_listener_service.dart';
import 'package:ham2k_logger/views/operation/operation_integrations_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  testWidgets('the Captured QSOs band pins over its own rows', (tester) async {
    final operation = Operation(uuid: 'op-1', data: const {'refs': []});
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(of: find.byType(SectionHeader), matching: find.byType(PinnedHeaderSliver)),
      findsOneWidget,
      reason: 'a band the list cannot see is not pinned, and its rows join the section above',
    );

    // Unmounted in the body: drift's stream close arms a timer that must fire
    // before the binding's pending-timer check.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });

  // Nothing in a datagram says who sent it, so a contact another device sent
  // waits here rather than reaching the log on its own; the operator, who
  // knows their own devices, says which ones to trust.
  testWidgets("another device's contacts wait under its address, and Always add keeps it and adds them here", (tester) async {
    const stranger = '203.0.113.5';
    final h = await makeHaLoServices();
    final operation = (await tester.runAsync(() => h.services.operations.create(stationCall: 'KI2D')))!;
    await tester.runAsync(
      () => h.services.inboundCaptures.capture(
        source: wsjtxSource,
        dedupeKey: 'w1aw',
        qsoData: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'FT8',
        },
        sender: stranger,
      ),
    );
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
      harness: h,
    );
    // The capture comes from the database, and whether its address is this
    // device's own from the network: both on the real event loop.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final strings = t.operation.import;
    expect(find.text(strings.heldTitle(sender: stranger)), findsOneWidget);

    await tester.tap(find.text(strings.heldAlwaysAction));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(h.settings.inboundSendersAllowed, [stranger]);
    final logged = (await tester.runAsync(() => h.services.qsos.watchForOperation(operation.uuid).first))!;
    expect(logged.map((q) => (q.data['their'] as Map)['call']), ['W1AW']);

    // The added contact's lookup waits out the extension runtime this test
    // never starts.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });

  // Turning on "Add to this operation" adds the backlog; a held device's
  // contacts in it would reach the log without the operator having said
  // which devices are theirs.
  testWidgets("turning on Add to this operation leaves another device's contacts waiting", (tester) async {
    const stranger = '203.0.113.5';
    final h = await makeHaLoServices();
    final operation = (await tester.runAsync(() => h.services.operations.create(stationCall: 'KI2D')))!;
    for (final (call, sender) in [('W1AW', null), ('K3TN', stranger)]) {
      await tester.runAsync(
        () => h.services.inboundCaptures.capture(
          source: wsjtxSource,
          dedupeKey: call,
          qsoData: {
            'their': {'call': call},
            'band': '20m',
            'mode': 'FT8',
          },
          sender: sender,
        ),
      );
    }
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
      harness: h,
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    await tester.tap(find.byType(SwitchListTile));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final logged = (await tester.runAsync(() => h.services.qsos.watchForOperation(operation.uuid).first))!;
    expect(logged.map((q) => (q.data['their'] as Map)['call']), ['W1AW']);
    expect(find.text(t.operation.import.heldTitle(sender: stranger)), findsOneWidget);

    h.services.inboundQsos.stopReceivingFor(operation.uuid);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });
}
