// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Layout Density re-derives the theme with its own header height, and a
// bare `showDialog`'s inset is a theme value: if the derivation carries only
// the header height, those dialogs keep the default header's inset and reach
// further into a taller header — under the window controls — than every
// other dialog. Drives the real derivation through HaLoApp; a theme built by
// hand in the test could not catch a derivation that forgets the inset.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';

import '../support/halo_test_support.dart';

void main() {
  for (final preference in [DensityPreference.densest, DensityPreference.sparsest]) {
    testWidgets('at ${preference.name}, a bare dialog overlaps the header by the same amount as every other', (tester) async {
      // Tall enough that an explicit pick stands rather than being overridden by the height.
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      setReleaseNotesForTesting(const []);
      setTesterNotesForTesting(const []);
      final HaLoHarness(:services) = await makeHaLoServices(prefs: null);
      await services.settings.setDensityPreference(preference);

      await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      final headerHeight = theme.appBarTheme.toolbarHeight!;
      expect(headerHeight, isNot(48.0), reason: 'the default header would not tell a carried inset from a forgotten one');
      expect(theme.dialogTheme.insetPadding!.top, headerHeight - dialogHeaderOverlap);
      expect(haloDialogEdgeClearance(tester.element(find.byType(Scaffold).first)), headerHeight - dialogHeaderOverlap);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
