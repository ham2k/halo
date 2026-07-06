// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list. Renders newest-first from the repository stream the
// screen already watches; deleting is a soft delete so sync can propagate
// it later.

import 'package:flutter/material.dart';

import 'package:polo_core/polo_core.dart';

class QsoList extends StatelessWidget {
  final List<Qso> qsos;
  final QsosRepository qsosRepository;

  const QsoList({super.key, required this.qsos, required this.qsosRepository});

  @override
  Widget build(BuildContext context) {
    if (qsos.isEmpty) {
      return Center(
        child: Text('No QSOs yet — work someone!', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    final monospace = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'Menlo');

    return ListView.builder(
      reverse: true,
      itemCount: qsos.length,
      itemBuilder: (context, index) {
        // reverse:true puts index 0 at the bottom, so the newest QSO sits
        // at the bottom edge next to the logging panel, contest-logger style.
        final qso = qsos[index];
        final number = index + 1;
        final time = qso.startAt;
        final timeLabel = time == null
            ? '--:--'
            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Text(number.toString().padLeft(3), style: monospace),
          title: Row(children: [
            SizedBox(width: 52, child: Text(timeLabel, style: monospace)),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: qso.theirCall, style: monospace?.copyWith(fontWeight: FontWeight.bold)),
                  if (qso.theirName != null && qso.theirName!.isNotEmpty)
                    TextSpan(
                      text: '  ${qso.theirName}',
                      style: monospace?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 48, child: Text(qso.band ?? '', style: monospace)),
            SizedBox(width: 48, child: Text(qso.mode ?? '', style: monospace)),
            SizedBox(width: 76, child: Text('${qso.sentRST ?? ''}/${qso.receivedRST ?? ''}', style: monospace)),
            if (qso.refs.isNotEmpty)
              SizedBox(
                width: 90,
                child: Text(
                  qso.refs.map((r) => r['ref']).whereType<String>().join(','),
                  style: monospace?.copyWith(color: Theme.of(context).colorScheme.tertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
          trailing: PopupMenuButton<String>(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete QSO')),
            ],
            onSelected: (value) {
              if (value == 'delete') qsosRepository.softDelete(qso);
            },
          ),
        );
      },
    );
  }
}
