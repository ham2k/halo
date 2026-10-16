// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A template editor's sample preview renders again when its renderer
// changes. Every settings change rebuilds the app root, so a renderer made
// afresh there would re-render every preview on screen on each one — an
// autosaving field included.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("a settings change leaves the template preview's renderer as it was", (tester) async {
    SharedPreferences.setMockInitialValues({});
    setReleaseNotesForTesting(const []);
    setTesterNotesForTesting(const []);
    final HaLoHarness(:services, :settings) = await makeHaLoServices(prefs: null);

    await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
    await tester.pump();
    TemplatePreview preview() => tester.widget<TemplateEditorScope>(find.byType(TemplateEditorScope)).preview;
    final before = preview();

    await settings.setFontScale(FontScale.larger);
    await tester.pump();
    expect(preview(), before);

    // Drain pending timers to avoid test errors.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
