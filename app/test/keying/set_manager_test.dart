// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The folders sets are filed in, and the manager that files them — through
// the CW sets, which need no audio. The traps: a folder change that loses a
// set (a folder is a way of filing, never a container a set dies with), a
// folder moved into its own subfolder (it and everything in it drop off the
// tree), a rename that is lost because the pane closed before Enter, and
// a folder opened or closed written into the folders themselves (a fold is
// how a list was left, not a setting).

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/sets/cw_message_set_category.dart';
import 'package:ham2k_logger/services/sets/set_tree.dart';
import 'package:ham2k_logger/views/sets/set_manager_pane.dart';
import 'package:ham2k_logger/views/sets/set_picker_field.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the tree', () {
    test('deleting a folder moves what was in it up a level, sets and folders alike', () {
      var (tree, outer) = const SetTree().addFolder('Contests');
      late SetFolder inner;
      (tree, inner) = tree.addFolder('CQ WW', parent: outer.id);
      final (withLeaf, leaf) = tree.addFolder('SSB', parent: inner.id);
      tree = withLeaf.moveSet('a', inner.id).moveSet('b', outer.id);

      tree = tree.deleteFolder(inner.id);
      expect(tree.folderOf('a'), outer.id, reason: "into the deleted folder's parent, not the top");
      expect(tree.folder(leaf.id)?.parent, outer.id);
      expect(tree.folderOf('b'), outer.id);
      expect(
        [
          for (final row in tree.rows(['a', 'b'])) row is SetTreeSetRow ? row.id : (row as SetTreeFolderRow).folder.name,
        ],
        ['Contests', 'a', 'b', 'SSB'],
      );
    });

    test('a folder never moves into itself or one inside it', () {
      var (tree, outer) = const SetTree().addFolder('Contests');
      late SetFolder inner;
      (tree, inner) = tree.addFolder('CQ WW', parent: outer.id);
      expect(tree.moveFolder(outer.id, inner.id), same(tree));
      expect(tree.moveFolder(outer.id, outer.id), same(tree));
    });

    test('a stored tree that loops, or files a set in a folder that is gone, still shows every set', () {
      // What a merge of two devices' edits can leave behind.
      final tree = SetTree.fromJson({
        'folders': [
          {'id': 'x', 'name': 'X', 'parent': 'y'},
          {'id': 'y', 'name': 'Y', 'parent': 'x'},
        ],
        'placement': {'a': 'x', 'b': 'gone'},
      });
      final rows = tree.rows(['a', 'b']);
      expect([
        for (final row in rows)
          if (row is SetTreeSetRow) row.id,
      ], unorderedEquals(['a', 'b']));
      expect([
        for (final row in rows)
          if (row is SetTreeFolderRow) row.folder.id,
      ], unorderedEquals(['x', 'y']));
    });

    test('a closed folder shows its own row and nothing under it', () {
      var (tree, folder) = const SetTree().addFolder('Contests');
      tree = tree.moveSet('a', folder.id);
      expect(tree.rows(['a', 'b'], open: {}).length, 2, reason: 'b, then the folder');
      expect(tree.rows(['a', 'b'], open: {folder.id}).length, 3);
    });
  });

  group('the manager', () {
    late HaLoServices services;
    late CwMessageSetCategory category;
    late SetFolder outer, inner;

    setUp(() async {
      services = (await makeHaLoServices()).services;
      category = CwMessageSetCategory(services.settings);
      var (tree, a) = category.tree.addFolder('Contests');
      final (withInner, b) = tree.addFolder('CQ WW', parent: a.id);
      (outer, inner) = (a, b);
      await category.setTree(withInner);
    });

    Widget host() => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => showSetManagerPane(context, services, category), child: const Text('open')),
          ),
        ),
      ),
    );

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// A drag on a touch screen, which the test platform is: it starts with
    /// a long press.
    Future<void> drag(WidgetTester tester, String from, String to) async {
      final target = tester.getCenter(find.text(to));
      final gesture = await tester.startGesture(tester.getCenter(find.text(from)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.moveTo(target + const Offset(0, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Future<void> rename(WidgetTester tester, String name, String to) async {
      await tester.tap(find.bySemanticsLabel('Actions for $name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), to);
    }

    testWidgets('the picked set is shown with the folders it is filed in, so a name repeated in another folder reads apart', (tester) async {
      await category.setTree(category.tree.moveSet('pota', inner.id));
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: SetPickerField(services: services, category: category, label: 'Sets', value: 'pota', onChanged: (_) {}),
            ),
          ),
        ),
      );
      expect(find.text('Contests / CQ WW / POTA', findRichText: true), findsOneWidget);
    });

    // The trap: a list left up over the dialog while the field beside it
    // takes the click meant to close it.
    testWidgets('the open list is modal: a folder opens in it, and a tap outside closes it and reaches nothing under it', (tester) async {
      var reached = false;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => reached = true, child: const Text('beside')),
                  SetPickerField(services: services, category: category, label: 'Sets', value: 'pota', onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SetPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contests'));
      await tester.pumpAndSettle();
      expect(find.text(category.manageLabel), findsOneWidget, reason: 'a folder is no choice to close on');
      expect(find.text('CQ WW'), findsOneWidget);

      await tester.tap(find.text('beside'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(category.manageLabel), findsNothing);
      expect(reached, isFalse);

      // Placed against the field when it opened, it would be left adrift.
      await tester.tap(find.byType(SetPickerField));
      await tester.pumpAndSettle();
      tester.view.physicalSize = tester.view.physicalSize * 0.9;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(find.text(category.manageLabel), findsNothing, reason: 'a window resized under the list closes it');
    });

    testWidgets('a set dropped on a folder goes into it; a folder dropped on its own subfolder stays put', (tester) async {
      await open(tester);
      await drag(tester, 'POTA', 'CQ WW');
      expect(category.tree.folderOf('pota'), inner.id);

      await drag(tester, 'Contests', 'CQ WW');
      expect(category.tree.folder(outer.id)?.parent, isNull);
      expect(category.tree.folder(inner.id)?.parent, outer.id, reason: 'still under Contests, and both still on the tree');
      expect(find.text('POTA'), findsOneWidget, reason: 'and the set in it still listed');
    });

    testWidgets('a rename happens in the row: Escape keeps the old name, and one left mid-edit is kept when the pane closes', (tester) async {
      await open(tester);
      await rename(tester, 'POTA', 'Parks');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(category.nameOf('pota'), 'POTA');
      expect(find.text('CW Message Sets'), findsOneWidget, reason: "Escape was the field's, not the pane's");

      // Closed by Back, with no Enter and no tap elsewhere first: the field
      // going away is the only thing that says the edit is over.
      await rename(tester, 'POTA', 'Parks');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('CW Message Sets'), findsNothing);
      expect(category.nameOf('pota'), 'Parks');

      // Torn down with the field still focused, no focus change ever comes:
      // only the field's own going away can keep the name.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await rename(tester, 'Parks', 'Parks on the Air');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(category.nameOf('pota'), 'Parks on the Air');
    });

    test('which folders are open is kept apart from the folders themselves', () async {
      final stored = services.settings.settingValue(SettingsService.radioGroup, category.treeKey);
      await category.toggleFolder(outer.id);
      expect(category.openFolders, {outer.id});
      expect(services.settings.settingValue(SettingsService.radioGroup, category.treeKey), stored);
      expect(CwMessageSetCategory(services.settings).openFolders, {outer.id}, reason: 'read back by any picker on this device');

      await category.toggleFolder(outer.id);
      expect(category.openFolders, isEmpty);
    });
  });
}
