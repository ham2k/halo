// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO list's rows for event pseudo-QSOs: the operation's own markers
// (start, break, pause, restart, finish) and the annotations attached to it.

part of 'qso_list.dart';

/// A start/break/end marker row in [QsoList], visually distinct from a QSO
/// row (centered label instead of data columns) since it isn't a contact —
/// tapping it loads `LoggingControls`' inline event editor, same as an
/// [AnnotationRow] (`Qso.isEvent`), just with a centered summary here
/// instead of the timeline layout below.
class EventRow extends StatelessWidget {
  final Qso qso;

  /// What this marker is called, localized — shown ahead of
  /// whatever the marker says about the operation. Null leaves the row its
  /// description alone, which is right for a kind the icon already names.
  final OperationMarkerLabel? label;

  final bool selected;
  final VoidCallback onTap;

  /// Width of the (optional) QSO-number column plus its gap, so the time
  /// column lines up with the QSO rows around it — same as [AnnotationRow].
  final double leadingWidth;

  const EventRow({super.key, required this.qso, this.label, required this.onTap, this.selected = false, this.leadingWidth = 0});

  /// Bare glyphs rather than boxed ones: the row's wash already frames the
  /// marker, and a box inside it reads as a control.
  IconData get _icon => switch (qso.eventKind) {
    'start' => MdiIcons.play,
    'break' => MdiIcons.slashForward,
    'pause' => MdiIcons.pause,
    'restart' => MdiIcons.refresh,
    'end' || 'stop' => MdiIcons.stop,
    _ => MdiIcons.timelapse,
  };

