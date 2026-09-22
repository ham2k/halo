// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Call Info pane's Notes section paints each note's marker emoji as its
// own glowed glyph, the way the logging panel's call info line does — not
// folded into the markdown prose, where Roboto resolves it to nothing on web
// and no halo can reach it without also landing on the text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(WidgetTester tester, List<String> notes) async {
    final services = (await makeHaLoServices()).services;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CallInfoPanel(
              operation: const Operation(uuid: 'op-1', data: {'grid': 'FN31pr'}),
              services: services,
              call: 'W1AW',
              guess: const {},
              lookups: [
                {'source': 'call-notes', 'notes': notes},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each note\'s marker is its own glowed glyph, in the emoji font', (tester) async {
    await pumpPanel(tester, ['🧑‍💻 Alan - Dev Team', '⏰ slow op', 'no marker here']);

    for (final marker in ['🧑‍💻', '⏰']) {
      final glyph = tester.widget<Text>(find.text(marker));
      expect(glyph.style?.fontFamily, emojiFontFamily);
      expect(glyph.style?.shadows, isNotEmpty);
    }
    // The prose carries no halo of its own, and a marker-less note is prose alone.
    expect(find.textContaining('Alan - Dev Team'), findsOneWidget);
    expect(find.textContaining('no marker here'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && (w.style?.shadows?.isNotEmpty ?? false)), findsNWidgets(2));
  });

  testWidgets('prose after the marker is inline markdown, never a block', (tester) async {
    // With the marker split off, the prose is the START of what the parser
    // sees; a block renderer would make this a bullet and that a numbered
    // list, where a note's line reads them as content.
    await pumpPanel(tester, ['⚠️ - never before 10z', '⏰ 73. tnx', '']);

    expect(find.textContaining('- never before 10z'), findsOneWidget);
    expect(find.textContaining('73. tnx'), findsOneWidget);
    // A blank entry is dropped, not padded in as a gap.
    expect(find.byWidgetPredicate((w) => w is InlineMarkdownText), findsNWidgets(2));
  });
}
