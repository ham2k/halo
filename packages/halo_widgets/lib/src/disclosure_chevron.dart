// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'collapsible_section.dart';
import 'mdi_icons.g.dart';

/// The caret leading every folding section: right when shut, down when open,
/// the disclosure triangle a file tree draws, pointing at what opening would
/// reveal. One glyph rotated rather than two swapped, so the turn is
/// continuous, and on [collapseDuration] so it lands as the body finishes
/// folding. It only shows which way the section is — the header is the
/// control.
class DisclosureChevron extends StatelessWidget {
  final bool expanded;

  /// The header's own text colour, where the ambient icon colour is not it —
  /// a caret in another colour than its title reads as a separate control.
  final Color? color;

  const DisclosureChevron({super.key, required this.expanded, this.color});

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    // `chevronDown` rests pointing down; a quarter turn ANTI-clockwise from
    // there is right. The positive quarter would point it left, at nothing.
    turns: expanded ? 0 : -0.25,
    duration: collapseDuration,
    curve: collapseCurve,
    child: Icon(MdiIcons.chevronDown, color: color, semanticLabel: expanded ? t.common.collapse : t.common.expand),
  );
}
