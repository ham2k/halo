// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Relaunches the desktop app so a downloaded Shorebird patch (docs/releases.md
// §4) takes effect — a patch only loads at process start, so an in-process hot
// restart won't pick it up. Only desktop is supported: iOS can't relaunch itself
// at all, and Android can only via a fragile intent, so on mobile the update
// notice is informational ("restart to apply") with no button.

import 'dart:io';

import 'package:flutter/foundation.dart';

class RestartService {
  const RestartService();

  /// True only where a full relaunch is possible: native desktop.
  bool get isSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  /// Quits this process and relaunches the app. We can't just spawn-and-exit:
  /// the app holds the SQLite/drift database, so a second instance starting
  /// before this one has released it would race for the lock. Instead we spawn a
  /// DETACHED helper that waits for THIS pid to exit and only then launches the
  /// app, then we exit — so the two never overlap. Best-effort: on any failure
  /// we just return and leave the app running (the patch still applies on the
  /// user's own next launch).
  Future<void> restart() async {
    if (!isSupported) return;
    final me = pid;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          // resolvedExecutable is <App>.app/Contents/MacOS/<bin>; the bundle is
          // three directories up. `open -n` forces a fresh instance.
          final app = File(Platform.resolvedExecutable).parent.parent.parent.path;
          await Process.start(
            'sh',
            ['-c', 'while kill -0 $me 2>/dev/null; do sleep 0.1; done; open -n "$app"'],
            mode: ProcessStartMode.detached,
          );
        case TargetPlatform.linux:
          final exe = Platform.resolvedExecutable;
          await Process.start(
            'sh',
            ['-c', 'while kill -0 $me 2>/dev/null; do sleep 0.1; done; exec "$exe"'],
            mode: ProcessStartMode.detached,
          );
        case TargetPlatform.windows:
          final exe = Platform.resolvedExecutable;
          await Process.start(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              "while (Get-Process -Id $me -ErrorAction SilentlyContinue) "
                  "{ Start-Sleep -Milliseconds 100 }; Start-Process '$exe'",
            ],
            mode: ProcessStartMode.detached,
          );
        default:
          return;
      }
    } catch (e) {
      debugPrint('[restart] could not spawn the relauncher: $e');
      return;
    }
    // Let pending DB writes flush, then exit so the waiting helper relaunches.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    exit(0);
  }
}
