// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A placement's own config and menu (extension API 23): the descriptor's `config`, `initialConfig`
// and `file`, a render's `form` and `menu`, and an event's `config` answer. Each is a promise
// about what a pane keeps, and a broken one keeps the wrong thing without a word.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_menu.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/settings/system_lists.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

import '../support/fake_panel_extensions.dart';

Map<String, dynamic> _entry({Object? initialConfig, Object? file}) => {
  'hookKey': 'control-board',
  'key': 'sample',
  'title': 'Sample',
  'multiple': true,
  'form': [
    {'type': 'field', 'fieldType': 'multiline', 'key': 'board', 'label': 'Board'},
  ],
  'config': ['params'],
  'initialConfig': ?initialConfig,
  'file': ?file,
};

void main() {
  group('a descriptor', () {
    test('keeps its `config` keys as config fields, so a layout file and a removal reach them too', () {
      final panel = PanelDefinition.fromExtensionEntry(_entry())!;
      expect([for (final f in panel.configFields) f['key']], ['board', 'params']);
    });

    test('drops an initialConfig key it does not declare: nothing could read it back, or forget it', () {
      final panel = PanelDefinition.fromExtensionEntry(_entry(initialConfig: {'board': 'items: []', 'stray': 1}))!;
      expect(panel.initialConfig, {'board': 'items: []'});
    });

    test('takes a file only as { key, extension }, the extension a plain lowercase word', () {
      expect(PanelDefinition.fromExtensionEntry(_entry(file: {'key': 'board', 'extension': 'h2kboard'}))!.file, (key: 'board', extension: 'h2kboard'));
      // A dot or a path in it would become part of the saved file's name.
      expect(PanelDefinition.fromExtensionEntry(_entry(file: {'key': 'board', 'extension': '../x'}))!.file, isNull);
      // A key it does not keep would export an empty file.
      expect(PanelDefinition.fromExtensionEntry(_entry(file: {'key': 'nope', 'extension': 'h2kboard'}))!.file, isNull);
    });

    test('its own form\'s Save writes only what that form shows, so a `config` key it does not show is kept', () {
      // A Save writing every config field would write the placement form's `params` as the null
      // the descriptor's dialog never drew, and the operator's Board Settings would be gone.
      final panel = PanelDefinition.fromExtensionEntry(_entry())!;
      expect([for (final f in panel.formValueFields) f['key']], ['board']);
    });

    test('a malformed `config` costs that panel its keys, not the catalog its panels', () {
      expect(PanelDefinition.fromExtensionEntry({..._entry(), 'config': 'params'})!.configKeys, isEmpty);
    });
  });

  group('a placement config', () {
    late FakePanelExtensions source;
    late PanelService panels;
    final descriptor = PanelDefinition.fromExtensionEntry(_entry(initialConfig: {'board': 'sample'}))!;
    final placed = descriptor.asInstance('${descriptor.id}#1');

    setUp(() {
      source = FakePanelExtensions(configs: {});
      panels = PanelService(source);
    });

    test('starts as a copy of initialConfig, written once, so a later sample leaves it alone', () async {
      expect(await panels.configFor(placed), {'board': 'sample'});
      expect(source.writes, hasLength(1));
      // The operator's edit, then a read: what they wrote stands, and nothing is copied over it.
      source.configs[placed.id]!['board'] = 'mine';
      expect(await panels.configFor(placed), {'board': 'mine'});
      expect(source.writes, hasLength(1));
    });

    test('a board emptied by the operator stays empty rather than becoming the sample again', () async {
      source.configs[placed.id] = {'board': ''};
      expect(await panels.configFor(placed), {'board': ''});
      expect(source.writes, isEmpty);
    });

    test('an answer writing a key the descriptor does not declare is refused, not dropped', () async {
      await expectLater(panels.writeConfig(placed, {'nope': 1}), throwsFormatException);
      expect(source.writes, isEmpty);
      final before = panels.configRevision(placed.id);
      await panels.writeConfig(placed, {
        'params': {'rig': 'ic-7300'},
      });
      expect(source.configs[placed.id], {
        'params': {'rig': 'ic-7300'},
      });
      expect(panels.configRevision(placed.id), before + 1, reason: 'the pane renders again with what it now holds');
    });
  });

  group('a render menu', () {
    test('reads a form and entries, each entry an event or the settings', () {
      final menu = PanelPlacementMenu.fromJson({
        'form': {'key': 'params', 'title': 'Board Settings…', 'elements': <Object>[]},
        'menu': [
          {'label': 'Edit Board…', 'settings': true},
          {'label': 'Reset', 'event': 'reset'},
        ],
      })!;
      expect(menu.form?.title, 'Board Settings…');
      expect(menu.entries, [(label: 'Edit Board…', event: null, settings: true), (label: 'Reset', event: 'reset', settings: false)]);
      expect(PanelPlacementMenu.fromJson({'kind': 'markdown'}), isNull);
      // An empty menu offers nothing, and would hide the descriptor's form behind an empty popup.
      expect(PanelPlacementMenu.fromJson({'menu': <Object>[]}), isNull);
    });

    test('refuses a form field the dialog could not keep: one with no key, or a secret', () {
      Map<String, dynamic> form(List<Object> elements) => {
        'form': {'key': 'params', 'title': 'Settings', 'elements': elements},
      };
      for (final elements in [
        [
          {'type': 'field', 'fieldType': 'text'},
        ],
        [
          {
            'type': 'row',
            'elements': [
              {'type': 'field', 'fieldType': 'text'},
            ],
          },
        ],
        // Inside one config object it would travel in a layout file, where only a top-level secret is held back.
        [
          {'type': 'field', 'fieldType': 'secret', 'key': 'token'},
        ],
      ]) {
        expect(() => PanelPlacementMenu.fromJson(form(elements)), throwsFormatException, reason: '$elements');
      }
    });

    test('refuses an entry that is both, or neither, rather than offering one that does nothing', () {
      for (final entry in [
        {'label': 'x'},
        {'label': 'x', 'event': 'e', 'settings': true},
        {'label': '', 'event': 'e'},
      ]) {
        expect(
          () => PanelPlacementMenu.fromJson({
            'menu': [entry],
          }),
          throwsFormatException,
          reason: '$entry',
        );
      }
    });
  });

  test('a system list with `none` offers a way back to no choice, first, valued ""', () async {
    final lists = SystemLists()
      ..equipment = (kind) => [
        {'label': 'IC-7300', 'value': 'uuid-1'},
      ];
    final [field] = await lists.resolveInElements([
      {'type': 'field', 'fieldType': 'select', 'key': 'rig', 'options': r'$core.radios', 'none': 'Designated radio'},
    ]);
    // Without it, a board's radio once picked could never follow the designated radio again.
    expect(field['options'], [
      {'label': 'Designated radio', 'value': ''},
      {'label': 'IC-7300', 'value': 'uuid-1'},
    ]);
  });

  testWidgets('a pane declares its menu, runs a menu event, and keeps the config its answer carries', (tester) async {
    final source = FakePanelExtensions(configs: {});
    final panels = _Panels(source);
    final panel = PanelDefinition.fromExtensionEntry(_entry())!.asInstance('ext:control-board:sample#1');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: true,
              child: ExtensionPanel(
                panel: panel,
                panels: panels,
                renderContext: PanelRenderContext(
                  operation: Operation(uuid: 'op-1', data: const {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(panels.menuOf(panel.id)?.entries.single.event, 'swap', reason: 'the tab offers what the last render named');

    var sent = false;
    unawaited(panels.queueEvent(panel.id, {'controlId': 'menu', 'action': 'swap', 'phase': 'activate', 'sequence': 0}).then((_) => sent = true));
    await tester.pump(const Duration(seconds: 2));
    expect(sent, isTrue, reason: 'the menu that sent it hears it went through');
    expect(panels.events.single['controlId'], 'menu');
    expect(source.configs[panel.id], {
      'params': {'rig': 'b'},
    });
    expect(panels.renders, greaterThan(1), reason: 'drawn again with the config it now holds');
  });

  test('a menu event still waiting when its pane is removed fails, rather than leaving its sender waiting', () async {
    final panels = PanelService(FakePanelExtensions(configs: {}));
    final sent = panels.queueEvent('ext:control-board:sample#1', {'controlId': 'menu'});
    final failed = expectLater(sent, throwsStateError);
    await panels.forgetInstanceConfig('ext:control-board:sample#1');
    await failed;
  });
}

class _Panels extends PanelService {
  _Panels(super.extensions);

  int renders = 0;
  final events = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders++;
    return {
      'kind': 'markdown',
      'content': 'board',
      'menu': [
        {'label': 'Swap', 'event': 'swap'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>?> event(PanelDefinition panel, Map<String, dynamic> args) async {
    events.add((args['event'] as Map).cast<String, dynamic>());
    return {
      'values': <String, Object>{},
      'config': {
        'params': {'rig': 'b'},
      },
    };
  }
}
