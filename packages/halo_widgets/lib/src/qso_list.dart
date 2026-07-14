// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, hairline dividers, newest QSO at the bottom edge next to the
// logging panel. Row layout follows ham2k/app-halo-dist#2's field list and
// order: Number (optional) | Time | Frequency (or Mode, if no frequency) |
// Mode (only when the operation uses more than one) | Callsign |
// Emoji(s)/Name | References | RST.

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'activity_controls.dart';
import 'icon_resolver.dart';
import 'theme.dart';

/// Horizontal gap between the row's fields (Number/Time/Frequency/Mode/
/// Callsign/Name/References/RST).
const double _columnGap = 12;

/// Measures how wide [text] renders in [style] — used to size the Number and
/// Callsign columns to the widest value in the list, per the issue's "wide
/// enough to fit the largest number/longest callsign" requirement. Merges
/// [style] onto the ambient `DefaultTextStyle` first, same as the real `Text`
/// widgets in the row do internally — measuring [style] alone undercounts
/// whenever the ambient style carries non-zero letter-spacing (Material 3's
/// default text theme sets `letterSpacing: 0.25`), which was previously
/// enough to wrap a long callsign onto a second line despite the SizedBox
/// supposedly being sized to fit it. Also applies the ambient text scaler
/// explicitly, matching how `Text` resolves its effective scaler by default —
/// `TextPainter` doesn't pick up `MediaQuery` on its own, so without this the
/// column would be sized for the unscaled text and wrap at any font-scale
/// setting above 1.0.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final merged = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: text, style: merged),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

class QsoList extends StatelessWidget {
  final List<Qso> qsos;
  final String? noQsosLabel;

  /// The uuid of the QSO currently loaded for editing in the logging panel,
  /// if any — that row gets the secondary-colored selected treatment.
  final String? selectedUuid;

  /// Tap a row to select/edit it. The caller owns toggle-to-deselect
  /// semantics (tapping the already-selected row again). Deleting is
  /// handled entirely through selecting a row and using the logging
  /// panel's staged delete — there's no separate quick-delete on the row
  /// itself, so a single delete flow can't be bypassed mid-edit.
  final void Function(Qso qso) onSelect;

  /// Tap an event marker row (start/break/end — see `Qso.isEvent`) to edit
  /// its time. Falls back to [onSelect] when omitted.
  final void Function(Qso qso)? onSelectEvent;

  /// Whether to show the RST column (ham2k/app-halo-dist#1's logging-view
  /// menu) — the underlying data always exists, this only hides the column.
  final bool showRSTFields;

  /// Whether to show the Number column (ham2k/app-halo-dist#2's logging-view
  /// menu) — the underlying numbering always exists, this only hides it.
  final bool showQsoNumbers;

  /// The active extension logging controls (`operation.data`-scoped, same
  /// list `LoggingControls` uses) — resolved to icons for each ref's `type`
  /// via `iconForRefType`. Empty list falls back to a generic marker icon.
  final List<Map<String, dynamic>> activityControls;

  /// The station's own DXCC entity prefix (e.g. `'K'` for the US), resolved
  /// once per operation — see `OperationView._load`. The DX/State column
  /// only shows the DX flag when this AND the QSO's `theirEntityPrefix` are
  /// both known and differ — positive evidence required. Anything else
  /// (either side unresolved, e.g. this is still loading, or they match)
  /// falls back to the contact's state, same as a same-entity contact would
  /// show, rather than momentarily misflagging every QSO as DX before this
  /// lookup lands.
  final String? ourEntityPrefix;

