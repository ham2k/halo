// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On web, with the accessibility DOM on (every dev web build, and any
// operator using assistive tech), a click goes to the topmost semantics
// node under the pointer. A FAB whose tap merges into the pane's node has
// no node of its own up there, so the click lands on the operation row the
// FAB covers and opens that operation instead of a new one.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the New Operation FAB is a button node of its own, not the pane holding the rows under it', (tester) async {
    final semantics = tester.ensureSemantics();
    final HaLoHarness(:services) = await makeHaLoServices();
    // Enough that a row runs under the FAB.
    for (var i = 0; i < 20; i++) {
      await services.operations.create(stationCall: 'N0DEV');
    }

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: HomeView(services: services)),
      ),
    );
    await tester.pumpAndSettle();

    final fab = find.ancestor(of: find.byIcon(MdiIcons.plus), matching: find.byType(Material)).first;
    final node = tester.getSemantics(fab);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.rect.size, tester.getSize(fab), reason: 'a node the size of the pane is the merged one, whose rows cover the FAB');
    expect(node.label, t.home.newOperation, reason: 'once, not again from the Text beside the icon');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });
}
