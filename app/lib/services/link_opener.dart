// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one place an arbitrary URL becomes an external launch. Anything whose
// URL comes from outside the app — an extension's notice action, a settings
// link, the markdown in a call note — goes through here.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Schemes we are willing to hand to the platform.
///
/// An allowlist rather than a denylist: these URLs are authored by extensions
/// and by community call-notes files, so `javascript:` and `file:` must not be
/// reachable just because nobody thought to exclude them.
const _allowedSchemes = {'http', 'https', 'mailto'};

/// Opens [url], if it is something we are prepared to open.
///
/// Silently does nothing for a malformed or disallowed URL — callers are tap
/// handlers on text that the operator did not write, where the useful response
/// to junk is to ignore it rather than to raise anything. A URL that passes and
/// then fails to launch is a different case: that stays unhandled.
///
/// [mode] defaults to leaving the app. Pass [LaunchMode.platformDefault] where
/// an in-app browser (Custom Tab / SFSafariViewController on mobile) is the
/// established behaviour for that surface.
void openExternalUrl(String url, {LaunchMode mode = LaunchMode.externalApplication}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_allowedSchemes.contains(uri.scheme)) {
    debugPrint('[links] refusing to open "$url"');
    return;
  }
  unawaited(launchUrl(uri, mode: mode));
}
