// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:web/web.dart' as web;

import 'web_preview_label_parser.dart';

/// The preview name for the current web host (see [previewLabelForHost]), or
/// `''` when not running at a preview URL.
String webPreviewLabel() => previewLabelForHost(web.window.location.hostname);
