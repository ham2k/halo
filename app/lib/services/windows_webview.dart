// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one WebView2 environment every `InAppWebView` on Windows is built
// from, and the answer to "can this machine show a webview at all".
//
// Left to itself, `flutter_inappwebview_windows` creates its environment
// with a null user data folder, which WebView2 resolves to
// `{Executable}.WebView2` NEXT TO THE EXE — and creation fails outright when
// the process cannot create a directory there (an install under Program
// Files, a read-only or network location, a OneDrive-synced folder,
// Controlled Folder Access). The plugin gives Dart no way to recover: it
// calls `initialize()` fire-and-forget from `initState`, so the
// PlatformException escapes to the zone as a fatal report and the view stays
// blank for the rest of the session. So we make the environment ourselves,
// pointed at the app's own writable directory, and hand it to every
// `InAppWebView`.
//
// ONE environment for the whole app, not one per view: WebView2 shares a
// browser process between webviews, and creating a second environment whose
// options don't match the running one fails with ERROR_INVALID_STATE.
//
// Callers must ask [isAvailable] before building an `InAppWebView`, and have
// something to show when it says no — the Map tab falls back to its OSM
// backend, the account login says it cannot sign in here. Resolving it is
// not free: unlike the runtime-version query it replaces, it spawns the
// browser process, so expect the first answer to take a noticeable moment.

import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import 'app_storage.dart';
import 'error_reporting_service.dart';

/// Subdirectory of the app's data directory holding WebView2's user data —
/// caches, cookies and the profile the runtime insists on writing somewhere.
const kWebView2DataDirName = 'WebView2';

/// Windows cannot give this app a webview. [cause] is the platform's account
/// of why: a PlatformException carrying the HRESULT, a FileSystemException
/// from the user data folder, or the TimeoutException standing in for a
/// browser process that never came up.
///
/// The wrapper exists so ErrorPolicy can classify exactly this failure and
/// nothing else — a bare PlatformException reaching the policy from anywhere
/// else in the app has no webview to blame.
@immutable
class WindowsWebViewUnavailable implements Exception {
  final Object cause;

  const WindowsWebViewUnavailable(this.cause);

  @override
  String toString() => 'WindowsWebViewUnavailable: $cause';
}

class WindowsWebView {
  WindowsWebView._();

  /// The environment to pass to every `InAppWebView`. Null off Windows,
  /// where the platform's own webview needs none, and null on a Windows
  /// machine where creating it failed. Only meaningful once [isAvailable]
  /// has completed.
  static WebViewEnvironment? get environment => _environment;
  static WebViewEnvironment? _environment;

  /// Resolved availability, once [isAvailable] has completed — lets a widget
  /// answer synchronously on later builds instead of flashing its fallback
  /// every time it mounts.
  static bool? get resolved => _resolved;
  static bool? _resolved;

  static Future<bool>? _pending;

  /// Whether an `InAppWebView` can be created here, resolved once and
  /// remembered. Always true off Windows.
  static Future<bool> isAvailable() => _pending ??= _resolve();

  /// How long the browser process gets to come up before we give up on it.
  /// Without a deadline a WebView2 stuck mid-repair, or a Controlled Folder
  /// Access prompt sitting behind the app window, leaves [_pending] holding a
  /// future that never settles — and every later caller awaiting the same
  /// dead future, with nothing logged and nothing shown. Generous, because a
  /// cold spawn on a slow disk is genuinely slow and a false negative here
  /// costs the operator their map.
  static const _deadline = Duration(seconds: 30);

  static Future<bool> _resolve() async {
    final create = debugCreateEnvironment;
    if (create == null && (kIsWeb || !Platform.isWindows)) return _resolved = true;
    try {
      _environment = await (create ?? _createEnvironment)().timeout(_deadline);
      return _resolved = true;
    } catch (e, st) {
      // Wrapped, because the wrapper is what ErrorPolicy's rule matches on:
      // the disposition for this failure is decided there, once, not asserted
      // here (see docs/design/error-reporting.md). The cause travels with it,
      // carrying the HRESULT that is the only thing saying WHY a given
      // machine cannot run a webview.
      ErrorReportingService.report(WindowsWebViewUnavailable(e), st, context: 'windows-webview:create');
      return _resolved = false;
    }
  }

