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

import 'dart:ui' show CheckedState;
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
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

    testWidgets('the way out is on screen while the pane is still loading', (tester) async {
      // The pane declines the header's close button, so the footer's Done is
      // its ONLY visible dismissal. A body that returns early for the spinner
      // takes that exit away with it — for as long as the extension host
      // takes to answer, which is not a single frame.
      final hold = Completer<void>();
      exports.holdOptions = hold;
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: OperationExportPanel(services: services, operation: operation)),
        ),
      ));

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('parks sharing an export type can be selected independently', (tester) async {
      exports.includeSecondPark = true;
      await pump(tester);
      expect(find.text('Save 2 files'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Save 1 file'), findsOneWidget);

      await tester.tap(find.text('Save 1 file'));
      await tester.pumpAndSettle();
      final selected = exports.generated.single.single;
      expect(selected['exportType'], 'potaActivation-adif');
      expect(selected['exportKey'], 'pota-adif:US-5678');
    });

    testWidgets('lists every option with its filename, and counts the ticked ones', (tester) async {
      await pump(tester);

      expect(find.text('Full ADIF Export'), findsOneWidget);
      expect(find.text('POTA US-1234'), findsOneWidget);
      expect(find.text('2026-07-15 N0CALL Test Op Full.adi'), findsOneWidget);

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

    // The sync state is a report the operator did not open this pane for.
    // Heading the list it pushed the formats — the reason they came — below
    // the fold; riding at the end of it, a long list of formats buried it.
    testWidgets('the sync report is pinned under the list, not scrolled with it', (tester) async {
      await pump(tester);

      final report = find.text('Operation has unsynced changes');
      expect(find.descendant(of: find.byType(CustomScrollView), matching: report), findsNothing,
          reason: 'inside the list it scrolls away, and the operator has to go find it');
      expect(tester.getCenter(report).dy, greaterThan(tester.getCenter(find.text('POTA US-1234')).dy));
      expect(tester.getCenter(report).dy, lessThan(tester.getCenter(find.text('Done')).dy),
          reason: 'under the list, over the way out');
    });

    // Two rows made a routine "everything is synced" read as two separate
    // reports to check, and the second appeared only when the operation had
    // markers — moving nothing else on screen only sometimes.
    testWidgets('event markers are counted in the sync row, not a row of their own', (tester) async {
      final qsos = QsosRepository(db);
      await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
      });
      await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 1000);
      await pump(tester);

      expect(find.textContaining('1 of 1 QSOs pending sync · 1 of 1 event markers pending'), findsOneWidget);
      expect(find.byIcon(MdiIcons.flag), findsNothing, reason: 'the markers had their own tile and its own icon');
    });

    // On a phone the two Android verbs take nearly the whole band, and a Row
    // would hand the count whatever was left — a few characters a line, or
    // nothing. The band stacks instead: an overflow is a framework error, so
    // laying out narrow is half the assertion, and the count's own geometry
    // is the other half.
    testWidgets('the batch band stacks rather than squeezing the count', (tester) async {
      final qsos = QsosRepository(db);
      await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
      });
      await pump(tester);
      final oneLine = tester.getSize(find.text('1 QSO in this operation')).height;

      tester.view.physicalSize = const Size(360, 900);
      await tester.pumpAndSettle();

      expect(find.text('Save 1 file'), findsOneWidget);
      expect(find.text('Share 1 file'), findsOneWidget);
      final count = find.text('1 QSO in this operation');
      expect(tester.getSize(count).height, oneLine,
          reason: 'the count keeps its line instead of wrapping into a column of characters');
      expect(tester.getTopLeft(count).dy, lessThan(tester.getTopLeft(find.text('Save 1 file')).dy),
          reason: 'the buttons took their own row under it');
    });

    // "Save 3 files" says nothing about the log until the operator has read
    // the list; the count is what makes it mean something up front.
    testWidgets('the batch band names what it acts on', (tester) async {
      final qsos = QsosRepository(db);
      await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
      });
      await qsos.add(operation.uuid, {
        'their': {'call': 'K2ABC'},
      });
      // A marker is not a contact, and must not be counted as one.
      await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 1000);
      await pump(tester);

      expect(find.text('2 QSOs in this operation'), findsOneWidget);
      expect(
        tester.getCenter(find.text('2 QSOs in this operation')).dx,
        lessThan(tester.getCenter(find.text('Save 1 file')).dx),
        reason: 'the count leads the band, the button closes it',
      );
    });

    // A bare left-aligned button in the one-callsign panel and a banded
    // right-aligned one in the many-callsign panel read as different
    // controls; they are the same control over different lists.
    testWidgets('the batch button sits in a band, right-aligned', (tester) async {
      await pump(tester);

      final button = find.widgetWithText(FilledButton, 'Save 1 file');
      // The Wrap, not the button: Android puts Share beside Save, so it is
      // the pair's trailing edge that is aligned, not the first button's.
      final buttons = find.ancestor(of: button, matching: find.byType(Wrap)).first;
      final band = find.ancestor(of: buttons, matching: find.byType(Container)).first;

      expect(tester.widget<Container>(band).color, isNotNull, reason: 'a tinted band, not bare list ground');
      expect(
        tester.widget<Container>(band).color,
        tester.widget<Container>(find.ancestor(
          of: find.text('Operation has unsynced changes'),
          matching: find.byType(Container),
        ).first).color,
        reason: 'the batch and the sync report are the two ends of one list, on one band',
      );
      expect(tester.getSize(band).width, 1000, reason: 'full-bleed, the way the group headers band');

      // One unit clear of the pane's edge — INSIDE the row controls' own
      // trailing edge, deliberately: a scrollbar rides there, and a button
      // under it is one the operator has to aim around.
      final panelRight = tester.getBottomRight(find.byType(OperationExportPanel)).dx;
      expect(tester.getTopRight(buttons).dx, panelRight - Space.xl);
      expect(tester.getTopRight(buttons).dx,
          lessThan(tester.getTopRight(find.byType(Checkbox).first).dx));
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
      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op Full.adi'));
      await tester.pumpAndSettle();

      expect(exports.generated, hasLength(1));
      expect(exports.generated.single.map((o) => o['exportType']), ['adif']);
      expect(exports.sharedFiles, hasLength(1));

      await readAndDismissResult(tester);
    });

    // Regression: with the button in CheckboxListTile's `secondary` slot, that
    // widget's MergeSemantics absorbed it — the row became ONE checkbox node
    // named "ADIF Export … Share ADIF Export …", with no button in the tree at
    // all, and pointer taps on the icon toggled the checkbox instead. A screen
    // reader user simply could not export a single file.
    testWidgets("a row's button is its own control, not swallowed by the checkbox", (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op Full.adi'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isChecked, CheckedState.none,
          reason: 'a checked state here means it merged into the checkbox again');

      // The row's tap target is excluded from semantics, so the checkbox is
      // the ONLY thing naming the option to a screen reader. Unlabelled, it
      // would announce as a bare "checkbox" in a column of them.
      final checkbox = tester.getSemantics(find.byType(Checkbox).first);
      expect(checkbox.flagsCollection.isChecked, isNot(CheckedState.none));
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
      final buttonX = tester.getCenter(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op Full.adi')).dx;
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

      expect(exports.generated.single.map((o) => o['exportKey']), ['pota-adif:US-1234']);

      // The whole point of the dialog over the old status-bar line: it names
      // WHERE the files went, and the operator cannot miss it.
      expect(await readAndDismissResult(tester), contains('Exported 1 file to /tmp/exports'));
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

      expect(find.text('N0CALL-20260715-test-op-full.adi'), findsOneWidget,
          reason: 'the extensions rebuild their names; the panel re-asks rather than rewriting them');
      expect(find.text('2026-07-15 N0CALL Test Op Full.adi'), findsNothing);
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

    // A contest names the refs it covers but leaves the glyph to the app, and
    // a file-export icon on every one of its rows would say only "an export",
    // which every row in the panel already is. The icon takes the same route
    // its accent does.
    testWidgets("an export with no icon of its own wears its activity's", (tester) async {
      exports.includeContest = true;
      services = HaLoServices(
        db,
        settings,
        extensions: _ExtensionsWithControls(const [
          {'key': 'cqww/ref', 'color': '#3C8C3C', 'icon': 'trophy', 'input': {'refType': 'cqww'}},
        ]),
        exports: exports,
      );
      await pump(tester);

      expect(find.byIcon(MdiIcons.trophy), findsOneWidget);
      expect(find.byIcon(MdiIcons.fileExport), findsOneWidget,
          reason: "only the whole-log ADIF, which asks for that glyph by name");
    });

    // Falling back on a name that doesn't RESOLVE, not merely on a missing
    // one — the accent does exactly this (an unreadable `color` still leaves
    // the row the activity's), and an option whose glyph is a typo would
    // otherwise wear the generic file icon while its row keeps the contest's
    // circle: the one outcome this whole fallback exists to prevent.
    testWidgets("an icon name that doesn't resolve falls through too", (tester) async {
      exports.includeContest = true;
      exports.contestIcon = 'trophy-cup-that-does-not-exist';
      services = HaLoServices(
        db,
        settings,
        extensions: _ExtensionsWithControls(const [
          {'key': 'cqww/ref', 'color': '#3C8C3C', 'icon': 'trophy', 'input': {'refType': 'cqww'}},
        ]),
        exports: exports,
      );
      await pump(tester);

      expect(find.byIcon(MdiIcons.trophy), findsOneWidget);
      expect(find.byIcon(MdiIcons.fileExport), findsOneWidget,
          reason: "only the whole-log ADIF, which asks for that glyph by name");
    });

    // `controlForRefType` matches on equality, so a control that declares no
    // refType of its own answers for a null one. The whole-log ADIF claims no
    // activity and must not be branded with whichever extension happens to
    // have shipped a control without an input refType.
    testWidgets('an option with no refType claims no activity, whatever the controls say',
        (tester) async {
      services = HaLoServices(
        db,
        settings,
        extensions: _ExtensionsWithControls(const [
          {'key': 'odd', 'color': '#3C8C3C', 'icon': 'trophy', 'input': {}},
        ]),
        exports: exports,
      );
      await pump(tester);

      expect(find.byIcon(MdiIcons.trophy), findsNothing);
      expect(find.byIcon(MdiIcons.fileExport), findsOneWidget);
      // The accent takes the same lookup, so the leak shows as a circle even
      // when the glyph is right — the control here declares a color too.
      expect(find.byType(CircleAvatar), findsNothing);
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

    // The failure branch is the one an operator meets on a bad day, and no
    // other surface reports it any more: the status-bar line it replaced is
    // gone, so a dialog that fails to appear leaves them with nothing.
    testWidgets('a failed export is reported, as a failure', (tester) async {
      exports.generateThrows = ExportException('the runtime is not ready');
      await pump(tester);

      await tester.tap(find.text('Save 1 file'));
      await tester.pumpAndSettle();

      final body = await readAndDismissResult(tester);
      expect(body, contains('Export failed'));
      expect(body, contains('the runtime is not ready'));
      expect(body, isNot(contains('Exported')), reason: 'a failure must not read as a success');
    });

    // The save counterpart of the dismissed share sheet: a cancelled picker
    // is the operator's own choice, not an outcome to announce.
    testWidgets('a cancelled save picker is not reported at all', (tester) async {
      exports.saveSucceeds = false;
      await pump(tester);

      await tester.tap(find.text('Save 1 file'));
      await tester.pumpAndSettle();

      expect(find.byType(HaloDialog), findsNothing);
    });

    // Android's SAF never says WHERE the operator put anything, so the save
    // reports the names it got back — and "to <those names>" would tell the
    // operator their files went to their own filenames.
    testWidgets('an Android save names the files, it does not call them a place', (tester) async {
      exports.saveNamesFiles = true;
      await pump(tester);

      await tester.tap(find.text('Save 1 file'));
      await tester.pumpAndSettle();

      final body = await readAndDismissResult(tester);
      expect(body, contains('Exported 1 file: /tmp/exports'));
      expect(body, isNot(contains('file to ')), reason: 'a list of names is not a destination');
    });

    // Android asks per file and takes a cancel partway, so the count the
    // dialog states is the SAVE's, never the list's — "2 files" over one name
    // sends the operator looking for one that was never written.
    testWidgets('a partial save reports what landed, not what was asked for', (tester) async {
      exports.saveCount = 1;
      await pump(tester);

      // Tick the ADIF export too, so two were asked for and one landed.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save 2 files'));
      await tester.pumpAndSettle();

      expect(await readAndDismissResult(tester), contains('Exported 1 file to /tmp/exports'));
    });

    // Reporting unconditionally announced a completed share for a sheet the
    // operator dismissed — worse than the silence it replaced, because it
    // asserts an outcome that didn't happen.
    testWidgets('a dismissed share sheet is not reported as a success', (tester) async {
      exports.shareSucceeds = false;
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op Full.adi'));
      await tester.pumpAndSettle();

      expect(exports.sharedFiles, hasLength(1), reason: 'the share sheet was opened');
      expect(find.byType(HaloDialog), findsNothing);
    });

    testWidgets('a completed share is reported', (tester) async {
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('Share 2026-07-15 N0CALL Test Op Full.adi'));
      await tester.pumpAndSettle();

      expect(exports.sharedOrigin, isNotNull);
      expect(exports.sharedOrigin!.isEmpty, isFalse);

      expect(await readAndDismissResult(tester), contains('Shared 1 file'));
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

      // It belongs to no activity, so it declares no colour and was the one
      // bare glyph in a column of circled ones.
      final circle = tester.widget<CircleAvatar>(find.ancestor(
        of: find.byIcon(MdiIcons.briefcaseUpload),
        matching: find.byType(CircleAvatar),
      ));
      expect(circle.backgroundColor, HaLoColors.light.devMode.withValues(alpha: 0.6));
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

      await readAndDismissResult(tester);
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
    // The operator who came to export everything should not have to reach the
    // end of the formats to find the button that does it.
    testWidgets('the combined batch opens the list, above every callsign', (tester) async {
      await pump(tester);

      final combinedY = tester.getCenter(find.text('Save combined 2 files')).dy;
      expect(combinedY, lessThan(tester.getCenter(find.text('N0CALL')).dy));
      expect(combinedY, lessThan(tester.getCenter(find.text('W1AW')).dy));
      expect(combinedY, lessThan(tester.getCenter(find.text('Full ADIF Export').first).dy),
          reason: 'above the first export row, not merely the first header');
    });

    // Three bands a shade apart read as three unrelated things rather than as
    // the frame around one list.
    testWidgets('the callsign bands and the batch band paint the same ground', (tester) async {
      await pump(tester);

      Color? bandUnder(Finder text) => tester
          .widget<Container>(find.ancestor(of: text, matching: find.byType(Container)).first)
          .color;

      final callsignBand = bandUnder(find.text('N0CALL'));
      expect(callsignBand, isNotNull);
      // Opaque, not a tint laid over the surface: this band pins, and the
      // rows scrolling underneath show straight through a translucent one.
      expect(callsignBand!.a, 1.0);
      expect(bandUnder(find.text('Save combined 2 files')), callsignBand);
      expect(bandUnder(find.text('Operation has unsynced changes')), callsignBand);
    });

    // A Row lays a non-flex child out with unbounded width, so the callsign's
    // ellipsis cannot make room for two counted labels — it gives way first
    // and the fixed-height band overflows. The count alone is what fits: the
    // icon already carries the verb.
    testWidgets('a narrow band shows the count alone, and still names itself', (tester) async {
      await pump(tester);
      tester.view.physicalSize = const Size(360, 900);
      await tester.pumpAndSettle();

      expect(find.text('Save 1 file'), findsNothing, reason: 'the label is what did not fit');
      expect(find.descendant(of: find.byType(FilledButton), matching: find.text('1')),
          findsNWidgets(2), reason: 'one per callsign');
      // No tooltips in this app, so the accessible name is the only name the
      // button has — "1" tells a screen-reader user nothing.
      expect(find.bySemanticsLabel('Save 1 file'), findsWidgets);
      expect(find.text('N0CALL'), findsOneWidget, reason: 'the callsign kept its room');
    });

    // The pinned band declares its height before its child is laid out and
    // the SizedBox clamps whatever comes back, so the constant and the
    // button's own 40 floor are coupled with zero slack: a button theme that
    // adds a pixel of padding clips the band instead of growing it, silently.
    testWidgets('the pinned band is exactly as tall as what it carries', (tester) async {
      await pump(tester);

      final band = find.ancestor(of: find.text('N0CALL'), matching: find.byType(Container)).first;
      final button = find.widgetWithText(FilledButton, 'Save 1 file').first;
      expect(
        tester.getSize(band).height,
        tester.getSize(button).height + Space.lg * 2,
        reason: 'the declared extent must be what the band actually needs',
      );
    });

    // Every group offers the same formats under a different callsign, so a
    // band that scrolls away leaves rows the operator cannot tell apart.
    testWidgets('a callsign band pins while its own exports scroll under it', (tester) async {
      await pump(tester);
      // Short enough that the list actually scrolls.
      tester.view.physicalSize = const Size(1100, 300);
      await tester.pumpAndSettle();

      final firstRow = find.text('Full ADIF Export').first;
      final rowBefore = tester.getTopLeft(firstRow).dy;

      // Past the band's own place in the list, but well short of the end of
      // its group — where the NEXT callsign's band takes over and pushes it
      // off, which is the other half of pinning and not what this asserts.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(firstRow).dy, lessThanOrEqualTo(rowBefore - 100), reason: 'the rows moved');
      expect(find.text('N0CALL'), findsOneWidget, reason: 'its band did not go with them');
      final band = find.ancestor(of: find.text('N0CALL'), matching: find.byType(Container)).first;
      expect(tester.getTopLeft(band).dy, closeTo(0, 0.5),
          reason: 'the band is stuck to the top of the viewport');
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
            'filename': '2026-07-15 $call Multi Full.adi',
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
  Future<({String location, int count, bool namesFiles})?> saveToDisk(
          List<Map<String, dynamic>> files) async =>
      (location: '/tmp/exports', count: files.length, namesFiles: false);

  @override
  Future<bool> shareFiles(List<Map<String, dynamic>> files, {Rect? sharePositionOrigin}) async =>
      true;
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

/// The confirmation the panel raises after every completed export, read and
/// dismissed. Scoped to the [HaloDialog]: the pane's own footer carries a
/// Done too, and a bare `find.text('Done')` would match it and pass with no
/// dialog on screen at all.
Future<String> readAndDismissResult(WidgetTester tester) async {
  final body = tester
      .widgetList<Text>(find.descendant(of: find.byType(HaloDialog), matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .join(' | ');
  await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.text('Done')));
  await tester.pumpAndSettle();
  expect(find.byType(HaloDialog), findsNothing, reason: 'Done dismisses the confirmation');
  return body;
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

  /// Whether to append a contest's Cabrillo, which names a refType but no
  /// icon or color of its own — the shape every contest hook returns.
  bool includeContest = false;
  bool includeSecondPark = false;

  /// An icon name for that Cabrillo, for the test that gives it one that
  /// doesn't resolve.
  String? contestIcon;

  /// Holds the option load open, for the test that has to see the pane
  /// mid-load. The real one waits on the extension host, which a fake
  /// answering synchronously never reproduces.
  Completer<void>? holdOptions;

  @override
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    if (holdOptions != null) await holdOptions!.future;
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
        'filename': compact ? 'N0CALL-20260715-test-op-full.adi' : '2026-07-15 N0CALL Test Op Full.adi',
        'selectedByDefault': false,
        'priority': -1,
      },
      {
        'hookKey': 'pota',
        'exportType': 'potaActivation-adif',
        'exportKey': 'pota-adif:US-1234',
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
      if (includeSecondPark)
        {
          'hookKey': 'pota',
          'exportType': 'potaActivation-adif',
          'exportKey': 'pota-adif:US-5678',
          'format': 'adif',
          'stationCall': operation.stationCalls.first,
          'label': 'POTA US-5678',
          'filename': 'N0CALL-US-5678.adi',
          'selectedByDefault': true,
          'priority': 0,
        },
      if (includeContest)
        {
          'hookKey': 'cqww',
          'exportType': 'cabrillo',
          'format': 'cabrillo',
          'refType': 'cqww',
          'stationCall': operation.stationCalls.first,
          'label': 'CQ WW Cabrillo',
          if (contestIcon != null) 'icon': contestIcon,
          'filename': '2026-07-15 N0CALL CQWW.log',
          'selectedByDefault': true,
          'priority': 0,
        },
      if (includeQson)
        {
          'hookKey': 'core-devmode',
          'exportType': 'devmode-qson',
          'stationCall': operation.stationCalls.first,
          'label': 'Developer Mode: QSON Export',
          'icon': 'briefcase-upload',
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
    if (generateThrows != null) throw generateThrows!;
    return [
      for (final option in selectedOptions)
        {'filename': option['filename'], 'mimeType': 'text/plain', 'content': 'x'},
    ];
  }

  /// Null stands for the operator cancelling the picker, and [saveCount] for
  /// a save that landed fewer files than it was handed — Android's per-file
  /// dialogs, cancelled partway.
  bool saveSucceeds = true;
  int? saveCount;

  /// Thrown by [generateExports], for the failure the panel has to report.
  Object? generateThrows;

  /// True for the Android shape, where `location` is the list of names the
  /// platform gave back rather than a place the files went.
  bool saveNamesFiles = false;

  @override
  Future<({String location, int count, bool namesFiles})?> saveToDisk(
      List<Map<String, dynamic>> files) async {
    savedFiles.addAll(files);
    if (!saveSucceeds) return null;
    return (
      location: '/tmp/exports',
      count: saveCount ?? files.length,
      namesFiles: saveNamesFiles,
    );
  }

  /// What the share sheet answered. False stands for the operator dismissing
  /// it without picking a target.
  bool shareSucceeds = true;

  /// The anchor the panel passed. iPadOS refuses to present the share popover
  /// without one, so the share test asserts it arrived — dropping the
  /// argument at the call site re-breaks iPad while every other platform
  /// stays green.
  Rect? sharedOrigin;

  @override
  Future<bool> shareFiles(List<Map<String, dynamic>> files, {Rect? sharePositionOrigin}) async {
    sharedFiles.addAll(files);
    sharedOrigin = sharePositionOrigin;
    return shareSucceeds;
  }
}

/// Never called — [_FakeExportService] overrides everything that would reach
/// the database.
class _UnusedQsos implements QsosRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
