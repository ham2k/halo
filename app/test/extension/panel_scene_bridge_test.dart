// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';

/// The production service over a host started here, counting the events that
/// cross the bridge — the point of these tests is that a gesture really does.
class _SampleExtensionService extends ExtensionService {
  final ExtensionHost sampleHost;
  int events = 0;
  _SampleExtensionService(this.sampleHost);
  @override
  ExtensionHost get host => sampleHost;
  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async => {};

  @override
  Future<Map<String, dynamic>?> panelEvent({required String hookKey, required String panelKey, required Map<String, dynamic> args}) {
    events++;
    return super.panelEvent(hookKey: hookKey, panelKey: panelKey, args: args);
  }
}

Future<ExtensionHost> startHost() => ExtensionHost.start(
  kernelSource: File('assets/extensions/kernel.js').readAsStringSync(),
  extensions: [
    ExtensionBundle(
      key: 'k2hrc-panel-scenes',
      // A fixture, built beside the shipped bundles but outside the app's
      // assets (extensions/build-config.mjs `fixturesDir`).
      source: File('../extensions/build/fixtures/k2hrc-panel-scenes.js').readAsStringSync(),
    ),
  ],
  onHostCall: (method, args) async => method == 'getSettings' ? {'appName': 'Test'} : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real sample bundle discovers, renders, and handles events through the production service', () async {
    final host = await startHost();
    addTearDown(host.dispose);
    final service = _SampleExtensionService(host);
    final panels = PanelService(service);
    addTearDown(panels.dispose);
    await panels.refreshExtensionPanels();
    expect(panels.catalog.length, 3);
    final radio = panels['ext:k2hrc-panel-scenes:radio#1']!;
    final other = panels['ext:k2hrc-panel-scenes:radio#2']!;
    final weather = panels['ext:k2hrc-panel-scenes:weather#1']!;
    const args = <String, dynamic>{'operation': <String, dynamic>{}, 'config': <String, dynamic>{}, 'qsoCount': 0, 'reason': 'test'};
    final content = PanelContent.fromJson(await panels.render(radio, args))!;
    expect(content.kind, 'scene');
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
    final service = _SampleExtensionService(host);
    final panels = PanelService(service);
    await tester.runAsync(panels.refreshExtensionPanels);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ExtensionPanel(panel: panels['ext:k2hrc-panel-scenes:radio#1']!, panels: panels, renderContext: const PanelRenderContext()),
          ),
        ),
      ),
    );
    // The bridge crosses into the runtime and back on real I/O, so it is
    // polled for what it should deliver rather than given a fixed time.
    Future<void> bridgeUntil(bool Function() delivered) async {
      for (var i = 0; i < 500 && !delivered(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
        await tester.pump();
      }
    }

    await bridgeUntil(() => find.text('14074.0 kHz').evaluate().isNotEmpty);
    expect(find.text('14074.0 kHz'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Simulate external tuning'));
    await bridgeUntil(() => find.text('14079.0 kHz').evaluate().isNotEmpty);
    expect(service.events, 1);
    expect(find.text('14079.0 kHz'), findsOneWidget);
    // Remove the widget before stopping the runtime: no timer may invoke it later.
    await tester.pumpWidget(const SizedBox());
    panels.dispose();
    await tester.runAsync(host.dispose);
  });

  // The whole string path: the field's `text` crosses the bridge, the
  // extension keeps it, and the `strings` patch and the re-render both come
  // back through ExtensionPanel. A patch parsed as values alone would drop
  // the status line; an event carrying `value` would never deliver the call.
  testWidgets('a native text field and button reach the real extension, and its strings come back', (tester) async {
    final host = (await tester.runAsync(startHost))!;
    final service = _SampleExtensionService(host);
    final panels = PanelService(service);
    await tester.runAsync(panels.refreshExtensionPanels);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 400,
              child: ExtensionPanel(panel: panels['ext:k2hrc-panel-scenes:controls#1']!, panels: panels, renderContext: const PanelRenderContext()),
            ),
          ),
        ),
      ),
    );
    // The bridge crosses into the runtime and back on real I/O, so it is
    // polled for what it should deliver rather than given a fixed time.
    Future<void> bridgeUntil(bool Function() delivered) async {
      for (var i = 0; i < 500 && !delivered(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
        await tester.pump();
      }
    }

    await bridgeUntil(() => find.text('Nothing spotted yet').evaluate().isNotEmpty);
    expect(find.text('Nothing spotted yet'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Callsign'), 'k2hrc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await bridgeUntil(() => service.events == 1);
    await tester.tap(find.text('Spot'));
    await bridgeUntil(() => find.text('Spotted K2HRC on 20m CW, 100 W').evaluate().isNotEmpty);
    expect(service.events, 2);
    expect(find.text('Spotted K2HRC on 20m CW, 100 W'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Callsign')).controller!.text,
      'K2HRC',
      reason: "the extension's normalized callsign replaced the typing",
    );
    await tester.pumpWidget(const SizedBox());
    panels.dispose();
    await tester.runAsync(host.dispose);
  });
}