  /// `additionalBrowserArguments` disables WebView2's Chromium compositor:
  /// several Windows-only native crashes bottom out in DirectManipulation and
  /// D3D compositor frames (`mtx_do_lock`, `CContext::EmptyOutAllDDIBindPoints`),
  /// which is that layer. Rasterization and video decode stay on the GPU —
  /// this is milder than `--disable-gpu`'s full software-rendering fallback.
  ///
  /// Extracted so a test can assert the argument is actually there — this
  /// path IS the mitigation, so a silent regression (a mistyped or dropped
  /// flag) brings the crash straight back with the suite still green.
  @visibleForTesting
  static WebViewEnvironmentSettings debugEnvironmentSettings(String userDataFolder) => WebViewEnvironmentSettings(
        userDataFolder: userDataFolder,
        additionalBrowserArguments: '--disable-gpu-compositing',
      );

  static Future<WebViewEnvironment> _createEnvironment() async {
    final folder = await Directory(await userDataFolderPath()).create(recursive: true);
    return WebViewEnvironment.create(settings: debugEnvironmentSettings(folder.path));
  }

  /// `%LOCALAPPDATA%\<edition>\WebView2`, read from [environment] (the real
  /// process environment by default) rather than taken from
  /// [appDataDirectory]: that one falls back to the operator's Documents
  /// folder when its migration fails, and on Windows Documents is the
  /// OneDrive-synced location this class exists to stay out of. Only an unset
  /// %LOCALAPPDATA% — never the case for an interactive session — settles for
  /// wherever the app's other files ended up.
  ///
  /// [environment] is a parameter only because tests cannot mutate the real
  /// one in-process, and this path IS the fix: a silent regression to the
  /// default folder brings the whole bug back.
  @visibleForTesting
  static Future<String> userDataFolderPath({Map<String, String>? environment}) async {
    final localAppData = (environment ?? Platform.environment)['LOCALAPPDATA'];
    final base = (localAppData == null || localAppData.isEmpty)
        ? (await appDataDirectory()).path
        : p.join(localAppData, windowsDataFolderName);
    return p.join(base, kWebView2DataDirName);
  }

  /// Stands in for the platform call this class exists to survive. Tests need
  /// it because `Platform.isWindows` cannot be faked and the plugin's method
  /// channel isn't there to fail the way the affected machines do.
  @visibleForTesting
  static Future<WebViewEnvironment> Function()? debugCreateEnvironment;

  @visibleForTesting
  static void debugReset() {
    _environment = null;
    _resolved = null;
    _pending = null;
    debugCreateEnvironment = null;
  }
}

/// Whether a pane may build an `InAppWebView` yet.
///
/// Three states rather than two, because "nobody has asked yet" is visibly
/// different from "no". The first Windows probe of a session spawns a browser
/// process and is allowed up to [WindowsWebView._deadline]; a pane that
/// renders a definite "not supported here" for that long is read as a verdict,
/// and the operator closes it rather than waiting out an answer that was going
/// to be yes.
enum WebviewSupport { pending, yes, no }

/// The platform rule every pane with no fallback of its own follows: the web
/// has an iframe, Linux has nothing, everything else but Windows is fine, and
/// Windows has to be asked.
///
/// Returns the answer available synchronously. [onResolved] fires later ONLY
/// when that answer is [WebviewSupport.pending] — a caller must still check
/// `mounted`, since a pane can be disposed while the browser process comes up.
///
/// Deliberately not used by the Map tab, which has a real fallback map and so
/// answers a different question: OSM is a worse map, not an absent one, and
/// showing it while the probe runs beats showing a spinner over a map the
/// operator could already be reading.
WebviewSupport probeWebviewSupport(void Function(bool) onResolved) {
  if (kIsWeb) return WebviewSupport.yes;
  if (defaultTargetPlatform == TargetPlatform.linux) return WebviewSupport.no;
  if (defaultTargetPlatform != TargetPlatform.windows) return WebviewSupport.yes;
  final resolved = WindowsWebView.resolved;
  if (resolved != null) return resolved ? WebviewSupport.yes : WebviewSupport.no;
  WindowsWebView.isAvailable().then(onResolved);
  return WebviewSupport.pending;
}
