// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, band names tinted with the Ham2K band colors, hairline dividers,
// newest QSO at the bottom edge next to the logging panel.

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'theme.dart';

class QsoList extends StatelessWidget {
  final List<Qso> qsos;
  final String? noQsosLabel;
  final String? duplicateLabel;
  final String? newEntityLabel;
  final String? newBandOrModeLabel;

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

  const QsoList({
    super.key,
    required this.qsos,
    required this.onSelect,
    this.onSelectEvent,
    this.selectedUuid,
    this.noQsosLabel,
    this.duplicateLabel,
    this.newEntityLabel,
    this.newBandOrModeLabel,
    this.showRSTFields = true,
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

    final poloColors = HaLoColors.of(context);
    final mono = haloMonoStyle(context, fontSize: 14, color: theme.colorScheme.onSurface);
    final monoDim = mono.copyWith(color: theme.colorScheme.outline);

    // QSO numbers count only real contacts — event markers interspersed in
    // the timeline don't consume a number.
    final numbers = List<int>.filled(qsos.length, 0);
    var runningNumber = 0;
    for (var i = 0; i < qsos.length; i++) {
      if (qsos[i].isRealContact) runningNumber++;
      numbers[i] = runningNumber;
    }

    return Container(
      // Shows through wherever the list doesn't reach (e.g. above the
      // oldest row when there are few QSOs, since the list is reversed to
      // keep the newest one at the bottom) — rows themselves stay opaque
      // on the normal surface color below.
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        reverse: true,
        itemCount: qsos.length,
        separatorBuilder: (context, index) => const Divider(),
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
              ? '--:--'
              : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          final band = qso.band ?? '';
          final selected = qso.uuid == selectedUuid;

          // Selected treatment matches app-polo's QSOList: secondaryContainer
          // fill with a secondary top/bottom border accent, text tinted
          // toward onSecondaryContainer so it doesn't wash out.
          var rowMono = selected ? mono.copyWith(color: theme.colorScheme.onSecondaryContainer) : mono;
          var rowMonoDim = selected
              ? monoDim.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.75))
              : monoDim;
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
          }

          return Container(
            // The border is always present (3px, just transparent when
            // unselected) rather than added/removed with `selected` —
            // Container turns a BoxDecoration's border into padding around
            // the child, so toggling it on and off would grow/shrink the
            // row's height by the border width instead of just recoloring it.
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: selected ? theme.colorScheme.secondary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Material(
              color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface,
              child: InkWell(
                onTap: () => onSelect(qso),
                mouseCursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(qso.deleted ? '' : '$number', style: rowMonoDim, textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 12, child: _scoreBadge(context, qso)),
                    const SizedBox(width: 6),
                    Text(timeLabel, style: rowMonoDim),
                    const SizedBox(width: 10),
                    // The callsign never truncates; the name absorbs the squeeze.
                    Text(qso.theirCall, style: rowMono.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        qso.theirName ?? '',
                        style: rowMonoDim.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (qso.refs.isNotEmpty) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 76),
                        child: Text(
                          qso.refs.map((r) => r['ref']).whereType<String>().join(','),
                          style: rowMono.copyWith(fontSize: 12, color: theme.colorScheme.tertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    SizedBox(
                      width: 44,
                      child: Text(
                        band,
                        style: rowMono.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? theme.colorScheme.onSecondaryContainer
                              : Color.lerp(poloColors.bandColor(band), theme.colorScheme.onSurface, 0.25),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 42, child: Text(qso.mode ?? '', style: rowMono)),
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

  /// A small colored dot summarizing this QSO's cached scoring verdict
  /// (`qso.scores`, written by `ScoringService` from the `scoring` hook's
  /// batched results — see DESIGN.md §4). `null` (no dot) until the
  /// operation has been scored, or when the QSO is unremarkable: not a
  /// dupe, no new DXCC entity, no new band/mode. Priority when more than
  /// one applies: duplicate > new entity > new band/mode.
  Widget? _scoreBadge(BuildContext context, Qso qso) {
    final scores = qso.scores;
    if (scores == null) return null;

    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    final dupeScore = scores['dupe'] as Map<String, dynamic>?;
    final isDupe = dupeScore?['dupe'] == true;
    final notices = (dupeScore?['notices'] as List?)?.cast<String>() ?? const [];
    final hasBandOrModeNotice = notices.contains('newBand') || notices.contains('newMode');

    final dxccScore = scores['dxcc'] as Map<String, dynamic>?;
    final isNewEntity = (dxccScore?['value'] as num?) == 1;

    Color color;
    String? tooltip;
    if (isDupe) {
      color = theme.colorScheme.error;
      tooltip = duplicateLabel;
    } else if (isNewEntity) {
      color = poloColors.important;
      tooltip = newEntityLabel;
    } else if (hasBandOrModeNotice) {
      color = poloColors.notice;
      tooltip = newBandOrModeLabel;
    } else {
      return null;
    }

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip, child: dot);
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
        ? '--:--'
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
