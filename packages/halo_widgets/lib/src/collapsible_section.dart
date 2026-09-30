// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one folding section every surface uses: a header that toggles, led by
// a [DisclosureChevron], over a body that folds on the same clock the caret
// turns on (docs/design/user-interface.md § Folding sections). The header
// looks differ by role — a filled band for a category, the unfilled heading
// for a section inside one, a bold row inside a form — and nothing else does.

import 'package:flutter/material.dart';

import 'collapsing_sliver.dart';
import 'disclosure_chevron.dart';
import 'section_header.dart';
import 'spacing.dart';
import 'theme.dart';

/// How long every section takes to open or shut, and the curve it takes —
/// shared by the box body, the sliver body and the caret, so no two folds in
/// the app play the same gesture at different speeds, and the turn and the
/// fold finish together.
const collapseDuration = Duration(milliseconds: 200);
const collapseCurve = Curves.easeInOut;

/// The FILLED header of a folding category — the Settings panel's, Add
/// Equipment's brand shelves: the caret, the title, and whatever control
/// the host hangs off the end. A widget of its own because the sliver
/// section PINS it.
class CollapsibleBand extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;

  /// The band's ground; the category band colour when null.
  final Color? headerColor;

  /// The caret's colour, matching the title's; the section heading accent
  /// when null.
  final Color? onHeaderColor;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the Manage extensions button).
  final Widget? trailing;

  /// Added to the header's own padding — for a host whose rows are inset
  /// beyond the pane's edges (Settings centres its content in a wide
  /// window), so the chevron and title line up with them while the header's
  /// tint still runs edge to edge.
  final EdgeInsetsGeometry headerInset;

  const CollapsibleBand({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.headerColor,
    this.onHeaderColor,
    this.trailing,
    this.headerInset = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final caretColor = onHeaderColor ?? SectionHeader.titleStyle(context).color;

    // The chevron hangs in the left margin when the margin has room for it, so
    // the TITLE starts where the rows' own text does — the same line a
    // [CategoryBand] or [SectionHeader] title keeps. Where the margin is too
    // narrow the chevron sits at the edge and the title follows it.
    //
    // The rows' inset is read from the ambient ListTileTheme, which already
    // carries any centring a wide pane adds — so [headerInset] is NOT added
    // on this side, or the title lands a whole centring past the rows.
    final direction = Directionality.of(context);
    final inset = headerInset.resolve(direction);
    final rowStart = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(direction).left;
    final hanging = rowStart - kMinInteractiveDimension;
    final left = hanging > Space.xs ? hanging : Space.xs;

    return Material(
      color: headerColor ?? haloCategoryBandColor(context),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          // Extra room on the right so the trailing control doesn't sit flush
          // against the pane's edge.
          padding: EdgeInsets.fromLTRB(left, Space.sm, Space.lg + inset.right, Space.sm),
          child: Row(
            children: [
              // A fixed width, whatever the platform's visual density makes
              // of an IconButton, so the title lands where `left` put it.
              SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: IconButton(
                  icon: DisclosureChevron(expanded: expanded, color: caretColor),
                  onPressed: onToggle,
                ),
              ),
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

/// The header of a fold INSIDE a form — Advanced settings, a troubleshooting
/// note: a row among the form's rows, in their inset, its title in the bold
/// row face rather than a heading's.
class CollapsibleRow extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  /// Overrides the title's colour (the dev-mode orange).
  final Color? color;

  const CollapsibleRow({super.key, required this.title, required this.expanded, required this.onToggle, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero,
    leading: DisclosureChevron(expanded: expanded, color: color),
    title: Text(
      title,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
    ),
    onTap: onToggle,
  );
}

/// The body of a box section: folds and fades out from the top, resizing as
/// it goes.
///
/// A shut body stays MOUNTED — a form inside it keeps its FocusNodes and
/// TextEditingControllers, and whatever was typed survives a close — but is
/// out of the focus order, hit-testing and semantics, all of which
/// [AnimatedCrossFade] withholds from its hidden child.
class CollapsibleBody extends StatelessWidget {
  final bool expanded;
  final Widget child;

  const CollapsibleBody({super.key, required this.expanded, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
    firstChild: child,
    secondChild: const SizedBox(width: double.infinity),
    crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    duration: collapseDuration,
    sizeCurve: collapseCurve,
  );
}

/// A folding section as a box: its header, then [child] while open.
///
/// One constructor per header role, so a surface picks what its section IS
/// rather than assembling a look:
/// - [CollapsibleSection.band] — a category, on the filled band.
/// - [CollapsibleSection.row] — a fold inside a form.
///
/// A section heading (the unfilled one) folds inside a [SectionedListView]
/// instead: give the [SectionHeader] `expanded` and `onTap`, and the list
/// folds the rows after it.
class CollapsibleSection extends StatelessWidget {
  final Widget header;
  final bool expanded;
  final Widget child;

  CollapsibleSection.band({
    super.key,
    required Widget title,
    required this.expanded,
    required VoidCallback onToggle,
    Color? headerColor,
    Color? onHeaderColor,
    Widget? trailing,
    EdgeInsetsGeometry headerInset = EdgeInsets.zero,
    required this.child,
  }) : header = CollapsibleBand(
         title: title,
         expanded: expanded,
         onToggle: onToggle,
         headerColor: headerColor,
         onHeaderColor: onHeaderColor,
         trailing: trailing,
         headerInset: headerInset,
       );

  CollapsibleSection.row({super.key, required String title, required this.expanded, required VoidCallback onToggle, Color? color, required this.child})
    : header = CollapsibleRow(title: title, expanded: expanded, onToggle: onToggle, color: color);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      header,
      CollapsibleBody(expanded: expanded, child: child),
    ],
  );
}

/// [CollapsibleSection.band] over a SLIVER body, with its header PINNED: the
/// header holds the top of the viewport while the section's own rows scroll
/// under it, and is pushed off by whatever comes next.
///
/// Only meaningful inside a scroll view — the group pins within its own
/// extent, so the header goes when the section does. A pinned band nested
/// inside it (a [SectionHeader.pinned] in [sliver]) stacks UNDER this one
/// rather than over it.
class SliverCollapsibleSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color? headerColor;
  final Color? onHeaderColor;

  /// The body, as ONE sliver — a group where the section holds several.
  final Widget sliver;

  /// See [CollapsibleBand.trailing].
  final Widget? trailing;

  /// See [CollapsibleBand.headerInset].
  final EdgeInsetsGeometry headerInset;

  /// A key on the header's own box, for a host that has to SCROLL to this
  /// section — the sliver itself has no RenderBox for `ensureVisible` to
  /// work against, and the header is the part worth revealing anyway.
  final Key? headerKey;

  const SliverCollapsibleSection({
    super.key,
    this.headerKey,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.headerColor,
    this.onHeaderColor,
    required this.sliver,
    this.trailing,
    this.headerInset = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      PinnedHeaderSliver(
        child: CollapsibleBand(
          key: headerKey,
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