  /// The rule the top border takes out of the row's vertical padding, so the
  /// row keeps [QsoList]'s fixed per-row height (HALO-258).
  static const _topBorder = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = _utcTimeLabel(qso.startAt);
    // The row reads as a timeline entry, like polo's: the time in the QSO
    // rows' column, the segment's mark, then what the segment says about
    // the operation ("for ARRL 10G Sep • at FN20rm"), stored on the row by
    // whatever wrote it (naming a reference needs an async extension hook,
    // which a list row can't make — polo recomposes per frame instead).
    //
    // Without one — an older row, or one written while the extension host
    // was down — the override's own square is still on the row and says
    // more than nothing: after a name, as the sentence it continues ("at
    // FN31pr"); alone, bare. A segment with neither shows its mark alone:
    // naming the kind ("Break") would say nothing the icon doesn't.
    final stored = (qso.event?['description'] as String?)?.trim() ?? '';
    final override = qso.event?['operation'];
    final grid = override is Map ? (override['grid'] as String?)?.trim() ?? '' : '';
    final label = this.label;
    final says = label?.standsAlone == true
        ? ''
        : stored.isNotEmpty
        ? (label == null ? stored : _continuing(stored))
        : (label == null || grid.isEmpty ? grid : t.operation.titleAt(value: grid));
    // The name set apart in bold, wherever its language put it in the
    // sentence; the rest — the time a restart sat, what a finished log came
    // to — in the row's own weight.
    final nameAt = label == null ? -1 : label.text.indexOf(label.name);
    var ink = selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant;
    // Deleted markers follow the QSO rows' "show deleted" treatment:
    // struck-through and faded, still in the timeline.
    if (qso.deleted) ink = ink.withValues(alpha: 0.5);
    final strike = qso.deleted ? TextDecoration.lineThrough : null;
    // polo's `primaryLighter` segment row: a wash of the primary over the
    // surface, so a blue theme reads blue-gray, and the dark theme gets the
    // same wash rather than a full-strength container. The rule along the
    // top is the same wash, deeper.
    final isDark = theme.brightness == Brightness.dark;
    Color wash(double alpha) => Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: alpha), theme.colorScheme.surface);
    final background = selected ? theme.colorScheme.secondaryContainer : wash(isDark ? 0.22 : 0.14);
    final rule = wash(isDark ? 0.5 : 0.35);
    // Matches the ordinary QSO row's own padding exactly (not a hardcoded
    // value) — [QsoList] forces every row into the same fixed
    // [_rowHeight] box (HALO-258, avoids a per-row layout
    // walk on `jumpTo`), so a row whose natural height doesn't match that
    // box overflows or leaves a gap. The border comes out of the top
    // padding for the same reason.
    final padding = PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: _rowPaddingV(LayoutDensity.metricsOf(context)));

    // The border is part of the row's height, so it comes OUT of the
    // padding — off the top first, and off the bottom for whatever the top
    // couldn't give. At the densest layout the vertical padding is 1px
    // against a 2px rule, and a bare clamp at the top would leave the row a
    // pixel taller than the box [QsoList] forces it into.
    final borderTop = padding.top.clamp(0.0, _topBorder);
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: rule, width: _topBorder),
            ),
          ),
          padding: padding.copyWith(top: padding.top - borderTop, bottom: (padding.bottom - (_topBorder - borderTop)).clamp(0.0, double.infinity)),
          child: Row(
            children: [
              SizedBox(width: leadingWidth),
              Text(
                timeLabel,
                style: haloMonoStyle(context, fontSize: _rowMonoFontSize, color: ink).copyWith(decoration: strike),
              ),
              const SizedBox(width: _columnGap),
              Icon(_icon, size: 16, color: ink),
              const SizedBox(width: _columnGap),
              Expanded(
                // The marker's own words first when it has a name, and what
                // it says about the operation running on from them as one
                // sentence — "**Started** at FN31pr". A kind with no name
                // keeps the row it always had.
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (label != null && nameAt >= 0) ...[
                        if (nameAt > 0) TextSpan(text: label.text.substring(0, nameAt)),
                        TextSpan(
                          text: label.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (nameAt + label.name.length < label.text.length) TextSpan(text: label.text.substring(nameAt + label.name.length)),
                      ] else if (label != null)
                        TextSpan(text: label.text),
                      if (label != null && says.isNotEmpty) const TextSpan(text: ' '),
                      if (says.isNotEmpty) TextSpan(text: says),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: ink, decoration: strike),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [description] as it reads after the marker's name: a start or a finish
  /// stores its sentence capitalized ("At FN31pr", "For NJQP at …"), and
  /// following "Started" it is the rest of that sentence. Only the opening
  /// words the description is composed from are lowered — a description that
  /// opens on a name ("NJQP: MORR …") keeps it as written.
  static String _continuing(String description) {
    for (final opening in [t.operation.titleAt(value: ''), t.operation.titleFor(value: '')]) {
      final word = opening.trim();
      if (word.isEmpty) continue;
      final capitalized = word[0].toUpperCase() + word.substring(1);
      if (description.startsWith('$capitalized ')) return word + description.substring(word.length);
    }
    return description;
  }
}

/// A note/todo/solar/weather annotation row in [QsoList] — an event
/// pseudo-QSO added by the annotation commands (ham2k/halo-dist#64,
/// `extensions/core/annotation-commands`). Unlike [EventRow]'s centered
/// segment markers, annotations are timeline entries: they keep the QSO
/// rows' time column (left-aligned, [leadingWidth] preserving the Number
/// column's indent), followed by the event's icon and its text. The yellow
/// "sticky note" treatment is ported from app-polo's QSOList `eventRow`/
/// `eventContent` styles.
class AnnotationRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final VoidCallback onTap;

  /// Width of the (optional) QSO-number column plus its gap, so the time
  /// column lines up with the QSO rows around it.
  final double leadingWidth;

  const AnnotationRow({super.key, required this.qso, required this.onTap, this.selected = false, this.leadingWidth = 0});

  /// app-polo's `eventRow` background, `rgb(252, 244, 167)` — blended over
  /// the surface at app-polo's row opacity (0.85 light / 0.65 dark) so the
  /// dark theme gets the same muted yellow instead of a full-brightness slab.
  static const _yellow = Color(0xFFFCF4A7);

  /// app-polo's `eventContent` text color, `rgb(21, 20, 10)` — near-black
  /// ink that stays readable on the yellow in both themes.
  static const _ink = Color(0xFF15140A);

  /// A to-do's icon tracks its state (same logic as app-polo's
  /// EventNoteItem): done shows a check, deleted hollows out. Everything
  /// else uses the icon the command stored on the event. The done flag is
  /// read from `data.done` with a fallback to a bare `done` — app-polo
  /// reads both, and synced logs contain the older bare shape.
  String get _iconName {
    final event = qso.event;
    if (qso.eventKind == 'todo') {
      if (qso.deleted) return 'sticker-outline';
      return eventTodoDone(event) ? 'sticker-check-outline' : 'sticker';
    }
    return asQsonString(event?['icon']) ?? 'information';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final event = qso.event;
    final timeLabel = _utcTimeLabel(qso.startAt);
    final text = asQsonString(event?['description']) ?? asQsonString(event?['note']) ?? qso.eventKind?.toUpperCase() ?? 'Event';

    final background = selected
        ? theme.colorScheme.secondaryContainer
        : Color.alphaBlend(_yellow.withValues(alpha: isDark ? 0.65 : 0.85), theme.colorScheme.surface);
    var ink = selected ? theme.colorScheme.onSecondaryContainer : _ink;
    // SOLAR/WEATHER descriptions mix emoji into the text, so the style
    // needs the bundled color-emoji font as an explicit fallback — the web
    // renderer never falls back to an OS emoji font on its own (see
    // theme.dart's `emojiFontFamily`).
    var textStyle = theme.textTheme.bodyMedium?.copyWith(color: ink, fontFamilyFallback: const [emojiFontFamily]);
    var timeStyle = haloMonoStyle(context, fontSize: _rowMonoFontSize, color: ink);
    // Deleted annotations follow the QSO rows' "show deleted" treatment:
    // struck-through and faded, still in the timeline.
    if (qso.deleted) {
      ink = ink.withValues(alpha: 0.5);
      textStyle = textStyle?.copyWith(color: ink, decoration: TextDecoration.lineThrough);
      timeStyle = timeStyle.copyWith(color: ink, decoration: TextDecoration.lineThrough);
    }

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          // See EventRow's identical note: matches the ordinary row's own
          // padding so this row's natural height fits [QsoList]'s fixed
          // per-row box exactly (HALO-258).
          padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: _rowPaddingV(LayoutDensity.metricsOf(context))),
          child: Row(
            children: [
              SizedBox(width: leadingWidth),
              Text(timeLabel, style: timeStyle),
              const SizedBox(width: _columnGap),
              Icon(resolveIconName(_iconName), size: 16, color: ink),
              const SizedBox(width: _columnGap),
              Expanded(
                child: Text(text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
