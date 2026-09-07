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

import 'dart:async';
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
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox()))));
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();

      // A dialog dims the window — on while it's up, off once dismissed.
      unawaited(showDialog<void>(context: navigator.context, builder: (_) => const AlertDialog(content: Text('hi'))));
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isTrue);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isFalse);
    } finally {
      modalBarrierIsVisible.value = false;
    }
  });

  testWidgets('the dismissible signal follows the TOP dialog, not the first one up', (tester) async {
    // Chrome outside the navigator paints its own copy of the barrier, and a
    // copy that dismisses what the real one would not — or refuses what it
    // would — is worse than none. Stacked dialogs are where a single flag
    // set on the way in goes wrong: the second one's answer is the one that
    // counts while it is up, and the first one's again once it is gone.
    try {
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [ModalBarrierRouteObserver()],
        home: const Scaffold(body: SizedBox()),
      ));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(modalBarrierIsDismissible.value, isFalse, reason: 'nothing is up');

      unawaited(showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('first')),
      ));
      await tester.pumpAndSettle();
      expect(modalBarrierIsDismissible.value, isTrue);

      unawaited(showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(content: Text('second')),
      ));
      await tester.pumpAndSettle();
      expect(modalBarrierIsDismissible.value, isFalse, reason: "the top dialog refuses barrier dismissal");

      navigator.pop();
      await tester.pumpAndSettle();
      expect(modalBarrierIsDismissible.value, isTrue, reason: 'the first dialog is topmost again');

      navigator.pop();
      await tester.pumpAndSettle();
      expect(modalBarrierIsVisible.value, isFalse);
      expect(modalBarrierIsDismissible.value, isFalse);
    } finally {
      modalBarrierIsVisible.value = false;
      modalBarrierIsDismissible.value = false;
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

    // The measurement has to go through the ambient text scaler, because the
    // Text it decides for paints through it: measuring unscaled calls a line
    // that only overflows under OS/accessibility scaling a fit, so it neither
    // shrinks nor ellipsizes and the title runs off the row instead.
    //
    // A SHORT title, sized so the box is comfortable unscaled and impossible
    // at 2x — the long one's natural width already exceeds the 800pt test
    // surface, so its box gets clipped to the surface and the floor is hit
    // whatever the scaler does, which would make this pass either way.
    testWidgets('shrinks a line that only overflows because the OS text scale is large', (tester) async {
      const shortTitle = 'KI2D Field Day';
      final natural = (TextPainter(
        text: const TextSpan(text: shortTitle, style: style),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;
      expect(natural * 1.2, lessThan(760), reason: 'the box must fit the test surface, or the surface decides the result');

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: natural * 1.2,
                  child: shrinkToFitText(const Text(shortTitle, style: style)),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final rendered = tester.widget<Text>(find.text(shortTitle));
      // The floor is 75% of the SCALED size, not of the unscaled one: a
      // reader who asked for a 2x font keeps most of it.
      expect(
        rendered.style!.fontSize,
        style.fontSize! * 0.75,
        reason: 'measuring unscaled would see a fit and leave the size at 18',
      );
      // And at that floor it STILL doesn't fit — 2x is more than this box can
      // hold at any size the floor allows, so the line is shrunk AND
      // ellipsized. That is the accepted outcome, not an oversight: the
      // alternative is undoing the reader's font setting.
      expect(rendered.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.text(shortTitle)).width, lessThanOrEqualTo(natural * 1.2 + 0.5));
    });

    // The scaler tests above and below both land ON the 0.75 clamp, where a
    // wrong ratio — a scaler applied twice, say — clamps to the same 13.5 and
    // passes. This one sits strictly inside the range, so the number it
    // asserts is the ratio itself.
    testWidgets('picks the ratio, not the floor, when the scaled overflow is mild', (tester) async {
      const shortTitle = 'KI2D Field Day';
      const scaler = TextScaler.linear(2.0);
      final scaled = (TextPainter(
        text: const TextSpan(text: shortTitle, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout())
          .width;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: scaled * 0.9,
                  child: shrinkToFitText(const Text(shortTitle, style: style)),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final rendered = tester.widget<Text>(find.text(shortTitle));
      // Near the ratio, not exactly it: glyph advances don't scale perfectly
      // linearly with font size, so the verification pass can shave a little
      // off. What must hold is that the size came from the ratio rather than
      // the clamp, and that it actually fits.
      expect(rendered.style!.fontSize, closeTo(style.fontSize! * 0.9, 0.5));
      expect(rendered.style!.fontSize, greaterThan(style.fontSize! * 0.75));
      final fittedWidth = (TextPainter(
        text: TextSpan(text: shortTitle, style: rendered.style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout())
          .width;
      expect(fittedWidth, lessThanOrEqualTo(scaled * 0.9 + 0.5));
    });

    // A non-linear scaler (Android 14+ curves system font scaling: the
    // amplification tapers as the size grows) breaks the identity a single
    // ratio relies on — scale(F·s) == s·scale(F) — so the size picked from one
    // measurement can still overflow. What the helper promises is a line that
    // FITS, so the check is on the width the chosen style actually paints at.
    testWidgets('fits under a non-linear scaler, where one ratio is not enough', (tester) async {
      const shortTitle = 'KI2D Field Day';
      const scaler = _TaperingScaler();
      double widthAt(TextStyle s) => (TextPainter(
            text: TextSpan(text: shortTitle, style: s),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout())
              .width;

      final scaled = widthAt(style);
      // Wide enough that the floor is not what saves it: the fit has to come
      // from the size the helper chose.
      final boxWidth = scaled * 0.85;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: boxWidth, child: shrinkToFitText(const Text(shortTitle, style: style))),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final rendered = tester.widget<Text>(find.text(shortTitle));
      expect(rendered.style!.fontSize, greaterThan(style.fontSize! * 0.75), reason: 'the floor must not be what fits it');
      expect(widthAt(rendered.style!), lessThanOrEqualTo(boxWidth + 0.5));
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

/// A scaler whose amplification TAPERS with size, the way Android 14+'s
/// system font scaling curves: `scale(F·s) != s·scale(F)`, which is the
/// identity a single fit-ratio would rely on.
class _TaperingScaler extends TextScaler {
  const _TaperingScaler();

  @override
  double scale(double fontSize) => fontSize <= 10 ? fontSize * 2 : 20 + (fontSize - 10) * 1.1;

  @override
  double get textScaleFactor => 2;
}
