// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the Swiss face is allowed to sweep.
//
// This is the only repeating animation in the app, and the two ways it can be
// wrong are opposites that look identical in a screenshot: a controller that
// never stops burns the display's refresh rate in a pane nobody is looking at
// — a dock group is an IndexedStack, so a hidden pane stays mounted and there
// is no TickerMode over it — and a controller that stops without restarting
// leaves a clock frozen at whatever time it was hidden, which is worse than
// showing nothing.
//
// `animate: true` throughout: the pane defaults the sweep OFF under
// `flutter test`, because a repeating controller has no settle point and
// `pumpAndSettle` would hang here and report the timeout against whatever
// test ran next. Nothing below calls `pumpAndSettle`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/clock/clock_panel.dart';

import 'fake_panel_extensions.dart';

void main() {
  PanelService serviceWith(Map<String, dynamic> config) {
    final service = PanelService(FakePanelExtensions(config: config));
    service.registerNative(const PanelDefinition(
      id: 'clock',
      title: 'Clock',
      source: PanelSource.native,
      multiple: true,
      formFields: [
        {'type': 'field', 'key': clockFaceKey, 'fieldType': 'select'},
        {'type': 'field', 'key': clockZoneKey, 'fieldType': 'select'},
        {'type': 'field', 'key': clockShowSecondsKey, 'fieldType': 'checkbox'},
      ],
    ));
    return service;
  }

  Future<void> pump(
    WidgetTester tester, {
    required PanelService service,
    required bool visible,
    bool animate = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DockPaneVisibility(
          visible: visible,
          child: ClockPanel(panelId: 'clock#1', panels: service, animate: animate),
        ),
      ),
    ));
    // Two pumps, never pumpAndSettle: the config read is a microtask and the
    // sweep would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Whether anything is asking for frames. A running AnimationController is
  /// the only source of these here.
  bool ticking(WidgetTester tester) => tester.binding.transientCallbackCount > 0;

  testWidgets('the Swiss face sweeps while it is on screen', (tester) async {
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: true);
    expect(ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a pane behind another tab does not sweep', (tester) async {
    // An IndexedStack keeps it mounted and built. Without the visibility gate
    // a four-pane layout animates three panes nobody can see.
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: false);
    expect(ticking(tester), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('coming back to the top starts it again', (tester) async {
    // The other half, and the one that fails silently: stopping on hide but
    // never restarting leaves a clock that is merely wrong.
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: false);
    expect(ticking(tester), isFalse);
    await pump(tester, service: service, visible: true);
    expect(ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a hidden app stops it, and a resumed one starts it', (tester) async {
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: true);
    expect(ticking(tester), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(ticking(tester), isFalse, reason: 'a minimized window must not animate');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a merely unfocused desktop window keeps sweeping', (tester) async {
    // `inactive` on desktop means the window lost FOCUS while still fully on
    // screen. Treating it as hidden freezes a clock the operator is looking
    // at, which reads as a hang.
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(ticking(tester), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the faces that only need one second a second never animate', (tester) async {
    // LCD and analog ride the shared WallClock heartbeat, which is already
    // running for the whole app. Starting a controller for them would add a
    // per-pane repaint at the display's refresh rate for a readout that
    // changes once a second.
    for (final face in [clockFaceLcd, clockFaceAnalog]) {
      final service = serviceWith({clockFaceKey: face, clockShowSecondsKey: true});
      await pump(tester, service: service, visible: true);
      expect(ticking(tester), isFalse, reason: '$face must not run a controller');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a Swiss face with no second hand has nothing to sweep', (tester) async {
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: false});
    await pump(tester, service: service, visible: true);
    expect(ticking(tester), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every face that is not sweeping still has something rebuilding it', (tester) async {
    // The trap: routing the builder by FACE rather than by whether the sweep
    // is this pane's clock. A Swiss face with its second hand off runs no
    // controller, so under an AnimatedBuilder nothing would ever rebuild it —
    // it would paint the minute it mounted on and hold that for the session,
    // looking like a perfectly good clock that happens to be wrong.
    for (final config in [
      {clockFaceKey: clockFaceSwiss, clockShowSecondsKey: false},
      {clockFaceKey: clockFaceLcd, clockShowSecondsKey: true},
      {clockFaceKey: clockFaceAnalog, clockShowSecondsKey: false},
    ]) {
      final service = serviceWith(config);
      await pump(tester, service: service, visible: true);
      expect(find.byType(OncePerSecond), findsOneWidget, reason: '$config has no rebuild source');
      await tester.pumpWidget(const SizedBox());
    }

    // And the one that IS driven by the sweep does not also carry a
    // per-second rebuild it does not need.
    final sweeping = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: sweeping, visible: true);
    expect(find.byType(OncePerSecond), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing takes the controller with it', (tester) async {
    // A leaked ticker outlives the pane and keeps the whole app awake. The
    // long pump after unmounting is what turns that into a failure HERE
    // rather than a timeout in an unrelated test later.
    final service = serviceWith({clockFaceKey: clockFaceSwiss, clockShowSecondsKey: true});
    await pump(tester, service: service, visible: true);
    expect(ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(ticking(tester), isFalse);
  });
}
