// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingPreferences.aboveLog: the panel drawn ABOVE its QSO list, as the
// Chasing view draws it. Every part that sits against "the edge next to the
// list" has to move to the other edge — the fields meet the top of the panel,
// the pills and what they open meet the list below, and a menu that floats
// over the info area has to float DOWN to where the info area now is.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart';

import 'support/logging_controls_harness.dart';

const _counties = [
  {'code': 'ASD', 'name': 'Ashland'},
  {'code': 'CUY', 'name': 'Cuyahoga'},
  {'code': 'WAS', 'name': 'Washington'},
];

final _countyControls = [
  {
    'key': 'qp/county',
    'label': 'County',
    'icon': 'flag-checkered',
    'input': {'kind': 'options', 'refType': 'qp', 'field': 'county', 'options': _counties},
  },
];

void main() {
  installLoggingHarness();

  testWidgets('above the log the panel stacks fields, info, then the pills, and a pill opens downward', (tester) async {
    await tester.pumpWidget(host(prefs: const LoggingPreferences(aboveLog: true)));
    await tester.pump();

    final call = tester.getRect(find.widgetWithText(TextField, 'Their call'));
    final info = tester.getRect(find.byType(LoggingInfoFrame));
    final pills = tester.getRect(find.byType(SecondaryControlRow));
    expect(call.bottom, lessThanOrEqualTo(info.top), reason: 'the fields meet the top of the panel');
    expect(info.bottom, lessThanOrEqualTo(pills.top), reason: 'the pills sit at the edge the list is on');

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    final timeChip = tester.getRect(find.byType(ChoiceChip).first);
    final timeField = tester.getRect(find.widgetWithText(TextField, 'Time (UTC)'));
    expect(timeField.top, greaterThan(timeChip.bottom), reason: 'an open control expands toward the list, below its pill');
  });

  // The menu floats over the info area rather than pushing the fields under
  // the operator's hands. Above the log that area is BELOW the field — a menu
  // still floating up would cover the panel's top edge and the view's header.
  testWidgets('the suggestions menu opens below its field, best match nearest it, and Down walks away from it', (tester) async {
    await tester.pumpWidget(
      host(
        prefs: const LoggingPreferences(aboveLog: true),
        log: LogHooks(operation: running(['qp']), qsosRepository: qsos),
        activities: ActivityHooks(activityControls: _countyControls),
      ),
    );
    await tester.tap(find.widgetWithText(TextField, 'County'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
    await tester.pump();

    final menu = find.byKey(exchangeSuggestionsKey);
    final follower = tester.widget<CompositedTransformFollower>(menu);
    expect(follower.targetAnchor, Alignment.bottomLeft, reason: 'hung off the bottom of the field');
    expect(follower.followerAnchor, Alignment.topLeft);
    expect(follower.offset.dy, greaterThan(0));

    Finder inMenu(String text) => find.descendant(of: menu, matching: find.text(text));
    expect(
      tester.getCenter(inMenu('ASD')).dy,
      lessThan(tester.getCenter(inMenu('WAS')).dy),
      reason: 'the best match is the row nearest the field: the top one',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.widget<Text>(inMenu('WAS')).style?.fontWeight, FontWeight.w700, reason: 'Down moves away from the field, to the next match');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.widget<Text>(inMenu('ASD')).style?.fontWeight, FontWeight.w700, reason: 'and Up back toward it');
  });
}
