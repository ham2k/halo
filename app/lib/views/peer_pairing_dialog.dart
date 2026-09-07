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

import 'package:halo_i18n/halo_i18n.dart';

/// The first group of a v4 UUID — enough to tell two devices apart at a
/// glance, and short enough to sit on a row beside a name. Every surface
/// that shows an id shortens it the same way, or the operator would be
/// comparing two different things across the two devices.
String shortPeerDeviceId(String deviceId) =>
    deviceId.length <= 8 ? deviceId : deviceId.substring(0, 8);

/// Returns true when the operator allows the device, false when they decline,
/// and null when they dismiss it — a dismissal is deliberately NOT an allow.
///
/// [viaBluetooth] only changes the words: which pipe carried the request is
/// what tells the operator WHICH nearby device this might be — "on your local
/// network" and "nearby, over Bluetooth" narrow it to different sets of boxes,
/// and the warning has to name the same set it is warning about.
Future<bool?> showPeerPairingDialog(
  BuildContext context, {
  required String deviceName,
  required String deviceId,
  required bool viaBluetooth,
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
        title: Text(t.pairTitle(name: deviceName.isEmpty ? shortPeerDeviceId(deviceId) : deviceName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(viaBluetooth ? t.pairBodyBle : t.pairBody),
            const SizedBox(height: Space.xl),
            Text(t.pairIdLabel, style: theme.textTheme.labelMedium),
            // Mono, like every other identifier the app shows. The first
            // group of the id only — the same form the device lists use, so
            // what the operator reads here matches what the other device
            // shows for this one.
            SelectableText(shortPeerDeviceId(deviceId), style: haloMonoStyle(dialogContext, fontSize: 12)),
            const SizedBox(height: Space.xl),
            Text(
              viaBluetooth ? t.pairWarningBle : t.pairWarning,
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
