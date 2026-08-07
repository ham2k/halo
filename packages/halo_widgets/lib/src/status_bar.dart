// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The footer: a collapsed one-line bar (tap to expand into a scrollable list
// of every active message/progress item) plus a stack of dismissible
// "post-it" notices overlaid on top of it. Data model lives in the app's
// `StatusBarService` — these widgets only render whatever list they're
// handed, so they stay usable from both the live footer and the read-only
// Recent Notices history screen.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'density.dart';
import 'format_utils.dart';
import 'icon_resolver.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'spacing.dart';
import 'theme.dart';
import 'ui_scale.dart';

/// One row in the footer: a transient message or progress bar. Mirrors the
/// app's `StatusBarItem` without depending on it, so this package doesn't
/// need to know about the app's service layer.
class StatusBarItemData {
  final String key;
  final String? icon;
  final String? title;
  final String? text;
  final double? progressValue;
  final bool isIndeterminateProgress;

  const StatusBarItemData({
    required this.key,
    this.icon,
    this.title,
    this.text,
    this.progressValue,
    this.isIndeterminateProgress = false,
  });

  bool get isProgress => isIndeterminateProgress || progressValue != null;
}

class StatusBarActionData {
  final String label;
  final VoidCallback onTap;

  const StatusBarActionData({required this.label, required this.onTap});
}

class StatusBarNoticeData {
  final String key;
  final String? icon;
  final String? title;
  final String text;
  final List<StatusBarActionData> actions;
  final DateTime createdAt;

  const StatusBarNoticeData({
    required this.key,
    this.icon,
    this.title,
    required this.text,
    this.actions = const [],
    required this.createdAt,
  });
}

/// The share of the window either of these may take when no caller supplies a
/// budget. Only honest when the widget owns the screen; the app always passes
/// a budget instead, because down there it is sharing the window with the
/// numbers row and the keyboard — see the `maxHeight` parameters.
const _windowFraction = 0.4;

/// The band `NoticeStack` paints around the card. Vertical chrome the stack
/// costs on top of the card — so when the whole stack is held to a budget
/// smaller than this, the band is what has to give (see `_bandFor`).
const _noticeBandTop = Space.lg;
const _noticeBandBottom = Space.md;
const _noticeBandHeight = _noticeBandTop + _noticeBandBottom;

/// A progress item splits its row evenly: the title takes the left half and
/// the bar the right half, so the bar never spans more than half the message.
const _progressBarFlex = 1;
const _progressTitleFlex = 1;

/// The collapsed/expandable status bar. Shows the most-recently-updated
/// [items] entry collapsed; tap to expand into a scrollable list, capped at
/// [maxExpandedHeight] — or 40% of the screen when no caller sets one.
/// Collapses to zero height on every platform when [items] is empty.
class StatusBarFooter extends StatefulWidget {
  /// The footer's height with its list collapsed — what it takes whenever
  /// there is anything to show at all. Public for the same reason as
  /// [NumberKeys.heightOf]: it is fixed chrome, so whatever divides up the
  /// bottom of the window has to spend it before splitting the remainder.
  static double collapsedHeightOf(BuildContext context) => LayoutDensity.metricsOf(context).statusBarCollapsed;

  final List<StatusBarItemData> items;
  final void Function(String key) onDismiss;

  /// Accessible name for an item's dismiss button — it is icon-only, and the
  /// app has no hover tooltips (docs/design/user-interface.md). English
  /// default so the package stays i18n-free; the app passes a translated
  /// value.
  final String dismissLabel;

  /// How tall the EXPANDED list may grow before it scrolls. Same contract as
  /// [NoticeStack.maxHeight]: null means a fraction of the window, which only
  /// holds when nothing else is competing for the bottom of it.
  final double? maxExpandedHeight;

  const StatusBarFooter({
    super.key,
    required this.items,
    required this.onDismiss,
    this.maxExpandedHeight,
    this.dismissLabel = 'Dismiss',
  });

