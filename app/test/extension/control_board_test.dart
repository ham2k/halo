// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Control Board panel through the real runtime: a board's YAML, compiled
// by the extension, must be a scene the app accepts whole, and a press must
// reach the radio as a host call. The compiler and the app's scene parser are
// written apart; this is where they meet.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';

const _board = '''
ham2k-board: 1
name: Station
sources:
  rig: { radio: null }
  rot: { rotator: rot-1 }
  ant: { antennaSwitch: sw-1 }
vars:
  drive: 40
  details: false
items:
  - { type: label, text: "{{ op.station }}", style: title, span: [4, 1] }
  - { type: needle, value: rig.signalDbm, min: -130, max: -10, label: S, hold: 800 }
  - { type: ledBar, value: rig.powerOut, max: 100, hold: 1000, zones: [[80, error]] }
  - { type: bar, value: var.drive, adjustable: true, label: Drive }
  - { type: frequency, value: rig.frequencyHz }
  - { type: readout, value: rig.swr, decimals: 1, label: SWR }
  - { type: segmented, value: rig.mode, options: [{ value: CW }, { value: USB }], onSelect: { setRadio: { mode: \$value } } }
  - { type: toggle, var: details, label: Details }
  - { type: toggle, on: { value: rig.tuner, is: inline }, label: ATU, onPress: { setRadio: { tunerInline: true } } }
  - { type: knob, var: drive }
  - { type: slider, var: drive, onChange: { setVar: { name: drive, value: \$value } } }
  - { type: button, label: Tune, onPress: { setRadio: { startTune: true } }, active: { value: rig.transmitting, is: 1 } }
  - { type: menuButton, label: Band, items: [{ label: 20m, onSelect: { setRadio: { frequencyHz: 14074000 } } }] }
  - type: group
    title: Rotator
    background: surfaceContainer
    columns: 6
    items:
      - { type: readout, value: rot.azimuth, suffix: "°", label: Heading }
      - { type: button, label: North, onPress: { turnRotator: { source: rot, azimuth: 0 } } }
      - { type: readout, value: ant.1.antennaName, label: Antenna, span: [2, 1] }
''';

/// The production service over a host started here, the pane's settings holding [config].
class _Service extends ExtensionService {
  _Service(this.runtime, this.config);
  final ExtensionHost runtime;
  final Map<String, dynamic> config;

  @override
  ExtensionHost get host => runtime;

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async => config;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({ExtensionHost host, List<(String, Map<dynamic, dynamic>)> calls})> start({bool refuse = false}) async {
    final calls = <(String, Map<dynamic, dynamic>)>[];
    final host = await ExtensionHost.start(
      kernelSource: File('assets/extensions/kernel.js').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'control-board', source: File('assets/extensions/control-board.js').readAsStringSync())],
      onHostCall: (method, args) async {
        calls.add((method, args));
        return switch (method) {
          'readRadio' => {'id': 'rig-now'},
          'setRadio' || 'setRotator' => refuse ? {'accepted': false, 'reason': 'unsupported'} : {'accepted': true},
          'getSettings' => {'appName': 'Test'},
          _ => null,
        };
      },
    );
    addTearDown(host.dispose);
    return (host: host, calls: calls);
  }

  const args = <String, dynamic>{
    'operation': {'stationCall': 'N0DEV'},
    'qsoCount': 0,
    'reason': 'test',
    'instanceId': 'board#1',
  };

  test('a board with every widget compiles to a scene the app accepts whole', () async {
    final (:host, calls: _) = await start();
    final service = _Service(host, {'board': _board});
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    final board = panels['ext:control-board:board#1']!;
    final rendered = await panels.render(board, {...args, 'config': await panels.configFor(board)});
    final content = PanelContent.fromJson(rendered)!;
    expect(content.kind, 'scene', reason: '${rendered?['content']}');
    final scene = content.scene!;
    expect(scene.sources.keys, containsAll(['rig', 'rot', 'ant']));
    expect(scene.cells, hasLength(16));
    expect(scene.sourceValues, containsAll(['rig.signalDbm', 'rig.powerOut', 'rot.azimuth']));
    expect(scene.sourceStrings, containsAll(['rig.mode', 'rig.tuner', 'ant.1.antennaName']));
    expect(rendered?['title'], 'Station');
    expect(scene.layers.any((l) => l.text?['literal'] == 'N0DEV'), isTrue, reason: 'the label rendered its Liquid');
  });

  test("a board's YAML that cannot be drawn says why in the pane, not as a blank one", () async {
    final (:host, calls: _) = await start();
    final service = _Service(host, {'board': 'items:\n  - { type: gauge }'});
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    final board = panels['ext:control-board:board#1']!;
    final content = PanelContent.fromJson(await panels.render(board, {...args, 'config': await panels.configFor(board)}))!;
    expect(content.kind, 'markdown');
    expect(content.content, contains('unknown type `gauge`'));
  });

  test("a pick reaches the logging radio, by the id it reads now; a var's toggle answers with the var", () async {
    final (:host, :calls) = await start();
    final service = _Service(host, {'board': _board});
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    final board = panels['ext:control-board:board#1']!;
    final config = await panels.configFor(board);
    // Each control's event as the board drew it: it carries the board's stamp, as the app sends it.
    final scene = PanelContent.fromJson(await panels.render(board, {...args, 'config': config}))!.scene!;
    String sent(String control) => scene.controlsById[control]!.event!;
    await panels.event(board, {
      ...args,
      'config': config,
      'event': {'controlId': 'w6-opt1', 'action': sent('w6-opt1'), 'phase': 'activate', 'sequence': 1},
    });
    final set = calls.where((c) => c.$1 == 'setRadio').single.$2;
    expect(set['mode'], 'USB');
    expect(set['id'], 'rig-now');
    final patch = await panels.event(board, {
      ...args,
      'config': config,
      'event': {'controlId': 'w7-press', 'action': sent('w7-press'), 'phase': 'activate', 'sequence': 2},
    });
    expect(patch!['values'], {'var.details': 1}, reason: 'only the var it changed: the others may be held by a knob');
  });

  test("a refused action is the operator's to read: a status notice, and the control put back", () async {
    final (:host, :calls) = await start(refuse: true);
    final service = _Service(host, {'board': _board});
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    final board = panels['ext:control-board:board#1']!;
    final config = await panels.configFor(board);
    final scene = PanelContent.fromJson(await panels.render(board, {...args, 'config': config}))!.scene!;
    final patch = await panels.event(board, {
      ...args,
      'config': config,
      'event': {'controlId': 'w6-opt1', 'action': scene.controlsById['w6-opt1']!.event, 'phase': 'activate', 'sequence': 1},
    });
    expect(patch, isNotNull, reason: 'answered, not failed: a refusal is no error to report');
    final said = calls.where((c) => c.$1 == 'showMessage').single.$2;
    expect(said['presentation'], 'status');
    expect(said['text'], 'The radio did not take it: unsupported');
  });
}
