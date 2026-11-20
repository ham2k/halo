// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene event's answer may name a page for the browser (`openUrl`): the
// operator's click is what opens it. An address that is not http or https
// fails the answer, changing nothing, rather than reaching the platform,
// which would otherwise launch `javascript:` or `file:` from an extension's
// say-so; and a page nothing opens fails it too, where a click that did
// nothing would look taken. Only a click opens one: a drag still moving
// opening the browser would be a navigation nobody started. Driven through
// the REAL kernel, by a hand-written bundle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/shipped_extensions.dart';

/// Two buttons: one answering with a web page and a count of the clicks kept, one with a `file:` address
/// and a config of its own; and a slider answering a drag's every step with a page.
const opener = r'''
  globalThis.__halo.defineExtension({
    key: 'opener',
    name: 'opener',
    version: '0.0.1',
    onActivation(api) {
      api.registerHook('panel', {
        hook: {
          getPanels: async () => [{ key: 'p', title: 'Opener', config: ['clicks', 'taken'] }],
          render: async () => ({
            kind: 'scene',
            scene: {
              version: 1, width: 200, height: 40, values: { level: 0 },
              layers: [{ id: 'bg', x: 0, y: 0, width: 200, height: 20, svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 20"><rect width="200" height="20" fill="#000"/></svg>' }],
              controls: [
                { id: 'web', kind: 'button', label: 'Web', event: 'web', x: 0, y: 0, width: 100, height: 20 },
                { id: 'file', kind: 'button', label: 'File', event: 'file', x: 100, y: 0, width: 100, height: 20 },
                { id: 'level', kind: 'slider', label: 'Level', event: 'level', value: 'level', min: 0, max: 100, continuous: true, x: 0, y: 20, width: 200, height: 20 },
              ],
            },
          }),
          onEvent: async (args) => args.event.controlId === 'level'
            ? { values: {}, ...(args.event.phase === 'change' ? { openUrl: 'http://127.0.0.1:8833/drag' } : {}) }
            : args.event.action === 'web'
            ? { values: {}, config: { clicks: (args.config.clicks ?? 0) + 1 }, openUrl: 'http://127.0.0.1:8833/' }
            : { values: {}, config: { taken: true }, openUrl: 'file:///etc/passwd' },
        },
      });
    },
  });
''';

class _RecordingLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final launched = <String>[];

  /// Whether anything on the device opens a page: false for one with no browser.
  bool handles = true;

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return handles;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an event answer\'s openUrl opens the page; an address that is not a web page, or a page nothing opens, fails the answer', (tester) async {
    final launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    SharedPreferences.setMockInitialValues({});
    final extensions = (await tester.runAsync(() async {
      final service = ExtensionService()..settings = await SettingsService.load();
      prepareExtensionServiceForTest(service);
      await service.setDevBundles({
        'opener': (source: opener, info: ExtensionInfo(key: 'opener', file: 'opener.js', source: ExtensionSource.dev, core: true, name: 'opener')),
      });
      return service;
    }))!;
    final panels = PanelService(extensions);
    await tester.runAsync(panels.refreshExtensionPanels);
    final panel = panels.catalog.singleWhere((p) => p.panelKey == 'p');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            // Room for the pane's notice that an action failed.
            body: SizedBox(
              width: 200,
              height: 300,
              child: ExtensionPanel(panel: panel, panels: panels, renderContext: const PanelRenderContext()),
            ),
          ),
        ),
      ),
    );
    Future<void> bridgeUntil(bool Function() delivered) async {
      for (var i = 0; i < 500 && !delivered(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    await bridgeUntil(() => find.bySemanticsLabel('Web').evaluate().isNotEmpty);
    await tester.tap(find.bySemanticsLabel('Web'));
    await bridgeUntil(() => launcher.launched.isNotEmpty);
    expect(launcher.launched, ['http://127.0.0.1:8833/']);
    // The page opens before the answer's config is kept.
    Future<Object?> clicks() async => (await tester.runAsync(() => panels.configFor(panel)))?['clicks'];
    for (var i = 0; i < 100 && await clicks() != 1; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await clicks(), 1);

    await tester.tap(find.bySemanticsLabel('File'));
    await bridgeUntil(() => find.text('That panel action failed. Try again.').evaluate().isNotEmpty);
    expect(find.text('That panel action failed. Try again.'), findsOneWidget);
    expect(launcher.launched, ['http://127.0.0.1:8833/'], reason: 'a file: address never reaches the platform');
    expect((await tester.runAsync(() => panels.configFor(panel)))!['taken'], isNull, reason: 'the refused answer\'s config is not kept');

    // No browser to open it: the click says it failed rather than looking taken.
    launcher.handles = false;
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('That panel action failed. Try again.'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Web'));
    await bridgeUntil(() => find.text('That panel action failed. Try again.').evaluate().isNotEmpty);
    expect(launcher.launched, ['http://127.0.0.1:8833/', 'http://127.0.0.1:8833/']);
    expect(find.text('That panel action failed. Try again.'), findsOneWidget);
    // Kept with the page unopened, the config would say the click was taken.
    expect(await clicks(), 1, reason: 'the failed answer\'s config is not kept');

    // A drag's steps are no click: the answer that would open a page from one fails instead.
    launcher.handles = true;
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    final drag = await tester.startGesture(tester.getCenter(find.bySemanticsLabel('Level')) - const Offset(60, 0));
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    await drag.moveBy(const Offset(40, 0));
    await bridgeUntil(() => find.text('That panel action failed. Try again.').evaluate().isNotEmpty);
    await drag.up();
    // The release's commit, answered before the pane goes.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('That panel action failed. Try again.'), findsOneWidget);
    expect(launcher.launched, ['http://127.0.0.1:8833/', 'http://127.0.0.1:8833/'], reason: 'a drag opens no page');

    await tester.pumpWidget(const SizedBox());
    panels.dispose();
  });
}
