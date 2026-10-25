// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Imports panel. The Captured QSOs band is built inside the StreamBuilder
// that watches the captures, where the SectionedListView around it cannot
// see it — so the panel must cut that section itself. Handed over as a plain
// row instead, the band trips SectionHeader's debug assertion and the panel
// shows an error box where the captures belong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/operation_import_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  testWidgets('the Captured QSOs band pins over its own rows', (tester) async {
    final operation = Operation(uuid: 'op-1', data: const {'refs': []});
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationImportPanel(services: services, operation: operation),
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
}
