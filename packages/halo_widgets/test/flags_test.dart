// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A flag emoji composes into one glyph everywhere — but only in the bundled
// color-emoji font. Left to the ambient text style it falls to Roboto, and
// from there to whatever the platform substitutes: Segoe UI Emoji on Windows,
// which has no flag glyphs and draws the bare letters "US", and nothing at all
// on web. Applying emojiFontFamily IS the whole fix, and it is unconditional —
// no platform branch — so these assert only that the font reaches the glyph.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  // Built from code points rather than pasted: the tag characters are
  // invisible, so a typo would not show in source.
  String tagFlag(String code) => String.fromCharCodes([0x1F3F4, ...code.codeUnits.map((c) => c + 0xE0000), 0xE007F]);

  group('flagGlyph', () {
    testWidgets('renders the emoji in the bundled font', (tester) async {
      await tester.pumpWidget(host(flagGlyph('🇺🇸')));

      // Without this the glyph is Roboto's, which resolves to letter boxes on
      // Windows and to nothing on web — the bug this whole path exists to
      // prevent, and invisible to a test that only looks for the string.
      expect(tester.widget<Text>(find.text('🇺🇸')).style?.fontFamily, emojiFontFamily);
    });

    testWidgets('a tag-sequence subdivision flag goes through the same path', (tester) async {
      final england = tagFlag('gbeng');
      await tester.pumpWidget(host(flagGlyph(england)));

      expect(tester.widget<Text>(find.text(england)).style?.fontFamily, emojiFontFamily);
    });

    testWidgets('a non-flag pictograph is rendered too, not dropped', (tester) async {
      // flagGlyph is the call note's leading-glyph renderer as well, so it
      // must not assume its argument decodes as a flag at all.
      await tester.pumpWidget(host(flagGlyph('🎉')));

      expect(tester.widget<Text>(find.text('🎉')).style?.fontFamily, emojiFontFamily);
    });

    testWidgets('the requested size and glow reach the glyph', (tester) async {
      await tester.pumpWidget(host(flagGlyph('🇺🇸', fontSize: 24, shadows: const [Shadow(blurRadius: 3)])));

      final style = tester.widget<Text>(find.text('🇺🇸')).style;
      expect(style?.fontSize, 24);
      expect(style?.shadows, hasLength(1));
    });
  });

  group('flagSpan', () {
    testWidgets('carries the surrounding style size into the glyph', (tester) async {
      await tester.pumpWidget(
        host(
          Text.rich(
            TextSpan(
              children: [
                flagSpan('🇺🇸', style: const TextStyle(fontSize: 20)),
                const TextSpan(text: ' United States'),
              ],
            ),
          ),
        ),
      );

      final style = tester.widget<Text>(find.text('🇺🇸')).style;
      expect(style?.fontFamily, emojiFontFamily);
      expect(style?.fontSize, 20);
    });
  });
}
