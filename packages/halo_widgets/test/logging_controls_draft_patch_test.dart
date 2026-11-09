// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's change to the QSO being composed (`host.updateDraft`): laid
// over the fields as they stand, so what it does not name stays as typed,
// and the field the operator is typing in keeps its caret — a patch can land
// mid-keystroke, and a caret thrown to the end of the call puts the next
// letter in the wrong place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('mergeDraftPatch', () {
    test('merges maps key by key, takes a key out for a null, and replaces anything else whole', () {
      final base = {
        'their': {'call': 'W1AW', 'sent': '599'},
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
        'notes': 'old',
      };
      final merged = mergeDraftPatch(base, {
        'their': {'sent': '579', 'grid': 'FN31'},
        'refs': [
          {'type': 'sota', 'ref': 'W1/HA-001'},
        ],
        'notes': null,
      });
      expect(merged, {
        'their': {'call': 'W1AW', 'sent': '579', 'grid': 'FN31'},
        'refs': [
          {'type': 'sota', 'ref': 'W1/HA-001'},
        ],
      });
      expect(base['their'], {'call': 'W1AW', 'sent': '599'}, reason: 'the draft it was read from is not written');
    });
  });

  group('a draft patch', () {
    TextField field(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    testWidgets('changes only what it names, and the field being typed in keeps its caret', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      final call = field(tester, 'Their call').controller!;
      call.selection = const TextSelection.collapsed(offset: 2);

      await tester.pumpWidget(
        host(
          session: const LoggingSession(
            draftPatch: (
              serial: 1,
              patch: {
                'their': {'sent': '579'},
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(field(tester, 'Rcvd').controller!.text, '579');
      expect(call.text, 'W1AW');
      expect(call.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('may change the call itself, and the same serial again changes nothing', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      const patched = LoggingSession(
        draftPatch: (
          serial: 1,
          patch: {
            'their': {'call': 'K1ABC'},
          },
        ),
      );
      await tester.pumpWidget(host(session: patched));
      await tester.pump();
      expect(field(tester, 'Their call').controller!.text, 'K1ABC');

      // The operator types over it; a rebuild carrying the same patch is not
      // a second one, and must not put the assistant's call back.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0DEV');
      await tester.pumpWidget(host(session: patched));
      await tester.pump();
      expect(field(tester, 'Their call').controller!.text, 'N0DEV');
    });
  });
}
