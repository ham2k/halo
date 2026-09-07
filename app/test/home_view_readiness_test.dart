// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dev bridge's `ready` promise (#239) is what lets agents await boot
// instead of sleeping a guessed interval. HomeView resolves it the moment its
// operations stream first emits (bootstrap done + first data load in) — but
// only when the bridge is actually installed. These pin both: it fires, and it
// stays inert on native/production where nothing installed the bridge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/config/dev_bridge.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/home_view.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> makeServices() async {
    return (await makeHaLoServices()).services;
  }

  Widget wrap(HaLoServices services) => TranslationProvider(
        child: MaterialApp(home: HomeView(services: services)),
      );

  testWidgets('resolves ready once the operations list first loads (bridge installed)', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    DevBridge.instance.resetReadyForTest();
    DevBridge.instance.installed = true;
    addTearDown(() => DevBridge.instance.installed = false);

    var ready = false;
    // ignore: unawaited_futures — asserted via the flag after settling.
    DevBridge.instance.ready.then((_) => ready = true);

    await tester.pumpWidget(wrap(await makeServices()));
    await tester.pumpAndSettle();

    expect(ready, isTrue, reason: 'the first operations-list snapshot should have signalled readiness');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5)); // drain home's debounce/clock timers
  });

  testWidgets('does not resolve ready when the bridge is not installed', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    DevBridge.instance.resetReadyForTest();
    DevBridge.instance.installed = false;

    var ready = false;
    // ignore: unawaited_futures — asserted via the flag after settling.
    DevBridge.instance.ready.then((_) => ready = true);

    await tester.pumpWidget(wrap(await makeServices()));
    await tester.pumpAndSettle();

    expect(ready, isFalse, reason: 'native/production must not resolve a promise nothing exposes');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
