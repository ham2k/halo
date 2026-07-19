// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

import '../i18n/strings.g.dart';

/// Localized pill text for a scoring notice/alert key (`duplicate`, `newBand`,
/// `newMode`, `newDXCC`), falling back to the raw key. Shared by the compact
/// call-info line (`logging_panel.dart`) and the call-info detail panel.
String scoreNoticeLabel(BuildContext context, String key) {
  final t = context.t.loggingControls.info;
  return switch (key) {
    'duplicate' => t.noticeDupe,
    'newBand' => t.noticeNewBand,
    'newMode' => t.noticeNewMode,
    'newDXCC' => t.noticeNewDXCC,
    _ => key,
  };
}
