// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's activity fields are re-fetched whenever the operation's
// refs change. A ref edit is not the only thing that re-runs that fetch —
// `runtimeGeneration` ticking (the extension host coming back up after a
// restart) does too — so a failure caused by that restart racing the ref
// edit self-corrects; a failure with no restart behind it stays exactly as
// installed, fields gone, until the operator reopens the operation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

const _exchangeControl = {
  'key': 'c/exchange',
  'label': 'Exch',
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
};

/// Answers the first `loggingControls` call and fails every one after it —
/// the runtime restarting mid-session, which is what makes this reachable
/// without the operator doing anything wrong.
class _FailsAfterFirst extends ExtensionServiceWithFakeHost {
  _FailsAfterFirst() : super(FakeExtensionHost({}));

  int calls = 0;

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      calls++ == 0 ? (controls: const [_exchangeControl], loadFailed: false) : (controls: const <Map<String, dynamic>>[], loadFailed: true);
}

/// Nothing configured yet (call 0, before the ref exists), then fails
/// exactly the call the ref edit provokes (call 1), then answers with the
/// full set (call 2+) — the runtime restart (enabling the new extension)
/// settling between the failed fetch and the `runtimeGeneration` tick that
/// follows it.
class _FailsOnceThenRecovers extends ExtensionServiceWithFakeHost {
  _FailsOnceThenRecovers() : super(FakeExtensionHost({}));

  /// Fetches made FOR THE REF. Keyed on what is asked rather than on call
  /// order: the view is not the only caller — the Spots pane fetches once for
  /// its row icons — and a script indexed by call count hands the failure to
  /// whichever of them happens to ask second.
  int refCalls = 0;

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async {
    final refs = operationData['refs'];
    if (refs is! List || refs.isEmpty) return (controls: const <Map<String, dynamic>>[], loadFailed: false);
    if (refCalls++ == 0) return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    return (controls: const [_exchangeControl], loadFailed: false);
  }
}

const _exchangeControl1 = {
  'key': 'c/exchange',
  'label': 'Exch1',
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
};
const _exchangeControl2 = {
  'key': 'c/exchange',
  'label': 'Exch2',
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
};

/// Every `loggingControls` call hangs on its own `Completer`, so a test can
/// resolve them in whatever order it likes — the only way to actually
/// construct the race `OperationRuntimeState`'s request id guards against, rather
/// than two calls that just happen to resolve in the order they were made.
class _OutOfOrder extends ExtensionServiceWithFakeHost {
  _OutOfOrder() : super(FakeExtensionHost({}));

  final List<Completer<ControlsResult>> completers = [];

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) {
    final completer = Completer<ControlsResult>();
    completers.add(completer);
    return completer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an older request resolving after a newer one does not clobber it', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final extensions = _OutOfOrder();
    final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pump();
    expect(extensions.completers, hasLength(1), reason: 'the initial fetch, from the first operation emission');

    // Two ref edits, back to back, neither given a chance to see the other's
    // fetch resolve — each provokes its own `refreshControls` call,
    // request IDs 2 and 3.
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      ),
    );
    await tester.pump();
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
            {'type': 'c', 'ref': 'C-2'},
          ],
        },
      ),
    );
    await tester.pump();
    expect(extensions.completers, hasLength(3));

    // Resolve OUT OF ORDER: the older (second-issued, index 1) request lands
    // after the newer (third-issued, index 2) one.
    extensions.completers[2].complete((controls: const [_exchangeControl2], loadFailed: false));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Exch2'), findsOneWidget, reason: 'the newer request landed first');

    extensions.completers[1].complete((controls: const [_exchangeControl1], loadFailed: false));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Exch2'), findsOneWidget, reason: 'the older request resolving late must not overwrite the newer result');
    expect(find.widgetWithText(TextField, 'Exch1'), findsNothing);

    // Drain the still-pending initial-fetch completer and any debounce
    // timers, so the binding's pending-timer invariant passes.
    extensions.completers[0].complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a runtime-generation tick retries a fetch the restart made fail', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final extensions = _FailsOnceThenRecovers();
    final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Exch'), findsNothing, reason: 'no ref yet — nothing to fetch for');

    // Adding the ref is what the operator did by adding the contest — and,
    // in the scenario this guards, is racing a runtime restart the same
    // gesture (enabling the extension) kicked off.
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(extensions.refCalls, 1, reason: 'the ref edit fetched, and lost the race');
    expect(find.widgetWithText(TextField, 'Exch'), findsNothing, reason: 'the failed fetch installed nothing');

    // The restart settling — extension_service.dart bumps this once the host
    // is genuinely live again.
    extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();

    expect(extensions.refCalls, 2, reason: 'the generation tick retried');
    expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the retry succeeds once the runtime is back, without reopening the operation');

    // Tear the tree down and drain the services' debounce timers, so the
    // binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed re-fetch keeps the activity fields already on the panel', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final extensions = _FailsAfterFirst();
    final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      ),
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the first fetch answered');

    // A ref edit is the trigger, and the only one — so the failure this
    // provokes is the last word on the panel's controls until the operation
    // is reopened.
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
            {'type': 'c', 'ref': 'C-2'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(extensions.calls, greaterThan(1), reason: 'the ref edit really did re-fetch');
    expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'a fetch that failed says nothing about what the activities want');

    // Tear the tree down and drain the services' debounce timers, so the
    // binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
