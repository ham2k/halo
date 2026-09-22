// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Relaunches the desktop app so a downloaded Shorebird patch (docs/releases.md
// §4) takes effect — a patch only loads at process start, so an in-process hot
// restart won't pick it up. Only desktop is supported: iOS can't relaunch itself
// at all, and Android can only via a fragile intent, so on mobile the update
// notice is informational ("restart to apply") with no button.
//
// The quit half of that — [quitThroughFramework] — is shared: the Windows
// self-updater also has to put this process down, and for the same reason it
// must go through the framework rather than exit(0).

import 'dart:io';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;

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
          await Process.start('sh', ['-c', 'while kill -0 $me 2>/dev/null; do sleep 0.1; done; open -n "$app"'], mode: ProcessStartMode.detached);
        case TargetPlatform.linux:
          final exe = Platform.resolvedExecutable;
          await Process.start('sh', ['-c', 'while kill -0 $me 2>/dev/null; do sleep 0.1; done; exec "$exe"'], mode: ProcessStartMode.detached);
        case TargetPlatform.windows:
          final exe = Platform.resolvedExecutable;
          await Process.start('powershell', [
            '-NoProfile',
            '-Command',
            "while (Get-Process -Id $me -ErrorAction SilentlyContinue) "
                "{ Start-Sleep -Milliseconds 100 }; Start-Process '$exe'",
          ], mode: ProcessStartMode.detached);
        default:
          return;
      }
    } catch (e) {
      debugPrint('[restart] could not spawn the relauncher: $e');
      return;
    }
    await quitThroughFramework('restart');
  }
}

/// Quits this process through the framework, forcing the exit if the framework
/// will not do it — for a caller that has already committed to this app going
/// away.
///
/// Through the framework rather than exit(0): that path runs the app's exit
/// hook (main.dart's shutdownOnExit), which says goodbye to the radios and
/// CLOSES THE DATABASE. Killing the process with SQLite still open leaves the
/// closing to the VM's own teardown, where it aborts — a crash report from an
/// app that was quitting perfectly well — and drops whatever the write queue
/// still held, which no fixed delay here could do better than guess at.
///
/// Reaching the forced exit means the framework declined — an observer
/// cancelled, the embedder has no exit channel (the platform method returns
/// null, which reads as a cancel), or the call threw. Force it anyway: every
/// caller here has already set something in motion that a still-running app
/// would turn into a surprise (a relauncher polling for this pid, an installer
/// waiting on the files this process holds). The `finally` is what guarantees
/// that — a throwing platform channel would otherwise escape into an
/// `unawaited` caller and leave the app up.
///
/// Console-only, and deliberately: a forced exit means the hook never ran and
/// this process is going down with the database open after all, which is worth
/// seeing while developing and unactionable to an operator whose app is
/// already gone. [logTag] names the caller in that line.
Future<void> quitThroughFramework(String logTag) async {
  try {
    final response = await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
    // `exit` here does NOT mean the exit happened — the platform answered and
    // left this process running, which is indistinguishable from a refusal in
    // every way that matters to the line below. A `cancel` is the one that says
    // an observer (or an embedder with no exit channel, which reads the same)
    // turned it down, and only that one skipped the hook.
    debugPrint(
      response == AppExitResponse.cancel
          ? '[$logTag] the exit was refused; forcing it with the database still open'
          : '[$logTag] the exit did not terminate this process; forcing it',
    );
  } catch (e) {
    debugPrint('[$logTag] the framework could not be asked to exit ($e); forcing it');
  } finally {
    exit(0);
  }
}
