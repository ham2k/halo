// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small tinted label used to divide a settings-style ListView into sections
// (Operation Settings, Operation Location, app Settings) — shared so the
// three screens that use it stay visually and behaviorally in sync.

import 'package:flutter/material.dart';

import 'theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const SectionHeader(this.title, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // HaLoColors.onSurfaceAccent, not colorScheme.primary directly — this text
    // sits on the surface, and primary's dark-mode value is a fill color
    // tuned for the AppBar, not for reading directly on a dark background
    // directly.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color ?? HaLoColors.of(context).onSurfaceAccent)),
    );
  }
}
