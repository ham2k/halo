// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, band names tinted with the Ham2K band colors, hairline dividers,
// newest QSO at the bottom edge next to the logging panel.

import 'package:flutter/material.dart';

import 'package:polo_core/polo_core.dart';

import 'theme.dart';

class QsoList extends StatelessWidget {
  final List<Qso> qsos;
  final QsosRepository qsosRepository;

  const QsoList({super.key, required this.qsos, required this.qsosRepository});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (qsos.isEmpty) {
      return Center(
        child: Text(
          'No QSOs yet — work someone!',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }

    final poloColors = PoloColors.of(context);
    final mono = poloMonoStyle(context, fontSize: 14, color: theme.colorScheme.onSurface);
    final monoDim = mono.copyWith(color: theme.colorScheme.outline);

    return ListView.separated(
      reverse: true,
      itemCount: qsos.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        // reverse:true puts index 0 at the bottom, so the newest QSO sits
        // next to the logging panel, contest-logger style.
        final qso = qsos[index];
        final number = index + 1;
        final time = qso.startAt;
        final timeLabel = time == null
            ? '--:--'
            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final band = qso.band ?? '';

        return InkWell(
          onLongPress: () => _confirmDelete(context, qso),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 34, child: Text('$number', style: monoDim, textAlign: TextAlign.right)),
                const SizedBox(width: 10),
                Text(timeLabel, style: monoDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: qso.theirCall, style: mono.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (qso.theirName != null && qso.theirName!.isNotEmpty)
                        TextSpan(text: '  ${qso.theirName}', style: monoDim.copyWith(fontSize: 13)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (qso.refs.isNotEmpty) ...[
                  Text(
                    qso.refs.map((r) => r['ref']).whereType<String>().join(','),
                    style: mono.copyWith(fontSize: 12, color: theme.colorScheme.tertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 46,
                  child: Text(
                    band,
                    style: mono.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(poloColors.bandColor(band), theme.colorScheme.onSurface, 0.25),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 44, child: Text(qso.mode ?? '', style: mono)),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${qso.sentRST ?? ''} ${qso.receivedRST ?? ''}',
                    style: monoDim,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Qso qso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete QSO with ${qso.theirCall}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await qsosRepository.softDelete(qso);
  }
}
