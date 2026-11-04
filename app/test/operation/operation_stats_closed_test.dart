// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A paused or finished log's summary: what counts as time away from the
// radio, and the rate that time leaves behind.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/operation_stats.dart';

const _t0 = 1700000000000;
const _minute = 60 * 1000;

Qso _qso(int minute) => Qso(
  uuid: 'q$minute',
  operationUuid: 'op',
  data: {
    'startAtMillis': _t0 + minute * _minute,
    'band': '20m',
    'mode': 'CW',
    'their': {'call': 'W1AW'},
  },
);

Qso _event(String kind, int minute) => Qso(
  uuid: 'e$minute',
  operationUuid: 'op',
  data: {
    'startAtMillis': _t0 + minute * _minute,
    'band': 'event',
    'event': {'event': kind},
  },
);

Future<List<String>> _closed(WidgetTester tester, List<Qso> qsos) async {
  List<String> lines = const [];
  await tester.pumpWidget(
    TranslationProvider(
      child: Builder(
        builder: (context) {
          lines = operationStatsLines(context, qsos, sinceLast: false, closed: true);
          return const SizedBox();
        },
      ),
    ),
  );
  return lines;
}

String _split(String rate, {required int pausedMinutes, required int activeMinutes}) => t.loggingControls.info.rateWithSplit(
  rate: rate,
  paused: fmtTimeBetween(0, pausedMinutes * _minute, seconds: false),
  active: fmtTimeBetween(0, activeMinutes * _minute, seconds: false),
);

void main() {
  final info = t.loggingControls.info;

  testWidgets('a pause ended by logging a contact is still time away', (tester) async {
    // Logging into a paused log reopens it without a `restart` row. Counted
    // only before restarts, that hour would read as an hour on the air.
    final lines = await _closed(tester, [_event('start', 0), _qso(10), _event('pause', 20), _qso(80), _event('stop', 90)]);
    expect(lines.last, _split(info.ratePerDay(rate: 2), pausedMinutes: 60, activeMinutes: 30));
  });

  testWidgets('a silence the sweep would pause is time away, though no row marks it', (tester) async {
    // The sweep pauses the record after twelve quiet hours and writes no
    // row, and a contact logged after it writes none either: the silence
    // itself is the only trace.
    final lines = await _closed(tester, [_event('start', 0), _qso(10), _qso(10 + 13 * 60), _event('stop', 20 + 13 * 60)]);
    expect(lines.last, _split(info.ratePerHour(rate: 6), pausedMinutes: 13 * 60, activeMinutes: 20));
  });

  testWidgets('a slow log is counted per day, not projected from its hourly rate', (tester) async {
    // Three contacts in an hour is three that day; projected from 3 QSO/h it
    // would claim 72.
    final lines = await _closed(tester, [_event('start', 0), _qso(10), _qso(30), _qso(50), _event('stop', 60)]);
    expect(lines.last, info.ratePerDay(rate: 3));
  });

  testWidgets('a fraction of a contact a day is written the device\'s way', (tester) async {
    // A fixed '.' reads as a thousands separator to a German operator.
    NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'de_DE');
    addTearDown(NumberFormatting.instance.reset);
    const day = 24 * 60;
    final lines = await _closed(tester, [
      _event('start', 0),
      _qso(0),
      _qso(11 * 60),
      _event('pause', 11 * 60 + 1),
      _event('restart', 9 * day),
      _qso(9 * day + 10),
      _event('stop', 9 * day + 20),
    ]);
    expect(lines.last, contains(info.ratePerDay(rate: '0,3')));
  });
}
