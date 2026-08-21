// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Android back key/gesture on the panes Home shows IN PLACE — Settings
// and Logs. Each rides over Home inside HOME's route, so an unclaimed press
// pops that route and backgrounds the app, with the pane still the
// destination waiting on the way back in. What proves the press was handled
// is therefore not the widget tree (which is identical either way: the first
// route's `maybePop` bubbles, pops nothing, and asks the platform to leave)
// but whether `SystemNavigator.pop` reached the platform channel.
//
// The claim is also scoped: while a pane slides back OUT it is still mounted,
// and a press absorbed there would do nothing at all rather than
// backgrounding the app the way a press on Home does.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/logs_view.dart';
import 'package:ham2k_logger/views/settings_view.dart';

Future<HaLoServices> _services(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return HaLoServices(db, settings);
}

/// Records what the app asks of the platform — `SystemNavigator.pop` is the
/// app leaving, and the only observable difference between a handled back
/// press and an unhandled one.
List<String> _watchPlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

/// Through the shell the ROOT uses, not HomeView bare: the rail is a sibling
/// of the window's chrome, and Settings is shown in Home's place inside it.
Future<void> _pumpHome(WidgetTester tester, HaLoServices services, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: HomeRailShell(services: services, routes: HomeView(services: services))),
  ));
  await _settle(tester);
}

/// A BOUNDED pump. Never `pumpAndSettle`: Settings loads extensions and
/// accounts asynchronously and has no settled state to wait for, so a test
/// that asks for one gets the 10-minute timeout.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every destination the rail publishes, in order. A departing pane answering
/// a press it did not block shows up here as a destination nobody asked for,
/// even where the final answer happens to come out the same.
List<HomeDestination> _watchDestinations() {
  final seen = <HomeDestination>[];
  void record() => seen.add(homeRail.destination);
  homeRail.addListener(record);
  addTearDown(() => homeRail.removeListener(record));
  return seen;
}

/// What the engine sends for a system back press — flutter_test has no
/// helper for it at this version.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

/// Unmounts the tree and lets Home's chained timers (the FAB settle deadline,
/// the first-run nudge and the widget it then mounts) run out — otherwise the
/// binding asserts a pending timer, which reads as a hang rather than as the
/// teardown it is. Called at the end of each body, never from `addTearDown`:
/// that assertion runs before any tearDown gets a turn.
Future<void> _endOfTest(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 6));
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.cogOutline)));
  await _settle(tester);
  expect(find.byType(SettingsView), findsOneWidget, reason: 'the header cog is the only way in at this width');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the back press leaves Settings instead of leaving the app', (tester) async {
    final services = await _services(tester);
    // A phone: no rail, the cog in the header, and Settings a single column.
    await _pumpHome(tester, services, size: const Size(400, 800));
    await _openSettings(tester);

    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    expect(platformCalls, isNot(contains('SystemNavigator.pop')), reason: 'the app must not be asked to leave');
    expect(homeRail.destination, HomeDestination.operations);
    expect(find.byType(SettingsView), findsNothing, reason: 'the slide has finished by now');

    await _endOfTest(tester);
  });

  testWidgets('a press while Settings slides out is not swallowed by it', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(400, 800));
    await _openSettings(tester);

    await _systemBack(tester);
    // Mid-slide: Settings is still mounted, and no longer the destination.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SettingsView), findsOneWidget, reason: 'the guard below is about the mounted-but-going state');

    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    // Home's own answer to a back press — the double-tap-to-exit an operator
    // expects. Claimed by the departing Settings, the press would do nothing
    // and nothing would say so.
    expect(platformCalls, contains('SystemNavigator.pop'));

    await _endOfTest(tester);
  });

  testWidgets('on a narrow window a panel pops before Settings does', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(400, 800));
    await _openSettings(tester);

    await tester.tap(find.text('All Settings'));
    await _settle(tester);
    expect(find.text('Common Preferences'), findsNothing, reason: 'the panel covers the sidebar at this width');

    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    // The panel is a route of its own above Home's, so it pops on its own and
    // this never reaches the interception — one back press per screen, not a
    // press that throws the operator out of Settings from three levels in.
    expect(find.text('Common Preferences'), findsOneWidget, reason: 'back from a panel lands on the sidebar');
    expect(find.byType(SettingsView), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await _endOfTest(tester);
  });

  testWidgets('the back press leaves Logs instead of leaving the app', (tester) async {
    final services = await _services(tester);
    // The rail's Logs destination only exists with the experiment on.
    await services.settings.setExperimentEnabled('logs', true) /* stored key, see experiments.yaml */;
    addTearDown(() => homeRail.destination = HomeDestination.operations);
    await _pumpHome(tester, services, size: const Size(400, 800));

    homeRail.destination = HomeDestination.logs;
    await _settle(tester);
    expect(find.byType(LogsView), findsOneWidget);

    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    expect(platformCalls, isNot(contains('SystemNavigator.pop')), reason: 'the app must not be asked to leave');
    expect(homeRail.destination, HomeDestination.operations, reason: 'Logs has one sibling to return to');
    expect(find.byType(LogsView), findsNothing);

    await _endOfTest(tester);
  });

  testWidgets('a press while Logs slides out is not swallowed by it', (tester) async {
    final services = await _services(tester);
    await services.settings.setExperimentEnabled('logs', true) /* stored key, see experiments.yaml */;
    addTearDown(() => homeRail.destination = HomeDestination.operations);
    await _pumpHome(tester, services, size: const Size(400, 800));

    homeRail.destination = HomeDestination.logs;
    await _settle(tester);

    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LogsView), findsOneWidget, reason: 'the guard below is about the mounted-but-going state');

    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    expect(platformCalls, contains('SystemNavigator.pop'));

    await _endOfTest(tester);
  });

  testWidgets('the pane on its way out does not answer a press the live one blocked', (tester) async {
    final services = await _services(tester);
    await services.settings.setExperimentEnabled('logs', true) /* stored key, see experiments.yaml */;
    addTearDown(() => homeRail.destination = HomeDestination.operations);
    await _pumpHome(tester, services, size: const Size(400, 800));

    homeRail.destination = HomeDestination.logs;
    await _settle(tester);
    homeRail.destination = HomeDestination.settings;
    // Mid-slide, with BOTH panes mounted: Settings arriving, Logs leaving.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LogsView), findsOneWidget);
    expect(find.byType(SettingsView), findsOneWidget);

    final destinations = _watchDestinations();
    final platformCalls = _watchPlatformCalls(tester);
    await _systemBack(tester);
    await _settle(tester);

    // One press, one answer — Settings blocked it, so Settings alone answers,
    // and it returns to where the operator was. The departing Logs pane
    // writing `operations` on its way past would flip the destination twice
    // in one turn and bill Home for a visit that never happened.
    expect(destinations, [HomeDestination.logs]);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await _endOfTest(tester);
  });
}
