// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A message the footer cuts short opens in full as a notice. The footer
// decides WHEN (halo_widgets' own tests); this pins what the app raises.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const long = 'Imported QSO_1_2 and QSO_3_4 from *field-day*.adi into the log for the whole weekend';

  testWidgets('tapping a cut-off message raises it whole, as written, once, on top', (tester) async {
    final services = (await makeHaLoServices()).services;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    services.statusBar.setMessage(key: 'import', text: long);
    // Notices queue oldest first: behind one already up, the full text would
    // sit out of sight and the tap would look like it did nothing.
    services.statusBar.showNotice(key: 'earlier', text: 'An earlier notice');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, _) => StatusBarOverlay(
            services: services,
            child: const Scaffold(body: SizedBox.expand()),
          ),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    // Fixed pumps: the chrome carries a once-a-second clock, so it never
    // settles.
    await tester.pump(const Duration(milliseconds: 400));

    final inBar = find.descendant(of: find.byType(StatusBarFooter), matching: find.text(long));
    for (var tap = 0; tap < 2; tap++) {
      await tester.tap(inBar);
      await tester.pump(const Duration(milliseconds: 400));
    }

    final notices = services.statusBar.activeNotices;
    // A second tap re-raises the same notice; a copy per tap would stack
    // behind the first and wait for the operator to dismiss each.
    expect(notices.map((n) => n.key), ['footer:full:import', 'earlier']);
    expect(notices.first.persist, isFalse, reason: 'it repeats a transient message, and has no business in a later session\'s history');
    // A notice is markdown and a message is not: unescaped, the asterisks
    // turn into emphasis and the operator reads "field-day.adi" in italics.
    expect(
      find.descendant(of: find.byType(NoticeStack), matching: find.text(long, findRichText: true)),
      findsWidgets,
      reason: 'the notice shows the message as it was written',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
