// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'platform_view_shield.dart';
import 'spacing.dart';

/// A SnackBar saying [message], shielded edge to edge from a map beneath it on
/// the web (platform_view_shield.dart): a bar given a padding of its own drops
/// its built-in one, so the padding moves inside the shield and the shield
/// spans the whole bar. The only way the app builds one —
/// `snack_bar_shield_test.dart` fails the build on any other.
///
/// [actionLabel] and [onAction] put a button at the bar's end — inside the
/// shield, not as the bar's own `action`, which would sit outside it and hand
/// its clicks to the map. Like a bar's own action, it keeps the bar up until
/// pressed or swiped away, and pressing it takes the bar down: an offer that
/// times out while the operator reads it is no offer.
SnackBar haloSnackBar(String message, {String? actionLabel, VoidCallback? onAction}) => SnackBar(
  padding: EdgeInsets.zero,
  persist: actionLabel != null && onAction != null,
  content: PlatformViewShield(
    child: Padding(
      // A floating bar's own: 16 across, 14 above and below its line.
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg + Space.xxs),
      child: actionLabel == null || onAction == null
          ? Text(message)
          : Builder(
              builder: (context) => Row(
                children: [
                  Expanded(child: Text(message)),
                  const SizedBox(width: Space.md),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.inversePrimary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      onAction();
                    },
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
    ),
  ),
);
