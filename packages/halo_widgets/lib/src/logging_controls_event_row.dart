// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel's entry row shows in place of the callsign and its
// trailing fields while an event/annotation row (NOTE, TODO, BREAK, …) is
// being edited rather than a contact: a kind label and, for NOTE/TODO, the
// text (and done state) the annotation commands wrote. Built from the same
// field primitives as the contact fields so the row's shape doesn't change
// between the two.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'logging_controls_metrics.dart';
import 'spacing.dart';

/// The main-fields row while editing an event/annotation: the kind is plain
/// text — not a value the operator edits, so it gets no field chrome —
/// baseline-aligned with whatever sits beside it. That's NOTE/TODO's real,
/// editable text field; everything else (SOLAR/WEATHER's fetched
/// description, or nothing at all for BREAK/START/END, whose
/// grid/contest-exchange segment override has no editing UI yet —
/// docs/design/contests.md §5.1.3) goes through [_chromelessValueField]
/// instead of a plain `Text`, so the row reaches a real field's height by
/// construction rather than by approximating it: `TextField` and `Text` size
/// themselves through different render objects (`RenderEditable` vs
/// `RenderParagraph`), which don't agree to the pixel even given the same
/// decoration.
///
/// The panel owns NOTE/TODO's text controller and focus node (it populates
/// them from the record and reads them back on save); this widget only draws
/// them.
class EventFieldRow extends StatelessWidget {
  const EventFieldRow({
    super.key,
    required this.editingQso,
    required this.textController,
    required this.textFocus,
    required this.enabled,
    required this.todoDone,
    required this.onTodoDoneChanged,
    required this.onSubmitted,
  });

  /// The event row being edited. Its kind picks the shape: NOTE and TODO get
  /// the editable text, every other kind shows whatever description it
  /// carries, read-only.
  final Qso editingQso;

  /// NOTE/TODO's inline editor.
  final TextEditingController textController;
  final FocusNode textFocus;

  /// False while the form is locked (a staged or already-deleted row).
  final bool enabled;

  /// TODO's done state and the tap that flips it.
  final bool todoDone;
  final ValueChanged<bool> onTodoDoneChanged;

  /// Enter in the text field.
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final kind = editingQso.eventKind;
    final event = editingQso.event;
    final label = kind?.toUpperCase() ?? 'EVENT';
    // Tinted against the panel's accent — tertiary while composing, secondary
    // while editing — which is the ambient theme the panel builds the row under.
    final textStyle = mainFieldStyle(context, fontWeight: FontWeight.w500)
        .copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer);

    Widget trailing;
    if (kind == 'note' || kind == 'todo') {
      final decoration = mainFieldDecoration(
        context,
        kind == 'todo' ? t.loggingControls.todoField : t.loggingControls.noteField,
        horizontalPadding: materialFilledInputGap,
      );
      trailing = TextField(
        controller: textController,
        focusNode: textFocus,
        enabled: enabled,
        style: mainFieldStyle(context, fontWeight: FontWeight.w400),
        // The done checkbox rides in the field's own prefixIcon slot rather
        // than sitting beside it in the row: a Checkbox can't answer the
        // dry-baseline query `IntrinsicHeight`/`CrossAxisAlignment.baseline`
        // need (its check mark paints through a `RenderCustomPaint`, which
        // doesn't implement one) — the decorator already knows how to place
        // a prefix icon without asking it for a baseline.
        decoration: kind == 'todo'
            ? decoration.copyWith(
                prefixIcon: Checkbox(
                  value: todoDone,
                  onChanged: enabled ? (value) => onTodoDoneChanged(value ?? false) : null,
                ),
              )
            : decoration,
        onSubmitted: (_) => onSubmitted(),
      );
    } else {
      trailing = _chromelessValueField(
        context,
        keySuffix: kind ?? 'event',
        value: (kind == 'solar' || kind == 'weather') ? (event?['description'] as String?) ?? '' : '',
        style: textStyle,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: textStyle),
        const SizedBox(width: Space.md),
        Expanded(child: trailing),
      ],
    );
  }

  /// A read-only, chrome-less field standing in for plain text wherever the
  /// row has no editable value: same decoration function NOTE/TODO's real
  /// field uses (so it claims the identical vertical space), with everything
  /// that paints stripped off (`filled: false`, no border, no label) — a real
  /// `TextField` under the hood so its height matches one exactly, but
  /// nothing on screen betrays that it is one. Keyed on its own value:
  /// `initialValue` only applies once per State, so a field showing a
  /// different event's text after a selection change (same widget position,
  /// new `editingQso`) needs a new key to pick it up.
  Widget _chromelessValueField(
    BuildContext context, {
    required String keySuffix,
    required String value,
    required TextStyle style,
  }) =>
      TextFormField(
        key: ValueKey('event-$keySuffix-$value'),
        initialValue: value,
        readOnly: true,
        enabled: false,
        maxLines: 1,
        style: style,
        decoration: mainFieldDecoration(context, '', horizontalPadding: materialFilledInputGap).copyWith(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );
}
