// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's activity fields are re-fetched whenever the operation's
// refs change. Nothing re-runs that fetch when it fails — refs only change on
// a deliberate edit — so installing a failed result is not a momentary blank:
// the fields stay gone until the operator reopens the operation.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

const _exchangeControl = {
  'key': 'c/exchange',
  'label': 'Exch',
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
};

/// Answers the first `loggingControls` call and fails every one after it —
/// the runtime restarting mid-session, which is what makes this reachable
/// without the operator doing anything wrong.
class _FailsAfterFirst extends ExtensionServiceWithMockHost {
  _FailsAfterFirst() : super(const MockExtensionHost({}));

  int calls = 0;

  @override
  Future<ControlsResult> loggingControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      calls++ == 0
          ? (controls: const [_exchangeControl], loadFailed: false)
          : (controls: const <Map<String, dynamic>>[], loadFailed: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a failed re-fetch keeps the activity fields already on the panel', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = _FailsAfterFirst()..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {
      ...operation.data,
      'refs': [
        {'type': 'c', 'ref': 'C-1'}
      ],
    }));

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the first fetch answered');

    // A ref edit is the trigger, and the only one — so the failure this
    // provokes is the last word on the panel's controls until the operation
    // is reopened.
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {
      ...operation.data,
      'refs': [
        {'type': 'c', 'ref': 'C-1'},
        {'type': 'c', 'ref': 'C-2'},
      ],
    }));
    await tester.pumpAndSettle();

    expect(extensions.calls, greaterThan(1), reason: 'the ref edit really did re-fetch');
    expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget,
        reason: 'a fetch that failed says nothing about what the activities want');

    // Tear the tree down and drain the services' debounce timers, so the
    // binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
