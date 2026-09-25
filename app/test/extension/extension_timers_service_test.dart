// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What ExtensionService adds to extension timers, which themselves live in the
// runtime (packages/halo_extension_host/test/timers_test.dart): telling each
// runtime whether the app is in view, including one that boots while it is
// hidden, and saying so when an extension's timers are suspended. Through the
// real runtime, with a probe extension loaded the way the dev loop loads one.

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

const _probe = r'''
(function () {
var heard = []
__polo.defineExtension({
  key: 'dev-timers',
  name: 'Timers probe',
  version: '0.0.1',
  onHide: function () { heard.push('hide') },
  onShow: function () { heard.push('show') },
  onActivation: function (api) {
    api.registerHook('bench', { key: 'dev-timers', hook: {
      heard: async function () { return heard },
      spin: async function () {
        var chain = function () { api.timers.set(chain, 0, false, []) }
        api.timers.set(chain, 0, false, [])
      },
    }})
  },
})
})()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late HaLoHarness harness;
  late FakeErrorReportingBackend backend;

  setUp(() async {
    ErrorReportingService.resetForTesting();
    backend = FakeErrorReportingBackend();
    await ErrorReportingService.run(() {}, backend: backend);
    extensions = ExtensionService();
    harness = await makeHaLoServices(extensions: extensions);
  });

  tearDown(ErrorReportingService.resetForTesting);

  Future<void> loadProbe() => extensions.host!.reloadBundle(const ExtensionBundle(key: 'dev-timers', source: _probe));

  Future<List<Object?>> heard() async => (await extensions.host!.invokeHook('bench', key: 'dev-timers', method: 'heard')) as List<Object?>;

  test('a runtime that boots while the app is hidden is told so', () async {
    // The kernel starts out assuming the app is visible, and the change it
    // missed happened before it existed: only the push after boot tells it.
    extensions.setAppVisible(false);
    await extensions.start();
    await loadProbe();
    expect(await heard(), ['hide']);
  });

  test('an inactive app still counts as visible, as it does to the panes; hidden and paused do not', () async {
    await extensions.start();
    await loadProbe();
    extensions.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(await heard(), isEmpty, reason: 'a dialog over the window, or the app switcher opening, is not hiding the app');
    extensions.didChangeAppLifecycleState(AppLifecycleState.hidden);
    extensions.didChangeAppLifecycleState(AppLifecycleState.paused);
    extensions.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(await heard(), ['hide', 'show']);
  });

  Future<void> suspendProbe() async {
    await extensions.start();
    await loadProbe();
    await extensions.host!.invokeHook('bench', key: 'dev-timers', method: 'spin');
    final waited = Stopwatch()..start();
    while (!backend.exceptions.any((e) => e.error is ExtensionTimersSuspended)) {
      if (waited.elapsed > const Duration(seconds: 15)) fail('the suspension was never reported');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('a suspension is reported, and named in a notice in developer mode', () async {
    await harness.settings.setDeveloperMode(true);
    await suspendProbe();
    final reported = backend.exceptions.firstWhere((e) => e.error is ExtensionTimersSuspended).error as ExtensionTimersSuspended;
    expect((reported.extensionKey, reported.reason), ('dev-timers', 'budget'));
    expect(harness.services.statusBar.activeNotices.map((n) => n.key), contains('extension-timers:dev-timers'));
  });

  test('outside developer mode a suspension is still reported, but no notice interrupts the operator', () async {
    // The operator can do nothing about it; the report is what tells a
    // maintainer that an extension trips its budget in the field.
    await suspendProbe();
    expect(harness.services.statusBar.activeNotices.map((n) => n.key), isNot(contains('extension-timers:dev-timers')));
  });
}
