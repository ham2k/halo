// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A panel's `radio` trigger: a render when the dial moves, so a panel that
// lays itself out around the frequency — a band map — need not tick once a
// second to notice. It must answer to the dial only: the radio's source fires
// at meter rate, and a render per S-meter flicker would hold the bridge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  PanelDefinition panel(List<String> triggers) =>
      PanelDefinition(id: 'ext:map:band', title: 'Band Map', source: PanelSource.extension, hookKey: 'map', panelKey: 'band', triggers: triggers);

  Widget harness(_Panels panels, PanelDefinition definition, _Radio? radio, {bool visible = true}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: DockPaneVisibility(
          visible: visible,
          child: ExtensionPanel(
            panel: definition,
            panels: panels,
            spectrum: radio,
            renderContext: PanelRenderContext(
              operation: Operation(uuid: 'op-1', data: const {}),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a dial move renders a `radio` panel, and a meter reading does not', (tester) async {
    final radio = _Radio(), panels = _Panels();
    addTearDown(radio.dispose);
    await tester.pumpWidget(harness(panels, panel(['radio']), radio));
    await settle(tester);
    expect(panels.renders, ['initial']);

    radio.meter();
    await settle(tester);
    expect(panels.renders, ['initial'], reason: 'the meters moved, the dial did not');

    radio.tune(7030000);
    await settle(tester);
    expect(panels.renders, ['initial', 'radio']);
  });

  testWidgets('a panel that did not ask is never rendered for it', (tester) async {
    final radio = _Radio(), panels = _Panels();
    addTearDown(radio.dispose);
    await tester.pumpWidget(harness(panels, panel(['spots']), radio));
    await settle(tester);
    radio.tune(7030000);
    await settle(tester);
    expect(panels.renders, ['initial']);
  });

  testWidgets('asking without leave to read the radio says so, rather than never firing in silence', (tester) async {
    // The dock hands no source to a panel without requiresRadioRead; a trigger that cannot fire
    // must be told apart from a panel that meant to render once.
    final said = <String>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => said.add(message ?? '');
    try {
      await tester.pumpWidget(harness(_Panels(), panel(['radio']), null));
      await settle(tester);
    } finally {
      debugPrint = print;
    }
    expect(said.where((line) => line.contains('requiresRadioRead')), hasLength(1));
  });

  testWidgets('an update that adds `radio` to the same panel is followed without remounting it', (tester) async {
    // An extension update replaces the definition under the same id and keeps the pane mounted:
    // watching only what the first definition declared, the updated panel never hears the dial.
    final radio = _Radio(), panels = _Panels();
    addTearDown(radio.dispose);
    await tester.pumpWidget(harness(panels, panel(['spots']), radio));
    await settle(tester);
    await tester.pumpWidget(harness(panels, panel(['spots', 'radio']), radio));
    await settle(tester);
    radio.tune(7030000);
    await settle(tester);
    expect(panels.renders, ['initial', 'radio']);
  });

  testWidgets('a `radio` trigger declared by a render is followed from then on', (tester) async {
    // A render may declare it for its own placement (`triggers`), and without re-subscribing on that
    // declaration the pane would never hear the dial.
    final radio = _Radio(), panels = _Panels(declares: ['radio']);
    addTearDown(radio.dispose);
    await tester.pumpWidget(harness(panels, panel(const []), radio));
    await settle(tester);
    radio.tune(7030000);
    await settle(tester);
    expect(panels.renders, ['initial', 'radio']);
  });

  testWidgets('a dial move behind a tab is remembered, and rendered once on coming back', (tester) async {
    final radio = _Radio(), panels = _Panels();
    addTearDown(radio.dispose);
    await tester.pumpWidget(harness(panels, panel(['radio']), radio));
    await settle(tester);
    await tester.pumpWidget(harness(panels, panel(['radio']), radio, visible: false));
    radio.tune(7030000);
    radio.tune(7031000);
    await settle(tester);
    expect(panels.renders, ['initial']);

    await tester.pumpWidget(harness(panels, panel(['radio']), radio));
    await settle(tester);
    expect(panels.renders, ['initial', 'visible']);
  });
}

class _Radio extends ChangeNotifier implements SceneSpectrumSource {
  int _hz = 14074000;
  double _dbm = -70;

  void tune(int hz) {
    _hz = hz;
    notifyListeners();
  }

  void meter() {
    _dbm += 3;
    notifyListeners();
  }

  @override
  List<Object?> dialState() => ['radio-1', _hz, 'USB'];
  @override
  Map<String, num> readings(String uuid) => {'frequencyHz': _hz, 'signalDbm': _dbm};
  @override
  Map<String, String> readingStrings(String uuid) => const {'mode': 'USB'};
  @override
  Listenable get readingChanges => this;
  @override
  String? resolve(String? radio) => radio ?? 'radio-1';
  @override
  bool recenter(String uuid, int centerHz) => false;
  @override
  void showWidth(String uuid, Object owner, int? widthHz) {}
  @override
  Stream<SpectrumFrame> frames(String uuid) => const Stream.empty();
  @override
  String? problem(String uuid) => null;
  @override
  double? vfoHz(String uuid) => _hz.toDouble();
  @override
  Listenable get changes => this;
  @override
  String get noRadio => 'no radio';
  @override
  String get waiting => 'waiting';
}

class _Panels extends PanelService {
  _Panels({this.declares = const []}) : super(_NullSource());

  final List<String> declares;
  final renders = <String>[];

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders.add(args['reason'] as String);
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
  Future<Map<String, dynamic>?> renderPanel({required String hookKey, required String panelKey, required Map<String, dynamic> args}) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async => const {};

  @override
  Future<void> forgetPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {}
}
