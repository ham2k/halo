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
  final QsosRepository qsosRepository;
  final String? noQsosLabel;
  final String Function(String call)? deleteConfirmTitleBuilder;
  final String? cancelLabel;
  final String? deleteLabel;
  final String? duplicateLabel;
  final String? newEntityLabel;
  final String? newBandOrModeLabel;

  /// The uuid of the QSO currently loaded for editing in the logging panel,
  /// if any — that row gets the secondary-colored selected treatment.
  final String? selectedUuid;

  /// Tap a row to select/edit it. The caller owns toggle-to-deselect
  /// semantics (tapping the already-selected row again).
  final void Function(Qso qso) onSelect;

  const QsoList({
    super.key,
    required this.qsos,
    required this.qsosRepository,
    required this.onSelect,
    this.selectedUuid,
    this.noQsosLabel,
    this.deleteConfirmTitleBuilder,
    this.cancelLabel,
    this.deleteLabel,
    this.duplicateLabel,
    this.newEntityLabel,
    this.newBandOrModeLabel,
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
          final number = chronologicalIndex + 1;
          final time = qso.startAt;
          final timeLabel = time == null
              ? '--:--'
              : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          final band = qso.band ?? '';
          final selected = qso.uuid == selectedUuid;

          // Selected treatment matches app-polo's QSOList: secondaryContainer
          // fill with a secondary top/bottom border accent, text tinted
          // toward onSecondaryContainer so it doesn't wash out.
          final rowMono = selected ? mono.copyWith(color: theme.colorScheme.onSecondaryContainer) : mono;
          final rowMonoDim = selected
              ? monoDim.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.75))
              : monoDim;

          return Container(
            decoration: selected
                ? BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: theme.colorScheme.secondary, width: 3),
                    ),
                  )
                : null,
            child: Material(
              color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface,
              child: InkWell(
                onTap: () => onSelect(qso),
                onLongPress: () => _confirmDelete(context, qso),
                mouseCursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('$number', style: rowMonoDim, textAlign: TextAlign.right)),
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

  Future<void> _confirmDelete(BuildContext context, Qso qso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(deleteConfirmTitleBuilder?.call(qso.theirCall) ?? 'Delete QSO with ${qso.theirCall}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel ?? 'Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(deleteLabel ?? 'Delete')),
        ],
      ),
    );
    if (confirmed == true) await qsosRepository.softDelete(qso);
  }
}
