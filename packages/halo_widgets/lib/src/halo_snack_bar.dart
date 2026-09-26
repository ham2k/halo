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
SnackBar haloSnackBar(String message) => SnackBar(
  padding: EdgeInsets.zero,
  content: PlatformViewShield(
    child: Padding(
      // A floating bar's own: 16 across, 14 above and below its line.
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg + Space.xxs),
      child: Text(message),
    ),
  ),
);
