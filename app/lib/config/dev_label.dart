// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The developer label the home header and the branding pane both show. Its own
// file because those two live in separate ones and neither owns it.

import 'dev_flags.dart';
import 'web_preview_label.dart';

/// A free-form developer label shown in the home header after the edition
/// badge — marks which dev build/session is running. Set with
/// `--dart-define=DEV_LABEL=…` or (off web) a `DEV_LABEL` environment variable;
/// that explicit label is dev-only (stripped in release). Web preview
/// deployments are themselves release builds, so they instead fall back to the
/// preview name derived from the URL. Empty
/// otherwise. Resolved once (a lazy top-level final).
final String devLabel = _resolveDevLabel();

String _resolveDevLabel() {
  final explicit = debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL');
  if (explicit.isNotEmpty) return explicit;
  return webPreviewLabel();
}
