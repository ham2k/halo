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

String _platformName() {
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

Future<String>? _cached;

/// The canonical `User-Agent`, e.g. `Ham2K Logger/26.8.0 (macos next 1)`.
///
/// Shaped as `Ham2K Logger/{publicVersion} ({platform} {flavor} {build})`,
/// where the build number is the native build (via package_info_plus) and is
/// omitted when unavailable. Resolved once and cached for the process life —
/// the Future itself is memoized, so concurrent first callers share one
/// package_info_plus lookup.
///
/// Note: on web `User-Agent` is a forbidden request header, so the browser
/// drops it — see docs/design/network.md.
Future<String> ham2kUserAgent() => _cached ??= _build();

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
  final parts = [_platformName(), kAppFlavor, if (build != null && build.isNotEmpty) build];
  return 'Ham2K Logger/$kPublicVersion (${parts.join(' ')})';
}

Future<String> _build() async {
  try {
    final build = (await PackageInfo.fromPlatform()).buildNumber;
    return _format(build);
  } catch (_) {
    // A first-call failure (e.g. the platform channel isn't ready yet) must
    // not be memoized for the process life — drop the cache so the next call
    // retries instead of re-throwing forever.
    _cached = null;
    rethrow;
  }
}
