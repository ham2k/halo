// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A header action with nothing to act on yet (the Chasing view's Exports
// over a period with no contacts) is disabled, not gone. Material's disabled
// grey all but vanishes on the header, so it would read as no button at all.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/header_action_button.dart';

void main() {
  const onHeader = Colors.white;

  Future<void> pumpHeader(WidgetTester tester, {required bool labeled}) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        appBarTheme: const AppBarTheme(foregroundColor: onHeader, backgroundColor: Colors.teal),
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            Builder(
              builder: (context) => headerActionButton(context, icon: MdiIcons.export, label: 'Exports', labeled: labeled, onPressed: null),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('a disabled labelled action dims the header color', (tester) async {
    await pumpHeader(tester, labeled: true);
    final label = tester.renderObject<RenderParagraph>(find.text('Exports')).text.style?.color;
    expect(label, onHeader.withValues(alpha: 0.38));
  });

  testWidgets('a disabled icon action dims the header color', (tester) async {
    await pumpHeader(tester, labeled: false);
    final icon = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(Icon), matching: find.byType(RichText))).text.style?.color;
    expect(icon, onHeader.withValues(alpha: 0.38));
  });
}
