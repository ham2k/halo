// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

/// Wraps [child] so it carries a stable, translation-independent semantics
/// [identifier] for agent/browser tooling (ham2k/app-halo-dist#236). In Flutter
/// web's accessibility DOM this surfaces as `flt-semantics-identifier="<id>"`,
/// which the generic browser tools (read_page / find / computer) can target
/// directly — no `window.__halo` bridge call needed for the common cases.
///
/// Always on: an identifier is just semantics metadata (no layout or meaningful
/// runtime cost, and inert unless something is reading semantics), so it ships
/// in every build. Only the *forcing* of Flutter web's semantics DOM is
/// dev-gated — see `ensureSemantics()` in the app's `main()`.
///
/// Convention for [identifier]: `field.<name>` for inputs (`field.call`),
/// `action.<name>` for buttons (`action.log`, `action.wipe`), `qso.row` for log
/// rows.
Widget semanticId(String identifier, Widget child) => Semantics(identifier: identifier, child: child);
