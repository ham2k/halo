// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's half of GO (`navigation-commands`): the `navigate` action. The
// extension already leaves out places this app has turned off, but the
// action is SDK surface any extension can send — so the app refuses those
// places itself, rather than letting the rail fall back to Operations or
// Settings open its first panel, either of which reads as GO going to the
// wrong place.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/command_actions.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/views/app_shell/home_rail_state.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => homeRail.destination = HomeDestination.operations);

  /// What the action said, if anything — with no bar asking, it lands on the
  /// status bar.
  String? said(HaLoServices services) => services.statusBar.items.where((i) => i.key == 'commandAction').map((i) => i.text).firstOrNull;

  testWidgets('a Home destination moves the rail there, saying nothing', (tester) async {
    final services = (await makeHaLoServices()).services;
    expect(await runCommandAction(services, 'navigate', {'to': 'maps'}), isFalse, reason: 'the place itself is the answer');
    expect(homeRail.destination, HomeDestination.maps);
  });

  testWidgets('a destination behind an experiment that is off is refused, not swapped', (tester) async {
    final services = (await makeHaLoServices()).services;
    expect(await runCommandAction(services, 'navigate', {'to': 'logs'}), isTrue);
    expect(said(services), t.commands.goUnavailable(place: t.home.nav.logs));
    expect(homeRail.destination, HomeDestination.operations, reason: 'the rail stays where it was');

    await services.settings.setExperimentEnabled('logs', true);
    expect(await runCommandAction(services, 'navigate', {'to': 'logs'}), isFalse);
    expect(homeRail.destination, HomeDestination.logs);
  });

  testWidgets('a Settings panel that is turned off is refused', (tester) async {
    final services = (await makeHaLoServices()).services;
    expect(await runCommandAction(services, 'navigate', {'to': 'peers'}), isTrue);
    expect(said(services), t.commands.goUnavailable(place: t.settings.panels.peers));
    expect(await runCommandAction(services, 'navigate', {'to': 'developer'}), isTrue);
    expect(said(services), t.commands.goUnavailable(place: t.settings.panels.developerSettings));
  });

  testWidgets('a place the app does not know is an error, not silence', (tester) async {
    final services = (await makeHaLoServices()).services;
    expect(await runCommandAction(services, 'navigate', {'to': 'nowhere'}), isTrue);
    expect(said(services), t.commands.goUnknown(to: 'nowhere'));
  });

  testWidgets('a dialog that refuses to close stops GO, and stays up', (tester) async {
    // An import's progress dialog: `popUntil` does not ask PopScope, and a
    // dialog popped out from under the code driving it has that code pop
    // whatever is on top once it finishes — Home itself, leaving nothing.
    final services = (await makeHaLoServices()).services;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    unawaited(
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const PopScope(canPop: false, child: Text('importing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(await runCommandAction(services, 'navigate', {'to': 'maps'}), isTrue);
    await tester.pumpAndSettle();
    expect(said(services), t.commands.goBlocked);
    expect(find.text('importing'), findsOneWidget);
    expect(homeRail.destination, HomeDestination.operations);
  });
}
