// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The footer: a collapsed one-line bar (tap to expand into a scrollable list
// of every active message/progress item) plus a stack of dismissible
// "post-it" notices overlaid on top of it. Data model lives in the app's
// `StatusBarService` — these widgets only render whatever list they're
// handed, so they stay usable from both the live footer and the read-only
// Recent Notices history screen.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'icon_resolver.dart';
import 'theme.dart';

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

const _collapsedHeight = 28.0;
const _expandedRowHeight = 36.0;
const _expandedVisibleRows = 5;

/// Cap on a progress item's title width when it sits beside the bar
/// (instead of above/below it), so the bar itself still gets the bulk of
/// the row.
const _progressTitleWidth = 96.0;

/// The collapsed/expandable status bar. Shows the most-recently-updated
/// [items] entry collapsed; tap to expand into a scrollable list of at least
/// [_expandedVisibleRows] rows. Collapses to zero height on every platform
/// when [items] is empty.
class StatusBarFooter extends StatefulWidget {
  final List<StatusBarItemData> items;
  final void Function(String key) onDismiss;

  const StatusBarFooter({super.key, required this.items, required this.onDismiss});

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

    // With no items the footer collapses to nothing, so each screen's own
    // content fills the bottom safe area with its own colour — teal Quick
    // Lookup on Home, the canvas on Settings, the separate split panes in
    // landscape — rather than one footer colour imposed over every screen.
    if (!hasItems) {
      return const SizedBox.shrink();
    }

    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
          // Animates every size change this widget can go through: an item
          // being added/dismissed while collapsed (changes the collapsed
          // row's natural height not at all, but empty<->non-empty toggles
          // between zero height and the bar), and expand/collapse.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.bottomCenter,
            child: expanded ? _buildExpanded(context, foregroundColor) : _buildCollapsed(context, foregroundColor),
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
      height: _collapsedHeight,
      child: last == null
          ? const SizedBox.shrink()
          // Cross-fades whenever the displayed item or item count changes
          // (a message/progress item added or dismissed), rather than
          // snapping the text/pills to their new state instantly.
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Padding(
                key: _collapsedSwitchKey(last),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      if (last.title != null) ...[
                        SizedBox(
                          width: _progressTitleWidth,
                          child: Text(
                            last.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _StatusBarProgressIndicator(item: last, color: foregroundColor)),
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
                    _DismissButton(color: foregroundColor, onPressed: () => widget.onDismiss(last.key)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildExpanded(BuildContext context, Color foregroundColor) {
    final list = widget.items.reversed.toList();
    // Only as tall as the actual item count needs, capped at
    // _expandedVisibleRows (scrollable beyond that) — no reason to reserve
    // 5 rows' worth of height for 1 or 2 items.
    final visibleRows = list.length.clamp(1, _expandedVisibleRows);
    return SizedBox(
      height: _expandedRowHeight * visibleRows,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: list.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: foregroundColor.withValues(alpha: 0.3)),
        itemBuilder: (context, index) => _StatusBarItemRow(
          item: list[index],
          color: foregroundColor,
          onDismiss: () => widget.onDismiss(list[index].key),
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
            '$count',
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

  const _DismissButton({required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.close, size: 14, color: color),
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
    return item.isIndeterminateProgress
        ? LinearProgressIndicator(color: color, backgroundColor: trackColor)
        : LinearProgressIndicator(value: item.progressValue, color: color, backgroundColor: trackColor);
  }
}

class _StatusBarItemRow extends StatelessWidget {
  final StatusBarItemData item;
  final Color color;
  final VoidCallback onDismiss;

  const _StatusBarItemRow({required this.item, required this.color, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _expandedRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(resolveIconName(item.icon), size: 18, color: color),
              const SizedBox(width: 8),
            ],
            if (item.isProgress) ...[
              if (item.title != null) ...[
                SizedBox(
                  width: _progressTitleWidth,
                  child: Text(
                    item.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: _StatusBarProgressIndicator(item: item, color: color)),
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
            _DismissButton(color: color, onPressed: onDismiss),
          ],
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

  const NoticeStack({super.key, required this.notices, required this.onDismiss});

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

  @override
  Widget build(BuildContext context) {
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final footerColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final top = widget.notices.last;
    final second = widget.notices.length > 1 ? widget.notices[widget.notices.length - 2] : null;
    final isDismissingTop = top.key == _dismissingKey;

    return Container(
      width: double.infinity,
      color: footerColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Invisible sizing reference: once the real cards below are
          // `Positioned` (needed for the peek/expand animation), the Stack
          // has no unpositioned child left to size itself from, so this
          // ghost copy of the top card's content establishes its box —
          // which is also how the peeking card ends up the same height as
          // the top one, rather than a fixed decorative sliver. `onDismiss`
          // must be non-null here too so the ghost renders the same close
          // button as the real top card — otherwise it's shorter and the
          // real (Positioned-constrained) card overflows its box.
          Opacity(
            opacity: 0,
            child: IgnorePointer(child: NoticeCard(notice: top, onDismiss: () {})),
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
                  // A no-op `onDismiss` (rather than none) keeps this card's
                  // rendered height identical to the ghost/top cards — see
                  // the ghost's comment above. It's inert either way since
                  // this whole subtree is wrapped in `IgnorePointer`.
                  child: NoticeCard(notice: second, onDismiss: () {}),
                ),
              ),
            ),
          AnimatedPositioned(
            key: ValueKey(top.key),
            duration: _noticeDismissDuration,
            curve: Curves.easeInOut,
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: isDismissingTop,
              child: AnimatedOpacity(
                duration: _noticeDismissDuration,
                opacity: isDismissingTop ? 0 : 1,
                child: NoticeCard(
                  notice: top,
                  onDismiss: () => _startDismiss(top.key),
                ),
              ),
            ),
          ),
        ],
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

  const NoticeCard({super.key, required this.notice, this.onDismiss});

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
                    icon: Icon(Icons.close, size: 18, color: onNotice),
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
