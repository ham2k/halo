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

/// How long a section takes to open or shut, and the curve it takes —
/// shared by the box accordion and the sliver one so the two never drift
/// into different animations of the same gesture.
const accordionDuration = Duration(milliseconds: 200);
const accordionCurve = Curves.easeInOut;

/// The tinted, tappable bar at the top of a section: the chevron, the title,
/// and whatever control the host hangs off the end. Both accordions draw it,
/// and the sliver one PINS it — which is the whole reason it is a widget of
/// its own rather than a private builder.
class AccordionHeader extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the Manage extensions button).
  final Widget? trailing;

  /// Added to the header's own padding — for a host whose rows are inset
  /// beyond the pane's edges (Settings centres its content in a wide
  /// window), so the chevron and title line up with them while the header's
  /// tint still runs edge to edge.
  final EdgeInsetsGeometry headerInset;

  const AccordionHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    this.trailing,
    this.headerInset = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final arrow = IconButton(
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: accordionDuration,
        curve: accordionCurve,
        child: Icon(
          MdiIcons.chevronDown,
          color: onHeaderColor,
          semanticLabel: expanded ? context.t.common.collapse : context.t.common.expand,
        ),
      ),
      onPressed: onToggle,
    );

    return Material(
      color: headerColor,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
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
        ),
      ),
    );
  }
}

class AccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;
  final Widget child;

  /// See [AccordionHeader.trailing].
  final Widget? trailing;

  /// See [AccordionHeader.headerInset].
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

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccordionHeader(
            title: title,
            expanded: expanded,
            onToggle: onToggle,
            headerColor: headerColor,
            onHeaderColor: onHeaderColor,
            trailing: trailing,
            headerInset: headerInset,
          ),
          AnimatedCrossFade(
            firstChild: child,
            secondChild: const SizedBox(width: double.infinity),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: accordionDuration,
            sizeCurve: accordionCurve,
          ),
        ],
      );
}

/// [AccordionSection] over a SLIVER body, with its header PINNED: the header
/// holds the top of the viewport while the section's own rows scroll under
/// it, and is pushed off by whatever comes next.
///
/// Only meaningful inside a scroll view — the group pins within its own
/// extent, so the header goes when the section does. A pinned band nested
/// inside it (a [SectionHeader.pinned] in [sliver]) stacks UNDER this one
/// rather than over it.
class SliverAccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;

  /// The body, as ONE sliver — a group where the section holds several.
  final Widget sliver;

  /// See [AccordionHeader.trailing].
  final Widget? trailing;

  /// See [AccordionHeader.headerInset].
  final EdgeInsetsGeometry headerInset;

  const SliverAccordionSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    required this.sliver,
    this.trailing,
    this.headerInset = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
        slivers: [
          PinnedHeaderSliver(
            child: AccordionHeader(
              title: title,
              expanded: expanded,
              onToggle: onToggle,
              headerColor: headerColor,
              onHeaderColor: onHeaderColor,
              trailing: trailing,
              headerInset: headerInset,
            ),
          ),
          CollapsingSliver(expanded: expanded, child: sliver),
        ],
      );
}
