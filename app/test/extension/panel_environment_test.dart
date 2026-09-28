// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/panel_environment.dart';
import '../support/fake_panel_extensions.dart';

class Source extends FakePanelExtensions {
  Source({this.scene = true});

  /// What the panel answers with: a scene, or markdown.
  final bool scene;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>?> renderPanel({required String hookKey, required String panelKey, required Map<String, dynamic> args}) async {
    calls.add(args);
    if (!scene) {
      return {
        'kind': 'markdown',
        'content': 'ok',
        'triggers': ['spots'],
      };
    }
    return {
      'kind': 'scene',
      'scene': {
        'version': 1,
        'width': 400,
        'height': 200,
        'values': <String, dynamic>{},
        'layers': [
          {
            'id': 'label',
            'x': 0,
            'y': 0,
            'width': 200,
            'height': 50,
            'text': {'literal': 'ok'},
          },
        ],
      },
    };
  }
}

const _panel = PanelDefinition(id: 'ext:test:scene', title: 'Scene', source: PanelSource.extension, hookKey: 'test', panelKey: 'scene');

Future<void> _show(WidgetTester tester, PanelService service, {double width = 400, int spotsRevision = 0}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 300,
              child: DockPaneVisibility(
                visible: true,
                child: ExtensionPanel(
                  panel: _panel,
                  panels: service,
                  renderContext: PanelRenderContext(spotsRevision: spotsRevision),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('resolved environment reaches the first render and changes respect visibility and budget', (tester) async {
    final source = Source();
    // Use one service/runtime for every rebuild, just like a dock placement.
    final service = PanelService(source);
    addTearDown(service.dispose);
    Future<void> show({Brightness brightness = Brightness.light, double width = 400, bool visible = true, double scale = 1, bool reduced = false}) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(brightness: brightness, fontFamily: 'Roboto'),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: 300,
                    child: DockPaneVisibility(
                      visible: visible,
                      child: ExtensionPanel(panel: _panel, panels: service, renderContext: const PanelRenderContext()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await show();
    expect(source.calls, hasLength(1));
    final first = source.calls.single['environment'] as Map;
    expect(first['width'], 400);
    expect(first['brightness'], 'light');
    expect(first['typography']['body']['fontFamily'], 'Roboto');
    expect(source.calls.single['clock']['realNowMillis'], isA<int>());
    await show(brightness: Brightness.dark, width: 450, scale: 2, reduced: true);
    await show(brightness: Brightness.dark, width: 460, scale: 2, reduced: true);
    expect(source.calls, hasLength(1), reason: 'resize bursts must not bypass the throttle');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(source.calls, hasLength(2));
    final latest = source.calls.last['environment'] as Map;
    expect(latest['width'], 460);
    expect(latest['brightness'], 'dark');
    expect(latest['colors']['surface'], isNot(first['colors']['surface']));
    expect(latest['reducedMotion'], true);
    expect(latest['typography']['body']['scaledFontSize'], latest['typography']['body']['fontSize'] * 2);
    await show(visible: false);
    await tester.pump(const Duration(seconds: 2));
    expect(source.calls, hasLength(2));
    await show();
    await tester.pump(const Duration(seconds: 2));
    expect(source.calls, hasLength(3));
    expect(source.calls.last['environment']['brightness'], 'light');
  });

  // Markdown and HTML are themed and laid out by the host. Re-rendering them
  // on a resize is a bridge call per pane per throttle window of a splitter
  // drag — and a web view reload for HTML — for an answer that cannot differ.
  testWidgets('a resize does not re-render a panel that is not a scene, and its next render sees the new size', (tester) async {
    final source = Source(scene: false);
    final service = PanelService(source);
    addTearDown(service.dispose);
    await _show(tester, service);
    expect(source.calls, hasLength(1));
    await _show(tester, service, width: 460);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(source.calls, hasLength(1));
    await _show(tester, service, width: 460, spotsRevision: 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(source.calls, hasLength(2));
    expect(source.calls.last['environment']['width'], 460);
  });

  // The environment reads MediaQuery by aspect. Depending on the whole query
  // rebuilds every mounted panel on each frame of a keyboard inset animation.
  testWidgets('a keyboard inset change does not rebuild what reads the environment', (tester) async {
    var builds = 0;
    // One instance across both pumps, so only an inherited dependency can
    // rebuild it.
    final probe = Builder(
      builder: (context) {
        builds++;
        panelEnvironment(context, const Size(400, 300));
        return const SizedBox();
      },
    );
    Future<void> show(double inset) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            viewInsets: EdgeInsets.only(bottom: inset),
          ),
          child: probe,
        ),
      ),
    );

    await show(0);
    expect(builds, 1);
    await show(300);
    expect(builds, 1);
  });
}
