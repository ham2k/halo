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

import 'settings_list.dart';
import 'spacing.dart';
import 'theme.dart';

/// The banded header shared by [HaloDialog] and Modal Panes, so the two can't
/// drift apart: the view-header type (the AppBar's own title style, recoloured
/// for the band — its `onPrimary` would be invisible here) at a view header's
/// height, growing only if the title wraps or carries a subtitle.
///
/// [trailing] is for a pane's close button; dialogs pass none.
class HaloDialogHeader extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? trailing;

  const HaloDialogHeader({super.key, this.leading, this.title, this.trailing});

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
        // on top pushes the header to 72. Tighter on the leading/trailing edge
        // when a button lives there, since its tap target supplies that inset.
        padding: EdgeInsets.only(
          left: leading == null ? 24 : 12,
          right: trailing == null ? 24 : 12,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Space.md),
            ],
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
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The gap between [haloDialogFooterRow]'s [cancel] and the primary action,
/// against the [Space.md] separating every other pair of buttons.
///
/// This is the app's one deliberate divergence from Material's dialog
/// footer, which packs the dismissive and confirming actions together with
/// uniform spacing (see docs/design/user-interface.md §Dialogs). A logging
/// operator works this footer at speed, often one-handed on a tablet in the
/// field, and Cancel discards what they just typed — three times the normal
/// gap is what keeps a mis-aimed tap on Save from landing on Cancel instead.
/// Pinning Cancel to the opposite edge would separate them further still, at
/// the cost of the grouping Material's convention depends on.
const double haloDialogCancelGap = Space.xxl;

/// The single footer layout for every modal surface in the app — plain
/// dialogs ([HaloDialog]), form dialogs and Modal Panes alike. One
/// implementation rather than a convention each footer follows on its own.
/// Duplicating the layout is what lets the copies drift: a slot added to one
/// (`destructive`, `secondary`) is absent from the other, and the dialogs
/// built on that one improvise it into [actions] instead.
///
/// Four roles, laid out to Material's end-aligned convention:
///
/// * [destructive] — alone at the LEADING edge, as far from the primary
///   action as the row allows. This is the position Material gives its
///   `neutral` button. A verb that destroys something the operator has
///   already made does not belong next to the one that saves it.
/// * [secondary] — trailing group, leftmost. Something else to DO with the
///   thing being edited, as opposed to a way out of the dialog.
/// * [cancel] — trailing group, immediately left of [actions], separated
///   from them by [haloDialogCancelGap].
/// * [actions] — the trailing edge. The primary/confirm action, normally one
///   `FilledButton`.
///
/// The trailing slots go through an [OverflowBar]: this footer can carry four
/// verbs at once (the equipment editor's Cancel/Remove/Report/Save) on a pane
/// that IS the screen on a phone, in a language that spells none of them
/// shortly, at a font scale of up to 1.90. A [Row] overflows rather than
/// shrinking, and an overflowing footer paints red stripes across the primary
/// action; the bar stacks its buttons instead, trailing edge aligned so the
/// primary stays where the thumb expects it.
///
/// [actions] is deliberately NOT wrapped in [Flexible], unlike the slots
/// before it: whatever else gets clipped, the dialog's own action stays
/// readable.
Widget haloDialogFooterRow({
  Widget? cancel,
  Widget? destructive,
  Widget? secondary,
  List<Widget> actions = const [],
}) {
  // The trailing buttons are the OverflowBar's OWN children, not a Row handed
  // to it as one child. An OverflowBar decides to stack by summing its
  // children's LAID-OUT sizes (`overflow_bar.dart`'s performLayout), and a Row
  // clamps itself to the incoming maxWidth however far its contents overflow —
  // so a grouped Row reports "I fit" while painting red stripes, and the
  // stacking fallback never runs. Given the buttons directly, the bar measures
  // each one and stacks when the set of them genuinely does not fit.
  return Row(
    // start, not the Row default of center: once the trailing buttons stack,
    // destructive lines up with the first of them rather than centering
    // against the whole stacked block.
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Its natural width, not `Flexible`: a Flexible beside the Expanded
      // below competes with it for flex share, so a single short verb would
      // reserve half the footer and force the trailing buttons to stack with
      // 300pt sitting unused.
      if (destructive != null) ...[
        destructive,
        const SizedBox(width: Space.md),
      ],
      Expanded(
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: Space.md,
          overflowSpacing: Space.md,
          children: [
            ?secondary,
            if (cancel != null)
              // The deliberate gap, as padding rather than a sibling spacer:
              // the bar's own `spacing` is uniform, and a spacer child would
              // become a stray empty row once the buttons stack. Only when
              // something follows — a cancel-only footer must land on the same
              // trailing edge as a primary-only one, not a gap short of it.
              actions.isEmpty
                  ? cancel
                  : Padding(
                      padding: const EdgeInsets.only(right: haloDialogCancelGap - Space.md),
                      child: cancel,
                    ),
            ...actions,
          ],
        ),
      ),
    ],
  );
}

