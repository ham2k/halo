// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

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
/// Title and rule alike sit at the ROW INSET, so the rule spans the content
/// it heads and stops where the rows' own text does. The inset comes from
/// the ambient `ListTileTheme` — the same one every settings row takes its
/// content inset from — so a heading and the rows under it line up wherever
/// the pane puts them.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Under the title, in the ordinary body face — for a section that needs a
  /// line of explanation before its rows.
  final Widget? subtitle;

  /// Overrides the accent the title is drawn in (the dev-mode orange, where a
  /// caller marks a section as developer-only).
  final Color? color;

  const SectionHeader(this.title, {super.key, this.subtitle, this.color});

  /// The band title's face, public so a hand-built band that cannot be a
  /// [SectionHeader] — one carrying its own controls and geometry — still
  /// takes its title from here rather than restating it and drifting.
  static TextStyle titleStyle(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w900,
            // Text on the surface, not a fill — HaLoColors.onSurfaceAccent,
            // not colorScheme.primary directly.
            color: color ?? HaLoColors.of(context).onSurfaceAccent,
          ) ??
      const TextStyle();

  /// The rule under the title. A hairline, in the title's own accent: it
  /// closes the heading rather than dividing rows, so it is thinner than a
  /// [Divider] and coloured with what it belongs to.
  static const ruleWidth = 1.0;

  static EdgeInsetsGeometry _padding(BuildContext context) =>
      (ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: Space.xxl))
          .add(const EdgeInsets.symmetric(vertical: Space.sm));

  /// This band's height at [width], for a caller that has to state it up
  /// front — a pinned sliver, whose extent is fixed before its child is laid
  /// out. Measured rather than assumed: the title wraps at a large font
  /// scale, and a guessed extent clips it or leaves a gap under it.
  ///
  /// Only for a subtitle-less band; a caller that needs one measures it
  /// itself.
  static double heightFor(BuildContext context, String title, {required double width}) {
    final padding = _padding(context).resolve(Directionality.of(context));
    final painter = TextPainter(
      text: TextSpan(text: title, style: titleStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (width - padding.horizontal).clamp(0.0, double.infinity));
    return painter.height + padding.vertical + ruleWidth;
  }

  /// This band as a header pinned to the top of its own section: it stays put
  /// while that section's rows scroll under it, and is pushed off by the next
  /// section's band. Only meaningful inside a [SliverMainAxisGroup] whose
  /// remaining slivers are the section's rows — pinned to the whole scroll
  /// view, every section's band would stack up at the top.
  static Widget pinned(BuildContext context, String title, {required double width, Color? color}) =>
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedSectionHeader(
          title: title,
          color: color,
          extent: heightFor(context, title, width: width),
        ),
      );

  /// A whole section: this band pinned over [children], which scroll under
  /// it until the next section's band pushes it off. [width] is the
  /// VIEWPORT's, which the band's extent has to be measured against before
  /// its child is laid out.
  ///
  /// Every sliver in the group is a sliver, [children] excepted — they are
  /// boxes, in a [SliverList]. A box handed straight to a viewport fails the
  /// whole list rather than just its own section.
  static Widget section(
    BuildContext context,
    String title, {
    required double width,
    required List<Widget> children,
    Color? color,
  }) =>
      SliverMainAxisGroup(
        slivers: [
          pinned(context, title, width: width, color: color),
          SliverList(delegate: SliverChildListDelegate(children)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final padding = _padding(context).resolve(Directionality.of(context));
    // The inset is spent OUTSIDE the ruled box, not inside it: the rule
    // measures the content it heads, ending where the rows' own text does,
    // rather than running out to the pane's edges the way a filled band
    // (the Settings panel's categories) does.
    return Padding(
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
            Text(title, style: titleStyle(context, color: color)),
            if (subtitle != null) ...[const SizedBox(height: Space.xs), subtitle!],
          ],
        ),
      ),
    );
  }
}

class _PinnedSectionHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final Color? color;
  final double extent;

  const _PinnedSectionHeader({required this.title, required this.color, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      // Painted, unlike the inline heading: pinned, it has its own rows
      // scrolling UNDER it, and a heading with no ground of its own would
      // show them through. The pane's surface is what it stands on — a
      // pinned band only belongs on a surface-grounded list.
      ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(height: extent, child: SectionHeader(title, color: color)),
      );

  @override
  bool shouldRebuild(_PinnedSectionHeader old) =>
      old.title != title || old.color != color || old.extent != extent;
}
