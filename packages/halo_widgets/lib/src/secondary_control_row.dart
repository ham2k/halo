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
// The chip strip itself can be dragged to scroll (desktop mice don't get
// click-drag scrolling by default — only touch/trackpad do, unless
// explicitly opted in), and a caret expands it into a multi-row grid (up to
// 4 rows tall, scrollable beyond that) so every control can be seen at
// once instead of scrolled through one at a time. Show/hide and reordering
// of which controls appear at all lives one level up (LoggingControls owns
// that state and persistence); this widget just renders whatever ordered
// list it's given, plus a settings button the caller wires up to open
// that management UI.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

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

/// Lets mouse click-drag scroll the chip strip, in addition to the
/// touch/trackpad drag Flutter's default behavior already allows.
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}

class SecondaryControlRow extends StatefulWidget {
  final List<SecondaryControlSpec> controls;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  /// Extra content shown at the end of the chip row (e.g. a DUPE indicator).
  /// It's not a control — it doesn't expand or get selected.
  final Widget? trailing;

  /// Opens the show/hide + reorder settings dialog. The gear button is
  /// hidden if this is null.
  final VoidCallback? onOpenSettings;

  /// How far the parent's own horizontal padding insets this widget from
  /// the true edge of the view. The expanded control panel's background
  /// bleeds out by this much on each side so it reaches the view's actual
  /// edges instead of stopping at the parent's padding.
  final double horizontalBleed;

  const SecondaryControlRow({
    super.key,
    required this.controls,
    required this.selectedKey,
    required this.onSelect,
    this.trailing,
    this.onOpenSettings,
    this.horizontalBleed = 0,
  });

  @override
  State<SecondaryControlRow> createState() => _SecondaryControlRowState();
}

class _SecondaryControlRowState extends State<SecondaryControlRow> {
  final _rowKey = GlobalKey();
  final _expandedKey = GlobalKey();
  final Map<String, GlobalKey> _chipKeys = {};

  /// Whether the caret has expanded the strip into a multi-row grid.
  bool _gridExpanded = false;

  /// A single chip's rendered height, measured post-frame from whichever
  /// chip happens to be built first — used to cap the expanded grid at
  /// ~4 rows. Defaults to a reasonable guess (a compact ChoiceChip's actual
  /// height) until the first real measurement lands.
  double _chipHeight = 32;

  /// Where the expanded panel's content sits within its (full-width)
  /// background: a chip in the left quarter of the row aligns the panel
  /// left, one in the right quarter aligns it right, and anything in the
  /// middle half centers the panel *on the chip itself* (not on the whole
  /// row) — computed from the chip's and panel's own measured widths so the
  /// panel visually hangs below the pill that opened it. Defaults to left
  /// until the first post-frame measurement lands.
  Alignment _expandedAlignment = Alignment.centerLeft;

  GlobalKey _chipKeyFor(String key) => _chipKeys.putIfAbsent(key, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant SecondaryControlRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;

    final anyChipBox = widget.controls.isEmpty
        ? null
        : _chipKeys[widget.controls.first.key]?.currentContext?.findRenderObject() as RenderBox?;
    if (anyChipBox != null && anyChipBox.attached) {
      final height = anyChipBox.size.height;
      if (height > 0 && (height - _chipHeight).abs() > 0.5) {
        setState(() => _chipHeight = height);
      }
    }

    if (widget.selectedKey == null) return;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final chipBox = _chipKeys[widget.selectedKey]?.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null || chipBox == null || !rowBox.attached || !chipBox.attached) return;

    final chipLeft = chipBox.localToGlobal(Offset.zero, ancestor: rowBox).dx;
    final chipCenter = chipLeft + chipBox.size.width / 2;
    final availableWidth = rowBox.size.width;

