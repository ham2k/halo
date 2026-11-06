// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial-number exchange fields: showing the number the sequence will
// issue, letting it go, logging it, and the number an edited contact shows.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart' show LoggingActionButton;

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('serial controls', () {
    const controls = [
      {
        'key': 'cqwpx/ourSerial',
        'label': 'Our #',
        'icon': 'flag-checkered',
        'input': {
          'kind': 'serial',
          'refType': 'cqwpx',
          'field': 'ourSerial',
          'sequence': {'key': 'serial'},
        },
      },
    ];

    /// A repository wired for allocation, as the app builds it.
    QsosRepository allocating() => QsosRepository(db, sequences: SequencesRepository(db));

    Widget hostWith(QsosRepository repo) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: controls),
        ),
      ),
    );

    testWidgets('shows the number the sequence will issue, and logs it', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      // The operator has to be able to read the number they're about to send
      // while they're still typing the callsign.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
    });

    testWidgets('advances after each QSO instead of repeating the last number', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitForQsos(tester, 1, repository: repo);
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '2');
    });

    testWidgets('with peers, shows no number until the operator starts a contact', (tester) async {
      // A shown number is held against every other position from that moment
      // (docs/design/contests.md §5.8.1), so an idle panel that shares the
      // sequence holds nothing — and a blank is the only honest display of
      // nothing. Without this, a phone left on the table burns a number.
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
      expect(source.claims, 0);

      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
    });

    testWidgets('alone, shows the next number before the operator starts a contact', (tester) async {
      // With no peers and no second SO2R set nothing else can take the
      // number, so the idle panel shows where the series stands. Without
      // this, a single-op station reads nothing until the first keystroke.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
    });

    testWidgets('alone, the number shown is not a contact in progress', (tester) async {
      // The idle number is the panel's, not the operator's: counted as
      // composed, every idle contest panel would keep its wipe live (wiping
      // only puts the number back), hide Start and Pause, and read a VFO move
      // as a QSY away from a draft.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');
      final wipe = tester.widget<LoggingActionButton>(find.ancestor(of: find.byIcon(MdiIcons.backspaceOutline), matching: find.byType(LoggingActionButton)));
      expect(wipe.onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Our #'), '7');
      await tester.pump();
      final typed = tester.widget<LoggingActionButton>(find.ancestor(of: find.byIcon(MdiIcons.backspaceOutline), matching: find.byType(LoggingActionButton)));
      expect(typed.onPressed, isNotNull, reason: 'a number the operator typed is theirs');
    });

    group('when the panel stops being alone', () {
      late So2rLink link;

      // One operation for every pump: a fresh `refs` list is a controls
      // change of its own, which refreshes the number whatever else moved.
      late Operation contest;
      setUp(() {
        link = So2rLink();
        addTearDown(link.dispose);
        contest = running(['cqwpx']);
      });

      Widget setA(QsosRepository repo, {required bool so2r}) => MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: contest, qsosRepository: repo),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
            so2r: so2r ? So2rSet(radio: 'A', link: link) : null,
          ),
        ),
      );

      String ourSerial(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text ?? '';

      testWidgets('an idle set shows no number, even with no peers', (tester) async {
        // The other set takes numbers from the same series, so the idle set's
        // number can be gone by the time it logs: SO2R is never "alone",
        // peers or not. Without this, both sets show the same next number.
        final repo = allocating();
        await tester.pumpWidget(setA(repo, so2r: true));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(ourSerial(tester), '');

        await startContact(tester);
        await pumpUntilSerial(tester, 'Our #');
        expect(ourSerial(tester), '1');
      });

      testWidgets('a set appearing takes back the number the idle panel showed alone', (tester) async {
        // Solo ends the moment a second set can take numbers; a number left
        // showing would be one the panel no longer holds.
        final repo = allocating();
        await tester.pumpWidget(setA(repo, so2r: false));
        await pumpUntilSerial(tester, 'Our #');

        await tester.pumpWidget(setA(repo, so2r: true));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(ourSerial(tester), '');
      });

      testWidgets('peers arriving take back the number the idle panel showed alone', (tester) async {
        // The same end of solo from the other side: a number left showing is
        // one no peer was told about, and a peer may send it too.
        final repo = allocating();
        final source = RecordingSerialSource(repo.sequences!);
        Widget panel(SerialNumberSource? peers) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: contest, qsosRepository: repo, serialNumbers: peers),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        );
        await tester.pumpWidget(panel(null));
        await pumpUntilSerial(tester, 'Our #');

        await tester.pumpWidget(panel(source));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(ourSerial(tester), '');
        expect(source.claims, 0, reason: 'an idle panel with peers holds nothing');
      });
    });

    testWidgets('a wipe lets go of the number and shows none again', (tester) async {
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(source.claims, 1);

      await tester.tap(find.bySemanticsIdentifier('action.wipe'));
      await tester.pump();
      expect(source.releases, greaterThanOrEqualTo(1), reason: 'the hold goes with the draft');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });

    testWidgets('Enter inside the claim window waits for the number rather than logging a blank', (tester) async {
      // The commit-time allocator is blind to the peers' holds: a blank
      // serial field on Enter would be filled from the local counter, and
      // two positions would send one number with neither record marked.
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!, gate: Completer<void>());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await startContact(tester, 'W1AW');
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '', reason: 'the claim is still settling');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 20));
      expect(await tester.runAsync(() => repo.watchForOperation(operation.uuid).first), isEmpty, reason: 'nothing committed while the number is unsettled');

      // The peers answer: the number lands in the field and the commit goes
      // through with it.
      source.gate!.complete();
      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
    });

    testWidgets('backspacing the call to nothing lets the number go', (tester) async {
      // A hold with no draft behind it blocks the other positions for as
      // long as the operator leaves the panel — and shows a number nobody
      // is about to send.
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await startContact(tester, 'W1');
      await pumpUntilSerial(tester, 'Our #');
      expect(source.releases, 0);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
      await tester.pump();
      expect(source.releases, 1);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });

    testWidgets('leaving the panel mid-contact lets the number go', (tester) async {
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      await tester.pumpWidget(const SizedBox());
      expect(source.releases, 1);
    });

    testWidgets('a number another position also showed is logged with the mark', (tester) async {
      // The number went on the air, so it is written as shown; the record
      // wearing the mark is what tells the operator two stations sent it.
      final repo = allocating();
      final source = RecordingSerialSource(repo.sequences!, conflicted: {1});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo, serialNumbers: source),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await startContact(tester, 'W1AW');
      await pumpUntilSerial(tester, 'Our #');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
      expect(logged.single.serialConflict, isTrue);
      expect(source.committed.map((request, number) => MapEntry(request.label, number)), {
        'cqwpx/serial': 1,
      }, reason: 'the source is told what the log now holds');
    });

    testWidgets('a number the operator types over the preview is what gets logged', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      // "I've been logging on paper, I'm actually on 57."
      await tester.enterText(find.widgetWithText(TextField, 'Our #'), '57');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 57},
      ]);
    });

    testWidgets('a serial takes digits only, and is never uppercased into nonsense', (tester) async {
      await tester.pumpWidget(hostWith(allocating()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Our #'), '1a2b');
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '12');
    });

    testWidgets('a call list numbers each call in turn, not all under the displayed one', (tester) async {
      // The displayed number is what the operator read out — but only to the
      // first station. The rest of a pileup got the next numbers in the series.
      // Writing the displayed number through (rather than treating it as a
      // guess) makes this the one place it must NOT be copied.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC,N1XYZ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 3, repository: repo);
      expect(logged, hasLength(3));
      final serials = [for (final qso in logged) (qso.refs.firstWhere((r) => r['type'] == 'cqwpx')['ourSerial'] as num).toInt()]..sort();
      expect(serials, [1, 2, 3], reason: 'three stations worked, three numbers sent');
    });

    const descriptor = SequenceDescriptor(refType: 'cqwpx', field: 'ourSerial', key: 'cqwpx/serial');

    testWidgets('logs the number that was displayed, even once the sequence has moved on', (tester) async {
      // THE reason the displayed number is written through instead of being
      // re-allocated at commit. The operator read "1" off the screen and said
      // it into the microphone. If something else consumes 1 in the meantime
      // (another window on the same log), allocating at commit would file this
      // QSO under 2 — and the log would disagree with what went out on the air.
      // A duplicate is the honest outcome here; a silently wrong number is not.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');

      // A second writer on the same operation takes 1 while this QSO is being
      // composed. `peek` is deliberately not a reservation.
      await tester.runAsync(
        () => repo.add(
          operation.uuid,
          {
            'their': {'call': 'DL1ABC'},
            'band': '20m',
            'mode': 'CW',
          },
          serialSequences: const [descriptor],
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2, repository: repo);
      final ours = logged.firstWhere((q) => q.theirCall == 'W1AW');
      expect(ours.refs.single['ourSerial'], 1, reason: 'what the operator was shown and sent — not the next free number');
    });

    testWidgets('editing a logged QSO shows ITS number, not the next one', (tester) async {
      // The number on a logged QSO is what that station was actually sent.
      // Opening the record to fix a busted call must show 1, not whatever the
      // sequence is up to — and saving must leave 1 on the record. Writing the
      // displayed number through is exactly what makes this dangerous: a
      // preview leaking into this field silently rewrites history.
      final repo = allocating();
      final first = await repo.add(
        operation.uuid,
        {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
        },
        serialSequences: const [descriptor],
      );
      await repo.add(
        operation.uuid,
        {
          'their': {'call': 'K1ABC'},
          'band': '20m',
          'mode': 'CW',
        },
        serialSequences: const [descriptor],
      );
      expect((first.refs.single['ourSerial'] as num).toInt(), 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo),
              session: LoggingSession(editingQso: first),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text,
        '1',
        reason: "the number this QSO sent, not the sequence's next",
      );

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(
        tester,
        'the edited Sent',
        (logged) => logged.any((q) => q.uuid == first.uuid && q.sentRST == '579'),
        repository: repo,
      );
      final edited = logged.firstWhere((q) => q.uuid == first.uuid);
      expect(edited.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ], reason: 'still an int, still the number that went on the air');
    });

    testWidgets('editing a QSO with no contest ref does not invent a serial for it', (tester) async {
      // An ordinary QSO logged before the contest was set up. Correcting it
      // must not attach a number the station was never sent.
      final repo = allocating();
      final plain = await repo.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo),
              session: LoggingSession(editingQso: plain),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Sent', (logged) => logged.single.sentRST == '579', repository: repo);
      expect(logged.single.refs, isEmpty);
    });

    testWidgets('a sibling exchange field on the same ref survives editing', (tester) async {
      // cqwpx declares `ourSerial` before `theirSerial`, both on the cqwpx ref.
      // Restoring only the first and bailing out leaves the second empty — and
      // an empty primary field is an active clear on save, so the received
      // number would be wiped by opening the record and saving it.
      const both = [
        {
          'key': 'cqwpx/ourSerial',
          'label': 'Our #',
          'icon': 'flag-checkered',
          'input': {
            'kind': 'serial',
            'refType': 'cqwpx',
            'field': 'ourSerial',
            'sequence': {'key': 'serial'},
          },
        },
        {
          'key': 'cqwpx/theirSerial',
          'label': 'Their #',
          'icon': 'flag-checkered',
          'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial', 'numeric': true},
        },
      ];

      final repo = allocating();
      final qso = await repo.add(
        operation.uuid,
        {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'refs': [
            {'type': 'cqwpx', 'theirSerial': '101'},
          ],
        },
        serialSequences: const [descriptor],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo),
              session: LoggingSession(editingQso: qso),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: both),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their #')).controller?.text, '101');

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Sent', (logged) => logged.single.sentRST == '579', repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'theirSerial': '101', 'ourSerial': 1},
      ]);
    });

    testWidgets('picks up a serial control that arrives after the first build', (tester) async {
      // How it actually happens in the app: the panel builds, THEN the
      // extension runtime answers with the operation's controls. Seeding the
      // preview only from initState left the field blank in the running app
      // while every construct-with-controls test here still passed.
      final repo = allocating();
      Widget hostControls(List<Map<String, dynamic>> active) => MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['cqwpx']), qsosRepository: repo),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: active),
          ),
        ),
      );

      await tester.pumpWidget(hostControls(const []));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Our #'), findsNothing);

      await tester.pumpWidget(hostControls(List<Map<String, dynamic>>.from(controls)));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
    });

    testWidgets('with no sequences wired up, the field stays empty rather than showing a fake number', (tester) async {
      // A bare repository (tests, tooling, an import path) allocates nothing.
      // Showing "1" there would be a number that never reaches the log.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: qsos),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });
  });
}
