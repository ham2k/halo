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

  /// The same panel with nothing declared up front — what a panel rendering
  /// operator-written text looks like before it has read any.
  const triggerless = PanelDefinition(
    id: 'ext:text:custom',
    title: 'Custom Text',
    source: PanelSource.extension,
    hookKey: 'text',
    panelKey: 'custom',
  );

  Widget harness(
    _RecordingPanels panels, {
    required bool visible,
    int qsoCount = 0,
    PanelDefinition panel = definition,
  }) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: visible,
              child: ExtensionPanel(
                panel: panel,
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

  // The half of the budget a panel can only decide once it has read its own
  // config: an operator's `{{ op.qsoCount }}` has to start updating without
  // the descriptor — and therefore every other placement of the same panel —
  // paying for it.
  testWidgets('a trigger the render itself declared wakes that placement', (tester) async {
    final panels = _RecordingPanels(declares: ['qsoLogged']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial']);

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial', 'qsoLogged']);
  });

  testWidgets('a placement that declared nothing is left alone by one that did', (tester) async {
    final panels = _RecordingPanels(declares: ['qsoLogged']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);

    // A second pane of the same panel, rendering static text.
    panels.declares = const [];
    const other = PanelDefinition(
      id: 'ext:text:custom#2',
      title: 'Custom Text',
      source: PanelSource.extension,
      hookKey: 'text',
      panelKey: 'custom',
    );
    await tester.pumpWidget(harness(panels, visible: true, panel: other));
    await settle(tester);
    panels.renders.clear();

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1, panel: other));
    await settle(tester);
    expect(panels.renders, isEmpty, reason: "the other pane's template is what asked for qsoLogged");
  });

  // A triggerless pane has nothing that would ever ask again: no ticker, an
  // empty set for didUpdateWidget to intersect, and a come-back-to-the-tab
  // path gated on a trigger having fired. A first render that fails — a
  // runtime still starting, a bridge timeout — would otherwise leave the
  // pane broken for the whole session, curable only by editing its config.
  testWidgets('a failed panel offers a retry, and the retry renders', (tester) async {
    final panels = _RecordingPanels()..failNextRender = true;
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial']);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(panels.renders, ['initial', 'retry']);
    expect(find.text('Try again'), findsNothing, reason: 'the retry succeeded, so the pane is content again');
  });

  testWidgets('a tick a render declared starts the ticker', (tester) async {
    final panels = _RecordingPanels(declares: ['tick:5']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial']);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(panels.renders, ['initial', 'tick']);
  });
}

/// Records what it was asked to render, and why. [declares] is what its
/// renders claim to need, as a templated panel's would.
class _RecordingPanels extends PanelService {
  _RecordingPanels({this.declares = const []}) : super(_NullSource());

  List<String> declares;
  final renders = <String>[];

  /// Fails one render, then answers normally — a runtime still starting.
  bool failNextRender = false;

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders.add(args['reason'] as String);
    if (failNextRender) {
      failNextRender = false;
      return null;
    }
    return {'kind': 'markdown', 'content': 'ok', if (declares.isNotEmpty) 'triggers': declares};
  }

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async => const {};
}

class _NullSource implements PanelExtensionSource {
  @override
  final runtimeGeneration = ValueNotifier(0);

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

  @override
  Future<void> forgetPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async {}
}
