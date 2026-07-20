// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's one dialog shell. Every dialog is a banded header and footer in
// the same colour a Modal Pane's chrome uses ([haloDialogBandColor]) wrapped
// around a ColorScheme.surface content area — near-white in light mode,
// near-black in dark — so the whole family reads alike instead of each dialog
// being one flat card in whatever Material picked.
//
// Pair it with `showHaloDialog`, which applies the shared size box
// (`haloDialogConstraints`). The content area is what scrolls when a dialog
// outgrows that box, so the header and footer stay pinned.

import 'package:flutter/material.dart';

import 'theme.dart';

/// The banded header shared by [HaloDialog] and Modal Panes, so the two can't
/// drift apart: the view-header type (the AppBar's own title style, recoloured
/// for the band — its `onPrimary` would be invisible here) at a view header's
/// height, growing only if the title wraps or carries a subtitle.
///
/// [trailing] is for a pane's close button; dialogs pass none.
class HaloDialogHeader extends StatelessWidget {
  final Widget? title;
  final Widget? trailing;

  const HaloDialogHeader({super.key, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: theme.appBarTheme.toolbarHeight ?? kToolbarHeight,
      ),
      child: Padding(
        // Horizontal only: the minHeight above sets the height, and a close
        // button's 48pt tap target already fills it — adding vertical padding
        // on top pushed the header to 72. Tighter on the trailing edge when a
        // button lives there, since its tap target supplies that inset.
        padding: EdgeInsets.only(left: 24, right: trailing == null ? 24 : 12),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style:
                    (theme.appBarTheme.titleTextStyle ??
                            theme.textTheme.headlineSmall ??
                            const TextStyle())
                        .copyWith(color: theme.colorScheme.onSurface),
                child: title ?? const SizedBox.shrink(),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class HaloDialog extends StatelessWidget {
  /// The header band's content — usually a plain `Text`; it picks up the
  /// dialog title style, so call sites don't restate it.
  final Widget? title;

  final Widget? content;

  /// The footer band's buttons, laid out end-aligned and wrapping when narrow.
  final List<Widget> actions;

  /// Whether [content] is wrapped in a scroll view. Turn OFF for content that
  /// scrolls itself (a ListView, or its own SingleChildScrollView) — nesting
  /// two scrollables on the same axis fails to lay out.
  final bool scrollable;

  final EdgeInsetsGeometry? contentPadding;

  /// Take the full [maxDialogWidth] instead of [compactDialogWidth]. For
  /// dialogs that carry real content — forms, pickers, filter panels, prose —
  /// rather than a prompt and two buttons.
  final bool wide;

  const HaloDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.scrollable = true,
    this.contentPadding,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final padding = contentPadding ?? const EdgeInsets.fromLTRB(24, 20, 24, 20);

    Widget? body;
    if (content != null) {
      // Material, not ColoredBox: ListTiles and other InkWell content paint
      // their splashes on the nearest Material ancestor, and a plain
      // ColoredBox over it would hide them (Flutter asserts on exactly that).
      body = Material(
        color: colors.surface,
        child: scrollable
            ? SingleChildScrollView(padding: padding, child: content)
            : Padding(padding: padding, child: content),
      );
    }

    return Dialog(
      // The card colour IS the band colour: the header and footer are just
      // this showing around the surface-coloured content.
      backgroundColor: haloDialogBandColor(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      // A dialog takes its whole allowed width rather than shrink-wrapping:
      // `stretch` is what spans the bands across the card, and it claims the
      // width to do so. (True shrink-wrapping would need IntrinsicWidth, which
      // throws on content holding a shrink-wrapping viewport — several dialogs
      // have ListViews.) So the width is chosen here instead: compact for
      // prompts, the full cap for content-carrying dialogs.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? maxDialogWidth : compactDialogWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) HaloDialogHeader(title: title),
            // Flexible, not Expanded: a short dialog still shrink-wraps.
            if (body != null) Flexible(child: body),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 4,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
