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

import 'format_utils.dart';
import 'icon_resolver.dart';
import 'layout.dart';
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

const _collapsedHeight = 28.0;
const _expandedRowHeight = 36.0;

/// The band `NoticeStack` paints around the card. Vertical chrome the stack
/// costs on top of the card — so when the whole stack is held to a budget
/// smaller than this, the band is what has to give (see `_bandFor`).
const _noticeBandTop = 12.0;
const _noticeBandBottom = 8.0;
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
  /// [NumberKeys.height]: it is fixed chrome, so whatever divides up the
  /// bottom of the window has to spend it before splitting the remainder.
  static const double collapsedHeight = _collapsedHeight;

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
      height: PixelGrid.of(context).snap(_collapsedHeight),
      child: last == null
          ? const SizedBox.shrink()
          : AnimatedSwitcher(
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
              child: Padding(
                key: _collapsedSwitchKey(last),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // Hold the message to the ideal pane width, centered, rather
                // than letting it stretch across a wide window.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: idealPaneWidth),
                    child: Row(
                      children: [
                        if (showGroups)
                          for (final group in _groupByIcon(widget.items))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _IconCountPill(icon: group.key, count: group.value, color: foregroundColor),
                            ),
                        if (last.icon != null) ...[
                          Icon(resolveIconName(last.icon), size: 16, color: foregroundColor),
                          const SizedBox(width: 6),
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
                          const SizedBox(width: 8),
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
                        const SizedBox(width: 4),
                        _DismissButton(
                          color: foregroundColor,
                          onPressed: () => widget.onDismiss(last.key),
                          label: widget.dismissLabel,
                        ),
                      ],
                    ),
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
    final contentHeight = _expandedRowHeight * list.length;
    final cap = maxHeight < _expandedRowHeight ? _expandedRowHeight : maxHeight;
    return SizedBox(
      // Snapped for the same reason as the collapsed bar: this height is what
      // positions the expanded panel's top edge against the content above it.
      height: PixelGrid.of(context).snap(contentHeight.clamp(_expandedRowHeight, cap).toDouble()),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(resolveIconName(icon), size: 11, color: color),
            const SizedBox(width: 3),
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
      icon: Icon(Icons.close, size: 14, color: color, semanticLabel: label),
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
      height: _expandedRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // Same ideal-width, centered treatment as the collapsed row.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: idealPaneWidth),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(resolveIconName(item.icon), size: 18, color: color),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
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
                const SizedBox(width: 4),
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
  /// it without knowing these internals — and when it tried, the stack quietly
  /// overran a tight budget by the whole band. Below [_noticeBandHeight] the
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
    return EdgeInsets.fromLTRB(12, _noticeBandTop * scale, 12, _noticeBandBottom * scale);
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
              Opacity(
                opacity: 0,
                child: IgnorePointer(child: _capHeight(context, NoticeCard(notice: top, onDismiss: () {}, dismissLabel: widget.dismissLabel))),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.icon != null) ...[
                  Icon(resolveIconName(notice.icon), size: 18, color: onNotice),
                  const SizedBox(width: 8),
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
                    icon: Icon(Icons.close, size: 18, color: onNotice, semanticLabel: dismissLabel),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    mouseCursor: SystemMouseCursors.click,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            MarkdownBody(
              data: notice.text,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(color: onNotice),
              ),
            ),
            if (notice.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final action in notice.actions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
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
