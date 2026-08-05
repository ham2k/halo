// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The canonical HTTP `User-Agent` for every HaLo network call. See
// docs/design/network.md — every outgoing request that lets us set headers
// must send this string, and the extension host stamps it on all
// `host.fetch` traffic automatically.

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'version.dart';

/// The platform name as used in the UA string and `host.getVersionInfo`
/// (HALO-140) — `web`/`macos`/`ios`/`android`/`windows`/`linux`/`fuchsia`.
String platformName() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

/// The resolved UA, memoized for the process life. The resolved *String*,
/// deliberately not the Future: a memoized Future is shared by every caller,
/// and dart:async will not deliver an error across an error-zone boundary —
/// it hands it to the zone that CREATED the future instead (future_impl.dart
/// `_propagateToListeners`, "Don't cross zone boundaries with errors"), and
/// the caller that joined never hears back at all. Under `flutter test` every
/// test is its own error zone and background work outlives the test that
/// started it, so a shared pending Future that fails reddens whichever test
/// created it — usually one that has already finished.
String? _cached;

/// The canonical `User-Agent`, e.g. `Ham2K Logger/26.8.0 (macos next 1)`.
///
/// Shaped as `Ham2K Logger/{publicVersion} ({platform} {flavor} {build})`,
/// where the build number is the native build (via package_info_plus) and is
/// omitted when unavailable. Resolved once and cached for the process life; a
/// failure caches nothing, so the next call retries instead of re-throwing
/// forever. Throws when the platform channel can't answer — see
/// [ham2kUserAgentOrFallback] for callers that must not fail on that.
///
/// Concurrent first callers each make their own package_info_plus call rather
/// than sharing one Future (see [_cached]); package_info_plus caches the
/// resolved value itself, so that costs at most one extra platform call.
///
/// Note: on web `User-Agent` is a forbidden request header, so the browser
/// drops it — see docs/design/network.md.
Future<String> ham2kUserAgent() async {
  final cached = _cached;
  if (cached != null) return cached;
  return _cached = _format((await PackageInfo.fromPlatform()).buildNumber);
}

/// The canonical `User-Agent` MINUS the native build number, e.g.
/// `Ham2K Logger/26.8.0 (macos next)`. Resolvable synchronously and without
/// package_info_plus, so it never throws — the safe fallback for callers that
/// must not fail on UA resolution (the extension runtime start; see
/// `ExtensionService`). A first-call [ham2kUserAgent] can throw if the
/// platform channel isn't ready (headless tests, early boot); this fills in
/// for that one call without polluting the cache, so a later call still gets
/// the full build-stamped UA.
String ham2kUserAgentWithoutBuild() => _format(null);

/// [ham2kUserAgent] that never throws: the full build-stamped UA when the
/// platform channel answers, otherwise [ham2kUserAgentWithoutBuild]. For
/// callers on paths that must not fail on UA resolution — the extension
/// runtime start and background fetches (flags, data files) — where a missing
/// build number is no reason to abort the whole operation.
Future<String> ham2kUserAgentOrFallback() async {
  try {
    return await ham2kUserAgent();
  } catch (e) {
    debugPrint('[user-agent] build number unavailable, using build-less UA: $e');
    return ham2kUserAgentWithoutBuild();
  }
}

String _format(String? build) {
  final parts = [platformName(), kAppFlavor, if (build != null && build.isNotEmpty) build];
  return 'Ham2K Logger/$kPublicVersion (${parts.join(' ')})';
}