  const QsoList({
    super.key,
    required this.qsos,
    required this.onSelect,
    this.onSelectEvent,
    this.selectedUuid,
    this.noQsosLabel,
    this.showRSTFields = true,
    this.showQsoNumbers = true,
    this.activityControls = const [],
    this.ourEntityPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (qsos.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            noQsosLabel ?? 'No QSOs yet — work someone!',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    final mono = haloMonoStyle(context, fontSize: 14, color: theme.colorScheme.onSurface);
    final monoDim = mono.copyWith(color: theme.colorScheme.outline);
    // Bold, but the same base size as every other field per the issue: "All
    // fields use the same base font size (except for frequency, see below)."
    final callStyle = mono.copyWith(fontWeight: FontWeight.w700);

    // QSO numbers count only real contacts — event markers interspersed in
    // the timeline don't consume a number.
    final numbers = List<int>.filled(qsos.length, 0);
    var runningNumber = 0;
    for (var i = 0; i < qsos.length; i++) {
      if (qsos[i].isRealContact) runningNumber++;
      numbers[i] = runningNumber;
    }
    // `numbers` only ever increases, so its last value is its max — no need
    // to fold over it separately.
    final maxNumber = runningNumber;

    // Column-sizing must cover every QSO that can actually render a row —
    // including deleted ones, which still show (struck-through) whenever the
    // "show deleted QSOs" menu toggle is on — not just `isRealContact` ones,
    // or a deleted QSO's callsign/frequency/mode can exceed what the columns
    // were sized for and wrap/truncate. One pass instead of separate
    // fold/map/toSet passes per column — cheap on its own (int/string
    // comparisons, not text layout), but there's no reason to walk the list
    // four times when once covers every column that needs a list-wide value.
    var longestCall = '';
    final freqsInKHz = <double?>[];
    final modesUsed = <String>{};
    for (final q in qsos) {
      if (q.isEvent) continue;
      if (q.theirCall.length > longestCall.length) longestCall = q.theirCall;
      freqsInKHz.add(q.freq);
      final mode = q.mode;
      if (mode != null) modesUsed.add(mode);
    }

    // Column widths are computed once for the whole list so every row lines
    // up, per the issue: "wide enough to fit the largest number"/"longest
    // callsign in all qsos".
    final numberWidth = showQsoNumbers ? _textWidth(context, '$maxNumber', mono) : 0.0;
    final callsignWidth = longestCall.isEmpty ? 0.0 : _textWidth(context, longestCall, callStyle);

    // "decide how many digits to display based on all the qsos in the
    // operation" — one Hz precision for the whole list, not per row.
    final hzDigits = hzDigitsNeeded(freqsInKHz);
    // The Mode column only earns its place when the operation actually mixes
    // modes — otherwise every row would repeat the same value.
    final usesMultipleModes = modesUsed.length > 1;

    return Container(
      // Shows through wherever the list doesn't reach (e.g. above the
      // oldest row when there are few QSOs, since the list is reversed to
      // keep the newest one at the bottom) — rows themselves stay opaque
      // on the normal surface color below.
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        reverse: true,
        itemCount: qsos.length,
        // Divider's own `height` (the space it reserves, not the visible
        // line) defaults to 16 regardless of the app-wide dividerTheme's
        // `space` unless given explicitly — measured at 16px in practice,
        // way more than the issue's "one pixel divider ... no further
        // margins" calls for.
        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
        itemBuilder: (context, index) {
          // reverse:true renders itemBuilder index 0 at the bottom of the
          // list. `qsos` is ordered oldest-first, so we index from the end to
          // put the newest QSO at index 0 — next to the logging panel,
          // contest-logger style. The row number stays chronological (1 =
          // first QSO logged), independent of where it renders.
          final chronologicalIndex = qsos.length - 1 - index;
          final qso = qsos[chronologicalIndex];

          if (qso.isEvent) {
            return EventRow(
              qso: qso,
              selected: qso.uuid == selectedUuid,
              onTap: () => (onSelectEvent ?? onSelect)(qso),
            );
          }

          final number = numbers[chronologicalIndex];
          final time = qso.startAt;
          final timeLabel = time == null
              ? '--:--z'
              : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}z';
          final selected = qso.uuid == selectedUuid;

          // Selected treatment matches app-polo's QSOList: secondaryContainer
          // fill with a secondary top/bottom border accent, text tinted
          // toward onSecondaryContainer so it doesn't wash out.
          var rowMono = selected ? mono.copyWith(color: theme.colorScheme.onSecondaryContainer) : mono;
          var rowMonoDim = selected
              ? monoDim.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.75))
              : monoDim;
          var rowCall = selected ? callStyle.copyWith(color: theme.colorScheme.onSecondaryContainer) : callStyle;
          // Deleted QSOs only ever show up here when the "show deleted QSOs"
          // menu toggle is on — struck-through and faded so they read as
          // gone without disappearing from the timeline.
          if (qso.deleted) {
            rowMono = rowMono.copyWith(
              color: rowMono.color?.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
            );
            rowMonoDim = rowMonoDim.copyWith(
              color: rowMonoDim.color?.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
            );
            rowCall = rowCall.copyWith(
              color: rowCall.color?.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
            );
          }

          // DX/State column: a flag only when we have positive evidence the
          // contact is outside our own DXCC entity (both sides resolved and
          // different) — otherwise falls back to the contact's state, same
          // as a same-entity contact. Emoji use a proportional font per the
          // issue ("emoji and name...use a proportional font"), so this
          // deliberately doesn't use rowMono/rowMonoDim for the flag case —
          // see theme.dart's emojiStyle for why it also needs an explicit
          // fontFamily.
          final theirEntityPrefix = qso.theirEntityPrefix;
          final isDX = theirEntityPrefix != null && ourEntityPrefix != null && theirEntityPrefix != ourEntityPrefix;
          final flag = qso.theirFlag;
          final state = qso.theirState;
          Widget? dxStateField;
          if (isDX && flag != null) {
            dxStateField = Text(flag, style: emojiStyle());
          } else if (state != null && state.isNotEmpty) {
            // Falls back to state whenever there's no flag to show — not just
            // when `!isDX` — so a DX contact whose entity resolved but whose
            // flag lookup came up empty (e.g. a DXCC entity present in
            // lib-country-files but missing from lib-dxcc-data's table)
            // still shows its state instead of going blank.
            dxStateField = Text(state, style: rowMonoDim);
          }

          // Frequency bolded-MHz/regular-kHz/smaller-Hz, dot-separated; falls
          // back to the mode when the QSO has no frequency at all.
          final freqKHz = qso.freq;
          final Widget freqField;
          if (freqKHz == null) {
            freqField = Text(qso.mode ?? '', style: rowMono);
          } else {
            final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
            freqField = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(parts.mhz, style: rowMono.copyWith(fontWeight: FontWeight.w700)),
                Text('.', style: rowMono),
                Text(parts.khz, style: rowMono),
                if (parts.hz != null) ...[
                  Text('.', style: rowMono),
                  Text(parts.hz!, style: rowMono.copyWith(fontSize: (rowMono.fontSize ?? 14) * 0.8)),
                ],
              ],
            );
          }