  @override
  State<StatusBarFooter> createState() => _StatusBarFooterState();
}

class _StatusBarFooterState extends State<StatusBarFooter> {
  bool _expanded = false;

  // AnimatedSwitcher requires each transition's key to be unique for as long
  // as the outgoing child is still animating out — reusing one throws a
  // duplicate-key error. Deriving the key straight from `(last.key,
  // items.length)` isn't safe: both can revert to a prior value within one
  // 200ms transition (e.g. two data-file syncs finishing back-to-back flips
  // the count 2 -> 3 -> 2), so a later build can mint a key identical to one
  // still mid-exit-animation. A monotonically increasing generation, bumped
  // only when the identity actually changes, is never reused.
  String? _lastSwitchIdentity;
  int _switchGeneration = 0;

  Key _collapsedSwitchKey(StatusBarItemData? last) {
    final identity = last == null ? null : '${last.key}|${widget.items.length}';
    if (identity != _lastSwitchIdentity) {
      _lastSwitchIdentity = identity;
      _switchGeneration++;
    }
    return ValueKey(_switchGeneration);
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.items.isNotEmpty;
    // A single item has nothing more to show expanded — the expanded list
    // would just be that same one row in a taller box — so there's nothing
    // to toggle.
    final canExpand = widget.items.length > 1;
    final theme = Theme.of(context);
    final expanded = _expanded && canExpand;
    final backgroundColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;

    // ONE semantics node for the whole footer, outside every switcher below so
    // that it is present even while the bar is empty, and carrying the message
    // as a LABEL that changes rather than as nodes that come and go.
    //
    // Load-bearing on web, not a nicety. The engine gives each semantics node
    // a DOM element chosen by its role, and disposes that element when the
    // role changes ("Role changed. This should be avoided as much as
    // possible" — semantics.dart's own words). The framework recycles
    // SemanticsNodes as the tree churns, so a footer that creates and destroys
    // nodes on every item frees them to be handed to some other widget — and
    // when the node being reused is the one hosting a focused TEXT FIELD, the
    // engine disposes its `<input>` and the operator's keystrokes stop
    // arriving mid-word.
    //
    // What this node fixes is the COLLAPSED bar, which is what churns during a
    // sync — the row it animates is wrapped in `ExcludeSemantics` and says
    // nothing, and this says it instead. Two paths below still create and
    // destroy nodes and are deliberately left alone: the expanded list
    // (`_buildExpanded`, only up while the operator holds it open, and its
    // rows are content a screen reader needs), and the empty-to-active
    // switcher, which takes the Material/InkWell/dismiss nodes with it when
    // the bar empties. Both are narrower than the per-item churn was; neither
    // is nothing.
    return Semantics(
      container: true,
      // Progress ticks would narrate several times a second; a message is
      // worth announcing once.
      liveRegion: _announceable,
      label: _semanticsLabel,
      child: _visuals(context, hasItems, canExpand, expanded, backgroundColor, foregroundColor),
    );
  }

  /// What assistive tech is told the footer currently says. Empty while there
  /// is nothing to report — an empty label on a node that stays put, rather
  /// than a node that goes away.
  String get _semanticsLabel {
    if (widget.items.isEmpty) return '';
    final last = widget.items.last;
    return last.title ?? last.text ?? '';
  }

  /// Whether the current message is worth announcing. A progress item updates
  /// several times a second and would talk over everything else.
  bool get _announceable => widget.items.isNotEmpty && !widget.items.last.isProgress;

