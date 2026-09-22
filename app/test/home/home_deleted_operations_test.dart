// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Show Deleted Operations: a deleted operation is only reachable — and so only
// undeletable — through Home's list, so the setting has to take effect on a
// Home that is already on screen (Home is never rebuilt by a settings change
// on its own), and a deleted row has to read as deleted, the way app-polo
// shows one, or the operator logs into it by mistake.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder row(String title) => find.textContaining(title, findRichText: true);

  /// The half-strength wrapper app-polo's deleted row has, if [title]'s row
  /// sits in one.
  Finder fade(String title) => find.ancestor(of: row(title), matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5));

  bool struckThrough(WidgetTester tester, String title) {
    final spans = <InlineSpan>[];
    tester.widget<RichText>(row(title)).text.visitChildren((span) {
      spans.add(span);
      return true;
    });
    return spans.every((span) => span.style?.decoration == TextDecoration.lineThrough);
  }

  testWidgets('deleted operations appear, struck through and faded, once the setting is turned on', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await services.operations.create(stationCall: 'N0DEV', userTitle: 'Alive');
    final gone = await services.operations.create(stationCall: 'N0DEV', userTitle: 'Gone');
    await services.operations.softDelete(gone.uuid);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: HomeView(services: services)),
      ),
    );
    await tester.pumpAndSettle();

    expect(row('Alive'), findsOneWidget);
    expect(row('Gone'), findsNothing);

    await settings.setSettingValue(SettingsService.loggingGroup, 'showDeletedOps', true);
    await tester.pumpAndSettle();

    expect(row('Gone'), findsOneWidget);
    expect(struckThrough(tester, 'Gone'), isTrue);
    expect(fade('Gone'), findsOneWidget);
    // The styling is the deleted row's alone.
    expect(struckThrough(tester, 'Alive'), isFalse);
    expect(fade('Alive'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5)); // drain home's debounce/clock timers
  });
}
