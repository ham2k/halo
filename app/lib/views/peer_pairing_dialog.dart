// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time "allow this device?" prompt for peer sync (HALO-310).
//
// The operator's answer IS the security boundary: nothing on the wire proves
// a device is who it says it is (see peer_protocol.dart's header), so this
// shows BOTH the self-asserted name and the device id it is claiming, and
// says plainly that anything on the network can ask. A prompt that showed
// only a friendly name would be trivially spoofable by choosing a friendly
// name.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';

/// Returns true when the operator allows the device, false when they decline,
/// and null when they dismiss it — a dismissal is deliberately NOT an allow.
Future<bool?> showPeerPairingDialog(
  BuildContext context, {
  required String deviceName,
  required String deviceId,
}) {
  return showHaloDialog<bool>(
    context: context,
    // A stray tap outside must not answer a security question. Dismissing is
    // still possible (the Reject action, or back), it just cannot happen by
    // accident.
    barrierDismissible: false,
    builder: (dialogContext) {
      final t = dialogContext.t.settings.peers;
      final theme = Theme.of(dialogContext);
      return HaloDialog(
        title: Text(t.pairTitle(name: deviceName.isEmpty ? deviceId : deviceName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.pairBody),
            const SizedBox(height: Space.xl),
            Text(t.pairIdLabel, style: theme.textTheme.labelMedium),
            // Mono, like every other identifier the app shows: the operator
            // is being asked to compare this against what the other device
            // displays, character by character.
            SelectableText(deviceId, style: haloMonoStyle(dialogContext, fontSize: 12)),
            const SizedBox(height: Space.xl),
            Text(
              t.pairWarning,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.reject),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.allow),
          ),
        ],
      );
    },
  );
}
