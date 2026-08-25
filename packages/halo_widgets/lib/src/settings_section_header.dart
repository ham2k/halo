// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'spacing.dart';
import 'theme.dart';

/// The band that heads a section of settings — every settings panel's, and
/// [FormRenderer]'s `style: 'section'` header, so a hand-built panel and a
/// declared one cannot drift apart.
///
/// The same ground the Operation Setup sheet's sections take. FULL-BLEED to
/// the pane's edges, with the row inset spent inside it: inset to match the
/// rows instead, a band reads as one highlighted row rather than as the start
/// of a section. The inset comes from the ambient `ListTileTheme` — the same
/// one every settings row takes its content inset from — so a band and the
/// rows under it line up wherever the pane puts them.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  /// Under the title, in the ordinary body face — for a section that needs a
  /// line of explanation before its rows.
  final Widget? subtitle;

  /// Overrides the accent the title is drawn in (the dev-mode orange, where a
  /// caller marks a section as developer-only).
  final Color? color;

  const SettingsSectionHeader(this.title, {super.key, this.subtitle, this.color});

  static TextStyle _titleStyle(BuildContext context, Color? color) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w900,
            // Text on the surface, not a fill — HaLoColors.onSurfaceAccent,
            // not colorScheme.primary directly.
            color: color ?? HaLoColors.of(context).onSurfaceAccent,
          ) ??
      const TextStyle();

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
      text: TextSpan(text: title, style: _titleStyle(context, null)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (width - padding.horizontal).clamp(0.0, double.infinity));
    return painter.height + padding.vertical;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: _padding(context),
      color: haloDialogBandColorAt(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(context, color)),
          if (subtitle != null) ...[const SizedBox(height: Space.xs), subtitle!],
        ],
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
      SizedBox(height: extent, child: SettingsSectionHeader(title, color: color));

  @override
  bool shouldRebuild(_PinnedSectionHeader old) =>
      old.title != title || old.color != color || old.extent != extent;
}
