// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:web/web.dart' as web;

/// Reopens the app's current URL in a standalone window sized like a phone
/// screen (390x844, an iPhone-class viewport). Returns whether the browser
/// actually opened it — `Window.open` returns null rather than throwing when
/// a popup blocker refuses, and that has to reach the operator rather than
/// being reported as success.
///
/// Any non-empty `features` string is what makes a browser drop the tab strip
/// and the rest of its normal chrome for the new window — there is no
/// separate "no chrome" flag to pass. The new window is a fresh load of the
/// app, sharing this tab's origin (and so its IndexedDB/localStorage) but
/// none of its in-memory state.
bool openPopupWindow() {
  final url = web.window.location.href;
  final popup = web.window.open(url, '_blank', 'popup,width=390,height=844');
  return popup != null;
}
