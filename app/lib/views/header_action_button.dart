// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

/// An action in a view's header (Exports, Imports, Tools): labelled where
/// the header has room for it ([labeled]), an icon carrying its accessible
/// name where it has not. One look for the operation, Chasing and Logs
/// headers.
Widget headerActionButton(BuildContext context, {required IconData icon, required String label, required bool labeled, required VoidCallback? onPressed}) {
  final theme = Theme.of(context);
  return labeled
      ? TextButton.icon(
          icon: Icon(icon),
          label: Text(label),
          style: TextButton.styleFrom(foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary),
          onPressed: onPressed,
        )
      : IconButton(
          icon: Icon(icon, semanticLabel: label),
          onPressed: onPressed,
        );
}
