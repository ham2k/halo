// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'mdi_icons.g.dart';

/// The caret leading a folding row: right when shut, down when open, the
/// disclosure triangle the app's accordions draw. One glyph rotated rather
/// than two swapped, so the turn is continuous. It only shows which way the
/// row is — the row itself is the control.
class DisclosureChevron extends StatelessWidget {
  final bool expanded;

  const DisclosureChevron({super.key, required this.expanded});

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    // `chevronDown` rests pointing down; a quarter turn ANTI-clockwise from
    // there is right. The positive quarter would point it left, at nothing.
    turns: expanded ? 0 : -0.25,
    duration: const Duration(milliseconds: 200),
    child: Icon(MdiIcons.chevronDown, semanticLabel: expanded ? t.common.collapse : t.common.expand),
  );
}
