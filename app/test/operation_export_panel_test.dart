// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Exports panel. What has to hold:
//   - the primary button says how many files it is about to write, so the
//     operator can check the count against the ticks before committing;
//   - a row's own button exports THAT file, whatever is ticked — the two
//     controls are independent (app-polo conflated them, so a row tap
//     silently exported one file and ignored the checkboxes entirely);
//   - the verbs follow the platform, because "Save" on iOS promises a
//     filesystem the operator can't see and "Download" only means anything
//     in a browser;
//   - flipping the filename setting relists the options — the names are
//     built by the extensions, so they can't be patched up locally — WITHOUT
//     discarding ticks already made.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/operation_export_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the platform decides the verb', () {
    test('desktop saves', () {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
        expect(bulkExportActions(isWeb: false, platform: platform), [ExportAction.save]);
        expect(rowExportAction(isWeb: false, platform: platform), ExportAction.save);
      }
    });

    test('the browser downloads', () {
      // isWeb wins over the platform: `defaultTargetPlatform` reports the HOST
      // OS on web, so a browser on a Mac would otherwise be offered a save
      // dialog it has no filesystem for.
      expect(bulkExportActions(isWeb: true, platform: TargetPlatform.macOS), [ExportAction.download]);
      expect(rowExportAction(isWeb: true, platform: TargetPlatform.macOS), ExportAction.download);
    });

    test('iOS exports — one verb, because the share sheet is the only way out', () {
      expect(bulkExportActions(isWeb: false, platform: TargetPlatform.iOS), [ExportAction.export]);
      expect(rowExportAction(isWeb: false, platform: TargetPlatform.iOS), ExportAction.export);
    });

    test('Android saves AND shares, and its rows share', () {
      expect(
        bulkExportActions(isWeb: false, platform: TargetPlatform.android),
        [ExportAction.save, ExportAction.share],
        reason: 'Save leads: it is the platform default verb, Share is the addition',
      );
      expect(rowExportAction(isWeb: false, platform: TargetPlatform.android), ExportAction.share);
    });
  });

  group('the panel', () {
    late HaLoDatabase db;
    late SettingsService settings;
    late _FakeExportService exports;
    late HaLoServices services;
    late Operation operation;

    // These run as ANDROID: `defaultTargetPlatform` is android under
    // `flutter test`, and overriding it per-test trips Flutter's own
    // "a foundation debug variable was changed by the test" invariant, which
    // fires before tearDown gets to reset it. So the widget tests cover the
    // Android verbs — the richest case, two footer buttons and a Share row —
    // and the other three platforms are covered by the pure-function group
    // above, which takes the platform as an argument.
    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      settings = await SettingsService.load();
      exports = _FakeExportService(settings);
      services = HaLoServices(db, settings, extensions: ExtensionService(), exports: exports);
      operation = await OperationsRepository(db).create(stationCall: 'N0CALL', userTitle: 'Test Op');
    });

    tearDown(() async => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: OperationExportPanel(services: services, operation: operation)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every option with its filename, and counts the ticked ones', (tester) async {
      await pump(tester);

      expect(find.text('Full ADIF Export'), findsOneWidget);
      expect(find.text('POTA US-1234'), findsOneWidget);
      expect(find.text('2026-07-15 N0CALL Test Op.adi'), findsOneWidget);

      // Only POTA is selectedByDefault, so the button opens on 1.
      expect(find.text('Save 1 file'), findsOneWidget);

      // The ADIF row is second — priority -1 sorts it under the activity's.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.text('Save 2 files'), findsOneWidget,
          reason: 'the count is in the button, not in a heading above it');
    });

    // The whole-log ADIF is the backup an operator takes as well; the
    // activity's own file is what they came to submit, so it leads.
    testWidgets('the full ADIF export sorts below the activity exports', (tester) async {
      await pump(tester);

      expect(
        tester.getCenter(find.text('POTA US-1234')).dy,
        lessThan(tester.getCenter(find.text('Full ADIF Export')).dy),
      );
    });

    testWidgets('with nothing ticked the primary button is disabled rather than hidden', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('Save 0 files'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save 0 files'));
      expect(button.onPressed, isNull);
      expect(exports.generated, isEmpty);
    });

    // The batch action moved out of the footer and up next to the ticks it
    // counts; the footer is now only the way out.
    testWidgets('the batch button sits above the list, and the footer is just Done', (tester) async {
      await pump(tester);

      expect(
        tester.getCenter(find.text('Save 1 file')).dy,
        lessThan(tester.getCenter(find.text('POTA US-1234')).dy),
      );
      // A plain TextButton, not filled: the exports have already happened by
      // the time this is pressed, so it dismisses rather than confirms.
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
      expect(
        tester.getCenter(find.text('Done')).dy,
        greaterThan(tester.getCenter(find.text('Full ADIF Export')).dy),
      );
    });

    testWidgets("a row's own button exports only that row, ignoring the ticks", (tester) async {
      await pump(tester);

      // The ADIF row is unticked; its button must still export it, and must
      // not drag the ticked POTA option along. The button is icon-only and
      // this app has no hover tooltips (#433), so its accessible name — which
      // names the actual file — is the only name it has.
      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op.adi'));
      await tester.pumpAndSettle();

      expect(exports.generated, hasLength(1));
      expect(exports.generated.single.map((o) => o['exportType']), ['adif']);
      expect(exports.sharedFiles, hasLength(1));
    });

    // Regression: with the button in CheckboxListTile's `secondary` slot, that
    // widget's MergeSemantics absorbed it — the row became ONE checkbox node
    // named "ADIF Export … Share ADIF Export …", with no button in the tree at
    // all, and pointer taps on the icon toggled the checkbox instead. A screen
    // reader user simply could not export a single file.
    testWidgets("a row's button is its own control, not swallowed by the checkbox", (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op.adi'));
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.hasCheckedState), isFalse,
          reason: 'a checked state here means it merged into the checkbox again');

      // The row's tap target is excluded from semantics, so the checkbox is
      // the ONLY thing naming the option to a screen reader. Unlabelled, it
      // would announce as a bare "checkbox" in a column of them.
      final checkbox = tester.getSemantics(find.byType(Checkbox).first);
      expect(checkbox.hasFlag(SemanticsFlag.hasCheckedState), isTrue);
      expect(checkbox.label, 'POTA US-1234');

      handle.dispose();
    });

    // The reading order the layout is meant to have: what it is, what it will
    // be called, the button for this one file, and the batch checkbox last.
    testWidgets('icon leads the row and the checkbox sits at the far end', (tester) async {
      await pump(tester);

      // The ADIF row's own icon: POTA's row uses 'pine-tree', so this is unique.
      final iconX = tester.getCenter(find.byIcon(MdiIcons.fileExport)).dx;
      final labelX = tester.getCenter(find.text('Full ADIF Export')).dx;
      final buttonX = tester.getCenter(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op.adi')).dx;
      final checkboxX = tester.getCenter(find.byType(Checkbox).last).dx;

      expect(iconX, lessThan(labelX));
      expect(labelX, lessThan(buttonX));
      expect(buttonX, lessThan(checkboxX), reason: 'the checkbox is the far-right control');
    });

    testWidgets('the option name is bold, so the filename reads as its subtitle', (tester) async {
      await pump(tester);

      final title = tester.widget<Text>(find.text('Full ADIF Export'));
      expect(title.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('the primary button exports exactly what is ticked', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Save 1 file'));
      await tester.pumpAndSettle();

      expect(exports.generated.single.map((o) => o['exportType']), ['pota-adif:US-1234']);
    });

    testWidgets('flipping the filename setting relists, and keeps the ticks', (tester) async {
      await pump(tester);

      // Tick the ADIF option too (the second row), so there is a choice
      // worth losing.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.text('Save 2 files'), findsOneWidget);

      await settings.setUseCompactFileNames(true);
      await tester.pumpAndSettle();

      expect(find.text('N0CALL-20260715-test-op.adi'), findsOneWidget,
          reason: 'the extensions rebuild their names; the panel re-asks rather than rewriting them');
      expect(find.text('2026-07-15 N0CALL Test Op.adi'), findsNothing);
      expect(find.text('Save 2 files'), findsOneWidget, reason: 'a relist must not silently drop selections');
    });

    testWidgets('Android offers both verbs, Save leading', (tester) async {
      await pump(tester);

      expect(find.text('Save 1 file'), findsOneWidget);
      expect(find.text('Share 1 file'), findsOneWidget);
      // Save is the FilledButton (the primary call to action); Share is the
      // alternative beside it, not a second equal-weight button.
      expect(find.descendant(of: find.byType(FilledButton), matching: find.text('Save 1 file')), findsOneWidget);
      expect(find.descendant(of: find.byType(OutlinedButton), matching: find.text('Share 1 file')), findsOneWidget);
    });

    // An export that claims an activity's refs wears that activity's own
    // accent — the same green the POTA row wears in the operation sheet — so
    // the two are recognisably the same thing. Everything else falls back to
    // the theme's on-surface accent rather than inventing a palette here.
    testWidgets("an activity's export takes the activity's accent color", (tester) async {
      services = HaLoServices(
        db,
        settings,
        extensions: _ExtensionsWithControls(const [
          {'key': 'pota/ref', 'color': '#3C8C3C', 'icon': 'pine-tree', 'input': {'refType': 'potaActivation'}},
        ]),
        exports: exports,
      );
      await pump(tester);

      // The POTA export declares refType 'potaActivation', so its icon is
      // circled in the control's declared color.
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, const Color(0xFF3C8C3C).withValues(alpha: 0.6));

      // The plain ADIF export claims no activity, so it gets no circle — just
      // the theme accent on the bare glyph.
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('with no activity colors at all, nothing is circled', (tester) async {
      await pump(tester);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    // The whole-log ADIF belongs to no activity, so it asks for a neutral
    // grey of its own rather than borrowing the theme accent and reading as
    // if it did.
    testWidgets("an option's own declared color beats the activity's", (tester) async {
      exports.adifColor = '#9E9E9E';
      services = HaLoServices(
        db,
        settings,
        // A control claiming potaActivation is green — the ADIF option must
        // not take it, and must not take the theme accent either.
        extensions: _ExtensionsWithControls(const [
          {'key': 'pota/ref', 'color': '#3C8C3C', 'icon': 'pine-tree', 'input': {'refType': 'potaActivation'}},
        ]),
        exports: exports,
      );
      await pump(tester);

      final colors = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .map((a) => a.backgroundColor)
          .toSet();
      expect(colors, {
        const Color(0xFF3C8C3C).withValues(alpha: 0.6),
        const Color(0xFF9E9E9E).withValues(alpha: 0.6),
      });
    });

    testWidgets('one callsign gets no group header — grouping one group is noise', (tester) async {
      await pump(tester);
      expect(find.text('N0CALL'), findsNothing);
    });

    // Reporting unconditionally announced a completed share for a sheet the
    // operator dismissed — worse than the silence it replaced, because it
    // asserts an outcome that didn't happen.
    testWidgets('a dismissed share sheet is not reported as a success', (tester) async {
      exports.shareSucceeds = false;
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op.adi'));
      await tester.pumpAndSettle();

      expect(exports.sharedFiles, hasLength(1), reason: 'the share sheet was opened');
      expect(services.statusBar.items.where((i) => i.key == 'export:status'), isEmpty);
    });

    testWidgets('a completed share is reported', (tester) async {
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op.adi'));
      await tester.pumpAndSettle();

      final message = services.statusBar.items.firstWhere((i) => i.key == 'export:status');
      expect(message.text, contains('Shared 1 file'));
    });

    // With developer mode on, the QSON dump used to arrive untagged and form
    // a group of its own keyed '' — which made an ordinary single-station
    // operation render callsign headers, lose its batch button and grow a
    // second header titled "Export".
    testWidgets('the developer QSON dump does not invent a second group', (tester) async {
      await settings.setDeveloperMode(true);
      exports.includeQson = true;
      await pump(tester);

      expect(find.text('Developer Mode: QSON Export'), findsOneWidget);
      expect(find.text('N0CALL'), findsNothing, reason: 'still a single-station operation');
      expect(find.text('Save 1 file'), findsOneWidget, reason: 'the batch button stays at the top');
      expect(find.textContaining('combined'), findsNothing);
    });
  });

  // A multi-operator operation owes each callsign its own submission, so the
  // options arrive tagged per call and the panel has to keep them apart:
  // separate headers, separate ticks, and a batch button per call so
  // "everything I ticked for W1AW" is sayable without unticking N0CALL's.
  group('several station callsigns', () {
    late HaLoDatabase db;
    late SettingsService settings;
    late _MultiCallExportService exports;
    late HaLoServices services;
    late Operation operation;

    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      settings = await SettingsService.load();
      exports = _MultiCallExportService(settings);
      services = HaLoServices(db, settings, extensions: ExtensionService(), exports: exports);
      operation = await OperationsRepository(db).create(stationCall: 'N0CALL, W1AW', userTitle: 'Multi');
    });

    tearDown(() async => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: OperationExportPanel(services: services, operation: operation)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('each callsign gets its own header over its own exports', (tester) async {
      await pump(tester);

      expect(find.text('N0CALL'), findsOneWidget);
      expect(find.text('W1AW'), findsOneWidget);
      expect(find.text('Full ADIF Export'), findsNWidgets(2), reason: 'one per call');

      // The header sits above the exports it owns.
      expect(
        tester.getCenter(find.text('N0CALL')).dy,
        lessThan(tester.getCenter(find.text('W1AW')).dy),
      );
    });

    testWidgets("a group's button exports only that group's ticks", (tester) async {
      await pump(tester);

      // Both calls' exports default to ticked, so the combined button reads 2
      // while each group reads 1.
      expect(find.text('Save combined 2 files'), findsOneWidget, reason: 'the batch spanning both calls');
      expect(find.text('Save 1 file'), findsNWidgets(2), reason: 'one per group header');

      // Press W1AW's — the second of the two group buttons.
      await tester.tap(find.text('Save 1 file').last);
      await tester.pumpAndSettle();

      expect(exports.generated, hasLength(1));
      expect(exports.generated.single.single['stationCall'], 'W1AW',
          reason: "N0CALL's ticked export must not ride along");
    });

    // Both calls offer the same hookKey/exportType pair, so a selection key
    // that ignored the callsign would tick and untick them together.
    testWidgets('ticking one call\'s export leaves the other call\'s alone', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // N0CALL's group drops to none; W1AW's is untouched, and the combined
      // button recounts.
      expect(find.text('Save 0 files'), findsOneWidget, reason: "only N0CALL's group emptied");
      expect(find.text('Save 1 file'), findsOneWidget, reason: "W1AW's group is untouched");
      expect(find.text('Save combined 1 file'), findsOneWidget);
      expect(find.text('Save combined 2 files'), findsNothing);
    });

    // "Save 8 files" sitting above the first callsign read as that callsign's
    // — so the whole-panel batch moved under the groups it spans, and says so.
    testWidgets('the combined batch closes the list, below every callsign', (tester) async {
      await pump(tester);

      final combinedY = tester.getCenter(find.text('Save combined 2 files')).dy;
      expect(combinedY, greaterThan(tester.getCenter(find.text('N0CALL')).dy));
      expect(combinedY, greaterThan(tester.getCenter(find.text('W1AW')).dy));
      expect(combinedY, greaterThan(tester.getCenter(find.text('Full ADIF Export').last).dy),
          reason: 'below the last export row, not merely the last header');
    });

    testWidgets('the combined batch is right-aligned, like the group buttons', (tester) async {
      await pump(tester);

      // The TRAILING button, not the Save one: these run as Android, so a
      // Share button sits to its right and the Save button's own edge says
      // nothing about the row's alignment.
      final panelRight = tester.getBottomRight(find.byType(OperationExportPanel)).dx;
      final combinedRight =
          tester.getBottomRight(find.widgetWithText(OutlinedButton, 'Share combined 2 files')).dx;

      expect(panelRight - combinedRight, lessThan(24),
          reason: 'hugs the trailing edge, inside its own padding');
    });
  });
}

/// Two callsigns, each offering the same single export — the shape
/// `ExportService.getExportOptions` produces for `stationCall: 'N0CALL, W1AW'`.
class _MultiCallExportService extends ExportService {
  _MultiCallExportService(SettingsService settings)
      : super(extensions: ExtensionService(), qsos: _UnusedQsos(), settings: settings);

  final List<List<Map<String, dynamic>>> generated = [];

  @override
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async => [
        for (final call in operation.stationCalls)
          {
            'hookKey': 'adif',
            'exportType': 'adif',
            'format': 'adif',
            'stationCall': call,
            'label': 'Full ADIF Export',
            'filename': '2026-07-15 $call Multi.adi',
            'selectedByDefault': true,
            'priority': -1,
          },
      ];

  @override
  Future<List<Map<String, dynamic>>> generateExports(
    Operation operation,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    generated.add(selectedOptions);
    return [
      for (final option in selectedOptions)
        {'filename': option['filename'], 'mimeType': 'text/plain', 'content': 'x'},
    ];
  }

  @override
  Future<String?> saveToDisk(List<Map<String, dynamic>> files) async => '/tmp/exports';

  @override
  Future<bool> shareFiles(List<Map<String, dynamic>> files) async => true;
}

/// Supplies activity controls (for their accent colors) without a runtime.
class _ExtensionsWithControls extends ExtensionService {
  final List<Map<String, dynamic>> controls;
  _ExtensionsWithControls(this.controls);

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: controls, loadFailed: false);

  @override
  Future<void> start() async {}
}

