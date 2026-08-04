// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The chromeless macOS window (MainFlutterWindow.swift) has no native title
// bar, so double-click-to-zoom would be lost entirely unless the app's own
// header provides it — windowHeaderGestureArea is that replacement. These
// tests pin the two halves of its contract: the empty header background
// reports double-clicks over the window-chrome channel, and header buttons
// still win hit-testing (a double-click on a button must act on the button,
// never zoom the window under it).

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const channel = MethodChannel('ham2k/window_chrome');

  Widget host({VoidCallback? onSettingsPressed}) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            flexibleSpace: windowHeaderGestureArea(),
            title: const Text('Title'),
            actions: [
              IconButton(icon: const Icon(MdiIcons.cog), onPressed: onSettingsPressed ?? () {}),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      );

  Future<void> doubleTapAt(WidgetTester tester, Offset location) async {
    await tester.tapAt(location);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(location);
    // Let the double-tap recognizer resolve.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('double-click on empty header background reports over the window-chrome channel', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await tester.pumpWidget(host());

      // Empty background: horizontally between the title text and the
      // settings action.
      final appBar = tester.getRect(find.byType(AppBar));
      final titleRight = tester.getTopRight(find.text('Title')).dx;
      final actionLeft = tester.getTopLeft(find.byIcon(MdiIcons.cog)).dx;
      await doubleTapAt(tester, Offset((titleRight + actionLeft) / 2, appBar.center.dy));

      expect(calls.map((c) => c.method), ['performHeaderDoubleClickAction']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('double-click on a header button acts on the button, not the window', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      var pressed = 0;
      await tester.pumpWidget(host(onSettingsPressed: () => pressed++));

      await doubleTapAt(tester, tester.getCenter(find.byIcon(MdiIcons.cog)));

      expect(pressed, 2);
      expect(calls, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('traffic-light clearance collapses in native full screen', (tester) async {
    // In full screen the buttons leave the header for the system's
    // auto-hiding titlebar overlay, so headers must stop reserving space
    // for them and align leading content with the window edge.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      double? clearance;
      Widget host(bool fullScreen) => MacOSFullScreenScope(
            isFullScreen: fullScreen,
            child: Builder(builder: (context) {
              clearance = macOSTrafficLightClearance(context);
              return const SizedBox();
            }),
          );

      await tester.pumpWidget(host(false));
      expect(clearance, macOSTrafficLightInset + macOSTrafficLightGap);

      await tester.pumpWidget(host(true));
      expect(clearance, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('off macOS and Windows the helper contributes no flexibleSpace', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(windowHeaderGestureArea(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('on Windows, dragging the empty header background starts a window drag', (tester) async {
    // The chromeless Windows window has no caption at all, so the header
    // drag is the ONLY way to move the window.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await tester.pumpWidget(host());

      final appBar = tester.getRect(find.byType(AppBar));
      final titleRight = tester.getTopRight(find.text('Title')).dx;
      final actionLeft = tester.getTopLeft(find.byIcon(MdiIcons.cog)).dx;
      final empty = Offset((titleRight + actionLeft) / 2, appBar.center.dy);

      await tester.dragFrom(empty, const Offset(40, 0));
      // Flush the sibling double-tap recognizer's timeout.
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls.map((c) => c.method), ['startWindowDrag']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('on Linux, dragging the empty header background starts a window drag', (tester) async {
    // Same as Windows: the chromeless Linux window has no caption at all, so
    // the header drag is the ONLY way to move the window.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await tester.pumpWidget(host());

      final appBar = tester.getRect(find.byType(AppBar));
      final titleRight = tester.getTopRight(find.text('Title')).dx;
      final actionLeft = tester.getTopLeft(find.byIcon(MdiIcons.cog)).dx;
      final empty = Offset((titleRight + actionLeft) / 2, appBar.center.dy);

      await tester.dragFrom(empty, const Offset(40, 0));
      // Flush the sibling double-tap recognizer's timeout.
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls.map((c) => c.method), ['startWindowDrag']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('the traffic-light mask paints the header colour fading to transparent, at fixed clearance width',
      (tester) async {
    // The mask hides header content that animates through the top-left corner
    // under the native buttons: it must be the header's own colour (invisible
    // against the header) and fade to transparent toward the content so masked
    // elements dissolve rather than hard-clip at its edge.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      const headerColor = Color(0xFF123456);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(appBarTheme: const AppBarTheme(backgroundColor: headerColor, toolbarHeight: 48)),
        home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: MacOSTrafficLightMask())),
      ));

      final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byType(MacOSTrafficLightMask),
        matching: find.byType(DecoratedBox),
      ));
      final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      // Opaque header colour on the left (under the buttons)…
      expect(gradient.colors.first, headerColor);
      expect(gradient.begin, Alignment.centerLeft);
      // …fading to fully transparent on the right (toward the header content).
      expect(gradient.colors.last, headerColor.withValues(alpha: 0));
      expect(gradient.end, Alignment.centerRight);

      // Fixed physical clearance width (the buttons don't scale), full header
      // height.
      final size = tester.getSize(find.byType(MacOSTrafficLightMask));
      expect(size.width, macOSTrafficLightInset + macOSTrafficLightGap);
      expect(size.height, 48);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the traffic-light mask lets the header zoom gesture through underneath it', (tester) async {
    // The mask overlays the header's top-left corner, but the native buttons
    // don't fill it — a double-click in the gaps must still reach the header
    // gesture area and zoom the window, so the mask has to be transparent to
    // pointers.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      // Mirror main.dart: the mask is overlaid on top of the header.
      await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
          Scaffold(
            appBar: AppBar(automaticallyImplyLeading: false, flexibleSpace: windowHeaderGestureArea()),
            body: const SizedBox.expand(),
          ),
          const Positioned(top: 0, left: 0, child: MacOSTrafficLightMask()),
        ]),
      ));

      await doubleTapAt(tester, tester.getRect(find.byType(MacOSTrafficLightMask)).center);

      expect(calls.map((c) => c.method), ['performHeaderDoubleClickAction']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('the traffic-light mask collapses to nothing in native full screen', (tester) async {
    // No buttons float over the header in full screen (they move to the
    // system's auto-hiding overlay), so there is nothing to mask.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(const MacOSFullScreenScope(
        isFullScreen: true,
        child: MaterialApp(home: Scaffold(body: MacOSTrafficLightMask())),
      ));

      expect(
        find.descendant(of: find.byType(MacOSTrafficLightMask), matching: find.byType(DecoratedBox)),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('off macOS the traffic-light mask renders nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MacOSTrafficLightMask())));

      expect(
        find.descendant(of: find.byType(MacOSTrafficLightMask), matching: find.byType(DecoratedBox)),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows caption buttons drive the window over the channel', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topRight, child: WindowsCaptionButtons())),
      ));

      await tester.tap(find.byIcon(MdiIcons.windowMinimize));
      await tester.tap(find.byIcon(MdiIcons.windowMaximize));
      await tester.tap(find.byIcon(MdiIcons.windowClose));

      expect(calls.map((c) => c.method), ['minimizeWindow', 'toggleMaximizeWindow', 'closeWindow']);

      // The native side pushes the maximize state; the middle button's glyph
      // must follow it so it reads restore-vs-maximize truthfully.
      windowsWindowIsMaximized.value = true;
      await tester.pump();
      expect(find.byIcon(MdiIcons.windowRestore), findsOneWidget);
      expect(find.byIcon(MdiIcons.windowMaximize), findsNothing);
    } finally {
      windowsWindowIsMaximized.value = false;
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('the traffic-light mask hides while a dialog barrier dims the window', (tester) async {
    // A modal barrier darkens the whole header; a bright same-as-header box in
    // the corner over that dim would read as a stray rectangle, so the mask
    // steps aside (as the release/onboarding overlays already do by z-order).
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      Finder maskBox() =>
          find.descendant(of: find.byType(MacOSTrafficLightMask), matching: find.byType(DecoratedBox));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MacOSTrafficLightMask())));
      expect(maskBox(), findsOneWidget);

      modalBarrierIsVisible.value = true;
      await tester.pump();
      expect(maskBox(), findsNothing);

      modalBarrierIsVisible.value = false;
      await tester.pump();
      expect(maskBox(), findsOneWidget);
    } finally {
      modalBarrierIsVisible.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ModalBarrierRouteObserver flips the signal for dimming dialogs, not plain page routes', (tester) async {
    try {
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [ModalBarrierRouteObserver()],
        home: const Scaffold(body: SizedBox()),
      ));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(modalBarrierIsVisible.value, isFalse);

      // An opaque page route has no barrier — it must NOT hide the mask.
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();

      // A dialog dims the window — on while it's up, off once dismissed.
      showDialog<void>(context: navigator.context, builder: (_) => const AlertDialog(content: Text('hi')));
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isTrue);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isFalse);
    } finally {
      modalBarrierIsVisible.value = false;
    }
  });

  group('shrinkToFit', () {
    // A header title that overflows must still read the full text (issue
    // #182) — the old `overflow: TextOverflow.ellipsis` truncated it
    // instead. Constraining width via a fixed-size SizedBox ancestor
    // (rather than the whole window) keeps the natural-vs-fitted contrast
    // deterministic regardless of surrounding chrome.
    Widget host(String text, double width) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: shrinkToFit(Text(text))),
            ),
          ),
        );

    testWidgets('renders at natural size, unscaled, when the text already fits', (tester) async {
      await tester.pumpWidget(host('Short', 300));
      expect(find.text('Short'), findsOneWidget);

      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fittedBox.fit, BoxFit.scaleDown);
      // scaleDown never enlarges past 1.0, and 'Short' comfortably fits 300px.
      final rendered = tester.getSize(find.text('Short'));
      final natural = _naturalTextWidth(tester, find.text('Short'));
      expect(rendered.width, closeTo(natural, 0.5));
    });

    testWidgets('shrinks a too-wide title to fit, reading the full text rather than truncating', (tester) async {
      const longTitle = 'KI2D A Very Long Operation Title That Would Have Been Ellipsized Before';
      await tester.pumpWidget(host(longTitle, 120));

      expect(tester.takeException(), isNull);
      // The full string is present — not a shortened/ellipsized substring.
      expect(find.text(longTitle), findsOneWidget);

      // The Text's own RenderBox lays out at its natural, unconstrained
      // size (FittedBox gives its child loose constraints) — the shrink is
      // a paint-time transform, invisible to `getSize` on the Text itself.
      // The FittedBox reports back the OUTER (constrained-to-120) size, so
      // a FittedBox visibly narrower than the text it contains is the
      // paint-time-scaling signature.
      final textNaturalWidth = tester.getSize(find.text(longTitle)).width;
      final fittedBoxWidth = tester.getSize(find.byType(FittedBox)).width;
      expect(textNaturalWidth, greaterThan(120), reason: 'title must actually be too wide to fit for this test to be meaningful');
      expect(fittedBoxWidth, lessThanOrEqualTo(120.5));
      expect(fittedBoxWidth, lessThan(textNaturalWidth), reason: 'text should have scaled down, not overflowed or truncated');
    });
  });

  group('shrinkToFitText', () {
    const longTitle = 'KI2D A Very Long Operation Title That Would Have Been Ellipsized Before';
    const style = TextStyle(fontSize: 18);

    double naturalWidth(WidgetTester tester) {
      final painter = TextPainter(text: const TextSpan(text: longTitle, style: style), textDirection: TextDirection.ltr)
        ..layout();
      return painter.width;
    }

    Widget host(double width) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: shrinkToFitText(const Text(longTitle, style: style))),
            ),
          ),
        );

    testWidgets('reads the full text, scaled down but above the 75% floor, when moderately too wide', (tester) async {
      final natural = naturalWidth(tester);
      // Comfortably requires a scale between the floor and 1.0.
      await tester.pumpWidget(host(natural * 0.85));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longTitle), findsOneWidget);

      final rendered = tester.widget<Text>(find.text(longTitle));
      final scale = rendered.style!.fontSize! / style.fontSize!;
      expect(scale, inInclusiveRange(0.75, 1.0));
    });

    testWidgets('locks at the 75% floor and relies on ellipsis for the rest', (tester) async {
      final natural = naturalWidth(tester);
      final width = natural * 0.2;
      // Would need well under a 75% scale to avoid overflowing — the floor
      // must win, with the residual overflow handled by ellipsis instead.
      await tester.pumpWidget(host(width));
      await tester.pump();

      expect(tester.takeException(), isNull);

      final rendered = tester.widget<Text>(find.text(longTitle));
      expect(rendered.style!.fontSize, style.fontSize! * 0.75, reason: 'font size should lock at the 75% floor, not keep shrinking');
      expect(rendered.overflow, TextOverflow.ellipsis);
      expect(rendered.maxLines, 1);

      // Unlike shrinkToFit's FittedBox (which reports the OUTER constrained
      // size while the child stays at its natural, unclipped size), Text
      // lays itself out AT the given constraint — so a width close to what
      // was given (rather than to `natural * 0.75`) is the signature of the
      // ellipsis actually clipping the overflow, not silently overflowing.
      final renderedWidth = tester.getSize(find.text(longTitle)).width;
      expect(renderedWidth, lessThanOrEqualTo(width + 0.5));
    });

    testWidgets('condensed defaults to false — a title never gets the width-axis treatment', (tester) async {
      final natural = naturalWidth(tester);
      await tester.pumpWidget(host(natural * 0.2)); // needs the floor regardless
      await tester.pump();

      final rendered = tester.widget<Text>(find.text(longTitle));
      expect(rendered.style!.fontVariations, isNull);
    });

    // #361: a subtitle should narrow (Roboto's variable 'wdth' axis, 100
    // Normal -> 75 Condensed) before its font size shrinks at all — a
    // condensed render at full size stays legible, unlike a smaller one.
    // Needs the REAL Roboto.ttf (the axis doesn't exist on flutter_test's
    // built-in stand-in font), loaded once for this group only — no other
    // test file in the repo does this; keep it scoped here.
    group('condensed', () {
      const condensedStyle = TextStyle(fontSize: 18, fontFamily: 'Roboto');

      setUpAll(() async {
        final bytes = await File('../../app/assets/fonts/Roboto.ttf').readAsBytes();
        final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
      });

      double widthOf(TextStyle style) => (TextPainter(
            text: TextSpan(text: longTitle, style: style),
            textDirection: TextDirection.ltr,
          )..layout())
          .width;

      Widget condensedHost(double width) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: shrinkToFitText(const Text(longTitle, style: condensedStyle), condensed: true),
                ),
              ),
            ),
          );

      testWidgets('narrows the glyphs at full size when that alone is enough to fit', (tester) async {
        final natural = widthOf(condensedStyle);
        final condensed = widthOf(condensedStyle.copyWith(fontVariations: const [FontVariation('wdth', 75)]));
        expect(condensed, lessThan(natural), reason: 'the real Roboto VF must actually narrow at wdth=75 for this test to be meaningful');

        // Between the two: condensing alone fits, no font-size shrink needed.
        final width = (natural + condensed) / 2;
        await tester.pumpWidget(condensedHost(width));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final rendered = tester.widget<Text>(find.text(longTitle));
        expect(rendered.style!.fontVariations, contains(const FontVariation('wdth', 75)));
        expect(rendered.style!.fontSize, condensedStyle.fontSize, reason: 'condensing should avoid needing any font-size shrink here');
      });

      testWidgets('still shrinks the font size (condensed) once condensing alone is not enough', (tester) async {
        final condensed = widthOf(condensedStyle.copyWith(fontVariations: const [FontVariation('wdth', 75)]));
        final width = condensed * 0.85; // condensed alone still overflows this

        await tester.pumpWidget(condensedHost(width));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final rendered = tester.widget<Text>(find.text(longTitle));
        expect(rendered.style!.fontVariations, contains(const FontVariation('wdth', 75)), reason: 'condensed width should still be used as the base to shrink from');
        expect(rendered.style!.fontSize, lessThan(condensedStyle.fontSize!));
        expect(rendered.style!.fontSize, greaterThanOrEqualTo(condensedStyle.fontSize! * 0.75));
      });

      testWidgets('does not condense when the text already fits', (tester) async {
        final natural = widthOf(condensedStyle);
        await tester.pumpWidget(condensedHost(natural * 1.5));
        await tester.pump();

        final rendered = tester.widget<Text>(find.text(longTitle));
        expect(rendered.style!.fontVariations, isNull);
        expect(rendered.style!.fontSize, condensedStyle.fontSize);
      });
    });
  });
}

/// The width [finder]'s Text would occupy laid out with no width constraint
/// — i.e. before any FittedBox scaling is applied.
double _naturalTextWidth(WidgetTester tester, Finder finder) {
  final textWidget = tester.widget<Text>(finder);
  final painter = TextPainter(
    text: TextSpan(text: textWidget.data, style: DefaultTextStyle.of(tester.element(finder)).style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}
