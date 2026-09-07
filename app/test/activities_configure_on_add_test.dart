// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Adding a contest from the search leaves an operation that cannot score until
// its exchange is set, and the row says nothing about it — so the setup form
// opens by itself. The trap this file guards is the ORDER: the ref is saved
// first and the form runs on top, so cancelling keeps the activity. Reversing
// it (form first, save on submit — what the Activity Types path does) makes a
// tap on a suggestion able to end with nothing added at all.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import 'support/halo_test_support.dart';

/// A form-configured contest control, the shape `refTypeIsForm` keys on.
const _contestControl = {
  'key': 'fd/setup',
  'label': 'ARRL Field Day',
  'input': {
    'kind': 'form',
    'refType': 'fd',
    'form': {
      'title': 'Field Day Setup',
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'ourClass', 'label': 'Class'},
      ],
    },
  },
};

/// A plain reference activity: its suggestion already carries the code that
/// identifies it, so there is nothing to prompt for.
const _parkControl = {
  'key': 'pota/activation',
  'label': 'Parks on the Air',
  'input': {'kind': 'refList', 'refType': 'pota'},
};

const _contestSuggestion = {
  'type': 'fd',
  'ref': '2027',
  'program': 'Contest',
  'label': 'ARRL Field Day 2027',
  'shortLabel': 'FD 2027',
};

const _parkSuggestion = {
  'type': 'pota',
  'ref': 'US-0001',
  'label': 'POTA US-0001',
  'shortLabel': 'POTA US-0001',
  'name': 'Some Park',
};

/// The shared FakeExtensionHost only overrides the public `host` getter, while
/// control collection and `suggestActivities` read the private field — so both
/// would come back empty and every row this file looks for would be missing.
/// Overriding the three methods the sheet actually calls says exactly what
/// these tests depend on.
class _AddFlowExtensions extends ExtensionServiceWithFakeHost {
  _AddFlowExtensions({required this.controls, required this.suggestions}) : super(FakeExtensionHost({}));

  final List<Map<String, dynamic>> controls;
  final List<Map<String, dynamic>> suggestions;

  /// Set to fail the controls fetch the way a timed-out hook does: no
  /// descriptors, and the fan-out saying so.
  bool controlsFail = false;

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      controlsFail ? (controls: const <Map<String, dynamic>>[], loadFailed: true) : (controls: controls, loadFailed: false);

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async =>
      (suggestions: suggestions, allSourcesFailed: false);

  /// Stands in for the contest's own decorateRef. The identity keys have to
  /// survive or the saved row can't be found again to replace.
  ///
  /// [onDecorate] runs while the hook is "in flight", standing in for anything
  /// the operator does during the up-to-10s window in which the dialog has
  /// closed and the sheet is live again.
  void Function()? onDecorate;

  @override
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async {
    onDecorate?.call();
    final own = (ref['ourClass'] as String?) ?? '';
    return {
      ...ref,
      'shortLabel': 'FD ${ref['ref']}',
      // Mirrors the real contest hooks: the second line is the exchange once
      // there is one, and says the entry is not set up while there isn't.
      'name': own.isEmpty ? 'Not configured!' : own,
    };
  }
}

