// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `select` whose options are ROWS rather than strings: a name, short tags,
// and an identifier in its own right-aligned column. `DropdownButtonFormField`
// can only take one string per item, so a list of near-identical device names
// — which is exactly what a serial port picker is — has nothing to scan down.

import 'package:flutter/material.dart';

import 'icon_resolver.dart';
import 'spacing.dart';
import 'theme.dart';

/// One row of a [RowSelectField]. [name] leads and carries the weight, [tags]
/// are short markers between the two columns, and [trailing] is the
/// right-aligned identifier.
class SelectRow {
  final Object? value;
  final String name;
  final List<String> tags;
  final String? trailing;

  /// The glyph in front of the name, by [resolveIconName]'s naming — what
  /// KIND of thing this row is, before reading a word of it.
  final String? icon;

  /// A line under the name. For what is true of THIS row in particular — a
  /// tag says which group a row is in, and a sentence saying so reads as a
  /// label nobody wrote.
  final String? subtitle;

  /// This is the row to pick — drawn heavier than the rest.
  final bool emphasis;

  const SelectRow({required this.value, required this.name, this.tags = const [], this.trailing, this.icon, this.subtitle, this.emphasis = false});

  /// What the closed field shows, which has one line and no columns.
  String get flatLabel => [name, ...tags, ?trailing].join(' ');
}

/// A dropdown built from [SelectRow]s, opened as a menu anchored under the
/// field.
///
/// A [MenuAnchor] rather than a [DropdownButton] for two reasons beyond the
/// layout: the menu is part of this widget's own tree, so a rebuild while it
/// is OPEN updates the rows in place — a port plugged in with the list down
/// appears in it — and a value that vanishes from [rows] is a state this
/// widget renders (as an empty field) instead of asserting on.
class RowSelectField extends StatefulWidget {
  final String label;
  final Object? value;
  final List<SelectRow> rows;
  final ValueChanged<Object?> onChanged;
  final FocusNode? focusNode;
  final String? errorText;
  final String? placeholder;
  final Color? labelColor;
  final bool enabled;

  const RowSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.rows,
    required this.onChanged,
    this.focusNode,
    this.errorText,
    this.placeholder,
    this.labelColor,
    this.enabled = true,
  });

  @override
  State<RowSelectField> createState() => _RowSelectFieldState();
}

class _RowSelectFieldState extends State<RowSelectField> {
  final _controller = MenuController();
  final _anchorKey = GlobalKey();

  /// What the field painted at last frame, for the case layout would not say.
  double? _anchorWidth;

  void _rememberAnchorWidth() {
    final width = (_anchorKey.currentContext?.findRenderObject() as RenderBox?)?.size.width;
    if (width == null || width == _anchorWidth) return;
    // Next frame: this runs during one, and the menu that wants the number is
    // built in the same pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _anchorWidth = width);
    });
  }

  @override
  Widget build(BuildContext context) =>
      // OUTSIDE the anchor, so the width is known during the very layout that
      // builds the menu — measuring inside the anchor's own builder only
      // learns it a frame late, which is a frame of the menu at the wrong
      // width every time the pane resizes.
      LayoutBuilder(
        // The constraint is the field's width WHERE THERE IS ONE. A form that
        // lays its fields out under an unbounded width — an intrinsic-width
        // ancestor, a Row without a flex — gives infinity here, and a menu
        // sized to that falls back to its own content and comes out narrower
        // than the field it dropped out of. [_anchorWidth] is what the field
        // actually painted at, which is never infinite.
        builder: (context, constraints) => _build(context, constraints.maxWidth.isFinite ? constraints.maxWidth : _anchorWidth ?? 0),
      );

  Widget _build(BuildContext context, double width) {
    final theme = Theme.of(context);
    _rememberAnchorWidth();
    final selected = widget.rows.where((row) => row.value == widget.value).firstOrNull;
    final detailStyle = _SelectRowLayout.detailStyle(theme);
    var trailingWidth = 0.0;
    for (final row in widget.rows) {
      if (row.trailing == null) continue;
      final width = textWidth(context, row.trailing!, detailStyle);
      if (width > trailingWidth) trailingWidth = width;
    }

    // Everything the row wants at its widest, against what the field has. A
    // name column that would be squeezed to a few characters is worth less
    // than a second line, so past that point the row becomes two.
    var nameWidth = 0.0;
    var tagsWidth = 0.0;
    for (final row in widget.rows) {
      final name = textWidth(context, row.name, _SelectRowLayout.nameStyle(theme, emphasis: row.emphasis));
      if (name > nameWidth) nameWidth = name;
      var tags = 0.0;
      for (final tag in row.tags) {
        tags += textWidth(context, tag, _TagPill.textStyle(theme)) + _TagPill.padding + Space.sm;
      }
      if (tags > tagsWidth) tagsWidth = tags;
    }
    final wanted = _iconSize + Space.sm + nameWidth + tagsWidth + Space.md + trailingWidth + _menuItemPadding;
    final twoLine = wanted > width;

    // The menu is pinned to the FIELD's width, both ends of the constraint.
    // Left to itself a menu sizes each item to its own content, so every row
    // ends somewhere different and the identifiers are not a column at all —
    // which no amount of right-aligning inside the row can fix. Pinning it
    // also lines the open list up with the closed field it drops out of.
    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, dropdownMenuMaxHeight(context))),
        alignment: Alignment.bottomLeft,
      ),
      menuChildren: [
        for (final row in widget.rows)
          MenuItemButton(
            onPressed: () => widget.onChanged(row.value),
            // The width is on the ITEM as well as on the menu's own style:
            // the panel takes the width of its widest child, so this holds
            // even where the style's constraint does not reach.
            child: SizedBox(
              width: width > _menuItemPadding ? width - _menuItemPadding : null,
              child: _SelectRowLayout(row: row, trailingWidth: trailingWidth, twoLine: twoLine),
            ),
          ),
      ],
      builder: (context, controller, _) => InkWell(
        key: _anchorKey,
        focusNode: widget.focusNode,
        onTap: widget.enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
        canRequestFocus: widget.enabled,
        child: InputDecorator(
          decoration: poloFieldDecoration(
            context,
            widget.label,
            errorText: widget.errorText,
            labelColor: widget.labelColor,
          ).copyWith(suffixIcon: dropdownTrailingIcon, enabled: widget.enabled),
          isEmpty: selected == null && widget.value == null && widget.placeholder == null,
          child: selected == null
              // A value no row offers is still the field's value — the port
              // is configured, its cable is just out. Shown muted rather than
              // as a blank field, which reads as nothing configured and has
              // the operator picking a port they had already chosen.
              ? (widget.value != null
                    ? Text('${widget.value}', style: _SelectRowLayout.detailStyle(theme))
                    : widget.placeholder == null
                    ? null
                    : Text(widget.placeholder!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              // The closed field shows the row's own layout, so what the
              // operator picked reads the same shut as it did open.
              : _SelectRowLayout(row: selected, trailingWidth: trailingWidth, twoLine: twoLine),
        ),
      ),
    );
  }
}

