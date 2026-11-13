// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A restart replaces every hook in the runtime, and anything they had put in
// the footer outlives them: the new generation does not know the keys, so a
// progress bar the old one left behind has nobody to finish it. The operator
// reads a download that is still running — while nothing is running, and no
// socket is open.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show DraftSuggestionList, MdiIcons;
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/fyi_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [returning] is what the next generation loads — the fixture's whole
  /// variable, since it decides whether a notice has an owner to come back to.
  Future<(ExtensionServiceWithFakeHost, StatusBarService)> serviceWithStatusBar({List<String> returning = const ['ham2k-pota']}) async {
    SharedPreferences.setMockInitialValues(const {});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost()
      ..statusBar = statusBar
      ..debugLoadedExtensionKeys = {'ham2k-pota'}
      ..debugSetAvailableExtensions([for (final key in returning) ExtensionInfo(key: key, file: '$key.js', core: false, name: key)]);
    return (extensions, statusBar);
  }

  test('a queued backoff restart does not make a running generation unhealthy', () async {
    // `_start` installs the host and keeps going — the activation wait, the
    // account-flag refresh that reaches the keychain. A throw there queues a
    // backoff restart over a generation that is loaded and serving hooks,
    // and the upgrade reads this to decide whether what it installed is
    // running. Counting a queued restart as unhealthy makes one keychain
    // prompt revert a perfectly good upgrade.
    final (extensions, _) = await serviceWithStatusBar();

    await withErrorHooks(() async {
      extensions.debugScheduleRestart('start failed: keychain refused');
    });

    expect(extensions.runtimeIsHealthy, isTrue);
    // Cancels the timer the backoff armed, so nothing fires past the test.
    await extensions.restartRuntime();
  });

  test('a restart forgets the boot failure the last generation recorded', () async {
    // The name outliving its generation is how an innocent extension gets
    // refused for good: a crash later in the session also schedules a
    // restart, and the upgrade would read whatever name was lying around as
    // the bundle that just killed the runtime.
    final (extensions, _) = await serviceWithStatusBar();
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'ham2k-qrz', file: 'ham2k-qrz.js', source: ExtensionSource.installed, core: false, name: 'QRZ', version: '0.2.0'),
    ]);
    extensions.debugLastStartFailure = 'evaluating ham2k-qrz: TypeError';
    expect(extensions.lastStartFailureKey, 'ham2k-qrz');

    await extensions.restartRuntime();

    expect(extensions.lastStartFailureKey, isNull);
  });

  test('a teardown that throws is reported, and the restart still sweeps and completes', () async {
    // Thrown, it reaches whoever asked for the restart — an install that has
    // just written its bundle reads it as the install failing while the next
    // runtime loads that bundle. Skipped, the sweep leaves the dying
    // generation's progress bar with nobody to finish it.
    final (extensions, statusBar) = await serviceWithStatusBar();
    extensions.debugHost = FakeExtensionHost()..onDispose = () async => throw StateError('teardown failed');
    statusBar.setProgress(key: 'ham2k-pota:all-parks', text: 'Downloading parks');
    final backend = FakeErrorReportingBackend();

    await withErrorHooks(() => extensions.restartRuntime(), backend: backend);

    expect(statusBar.itemForKey('ham2k-pota:all-parks'), isNull);
    expect(backend.exceptions.map((e) => e.context), contains('extensions:dispose'));
  });

  // A bundle's sub-extensions post under their own keys (`ham2k-pota-all-parks`
  // from `ham2k-pota`), and a sweep by the bundle's key alone left theirs on
  // the line with nobody to take them down. The trap the other way is a
  // separately installed extension that merely shares the prefix: it is its
  // own bundle, and nothing of its may go with this one.
  test("a restart takes what a bundle's sub-extensions posted, and leaves a separate bundle named like one", () async {
    final (extensions, statusBar) = await serviceWithStatusBar(returning: const ['ham2k-pota', 'ham2k-pota-tools']);
    final fyi = FyiService();
    extensions.fyi = fyi;
    for (final ns in ['ham2k-pota-all-parks', 'ham2k-pota-tools']) {
      statusBar.setProgress(key: '$ns:sync', text: 'Syncing');
      fyi.post(FyiMessage(key: FyiService.extensionKey(ns, 'hint'), category: FyiCategory.info, icon: MdiIcons.information, text: 'Hint'));
      extensions.draftSuggestions.post(ns, 'op-1', const DraftSuggestionList(forCall: 'K1A', drafts: []));
    }

    await extensions.restartRuntime();

    expect(statusBar.itemForKey('ham2k-pota-all-parks:sync'), isNull);
    expect(fyi.messageFor(FyiService.extensionKey('ham2k-pota-all-parks', 'hint')), isNull);
    expect(extensions.draftSuggestions.offers('op-1', 'ham2k-pota-all-parks'), isFalse);

    expect(statusBar.itemForKey('ham2k-pota-tools:sync'), isNotNull, reason: 'its own bundle, not loaded in this generation');
    expect(fyi.messageFor(FyiService.extensionKey('ham2k-pota-tools', 'hint')), isNotNull);
    expect(extensions.draftSuggestions.offers('op-1', 'ham2k-pota-tools'), isTrue);
  });

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
    expect(statusBar.history.map((n) => n.key), contains('ham2k-pota:account'), reason: 'dismissed, not deleted — Recent Notices keeps it');
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
