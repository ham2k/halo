// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyer sets an extension offers (docs/extensions/commands.md § keyerSets),
// through the CW sets, which need no audio. The traps: the Extensions folder
// written into the operator's own folders (it would outlive the extension,
// and sync to a device without it); an edit that lands in an offered set, or
// looks made and lands nowhere silently; the pick of an offered set lost when
// the extension goes away for a while, or when the operator writes their
// own sets; and a hook that fails for a moment taking its sets, and the set
// in use, with it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/sets/cw_message_set_category.dart';
import 'package:ham2k_logger/services/sets/offered_keyer_sets.dart';
import 'package:ham2k_logger/services/sets/set_tree.dart';
import 'package:ham2k_logger/views/sets/set_manager_pane.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an answer', () {
    test('is filed under the hook that gave it, so two extensions can each offer a "contest" set', () {
      final a = OfferedKeyerSets.parse({'kind': 'cw', 'id': 'contest', 'name': 'Contest', 'messages': <String>[]}, hookKey: 'a');
      final b = OfferedKeyerSets.parse({'kind': 'cw', 'id': 'contest', 'name': 'Contest', 'messages': <String>[]}, hookKey: 'b');
      expect(a.cw!.id, isNot(b.cw!.id));
      expect(isOfferedSetId(a.cw!.id), isTrue, reason: 'and never taken for one of the operator\'s');
    });

    test('that is not a set is refused, not padded into one', () {
      Object? refused(Map<String, dynamic> item) {
        try {
          OfferedKeyerSets.parse(item, hookKey: 'x');
          return null;
        } on FormatException catch (e) {
          return e;
        }
      }

      expect(refused({'kind': 'cw', 'name': 'No id', 'messages': <String>[]}), isNotNull);
      expect(refused({'kind': 'cw', 'id': 'a', 'messages': <String>[]}), isNotNull, reason: 'no name');
      expect(refused({'kind': 'rtty', 'id': 'a', 'name': 'A', 'messages': <String>[]}), isNotNull);
      expect(refused({'kind': 'cw', 'id': 'a', 'name': 'A', 'messages': List.filled(9, 'CQ')}), isNotNull, reason: 'nine messages for eight keys');
      expect(refused({'kind': 'voice', 'id': 'a', 'name': 'A', 'templates': 'CQ'}), isNotNull);
      expect(refused({'kind': 'cw', 'id': 'a:b', 'name': 'A', 'messages': <String>[]}), isNotNull, reason: "the id's last ':' ends the hook key");
    });
  });

  group('offered CW sets', () {
    late HaLoServices services;
    late CwMessageSetCategory category;

    /// What the `keyerSets` hooks answer, entry by entry, as the runtime
    /// hands them over: `{key, ok, value}`.
    late List<Map<String, dynamic>> answer;

    /// Thrown in place of any answer: the fan-out itself failing.
    Object? fanOutFailure;

    Map<String, dynamic> contest({String id = 'cqww', String name = 'CQ WW'}) => {
      'kind': 'cw',
      'id': id,
      'name': name,
      'messages': ['CQ TEST {{op.call}}', '5NN 14'],
      'labels': ['CQ', 'Exch'],
    };

    Future<void> offer(List<Map<String, dynamic>> entries) async {
      answer = entries;
      await services.extensions.refreshOfferedKeyerSets();
    }

    String offeredId([String id = 'cqww']) => '${offeredSetIdPrefix}contests:$id';

    setUp(() async {
      answer = const [];
      fanOutFailure = null;
      services = (await makeHaLoServices(stubs: {'keyerSets:*:getSets': (Object? _) => fanOutFailure != null ? throw fanOutFailure! : answer})).services;
      category = CwMessageSetCategory(services.settings);
    });

    test('are listed in a folder for their extension inside Extensions, after the operator\'s folders, and none of it is stored', () async {
      final (withFolder, _) = category.tree.addFolder('Zulu');
      await category.setTree(withFolder);
      expect(category.tree.rows([for (final set in category.sets) set.id]).whereType<SetTreeFolderRow>(), hasLength(1), reason: 'nothing offered, no folder');

      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      final rows = category.rows;
      expect([for (final row in rows) row is SetTreeFolderRow ? '${row.depth}:${row.folder.name}' : null].nonNulls, [
        '0:Zulu',
        '0:${t.sets.extensionsFolder}',
        '1:contests',
      ], reason: 'the extensions\' folder last, even after a "Z"');
      expect(rows.last, isA<SetTreeSetRow>().having((row) => row.id, 'id', offeredId()));
      expect(category.tree.pathOf(category.tree.folderOf(offeredId())!), [t.sets.extensionsFolder, 'contests']);

      // Any folder change writes the whole tree back.
      await category.setTree(category.tree.renameFolder(withFolder.folders.single.id, 'Yankee'));
      final stored = services.settings.settingValue(SettingsService.radioGroup, CwMessageSet.treeKey).toString();
      expect(stored, isNot(contains(offeredSetIdPrefix)));
    });

    test('picked, key what they say; the extension gone leaves the first set, and back, its set is in use again', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      await services.settings.setCwMessageSets(services.settings.cwMessageSets, active: offeredId());
      expect(services.settings.cwMessage(1), 'CQ TEST {{op.call}}');

      await offer(const []);
      expect(services.settings.cwMessageSetId, services.settings.cwMessageSets.first.id);

      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      expect(services.settings.cwMessageSetId, offeredId());
    });

    test('a hook that fails keeps what it offered, and the set in use stays in use', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      await services.settings.setCwMessageSets(services.settings.cwMessageSets, active: offeredId());
      await offer([
        {'key': 'contests', 'ok': false, 'error': 'TypeError: boom'},
      ]);
      expect(services.settings.cwMessageSetId, offeredId());
    });

    // The trap: a fan-out that never ran reads exactly like every hook
    // answering nothing, and the set in use drops to the first.
    // The trap: a single extension reloaded by the dev server bumps the
    // generation without restarting the runtime, and its edited sets never
    // reach the picker.
    test('are asked again on every runtime generation, a single extension\'s reload included', () async {
      answer = [
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ];
      services.extensions.runtimeGeneration.value++;
      await pumpEventQueue();
      expect(services.settings.offeredKeyerSets.cw.map((o) => o.set.id), [offeredId()]);
    });

    test('a fan-out that fails outright changes nothing', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      await services.settings.setCwMessageSets(services.settings.cwMessageSets, active: offeredId());
      fanOutFailure = StateError('runtime gone');
      await services.extensions.refreshOfferedKeyerSets();
      expect(services.settings.cwMessageSetId, offeredId());
    });

    test('a CW set and a voice set may share an id', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [
            contest(),
            {
              'kind': 'voice',
              'id': 'cqww',
              'name': 'CQ WW',
              'templates': <String>['CQ contest'],
            },
          ],
        },
      ]);
      expect(services.settings.offeredKeyerSets.cw.map((o) => o.set.id), [offeredId()]);
      expect(services.settings.offeredKeyerSets.voice.map((o) => o.set.id), [offeredId()]);
    });

    test('a malformed set is left out and the extension\'s others are offered', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [
            contest(),
            {'kind': 'cw', 'id': 'bad', 'name': 'Bad', 'messages': 'not a list'},
            contest(name: 'Again'),
          ],
        },
      ]);
      expect([for (final set in category.sets) set.id].where(isOfferedSetId), [offeredId()], reason: 'and the second with the same id is not a second set');
    });

    test('nothing the operator writes lands in one, and their own writes keep it picked', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      await services.settings.setCwMessageSets(services.settings.cwMessageSets, active: offeredId());

      // SET's path: it reads the message back and says it was not stored.
      await services.settings.setCwMessage(1, 'CQ CQ');
      expect(services.settings.cwMessage(1), 'CQ TEST {{op.call}}');

      final own = services.settings.cwMessageSets.first.id;
      await category.rename(own, 'Mine');
      await category.rename(offeredId(), 'Hijacked');
      expect(services.settings.cwMessageSetId, offeredId());
      expect(category.nameOf(offeredId()), 'CQ WW');
      expect(category.canRename(offeredId()), isFalse);
      expect(category.canDelete(offeredId()), isFalse);
    });

    test('duplicated, one is the operator\'s own: with their sets, at the top level, theirs to change', () async {
      await offer([
        {
          'key': 'contests',
          'ok': true,
          'value': [contest()],
        },
      ]);
      final copy = await category.duplicate(offeredId(), 'CQ WW copy');
      expect(copy, isNotNull);
      expect(isOfferedSetId(copy!), isFalse);
      expect(services.settings.cwMessageSets.map((set) => set.id), contains(copy));
      expect(category.tree.folderOf(copy), isNull);
      expect(category.canRename(copy), isTrue);

      await services.settings.setCwMessageSets(services.settings.cwMessageSets, active: copy);
      await services.settings.setCwMessage(1, 'CQ CQ');
      expect(services.settings.cwMessage(1), 'CQ CQ');
    });

    testWidgets('the manager offers only Duplicate and Export for one, and nothing for its folders', (tester) async {
      await tester.runAsync(
        () => offer([
          {
            'key': 'contests',
            'ok': true,
            'value': [contest()],
          },
        ]),
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(onPressed: () => showSetManagerPane(context, services, category), child: const Text('open')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Future<Map<String, bool>> actions(String name) async {
        await tester.tap(find.bySemanticsLabel('Actions for $name'));
        await tester.pumpAndSettle();
        final enabled = {
          for (final button in tester.widgetList<MenuItemButton>(find.byType(MenuItemButton))) (button.child! as Text).data!: button.onPressed != null,
        };
        // The ⋮ again: a tap outside would close the pane with the menu.
        await tester.tap(find.bySemanticsLabel('Actions for $name'));
        await tester.pumpAndSettle();
        return enabled;
      }

      final m = t.sets;
      expect(await actions('CQ WW'), {m.rename: false, m.duplicate: true, m.moveTo: false, m.export: true, m.delete: false});
      expect((await actions('contests')).values, everyElement(isFalse));
      expect((await actions(m.extensionsFolder)).values, everyElement(isFalse));
    });
  });
}
