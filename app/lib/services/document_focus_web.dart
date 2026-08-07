// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:web/web.dart' as web;

/// Whether the page is the one the operator is currently in — false once they
/// switch window, tab or application. Distinct from the FLUTTER VIEW's own
/// focus, which the accessibility DOM can drop while the page keeps its own
/// (see `ViewFocusGuard`).
bool documentHasFocus() => web.document.hasFocus();