/// [haloDialogFooterRow] in the band a dialog's own footer sits in — for a
/// surface that builds its own chrome instead of being a [HaloDialog]: a
/// modal pane's body, whose footer must stay pinned under a list that
/// scrolls.
///
/// A pane that carries this is closed BY it (`showModalPane`'s
/// `closeButton: false` takes the header's X away), so the way out is one
/// button in the place every dialog puts it rather than two in two places.
Widget haloDialogFooterBand(
  BuildContext context, {
  Widget? cancel,
  Widget? destructive,
  Widget? secondary,
  List<Widget> actions = const [],
}) {
  final theme = Theme.of(context);
  return Container(
    decoration: BoxDecoration(
      // Elevation-corrected for a modal pane's own Material, so a Done-only
      // footer reads the same wherever it appears rather than drifting to a
      // tint of its own.
      color: haloDialogBandColorAt(context),
      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.lg),
        child: haloDialogFooterRow(
          cancel: cancel,
          destructive: destructive,
          secondary: secondary,
          actions: actions,
        ),
      ),
    ),
  );
}

class HaloDialog extends StatelessWidget {
  /// The header band's content — usually a plain `Text`; it picks up the
  /// dialog title style, so call sites don't restate it.
  final Widget? title;

  final Widget? content;

  /// A band between the title and [content] that does NOT scroll with the
  /// rows — a picker naming what those rows are, say. Handed the card's whole
  /// width, unlike [title], which the header band insets: a band here paints
  /// its own inset and reaches the card's edges, the way a settings section
  /// band does.
  final Widget? header;

  /// The footer band's buttons, laid out end-aligned and wrapping when narrow.
  final List<Widget> actions;

  /// The footer's way out — a `TextButton` reading Cancel when there are
  /// pending changes to abandon, or Done when there are not (see
  /// docs/design/user-interface.md §Dialogs for the verb rule).
  ///
  /// Kept a slot of its own rather than being listed first in [actions],
  /// even though it now renders in the same trailing group: only this slot
  /// gets [haloDialogCancelGap] between it and the primary action, so a
  /// Cancel passed through [actions] lands flush against Save with nothing
  /// separating them. `dialog_footer_convention_test.dart` fails the build
  /// when that happens.
  final Widget? cancel;

  /// A verb that destroys what the operator is looking at. Rendered alone at
  /// the leading edge, as far from [actions] as the footer allows — never in
  /// [actions] beside the primary.
  final Widget? destructive;

  /// Something else to DO with the thing being edited, as opposed to a way
  /// out of the dialog. Sits in the trailing group, left of [cancel].
  final Widget? secondary;