          // One icon per distinct ref type, "×N" appended when the QSO
          // carries more than one ref of that type.
          final refCountsByType = <String, int>{};
          for (final ref in qso.refs) {
            final type = ref['type'] as String?;
            if (type == null) continue;
            refCountsByType.update(type, (count) => count + 1, ifAbsent: () => 1);
          }

          return Container(
            // foregroundDecoration paints over the already-laid-out child
            // instead of insetting it (unlike Container's `decoration`,
            // which turns a BoxDecoration's border into padding) — the
            // selected-row accent border can't add any height on top of the
            // hairline row/divider spacing the issue calls for.
            foregroundDecoration: BoxDecoration(
              border: selected
                  ? Border.symmetric(horizontal: BorderSide(color: theme.colorScheme.secondary, width: 3))
                  : null,
            ),
            child: Material(
              color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface,
              child: InkWell(
                onTap: () => onSelect(qso),
                mouseCursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      if (showQsoNumbers) ...[
                        SizedBox(
                          width: numberWidth,
                          child: Text(qso.deleted ? '' : '$number', style: rowMonoDim, textAlign: TextAlign.right),
                        ),
                        const SizedBox(width: _columnGap),
                      ],
                      Text(timeLabel, style: rowMonoDim),
                      const SizedBox(width: _columnGap),
                      freqField,
                      const SizedBox(width: _columnGap),
                      if (usesMultipleModes) ...[
                        SizedBox(width: 42, child: Text(qso.mode ?? '', style: rowMono)),
                        const SizedBox(width: _columnGap),
                      ],
                      // The callsign never truncates; the name absorbs the squeeze.
                      SizedBox(width: callsignWidth, child: Text(qso.theirCall, style: rowCall)),
                      const SizedBox(width: _columnGap),
                      if (dxStateField != null) ...[
                        dxStateField,
                        const SizedBox(width: _columnGap),
                      ],
                      Expanded(
                        child: Text(
                          qso.theirName ?? '',
                          style: rowMonoDim.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (refCountsByType.isNotEmpty) ...[
                        const SizedBox(width: _columnGap),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in refCountsByType.entries) ...[
                              Icon(
                                resolveIconName(iconForRefType(activityControls, entry.key)),
                                size: 14,
                                color: theme.colorScheme.tertiary,
                              ),
                              if (entry.value > 1)
                                Text('×${entry.value}', style: rowMono.copyWith(fontSize: 11)),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ],
                      if (showRSTFields)
                        SizedBox(
                          width: 68,
                          child: Text(
                            '${qso.sentRST ?? ''} ${qso.receivedRST ?? ''}',
                            style: rowMonoDim,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A start/break/end marker row in [QsoList], visually distinct from a QSO
/// row (centered label instead of data columns) since it isn't a contact —
/// tapping it opens time editing rather than the logging panel.
class EventRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final VoidCallback onTap;

  const EventRow({super.key, required this.qso, required this.onTap, this.selected = false});

  static const _icons = {
    'start': Icons.flag_outlined,
    'break': Icons.pause_circle_outline,
    'end': Icons.flag,
  };

  static const _labels = {
    'start': 'Operation started',
    'break': 'Break',
    'end': 'Operation ended',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = qso.eventKind;
    final time = qso.startAt;
    final timeLabel = time == null
        ? '--:--z'
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}z';

    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icons[kind] ?? Icons.timelapse, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                _labels[kind] ?? kind ?? 'Event',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timeLabel,
                style: haloMonoStyle(context, fontSize: 12, color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
