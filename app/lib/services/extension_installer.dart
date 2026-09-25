// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where an extension install is while it is happening: which keys are in
// flight, and the footer progress item each one posts. The flow that asks
// (views/extension_install_flow.dart) drives it; the Extensions panel reads
// it to draw progress on the row being installed.
//
// A service rather than panel state because an install outlives the screen
// it was started from — Update all runs from the footer notice with no panel
// open, and a panel opened part way through has to show what is going on.

import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:halo_i18n/halo_i18n.dart';

import 'status_bar_service.dart';

class ExtensionInstaller extends ChangeNotifier {
  final StatusBarService statusBar;

  ExtensionInstaller({required this.statusBar});

  /// The footer item an install of [key] posts under, and the one its row in
  /// the Extensions panel mirrors.
  static String progressKey(String key) => 'extensions:install:$key';

  final _active = <String>{};

  /// Whether an install of [key] is under way — downloading, waiting for its
  /// turn, or being written. A second one for the same key is refused while
  /// this is true.
  bool isActive(String key) => _active.contains(key);

  /// The tail of the commit queue — see [commit].
  Future<void> _tail = Future.value();

  /// Runs [job] with [key] marked active. What it leaves in the footer is
  /// taken down on the way out unless it is a completion: a cancelled consent
  /// screen or a refused bundle must not leave a bar at 60% behind it.
  ///
  /// Re-entrant for the same key, so a flow that marks a catalog install
  /// active before its download can hand the same key to [commit] later.
  Future<T> run<T>(String key, Future<T> Function() job) async {
    final added = _active.add(key);
    if (added) notifyListeners();
    try {
      return await job();
    } finally {
      if (added) {
        _active.remove(key);
        final item = statusBar.itemForKey(progressKey(key));
        if (item != null && (item.progressValue ?? 0) < 1.0) statusBar.clear(progressKey(key));
        notifyListeners();
      }
    }
  }

  /// A download's share of the install, for [name]'s footer item.
  void downloading(String key, String name, double? fraction) =>
      statusBar.setProgress(key: progressKey(key), title: name, text: t.extensionsPanel.installDownloading, value: fraction?.clamp(0.0, 0.99));

  /// While the consent screen is up: the install is waiting on the operator,
  /// and a bar — even an indeterminate one — would say it is waiting on the
  /// app.
  void awaitingApproval(String key, String name) => statusBar.setMessage(key: progressKey(key), title: name, text: t.extensionsPanel.installAwaitingApproval);

  /// Takes [key]'s item down — ahead of a refusal dialog, which a bar still
  /// standing behind it would contradict.
  void clearProgress(String key) => statusBar.clear(progressKey(key));

  /// Writes an install through [install], one at a time.
  ///
  /// Serialized because each install restarts the extension runtime, and a
  /// second install written while the first one's restart is in flight is
  /// written into a store the new generation has already read. Downloads
  /// are not queued — only this step is.
  Future<void> commit(String key, String name, Future<void> Function() install) => run(key, () async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    try {
      statusBar.setProgress(key: progressKey(key), title: name, text: t.extensionsPanel.installWaiting);
      await previous;
      statusBar.setProgress(key: progressKey(key), title: name, text: t.extensionsPanel.installInstalling);
      await install();
      statusBar.setProgress(
        key: progressKey(key),
        title: name,
        text: t.extensionsPanel.installedMessage(name: name),
        value: 1.0,
      );
    } catch (_) {
      // Down before the caller's "did not finish" dialog opens over it.
      clearProgress(key);
      rethrow;
    } finally {
      done.complete();
    }
  });
}