  /// Whether [content] is wrapped in a scroll view. Turn OFF for content that
  /// scrolls itself (a ListView, or its own SingleChildScrollView) — nesting
  /// two scrollables on the same axis fails to lay out.
  final bool scrollable;

  final EdgeInsetsGeometry? contentPadding;

  /// Take the full [maxDialogWidth] instead of [compactDialogWidth]. For
  /// dialogs that carry real content — forms, pickers, filter panels, prose —
  /// rather than a prompt and two buttons.
  final bool wide;

  /// Whether [content] is a settings-shaped LIST rather than dialog prose.
  ///
  /// A list dialog spends no horizontal padding of its own: its rows run to
  /// the card's edges and inset their contents instead, off the
  /// [SettingsList] this wraps them in — the same rule the settings panels
  /// follow (docs/design/user-interface.md § Settings lists), so a row
  /// background, a divider and a [SectionHeader] band reach the same edge
  /// wherever the operator meets them. Padded like prose, the rows float in
  /// a gutter and the bands stop short of the card.
  ///
  /// A caller that states its own [contentPadding] keeps it — only the
  /// padding DEFAULT defers. The [SettingsList] wrapper goes on either way,
  /// since that is what the rows read their inset from.
  final bool list;

  const HaloDialog({
    super.key,
    this.title,
    this.content,
    this.header,
    this.actions = const [],
    this.cancel,
    this.destructive,
    this.secondary,
    this.scrollable = true,
    this.contentPadding,
    this.wide = false,
    this.list = false,
  });

  /// A list dialog publishes the settings row inset its rows read from; any
  /// other dialog is put back to the row theme it would have with no ancestor
  /// `ListTileTheme` at all — the app theme's, which is what every consumer's
  /// own fallback is written against.
  ///
  /// Not an inherited value, deliberately: `showDialog` CAPTURES the themes in
  /// force where it was called and re-installs them inside the route, so a
  /// dialog opened from a settings pane inherits that pane's row inset —
  /// which carries the pane's centring offset (`settingsRowCentering`),
  /// hundreds of pixels on a wide window. Left to inherit, a `ListTile` in
  /// the dialog indents its contents by it and its title wraps to a letter a
  /// line.
  ///
  /// Restated rather than merged, and a bare value rather than a number of
  /// our own: a dialog's rows have to land where they do when the same dialog
  /// is opened from anywhere else, and the consumers disagree about what "no
  /// inset" means — `SectionHeader` reads Space.xxl, `FormRenderer`'s rows
  /// zero, a plain `ListTile` Material's 16. Naming one of those here would
  /// move the other two in every dialog in the app.
  Widget _wrapContent(BuildContext context, Widget content) => list
      ? SettingsList(child: content)
      : ListTileTheme(data: Theme.of(context).listTileTheme, child: content);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final padding = contentPadding ??
        (list
            ? const EdgeInsets.symmetric(vertical: Space.md)
            : const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl));

    Widget? body;
    if (content != null) {
      // Material, not ColoredBox: ListTiles and other InkWell content paint
      // their splashes on the nearest Material ancestor, and a plain
      // ColoredBox over it would hide them (Flutter asserts on exactly that).
      body = Material(
        color: colors.surface,
        child: scrollable
            ? SingleChildScrollView(padding: padding, child: _wrapContent(context, content!))
            : Padding(padding: padding, child: _wrapContent(context, content!)),
      );
    }

    return Dialog(
      // The card colour IS the band colour: the header and footer are just
      // this showing around the surface-coloured content.
      backgroundColor: haloDialogBandColor(context),
      shadowColor: haloDialogShadowColor,
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
            ?header,
            // Flexible, not Expanded: a short dialog still shrink-wraps.
            if (body != null) Flexible(child: body),
            if (actions.isNotEmpty || cancel != null || destructive != null || secondary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.lg),
                child: haloDialogFooterRow(
                  cancel: cancel,
                  destructive: destructive,
                  secondary: secondary,
                  actions: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
