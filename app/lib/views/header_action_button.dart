// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

/// An action in a view's header (Exports, Imports, Tools): labelled where
/// the header has room for it ([labeled]), an icon carrying its accessible
/// name where it has not. One look for the operation, Chasing and Logs
/// headers.
///
/// Disabled ([onPressed] null), it dims the header's own color: Material's
/// disabled grey all but vanishes on the header, and an action that is
/// there but has nothing to act on yet should still be seen.
Widget headerActionButton(BuildContext context, {required IconData icon, required String label, required bool labeled, required VoidCallback? onPressed}) {
  final theme = Theme.of(context);
  final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
  final disabled = onHeader.withValues(alpha: 0.38);
  return labeled
      ? TextButton.icon(
          icon: Icon(icon),
          label: Text(label),
          style: TextButton.styleFrom(foregroundColor: onHeader, disabledForegroundColor: disabled, disabledIconColor: disabled),
          onPressed: onPressed,
        )
      : IconButton(
          icon: Icon(icon, semanticLabel: label),
          color: onHeader,
          disabledColor: disabled,
          onPressed: onPressed,
        );
}
