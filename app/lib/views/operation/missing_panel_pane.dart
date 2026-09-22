// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a pane shows when the panel behind it is not in the catalog — an
// extension disabled, uninstalled, or one whose runtime has not answered
// yet (docs/design/layouts.md).
//
// The pane STAYS. A saved arrangement is never set aside for naming a
// module the catalog cannot currently explain: an extension that is only
// briefly missing repairs itself when it answers, and one that is really
// gone waits to be removed from Layout Setup, deliberately. The alternative
// — judging the arrangement unbuildable — means the next thing written
// replaces it, so a hook that timed out once costs the operator a layout
// they cannot get back.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';

/// The extension a panel id belongs to, for naming it in a message. Ids are
/// `ext:<hookKey>:<panelKey>`; anything else is not an extension's.
String? extensionKeyOfPanelId(String id) {
  final parts = id.split(':');
  return parts.length >= 3 && parts.first == 'ext' ? parts[1] : null;
}

/// The panel's own key, which reads better on a tab than the full id.
String panelKeyOfPanelId(String id) {
  final parts = id.split(':');
  return parts.length >= 3 && parts.first == 'ext' ? parts.sublist(2).join(':') : id;
}

class MissingPanelPane extends StatelessWidget {
  final String extensionName;

  const MissingPanelPane({super.key, required this.extensionName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.toyBrickRemove, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: Space.lg),
            Text(
              context.t.operation.layout.missingExtension(name: extensionName),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
