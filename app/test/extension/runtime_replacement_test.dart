// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Against the REAL runtime: a replacement disposes the host, which fails every
// call pending on it at once, and the next host is seconds of bundle loading
// away. A caller that lands in that gap reads it as a runtime that failed to
// start, and Settings tells the operator so on every extension update.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dyingProgress = 'probe-extension:download';

/// Notes, as each boot begins, whether the replacement has already swept the
/// old generation's status — the step that follows the old host's disposal.
class _BootWatchingExtensions extends ExtensionService {
  final sweptAtBoot = <bool>[];

  @override
  Future<List<ExtensionInfo>> loadAvailableExtensions({Map<String, dynamic>? index, bool force = false}) {
    if (index != null) sweptAtBoot.add(statusBar!.itemForKey(_dyingProgress) == null);
    return super.loadAvailableExtensions(index: index, force: force);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _BootWatchingExtensions extensions;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    extensions = _BootWatchingExtensions()
      ..settings = SettingsService(prefs)
      ..statusBar = StatusBarService(prefs);
    await extensions.start();
    expect(extensions.ready, isTrue, reason: 'extension runtime failed to boot');
  });

  tearDown(() => extensions.shutdownForExit());

  test('a settings query caught by a replacement is answered by the runtime that replaced it', () async {
    final expected = [for (final panel in await extensions.getSettingsPanels()) panel['panelKey']];
    expect(expected, isNotEmpty, reason: 'the built-in extensions contribute settings panels');
    final before = extensions.host;

    // Sent before the replacement takes the host down: the dispose fails it,
    // and the empty answer arrives while no runtime is up at all.
    final query = extensions.settledSettingsPanels();
    final replacement = extensions.restartRuntime();
    final panels = await query;
    await replacement;

    expect(extensions.host, isNot(same(before)));
    expect([for (final panel in panels) panel['panelKey']], expected);
  });

  test('a start during the old runtime\'s disposal waits for the replacement\'s own boot', () async {
    // A boot begun inside the dispose runs beside the dying runtime and ahead
    // of the sweep that clears the old generation's status after it.
    extensions.debugLoadedExtensionKeys = {'probe-extension'};
    extensions.statusBar!.setProgress(key: _dyingProgress, text: 'Downloading');
    extensions.sweptAtBoot.clear();

    final replacement = extensions.restartRuntime();
    while (extensions.host != null) {
      await Future<void>.delayed(Duration.zero);
    }
    final joined = extensions.start();
    await replacement;
    await joined;

    expect(extensions.sweptAtBoot, [true], reason: 'one boot, begun only once the old generation was cleared away');
    expect(extensions.ready, isTrue);
  });
}
