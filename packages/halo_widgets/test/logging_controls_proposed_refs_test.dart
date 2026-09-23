// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// References a lookup proposes: logged on the contact, never replacing one
// the operator entered, taken back when the callsign changes, and kept
// across a wipe or a detour through an earlier contact.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('references proposed by a lookup', () {
    // What `spot-history` returns: a park it found on a recent spot for the
    // call being typed. The QSO must end up carrying it without the operator
    // touching the POTA chip (HALO-80).
    const hunter = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'potaHunter'},
    };

    /// A lookup returning [refs] on the guess, counting its own calls so a
    /// re-lookup loop shows up as an ever-growing number rather than a hang.
    ({
      Future<Map<String, dynamic>?> Function(
        String, {
        required Map<String, dynamic> qso,
        required Map<String, dynamic> operation,
        required bool online,
        bool recentContext,
      })
      fn,
      List<Map<String, dynamic>> seenQsos,
      List<bool> seenRecentContext,
    })
    refLookup(List<Map<String, dynamic>> refs, {String forCall = 'W1AW'}) {
      final seenQsos = <Map<String, dynamic>>[];
      final seenRecentContext = <bool>[];
      Future<Map<String, dynamic>?> fn(
        String call, {
        required Map<String, dynamic> qso,
        required Map<String, dynamic> operation,
        required bool online,
        bool recentContext = false,
      }) async {
        seenQsos.add(qso);
        seenRecentContext.add(recentContext);
        if (call != forCall) return null;
        return {
          'guess': {'name': 'ARRL HQ', 'refs': refs},
        };
      }

      return (fn: fn, seenQsos: seenQsos, seenRecentContext: seenRecentContext);
    }

    Future<void> typeCall(WidgetTester tester, String call) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
      await tester.pump(const Duration(milliseconds: 350)); // past the lookup debounce
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a park from the guess is logged on the QSO', (tester) async {
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-1234'},
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );

      await typeCall(tester, 'W1AW');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect((logged.single.data['refs'] as List).cast<Map>(), contains(containsPair('ref', 'US-1234')));
    });

    testWidgets('composing a contact asks for recent context; editing a logged one does not', (tester) async {
      // `recentContextLookup` hooks answer "what is this station doing right
      // now". That is a question about a contact in progress — asked while
      // editing a QSO logged an hour ago, a current spot describes a park the
      // station may have reached long after the contact ended. The gate lives
      // here, at the request, so those hooks are never even consulted rather
      // than each having to recognize a context it cannot see.
      final composing = refLookup(const []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: composing.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await typeCall(tester, 'W1AW');
      expect(composing.seenRecentContext, isNotEmpty);
      expect(composing.seenRecentContext, everyElement(isTrue));

      // A different call from the one typed below, so the edit genuinely
      // changes it — retyping the record's own call is an early return in
      // `_scheduleLookup` and no lookup would fire at all.
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'K1ABC'},
          'startAtMillis': 1000000,
          'freq': 14285.0,
        }),
      ))!;
      final editing = refLookup(const []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: editing.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await typeCall(tester, 'W1AW');
      expect(editing.seenRecentContext, isNotEmpty, reason: 'the lookup still runs when editing');
      expect(editing.seenRecentContext, everyElement(isFalse));
    });

    testWidgets('a ref the operator already entered is never replaced by the guess', (tester) async {
      // The operator's own park outranks one mined from a spot: a spot can be
      // stale, or for the wrong one of two parks, and silently rewriting what
      // was typed would put the wrong reference in the log.
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-9999'},
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(
                // Shaped like a real spot tap — band and mode included, since a
                // suggestedQso replaces the radio-seeded ones and a QSO carrying
                // neither refuses to log (HALO-24).
                suggestedQso: const {
                  'band': '20m',
                  'mode': 'SSB',
                  'refs': [
                    {'type': 'potaHunter', 'ref': 'US-0001'},
                  ],
                },
              ),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await tester.pump();

      await typeCall(tester, 'W1AW');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      final refs = (logged.single.data['refs'] as List).cast<Map>();
      expect(refs, contains(containsPair('ref', 'US-0001')));
      expect(refs, isNot(contains(containsPair('ref', 'US-9999'))));
      // And exactly one potaHunter ref — not the operator's plus the guess's.
      expect(refs.where((r) => r['type'] == 'potaHunter'), hasLength(1));
    });

    testWidgets('correcting the callsign takes back the ref guessed for the old one', (tester) async {
      // KI2D is spotted at US-2080, so typing it brings the park in. Fixing
      // the call to KI2E must not log KI2E at KI2D's park — the ref answered
      // a question about a station that is no longer the one being worked.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'},
      ], forCall: 'KI2D');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'the park was picked up');

      // Backspace, then a different suffix — the ref must be gone at the
      // intermediate step, not merely replaced once KI2E resolves.
      await typeCall(tester, 'KI2');
      expect(find.text('✓ POTA'), findsNothing);
      expect(find.text('POTA'), findsOneWidget, reason: 'the chip stays, without a reference');

      await typeCall(tester, 'KI2E');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect(logged.single.theirCall, 'KI2E');
      expect((logged.single.data['refs'] as List?) ?? const [], isNot(contains(containsPair('ref', 'US-2080'))));
    });

    testWidgets('taking back a guessed ref leaves the operator\'s own alone', (tester) async {
      // The mirror of the test above: removal must be targeted at the refs
      // this widget inserted, not a blanket wipe. Silently deleting the
      // operator's own park because they fixed a typo in the call would be
      // worse than the bug being fixed. Both kinds are present here at once —
      // the guessed summit must go, the typed park must stay.
      final lookup = refLookup(const [
        {'type': 'sotaHunter', 'ref': 'W2/GC-001'},
      ], forCall: 'KI2D');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(
                suggestedQso: const {
                  'band': '20m',
                  'mode': 'SSB',
                  'refs': [
                    {'type': 'potaHunter', 'ref': 'US-0001'},
                  ],
                },
              ),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await tester.pump();

      await typeCall(tester, 'KI2D');
      await typeCall(tester, 'KI2E');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      final refs = (logged.single.data['refs'] as List).cast<Map>();
      expect(refs, contains(containsPair('ref', 'US-0001')), reason: "the operator's park");
      expect(refs, isNot(contains(containsPair('ref', 'W2/GC-001'))), reason: "KI2D's summit");
    });

    testWidgets('a guess is taken back even after the operator typed in the open POTA field', (tester) async {
      // The chip is open BEFORE the guess lands, so the field is handed the
      // park after it was built and re-emits it on the next keystroke. The
      // take-back is by identity: only the map the field hands back being the
      // one the guess put there keeps KI2E off KI2D's park — and the field
      // has to be told the list changed, or it goes on showing the park.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'},
      ], forCall: 'KI2D');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await openControl(tester, MdiIcons.pineTree);
      TextField potaField() => tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
      // A park typed and deleted again leaves the field holding an empty
      // list — the one a guess could grow in place without the field noticing.
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-0001');
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), '');
      await tester.pump();
      expect(potaField().controller!.text, isEmpty);

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget);
      expect(potaField().controller!.text, 'US-2080', reason: 'the field shows what the chip counts');

      // The operator deletes the park. The re-lookup that triggers proposes
      // it again — and must not put it back into the field they just cleared.
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(potaField().controller!.text, isEmpty, reason: 'a guess the operator removed stays removed');
      expect(find.text('✓ POTA'), findsNothing);

      // Typed back in on purpose, then a keystroke on the way to a second park.
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-2080');
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-2080,');
      await tester.pump();
      expect(find.text('✓ POTA'), findsOneWidget);

      await typeCall(tester, 'KI2E');
      expect(find.text('✓ POTA'), findsNothing);
      expect(potaField().controller!.text, isEmpty, reason: 'the field agrees with the chip');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirCall, 'KI2E');
      expect((logged.single.data['refs'] as List?) ?? const [], isNot(contains(containsPair('ref', 'US-2080'))));
    });

    testWidgets('stacking a second call keeps the ref the first one earned', (tester) async {
      // "KI2D,W1AW" logs one QSO per call and they share the ref list, so a
      // park one of them was spotted at is carried by both — two operators
      // activating together is exactly what produces a call list. Typing the
      // comma moves the cursor off KI2D without correcting it, which is the
      // distinction the clearing has to draw: the call left the CURSOR, not
      // the field.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'},
      ], forCall: 'KI2D');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget);

      await typeCall(tester, 'KI2D,W1AW');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'KI2D is still in the field');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      for (final qso in logged) {
        expect((qso.data['refs'] as List).cast<Map>(), contains(containsPair('ref', 'US-2080')), reason: '${qso.theirCall} shares the stack\'s park');
      }
    });

    testWidgets('correcting the callsign back again brings its ref along', (tester) async {
      // The lookup is cached per call, so re-typing KI2D reaches it only
      // through that cache hit — a path that skips the fetch and everything
      // hung off it. Without applying refs there too, the info panel would
      // show KI2D's guess while the park it names is missing from the QSO.
      // Only reachable once guessed refs are cleared on a call change, which
      // is what makes this a pair with the test above.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'},
      ], forCall: 'KI2D');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );
      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'picked up the first time');
      await typeCall(tester, 'KI2E');
      expect(find.text('✓ POTA'), findsNothing, reason: 'taken back for KI2E');
      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: "back on KI2D, so the park is KI2D's again");
    });

    testWidgets('applying a ref settles instead of re-triggering itself forever', (tester) async {
      // Applying a ref re-runs the lookup (the POTA hook needs to see the
      // park to resolve its grid), and the lookup proposes refs — the exact
      // shape of an endless loop if an already-applied ref were re-applied.
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-1234'},
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(lookup: lookup.fn),
              activities: ActivityHooks(activityControls: const [hunter]),
            ),
          ),
        ),
      );

      await typeCall(tester, 'W1AW');
      // Let any re-lookup rounds play out.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
      }
      final settled = lookup.seenQsos.length;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(lookup.seenQsos.length, settled, reason: 'the lookup stopped re-firing');

      // And the park did reach the hooks: some pass saw it on the QSO it was
      // handed, which is the whole reason for the re-lookup.
      expect(lookup.seenQsos.any((qso) => (qso['refs'] as List?)?.any((ref) => (ref as Map)['ref'] == 'US-1234') ?? false), isTrue);
    });

    // A restore puts the refs back as plain data, and plain data cannot say
    // which of them a lookup proposed. Without the provenance travelling
    // beside the draft, a restored park reads as the operator's own and no
    // correction to the callsign ever takes it back — the contact is logged
    // at a park the station was never at, with the chip lit and nothing on
    // screen wrong.
    group('a guess survives the draft being parked and put back', () {
      Widget hostWithGuess(
        ({
          Future<Map<String, dynamic>?> Function(
            String, {
            required Map<String, dynamic> qso,
            required Map<String, dynamic> operation,
            required bool online,
            bool recentContext,
          })
          fn,
          List<Map<String, dynamic>> seenQsos,
          List<bool> seenRecentContext,
        })
        lookup, {
        Qso? editingQso,
      }) => MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            session: LoggingSession(editingQso: editingQso, onEditCanceled: () {}),
            radio: baseRadio(),
            lookups: LookupHooks(lookup: lookup.fn),
            activities: ActivityHooks(activityControls: const [hunter]),
          ),
        ),
      );

      testWidgets('a wipe undone keeps the park a lookup proposed, so correcting the call still takes it back', (tester) async {
        final lookup = refLookup(const [
          {'type': 'potaHunter', 'ref': 'US-2080'},
        ], forCall: 'KI2D');
        await tester.pumpWidget(hostWithGuess(lookup));

        await typeCall(tester, 'KI2D');
        expect(find.text('✓ POTA'), findsOneWidget, reason: 'the park was picked up');

        await tester.tap(find.bySemanticsIdentifier('action.wipe'));
        await tester.pump();
        await tester.tap(find.byIcon(MdiIcons.undo));
        await tester.pump();
        expect(find.text('✓ POTA'), findsOneWidget, reason: 'the undo brought the park back');

        // The correction. This is the assertion the bug turned vacuous: the
        // park came back unmarked, so nothing recognised it as the old
        // call's and KI2E was logged at KI2D's park.
        await typeCall(tester, 'KI2E');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await waitForQsos(tester, 1);

        expect(logged.single.theirCall, 'KI2E');
        expect(
          (logged.single.data['refs'] as List?) ?? const [],
          isNot(contains(containsPair('ref', 'US-2080'))),
          reason: 'the park answered a question about KI2D, who is not the station being worked',
        );
      });

      testWidgets('a detour through an earlier contact keeps it too', (tester) async {
        final lookup = refLookup(const [
          {'type': 'potaHunter', 'ref': 'US-2080'},
        ], forCall: 'KI2D');
        await tester.pumpWidget(hostWithGuess(lookup));

        await typeCall(tester, 'KI2D');
        expect(find.text('✓ POTA'), findsOneWidget);

        // Away to an earlier contact and back — the draft is parked and
        // restored, exactly as the undo path does it.
        final earlier = (await tester.runAsync(
          () => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
            'freq': 14285.0,
          }),
        ))!;
        await tester.pumpWidget(hostWithGuess(lookup, editingQso: earlier));
        await tester.pump();
        await tester.pumpWidget(hostWithGuess(lookup));
        await tester.pump();
        expect(find.text('✓ POTA'), findsOneWidget, reason: 'the parked draft came back with its park');

        await typeCall(tester, 'KI2E');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await waitForQsos(tester, 2);
        final composed = logged.firstWhere((qso) => qso.theirCall == 'KI2E');

        expect((composed.data['refs'] as List?) ?? const [], isNot(contains(containsPair('ref', 'US-2080'))));
      });

      testWidgets('a guess the operator deleted before the wipe stays deleted after the undo', (tester) async {
        // The other half of the provenance: the model gives a guess once per
        // call, so that deleting one does not simply invite the re-lookup to
        // put it straight back. An undo that restored only the refs still in
        // the field would lose that, and hand back the park just removed.
        final lookup = refLookup(const [
          {'type': 'potaHunter', 'ref': 'US-2080'},
        ], forCall: 'KI2D');
        await tester.pumpWidget(hostWithGuess(lookup));

        await typeCall(tester, 'KI2D');
        expect(find.text('✓ POTA'), findsOneWidget);

        // Delete it from the field the operator's own way.
        await tester.tap(find.ancestor(of: find.text('✓ POTA'), matching: find.byType(ChoiceChip)));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'POTA'), '');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(find.text('✓ POTA'), findsNothing, reason: 'the operator removed it');

        await tester.tap(find.bySemanticsIdentifier('action.wipe'));
        await tester.pump();
        await tester.tap(find.byIcon(MdiIcons.undo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(find.text('✓ POTA'), findsNothing, reason: 'the re-lookup must not hand back the park the operator deleted');
      });
    });
  });
}
