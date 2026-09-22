// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'spacing.dart';

/// The selected/unselected chrome shared by this app's hand-rolled tab
/// strips — [DockLayoutView]'s `_DockTab` and operation_view.dart's narrow
/// tab bar both build a "Material tab" themselves instead of a stock
/// [TabBar] (which always splits its width evenly across tabs, wrong for
/// either: dock tabs share a scrollable strip, the narrow bar needs one
/// asymmetric width to leave room for a trailing button). Sharing this piece
/// keeps the two from silently diverging on it — label-color resolution,
/// the selection indicator, and the `Semantics(role: tab)` a screen reader
/// needs to announce it as a tab at all.
class TabChrome extends StatelessWidget {
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget Function(BuildContext context, Color labelColor) builder;

  /// The selection indicator's thickness, shared by every tab strip in the
  /// app — the two hand-rolled ones through [TabChrome] and the wide split's
  /// stock `TabBar` through its `indicatorWeight`. One value, because the
  /// strips abut and are all one [LayoutDensity] chrome height.
  static const double defaultIndicatorWidth = 3;

  final double indicatorWidth;
  final EdgeInsetsGeometry padding;

  /// Whether a selected tab shows the indicator at all. Off for a caller that
  /// marks selection some other way and would otherwise get two marks that
  /// contradict each other — the dock's editing mode outlines the showing tab
  /// and leaves its BOTTOM open, so a line across exactly there closes the
  /// one gap the whole shape is built around.
  final bool showIndicator;

  const TabChrome({
    super.key,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    required this.builder,
    this.indicatorWidth = defaultIndicatorWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.lg),
    this.showIndicator = true,
  });

  /// The bottom-border selection indicator, on its own so a caller that
  /// needs the same tab chrome without TabChrome's own InkWell/Semantics —
  /// e.g. a non-interactive drag placeholder — can still match it exactly.
  static BoxDecoration indicatorDecoration({
    required bool selected,
    required Color labelColor,
    required TabBarThemeData tabTheme,
    double indicatorWidth = defaultIndicatorWidth,
  }) {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(color: selected ? (tabTheme.indicatorColor ?? labelColor) : Colors.transparent, width: indicatorWidth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabTheme = theme.tabBarTheme;
    final labelColor = (selected ? tabTheme.labelColor : tabTheme.unselectedLabelColor) ?? theme.colorScheme.onPrimary;
    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        overlayColor: tabTheme.overlayColor,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // foregroundDecoration, not decoration: a BoxDecoration BORDER
          // insets the child, so on `decoration` the indicator took its width
          // off whatever the tab holds — and a tab's trailing IconButton then
          // renders that much under the strip's own height, below the tap
          // target the strip was sized to guarantee. Painted in front, over
          // an already-laid-out child, it costs no height at all. Same idiom
          // and same reason as `qso_list.dart`'s day-header rule.
          foregroundDecoration: indicatorDecoration(
            selected: selected && showIndicator,
            labelColor: labelColor,
            tabTheme: tabTheme,
            indicatorWidth: indicatorWidth,
          ),
          padding: padding,
          child: builder(context, labelColor),
        ),
      ),
    );
  }
}
