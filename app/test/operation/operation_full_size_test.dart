// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pane shown full size in the Operation view (docs/design/layouts.md, "Full
// size"), through the view's own wiring: the system back and Escape put the
// pane back, after whatever comes before them, rather than leaving the view.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/app_shell/system_back.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Whether a back reached the platform as leaving the app.
  late List<MethodCall> platformCalls;

  Future<void> openOperation(WidgetTester tester) async {
    platformCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();
    // A profile callsign, or the view opens on a prompt for one.
    await services.setOperatorCall('N0CALL');
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    systemBack.attach();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          onNavigationNotification: systemBack.onNavigationNotification,
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await settleFrames(tester);
    // A new operation opens its setup sheet once; out of the way.
    await tester.tap(find.text('OK'));
    await settleFrames(tester);
  }

  Future<void> enlargeLogging(WidgetTester tester) async {
    await tester.tap(find.text('0 QSOs'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('0 QSOs'));
    await settleFrames(tester);
  }

  DockLayoutViewState dock(WidgetTester tester) => tester.state<DockLayoutViewState>(find.byType(DockLayoutView));

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('the system back puts a full-size pane back and stays in the operation', (tester) async {
    await openOperation(tester);
    await enlargeLogging(tester);
    expect(dock(tester).fullSizeModule, 'logging');

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await settleFrames(tester);

    expect(platformCalls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty, reason: 'the back was the card\'s, not the view\'s');
    expect(dock(tester).fullSizeModule, isNull);
    await tearDownView(tester);
  });

  testWidgets('Escape in a full-size logging pane with nothing to back out of puts it back', (tester) async {
    // The logger lets an Escape it has no use for go on: swallowed, a
    // full-size logging pane would have no Escape out. A menu or an open
    // control takes its own Escape first (the ladder in logging-fields.md).
    await openOperation(tester);
    await enlargeLogging(tester);
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await settleFrames(tester);

    // One press per open layer, then the card: never more than the ladder
    // has rungs. Swallowed at the bottom of the ladder, it never closes.
    for (var press = 0; press < 4 && dock(tester).fullSizeModule != null; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleFrames(tester);
    }

    expect(dock(tester).fullSizeModule, isNull);
    await tearDownView(tester);
  });

  testWidgets('the header is under the barrier while a pane is full size: a click there closes the card, and nothing else', (tester) async {
    // The card covers the dock alone. A header still answering would open
    // the operation sheet, or start a layout edit, from under the card; a
    // dimmed header that swallowed the click would leave the operator
    // clicking at a barrier that does nothing.
    await openOperation(tester);
    await enlargeLogging(tester);

    await tester.tap(find.textContaining('Test Op'), warnIfMissed: false);
    await settleFrames(tester);

    expect(find.text('No Activities Selected'), findsNothing, reason: 'the operation sheet stayed shut');
    expect(dock(tester).fullSizeModule, isNull);
    await tearDownView(tester);
  });
}
