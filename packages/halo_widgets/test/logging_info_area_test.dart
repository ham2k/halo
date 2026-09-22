// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The info area's priority order and its one gesture, on their own: which of
// its four states wins, that the missing-band warnings ride above whichever
// one does, and that a tap anywhere on it opens the call detail while the
// call info shows and the operation's info otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_info_area.dart';

Widget _host({
  List<String> warnings = const [],
  String? message,
  CallInfoData? callInfo,
  String? gridOnlyLine,
  List<String> stats = const ['3 QSOs'],
  VoidCallback? onCallInfoTap,
  VoidCallback? onOperationInfoTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => LoggingInfoArea(
            theme: Theme.of(context),
            warnings: warnings,
            message: message,
            callInfo: callInfo,
            locationLine: null,
            gridOnlyLine: gridOnlyLine,
            statsLines: () => stats,
            noticeLabel: null,
            workedBeforeLabel: null,
            onCallInfoTap: onCallInfoTap,
            onOperationInfoTap: onOperationInfoTap,
            onOpenLink: null,
          ),
        ),
      ),
    );

const _w1aw = CallInfoData(call: 'W1AW');

/// The call-info panel for W1AW — the summary widget draws the call through
/// its own layout, so the test looks for the widget rather than the text.
final _w1awPanel = find.byWidgetPredicate((w) => w is CallInfoSummary && w.data.call == 'W1AW');

void main() {
  testWidgets('with nothing to say about a station, the operation statistics show', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('3 QSOs'), findsOneWidget);
  });

  testWidgets('a call in hand replaces the statistics; a command message outranks the call', (tester) async {
    await tester.pumpWidget(_host(callInfo: _w1aw));
    expect(_w1awPanel, findsOneWidget);
    expect(find.text('3 QSOs'), findsNothing);

    await tester.pumpWidget(_host(callInfo: _w1aw, message: 'Tune to **14285**'));
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(_w1awPanel, findsNothing, reason: 'the message takes the whole area');
  });

  testWidgets('a grid alone shows its distance line, below a call but above the statistics', (tester) async {
    await tester.pumpWidget(_host(gridOnlyLine: '1,234 km NE'));
    expect(find.text('1,234 km NE'), findsOneWidget);
    expect(find.text('3 QSOs'), findsNothing);
    await tester.pumpWidget(_host(gridOnlyLine: '1,234 km NE', callInfo: _w1aw));
    expect(_w1awPanel, findsOneWidget);
    expect(find.text('1,234 km NE'), findsNothing);
  });

  testWidgets('the missing-band warnings ride above whatever the area shows, the message included', (tester) async {
    await tester.pumpWidget(_host(warnings: const ['No Band', 'No Mode'], message: 'Reloaded'));
    expect(find.text('No Band'), findsOneWidget);
    expect(find.text('No Mode'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    final warning = tester.getTopLeft(find.text('No Band'));
    final message = tester.getTopLeft(find.byType(MarkdownBody));
    expect(warning.dy, lessThan(message.dy));
  });

  // Which of the two callbacks fires is decided by what the area shows, never
  // by where the finger lands: a warning pill above a call opens the call, the
  // same pill above the statistics opens the operation. A command message over
  // a call in hand is the trap: the host holds no call info while a message has
  // the space, so routing that tap to the call would open nothing.
  testWidgets('a tap anywhere opens the call detail while the call shows, the operation info otherwise',
      (tester) async {
    var callTaps = 0, operationTaps = 0;
    Widget host({CallInfoData? callInfo, String? message, String? gridOnlyLine}) => _host(
          callInfo: callInfo,
          message: message,
          gridOnlyLine: gridOnlyLine,
          warnings: const ['No Band'],
          onCallInfoTap: () => callTaps++,
          onOperationInfoTap: () => operationTaps++,
        );

    await tester.pumpWidget(host(callInfo: _w1aw));
    await tester.tap(_w1awPanel);
    await tester.tap(find.text('No Band'));
    expect((callTaps, operationTaps), (2, 0), reason: 'the pill is part of the same target');

    await tester.pumpWidget(host());
    await tester.tap(find.text('3 QSOs'));
    await tester.tap(find.text('No Band'));
    expect((callTaps, operationTaps), (2, 2));

    await tester.pumpWidget(host(gridOnlyLine: '1,234 km NE'));
    await tester.tap(find.text('1,234 km NE'));
    expect((callTaps, operationTaps), (2, 3), reason: 'a grid alone names no station');

    await tester.pumpWidget(host(callInfo: _w1aw, message: 'Tune to **14285**'));
    await tester.tap(find.byType(MarkdownBody));
    expect((callTaps, operationTaps), (2, 4), reason: 'the message has the space, and the host no call to open');
  });
}
