// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'sectioned_list.dart';
import 'spacing.dart';
import 'theme.dart';

/// The heading of a section of settings — every settings panel's, and
/// [FormRenderer]'s `style: 'section'` header, so a hand-built panel and a
/// declared one cannot drift apart.
///
/// The accent title over a hairline rule, on no ground of its own. The
/// Settings panel's CATEGORY headings are the filled bands (settings_view.
/// dart's `_settingsCategory`), and a section sits INSIDE one: taking a
/// ground here too would leave the two headings saying the same thing at
/// different sizes.
///
/// Title and rule alike keep the row inset, lining up with the rows they
/// head; the slab face and the rule are what set the heading apart from
/// them. The inset comes from the ambient `ListTileTheme` — the same one
/// every settings row takes its content inset from — so a heading and the
/// rows under it stay related wherever the pane puts them. With no inset
/// there, the heading takes none, exactly as [FormRenderer]'s rows and
/// [CategoryBand] do: a surface that pads its body itself has already
/// spent the inset, and a heading with a default of its own lands off the
/// rows by that much. A surface that pads nothing publishes the inset
/// (`SettingsList`) rather than leaning on a default here.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Under the title, in the ordinary body face — for a section that needs a
  /// line of explanation before its rows.
  final Widget? subtitle;

  /// Overrides the accent the title is drawn in (the dev-mode orange, where a
  /// caller marks a section as developer-only).
  final Color? color;

  /// One control on the band's trailing edge, level with the title — for a
  /// verb that acts on the SECTION rather than on any row in it ("Update
  /// all"). A row's own control belongs on the row.
  ///
  /// It shares the band's height, so keep it to a text or outlined button: the
  /// band is a heading, and a control tall enough to change that makes it a
  /// toolbar.
  final Widget? trailing;

  /// Before the title, inside the same inset — a disclosure chevron, for a
  /// section that folds. Unlike a category band's chevron it never hangs in
  /// the margin: a section sits inside a category, and its heading keeps the
  /// rows' measure.
  final Widget? leading;

  /// Makes the whole heading a control — for a section that folds, so the
  /// title opens it as well as the chevron beside it.
  final VoidCallback? onTap;

  /// A ground for the band, painted EDGE TO EDGE — past the inset the title
  /// and rule sit within.
  ///
  /// For a section that is a standing notice rather than one more group of
  /// rows: the ground runs behind its rows too, and a band inset from the
  /// pane's edges would leave two stripes of surface down the sides of one
  /// block of colour. Null is the ordinary heading, which has no ground of
  /// its own.
  final Color? background;

  const SectionHeader(this.title, {super.key, this.subtitle, this.color, this.trailing, this.leading, this.onTap, this.background});

  /// The band title's face, public so a hand-built HEADING that cannot be a
  /// [SectionHeader] — one carrying its own controls and geometry — still
  /// takes its title from here rather than restating it and drifting. Text that
  /// is not a heading (a count, a status line) does not belong in it, whatever
  /// ground it shares with one.
  ///
  /// A step above `titleSmall`: the band names a group of rows and has to be
  /// findable while scrolling past them.
  static TextStyle titleStyle(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.titleSmall;
    return base?.copyWith(
          fontFamily: 'RobotoSlab',
          fontWeight: FontWeight.w900,
          fontSize: (base.fontSize ?? 14) + 2,
          // Text on the surface, not a fill — HaLoColors.onSurfaceAccent,
          // not colorScheme.primary directly.
          color: color ?? HaLoColors.of(context).onSurfaceAccent,
        ) ??
        const TextStyle();
  }

  /// The rule under the title. A hairline, in the title's own accent: it
  /// closes the heading rather than dividing rows, so it is thinner than a
  /// [Divider] and coloured with what it belongs to.
  static const ruleWidth = 1.0;

  static EdgeInsets _padding(BuildContext context) {
    final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));
    // More above than below: the gap belongs between sections, and the
    // heading abuts the rows it names.
    return EdgeInsets.fromLTRB(inset.left, inset.top + Space.sm + Space.md, inset.right, inset.bottom + Space.sm);
  }

  /// This band as a header pinned to the top of its own section: it stays
  /// put while that section's rows scroll under it, and is pushed off by the
  /// next section's band. Only meaningful inside a [SliverMainAxisGroup]
  /// whose remaining slivers are the section's rows — pinned to the whole
  /// scroll view, every section's band would stack up at the top.
  ///
  /// A [PinnedHeaderSliver], so the band's height is whatever the band lays
  /// out to — a title that wraps at a large font scale takes the room it
  /// needs, which a stated extent can only guess at. Nested groups stack
  /// rather than overlap: it pins under whatever pinned band the group above
  /// it holds (the Settings panel's category band over its sections).
  static Widget pinned(BuildContext context, String title, {Color? color, Widget? subtitle, Widget? trailing, Color? background}) =>
      SectionHeader(title, color: color, subtitle: subtitle, trailing: trailing, background: background).asPinnedSliver(context);

  /// This very band as its pinned sliver — for a caller holding a built
  /// [SectionHeader] rather than a title ([sectionSlivers], which reads the
  /// bands out of a list of rows).
  Widget asPinnedSliver(BuildContext context) => PinnedHeaderSliver(
    // Painted, unlike the inline heading: pinned, it has its own rows
    // scrolling UNDER it, and a heading with no ground of its own would
    // show them through. The pane's surface is what it stands on — a
    // pinned band only belongs on a surface-grounded list — unless the
    // band brought its own, which is then what its rows scroll under.
    child: ColoredBox(color: background ?? Theme.of(context).colorScheme.surface, child: this),
  );

  /// A whole section: this band pinned over [children], which scroll under
  /// it until the next section's band pushes it off.
  ///
  /// Every sliver in the group is a sliver, [children] excepted — they are
  /// boxes, in a [SliverList]. A box handed straight to a viewport fails the
  /// whole list rather than just its own section.
  static Widget section(BuildContext context, String title, {required List<Widget> children, Color? color}) => SliverMainAxisGroup(
    slivers: [
      pinned(context, title, color: color),
      SliverList(delegate: SliverChildListDelegate(children)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // A band inside a sectioned list that is NOT the one that list pinned is
    // a band buried in a row: the list could not see it, so the rows under it
    // belong to the section above and its own pinned band names them. Silent
    // and plausible on screen, which is why it fails here instead.
    assert(
      context.findAncestorWidgetOfExactType<SectionedListView>() == null || context.findAncestorWidgetOfExactType<PinnedHeaderSliver>() != null,
      'A SectionHeader in a SectionedListView must be a direct child of it, '
      'or come from a widget that returns SectionedSlivers.',
    );
    final padding = _padding(context);
    // The inset is spent OUTSIDE the ruled box, not inside it: the rule
    // measures the content it heads, the same width as the rows under it,
    // rather than running out to the pane's edges the way a filled band (the
    // Settings panel's categories) does.
    final band = Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color ?? HaLoColors.of(context).onSurfaceAccent, width: ruleWidth),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trailing == null && leading == null)
              Text(title, style: titleStyle(context, color: color))
            else
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: Space.sm)],
                  // Expanded, not Flexible: the control belongs on the band's
                  // trailing edge, and a Flexible title shrink-wraps and drags
                  // it back against the last word. Expanded also gives the
                  // title the room to WRAP at a large font scale rather than
                  // pushing the control off the band.
                  Expanded(
                    child: Text(title, style: titleStyle(context, color: color)),
                  ),
                  if (trailing != null) ...[const SizedBox(width: Space.md), trailing!],
                ],
              ),
            if (subtitle != null) ...[const SizedBox(height: Space.xs), subtitle!],
          ],
        ),
      ),
    );
    // Outside the inset, so the ground reaches the pane's edges while the
    // title and its rule keep the measure of the rows they head.
    final grounded = background == null ? band : ColoredBox(color: background!, child: band);
    if (onTap == null) return grounded;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: grounded),
      ),
    );
  }
}
