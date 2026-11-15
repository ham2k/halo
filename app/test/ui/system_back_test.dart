// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The system back over the startup overlays, which are painted above the
// Navigator and so are no route it could pop. Unclaimed, a back over them at
// Home leaves the app with the overlay still showing on the way back in, and
// a tablet keyboard often sends Back from its Escape key. What proves the
// press was handled is that `SystemNavigator.pop` never reached the platform
// channel.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/app_shell/system_back.dart';
import 'package:ham2k_logger/views/release_overlay.dart';
import 'package:ham2k_logger/views/tester_overlay.dart';

import '../support/halo_test_support.dart';

/// What the engine sends for a system back press.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await settleFrames(tester);
}

void main() {
  testWidgets('a back closes the tester notes, then the release notes under them, and only then leaves the app', (tester) async {
    final services = (await makeHaLoServices()).services;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    bool? handlesBack() =>
        calls.lastWhere((c) => c.method == 'SystemNavigator.setFrameworkHandlesBack', orElse: () => const MethodCall('none')).arguments as bool?;
    bool left() => calls.any((c) => c.method == 'SystemNavigator.pop');

    // Ahead of the MaterialApp, as HaLoApp attaches it: after the
    // Navigator's observer it would never be asked.
    systemBack.attach();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigator,
          // As HaLoApp wires it.
          onNavigationNotification: systemBack.onNavigationNotification,
          builder: (context, child) => TesterOverlayGate(
            services: services,
            child: ReleaseOverlayGate(services: services, child: child!),
          ),
          home: const Text('Home'),
        ),
      ),
    );
    // The tester notes first: the back must go to the one painted on top,
    // not to the one that came up last.
    services.devTesterTrigger.trigger();
    await settleFrames(tester);
    services.devSplashTrigger.trigger();
    await settleFrames(tester);
    expect(find.byType(TesterOverlayView), findsOneWidget);
    expect(find.byType(ReleaseOverlayView), findsOneWidget);
    // Up before the app was: nothing may reach the engine until it is, and
    // the claim must not be lost for having come too early.
    expect(handlesBack(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(handlesBack(), isTrue, reason: 'at the first route, Android sends the press to the app only if told to');

    // A route change under the covers: WidgetsApp's own answer to it would
    // tell Android only what the Navigator can pop — nothing, back at Home.
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('Pushed'))));
    await settleFrames(tester);
    navigator.currentState!.pop();
    await settleFrames(tester);
    expect(handlesBack(), isTrue, reason: 'the covers still claim the back at Home');

    await _systemBack(tester);
    expect(find.byType(TesterOverlayView), findsNothing);
    expect(find.byType(ReleaseOverlayView), findsOneWidget);
    expect(left(), isFalse);

    await _systemBack(tester);
    expect(find.byType(ReleaseOverlayView), findsNothing);
    expect(left(), isFalse);
    expect(handlesBack(), isFalse, reason: 'with nothing covering Home, a back is Android\'s again');

    await _systemBack(tester);
    expect(left(), isTrue);
    expect(find.text('Home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
