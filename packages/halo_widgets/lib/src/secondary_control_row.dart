// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The secondary control row, ported from app-polo's SecondaryExchangePanel:
// a horizontal strip of chips — one per control, built-in (Time, Radio) or
// extension-contributed (POTA's park reference, etc.) — each showing a
// compact summary of its current value. Tapping a chip expands that
// control's input panel above the row; tapping the same chip again
// collapses it. Only one control is expanded at a time, which is what lets
// this scale to many extensions contributing controls without the panel's
// footprint growing — the alternative (every control's inputs always
// visible) is what app-polo moved away from as more activities registered
// logging controls.
//
// Scoped down for v1 versus app-polo's original: no per-user visibility
// settings (every control the caller passes in shows; there's no persisted
// "hide this one" yet) and no drag-reordering. Both can layer onto this
// widget's contract later without changing it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// One control the row can show. Built by the screen/panel that owns the
/// relevant state — some specs wrap a built-in Dart widget (Time, Radio),
/// others wrap an extension-described input (POTA's refList) rendered
/// through the UI catalog. Either way, by the time it reaches this widget
/// it's just an icon, a summary, and a builder — the row doesn't know or
/// care where a control came from.
class SecondaryControlSpec {
  final String key;
  final IconData icon;
  final String summary;
  final WidgetBuilder expandedBuilder;

  const SecondaryControlSpec({
    required this.key,
    required this.icon,
    required this.summary,
    required this.expandedBuilder,
  });
}

class SecondaryControlRow extends StatefulWidget {
  final List<SecondaryControlSpec> controls;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  /// Extra content shown at the end of the chip row (e.g. a DUPE indicator).
  /// It's not a control — it doesn't expand or get selected.
  final Widget? trailing;

  const SecondaryControlRow({
    super.key,
    required this.controls,
    required this.selectedKey,
    required this.onSelect,
    this.trailing,
  });

  @override
  State<SecondaryControlRow> createState() => _SecondaryControlRowState();
}

class _SecondaryControlRowState extends State<SecondaryControlRow> {
  // Anchors the coordinate space used to position the expanded content: its
  // own top-left corner (stable regardless of how wide this widget's
  // shrink-wrapped content ends up being — only its origin matters here),
  // not its rendered width, which is why availableWidth comes from
  // LayoutBuilder's incoming constraints instead (the true width this
  // widget was offered, not whatever it chose to consume).
  final _rowKey = GlobalKey();
  final _expandedKey = GlobalKey();
  final Map<String, GlobalKey> _chipKeys = {};
  double _expandedLeft = 0;
  double _availableWidth = 0;

  GlobalKey _chipKeyFor(String key) => _chipKeys.putIfAbsent(key, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scheduleReposition();
  }

  @override
  void didUpdateWidget(covariant SecondaryControlRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReposition();
  }

  void _scheduleReposition() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  /// Centers the expanded content over the selected chip when there's room;
  /// otherwise hugs whichever edge of the chip it overflowed past, so it
  /// never spills outside the panel. Runs after layout (needs the chip's
  /// and expanded content's actual rendered sizes, which aren't known
  /// during build), so a freshly-selected control briefly renders at its
  /// previous offset before snapping into place one frame later.
  void _reposition() {
    if (!mounted || widget.selectedKey == null) return;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final chipBox = _chipKeys[widget.selectedKey]?.currentContext?.findRenderObject() as RenderBox?;
    final expandedBox = _expandedKey.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null ||
        chipBox == null ||
        expandedBox == null ||
        !rowBox.attached ||
        !chipBox.attached ||
        !expandedBox.attached) {
      return;
    }

    final chipLeft = chipBox.localToGlobal(Offset.zero, ancestor: rowBox).dx;
    final chipWidth = chipBox.size.width;
    final expandedWidth = expandedBox.size.width;
    final availableWidth = _availableWidth.isFinite ? _availableWidth : expandedWidth;
    final maxLeft = math.max(0.0, availableWidth - expandedWidth);

    var left = chipLeft + chipWidth / 2 - expandedWidth / 2;
    if (left < 0) {
      left = chipLeft; // hug the pill's left edge
    } else if (left + expandedWidth > availableWidth) {
      left = chipLeft + chipWidth - expandedWidth; // hug the pill's right edge
    }
    left = left.clamp(0.0, maxLeft);

    if ((left - _expandedLeft).abs() > 0.5) {
      setState(() => _expandedLeft = left);
    }
  }

  @override
  Widget build(BuildContext context) {
    SecondaryControlSpec? selected;
    for (final control in widget.controls) {
      if (control.key == widget.selectedKey) selected = control;
    }
    // The expanded content's own size can change between builds (e.g.
    // switching from Time's fields to Radio's, or DUPE appearing/
    // disappearing next to the chips), so reposition on every build, not
    // just when selectedKey changes; _reposition's own threshold check
    // makes this a no-op once things settle.
    if (selected != null) _scheduleReposition();

    return LayoutBuilder(
      builder: (context, constraints) {
        _availableWidth = constraints.maxWidth;
        return Column(
          key: _rowKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null)
              Padding(
                padding: EdgeInsets.only(left: _expandedLeft, bottom: 4),
                child: Builder(key: _expandedKey, builder: selected.expandedBuilder),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final control in widget.controls) ...[
                    _ControlChip(
                      key: _chipKeyFor(control.key),
                      control: control,
                      selected: control.key == widget.selectedKey,
                      onTap: () => widget
                          .onSelect(control.key == widget.selectedKey ? null : control.key),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ?widget.trailing,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlChip extends StatelessWidget {
  final SecondaryControlSpec control;
  final bool selected;
  final VoidCallback onTap;

  const _ControlChip({
    super.key,
    required this.control,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    // Matches app-polo's LoggerChip: unselected = tertiaryLight fill with
    // onTertiaryContainer text/icon; selected = solid tertiary fill with
    // onTertiary (near-white) text/icon. A rounded-rectangle shape, not
    // Flutter's default full-pill chip — app-polo's chips (react-native-paper
    // Chip, flat mode) are boxy with a modest corner radius.
    final foreground = selected
        ? theme.colorScheme.onTertiary
        : theme.colorScheme.onTertiaryContainer;

    return ChoiceChip(
      avatar: Icon(
        control.icon,
        size: 16 * MediaQuery.textScalerOf(context).scale(1.0),
        color: foreground,
      ),
      label: Text(control.summary, style: TextStyle(color: foreground)),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: poloColors.tertiaryLight,
      selectedColor: theme.colorScheme.tertiary,
      // Material3's ChoiceChip draws a default outline when side is null;
      // app-polo's LoggerChip has none.
      side: BorderSide.none,
      onSelected: (_) => onTap(),
      mouseCursor: SystemMouseCursors.click,
    );
  }
}