  /// Everything the operator SEES — free to animate however it likes, since
  /// none of it reaches the semantics tree (see [build]).
  Widget _visuals(
    BuildContext context,
    bool hasItems,
    bool canExpand,
    bool expanded,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          reverseDuration: const Duration(milliseconds: 200),
          switchInCurve: Curves.fastOutSlowIn,
          switchOutCurve: Curves.fastOutSlowIn,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 1.0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          child: !hasItems
              ? const SizedBox(key: ValueKey('footer_empty'), width: double.infinity, height: 0)
              : Material(
                  key: const ValueKey('footer_active'),
                  color: backgroundColor,
                  child: SafeArea(
                    top: false,
                    child: InkWell(
                      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.fastOutSlowIn,
                        alignment: Alignment.bottomCenter,
                        child: expanded ? _buildExpanded(context, foregroundColor) : _buildCollapsed(context, foregroundColor),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, Color foregroundColor) {
    final theme = Theme.of(context);
    final last = widget.items.isNotEmpty ? widget.items.last : null;
    final showGroups = widget.items.length > 1;

    return SizedBox(
      // Snapped: the bar sits against the content above it in a different
      // color, and its height is what places that boundary (the bar itself is
      // pinned to the window's bottom edge, which is always on-grid). See
      // PixelGrid — 28 × 0.85 × 2.0 is 47.6 device px, a hairline seam.
      height: PixelGrid.of(context).snap(StatusBarFooter.collapsedHeightOf(context)),
      child: last == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              // Hold the message to the ideal pane width, centered, rather
              // than letting it stretch across a wide window.
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: idealPaneWidth),
                  child: Row(
                    // Stretch, so the switcher's child is as tall as the bar
                    // rather than as tall as its text. The slide travels the
                    // child's height: left to size itself the outgoing message
                    // crossfades nearly in place instead of sliding out under
                    // the bar's clip, which is a visual change this
                    // semantics-only restructuring has no business making.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Everything that changes with the item, and the only
                      // part that animates. Excluded from semantics: the
                      // switcher builds a fresh subtree per item and keeps the
                      // outgoing one mounted through the transition, so its
                      // nodes would be created and destroyed several times a
                      // second — which is exactly what steals a focused text
                      // field's node (see build()). The message itself is
                      // still announced, by the one stable node up there.
                      Expanded(
                        child: ExcludeSemantics(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(opacity: animation, child: child),
                              );
                            },
                            child: Row(
                              key: _collapsedSwitchKey(last),
                              children: [
                                if (showGroups)
                                  for (final group in _groupByIcon(widget.items))
                                    Padding(
                                      padding: const EdgeInsets.only(right: Space.xs),
                                      child: _IconCountPill(icon: group.key, count: group.value, color: foregroundColor),
                                    ),
                                if (last.icon != null) ...[
                                  Icon(resolveIconName(last.icon), size: 16, color: foregroundColor),
                                  const SizedBox(width: Space.sm),
                                ],
                                if (last.isProgress) ...[
                                  Expanded(
                                    flex: _progressTitleFlex,
                                    child: Text(
                                      last.title ?? last.text ?? '',
                                      textAlign: TextAlign.left,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
                                    ),
                                  ),
                                  const SizedBox(width: Space.md),
                                  Expanded(
                                    flex: _progressBarFlex,
                                    child: _StatusBarProgressIndicator(item: last, color: foregroundColor),
                                  ),
                                ] else
                                  Expanded(
                                    child: Text(
                                      last.title ?? last.text ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      // Hoisted OUT of the switcher above, deliberately. It is
                      // the one control down here, it exists in every state,
                      // and outside the switcher its element — and so its
                      // semantics node — survives every item change instead of
                      // being rebuilt with the row.
                      // Centred rather than stretched: the row's stretch is
                      // for the switcher's travel, and the button sizes itself.
                      Center(
                        child: _DismissButton(
                          color: foregroundColor,
                          onPressed: () => widget.onDismiss(last.key),
                          label: widget.dismissLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildExpanded(BuildContext context, Color foregroundColor) {
    final list = widget.items.reversed.toList();
    // Only as tall as the actual item count needs, but never more than the
    // caller's cap (or 40% of the screen absent one), scrollable beyond that.
    //
    // The floor below is a real exception to that cap: one row, so a single
    // item still shows. A caller whose budget is tighter than a row gets a
    // footer taller than it allowed — the alternative is an expanded list with
    // nothing legible in it.
    final maxHeight = widget.maxExpandedHeight ?? MediaQuery.sizeOf(context).height * _windowFraction;
    final rowHeight = LayoutDensity.metricsOf(context).statusBarRow;
    final contentHeight = rowHeight * list.length;
    final cap = maxHeight < rowHeight ? rowHeight : maxHeight;
    return SizedBox(
      // Snapped for the same reason as the collapsed bar: this height is what
      // positions the expanded panel's top edge against the content above it.
      height: PixelGrid.of(context).snap(contentHeight.clamp(rowHeight, cap).toDouble()),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        itemCount: list.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: foregroundColor.withValues(alpha: 0.3)),
        itemBuilder: (context, index) => _StatusBarItemRow(
          item: list[index],
          color: foregroundColor,
          onDismiss: () => widget.onDismiss(list[index].key),
          dismissLabel: widget.dismissLabel,
        ),
      ),
    );
  }
}

/// Tallies [items] by icon, preserving first-appearance order so the pill
/// row stays stable as items come and go rather than jumping around.
List<MapEntry<String?, int>> _groupByIcon(List<StatusBarItemData> items) {
  final counts = <String?, int>{};
  for (final item in items) {
    counts[item.icon] = (counts[item.icon] ?? 0) + 1;
  }
  return counts.entries.toList();
}

class _IconCountPill extends StatelessWidget {
  final String? icon;
  final int count;
  final Color color;

  const _IconCountPill({required this.icon, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(resolveIconName(icon), size: 11, color: color),
            const SizedBox(width: Space.xs),
          ],
          Text(
            formatNumber(count),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;
  final String label;

  const _DismissButton({required this.color, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(MdiIcons.close, size: 14, color: color, semanticLabel: label),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

class _StatusBarProgressIndicator extends StatelessWidget {
  final StatusBarItemData item;
  final Color color;

  const _StatusBarProgressIndicator({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final trackColor = color.withValues(alpha: 0.3);
    if (item.isIndeterminateProgress) {
      return LinearProgressIndicator(color: color, backgroundColor: trackColor);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: item.progressValue ?? 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (context, val, child) {
        return LinearProgressIndicator(
          value: val,
          color: color,
          backgroundColor: trackColor,
        );
      },
    );
  }
}

class _StatusBarItemRow extends StatelessWidget {
  final StatusBarItemData item;
  final Color color;
  final VoidCallback onDismiss;
  final String dismissLabel;

  const _StatusBarItemRow({
    required this.item,
    required this.color,
    required this.onDismiss,
    required this.dismissLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: LayoutDensity.metricsOf(context).statusBarRow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        // Same ideal-width, centered treatment as the collapsed row.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: idealPaneWidth),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(resolveIconName(item.icon), size: 18, color: color),
                  const SizedBox(width: Space.md),
                ],
                if (item.isProgress) ...[
                  Expanded(
                    flex: _progressTitleFlex,
                    child: Text(
                      item.title ?? item.text ?? '',
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: _progressBarFlex,
                    child: _StatusBarProgressIndicator(item: item, color: color),
                  ),
                ] else
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title != null)
                          Text(
                            item.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: color),
                          ),
                        if (item.text != null)
                          Text(
                            item.text!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: color.withValues(alpha: 0.85)),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: Space.xs),
                _DismissButton(color: color, onPressed: onDismiss, label: dismissLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The stack of dismissible "post-it" notices, overlaid above whatever the
/// [StatusBarFooter] is doing. [notices] is oldest-first; the most recent is
/// drawn fully on top, with the next one peeking a few pixels behind when
/// there's more than one.
class NoticeStack extends StatefulWidget {
  /// The vertical chrome this widget paints around its card, on top of
  /// whatever the card itself needs. Public so that anything reasoning about
  /// the stack's height — a caller's budget, a test's expected viewport —
  /// reads it rather than re-deriving it from the two paddings, which is a
  /// copy that goes stale silently the next time either one moves.
  static const double bandHeight = _noticeBandHeight;

  final List<StatusBarNoticeData> notices;
  final void Function(String key) onDismiss;

  /// Accessible name for each card's dismiss button (see
  /// [StatusBarFooter.dismissLabel]).
  final String dismissLabel;

  /// How tall the **whole stack** may grow — band included — before the card
  /// inside it scrolls. Null falls back to a fraction of the window, which is
  /// right when this owns the screen and wrong when it is sharing the bottom
  /// strip with the footer, the numbers row and the keyboard; there the caller
  /// has a budget and this is how it says so.
  ///
  /// Deliberately the total, not the card. The band is chrome this widget adds
  /// on its own account, so a caller dividing up a fixed strip cannot pay for
  /// it without knowing these internals — a card-only cap quietly overruns a
  /// tight budget by the whole band. Below [_noticeBandHeight] the
  /// band itself gives way, so this is a bound the widget cannot exceed.
  final double? maxHeight;

  const NoticeStack({
    super.key,
    required this.notices,
    required this.onDismiss,
    this.maxHeight,
    this.dismissLabel = 'Dismiss',
  });

  @override
  State<NoticeStack> createState() => _NoticeStackState();
}

const _noticeDismissDuration = Duration(milliseconds: 220);

class _NoticeStackState extends State<NoticeStack> {
  /// Set while the top notice is fading out and the one behind it is
  /// animating into its place; cleared (and [NoticeStack.onDismiss] actually
  /// called) once that transition finishes.
  String? _dismissingKey;

  void _startDismiss(String key) {
    setState(() => _dismissingKey = key);
    Future.delayed(_noticeDismissDuration, () {
      widget.onDismiss(key);
      if (mounted) setState(() => _dismissingKey = null);
    });
  }

  /// The budget for the whole stack: what the caller allowed, or 40% of the
  /// window when it did not say.
  double _stackCap(BuildContext context) =>
      widget.maxHeight ?? MediaQuery.sizeOf(context).height * _windowFraction;

  /// The band actually painted. Normally the full [_noticeBandHeight]; when
  /// the stack's whole budget is smaller than that, the band shrinks with it
  /// rather than pushing the stack past what it was given. Keeping the top and
  /// bottom in proportion means it reads as a tighter band, not a broken one.
  EdgeInsets _bandFor(double cap) {
    final scale = (cap / _noticeBandHeight).clamp(0.0, 1.0);
    return EdgeInsets.fromLTRB(Space.lg, _noticeBandTop * scale, Space.lg, _noticeBandBottom * scale);
  }

  /// Caps a notice card so the card PLUS the band fits the stack's budget,
  /// scrolling its content when it would grow past that. Applied to every card
  /// — including the ghost that sizes the stack — so the whole stack stays
  /// within the limit, which is the property the caller is relying on.
  Widget _capHeight(BuildContext context, Widget card) {
    final cap = _stackCap(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(0.0, cap - _bandFor(cap).vertical)),
      child: SingleChildScrollView(child: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNotices = widget.notices.isNotEmpty;

    final theme = Theme.of(context);
    final footerColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final top = hasNotices ? widget.notices.last : null;
    final second = widget.notices.length > 1 ? widget.notices[widget.notices.length - 2] : null;
    final isDismissingTop = top != null && top.key == _dismissingKey;

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          reverseDuration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 1.0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          child: !hasNotices || top == null
              ? const SizedBox(key: ValueKey('notice_empty'), width: double.infinity, height: 0)
              : Container(
                  key: const ValueKey('notice_active'),
                  width: double.infinity,
                  color: footerColor,
                  padding: _bandFor(_stackCap(context)),
                  // Hold the notice card to the ideal pane width, centered, rather than
                  // letting it stretch across a wide window (the full-width band behind it
                  // stays, matching the footer).
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: idealPaneWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Invisible sizing reference: once the real cards below are
              // `Positioned` (needed for the peek/expand animation), the
              // Stack has no unpositioned child left to size itself from, so
              // this ghost copy of the top card's content establishes its
              // box — which is also how the peeking card ends up the same
              // height as the top one, rather than a fixed decorative sliver.
              // `onDismiss` must be non-null here too so the ghost renders
              // the same close button as the real top card — otherwise it's
              // shorter and the real (Positioned-constrained) card overflows
              // its box.
              //
              // `ExcludeSemantics` states what `Opacity(0)` already achieves
              // (RenderOpacity drops its child's semantics at zero alpha) so
              // that raising the opacity for a fade one day cannot silently
              // publish a duplicate of the notice — and a dead close button —
              // to assistive tech. The peek below is the case that got that
              // wrong.
              ExcludeSemantics(
                child: Opacity(
                  opacity: 0,
                  child: IgnorePointer(child: _capHeight(context, NoticeCard(notice: top, onDismiss: () {}, dismissLabel: widget.dismissLabel))),
                ),
              ),
              if (second != null)
                AnimatedPositioned(
                  key: ValueKey(second.key),
                  duration: _noticeDismissDuration,
                  curve: Curves.easeInOut,
                  left: isDismissingTop ? 0 : 6,
                  top: isDismissingTop ? 0 : 6,
                  right: isDismissingTop ? 0 : -6,
                  bottom: isDismissingTop ? 0 : -6,
                  // A few pixels of card edge showing behind the top one, to
                  // say "there is another". Purely visual, and it must stay
                  // that way: `IgnorePointer` takes it out of hit testing but
                  // NOT out of semantics (`ignoringSemantics` defaults to
                  // null, which reads as false), and at 0.7 opacity the
                  // subtree is not dropped either — so without the exclusion
                  // a screen reader is read the second notice in full, ahead
                  // of the one actually on top, along with a close button
                  // wired to a no-op. It is also churn: the whole card's
                  // worth of nodes appears and vanishes as notices stack, and
                  // freed nodes get recycled onto other widgets — including,
                  // on web, a focused text field, whose `<input>` the engine
                  // then disposes mid-word (see StatusBarFooter.build).
                  //
                  // This does cost something, and it is not only the label:
                  // `NoticeCard` renders `notice.actions` as live buttons, so
                  // a stacked notice's actions become unreachable to assistive
                  // tech until it reaches the top. That is the intended
                  // trade — activating a button on a card sitting visually
                  // behind another is worse than waiting for it to surface —
                  // but it is a trade, not a free silence.
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: _noticeDismissDuration,
                        opacity: isDismissingTop ? 1 : 0.7,
                        // A no-op `onDismiss` (rather than none) keeps this
                        // card's rendered height identical to the ghost/top
                        // cards — see the ghost's comment above. It's inert
                        // either way since this whole subtree is wrapped in
                        // `IgnorePointer`.
                        child: _capHeight(context, NoticeCard(notice: second, onDismiss: () {}, dismissLabel: widget.dismissLabel)),
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                key: ValueKey(top.key),
                duration: _noticeDismissDuration,
                curve: Curves.easeInOut,
                left: 0,
                top: isDismissingTop ? 80 : 0,
                right: 0,
                bottom: isDismissingTop ? -80 : 0,
                child: IgnorePointer(
                  ignoring: isDismissingTop,
                  child: AnimatedOpacity(
                    duration: _noticeDismissDuration,
                    opacity: isDismissingTop ? 0 : 1,
                    child: _capHeight(
                      context,
                      NoticeCard(notice: top, onDismiss: () => _startDismiss(top.key), dismissLabel: widget.dismissLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
}
}

class _NoticeSurface extends StatelessWidget {
  final Widget child;

  const _NoticeSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HaLoColors.of(context).notice,
      elevation: 2,
      child: child,
    );
  }
}

/// The post-it keeps its own paper color in both brightnesses (see
/// [HaLoColors.notice]), so every markdown role has to be pinned to the notice
/// ink rather than inherited: what `fromTheme` derives from the ambient
/// surface is near-white under the dark theme and disappears on the yellow.
///
/// The same constraint binds every CONTROL on a notice, not just its markdown,
/// and it now cuts against the theme's own defaults: a bare `TextButton`,
/// spinner or text field takes [HaLoColors.onSurfaceAccent], which reads at
/// 2.46:1 on this yellow. Anything added to a `NoticeCard` has to pin
/// `onNotice` explicitly the way the action and dismiss buttons below do.
MarkdownStyleSheet _noticeMarkdownStyle(ThemeData theme, Color onNotice) {
  final body = theme.textTheme.bodyMedium?.copyWith(color: onNotice);
  final faint = onNotice.withValues(alpha: 0.08);
  final rule = onNotice.withValues(alpha: 0.3);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    listBullet: body,
    blockquote: body,
    tableBody: body,
    img: body,
    checkbox: body,
    // Color only, never a body-derived style: the builder merges the link
    // style onto its parent, and `merge` takes every non-null field — a
    // fontSize or fontWeight here would override the heading or bold run the
    // link sits inside. No underline either, since without an `onTapLink`
    // these links do nothing; [StatusBarActionData]s are the actionable part.
    a: TextStyle(color: Colors.blue.shade900),
    code: body?.copyWith(
      backgroundColor: faint,
      fontFamily: 'monospace',
      fontSize: theme.textTheme.bodyMedium!.fontSize! * 0.85,
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(color: onNotice),
    h2: theme.textTheme.titleLarge?.copyWith(color: onNotice),
    h3: theme.textTheme.titleMedium?.copyWith(color: onNotice),
    h4: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    h5: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    h6: theme.textTheme.bodyLarge?.copyWith(color: onNotice),
    codeblockDecoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(2)),
    blockquoteDecoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(2)),
    tableBorder: TableBorder.all(color: rule),
    horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(width: 5, color: rule))),
  );
}

/// One notice, as a "post-it" card: icon+title row, markdown body, action
/// buttons. Used both live (dismissible, in [NoticeStack]) and read-only (no
/// [onDismiss]) in the Recent Notices history screen.
class NoticeCard extends StatelessWidget {
  final StatusBarNoticeData notice;
  final VoidCallback? onDismiss;

  /// Accessible name for the dismiss button (see [StatusBarFooter.dismissLabel]).
  final String dismissLabel;

  const NoticeCard({super.key, required this.notice, this.onDismiss, this.dismissLabel = 'Dismiss'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onNotice = HaLoColors.of(context).onNotice;

    return _NoticeSurface(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.icon != null) ...[
                  Icon(resolveIconName(notice.icon), size: 18, color: onNotice),
                  const SizedBox(width: Space.md),
                ],
                if (notice.title != null)
                  Expanded(
                    child: Text(
                      notice.title!,
                      style: theme.textTheme.titleSmall?.copyWith(color: onNotice, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const Spacer(),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(MdiIcons.close, size: 18, color: onNotice, semanticLabel: dismissLabel),
                    onPressed: onDismiss,
                    // The hover/press overlay derives from foregroundColor, so
                    // without this it resolves against the ambient theme and a
                    // near-white state layer washes out on the yellow paper.
                    style: IconButton.styleFrom(foregroundColor: onNotice),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    mouseCursor: SystemMouseCursors.click,
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            MarkdownBody(
              data: notice.text,
              styleSheet: _noticeMarkdownStyle(theme, onNotice),
            ),
            if (notice.actions.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final action in notice.actions)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.md),
                        child: TextButton(
                          onPressed: action.onTap,
                          style: TextButton.styleFrom(foregroundColor: onNotice),
                          child: Text(action.label),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
