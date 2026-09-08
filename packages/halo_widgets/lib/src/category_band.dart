// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'section_header.dart';
import 'spacing.dart';
import 'theme.dart';

/// The FILLED heading band — the shelf a group of rows sits on, as opposed to
/// [SectionHeader]'s unfilled heading, which names a group of rows already on
/// one (docs/design/user-interface.md § Settings lists).
///
/// The Settings panel's categories are the other use, with a chevron and a
/// tap (`AccordionSection`). This is the same band without them, for a
/// surface whose groups do not collapse — the equipment editor's, which
/// divides one form into what the equipment IS doing and how it is WIRED.
///
/// The ground runs edge to edge and the TITLE takes the row inset, which is
/// what makes a band read as the shelf rather than as one highlighted row.
/// So a host that pads its content horizontally has to spend that padding on
/// its rows instead, or this floats in a gutter.
class CategoryBand extends StatelessWidget {
  final String title;

  /// Overrides the accent the title is drawn in — the dev-mode orange, where
  /// a caller marks a section as developer-only.
  final Color? color;

  /// Under the title, in the ordinary body face.
  final Widget? subtitle;

  const CategoryBand(this.title, {super.key, this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    // The rows' own inset, and their own default for "none" — a band whose
    // idea of no-inset differs from theirs lands its title off the rows it
    // heads, which is the trap halo_dialog.dart's contentPadding note names.
    final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero)
        .resolve(Directionality.of(context));
    return Material(
      color: haloDialogBandColorAt(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset.left, Space.md, inset.right, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SectionHeader.titleStyle(context, color: color)),
            if (subtitle != null) ...[const SizedBox(height: Space.xs), subtitle!],
          ],
        ),
      ),
    );
  }

  /// This band pinned over its own rows, the way [SectionHeader.pinned] is —
  /// and opaque for the same reason, which its own ground already answers.
  Widget get asPinnedSliver => PinnedHeaderSliver(child: this);
}
