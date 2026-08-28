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

/// Whether [openExternalUrl] would actually open [url].
///
/// For a caller that RENDERS a control because a link exists: a button whose
/// only job is to open one must not be drawn for a URL that will be refused,
/// or the operator taps a live-looking control forever and the only record is
/// a debugPrint. Checking here rather than at the tap keeps the two answers
/// from drifting apart.
bool canOpenExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && _allowedSchemes.contains(uri.scheme);
}

/// Opens [url], if it is something we are prepared to open.
///
/// Silently does nothing for a malformed or disallowed URL — callers are tap
/// handlers on text that the operator did not write, where the useful response
/// to junk is to ignore it rather than to raise anything. A caller that DRAWS
/// a control for the link is not that caller: it asks [canOpenExternalUrl]
/// first and draws nothing, rather than offering a button that does nothing.
/// A URL that passes and then fails to launch is a different case: that stays
/// unhandled.
///
/// Always [LaunchMode.externalApplication], with no per-caller override: a
/// link the app hands off belongs in the operator's own browser, where their
/// sessions, extensions and history are, and not in an in-app browser (a
/// Custom Tab / SFSafariViewController) that merely looks like one.
void openExternalUrl(String url) {
  if (!canOpenExternalUrl(url)) {
    debugPrint('[links] refusing to open "$url"');
    return;
  }
  unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
}
