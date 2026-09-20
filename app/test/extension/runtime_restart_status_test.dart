// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A restart replaces every hook in the runtime, and anything they had put in
// the footer outlives them: the new generation does not know the keys, so a
// progress bar the old one left behind has nobody to finish it. The operator
// reads a download that is still running — while nothing is running, and no
// socket is open.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_info.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [returning] is what the next generation loads — the fixture's whole
  /// variable, since it decides whether a notice has an owner to come back to.
  Future<(ExtensionServiceWithFakeHost, StatusBarService)> serviceWithStatusBar({
    List<String> returning = const ['ham2k-pota'],
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost()
      ..statusBar = statusBar
      ..debugLoadedExtensionKeys = {'ham2k-pota'}
      ..debugSetAvailableExtensions([
        for (final key in returning) ExtensionInfo(key: key, file: '$key.js', core: false, name: key),
      ]);
    return (extensions, statusBar);
  }

  test('a restart takes the old generation\'s progress bar with it', () async {
    final (extensions, statusBar) = await serviceWithStatusBar();
    statusBar.setProgress(key: 'ham2k-pota:all-parks', text: 'Downloading parks');

    await extensions.restartRuntime();

    expect(statusBar.itemForKey('ham2k-pota:all-parks'), isNull);
  });

  test('but leaves a loaded extension\'s notice on screen', () async {
    // Most restarts here are one extension toggled in the panel, and every
    // other extension comes back loaded. An "account expired — reconnect"
    // card is the operator's to answer; nothing re-posts it, so dismissing it
    // as a side effect of an unrelated toggle loses it into history unread.
    final (extensions, statusBar) = await serviceWithStatusBar();
    statusBar.showNotice(key: 'ham2k-pota:account', text: 'Reconnect your account');

    await extensions.restartRuntime();

    expect(statusBar.activeNotices.map((n) => n.key), contains('ham2k-pota:account'));
  });

  test('but a key that is not coming back loses its notice, the way an uninstall does', () async {
    // Disabled, or renamed by the catalog upgrade — `wca` becomes
    // `ham2k-wca`, a different namespace. Nothing will ever post to the old
    // one again, so its "reconnect your account" card would sit there live
    // and unanswerable, opening an account dialog for an extension that is
    // no longer loaded.
    final (extensions, statusBar) = await serviceWithStatusBar(returning: const []);
    statusBar.showNotice(key: 'ham2k-pota:account', text: 'Reconnect your account');

    await extensions.restartRuntime();

    expect(statusBar.activeNotices, isEmpty);
    expect(statusBar.history.map((n) => n.key), contains('ham2k-pota:account'),
        reason: 'dismissed, not deleted — Recent Notices keeps it');
  });

  test('and leaves the app\'s own footer items alone', () async {
    // The namespaces are not the extensions' alone — `adifImport:status` and
    // `operation:…` live in the same map, and an import running through a
    // restart is not the restart's to cancel.
    final (extensions, statusBar) = await serviceWithStatusBar();
    statusBar.setProgress(key: 'adifImport:status', text: 'Importing');

    await extensions.restartRuntime();

    expect(statusBar.itemForKey('adifImport:status'), isNotNull);
  });
}
