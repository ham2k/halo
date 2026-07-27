// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The selected/unselected chrome shared by this app's hand-rolled tab
/// strips — [DockLayoutView]'s `_DockTab` and operation_view.dart's narrow
/// tab bar both build a "Material tab" themselves instead of a stock
/// [TabBar] (which always splits its width evenly across tabs, wrong for
/// either: dock tabs share a scrollable strip, the narrow bar needs one
/// asymmetric width to leave room for a trailing button). Sharing this piece
/// keeps the two from silently diverging on it — label-color resolution,
/// the selection indicator, and the `Semantics(role: tab)` a screen reader
/// needs to announce it as a tab at all, which neither had before.
class TabChrome extends StatelessWidget {
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget Function(BuildContext context, Color labelColor) builder;
  final double indicatorWidth;
  final EdgeInsetsGeometry padding;

  const TabChrome({
    super.key,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    required this.builder,
    this.indicatorWidth = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  /// The bottom-border selection indicator, on its own so a caller that
  /// needs the same tab chrome without TabChrome's own InkWell/Semantics —
  /// e.g. a non-interactive drag placeholder — can still match it exactly.
  static BoxDecoration indicatorDecoration({
    required bool selected,
    required Color labelColor,
    required TabBarThemeData tabTheme,
    double indicatorWidth = 3,
  }) {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: selected ? (tabTheme.indicatorColor ?? labelColor) : Colors.transparent,
          width: indicatorWidth,
        ),
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
          decoration: indicatorDecoration(
            selected: selected,
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