/// The row: name, its tags, and the identifier in a column of a width every
/// row shares — on one line where that fits, and on two where it does not.
class _SelectRowLayout extends StatelessWidget {
  final SelectRow row;

  /// Measured across every row, so the identifiers line up as a column
  /// instead of each sitting wherever its own name ended. A menu lays each
  /// item out to its own intrinsic width, so nothing about `Expanded` or
  /// right alignment gets two rows agreeing on their own.
  final double trailingWidth;

  /// The name gets the first line to itself, and the tags and identifier
  /// share a second — tags left, identifier right. Squeezing all three onto
  /// one line on a narrow pane costs the name, which is the part being read.
  final bool twoLine;

  const _SelectRowLayout({required this.row, required this.trailingWidth, required this.twoLine});

  static TextStyle nameStyle(ThemeData theme, {required bool emphasis}) =>
      theme.textTheme.bodyMedium?.copyWith(
        // The name identifies the hardware, so it carries the weight in every
        // row; the suggested one carries more, which is a difference only
        // visible because the rest of the list is NOT already bold.
        fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
      ) ??
      const TextStyle();

  static TextStyle detailStyle(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final icon = row.icon == null
        ? const SizedBox(width: _iconSize)
        : Icon(resolveIconName(row.icon), size: _iconSize, color: theme.colorScheme.onSurfaceVariant);

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          row.name,
          overflow: TextOverflow.ellipsis,
          style: nameStyle(theme, emphasis: row.emphasis),
        ),
        if (row.subtitle != null) Text(row.subtitle!, overflow: TextOverflow.ellipsis, style: detailStyle(theme)),
      ],
    );

    final tags = [for (final tag in row.tags) _TagPill(text: tag)];

    final trailing = row.trailing == null ? null : Text(row.trailing!, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: detailStyle(theme));

    if (twoLine) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: Space.sm),
              Expanded(child: name),
            ],
          ),
          // Indented to the name's own left edge, so the second line reads as
          // belonging to the row above it rather than as a row of its own.
          Padding(
            padding: const EdgeInsets.only(left: _iconSize + Space.sm, top: Space.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Flexible around a Wrap, not a bare Row of pills: a non-flex
                // child of a Row is given UNBOUNDED width, so pills that do
                // not fit overflow the line rather than moving onto another.
                Flexible(
                  child: Wrap(spacing: Space.sm, runSpacing: Space.xxs, children: tags),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.sm), Expanded(child: trailing)],
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      // Start, not centre: a row with a subtitle is taller, and its tags and
      // identifier belong beside the NAME rather than floating between the
      // two lines.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: Space.sm),
        // Expanded, not Flexible: the row fills the field's width, so the
        // tags and the identifier sit at the right edge instead of trailing
        // whatever length the name happened to have.
        Expanded(child: name),
        for (final tag in tags) ...[const SizedBox(width: Space.sm), tag],
        if (trailing != null) ...[const SizedBox(width: Space.md), SizedBox(width: trailingWidth, child: trailing)],
      ],
    );
  }
}

/// The leading glyph's size, and what a menu item insets its child by — both
/// only for the width arithmetic that decides one line or two.
const _iconSize = 20.0;
const _menuItemPadding = 24.0;

/// A tag as a pill rather than as bracketed words: `[suggested]` in running
/// text is read as part of the name, which is the one thing it is not.
class _TagPill extends StatelessWidget {
  final String text;

  const _TagPill({required this.text});

  /// The horizontal room the pill adds around its own text.
  static const padding = 2 * Space.sm;

  static TextStyle textStyle(ThemeData theme) => theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer) ?? const TextStyle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(Space.sm)),
      child: Text(text, style: textStyle(theme)),
    );
  }
}
