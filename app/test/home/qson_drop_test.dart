// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operations list takes a QSON file as a new operation. The trap:
// because Logs, Chasing and Maps slide OVER the list rather than replacing
// it, a list still counted as on screen there would be offered a file opened
// while the operator is looking at Logs.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';
import 'package:ham2k_logger/views/file_open/file_destinations.dart';
import 'package:ham2k_logger/views/file_open/file_kind.dart';
import 'package:ham2k_logger/views/file_open/file_router.dart';
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

  final aQson = XFile.fromData(Uint8List(0), name: 'a.qson', path: 'a.qson');

  /// The destinations on screen that would take a QSON file.
  List<FileDestination> takingQson() => [
    for (final destination in FileSuggestions.onScreen())
      if (destination.takes(HaloFileKind.qson, aQson)) destination,
  ];

  testWidgets('takes a QSON file only while the list is what shows', (tester) async {
    await pumpHome(tester);
    addTearDown(() => homeRail.destination = HomeDestination.operations);

    expect(takingQson().map((d) => d.id), ['qson:operation']);

    homeRail.destination = HomeDestination.logs;
    await tester.pumpAndSettle();
    expect(takingQson(), isEmpty);

    await unmount(tester);
  });

  testWidgets('takes no file while its dock tab is behind another', (tester) async {
    // A dock group is an IndexedStack: the pane behind keeps its rect and
    // stays mounted, and would be offered a file meant for the tab in front.
    final services = (await makeHaLoServices()).services;
    Future<void> pumpAt({required bool visible}) => tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: DockPaneVisibility(
            visible: visible,
            child: FileSuggestions(suggestions: [qsonFileDestination(services)], child: const SizedBox()),
          ),
        ),
      ),
    );

    await pumpAt(visible: true);
    expect(takingQson(), hasLength(1));
    await pumpAt(visible: false);
    expect(takingQson(), isEmpty);

    await unmount(tester);
  });

  testWidgets('an imported file opens as its own operation, and the next one imports too', (tester) async {
    // Two in a row: an in-flight claim never released would answer every
    // import after the first with "busy".
    final pushes = _PushCounter();
    final services = await pumpHome(tester, observers: [pushes]);
    final context = tester.element(find.byType(HomeView));
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

    // The import must complete with its operation still open: the file
    // router waits on it before the next file, and an import that waited
    // for the operation to be left would hold every file after it, a log
    // dropped on that operation included.
    Future<void> importAndWait(String title) async {
      final before = pushes.count;
      await tester.runAsync(() => runQsonImport(context, services, file: qson(title)).timeout(const Duration(seconds: 5)));
      expect(pushes.count, before + 1, reason: '$title opens');
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
    final context = tester.element(find.byType(HomeView));
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
