// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// "Run an extension from h2kext-dev?" (docs/design/extension-dev-link.md).
// The tool's name, folder and keys are its own word, so the dialog says what
// allowing it does, never that the tool is what it says.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/extensions/dev_link/extension_dev_link.dart';

/// The operator's answer: true to allow. Closes on its own, answering
/// false, when [withdrawn] completes: the tool hung up, or the link stopped.
Future<bool> showExtensionDevLinkDialog(BuildContext context, {required ExtensionDevLinkAsk ask, required Future<void> withdrawn}) async {
  final allowed = await showHaloDialog<bool>(
    context: context,
    // A stray tap outside must not answer it.
    barrierDismissible: false,
    builder: (dialogContext) {
      unawaited(
        withdrawn.then((_) {
          if (!dialogContext.mounted) return;
          final route = ModalRoute.of(dialogContext);
          if (route == null || !route.isActive) return;
          // Under another route it is removed where it is: left there, it
          // would hold back the next tool's question, and an Allow on it
          // would answer a request already gone.
          if (route.isCurrent) {
            Navigator.of(dialogContext).pop(false);
          } else {
            Navigator.of(dialogContext).removeRoute(route, false);
          }
        }),
      );
      final t = dialogContext.t.settings.developer;
      final theme = Theme.of(dialogContext);
      return HaloDialog(
        title: Text(t.extDevLinkTitle(tool: ask.tool)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.extDevLinkBody(tool: ask.tool, keys: ask.keys.join(', '), dir: ask.dir)),
            const SizedBox(height: Space.lg),
            Text(t.extDevLinkWarning, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t.extDevLinkDeny)),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(t.extDevLinkAllow))],
      );
    },
  );
  return allowed ?? false;
}
