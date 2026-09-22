// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host(NumberKeys keys) => MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: keys),
    ),
  );

  NumberKeys make({required ValueChanged<String> onKey, String? extraKey, bool vibrate = true}) =>
      NumberKeys(onKey: onKey, extraKey: extraKey, vibrate: vibrate, backgroundColor: const Color(0xFF202020), foregroundColor: const Color(0xFFF0F0F0));

  testWidgets('renders 0–9 plus the extra key and reports each tap', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(host(make(onKey: pressed.add, extraKey: '/', vibrate: false)));

    for (final glyph in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '/']) {
      expect(find.text(glyph), findsOneWidget, reason: 'missing key "$glyph"');
    }

    await tester.tap(find.text('7'));
    await tester.tap(find.text('/'));
    expect(pressed, ['7', '/']);
  });

  testWidgets('omits the extra key when it is null', (tester) async {
    await tester.pumpWidget(host(make(onKey: (_) {}, extraKey: null)));

    expect(find.text('/'), findsNothing);
    expect(find.text('.'), findsNothing);
    // Exactly the ten digits, each its own tappable key.
    expect(find.descendant(of: find.byType(NumberKeys), matching: find.byType(InkWell)), findsNWidgets(10));
  });

  testWidgets('vibrate flag gates the haptic on each press', (tester) async {
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String?);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(host(make(onKey: (_) {}, extraKey: null, vibrate: false)));
    await tester.tap(find.text('1'));
    expect(haptics, isEmpty, reason: 'vibrate: false must not buzz');

    await tester.pumpWidget(host(make(onKey: (_) {}, extraKey: null, vibrate: true)));
    await tester.tap(find.text('2'));
    expect(haptics, isNotEmpty, reason: 'vibrate: true must buzz');
  });
}
