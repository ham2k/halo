// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// flags.dart's Windows image fallback (APP-29) hinges on flagIconCode
// decoding a flag emoji into flag-icons' filename vocabulary correctly — get
// that wrong and either the fallback silently no-ops (still broken on
// Windows) or points at a nonexistent asset. These tests pin the two shapes
// DXCC flags actually take (a plain regional-indicator pair, and the
// tag-sequence subdivision flags for England/Scotland/Wales/N. Ireland) and
// the platform gate that decides whether the fallback engages at all.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('flagIconCode', () {
    test('decodes a regional-indicator pair into a lowercase ISO code', () {
      expect(flagIconCode('🇺🇸'), 'us');
      expect(flagIconCode('🇨🇦'), 'ca');
    });

    // Black flag + Unicode tag characters (0xE0000-offset ASCII) spelling the
    // subdivision code + the cancel tag (U+E007F) — built from code points
    // rather than pasted, since the tag characters are invisible and a typo
    // wouldn't be visible in source.
    String tagFlag(String code) =>
        String.fromCharCodes([0x1F3F4, ...code.codeUnits.map((c) => c + 0xE0000), 0xE007F]);

    test('decodes England/Scotland/Wales/N. Ireland tag-sequence flags into flag-icons subdivision codes', () {
      // Matches @ham2k/lib-dxcc-data's dxccByCode.json exactly (dxccCode 223,
      // 279, 294, 265).
      expect(flagIconCode(tagFlag('gbeng')), 'gb-eng');
      expect(flagIconCode(tagFlag('gbsct')), 'gb-sct');
      expect(flagIconCode(tagFlag('gbwls')), 'gb-wls');
      expect(flagIconCode(tagFlag('gbnir')), 'gb-nir');
    });

    test('returns null for a non-flag emoji or an incomplete tag sequence', () {
      expect(flagIconCode('🎉'), isNull);
      expect(flagIconCode(''), isNull);
      // A black flag with no tag sequence (or an unterminated one) at all —
      // must not be mistaken for a subdivision flag.
      expect(flagIconCode('🏴'), isNull);
    });
  });

  group('flagGlyph', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('renders the emoji glyph directly off Windows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host(flagGlyph('🇺🇸')));
        expect(find.text('🇺🇸'), findsOneWidget);
        expect(find.byType(SvgPicture), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders the bundled SVG on Windows for a decodable flag', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(host(flagGlyph('🇺🇸')));
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('🇺🇸'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('still falls back to plain emoji text on Windows for a flag shape with no bundled SVG', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(host(flagGlyph('🎉')));
        expect(find.text('🎉'), findsOneWidget);
        expect(find.byType(SvgPicture), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('flagsInMarkdown', () {
    test('leaves text unchanged off Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        expect(flagsInMarkdown('Worked 🇺🇸 for a new one!'), 'Worked 🇺🇸 for a new one!');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('rewrites a flag emoji into a sized flag: image reference on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(flagsInMarkdown('Worked 🇺🇸 for a new one!', fontSize: 12), 'Worked ![flag](flag:us#16x12) for a new one!');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('leaves a flag shape with no bundled SVG untouched even on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(flagsInMarkdown('🎉 congrats!'), '🎉 congrats!');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('flagMarkdownImageBuilder', () {
    test('renders the bundled SVG for a flag: uri', () {
      final widget = flagMarkdownImageBuilder(
        MarkdownImageConfig(uri: Uri.parse('flag:gb-eng'), width: 20, height: 15),
      );
      expect(widget, isA<SvgPicture>());
    });

    test('renders nothing for any other uri scheme', () {
      final widget = flagMarkdownImageBuilder(MarkdownImageConfig(uri: Uri.parse('https://example.com/x.png')));
      expect(widget, isA<SizedBox>());
    });
  });
}