Future<(HaLoServices, Operation)> _harness({
  required List<Map<String, dynamic>> controls,
  required List<Map<String, dynamic>> suggestions,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _AddFlowExtensions(controls: controls, suggestions: suggestions)..settings = settings;
  return (HaLoServices(db, settings, extensions: extensions), Operation(uuid: 'op-1', data: const {'refs': []}));
}

Future<void> _pumpSheet(WidgetTester tester, HaLoServices services, Operation operation,
    {void Function(Operation)? onChanged}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: OperationSheet(
          services: services,
          operation: operation,
          onOperationChanged: onChanged,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a contest suggestion opens its setup form', (tester) async {
    final (services, operation) = await _harness(
      controls: const [_contestControl],
      suggestions: const [_contestSuggestion],
    );
    await _pumpSheet(tester, services, operation);

    await tester.tap(find.text('ARRL Field Day 2027').first);
    await tester.pumpAndSettle();

    // The form's own title — proof the dialog opened rather than the row
    // simply appearing in the list.
    expect(find.text('Field Day Setup'), findsOneWidget);
  });

  testWidgets('a setup form that could not be fetched says so instead of adding in silence', (tester) async {
    // `_configureNewRef` reloads the descriptors before deciding whether to
    // prompt, so a failed fetch leaves `control == null` — which is also what
    // a type with no form looks like. Read as the latter, the contest saves
    // unconfigured, no dialog appears, and `refTypeIsEditable(null)` renders
    // the row inert, so nothing on screen offers a way back to the setup.
    final (services, operation) = await _harness(
      controls: const [_contestControl],
      suggestions: const [_contestSuggestion],
    );
    (services.extensions as _AddFlowExtensions).controlsFail = true;
    await _pumpSheet(tester, services, operation);

    // Its short label, not the full name: with no control to build the row
    // title from, `activityRowTitle` falls back to the ref itself.
    await tester.tap(find.text('FD 2027').first);
    await tester.pumpAndSettle();

    expect(find.text('Field Day Setup'), findsNothing, reason: 'there were no descriptors to build it from');
    expect(
      services.statusBar.items.any((item) => item.key == 'activities:setup-unavailable'),
      isTrue,
      reason: 'the operator is told, rather than left with an unconfigured contest and an inert row',
    );
  });

  testWidgets('cancelling the setup form leaves the activity added', (tester) async {
    Operation? latest;
    final (services, operation) = await _harness(
      controls: const [_contestControl],
      suggestions: const [_contestSuggestion],
    );
    await _pumpSheet(tester, services, operation, onChanged: (op) => latest = op);

    await tester.tap(find.text('ARRL Field Day 2027').first);
    await tester.pumpAndSettle();
    expect(find.text('Field Day Setup'), findsOneWidget);

    // `_runSetupForm` passes no `labels`, so the dialog uses
    // FormRendererLabels.english and its cancel button is this literal.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The whole point of saving before prompting: backing out of the form is
    // not backing out of the add.
    expect(latest, isNotNull);
    final kept = latest!.refs.singleWhere((r) => r['type'] == 'fd' && r['ref'] == '2027');

    // And the cancelled ref is DECORATED, not left as the suggestion wrote it.
    // A suggestion's `name` describes the event for the search list it belongs
    // to; keeping that here would leave a contest the operator backed out of
    // reading like a configured activity. Only the hook can say otherwise.
    expect(kept['name'], 'Not configured!');
  });

  testWidgets('submitting the form writes the exchange back, decorated', (tester) async {
    Operation? latest;
    final (services, operation) = await _harness(
      controls: const [_contestControl],
      suggestions: const [_contestSuggestion],
    );
    await _pumpSheet(tester, services, operation, onChanged: (op) => latest = op);

    await tester.tap(find.text('ARRL Field Day 2027').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3A');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The point of the whole feature: the exchange reaches the ref. Everything
    // after the cancel check — re-finding the row, decorating, writing back —
    // can be deleted without the other tests here noticing, because they all
    // stop at the dialog.
    final saved = latest!.refs.singleWhere((r) => r['type'] == 'fd');
    expect(saved['ourClass'], '3A');
    // Decorated on the way in, not stored raw: the row's display fields come
    // from the extension, so a save that skipped decorateRef would leave the
    // ref labelled with whatever the suggestion happened to carry.
    expect(saved['shortLabel'], 'FD 2027');
    // Replaced in place rather than appended — a second row for the same
    // running is what an index-based re-find gets wrong.
    expect(latest!.refs.where((r) => r['type'] == 'fd'), hasLength(1));
  });

  testWidgets('an activity added while decorateRef is in flight is not clobbered', (tester) async {
    Operation? latest;
    final (services, operation) = await _harness(
      controls: const [_contestControl, _parkControl],
      suggestions: const [_contestSuggestion, _parkSuggestion],
    );
    await _pumpSheet(tester, services, operation, onChanged: (op) => latest = op);

    // The setup dialog closes before `decorateRef` is asked anything, and that
    // hook runs to a 10-second timeout with the sheet fully live behind it —
    // so whatever the operator does in that window has to survive. Reading the
    // refs list before the await and writing it after silently reverts it.
    final extensions = services.extensions as _AddFlowExtensions;
    extensions.onDecorate = () {
      final sheet = tester.state<OperationSheetState>(find.byType(OperationSheet));
      sheet.updateOperation(Operation(
        uuid: 'op-1',
        data: {
          'refs': [
            ...latest!.refs,
            {'type': 'pota', 'ref': 'US-0001', 'shortLabel': 'POTA US-0001'},
          ],
        },
      ));
    };

    await tester.tap(find.text('ARRL Field Day 2027').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3A');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(latest!.refs.where((r) => r['type'] == 'fd'), hasLength(1));
    expect(
      latest!.refs.where((r) => r['type'] == 'pota'),
      hasLength(1),
      reason: 'the park added while the hook was running must not be undone by the write-back',
    );
  });

  testWidgets('a plain reference suggestion adds without prompting', (tester) async {
    Operation? latest;
    final (services, operation) = await _harness(
      controls: const [_parkControl],
      suggestions: const [_parkSuggestion],
    );
    await _pumpSheet(tester, services, operation, onChanged: (op) => latest = op);

    await tester.tap(find.text('POTA US-0001').first);
    await tester.pumpAndSettle();

    // A park's code is already resolved by the search that found it; a dialog
    // here could only ask the operator to retype what they just picked.
    expect(find.byType(Dialog), findsNothing);
    expect(latest, isNotNull);
    expect(latest!.refs.where((r) => r['type'] == 'pota'), hasLength(1));
  });
}
