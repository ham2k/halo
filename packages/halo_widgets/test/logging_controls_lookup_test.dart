// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the panel learns about a callsign and shows for it: the information
// area, worked-before, the background lookup queue, the references a lookup
// proposes, and the More pane's station fields.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('info area (issue #40)', () {
    Future<Map<String, dynamic>?> Function(String,
            {required Map<String, dynamic> qso,
            required Map<String, dynamic> operation,
            required bool online,
            bool recentContext}) guessLookup(
      Map<String, dynamic> guess,
    ) {
      return (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': guess};
    }

    Widget withWorkedBefore({
      required WorkedBefore workedBefore,
      Qso? editingQso,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(
                editingQso: editingQso,
              ),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: guessLookup({'name': 'Hiram'}),
                workedBefore: workedBefore,
                workedBeforeLabel: (times) => '${times.length} before',
              ),
            ),
          ),
        );

    // The argument is the whole reason an edited QSO is not its own prior
    // contact; nothing else fails when it is dropped.
    testWidgets('worked-before: an edit asks with its own QSO excluded, and shows the answer', (tester) async {
      final existing = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
            'freq': 7100,
            'mode': 'SSB',
          })))!;
      final asked = <(String, String?)>[];
      await tester.pumpWidget(withWorkedBefore(
        editingQso: existing,
        workedBefore: (call, {excludingQsoUuid}) async {
          asked.add((call, excludingQsoUuid));
          return [500];
        },
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(asked, contains(('W1AW', existing.uuid)));
      expect(asked.where((a) => a.$1 == 'W1AW').every((a) => a.$2 == existing.uuid), isTrue);
      expect(find.text('1 before'), findsOneWidget);
    });

    // The trap: the worked-before fetch used to hang off the lookup's own
    // scheduling, below its `_lookupFor == activeCall` early return. A typo
    // and the backspace correcting it leave `_lookupFor` still naming the
    // original call, so that return fires — and the pill, cleared for the
    // typo, was never fetched again for the rest of the call's life.
    testWidgets('worked-before: survives a typo corrected before the lookup debounce fires', (tester) async {
      final pending = <String, Completer<List<int>>>{};
      await tester.pumpWidget(withWorkedBefore(
        workedBefore: (call, {excludingQsoUuid}) => (pending[call] ??= Completer()).future,
      ));
      final field = find.widgetWithText(TextField, 'Their call');

      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      pending['W1AW']!.complete([1, 2, 3]);
      await tester.pump();
      expect(find.text('3 before'), findsOneWidget);

      // The typo, and the correction before its 300ms lookup debounce fires.
      await tester.enterText(field, 'W1AX');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('3 before'), findsOneWidget);
    });

    testWidgets('worked-before: an answer for a call no longer at the cursor is dropped', (tester) async {
      final pending = <String, Completer<List<int>>>{};
      await tester.pumpWidget(withWorkedBefore(
        workedBefore: (call, {excludingQsoUuid}) => (pending[call] ??= Completer()).future,
      ));
      final field = find.widgetWithText(TextField, 'Their call');
      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(field, 'K1ABC');
      await tester.pump(const Duration(milliseconds: 400));
      expect(pending.keys, containsAll(['W1AW', 'K1ABC']));

      // The first call's answer lands late, after the field moved on.
      pending['W1AW']!.complete([1, 2, 3]);
      await tester.pump();
      expect(find.text('3 before'), findsNothing);

      pending['K1ABC']!.complete([7]);
      await tester.pump();
      expect(find.text('1 before'), findsOneWidget);
    });

    testWidgets('idle (no call): renders the operation statistics lines', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              operationStatsLines: (_) => ['12 QSOs in 1h 5m', '48 Q/h for last 10'],
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('12 QSOs in 1h 5m'), findsOneWidget);
      expect(find.text('48 Q/h for last 10'), findsOneWidget);
    });

    testWidgets('call entered: flag, location line and name replace the stats', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: guessLookup({'flag': '🇮🇹', 'name': 'Marco', 'entityPrefix': 'I', 'country': 'Italy'}),
              callLocationLine: (guess) => '5,000 mi to • ${guess['country']}',
              operationStatsLines: (_) => ['stats-line-should-be-hidden'],
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle

      expect(find.text('🇮🇹'), findsOneWidget);
      expect(find.textContaining('5,000 mi to'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
      // Once a call of ≥3 chars is entered, the default stats give way to
      // the call-info panel.
      expect(find.text('stats-line-should-be-hidden'), findsNothing);
    });

    testWidgets('a grid typed with no call shows its distance line in place of the stats', (tester) async {
      // A microwave operator lines a dish up on a square before the other
      // station is named — polo shows the distance for a grid alone, and so
      // must this. Nothing else of call-info applies: no lookup ran, so the
      // line is all that appears, and it goes back to the stats the moment
      // the grid stops being complete.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              callLocationLine: (guess) => '${guess['grid']} is 42 km away',
              operationStatsLines: (_) => ['stats-line'],
            ),
            prefs: LoggingPreferences(
              showGridField: true,
            ),
          ),
        ),
      ));
      expect(find.text('stats-line'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle
      expect(find.text('FN20aa is 42 km away'), findsOneWidget);
      expect(find.text('stats-line'), findsNothing);

      // Half a grid points nowhere.
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN2');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('km away'), findsNothing);
      expect(find.text('stats-line'), findsOneWidget);
    });

    testWidgets("the Grid hint is the square the lookup's coordinate resolves to, not the one it filed", (tester) async {
      // A lookup that reports a coordinate has a SIX-character grid derived
      // beside it, whatever Grid Precision is in force. The hint must show
      // what would be stored if the operator left the field alone — the
      // locator that coordinate resolves to at their own precision
      // (docs/design/locations.md) — or the hint and the record disagree.
      GridPrecision.configure(GridPrecision.eight);
      addTearDown(GridPrecision.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {
                'guess': {'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278},
              },
            ),
            prefs: LoggingPreferences(
              showGridField: true,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final hint = tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).decoration!.hintText;
      expect(hint, locationToGrid8(41.7135, -72.7278));
      expect(hint, isNot('FN31pr'), reason: "the filed grid is coarser than the coordinate beside it");
    });

    testWidgets('a lookup that reports only a square hints that square, inventing no precision', (tester) async {
      // The other half: with no coordinate there is nothing finer to show, and
      // the stored square goes through as written however fine the setting is.
      GridPrecision.configure(GridPrecision.eight);
      addTearDown(GridPrecision.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {
                'guess': {'grid': 'FN31pr'},
              },
            ),
            prefs: LoggingPreferences(
              showGridField: true,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).decoration!.hintText, 'FN31pr');
    });

    testWidgets('a grid with nothing to say about it keeps the stats, rather than a blank info line', (tester) async {
      // The app answers null when the operation has no location of its own;
      // swapping the stats for an empty line would hide that the operator's
      // own grid is what's missing.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              callLocationLine: (guess) => null,
              operationStatsLines: (_) => ['stats-line'],
            ),
            prefs: LoggingPreferences(
              showGridField: true,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('stats-line'), findsOneWidget);
    });

    testWidgets("a contest's own grid exchange counts as the grid for the no-call distance line", (tester) async {
      // The 10 GHz events take the grid on their exchange field, not the core
      // Grid field — the descriptor names its ref field `grid`, and that is
      // what marks it.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(
              operation: running(['arrl-vhf-tests']),
              qsosRepository: qsos,
            ),
            radio: baseRadio(),
            lookups: LookupHooks(
              callLocationLine: (guess) => '${guess['grid']} is 42 km away',
              operationStatsLines: (_) => ['stats-line'],
            ),
            activities: ActivityHooks(
              activityControls: const [
                {
                  'key': 'arrl-vhf-tests/grid',
                  'label': 'Grid',
                  'input': {'kind': 'text', 'refType': 'arrl-vhf-tests', 'field': 'grid', 'maxLength': 6},
                },
              ],
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle
      expect(find.text('FN20aa is 42 km away'), findsOneWidget);
      expect(find.text('stats-line'), findsNothing);
    });

    testWidgets('a lookup note takes line 2 over the name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: guessLookup({'name': 'Marco', 'note': 'Old friend, always on 20m'}),
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Old friend, always on 20m'), findsOneWidget);
      expect(find.text('Marco'), findsNothing);
    });

    // The panel has always styled a note's links in its own tuned blue, but
    // MarkdownBody left them inert — the operator could read a note's QRZ or
    // socials link and not follow it.
    testWidgets('a link in a note opens through onOpenLink', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              onOpenLink: opened.add,
              lookup: guessLookup({'note': 'QSL via [the club](https://example.org/qsl)'}),
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      // The url itself never renders — only the label.
      expect(find.textContaining('https://example.org/qsl'), findsNothing);

      await tester.tapOnText(find.textRange.ofSubstring('the club'));
      await tester.pump();

      expect(opened, ['https://example.org/qsl']);
    });

    // The note-width measurement decides ONE thing: whether the note shares
    // line 2 with the pills or takes its own line above them. Asserting that
    // choice is the only way this test can fail if the measurement breaks —
    // an earlier version asserted only "no exception", which both branches
    // satisfy.
    testWidgets('the measured note shares line 2 when it fits, and takes its own line when it does not',
        (tester) async {
      Future<({Offset pill, Offset note})> layout(String note) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            // 700px wide on purpose. The note below measures 342 as spans and
            // 627 as raw markdown, and the fit test is
            // `pills(92.5) + gap(8) + note <= maxWidth`, so at this width the
            // span measurement fits and the raw one does not. At the default
            // 800 there is ~400px of slack and BOTH fit, which is why an
            // earlier version of this test could not fail.
            body: SizedBox(
              width: 700,
              // Keyed per note: without it the second pump reuses the same
              // State, whose guess is already cached for this callsign, and
              // the note never changes.
              child: LoggingControls(
                key: ValueKey(note),
                log: baseLog(),
                radio: baseRadio(),
                lookups: LookupHooks(
                  lookup: guessLookup({'note': note}),
                  scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                      {'notices': ['newDXCC'], 'alerts': <String>[]},
                ),
              ),
            ),
          ),
        ));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        return (
          pill: tester.getTopLeft(find.text('newDXCC')),
          note: tester.getTopLeft(find.byType(InlineMarkdownText)),
        );
      }

      // Heavily marked up on purpose: 342 as spans, 627 as raw markdown. Only
      // a measurement that parses the note fits it beside the pills here.
      final fits = await layout('**Great** **op** **and** **good** **friend**');
      expect(fits.pill.dx, greaterThan(fits.note.dx), reason: 'a short note should lead, with the pills beside it');
      expect((fits.pill.dy - fits.note.dy).abs(), lessThan(8), reason: 'on the same line');
      // Next to the note, not at the far right: a note row that filled the
      // line would leave the pills fitting but stranded.
      expect(fits.pill.dx, lessThan(fits.note.dx + 400), reason: 'the pills should hug the note');

      // Long: note takes line 2 on its own and the pills stack below it, so the
      // note starts at the column's left edge rather than trailing the pills.
      final wraps = await layout('Very long note about this operator ' * 8);
      // The note starts at the column's left edge; the pill's label is inset by
      // its own 6px padding, so the note is very slightly left of it.
      expect(wraps.note.dx, lessThan(wraps.pill.dx),
          reason: 'a note too wide for the row should start where the pills do, not trail them');
      expect(wraps.note.dy, lessThan(wraps.pill.dy), reason: 'and sit above them');
    });

    // A flag in the middle of a note is rendered as text, not rewritten into
    // an image, so the note's style is the only thing that can resolve it —
    // and Roboto resolves no emoji on web at all. Asserting the fallback
    // rather than the glyph: a widget test cannot see which font painted.
    testWidgets('a note carrying a flag styles it in the bundled emoji font', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            key: const ValueKey('flag-note'),
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: guessLookup({'note': 'from 🇺🇸 with **love**'}),
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                  {'notices': ['newDXCC'], 'alerts': <String>[]},
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      // The note paints as spans (InlineMarkdownText), so the style rides the
      // root TextSpan rather than a Text widget.
      final note = find.textContaining('love', findRichText: true);
      expect(note, findsOneWidget);
      expect(tester.widget<RichText>(note).text.style?.fontFamilyFallback, contains(emojiFontFamily));
    });

    testWidgets('scoreQso notices render as line-3 pills', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: guessLookup({'name': 'Marco'}),
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                  {'notices': ['newDXCC', 'newBand'], 'alerts': <String>[]},
              scoreNoticeLabel: (key) => const {'newDXCC': 'New DXCC', 'newBand': 'New Band'}[key] ?? key,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('New DXCC'), findsOneWidget);
      expect(find.text('New Band'), findsOneWidget);
    });

    testWidgets("the hook's dupe alert shows as a pill — and no DUPE chip in the control row", (tester) async {
      // Dupe detection now lives in the scoreQso hook (which knows the
      // operation's activities), not a client-side check — the widget just
      // renders whatever the hook returns.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                  {'notices': <String>[], 'alerts': ['duplicate']},
              scoreNoticeLabel: (key) => key == 'duplicate' ? 'Dupe!' : key,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));

      // The hook's dupe alert renders as a pill...
      expect(find.text('Dupe!'), findsOneWidget);
      // ...and never as a Chip in the secondary control row (issue #40).
      expect(find.widgetWithText(Chip, 'DUPE'), findsNothing);
    });

    testWidgets('scoreQso fires only for a plausible callsign, not junk input', (tester) async {
      final scored = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
                scored.add(((qso['their'] as Map)['call']) as String);
                return {'notices': <String>[], 'alerts': <String>[]};
              },
            ),
          ),
        ),
      ));

      // "QQQ" is ≥3 chars but not a plausible callsign — no whole-log scoring
      // pass should fire (the same gate the lookup uses).
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ');
      await tester.pump(const Duration(milliseconds: 500));
      expect(scored, isEmpty);

      // A real callsign triggers exactly one debounced scoring pass.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      expect(scored, ['W1AW']);
    });

    // New State is scored off `their.guess.state`, which the lookup resolves
    // AFTER the scoring debounce has already run against a QSO that had no
    // guess at all. Scoring once per call would show the pill only for a call
    // already in the lookup cache.
    testWidgets('a resolved lookup re-scores, so the guess it carries can be scored on', (tester) async {
      final scoredStates = <String?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: guessLookup({'state': 'CT'}),
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
                final their = qso['their'] as Map;
                scoredStates.add(((their['guess'] as Map?)?['state']) as String?);
                return {'notices': <String>[], 'alerts': <String>[]};
              },
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // The first pass runs before the lookup lands and legitimately has no
      // guess; what matters is that a later pass sees the resolved state.
      expect(scoredStates, contains('CT'));
    });

    // The operator typing a state is the other way it reaches the scorer.
    testWidgets('typing a state re-scores', (tester) async {
      final scoredStates = <String?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
                scoredStates.add(((qso['their'] as Map)['state']) as String?);
                return {'notices': <String>[], 'alerts': <String>[]};
              },
            ),
            prefs: LoggingPreferences(
              showStateField: true,
            ),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'State'), 'CT');
      await tester.pump(const Duration(milliseconds: 500));

      expect(scoredStates.last, 'CT');
    });
  });

  testWidgets('logging a comma-separated call list saves immediately without inline lookups; each entry is enqueued for background lookup', (tester) async {
    // Saving a call list must never block on N network lookups (a stall
    // with no connectivity): the QSOs land bare and each is handed to the
    // caller's background queue, which enriches them after the fact.
    final lookedUp = <String>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      lookedUp.add(call);
      return {'guess': {'name': 'Should Not Be Saved Inline'}};
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: lookup,
            enqueueLookup: enqueued.add,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    // Enter before the 300ms preview debounce fires — the save must not
    // depend on any lookup having started, let alone completed.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    // No lookup ran as part of the save, and nothing got attached inline...
    expect(lookedUp, isEmpty);
    expect(logged.every((q) => q.theirName == null), isTrue);
    // ...instead every new QSO was queued for background enrichment, in
    // logging order — a fresh, independent lookup per call, never one
    // cached result duplicated across different calls.
    expect(enqueued.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueued.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
  });

  testWidgets(
      'editing a QSO into a comma-separated list: the original record survives untouched; saving only enqueues the newly added call, not the original again',
      (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'name': 'Stale Cached Name', 'grid': 'FN31pr'},
          'startAtMillis': 1000000,
          // A real logged contact carries a frequency; editing one that has
          // neither band nor frequency is refused (HALO-24), which would stop
          // this test's save before it reached what it's actually about.
          'freq': 14285.0,
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          session: LoggingSession(
            editingQso: existingQso,
          ),
          radio: baseRadio(),
          lookups: LookupHooks(
            enqueueLookup: enqueued.add,
          ),
        ),
      ),
    ));
    // Opening it for editing enqueues it once, on its own (it never had an
    // online lookup) — asserted here so the rest of this test can focus on
    // what SAVING does, without that opening-time enqueue muddying it.
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid]);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    // The record being edited is untouched — not re-looked-up (inline or
    // via the queue), its own already-stored data survives exactly as
    // before: a background refresh would overwrite `guess` data the
    // operator may already be relying on.
    expect(w1aw.theirName, 'Stale Cached Name');
    expect(w1aw.theirGrid, 'FN31pr');
    // The newly added call is saved bare and queued for its own
    // independent background lookup, rather than inheriting anything
    // cached for the original call — and saving doesn't enqueue the
    // original record a second time.
    expect(k1abc.theirName, isNull);
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid, k1abc.uuid]);
  });

  testWidgets('constructed already editing a QSO enqueues it for a background lookup (ham2k/halo-dist#279 follow-up)',
      (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      lookups: LookupHooks(enqueueLookup: enqueued.add),
    ));

    // enqueueLookup itself decides (via LookupQueueService, tested
    // separately) whether the record actually needs a fresh lookup —
    // LoggingControls' job is just to always offer it up on open.
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid]);
  });

  testWidgets('selecting a different QSO to edit (not constructing already editing one) also enqueues it',
      (tester) async {
    final first = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
        })))!;
    final second = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'K1ABC'},
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: first),
      lookups: LookupHooks(enqueueLookup: enqueued.add),
    ));
    expect(enqueued.map((q) => q.uuid).toList(), [first.uuid]);

    // Same widget, editingQso transitions via didUpdateWidget — not a fresh
    // construction, the other code path that also has to enqueue.
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: second),
      lookups: LookupHooks(enqueueLookup: enqueued.add),
    ));
    expect(enqueued.map((q) => q.uuid).toList(), [first.uuid, second.uuid]);
  });

  testWidgets('a single-call log keeps its debounced preview result and is still handed to the background queue', (tester) async {
    final enqueued = <Qso>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      return {'guess': {'name': 'ARRL HQ'}};
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: lookup,
            enqueueLookup: enqueued.add,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400)); // let the preview lookup settle
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    // The cached preview result is written with the QSO...
    expect(logged.single.theirName, 'ARRL HQ');
    // ...and the saved record is still handed to the queue: the QUEUE
    // decides whether more lookup work is needed (it skips records that
    // already carry online data), so an Enter that beats the 300ms preview
    // debounce — leaving the record bare — still gets enriched.
    expect(enqueued.map((q) => q.uuid).toList(), [logged.single.uuid]);
  });

  testWidgets('command actions that add QSOs enqueue the whole batch for background lookup at once', (tester) async {
    // A command whose interpretation does not set `skipOnlineLookup` (e.g.
    // annotation-commands' WX/SOLAR event rows) gets its added QSOs batched
    // through enqueueAllLookups (not the per-QSO enqueueLookup), reusing the
    // same "Lookup all QSOs" bulk mechanism and progress reporting, fired
    // once the whole command has finished adding QSOs rather than QSO-by-QSO.
    Future<Map<String, dynamic>?> interpret(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input != 'ADDCMD') return null;
      return {
        'describe': 'Add QSOs?',
        'confirm': 'Added',
        'commands': [
          {'addQso': {'their': {'call': 'W1AW'}, 'startAtMillis': 1000000}},
          {'addQso': {'their': {'call': 'K1ABC'}, 'startAtMillis': 2000000}},
        ],
      };
    }

    final enqueuedSingly = <Qso>[];
    final enqueuedBatches = <List<Qso>>[];
    await tester.pumpWidget(host(
      lookups: LookupHooks(
        enqueueLookup: enqueuedSingly.add,
        enqueueAllLookups: (qsos) => enqueuedBatches.add(qsos.toList()),
      ),
      commands: CommandHooks(interpretCommand: interpret),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'ADDCMD');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    expect(enqueuedSingly, isEmpty, reason: 'batches through enqueueAllLookups, not per-QSO enqueueLookup');
    expect(enqueuedBatches, hasLength(1), reason: 'one batch for the whole command, not one call per QSO');
    expect(enqueuedBatches.single.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueuedBatches.single.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
  });

  testWidgets('a command interpretation with skipOnlineLookup (e.g. SEED) never enqueues its added QSOs for online lookup', (tester) async {
    // SEED's fabricated calls only ever carry the offline guess the
    // extension attached itself — there's no real online data to fetch, so
    // SEED sets `skipOnlineLookup` and the batch never reaches the queue.
    Future<Map<String, dynamic>?> interpret(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input != 'SEED') return null;
      return {
        'describe': 'Add seed QSOs?',
        'confirm': 'Added',
        'commands': [
          {'addQso': {'their': {'call': 'W1AW'}, 'startAtMillis': 1000000}},
          {'addQso': {'their': {'call': 'K1ABC'}, 'startAtMillis': 2000000}},
        ],
        'skipOnlineLookup': true,
      };
    }

    final enqueuedSingly = <Qso>[];
    final enqueuedBatches = <List<Qso>>[];
    await tester.pumpWidget(host(
      lookups: LookupHooks(
        enqueueLookup: enqueuedSingly.add,
        enqueueAllLookups: (qsos) => enqueuedBatches.add(qsos.toList()),
      ),
      commands: CommandHooks(interpretCommand: interpret),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SEED');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    expect(enqueuedSingly, isEmpty);
    expect(enqueuedBatches, isEmpty, reason: 'skipOnlineLookup must suppress the background lookup queue entirely');
  });

  testWidgets('a manually entered name override does not duplicate onto a newly added call, but a grid override does', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          // See the note on the same fixture above: saving an edit is refused
          // when the contact would carry neither band nor frequency.
          'freq': 14285.0,
        })))!;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          session: LoggingSession(
            editingQso: existingQso,
          ),
          radio: baseRadio(),
        ),
      ),
    ));

    // Drive the "More" pane to set an explicit name+grid override. The
    // icon sits inside a horizontally-scrolling chip row — same harmless
    // "off the hit-test center" artifact as the DropdownMenu taps elsewhere
    // in this file. Grid is typed lowercase on purpose: the pane's Grid
    // field is `uppercase: true` (logging INPUT is uppercase unless
    // explicitly mixed-case), but the stored value gets the conventional
    // Maidenhead casing back via normalizeGrid — so it must land as FN99xx
    // below — while Name is an explicitly mixed-case field and survives
    // exactly as typed.
    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Corrected Name');
    await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn99xx');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Extend the call field into a list — K1ABC is a newly added call.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    // The record being edited keeps both — same as before this feature.
    expect(w1aw.theirName, 'Corrected Name');
    expect(w1aw.theirGrid, 'FN99xx');
    // The newly added call inherits the grid override, but not the name.
    expect(k1abc.theirGrid, 'FN99xx');
    expect(k1abc.theirName, isNot('Corrected Name'));
  });

  testWidgets('a name set via the More pane does not leak onto the next QSO after logging', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Hiram');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 2);

    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    expect(w1aw.theirName, 'Hiram');
    // The log-then-wipe must clear the override — K1ABC is a different human.
    expect(k1abc.theirName, isNull);
  });

  // Who was at the key rides on the CONTACT, stamped at save time from the
  // operation. The pane is how a contact gets one of its own — the operator
  // who worked a guest at their station, or a record being corrected long
  // after the fact.
  testWidgets('an operator typed into the More pane is logged onto the contact', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(defaultOperatorCall: 'N0DEV')));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    // The field shows the operation's answer as a placeholder only, so what
    // is typed here is the operator's own statement about this contact.
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'w1abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map)['operatorCall'], 'W1ABC');
  });

  // A contact merely opened and saved must keep taking the operation's stamp
  // (`qsoWithOperator`, applied by the app after this widget hands the QSO
  // over). Writing the placeholder through as a value would freeze whoever
  // happened to be at the key onto every record anyone ever opens.
  testWidgets('the More pane records no operator when its field was not touched', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(defaultOperatorCall: 'N0DEV')));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map).containsKey('operatorCall'), isFalse);
  });

  // Wipe-then-undo round-trips the draft through `_applyFieldsFromData`, the
  // same path that would otherwise drop a name set in the pane. Dropped here,
  // the restored contact silently goes back to taking the operation's stamp.
  testWidgets('an operator set in the More pane survives wipe-then-undo', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(defaultOperatorCall: 'N0DEV')));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'W1ABC');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW); // wipes, offers undo
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect((logged.single.data['our'] as Map)['operatorCall'], 'W1ABC');
  });

  testWidgets('the Position field is offered only where the operation is run by positions', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Position'), findsNothing,
        reason: 'a single-operator station has no seats to choose between');
  });

  testWidgets('a position typed into the More pane is logged in its canonical form', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(showPositionField: true, defaultPosition: '1')));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Leading zeros and stray characters are the same seat as plain digits —
    // `/OP02` is a callsign no hunter can use.
    await tester.enterText(find.widgetWithText(TextField, 'Position'), '0x2');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map)['multiIdentifier'], '2');
  });

  testWidgets('debounced lookup enriches the entry line and the logged QSO', (tester) async {
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      lookups++;
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: lookup,
            // The location line is formatted by the app layer (issue #40);
            // surface the guess's location so it can be asserted here.
            callLocationLine: (guess) => guess['location'] as String?,
          ),
        ),
      ),
    ));

    // Typing partial calls must not fire lookups until the debounce expires.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1A');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 100));
    expect(lookups, 0);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    // Two passes per resolved call: an offline pass, then an online pass.
    expect(lookups, 2);
    expect(find.textContaining('ARRL HQ'), findsOneWidget); // name, line 2
    expect(find.textContaining('Newington, CT'), findsOneWidget); // location, line 1

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirName, 'ARRL HQ');
    expect(logged.single.theirGrid, 'FN31pr');

    // Wipe cleared the enrichment line (after the info-area cross-fade settles).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ARRL HQ'), findsNothing);
  });

  testWidgets('restoring a wiped entry re-runs the lookup, not just its stale cached result', (tester) async {
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      lookups++;
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: lookup,
            callLocationLine: (guess) => guess['location'] as String?,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 2); // offline + online pass
    expect(find.textContaining('ARRL HQ'), findsOneWidget);

    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW); // wipes, offers undo
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(callField.controller!.text, 'W1AW');

    // The wipe cleared the lookup cache along with the fields — restoring
    // must schedule a fresh lookup, not leave the entry unlooked-up until
    // the user edits the field themselves.
    expect(lookups, 2); // unchanged immediately — the lookup is debounced
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 4);
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  testWidgets('restoring a wiped entry also re-runs scoring, not just the lookup', (tester) async {
    // Same wipe-then-undo flow as the lookup regression above, but for the
    // dupe/New-* score pill: _wipe() clears score notices along with the
    // lookup cache, so restoring must re-trigger scoring too, or the pill
    // stays gone until the user edits the field themselves.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                {'notices': <String>[], 'alerts': ['duplicate']},
            scoreNoticeLabel: (key) => key == 'duplicate' ? 'Dupe!' : key,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Dupe!'), findsOneWidget);

    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW); // wipes, offers undo
    expect(find.text('Dupe!'), findsNothing);

    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Dupe!'), findsOneWidget);
  });

  testWidgets('a callsign note takes the name slot on the call-info line', (tester) async {
    // Issue #17: guess.note (from the call-notes lookup hook) usually
    // already names the operator, so it replaces guess.name on line 2
    // instead of joining it — same precedence app-polo gives notes.
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      if (call != 'KI2D') return null;
      return {
        'guess': {'name': 'Sebastian', 'note': '🤩 Sebastián - Ham2K PoLo Creator', 'location': 'New York, NY'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: lookup,
            callLocationLine: (guess) => guess['location'] as String?,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // The note's leading emoji is split into its own (glowed) widget; the
    // prose renders as markdown beside it.
    expect(find.text('🤩'), findsOneWidget); // leading emoji, glowed separately
    expect(find.textContaining('Sebastián - Ham2K PoLo Creator'), findsOneWidget); // note prose, line 2
    expect(find.textContaining('New York, NY'), findsOneWidget); // location, line 1
    expect(find.text('Sebastian'), findsNothing); // name is displaced by the note, not shown
  });

  // Dupe detection (same call+band+mode, cursor segment within a call list,
  // stacked calls) moved to the scoreQso hook — see the extension's
  // scoreQso.test.ts. The widget's remaining responsibility is passing the
  // right candidate; the call-at-cursor selection is covered by the lookup
  // tests above, and excludeUuid by the test below.

  testWidgets('scoreQso excludes the QSO being edited (so it never self-dupes)', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
      },
    );

    String? excluded;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: operation,
            qsosRepository: qsos,
            qsos: [existingQso],
          ),
          session: LoggingSession(
            editingQso: existingQso,
          ),
          radio: baseRadio(),
          lookups: LookupHooks(
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
              excluded = excludeUuid;
              return {'notices': <String>[], 'alerts': <String>[]};
            },
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // Editing populates the fields from the QSO, then scores it excluding
    // itself, so it can never flag itself as its own duplicate.
    expect(excluded, 'existing-uuid');
  });

  group('scoreQso and segments', () {
    // The scoring pills and the entry row's primary fields both have to follow
    // the CURRENT segment, or the operator sees a contest's exchange field
    // while the dupe check still belongs to the activity it replaced.
    late Qso editing;

    Qso segmentBreak(List<String> refTypes) => Qso(
          uuid: 'break-1',
          operationUuid: operation.uuid,
          data: {
            'startAtMillis': 1000,
            'band': 'event',
            'event': {
              'event': 'break',
              'operation': {
                'refs': [for (final type in refTypes) {'type': type}],
              },
            },
          },
        );

    setUp(() {
      editing = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
        },
      );
    });

    Future<({Map<String, dynamic>? operation, List<Map<String, dynamic>>? segments})> scored(
      WidgetTester tester, {
      required List<Qso> log,
    }) async {
      Map<String, dynamic>? sentOperation;
      List<Map<String, dynamic>>? sentSegments;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(
              operation: running(['pota']),
              qsosRepository: qsos,
              qsos: log,
            ),
            session: LoggingSession(
              editingQso: editing,
            ),
            radio: baseRadio(),
            lookups: LookupHooks(
              scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
                sentOperation = operation;
                sentSegments = segments;
                return {'notices': <String>[], 'alerts': <String>[]};
              },
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      return (operation: sentOperation, segments: sentSegments);
    }

    testWidgets('sends the current segment, not the base operation', (tester) async {
      final sent = await scored(tester, log: [segmentBreak(['cqww']), editing]);

      // The operation is a park activation; a break turned it into a contest.
      // Scoring must follow, or the contest's dupe rules never apply.
      expect([for (final ref in (sent.operation!['refs'] as List)) ref['type']], ['cqww']);
      // The hook reads the log through this uuid — dropping it would silently
      // score the candidate against an empty log.
      expect(sent.operation!['uuid'], operation.uuid);
      expect(sent.segments, hasLength(2), reason: 'base plus the break');
    });

    testWidgets('sends no timeline for an unsegmented operation', (tester) async {
      final sent = await scored(tester, log: [editing]);

      expect([for (final ref in (sent.operation!['refs'] as List)) ref['type']], ['pota']);
      expect(sent.segments, isNull, reason: 'one segment is not a timeline; sending it is pure payload');
    });
  });

  group("the More pane's station fields", () {
    /// A panel whose lookup answers [guess] for W1AW — the pane's placeholders
    /// and its US-only fields both hang off what the lookup said.
    Widget hostWithGuess(Map<String, dynamic> guess) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async =>
                    call == 'W1AW' ? {'guess': guess} : null,
              ),
            ),
          ),
        );

    Future<void> openPane(WidgetTester tester) async {
      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('County and ARRL Section are offered for a US contact and withheld for a DX one', (tester) async {
      // Both name a US administrative division. Over a DX contact they are
      // fields with no possible answer, and an operator who fills one in has
      // written something no program will read.
      await tester.pumpWidget(hostWithGuess({'entityPrefix': 'I', 'entityName': 'Italy'}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await openPane(tester);
      expect(find.text('County'), findsNothing);
      expect(find.text('ARRL Section'), findsNothing);
      expect(find.text('Entity'), findsOneWidget, reason: 'the entity is shown whoever they are');
    });

    testWidgets('a city and a zone typed into the pane reach the logged QSO', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'Newington');
      await tester.enterText(find.widgetWithText(TextField, 'CQ Zone'), '5');
      await tester.enterText(find.widgetWithText(TextField, 'Their power'), '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      final their = logged.single.data['their'] as Map;
      expect(their['city'], 'Newington');
      expect(their['cqZone'], 5);
      expect(their['power'], 100);
    });

    testWidgets('opening the pane over a guess and saving does not make the guess an entered value', (tester) async {
      // The trap the whole `theirExtra` before/after comparison exists for:
      // a guess promoted to an entered value stops tracking the lookup, and
      // an operator who merely looked at the pane has stated nothing.
      await tester.pumpWidget(hostWithGuess({'city': 'Newington', 'state': 'CT', 'cqZone': 5}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));

      await openPane(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      final their = logged.single.data['their'] as Map;
      expect(their.containsKey('city'), isFalse);
      expect(their.containsKey('cqZone'), isFalse);
      expect((their['guess'] as Map)['city'], 'Newington', reason: 'the lookup still answers for it');
    });

    testWidgets('editing the grid clears the coordinate, on screen and on the record', (tester) async {
      // A coordinate outranks a grid wherever one is read
      // (docs/design/locations.md), so a stale pair left beside a corrected
      // locator would silently discard the correction — and a pane still
      // showing that pair would be telling the operator the opposite of what
      // the save is about to do.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'grid': 'FN31pr', 'lat': 41.71, 'lon': -72.72},
        'band': '20m',
        'mode': 'SSB',
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Latitude')).controller!.text, '41.71');

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // onChange fires on blur, which is what an operator moving on does.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Latitude')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Longitude')).controller!.text, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // The panel's own Log button, not Enter: the pane has just closed and
      // the keyboard is not back in a main field for a shortcut to reach.
      await tester.tap(find.byType(FilledButton));

      // The record already exists, so a count of one says nothing about
      // whether the edit landed — poll for the value itself.
      var saved = existing;
      for (var i = 0; i < 20 && saved.theirGrid != 'FN20aa'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.theirGrid, 'FN20aa');
      // The stale pair is gone — what stands in its place is the typed
      // square's own center, which says nothing FN20aa did not. BOTH halves:
      // the writer decides them together, and a latitude paired with the
      // other square's longitude is a point nobody stated.
      final theirSaved = saved.data['their'] as Map;
      expect(theirSaved['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(theirSaved['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(theirSaved['lat'], isNot(closeTo(41.71, 0.01)));
    });

    testWidgets('a grid saved without leaving the field still clears the coordinate', (tester) async {
      // The pane's on-screen coordinate clear runs on BLUR, and `submit()`
      // snapshots its values before the unfocus it triggers is delivered — so
      // a grid typed and submitted straight from the field arrives with the
      // coordinate fields never blanked and nothing recorded to blank them.
      // The pair then outranks the grid just entered, everywhere it is read.
      //
      // It has to be a COMPOSED contact: on a saved record the coordinate
      // lives on the record itself, where the grid's own clear reaches it. On
      // a draft it lives in the pane's override map, which is what this
      // orders against.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '-72.72');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // The engine's own end-of-editing action, which the pane's single-line
      // fields wire straight to `submit()`. NOT a tap on Save: a tap moves
      // focus off the field first, firing the blur listener and hiding the
      // very ordering this test exists for.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['grid'], 'FN20aa');
      expect(their['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(their['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(their['lat'], isNot(closeTo(41.71, 0.01)), reason: 'the pane pair must not survive the typed grid');
    });

    testWidgets("the More pane's Grid hint is the same square the logging row hints", (tester) async {
      // Two Grid fields for one station, and they must not disagree. The pane
      // reads the guess's own stored square, which is six characters whatever
      // Grid Precision says — so with a coordinate in the guess and the
      // setting at eight, the row hinted the derived locator and the pane
      // hinted the coarser filed one. Both go through `guessGridDisplay` now.
      GridPrecision.configure(GridPrecision.eight);
      addTearDown(GridPrecision.reset);
      await tester.pumpWidget(hostWithGuess({'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await openPane(tester);

      final paneHint = tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).decoration!.hintText;
      expect(paneHint, locationToGrid8(41.7135, -72.7278));
      expect(paneHint, isNot('FN31pr'), reason: 'the filed square is coarser than the coordinate beside it');
    });

    testWidgets('County and ARRL Section are offered to Alaska and Hawaii', (tester) async {
      // They are their own DXCC entities, so a bare `K` test hides both — and
      // per the scorer these stations carry no `state` of their own, which
      // makes the section the only place their location could be recorded.
      for (final prefix in const ['KL', 'KH6']) {
        await tester.pumpWidget(hostWithGuess({'entityPrefix': prefix}));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump(const Duration(milliseconds: 400));
        await openPane(tester);
        expect(find.text('ARRL Section'), findsOneWidget, reason: '$prefix is US');
        expect(find.text('County'), findsOneWidget, reason: '$prefix is US');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets("a typed grid drops the country-file tag that would make readers refuse its coordinate", (tester) async {
      // app-polo spreads lib-country-files' annotation onto `their` itself,
      // so a synced QSO arrives with a DXCC centroid AND `locSource: 'prefix'`
      // marking it as one. Typing a grid replaces the pair with the square's
      // own center — and a tag left behind would then describe THAT, so every
      // reader would refuse it (halo_core's `locationFromGuess`) and the grid
      // would carry no coordinate after all.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'lat': 41.71, 'lon': 72.72, 'locSource': 'prefix'},
        'band': '20m',
        'mode': 'SSB',
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));

      var saved = existing;
      for (var i = 0; i < 20 && saved.theirGrid != 'FN20aa'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.theirGrid, 'FN20aa');
      expect((saved.data['their'] as Map)['locSource'], isNull);
      // The point of clearing it: the pair is readable as a coordinate again.
      expect(saved.theirExactLocation, gridToLocation('FN20aa'));
    });

    testWidgets('half a coordinate in the pane does not fuse with the grid into a whole one', (tester) async {
      // The trap: a typed grid writes its square's center, and the pane
      // records Latitude and Longitude as two independent overrides. Decided
      // per-field, a stated latitude beside the center's longitude would be
      // stored as a coordinate — a point nobody named, outranking the grid
      // everywhere it is read (docs/design/locations.md). Half a pair is no
      // coordinate, so the grid must answer for both halves or neither.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // Latitude alone, Longitude left empty.
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['grid'], 'FN20aa');
      expect(their['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(their['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(their['lat'], isNot(closeTo(41.71, 0.01)), reason: 'half a stated pair is not a coordinate');
    });

    testWidgets('a coordinate typed into the pane outranks the grid it was stored beside', (tester) async {
      // The other half: the clear above exists to stop a STALE pair from
      // surviving a typed grid, not to overrule one the operator just stated.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '-72.72');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['lat'], 41.71);
      expect(their['lon'], -72.72);
    });
  });

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
      Future<Map<String, dynamic>?> Function(String, {
        required Map<String, dynamic> qso,
        required Map<String, dynamic> operation,
        required bool online,
        bool recentContext,
      }) fn,
      List<Map<String, dynamic>> seenQsos,
      List<bool> seenRecentContext,
    }) refLookup(List<Map<String, dynamic>> refs, {String forCall = 'W1AW'}) {
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
        {'type': 'potaHunter', 'ref': 'US-1234'}
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));

      await typeCall(tester, 'W1AW');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect(
        (logged.single.data['refs'] as List).cast<Map>(),
        contains(containsPair('ref', 'US-1234')),
      );
    });

    testWidgets('composing a contact asks for recent context; editing a logged one does not', (tester) async {
      // `recentContextLookup` hooks answer "what is this station doing right
      // now". That is a question about a contact in progress — asked while
      // editing a QSO logged an hour ago, a current spot describes a park the
      // station may have reached long after the contact ended. The gate lives
      // here, at the request, so those hooks are never even consulted rather
      // than each having to recognize a context it cannot see.
      final composing = refLookup(const []);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: composing.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
      await typeCall(tester, 'W1AW');
      expect(composing.seenRecentContext, isNotEmpty);
      expect(composing.seenRecentContext, everyElement(isTrue));

      // A different call from the one typed below, so the edit genuinely
      // changes it — retyping the record's own call is an early return in
      // `_scheduleLookup` and no lookup would fire at all.
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'K1ABC'},
            'startAtMillis': 1000000,
            'freq': 14285.0,
          })))!;
      final editing = refLookup(const []);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            session: LoggingSession(
              editingQso: existingQso,
            ),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: editing.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
      await typeCall(tester, 'W1AW');
      expect(editing.seenRecentContext, isNotEmpty, reason: 'the lookup still runs when editing');
      expect(editing.seenRecentContext, everyElement(isFalse));
    });

    testWidgets('a ref the operator already entered is never replaced by the guess', (tester) async {
      // The operator's own park outranks one mined from a spot: a spot can be
      // stale, or for the wrong one of two parks, and silently rewriting what
      // was typed would put the wrong reference in the log.
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-9999'}
      ]);
      await tester.pumpWidget(MaterialApp(
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
                  {'type': 'potaHunter', 'ref': 'US-0001'}
                ],
              },
            ),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
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
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));

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
      expect(
        (logged.single.data['refs'] as List?) ?? const [],
        isNot(contains(containsPair('ref', 'US-2080'))),
      );
    });

    testWidgets('taking back a guessed ref leaves the operator\'s own alone', (tester) async {
      // The mirror of the test above: removal must be targeted at the refs
      // this widget inserted, not a blanket wipe. Silently deleting the
      // operator's own park because they fixed a typo in the call would be
      // worse than the bug being fixed. Both kinds are present here at once —
      // the guessed summit must go, the typed park must stay.
      final lookup = refLookup(const [
        {'type': 'sotaHunter', 'ref': 'W2/GC-001'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            session: LoggingSession(
              suggestedQso: const {
                'band': '20m',
                'mode': 'SSB',
                'refs': [
                  {'type': 'potaHunter', 'ref': 'US-0001'}
                ],
              },
            ),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
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
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
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
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget);

      await typeCall(tester, 'KI2D,W1AW');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'KI2D is still in the field');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      for (final qso in logged) {
        expect(
          (qso.data['refs'] as List).cast<Map>(),
          contains(containsPair('ref', 'US-2080')),
          reason: '${qso.theirCall} shares the stack\'s park',
        );
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
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));
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
        {'type': 'potaHunter', 'ref': 'US-1234'}
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: lookup.fn,
            ),
            activities: ActivityHooks(
              activityControls: const [hunter],
            ),
          ),
        ),
      ));

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
      expect(
        lookup.seenQsos.any((qso) =>
            (qso['refs'] as List?)?.any((ref) => (ref as Map)['ref'] == 'US-1234') ?? false),
        isTrue,
      );
    });
  });
}
