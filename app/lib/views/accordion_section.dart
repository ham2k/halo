// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One collapsible section. The tinted header always shows, arrow on the
// left; the body appears below it only while expanded, using the default
// (untinted) background. The arrow rotates and the body cross-fades and
// resizes smoothly.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';

class AccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;
  final Widget child;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the Manage extensions button).
  final Widget? trailing;

  /// Added to the header's own padding — for a host whose rows are inset
  /// beyond the pane's edges (Settings centres its content in a wide
  /// window), so the chevron and title line up with them while the header's
  /// tint still runs edge to edge.
  final EdgeInsetsGeometry headerInset;

  const AccordionSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    required this.child,
    this.trailing,
    this.headerInset = EdgeInsets.zero,
  });

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final arrow = IconButton(
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: _duration,
        curve: Curves.easeInOut,
        child: Icon(
          MdiIcons.chevronDown,
          color: onHeaderColor,
          semanticLabel: expanded ? context.t.common.collapse : context.t.common.expand,
        ),
      ),
      onPressed: onToggle,
    );

    final headerRow = Padding(
      // Extra room on the right so the trailing control doesn't sit flush
      // against the pane's edge — the rows below match it, see
      // `contentPadding`.
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.lg, Space.sm).add(headerInset),
      child: Row(
        children: [
          arrow,
          Expanded(child: title),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorbs taps so they don't propagate to InkWell
              child: trailing!,
            ),
        ],
      ),
    );

    final header = Material(
      color: headerColor,
      child: InkWell(onTap: onToggle, child: headerRow),
    );

    final body = AnimatedCrossFade(
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity),
      crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: _duration,
      sizeCurve: Curves.easeInOut,
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [header, body]);
  }
}
