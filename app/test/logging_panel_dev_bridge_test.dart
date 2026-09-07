// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingPanel wires the dev bridge's action handlers (window.__halo
// setField/tap) to its LoggingControls, but ONLY when the bridge is installed,
// and its dispose must not clobber the handlers if a newer panel has already
// taken them over. That handoff guard is the load-bearing bit: it's what keeps
// a panel torn down *after* its replacement mounted from leaving the bridge
// dead. These tests pin both halves.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/config/dev_bridge.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    // Pretend the web bridge is installed (dev/preview build) so the panel
    // registers its handlers. Start from a clean slate.
    DevBridge.instance.installed = true;
    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
  });

  tearDown(() {
    DevBridge.instance.installed = false;
    DevBridge.instance.setFieldHandler = null;
    DevBridge.instance.actionHandler = null;
  });

  Widget wrap(Widget child) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 800, child: child),
          ),
        ),
      );

  LoggingPanel panel(Key key) => LoggingPanel(
        key: key,
        operation: operation,
        services: services,
        qsos: const [],
        loggingControls: const [],
        onCommandAction: (action, [params]) async {},
      );

  testWidgets('registers action handlers on mount and clears them on dispose', (tester) async {
    await tester.pumpWidget(wrap(panel(const ValueKey('a'))));
    await tester.pump(const Duration(milliseconds: 100));

    expect(DevBridge.instance.setFieldHandler, isNotNull);
    expect(DevBridge.instance.actionHandler, isNotNull);

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5)); // drain the controls' debounce/clock timers

    expect(DevBridge.instance.setFieldHandler, isNull);
    expect(DevBridge.instance.actionHandler, isNull);
  });

  testWidgets('a disposing panel does not clobber a newer panel that took over', (tester) async {
    await tester.pumpWidget(wrap(panel(const ValueKey('a'))));
    await tester.pump(const Duration(milliseconds: 100));
    final handlerA = DevBridge.instance.actionHandler;
    expect(handlerA, isNotNull);

    // Swap in a second panel at the same slot with a different key: the new
    // element inflates (panel B's initState re-registers) BEFORE the old one
    // unmounts (panel A's dispose). If the guard were an unconditional clear,
    // A's dispose would null out B's freshly-registered handlers.
    await tester.pumpWidget(wrap(panel(const ValueKey('b'))));
    await tester.pump(const Duration(milliseconds: 100));

    expect(DevBridge.instance.actionHandler, isNotNull,
        reason: 'panel A dispose must not clear the handlers panel B just registered');
    expect(DevBridge.instance.setFieldHandler, isNotNull);
    expect(DevBridge.instance.actionHandler, isNot(same(handlerA)),
        reason: 'panel B should now own the bridge');

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5));
    expect(DevBridge.instance.actionHandler, isNull);
  });

  testWidgets('does not register when the bridge is not installed', (tester) async {
    DevBridge.instance.installed = false;

    await tester.pumpWidget(wrap(panel(const ValueKey('a'))));
    await tester.pump(const Duration(milliseconds: 100));

    expect(DevBridge.instance.setFieldHandler, isNull);
    expect(DevBridge.instance.actionHandler, isNull);

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5));
  });
}
