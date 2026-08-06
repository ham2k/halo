// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The render budget an extension panel is documented to keep
// (docs/extensions/hooks.md). Every pane of a dock group stays MOUNTED so
// in-progress input survives a tab switch, so nothing about being built says
// anything about being looked at — and each of these rules is invisible from
// the outside, which is how the whole budget came to be documented in three
// places while implemented in none.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

void main() {
  /// Never pumpAndSettle here: a panel with no content yet shows a
  /// progress indicator, which animates forever. These pumps are long
  /// enough to carry a render's throttle window (panelRenderThrottle).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  const definition = PanelDefinition(
    id: 'ext:wx:forecast',
    title: 'Forecast',
    source: PanelSource.extension,
    hookKey: 'wx',
    panelKey: 'forecast',
    triggers: ['qsoLogged'],
  );

  Operation operation() => Operation(uuid: 'op-1', data: const {'stationCall': 'N0DEV'});

  Widget harness(_RecordingPanels panels, {required bool visible, int qsoCount = 0}) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: visible,
              child: ExtensionPanel(
                panel: definition,
                panels: panels,
                renderContext: PanelRenderContext(operation: operation(), qsoCount: qsoCount),
              ),
            ),
          ),
        ),
      );

  testWidgets('a panel that starts behind a tab does not render at all', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);

    // A group of four extension panels would otherwise fire four bridge
    // calls the moment it is built, three of them for panes nobody can see.
    expect(panels.renders, isEmpty);
  });

  testWidgets('it renders as soon as it is looked at', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);

    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    expect(panels.renders, ['initial']);
  });

  testWidgets('a trigger that fires behind a tab is remembered, not rendered', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    expect(panels.renders, ['initial']);

    // Hidden, and its trigger fires.
    await tester.pumpWidget(harness(panels, visible: false, qsoCount: 1));
    await settle(tester);
    expect(panels.renders, ['initial'], reason: 'nobody is looking at it');

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1));
    await settle(tester);
    // What it missed, once — not once per trigger that fired while hidden.
    expect(panels.renders, ['initial', 'visible']);
  });

  testWidgets('coming back to a tab where nothing happened costs nothing', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);

    // A descriptor with no trigger for what changed renders once and stays
    // put — tab switching is not itself a reason to cross the bridge.
    expect(panels.renders, ['initial']);
  });
}

/// Records what it was asked to render, and why.
class _RecordingPanels extends PanelService {
  _RecordingPanels() : super(_NullSource());

  final renders = <String>[];

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders.add(args['reason'] as String);
    return {'kind': 'markdown', 'content': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async => const {};
}

class _NullSource implements PanelExtensionSource {
  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => const [];

  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};
}
