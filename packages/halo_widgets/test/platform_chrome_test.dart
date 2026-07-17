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
              IconButton(icon: const Icon(Icons.settings), onPressed: onSettingsPressed ?? () {}),
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
      final actionLeft = tester.getTopLeft(find.byIcon(Icons.settings)).dx;
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

      await doubleTapAt(tester, tester.getCenter(find.byIcon(Icons.settings)));

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
      final actionLeft = tester.getTopLeft(find.byIcon(Icons.settings)).dx;
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
}
