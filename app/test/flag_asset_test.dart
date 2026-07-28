// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// flags.dart's Windows image fallback (APP-29) references vendored SVGs
// under app/assets/flags/ by a code decoded from the flag emoji — a missing
// or malformed file there fails silently at runtime (SvgPicture just
// doesn't paint) rather than as a compile error. halo_widgets' own test
// suite can't catch this: assets/flags/ is declared in this app's
// pubspec.yaml, not halo_widgets', so a test running there never sees the
// real asset bundle. Only a test in the app package, like this one,
// actually exercises the vendored files.
//
// "No exception" alone doesn't prove a flag actually painted, so this also
// checks for real non-transparent pixels — captured via a real Future
// (`tester.runAsync`), since vector_graphics compiles each SVG through an
// isolate `compute()` call that a bare `pumpAndSettle()` doesn't wait for
// (confirmed empirically: without this, the raster-embedded us.svg/um.svg
// painted nothing in a widget test despite throwing no exception).
//
// That blank-pixels check alone wouldn't have caught the US/UM bug this PR
// actually fixed, though: flutter_svg silently drops any `<marker>` element
// (a long-standing gap, no exception, no warning visible outside the
// console) — flag-icons draws the US flag's 50 stars via one, so the flag
// still painted plenty of non-transparent pixels (the red/white stripes),
// just with a blank canton where the stars should be. A per-pixel diff
// against a reference render would be the thorough fix; the static element
// check below is the cheap one that actually matches the failure mode.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  testWidgets('every vendored flag SVG loads and paints real (non-transparent) pixels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final codes = Directory('assets/flags')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.svg'))
          .map((name) => name.substring(0, name.length - 4))
          .toList();
      // A directory-listing bug (wrong path, nothing vendored) must fail
      // loud here, not pass vacuously with zero codes checked.
      expect(codes.length, greaterThan(260));

      final key = GlobalKey();
      for (final code in codes) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(key: key, child: SvgPicture.asset(flagAssetPath(code), width: 40, height: 30)),
          ),
        ));
        await tester.pumpAndSettle();
        // Real wall-clock time for the SVG's isolate compile to finish — see
        // this file's header.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'assets/flags/$code.svg');

        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        expect(_hasVisibleContent(bytes!), isTrue, reason: 'assets/flags/$code.svg rendered as a blank/transparent image');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('no vendored flag SVG uses an element flutter_svg silently drops', () {
    // flutter_svg has no support for <marker> at all (github.com/dnfield/
    // flutter_svg — long-standing, unresolved as of this writing); <filter>,
    // <style>, and <mask> are the other commonly-seen ones it warns about and
    // ignores rather than erroring on. A future re-vendor pulling in a flag
    // that uses one of these would silently lose detail exactly like the
    // original US/UM stars did, with nothing in the test run to say so
    // beyond this check.
    final offenders = <String>[];
    for (final file in Directory('assets/flags').listSync().whereType<File>()) {
      if (!file.path.endsWith('.svg')) continue;
      final svg = file.readAsStringSync();
      if (RegExp(r'<(marker|filter|style|mask|pattern)[\s>]').hasMatch(svg)) {
        offenders.add(file.uri.pathSegments.last);
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('flagGlyph renders a real DXCC flag as the bundled SVG on Windows, not the raw emoji', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      // England's tag-sequence flag — the shape #451's font swap couldn't
      // fix (an uncomposed black flag), so this is the case that matters
      // most to actually exercise end to end.
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: flagGlyph(dxccFlagEngland))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text(dxccFlagEngland), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// True if [rgba] (a `rawRgba` capture) has at least one non-transparent
/// pixel — cheap enough over a 40x30 capture to run per-asset in a loop, and
/// specifically catches a picture that decoded/compiled but painted nothing
/// (the class of bug flutter_svg's dropped-`<marker>` elements caused for
/// the US/UM flags, silently, with no exception).
bool _hasVisibleContent(ByteData rgba) {
  for (var i = 3; i < rgba.lengthInBytes; i += 4) {
    if (rgba.getUint8(i) != 0) return true;
  }
  return false;
}

/// England's DXCC flag (dxccCode 223 in @ham2k/lib-dxcc-data's
/// dxccByCode.json) — black flag + Unicode tag sequence spelling "gbeng".
final String dxccFlagEngland =
    String.fromCharCodes([0x1F3F4, ...'gbeng'.codeUnits.map((c) => c + 0xE0000), 0xE007F]);
