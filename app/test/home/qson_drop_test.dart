// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operations list takes a dropped QSON file as a new operation — a
// Developer Mode tool. The traps: an operator who is not a developer gets a
// drop target that imports whatever lands on the list; and because Logs,
// Chasing and Maps slide OVER the list rather than replacing it, and
// `desktop_drop` hands a drop to every target under the point, an ADIF file
// dropped on the Logs view would also be imported here as a broken operation.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';
import 'package:ham2k_logger/views/qson_import_flow.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> pumpHome(WidgetTester tester, {List<NavigatorObserver> observers = const []}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final services = (await makeHaLoServices()).services;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorObservers: observers,
          home: HomeView(services: services),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return services;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  // Offstage included: Home is hidden, not torn down, while another
  // destination is up, and its drop target is still laid out under the one on
  // screen — `enable` is all that keeps it from taking that view's drops.
  bool dropEnabled(WidgetTester tester) => tester
      .widget<DropTarget>(
        find.descendant(of: find.byType(QsonDropTarget, skipOffstage: false), matching: find.byType(DropTarget, skipOffstage: false), skipOffstage: false),
      )
      .enable;

  testWidgets('takes a drop only in Developer Mode, and only while the list is what shows', (tester) async {
    final services = await pumpHome(tester);
    addTearDown(() => homeRail.destination = HomeDestination.operations);

    expect(dropEnabled(tester), isFalse);

    await tester.runAsync(() => services.settings.setDeveloperMode(true));
    await tester.pumpAndSettle();
    expect(dropEnabled(tester), isTrue);

    homeRail.destination = HomeDestination.logs;
    await tester.pumpAndSettle();
    expect(dropEnabled(tester), isFalse);

    await unmount(tester);
  });

  testWidgets('takes no drop while its dock tab is behind another', (tester) async {
    // A dock group is an IndexedStack: the pane behind keeps its rect, and
    // would import a file dropped on the tab in front of it.
    final services = (await makeHaLoServices()).services;
    Future<void> pumpAt({required bool visible}) => tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: DockPaneVisibility(
            visible: visible,
            child: QsonDropTarget(services: services, enabled: true, child: const SizedBox()),
          ),
        ),
      ),
    );

    await pumpAt(visible: true);
    expect(dropEnabled(tester), isTrue);
    await pumpAt(visible: false);
    expect(dropEnabled(tester), isFalse);

    await unmount(tester);
  });

  testWidgets('an imported file opens as its own operation, and the next one imports too', (tester) async {
    // Two in a row: an in-flight claim never released would answer every
    // import after the first with "busy".
    final pushes = _PushCounter();
    final services = await pumpHome(tester, observers: [pushes]);
    final context = tester.element(find.byType(QsonDropTarget));
    XFile qson(String title) => XFile.fromData(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'operation': {'stationCall': 'N0DEV', 'userTitle': title},
            'qsos': [
              {
                'their': {'call': 'W1AW'},
                'band': '20m',
                'mode': 'CW',
                'startAtMillis': 1000,
              },
            ],
          }),
        ),
      ),
      name: '$title.qson',
      path: '$title.qson',
    );

    // The import awaits the route it pushes, so it is started rather than
    // awaited, and the push is waited for. Not through a drift stream: one
    // subscribed in a widget test never fires.
    Future<void> importAndWait(String title) async {
      final before = pushes.count;
      await tester.runAsync(() async {
        unawaited(runQsonImport(context, services, file: qson(title)));
        for (var tries = 0; pushes.count == before; tries++) {
          if (tries > 500) throw StateError('$title never opened');
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    }

    Future<List<String?>> openTitles() async => [
      for (final view in tester.widgetList<OperationView>(find.byType(OperationView, skipOffstage: false)))
        (await tester.runAsync(() => services.operations.get(view.operationUuid)))?.data['userTitle'] as String?,
    ];

    await importAndWait('first');
    expect(await openTitles(), ['first']);
    await importAndWait('second');
    expect(await openTitles(), unorderedEquals(['first', 'second']));

    await unmount(tester);
  });

  testWidgets('a file that is not QSON says so and creates nothing', (tester) async {
    final services = await pumpHome(tester);
    final context = tester.element(find.byType(QsonDropTarget));
    final file = XFile.fromData(Uint8List.fromList(utf8.encode('<eoh>')), name: 'log.adi', path: 'log.adi');

    await tester.runAsync(() => runQsonImport(context, services, file: file));
    await tester.pump();

    expect(find.textContaining('log.adi is not a JSON file'), findsOneWidget);
    expect(await tester.runAsync(() => services.operations.watchAll().first), isEmpty);

    await unmount(tester);
  });
}

class _PushCounter extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}
