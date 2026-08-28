// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A reference row's title line shrinks rather than truncates. Half a reference
// is not a shorter version of it — it is the wrong reference — so a narrow row
// gives up point size, not characters. The trap is that `TextOverflow.ellipsis`
// looks identical in a passing test to a line that was fitted: assert the font
// size actually came DOWN, which only a real shrink does.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The row is squeezed by the WINDOW rather than by a wrapper, because the
  /// sheet lays itself out against the whole width.
  Future<double?> titleFontSize(WidgetTester tester, String reference) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(HaLoDatabase(NativeDatabase.memory()), settings, extensions: extensions);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(
            // A fresh State per reference: the sheet reads the operation in
            // `initState`, so re-pumping the same widget type would keep the
            // first one and measure it twice.
            key: ValueKey(reference),
            services: services,
            operation: Operation(
              uuid: 'op-123',
              data: {
                'refs': [
                  {'type': 'potaActivation', 'ref': reference, 'shortLabel': reference, 'name': 'A Park'},
                ],
              },
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // `find.text` reads `Text.data`, which is the same string whether or not
    // the line ellipsized when painted — so this locates the row, and the
    // caller's font-size comparison is what shows it was FITTED rather than
    // truncated.
    final title = find.text(reference);
    expect(title, findsOneWidget);
    return tester.widget<Text>(title).style?.fontSize;
  }

  testWidgets('a reference too wide for its row shrinks instead of truncating', (tester) async {
    final short = await titleFontSize(tester, 'US-0370');
    final long = await titleFontSize(tester, 'US-0370/VERY-LONG-COMPOUND-REFERENCE-0001');

    expect(short, isNotNull);
    expect(long, isNotNull);
    expect(long!, lessThan(short!));
  });
}
