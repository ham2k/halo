// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';

import '../../tool/svg_scene_preview.dart';

Future<ExtensionHost> startHost() => ExtensionHost.start(
  kernelSource: File('assets/extensions/kernel.js').readAsStringSync(),
  extensions: [
    ExtensionBundle(
      key: 'k2hrc-svg-scenes',
      // A fixture, built beside the shipped bundles but outside the app's
      // assets (extensions/build-config.mjs `fixturesDir`).
      source: File('../extensions/build/fixtures/k2hrc-svg-scenes.js').readAsStringSync(),
    ),
  ],
  onHostCall: (method, args) async => method == 'getSettings' ? {'appName': 'Test'} : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real sample bundle discovers, renders, and handles events through the production service', () async {
    final host = await startHost();
    addTearDown(host.dispose);
    final service = PrototypeExtensionService(host);
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    expect(panels.catalog.length, 2);
    final radio = panels['ext:k2hrc-svg-scenes:radio#1']!;
    final other = panels['ext:k2hrc-svg-scenes:radio#2']!;
    final weather = panels['ext:k2hrc-svg-scenes:weather#1']!;
    const args = <String, dynamic>{
      'operation': <String, dynamic>{},
      'config': <String, dynamic>{},
      'qsoCount': 0,
      'reason': 'test',
    };
    final content = PanelContent.fromJson(await panels.render(radio, args))!;
    expect(content.kind, 'svgScene');
    expect(content.scene!.values['reported'], 14074);
    expect(content.scene!.controls.map((c) => c.kind), containsAll(['button', 'slider', 'knob']));
    final patch = await panels.event(radio, {
      ...args,
      'event': {'controlId': 'tune', 'action': 'tune', 'phase': 'commit', 'sequence': 1, 'value': 14200},
    });
    expect((patch!['values'] as Map)['requested'], 14200);
    expect((patch['values'] as Map)['reported'], 14074);
    expect(PanelContent.fromJson(await panels.render(other, args))!.scene!.values['requested'], 14074);
    final chart = PanelContent.fromJson(await panels.render(weather, args))!;
    expect(chart.scene!.controls.single.event, isNull);
    expect(chart.scene!.layers.any((l) => l.text?['samples'] != null), isTrue);
    expect(service.events, 1);
  });
  testWidgets('a gesture reaches the real extension and updates the rendered panel', (tester) async {
    final host = (await tester.runAsync(startHost))!;
    final service = PrototypeExtensionService(host);
    final panels = PanelService(service);
    await tester.runAsync(panels.refreshExtensionPanels);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ExtensionPanel(
              panel: panels['ext:k2hrc-svg-scenes:radio#1']!,
              panels: panels,
              renderContext: const PanelRenderContext(),
            ),
          ),
        ),
      ),
    );
    Future<void> bridgeSettles() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump();
    }

    await bridgeSettles();
    expect(find.text('14074.0 kHz'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Simulate external tuning'));
    await bridgeSettles();
    expect(service.events, 1);
    expect(find.text('14079.0 kHz'), findsOneWidget);
    // Remove the widget before stopping the runtime: no timer may invoke it later.
    await tester.pumpWidget(const SizedBox());
    panels.dispose();
    await tester.runAsync(host.dispose);
  });
}
