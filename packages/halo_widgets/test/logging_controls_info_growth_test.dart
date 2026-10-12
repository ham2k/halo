// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The entry row never moves under the operator's hands. The info area grows
// with what it shows — a call's lookup and scoring pills, wrapped onto lines
// of their own when they name their scorers — and that growth goes away from
// the fields: up into the log below the panel, down into it above.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart';

import 'support/logging_controls_harness.dart';

/// Enough named pills to run past a phone-width line and wrap.
Future<Map<String, dynamic>?> _disagreeingScorers({
  required Map<String, dynamic> operation,
  required Map<String, dynamic> qso,
  String? excludeUuid,
  List<Map<String, dynamic>>? segments,
}) async => {
  'alerts': ['duplicate'],
  'notices': ['newDay', 'newMult', 'newBand'],
  'sources': {
    'duplicate': ['PAQP'],
    'newDay': ['POTA'],
    'newMult': ['CQWW', 'PAQP'],
    'newBand': ['POTA'],
  },
};

void main() {
  installLoggingHarness();

  for (final aboveLog in [false, true]) {
    testWidgets('the fields stay put while the info area grows ${aboveLog ? 'below them' : 'above them'}', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          prefs: LoggingPreferences(aboveLog: aboveLog),
          lookups: const LookupHooks(scoreQso: _disagreeingScorers),
        ),
      );
      await tester.pumpAndSettle();
      final call = find.widgetWithText(TextField, 'Their call');
      final fieldsBefore = tester.getRect(call);
      final infoBefore = tester.getRect(find.byType(LoggingInfoFrame));

      await tester.enterText(call, 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final info = tester.getRect(find.byType(LoggingInfoFrame));
      final pillLines = {
        for (final label in ['PAQP: DUPE', 'CQWW, PAQP: newMult']) tester.getTopLeft(find.text(label)).dy,
      };
      expect(pillLines.length, 2, reason: 'the pills wrapped, so the area grew by more than a line');
      expect(info.height, greaterThan(infoBefore.height));
      expect(tester.getRect(call), fieldsBefore);
      if (aboveLog) {
        expect(info.top, infoBefore.top, reason: 'grown downward, into the log');
      } else {
        expect(info.bottom, infoBefore.bottom, reason: 'grown upward, into the log');
      }
    });
  }
}
