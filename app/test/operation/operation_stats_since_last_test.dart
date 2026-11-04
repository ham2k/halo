// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one figure in the operation's stats line that moves on its own, and
// when it must stop.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/operation_stats.dart';

Qso _qso(int atMillis) => Qso(
  uuid: 'q$atMillis',
  operationUuid: 'op',
  data: {
    'startAtMillis': atMillis,
    'band': '20m',
    'mode': 'CW',
    'their': {'call': 'W1AW'},
  },
);

Qso _startEvent(int atMillis) => Qso(
  uuid: 'e$atMillis',
  operationUuid: 'op',
  data: {
    'startAtMillis': atMillis,
    'band': 'event',
    'event': {'event': 'start'},
  },
);

void main() {
  testWidgets('a started operation counts its elapsed time instead of "no QSOs"', (tester) async {
    // The operator knows the log is empty — they are sitting in front of the
    // row. What they cannot see is how long they have been at it.
    List<String> beforeStart = const [];
    List<String> afterStart = const [];
    var noQsos = '';
    await tester.pumpWidget(
      TranslationProvider(
        child: Builder(
          builder: (context) {
            noQsos = context.t.loggingControls.info.noQsos;
            beforeStart = operationStatsLines(context, const []);
            afterStart = operationStatsLines(context, [_startEvent(nowMillis() - 12 * 60 * 1000)]);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(beforeStart, [noQsos]);
    expect(afterStart.first, isNot(noQsos));
    expect(afterStart.first, contains('12m'));
  });

  testWidgets('a closed operation with no contacts reports no running clock', (tester) async {
    // Same rule as "since last": a figure counting up beside a state that
    // says the operator has stopped is the panel contradicting itself.
    List<String> closed = const [];
    await tester.pumpWidget(
      TranslationProvider(
        child: Builder(
          builder: (context) {
            closed = operationStatsLines(context, [_startEvent(nowMillis() - 12 * 60 * 1000)], sinceLast: false);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(closed.first, isNot(contains('12m')));
    expect(closed.first, isNotEmpty);
  });

  testWidgets('a closed log reports no "since last"', (tester) async {
    List<String> live = const [];
    List<String> closed = const [];
    var marker = '';
    final qsos = [_qso(nowMillis() - 60 * 60 * 1000), _qso(nowMillis() - 60 * 1000)];

    await tester.pumpWidget(
      TranslationProvider(
        child: Builder(
          builder: (context) {
            live = operationStatsLines(context, qsos);
            closed = operationStatsLines(context, qsos, sinceLast: false);
            // The label's own wording is not the point — its trailing word marks
            // the fragment, whatever a translation does around it.
            marker = context.t.loggingControls.info.sinceLast(time: '1m').split(' ').last;
            return const SizedBox();
          },
        ),
      ),
    );

    // Live, the figure is there and counting.
    expect(live.first, contains(marker));
    // Closed, it is gone — counting up beside "Operation Completed" would say
    // the operator is still at the radio. Everything else survives, because
    // the count and the span describe what the log already holds.
    expect(closed.first, isNot(contains(marker)));
    expect(closed.first, isNotEmpty);
  });
}
