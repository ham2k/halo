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

  /// Shown as a highlighted border on the chip when the control already
  /// holds a value worth flagging (e.g. a POTA ref has been entered, or the
  /// time has been manually overridden).
  final bool hasValue;

  final WidgetBuilder expandedBuilder;

  const SecondaryControlSpec({
    required this.key,
    required this.icon,
    required this.summary,
    required this.expandedBuilder,
    this.hasValue = false,
  });
}

class SecondaryControlRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    SecondaryControlSpec? selected;
    for (final control in controls) {
      if (control.key == selectedKey) selected = control;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Builder(builder: selected.expandedBuilder),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final control in controls) ...[
                _ControlChip(
                  control: control,
                  selected: control.key == selectedKey,
                  onTap: () =>
                      onSelect(control.key == selectedKey ? null : control.key),
                ),
                const SizedBox(width: 6),
              ],
              ?trailing,
            ],
          ),
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
    required this.control,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = PoloColors.of(context);

    // Matches app-polo's LoggerChip: unselected = tertiaryLight fill with
    // onTertiaryContainer text/icon; selected = solid tertiary fill with
    // onTertiary (near-white) text/icon. A rounded-rectangle shape, not
    // Flutter's default full-pill chip — app-polo's chips (react-native-paper
    // Chip, flat mode) are boxy with a modest corner radius.
    final foreground = selected
        ? theme.colorScheme.onTertiary
        : theme.colorScheme.onTertiaryContainer;

    return ChoiceChip(
      avatar: Icon(control.icon, size: 16, color: foreground),
      label: Text(control.summary, style: TextStyle(color: foreground)),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: poloColors.tertiaryLight,
      selectedColor: theme.colorScheme.tertiary,
      // Material3's ChoiceChip draws a default outline when side is null;
      // app-polo's LoggerChip has none unless flagging hasValue.
      side: control.hasValue
          ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
          : BorderSide.none,
      onSelected: (_) => onTap(),
    );
  }
}
