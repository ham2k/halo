// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene control's action, from the pane's side: what it is sent with, and
// who is blamed when it cannot be sent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_panel_extensions.dart';

class _ScenePanels extends PanelService {
  _ScenePanels({Future<String?> Function(String, Map<String, dynamic>)? onUpdateOperation})
    : super(FakePanelExtensions(), onUpdateOperation: onUpdateOperation);

  bool configUnreadable = false;
  Map<String, dynamic>? reply = const {'values': <String, dynamic>{}};
  final events = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async => {
    'kind': 'scene',
    'scene': {
      'version': 1,
      'width': 400,
      'height': 200,
      'values': <String, dynamic>{},
      'layers': <dynamic>[],
      'controls': [
        {'id': 'go', 'label': 'Tune', 'kind': 'button', 'x': 0, 'y': 0, 'width': 200, 'height': 100, 'event': 'go'},
      ],
    },
  };

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async {
    if (configUnreadable) throw StateError('keychain is locked');
    return const {'radio': 'rig-b'};
  }

  @override
  Future<Map<String, dynamic>?> event(PanelDefinition panel, Map<String, dynamic> args) async {
    events.add(args);
    return reply;
  }
}

const _panel = PanelDefinition(id: 'ext:rig:face', title: 'Rig', source: PanelSource.extension, hookKey: 'rig', panelKey: 'face');

void main() {
  setUp(ErrorReportingService.resetFailureStreaks);
  tearDown(ErrorReportingService.resetFailureStreaks);

  Future<void> show(WidgetTester tester, _ScenePanels panels, {Operation? operation}) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: true,
              child: ExtensionPanel(
                panel: _panel,
                panels: panels,
                renderContext: PanelRenderContext(operation: operation),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  // A hook that forgets to return answers null (or an object with neither
  // field). Read as an empty patch, the control would keep the operator's
  // value on screen as if the extension had taken it.
  for (final (name, reply) in [
    ('nothing', null),
    ('neither values nor strings', <String, dynamic>{}),
    // A scene refuses a key in both maps; a patch taking one silently
    // would apply whichever map the merge happened to list last.
    (
      'a key as both a number and a string',
      <String, dynamic>{
        'values': {'mode': 1},
        'strings': {'mode': 'CW'},
      },
    ),
  ]) {
    testWidgets('an event answered with $name fails the action', (tester) async {
      final panels = _ScenePanels()..reply = reply;
      addTearDown(panels.dispose);
      await withErrorHooks(() async {
        await show(tester, panels);
        await tester.tap(find.bySemanticsLabel('Tune'));
        await tester.pump();
        await tester.pump();
        expect(panels.events, hasLength(1));
        expect(find.text(t.operation.layout.panelActionFailed), findsOneWidget);
      });
    });
  }

  testWidgets('an action is sent with the panel\'s config', (tester) async {
    final panels = _ScenePanels();
    addTearDown(panels.dispose);
    await show(tester, panels);
    await tester.tap(find.bySemanticsLabel('Tune'));
    await tester.pump();
    expect(panels.events.single['config'], {'radio': 'rig-b'});
    expect(find.text(t.operation.layout.panelActionFailed), findsNothing);
  });

  testWidgets('a scene button applies a setup patch to its open operation even if the reply names another log', (tester) async {
    final updates = <(String, String)>[];
    final panels =
        _ScenePanels(
            onUpdateOperation: (uuid, patch) async {
              updates.add((uuid, patch['userTitle'] as String));
              return null;
            },
          )
          ..reply = {
            'values': <String, dynamic>{},
            'updateOperation': {'uuid': 'different-log', 'userTitle': 'North Trailhead'},
          };
    addTearDown(panels.dispose);
    await show(
      tester,
      panels,
      operation: const Operation(uuid: 'open-log', data: {}),
    );
    await tester.tap(find.bySemanticsLabel('Tune'));
    await tester.pump();

    expect(updates, [('open-log', 'North Trailhead')]);
    expect(find.text(t.operation.layout.panelActionFailed), findsNothing);
  });

  testWidgets('a scene button tells the operator which setup entry was refused', (tester) async {
    const rejection = 'POTA does not recognize BAD-PARK';
    final panels = _ScenePanels(onUpdateOperation: (_, _) async => rejection)
      ..reply = {
        'values': <String, dynamic>{},
        'updateOperation': {
          'addActivationRefs': [
            {'activityKey': 'pota', 'ref': 'BAD-PARK'},
          ],
        },
      };
    addTearDown(panels.dispose);
    await show(
      tester,
      panels,
      operation: const Operation(uuid: 'open-log', data: {}),
    );
    await tester.tap(find.bySemanticsLabel('Tune'));
    await tester.pump();

    await tester.pump();
    expect(find.text(rejection), findsOneWidget);
  });

  testWidgets('a scene button on Home cannot target an operation by its UUID', (tester) async {
    final panels = _ScenePanels(onUpdateOperation: (_, _) async => fail('Home has no operation to update'))
      ..reply = {
        'values': <String, dynamic>{},
        'updateOperation': {'uuid': 'some-log', 'userTitle': 'North Trailhead'},
      };
    addTearDown(panels.dispose);
    await show(tester, panels);
    await tester.tap(find.bySemanticsLabel('Tune'));
    await tester.pump();

    await tester.pump();
    expect(find.text(t.commands.noOperationOpen), findsOneWidget);
  });

  // A render falls back to an empty config; an ACTION must not. The config is
  // where a panel keeps which radio it commands, so running on defaults tunes
  // the wrong rig. And the fault is the keychain's: reported as the panel's,
  // it sends the investigation to the extension.
  testWidgets('an unreadable config refuses the action, and is not blamed on the panel', (tester) async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      final panels = _ScenePanels();
      addTearDown(panels.dispose);
      await show(tester, panels);
      panels.configUnreadable = true;
      await tester.tap(find.bySemanticsLabel('Tune'));
      await tester.pump();
      await tester.pump();

      expect(panels.events, isEmpty);
      expect(find.text(t.operation.layout.panelActionFailed), findsOneWidget);
      // The reporter appends the streak length to the context it was given.
      final contexts = backend.exceptions.map((e) => e.context ?? '').toList();
      expect(contexts, [startsWith('panel:config:${_panel.id}')]);
    }, backend: backend);
  });
}
