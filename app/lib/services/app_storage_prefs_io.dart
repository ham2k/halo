// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import 'error_reporting_service.dart';

/// Makes shared_preferences write `shared_preferences.json` into [directory]
/// instead of the app-support directory it would pick for itself.
///
/// The plugin builds that path from a `PathProviderWindows` it constructs
/// internally, so overriding `PathProviderPlatform.instance` — the seam that
/// works for everything else — doesn't reach it, and the only public knob its
/// options expose is the file's *name*. Substituting the store's own provider
/// is what's left, and it keeps the plugin's read/write logic intact rather
/// than reimplementing preference storage. Must run before anything awaits
/// `SharedPreferences.getInstance()`: the store caches what it first read.
///
/// Windows only — every other platform already writes its preferences into
/// the directory [appDataDirectory] resolves to.
Future<void> redirectPreferencesDirectory(String directory) async {
  final store = SharedPreferencesStorePlatform.instance;
  if (store is! SharedPreferencesWindows) {
    // Not a crash: preferences keep working from wherever the plugin decides.
    // Reported because it silently splits settings from the rest of the
    // app's files, which is exactly what this is here to prevent.
    ErrorReportingService.report(
      StateError('shared_preferences store is ${store.runtimeType}, not SharedPreferencesWindows'),
      StackTrace.current,
      context: 'app-storage:redirect-preferences',
    );
    return;
  }
  // ignore: invalid_use_of_visible_for_testing_member
  store.pathProvider = _FixedPathProviderWindows(directory);
}

/// A [PathProviderWindows] that answers with one fixed support directory and
/// otherwise behaves normally.
class _FixedPathProviderWindows extends PathProviderWindows {
  _FixedPathProviderWindows(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}
