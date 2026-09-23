// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The tentative fill a slid spot row offers: filling the fields and
// withdrawing them, the next spot replacing the last, and a suggestion that
// would overwrite the operator's typing being held and put to them instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  // A spot row slid open far enough to peek fills these fields, and the fill
  // is the OPEN ROW's: it goes back out when the row closes, and it is never
  // the "work in progress" that the next suggestion — or the log request that
  // ends the very same slide — has to ask the operator about.
  group('a tentative suggestion from a slid spot row', () {
    const spotA = {
      'their': {'call': 'K1ABC'},
      'band': '20m',
      'mode': 'SSB',
    };
    const spotB = {
      'their': {'call': 'W2DEF'},
      'band': '20m',
      'mode': 'SSB',
    };

    String callIn(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call').first).controller?.text ?? '';

    testWidgets('fills the fields, and withdrawing it empties them again', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      expect(callIn(tester), 'K1ABC');

      // The row closed — dragged back, scrolled away, set aside. The operator
      // is visibly done with that spot, and a call left behind here is what
      // the next Log would go out as.
      await tester.pumpWidget(host());
      await tester.pump();

      expect(callIn(tester), isEmpty);
    });

    testWidgets('the next spot replaces the last one without asking', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      // Sliding the next row: its withdrawal and its suggestion land in the
      // same widget update, so the panel never sees the fields empty. The
      // mutation this catches is counting the last peek's own fill as work —
      // which makes every spot after the first raise a prompt.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotB,
            suggestedQsoIsTentative: true,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      expect(callIn(tester), 'W2DEF');
      expect(asked, 0, reason: 'the call it replaced was the previous peek\'s, not the operator\'s');
    });

    testWidgets('the operator working the call field says so; a suggestion filling it does not', (tester) async {
      // What the spots list closes an open row on. A suggestion arriving must
      // never look like this, or filling the fields would close the very row
      // that filled them — and take its own fill back out on the way.
      var edited = 0;

      await tester.pumpWidget(host(session: LoggingSession(onCallEdited: () => edited++)));
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true, onCallEdited: () => edited++),
        ),
      );
      await tester.pumpAndSettle();
      expect(callIn(tester), 'K1ABC');
      expect(edited, 0, reason: 'a spot arriving is not the operator composing anything');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();
      expect(edited, greaterThan(0), reason: 'typing is');

      // And the wipe button, which is the other way the operator empties it.
      final before = edited;
      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, onCallEdited: () => edited++),
        ),
      );
      await tester.pumpAndSettle();
      expect(edited, before, reason: 'the suggestion that replaced it is still not an edit');
    });

    testWidgets('a call a TAP chose does not block the next slide either', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      // A tap: a station chosen outright, not a peek. The operator picked it,
      // but they did not COMPOSE an entry — so the next spot replaces it the
      // same way, without a prompt standing between the slide and the fields.
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA)));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'K1ABC');

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotB,
            suggestedQsoIsTentative: true,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF');
      expect(asked, 0);
    });

    testWidgets('a callsign the field rewrites under the panel is still the suggestion\'s', (tester) async {
      // The call field's listener fires for programmatic writes exactly as it
      // does for typing, so "the operator has taken this over" cannot be
      // decided there. Whatever kicks the field — a command expansion, a pane
      // save, a formatter on a slashed call — the text is what says whose the
      // entry is. The mutation this catches is going back to a listener flag:
      // one spurious fire and every slide after it is refused in silence.
      var asked = 0;
      const slashed = {
        'their': {'call': 'EA3/KI2D'},
        'band': '20m',
        'mode': 'SSB',
      };

      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: slashed, suggestedQsoIsTentative: true)));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'EA3/KI2D');

      // Rewritten to the very same text, which is what a formatter or an
      // expansion that changes nothing does — and which fires the listener.
      tester.widget<TextField>(find.widgetWithText(TextField, 'Their call').first).controller!.value = const TextEditingValue(
        text: 'EA3/KI2D',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotB,
            suggestedQsoIsTentative: true,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF', reason: 'the slide still hands the fields to the new spot');
      expect(asked, 0);
    });

    testWidgets('typing over the fill makes it the operator\'s, and it survives the row closing', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC/P');
      await tester.pump();

      await tester.pumpWidget(host());
      await tester.pump();

      expect(callIn(tester), 'K1ABC/P', reason: 'a station the operator has worked on is theirs, not the row\'s');
    });

    testWidgets('is held over a part-typed call, and put to the operator when the gesture settles', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      // Mid-drag. A dialog here takes the pointer while the drag runs on
      // underneath it, and the release still commits.
      expect(asked, 0, reason: 'the finger is still on the row');
      expect(callIn(tester), 'W9XYZ', reason: 'and the fields are still the operator\'s');

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(asked, 1, reason: 'the row came to rest, so the conflict can be put to them');
      expect(callIn(tester), 'W9XYZ', reason: 'they said go back — their entry stands');
    });

    testWidgets('the prompt is a real route, raised in a frame that can take one', (tester) async {
      // The harness callbacks elsewhere in this group return a Future without
      // ever pushing anything, which is precisely what let a Navigator assert
      // ("!navigator._debugLocked") reach the operator instead of a test: the
      // ask is made from didUpdateWidget, and a route pushed while the
      // framework is mid-flush trips over itself when its push animation
      // lands. Only a callback that pushes a real dialog exercises that.
      Future<bool> ask({required bool editing}) async {
        final context = tester.element(find.byType(LoggingControls));
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('Clear it?'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Go back'))],
          ),
        );
        return answer ?? false;
      }

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true, confirmLogOverwrite: ask),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true, suggestionSettledSerial: 1, confirmLogOverwrite: ask),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the dialog went up without the Navigator objecting');
      expect(find.text('Clear it?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
    });

    testWidgets('clearing the way at the prompt hands the fields to the spot', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            confirmLogOverwrite: ({required bool editing}) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callIn(tester), 'K1ABC');
    });

    testWidgets('a peek held on the way in does not outlive the commit that follows it', (tester) async {
      // The whole slide is one gesture: the peek asks to take the fields, the
      // commit asks to log over them. Held past the commit, the peek's
      // question survives the log — and the next row the operator slides is
      // the one that pays. Its own peek fills the fields, then ITS settle
      // fires the stale question, which by then has nothing left to ask about
      // and so goes straight through: the station they just slid to is
      // replaced by the one they finished with, and the VFO follows it.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      // Slide row A: peek (held, a call is in progress)...
      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true, confirmLogOverwrite: ({required bool editing}) async => true),
        ),
      );
      await tester.pump();
      // ...then the same drag carried through to the commit, which arrives
      // with a fresh suggestion of its own alongside the request.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: Map<String, dynamic>.from(spotA),
            suggestedQsoIsTentative: true,
            logRequest: (serial: 1, qso: spotA),
            confirmLogOverwrite: ({required bool editing}) async => true,
          ),
        ),
      );
      await waitForQsos(tester, 1);

      // Slide row B: its peek lands in an empty panel, so it simply applies.
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotB, suggestedQsoIsTentative: true)));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'W2DEF');

      // B's row comes to rest.
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotB, suggestedQsoIsTentative: true, suggestionSettledSerial: 1)));
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF', reason: 'the spent peek did not reach back in and replace it');
    });

    testWidgets('a held suggestion the row took back while the dialog was up is dropped', (tester) async {
      // The prompt is a wait, and the row that raised it can close or be
      // discarded while it is up — which takes the suggestion back. Applying
      // it on the way out fills the fields and retunes the radio for a row
      // that is gone, and the withdrawal that would have undone it has
      // already happened: nothing is left that can take it back.
      final completer = Completer<bool>();

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true, confirmLogOverwrite: ({required bool editing}) => completer.future),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            confirmLogOverwrite: ({required bool editing}) => completer.future,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The row goes away while the operator is still looking at the dialog.
      await tester.pumpWidget(host(session: LoggingSession(confirmLogOverwrite: ({required bool editing}) => completer.future)));
      await tester.pump();

      // ...and only then do they answer it.
      completer.complete(true);
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W1AW', reason: 'their own entry stands; the withdrawn spot never lands');
    });

    testWidgets('a suggestion parked behind an edit lands the moment the edit is cancelled', (tester) async {
      // Parked work drains from the branch that CLEARS the edit, not merely
      // from the bottom of didUpdateWidget — that branch returns before ever
      // reaching it. Draining only at the bottom leaves the suggestion sitting
      // there until some unrelated rebuild (a spot poll, a clock tick) happens
      // along, by which time it lands on top of whatever has been typed since,
      // and moves the VFO with it.
      final edited = Qso(
        uuid: 'q1',
        operationUuid: operation.uuid,
        data: const {
          'their': {'call': 'W1AW'},
        },
      );
      var cancels = 0;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: edited)));
      await tester.pump();
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            editingQso: edited,
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            onEditCanceled: () => cancels++,
            confirmLogOverwrite: ({required bool editing}) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cancels, 1, reason: 'the operator cleared the way');

      // The edit going away IS the update that must apply it. Nothing else is
      // pumped here — no poll, no later rebuild to be rescued by.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            onEditCanceled: () => cancels++,
            confirmLogOverwrite: ({required bool editing}) async => true,
          ),
        ),
      );
      await tester.pump();

      expect(callIn(tester), 'K1ABC');
    });

    testWidgets('a held suggestion whose conflict is gone is applied, not put to the operator', (tester) async {
      // Held over a part-typed call; by the time the gesture settles the
      // operator has cleared it themselves. Asking anyway offers to overwrite
      // an empty panel, which teaches them the prompt means nothing.
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            suggestionSettledSerial: 1,
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(asked, 0);
      expect(callIn(tester), 'K1ABC', reason: 'the spot takes the fields it no longer has to fight for');
    });

    testWidgets('the commit that ends the same slide does not ask about the peek\'s own fill', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(session: LoggingSession(suggestedQso: spotA, suggestedQsoIsTentative: true)));
      await tester.pump();
      expect(callIn(tester), 'K1ABC');

      // Dragging on past the commit point: the panel is holding this very
      // spot's callsign, put there by this very gesture. Treating that as work
      // at risk puts a prompt in front of every slide-to-log there is.
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            suggestedQso: spotA,
            suggestedQsoIsTentative: true,
            logRequest: (serial: 1, qso: spotA),
            confirmLogOverwrite: ({required bool editing}) async {
              asked++;
              return false;
            },
          ),
        ),
      );

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0);
      expect(logged.single.data['their']['call'], 'K1ABC');
    });
  });
}