    Alignment alignment;
    if (chipCenter < availableWidth * 0.25) {
      alignment = Alignment.centerLeft;
    } else if (chipCenter > availableWidth * 0.75) {
      alignment = Alignment.centerRight;
    } else {
      // Center the panel on the chip's own position rather than the whole
      // row: solve Align's placement formula for the x that puts the
      // panel's midpoint at chipCenter, using the panel's own measured
      // width (falls back to plain center pending that measurement).
      final expandedBox = _expandedKey.currentContext?.findRenderObject() as RenderBox?;
      final expandedWidth = expandedBox != null && expandedBox.attached ? expandedBox.size.width : null;
      if (expandedWidth == null || expandedWidth >= availableWidth) {
        alignment = Alignment.center;
      } else {
        final x = 2 * (chipCenter - expandedWidth / 2) / (availableWidth - expandedWidth) - 1;
        alignment = Alignment(x.clamp(-1.0, 1.0), 0);
      }
    }
    if (alignment != _expandedAlignment) {
      setState(() => _expandedAlignment = alignment);
    }
  }

  @override
  Widget build(BuildContext context) {
    SecondaryControlSpec? selected;
    for (final control in widget.controls) {
      if (control.key == widget.selectedKey) selected = control;
    }

    final theme = Theme.of(context);
    const spacing = 6.0;
    final chips = [
      for (final control in widget.controls)
        _ControlChip(
          key: _chipKeyFor(control.key),
          control: control,
          selected: control.key == widget.selectedKey,
          onTap: () => widget.onSelect(control.key == widget.selectedKey ? null : control.key),
        ),
      ?widget.trailing,
      if (widget.onOpenSettings != null) _SettingsPill(height: _chipHeight, onTap: widget.onOpenSettings!),
    ];

    return Column(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected case final selected?)
          LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              // Bleeds past the parent's own horizontal padding so the
              // background below reaches the view's true edges instead of
              // stopping short at that padding. OverflowBox (rather than a
              // negative Padding, which Flutter rejects outright) lets a
              // child be wider than the space its parent offered.
              minWidth: 0,
              maxWidth: constraints.maxWidth + widget.horizontalBleed * 2,
              // The Column above sizes to its children (mainAxisSize.min),
              // handing this an unbounded height — deferToChild sizes the
              // OverflowBox to its child's own height instead of trying to
              // fill that infinite constraint.
              fit: OverflowBoxFit.deferToChild,
              child: Container(
                // Same solid color as a selected pill — this is the
                // "extended area" that gets the pill background, not the
                // chip strip itself — full width, flush against the top
                // and sides, with its own regular inner padding around
                // the content.
                width: constraints.maxWidth + widget.horizontalBleed * 2,
                color: theme.colorScheme.tertiary,
                // Horizontal inset matches the pill row's own — that row
                // has no padding of its own, so its chips sit exactly
                // `horizontalBleed` in from the true edge (the parent's own
                // padding, which this panel otherwise bleeds past).
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalBleed, vertical: 8),
                child: Align(
                  alignment: _expandedAlignment,
                  child: Builder(key: _expandedKey, builder: selected.expandedBuilder),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _gridExpanded
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: _chipHeight * 4 + spacing * 3),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: chips,
                        ),
                      ),
                    )
                  : ScrollConfiguration(
                      behavior: _DragScrollBehavior(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final chip in chips) ...[
                              chip,
                              if (chip != chips.last) const SizedBox(width: spacing),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            IconButton(
              tooltip: _gridExpanded ? 'Collapse' : 'Expand',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: HaLoColors.of(context).tertiaryLight.withValues(alpha: 0.5),
              ),
              icon: Icon(_gridExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _gridExpanded = !_gridExpanded),
            ),
          ],
        ),
      ],
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

/// Opens the show/hide + reorder settings dialog. Same pill shape/fill as
/// an unselected control chip (it's never "selected" — it opens a dialog
/// rather than expanding inline), icon-only. Built directly on Material
/// rather than ChoiceChip/ActionChip — Chip's built-in label padding keeps
/// some horizontal space reserved even for an empty label, which fights
/// against staying narrow; a square Material+InkWell has no such minimum.
class _SettingsPill extends StatelessWidget {
  final double height;
  final VoidCallback onTap;

  const _SettingsPill({required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final borderRadius = BorderRadius.circular(8);

    return SizedBox(
      width: height,
      height: height,
      child: Material(
        color: poloColors.tertiaryLight,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: Center(
            child: Icon(
              Icons.settings,
              size: 16 * MediaQuery.textScalerOf(context).scale(1.0),
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