/// Stands in for the real service, which a widget test cannot use: its option
/// listing awaits a drift stream's `.first`, and that never resolves under
/// `testWidgets`. Answers the two filename forms the extensions would.
class _FakeExportService extends ExportService {
  final SettingsService _settings;

  _FakeExportService(this._settings)
      : super(extensions: ExtensionService(), qsos: _UnusedQsos(), settings: _settings);

  final List<List<Map<String, dynamic>>> generated = [];
  final List<Map<String, dynamic>> savedFiles = [];
  final List<Map<String, dynamic>> sharedFiles = [];

  /// The whole-log ADIF's own declared accent, when the test wants one.
  String? adifColor;

  /// Whether to append the developer-mode QSON dump, as the real service does
  /// when developer mode is on — tagged with the operation's first callsign.
  bool includeQson = false;

  @override
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    final compact = _settings.useCompactFileNames;
    return [
      // Deliberately returned in the WRONG order, so the panel's own
      // priority sort is what puts them right: the whole-log ADIF is -1 and
      // belongs last, under the activity export an operator actually came to
      // submit. Same values the real hooks use.
      {
        'hookKey': 'adif',
        'exportType': 'adif',
        'format': 'adif',
        // The real service tags every option with the call that owes it.
        'stationCall': operation.stationCalls.first,
        'label': 'Full ADIF Export',
        if (adifColor != null) 'color': adifColor,
        'filename': compact ? 'N0CALL-20260715-test-op.adi' : '2026-07-15 N0CALL Test Op.adi',
        'selectedByDefault': false,
        'priority': -1,
      },
      {
        'hookKey': 'pota',
        'exportType': 'pota-adif:US-1234',
        'format': 'adif',
        // What ties this export to the POTA activity — the core slices its
        // QSOs by it, and the panel takes its accent color from it.
        'refType': 'potaActivation',
        'stationCall': operation.stationCalls.first,
        'label': 'POTA US-1234',
        'icon': 'pine-tree',
        'filename': compact ? 'N0CALL@US-1234-20260715.adi' : '2026-07-15 N0CALL at US-1234.adi',
        'selectedByDefault': true,
        'priority': 0,
      },
      if (includeQson)
        {
          'hookKey': 'core-devmode',
          'exportType': 'devmode-qson',
          'stationCall': operation.stationCalls.first,
          'label': 'Developer Mode: QSON Export',
          'filename': '2026-07-15 N0CALL abcd1234.qson',
          'selectedByDefault': false,
          'priority': -100,
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> generateExports(
    Operation operation,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    generated.add(selectedOptions);
    return [
      for (final option in selectedOptions)
        {'filename': option['filename'], 'mimeType': 'text/plain', 'content': 'x'},
    ];
  }

  @override
  Future<String?> saveToDisk(List<Map<String, dynamic>> files) async {
    savedFiles.addAll(files);
    return '/tmp/exports';
  }

  /// What the share sheet answered. False stands for the operator dismissing
  /// it without picking a target.
  bool shareSucceeds = true;

  @override
  Future<bool> shareFiles(List<Map<String, dynamic>> files) async {
    sharedFiles.addAll(files);
    return shareSucceeds;
  }
}

/// Never called — [_FakeExportService] overrides everything that would reach
/// the database.
class _UnusedQsos implements QsosRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
