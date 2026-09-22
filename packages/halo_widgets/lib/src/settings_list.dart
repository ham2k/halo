// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one inset every settings-shaped list measures itself by, and the
// wrapper that publishes it (docs/design/user-interface.md § Settings
// lists). A settings panel, a target-scoped settings dialog, a pane's
// layout options and the spot filters are all the same list to the operator,
// so they take their inset from the same place rather than each naming a
// spacing rung.

import 'package:flutter/material.dart';

/// What a settings row insets its CONTENTS by, off the row's own edge — the
/// row itself runs to the surface's. One number, because a pane's title lines
/// up with it too (see `settings_view.dart`'s wide layout).
const double settingsRowInset = 24;

/// Publishes [settingsRowInset] as the ambient `ListTileTheme` inset, which
/// is where every row in a settings list reads it from — `ListTile`-based
/// rows directly, [FormRenderer]'s rows and [SectionHeader] through their own
/// lookups.
///
/// The inset rides the theme rather than a `Padding` around the list because
/// row backgrounds, dividers and section bands must reach the surface's
/// edges: pad the list and they float in a gutter, which is precisely what
/// this exists to prevent.
///
/// [extraLeft] is for a surface whose left edge is not where its content
/// starts — a pane behind a resize grab strip, or one centring its rows in a
/// wide window. It adds to the left inset only, so the row still starts where
/// the operator's eye expects while the row itself still spans.
class SettingsList extends StatelessWidget {
  final Widget child;
  final double extraLeft;

  const SettingsList({super.key, required this.child, this.extraLeft = 0});

  @override
  Widget build(BuildContext context) => ListTileTheme.merge(
    contentPadding: EdgeInsets.only(left: settingsRowInset + extraLeft, right: settingsRowInset),
    child: child,
  );
}
