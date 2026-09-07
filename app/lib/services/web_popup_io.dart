// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Non-web fallback: DEVPOPUP is gated to web before this is ever called (see
// main.dart's `devPopup` case), so reaching it means that gate is wrong — it
// throws rather than no-opping to make that visible.

bool openPopupWindow() {
  throw UnsupportedError('openPopupWindow is web-only.');
}
