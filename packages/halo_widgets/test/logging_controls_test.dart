// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel end to end: composing a contact and logging it, the
// call-list and call-stacking paths through one entry, and wiping and
// undoing. The clusters with a model of their own are beside this file —
// radio, lookup, commands, exchange fields, focus, spotting, the control
// strip and the event row each have their own.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('the call field and Log/Wipe buttons carry stable semantics identifiers (#236)', (tester) async {
    // Translation-independent hooks for agent/browser tooling — a rename or a
    // dropped wrapper must fail here, not silently strip the targets.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
    expect(find.bySemanticsIdentifier('action.log'), findsOneWidget);
    expect(find.bySemanticsIdentifier('action.wipe'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('leftieMode renders the submit button and wipe button on the left of the main logging fields', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(leftieMode: false)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    final logBtnXRight = tester.getTopLeft(find.bySemanticsIdentifier('action.log')).dx;
    final wipeBtnXRight = tester.getTopLeft(find.bySemanticsIdentifier('action.wipe')).dx;
    final callFieldXRight = tester.getTopLeft(find.bySemanticsIdentifier('field.call')).dx;
    expect(logBtnXRight, greaterThan(callFieldXRight));
    expect(wipeBtnXRight, greaterThan(callFieldXRight));

    await tester.pumpWidget(host(prefs: LoggingPreferences(leftieMode: true)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    final logBtnXLeft = tester.getTopLeft(find.bySemanticsIdentifier('action.log')).dx;
    final wipeBtnXLeft = tester.getTopLeft(find.bySemanticsIdentifier('action.wipe')).dx;
    final callFieldXLeft = tester.getTopLeft(find.bySemanticsIdentifier('field.call')).dx;
    expect(logBtnXLeft, lessThan(callFieldXLeft));
    expect(wipeBtnXLeft, lessThan(callFieldXLeft));
  });

  testWidgets('an operation run under several callsigns logs contacts under the first, not the field', (tester) async {
    // The several callsigns live in `stationCall` as ONE comma-separated
    // string, so stamping the field puts "KI2D,W1AW" — not a callsign — on
    // every contact and into the `our_call` column the cross-operation Logs
    // view groups by. A contact holds exactly one call, as it does in
    // app-polo, whose extra calls sit in a separate array entirely.
    operation = await operations.create(stationCall: 'KI2D, W1AW');
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.ourCall, 'KI2D');
  });

  testWidgets('Enter logs a QSO with mode, band and default RSTs', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    final qso = logged.single;
    expect(qso.theirCall, 'W1AW');
    expect(qso.ourCall, 'KI2D');
    expect(qso.freq, 14285);
    expect(qso.band, '20m');
    expect(qso.mode, 'SSB');
    expect(qso.sentRST, '59');
    expect(qso.receivedRST, '59');

    // Entry is wiped and ready for the next call.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
    expect(callField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Enter with an implausible call logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await qsosAfterWaiting(tester);
    expect(logged, isEmpty, reason: 'an implausible call is refused, not logged');
  });

  // The panel reserves the home indicator below its fields, but NOT while the
  // on-screen keyboard is up — the keyboard covers the indicator, and
  // StatusBarOverlay is already holding back that whole strip so the status
  // footer can ride above the keyboard. Reserving it here as well put a dead
  // gap between the numbers row and the footer (caught on a simulator, not by
  // the tests, which is why this one exists).
  //
  // Measured as the space below the fields rather than by reading the private
  // getter, so it stays a statement about what the operator sees.
  group('the panel does not reserve the home indicator under the keyboard', () {
    double gapBelowFields(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(LoggingControls)).dy - tester.getBottomLeft(find.widgetWithText(TextField, 'Their call')).dy;

    Future<double> gapWith(WidgetTester tester, {required bool keyboardUp, bool hostHoldsStrip = false}) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: 34 * dpr); // a home indicator
      // Set BOTH branches, never just one: leaving `viewInsets` alone on the
      // keyboard-down call made the result depend on which order the two calls
      // happened to run in — reversing them measured "keyboard down" under a
      // raised keyboard and reported a difference of 0.
      tester.view.viewInsets = keyboardUp ? FakeViewPadding(bottom: 300 * dpr) : FakeViewPadding.zero;
      // `padding` too, and by hand: the real engine derives it (viewPadding
      // less whatever the keyboard covers), but a TestFlutterView holds the
      // two independently, so a fake that sets only `viewPadding` leaves
      // MediaQuery — which is where the panel reads the strip from — saying
      // there is no home indicator at all.
      tester.view.padding = keyboardUp ? FakeViewPadding.zero : FakeViewPadding(bottom: 34 * dpr);
      addTearDown(() {
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
        tester.view.resetPadding();
      });
      // A host that draws its own chrome over the bottom edge — the app's
      // status footer — takes the strip out of the MediaQuery it hands down,
      // which is exactly how this panel is told not to hold it twice.
      await tester.pumpWidget(
        hostHoldsStrip
            ? Builder(
                builder: (context) => MediaQuery.removePadding(context: context, removeBottom: true, child: host()),
              )
            : host(),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return gapBelowFields(tester);
    }

    testWidgets('reserves it with the keyboard down, and nothing with it up', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // Keyboard UP first, deliberately: taken in the other order this passed
        // even when `gapWith` never cleared the inset, because the down case
        // happened to run before anything set it.
        final up = await gapWith(tester, keyboardUp: true);
        final down = await gapWith(tester, keyboardUp: false);
        // The indicator's 34pt is held back only when it is actually exposed.
        expect(down - up, moreOrLessEquals(34, epsilon: 1.0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('reserves nothing when the host already holds the strip', (tester) async {
      // The app's status footer spans the window below every route and covers
      // the indicator itself, so the panel reserving it as well opens a band
      // of panel background between the fields and the footer. The host says
      // so by taking the inset out of the MediaQuery — nothing tells this
      // panel directly, which is why reading the strip from the raw
      // `FlutterView` instead would be undetectable here and wrong there.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final held = await gapWith(tester, keyboardUp: false, hostHoldsStrip: true);
        final unheld = await gapWith(tester, keyboardUp: false);
        expect(unheld - held, moreOrLessEquals(34, epsilon: 1.0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('a comma-separated call list logs one QSO per call, 5 seconds apart', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    // The stream's list is unmodifiable; sort a copy.
    final logged = [...await waitForQsos(tester, 3)]..sort((a, b) => a.startAtMillis!.compareTo(b.startAtMillis!));
    expect(logged, hasLength(3));
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC', 'N2XYZ']);
    expect(logged[1].startAtMillis! - logged[0].startAtMillis!, 5000);
    expect(logged[2].startAtMillis! - logged[1].startAtMillis!, 5000);

    // Entry is wiped, same as the single-call case.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
  });

  testWidgets('a call list with any implausible entry logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, QQQ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await qsosAfterWaiting(tester);
    expect(logged, isEmpty, reason: 'one implausible entry refuses the whole list');
  });

  // The traps these two exist to catch: _log() letting an insert failure
  // escape to the zone handler (the panel looks like it logged while the QSO
  // is gone, and the generic notice shows at most once per session), wiping
  // the typed fields anyway, or leaving already-committed calls in the field
  // so the retry logs them twice.
  testWidgets('a failed insert keeps the typed call, says so in the panel, and reports the error', (tester) async {
    final errors = <Object>[];
    await tester.pumpWidget(
      host(
        log: baseLog().copyWith(qsosRepository: FailingQsosRepository(db), onWriteError: (e, _) => errors.add(e)),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await qsosAfterWaiting(tester);
    expect(logged, isEmpty, reason: 'the insert failed, so nothing reached the log');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(errors, hasLength(1));
  });

  testWidgets('a mid-list insert failure keeps only the unlogged calls, so a retry cannot duplicate', (tester) async {
    await tester.pumpWidget(host(log: baseLog().copyWith(qsosRepository: FailingQsosRepository(db, addsBeforeFailure: 1))));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC,N2XYZ');
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  testWidgets('call stacking: "//" logs the last stacked call and leaves the rest for the next QSO', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'W1AW');

    // The un-logged fragment stays in the field, ready for the next QSO —
    // not a full wipe.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC');
    expect(callField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('call stacking: picks the segment at the cursor, not always the last one', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    // Move the cursor into the first segment ("K1AB|C").
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    callField.controller!.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'K1ABC');
    expect(callField.controller!.text, 'W1AW');
  });

  testWidgets('call stacking: scans left past invalid fragments to find a valid callsign', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//QQQ//RRR');
    await tester.pump(); // cursor defaults to the end, inside the invalid "RRR" segment
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'W1AW');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'QQQ//RRR');
  });

  testWidgets('call stacking: no valid callsign anywhere in the stack logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ//RRR');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await qsosAfterWaiting(tester);
    expect(logged, isEmpty, reason: 'a stack with no valid callsign logs nothing');
  });

  testWidgets('call stacking: a leading "//" is a stack whose first segment is empty', (tester) async {
    // Nothing here carves a leading "//" out of stacking — what keeps a note
    // key from logging is _log running command interpretation FIRST, and no
    // interpretCommand is wired in this host. So the key falls through and
    // logs as the callsign it looks like, rather than the field being
    // neither syntax and doing nothing.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, '');
  });

  testWidgets('call stacking: a key leading a stack picks the cursor segment, not the key', (tester) async {
    // The trap: exclude a leading "//" from stacking and "//KEY//CALL" is
    // neither syntax — not a stack, and not a whole-field command either,
    // since the key then reads as "KEY//CALL" and matches nothing. Enter
    // does nothing at all, and no assertion about a logged QSO catches it.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    // The key is left intact, still leading, ready for the next Enter to
    // expand it.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, '//DAN');
  });

  testWidgets('call stacking: a cursor at the very start is not a dead spot', (tester) async {
    // The empty first segment is where offset 0 lands, and it has nothing to
    // expand and nothing to log — so without treating the leading "//" as a
    // separator rather than a segment, Enter does nothing here while the same
    // Enter one character to the right works. An invisible cursor position
    // selecting between two outcomes is the worst shape this can take.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW//QQQ');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    callField.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    expect(callField.controller!.text, '//QQQ');
  });

  testWidgets('call stacking: a stacked segment that is a comma list logs every call in it', (tester) async {
    // "W1AW//K1ABC,N2XYZ" splits into "W1AW" and "K1ABC,N2XYZ"; the cursor
    // sits in the second. That segment is the shape a mid-stack note
    // expansion leaves behind, so it has to log as a list rather than be
    // skipped for failing looksLikeCallsign whole — otherwise an operator
    // could expand a key and then never log what it expanded to.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    expect(logged.map((q) => q.theirCall).toList(), ['K1ABC', 'N2XYZ']);

    // Only the picked segment leaves the field; the rest of the stack stays.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');
  });

  testWidgets('call stacking: a stacked segment with any implausible entry is skipped, not logged', (tester) async {
    // The comma list a segment holds is all-or-nothing, same rule a
    // top-level list follows — a half-typed second call must not drag the
    // segment into logging, it must fall back to scanning left.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//K1ABC,QQQ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC,QQQ');
  });

  testWidgets('editing a QSO with a comma-separated call list updates the original and adds new QSOs for the rest', (tester) async {
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'freq': 7100,
        'mode': 'SSB',
      }),
    ))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = [...await waitForQsos(tester, 2)]..sort((a, b) => a.startAtMillis!.compareTo(b.startAtMillis!));
    expect(logged, hasLength(2));
    // The original QSO is updated in place, keeping its own recorded time.
    expect(logged[0].uuid, existingQso.uuid);
    expect(logged[0].theirCall, 'W1AW');
    expect(logged[0].startAtMillis, 1000000);
    // The extra call becomes a new QSO, 5 seconds later.
    expect(logged[1].uuid, isNot(existingQso.uuid));
    expect(logged[1].theirCall, 'K1ABC');
    expect(logged[1].startAtMillis, 1005000);
  });

  testWidgets('lookup preview follows the cursor segment within a comma-separated call list', (tester) async {
    final lookups = <String>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      lookups.add(call);
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(lookup: lookup),
          ),
        ),
      ),
    );

    // Cursor ends up at the end (last segment, "W1AW") after enterText.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC, W1AW');
    await tester.pump(const Duration(milliseconds: 400));

    expect(lookups, contains('W1AW'));
    expect(lookups, isNot(contains('K1ABC, W1AW')));
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  testWidgets('onCommandMessageChanged does not fire on every keystroke when the message is unchanged', (tester) async {
    final messages = <String?>[];
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeInterpretCommand, onCommandMessageChanged: messages.add),
      ),
    );

    // Typing an ordinary callsign never produces a command message: the
    // callback must stay silent rather than firing null on every character
    // (which used to rebuild the whole QsoList per keystroke).
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1A');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));

    expect(messages, isEmpty);
  });

  testWidgets('call-info reports isEditing so the map can colour the current QSO (orange composing, blue editing)', (tester) async {
    // The map reads CallInfoData.isEditing to pick the highlight colour.
    final infos = <CallInfoData>[];
    void capture(CallInfoData? info) {
      if (info != null) infos.add(info);
    }

    // Composing a new QSO → isEditing false.
    await tester.pumpWidget(host(lookups: LookupHooks(onCallInfoChanged: capture)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    expect(infos, isNotEmpty, reason: 'a real callsign produces call-info');
    expect(infos.last.isEditing, isFalse, reason: 'composing a new QSO');

    // Editing an existing QSO → isEditing true (its call auto-populates the field).
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'K1ABC'},
        'startAtMillis': 1000000,
        'freq': 7100,
        'mode': 'SSB',
      }),
    ))!;
    infos.clear();
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        lookups: LookupHooks(onCallInfoChanged: capture),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(infos, isNotEmpty);
    expect(infos.last.isEditing, isTrue, reason: 'editing an existing QSO');
  });

  testWidgets('the published QSO draft carries every field, not just the call', (tester) async {
    // Extension panels declaring the `qso` trigger render against this, and
    // the whole point of publishing the draft rather than reusing the
    // call-info summary is that a panel can see what is about to be logged —
    // band and mode included.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: drafts.add)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));

    expect(drafts, isNotEmpty);
    final draft = drafts.last;
    expect((draft['their'] as Map)['call'], 'W1AW');
    expect(draft['band'], isNotNull, reason: 'the radio is tuned; a panel can see the band');
    expect(draft['mode'], isNotNull);
    expect((draft['our'] as Map)['call'], operation.stationCall);
  });

  testWidgets('a rebuild that changes nothing publishes no draft', (tester) async {
    // This fires from a post-frame callback on EVERY build, and the panel it
    // wakes crosses the JS bridge. Without the dedupe, an unrelated rebuild
    // of the operation view — a spot refresh, a clock tick — would look to
    // every `qso` panel exactly like the operator typing.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: drafts.add)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    final settled = drafts.length;

    await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: drafts.add)));
    // Past a second, because the draft must not carry a live clock: an
    // auto-timestamped QSO takes its startAtMillis at save, and a "now" in
    // here would republish on every heartbeat and wake every `qso` panel
    // forever, with nobody touching the keyboard.
    await tester.pump(const Duration(milliseconds: 2500));

    expect(drafts.length, settled, reason: 'nothing about the QSO changed');
  });

  testWidgets('moving the cursor within a stack republishes which call the draft names', (tester) async {
    // The QSON half of the draft is identical wherever the cursor sits, so a
    // dedupe on it alone would leave `{{ qso.call }}` naming the segment the
    // cursor just left — and a CW message would key the wrong station.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: drafts.add)));
    const stack = 'KN2//KI2D//NK2Y//FR';
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), stack);
    await tester.pump(const Duration(milliseconds: 200));
    expect(drafts.last['callField'], {'call': 'NK2Y', 'fullCall': 'NK2Y', 'partial': '', 'nextCall': 'KI2D', 'nextPartial': 'FR'});

    tester.testTextInput.updateEditingValue(const TextEditingValue(text: stack, selection: TextSelection.collapsed(offset: 8)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(drafts.last['callField'], {'call': 'KI2D', 'fullCall': 'KI2D', 'partial': '', 'nextCall': 'NK2Y', 'nextPartial': 'FR'});
    expect((drafts.last['their'] as Map)['call'], stack, reason: 'their.call stays the field as typed');
  });

  testWidgets('editing a field other than the call still publishes', (tester) async {
    // The draft is the whole QSO, not the callsign summary the call-info
    // callback carries: a dedupe keyed on the call alone would go quiet for
    // every field beside it, and a panel would show a report the operator
    // has already changed.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(session: LoggingSession(onQsoChanged: drafts.add)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    final before = drafts.length;

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '559');
    await tester.pump(const Duration(milliseconds: 200));

    expect(drafts.length, greaterThan(before));
    expect((drafts.last['their'] as Map)['sent'], '559');
  });

  testWidgets('onCallListLogged fires once after a comma-separated list logs, never for a single call', (tester) async {
    var callListLoggedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: operation, qsosRepository: qsos, onCallListLogged: () => callListLoggedCount++),
            radio: baseRadio(),
          ),
        ),
      ),
    );

    // Single call — must NOT fire.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);
    expect(callListLoggedCount, 0);

    // Comma-separated list — fires exactly once for the whole batch.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC, N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 3);
    expect(callListLoggedCount, 1);
  });

  testWidgets('call stacking: no information carries over between stacked calls — logging one wipes fully before restoring the rest', (tester) async {
    await tester.pumpWidget(host());

    // A touched Sent RST — state that should apply to the QSO being logged
    // but NOT carry over to whatever gets logged from the leftover stack.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'W1AW');
    expect(logged.single.sentRST, '57'); // the touched RST applied to the logged QSO

    // The field now holds the remainder, but the touched RST is gone —
    // wiped back to blank-means-the-default, same as an ordinary log.
    final sentField = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
    expect(sentField.controller!.text, isEmpty);
    expect(sentField.decoration!.hintText, '59');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC');
  });

  testWidgets('call stacking: lookup enrichment applies to the picked call and reaches the logged QSO', (tester) async {
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
    }) async {
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            lookups: LookupHooks(lookup: lookup, enqueueLookup: enqueued.add),
          ),
        ),
      ),
    );

    // Cursor ends up at the end (last segment, "W1AW") after enterText.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump(const Duration(milliseconds: 400)); // let the debounced lookup resolve
    expect(find.textContaining('ARRL HQ'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'W1AW');
    expect(logged.single.theirName, 'ARRL HQ');
    expect(logged.single.theirGrid, 'FN31pr');
    // The stacked save is handed to the background queue like any other new
    // QSO — had Enter beaten the preview debounce, the queue would still
    // enrich it (the queue skips records that already carry online data).
    expect(enqueued.map((q) => q.uuid).toList(), [logged.single.uuid]);
  });

  // Escape is aimed at menus and open controls all day long; a contact lost to
  // one press too many is not a recoverable mistake, so the wipe lives on a
  // chord nobody hits by accident.
  testWidgets('Escape leaves a QSO being composed alone', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    expect(find.byIcon(MdiIcons.undo), findsNothing, reason: 'nothing was wiped, so there is nothing to offer back');
  });

  testWidgets('Alt+W wipes the entry and offers the same undo as the wipe button', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);

    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
    expect(await qsosAfterWaiting(tester), isEmpty, reason: 'a wipe throws the contact away rather than logging it');

    final undoIcon = MdiIcons.undo;
    expect(find.byIcon(undoIcon), findsOneWidget);
    await tester.tap(find.byIcon(undoIcon));
    await tester.pump();
    expect(callField.controller!.text, 'W1AW');
    expect(find.byIcon(undoIcon), findsNothing);

    // With nothing composed, the chord doesn't stash an empty entry as undoable.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
    await tester.pump();
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);
    expect(find.byIcon(undoIcon), findsNothing);
  });

  // A report typed with no call is not "composed" — the wipe button stays
  // disabled over it — so the chord is the only gesture that resets it.
  testWidgets('Alt+W resets what the wipe button does not count as composed', (tester) async {
    await tester.pumpWidget(host());

    final sent = find.widgetWithText(TextField, 'Sent');
    await tester.enterText(sent, '57');
    await tester.pump();
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);

    expect(tester.widget<TextField>(sent).controller!.text, isNot('57'));
    expect(find.byIcon(MdiIcons.undo), findsNothing, reason: 'nothing composed, so nothing worth offering back');
  });

  // Unclaimed, a held Option+W auto-repeats into the focused field as "∑".
  testWidgets('Alt+W is claimed on key repeat too, without wiping again', (tester) async {
    await tester.pumpWidget(host());

    final call = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(call, 'W1AW');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    await tester.enterText(call, 'K2HAM');
    await tester.pump();
    final claimed = await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();

    expect(claimed, isTrue);
    expect(tester.widget<TextField>(call).controller!.text, 'K2HAM');
  });

  // The undo offer outlives the operator starting the next contact. A Cmd+Z
  // aimed at a typo in it must not swap that contact for the wiped one — the
  // slot is single-use, so there would be nothing left to take THAT back.
  testWidgets('Cmd+Z leaves a wipe alone once something new is composed', (tester) async {
    await tester.pumpWidget(host());

    final call = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(call, 'W1AW');
    await tester.pump();
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);
    await tester.enterText(call, 'K2HAM');
    await tester.pump();

    await sendChord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyZ);

    expect(tester.widget<TextField>(call).controller!.text, isNot('W1AW'));
    // Still on offer from the button, which says what it is about to do.
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();
    expect(tester.widget<TextField>(call).controller!.text, 'W1AW');
  });

  for (final modifier in [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.controlLeft]) {
    testWidgets('${modifier.keyLabel}+Z restores a wiped entry, same as tapping Undo', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyW);

      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, isEmpty);

      await sendChord(tester, modifier, LogicalKeyboardKey.keyZ);

      expect(callField.controller!.text, 'W1AW');
      expect(find.byIcon(MdiIcons.undo), findsNothing);
    });
  }

  // The chord is claimed ONLY while there is a wipe to take back. Claimed
  // unconditionally it would take text undo away from every logging field.
  testWidgets('Ctrl+Z with no wipe to take back is still the field\'s own text undo', (tester) async {
    await tester.pumpWidget(host());

    final call = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(call, 'W1AW');
    await tester.pump();
    // The undo history coalesces edits made inside its throttle window.
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(call, 'W1AWX');
    await tester.pump(const Duration(seconds: 1));

    // Ctrl, not Cmd: the test platform is Android, whose text undo is Ctrl+Z.
    await sendChord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyZ);

    expect(tester.widget<TextField>(call).controller!.text, 'W1AW');
  });

  group('wipe/undo, delete/undo, revert-changes button', () {
    IconButton secondButton(WidgetTester tester, IconData icon) =>
        tester.widget<IconButton>(find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)));

    final wipeIcon = MdiIcons.backspaceOutline;
    final undoIcon = MdiIcons.undo;
    final deleteIcon = MdiIcons.trashCanOutline;

    testWidgets('wipe is disabled with nothing entered, enabled once a call is typed, and wiping offers a 5s undo', (tester) async {
      await tester.pumpWidget(host());

      expect(secondButton(tester, wipeIcon).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      expect(secondButton(tester, wipeIcon).onPressed, isNotNull);

      await tester.tap(find.byIcon(wipeIcon));
      await tester.pump();

      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, isEmpty);
      expect(find.byIcon(wipeIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      expect(callField.controller!.text, 'W1AW');
      expect(find.byIcon(undoIcon), findsNothing);
      expect(find.byIcon(wipeIcon), findsOneWidget);
    });

    testWidgets('a wipe undone brings a typed grid back onto the record, not just onto the screen', (tester) async {
      // The record writes a grid only once the field was touched; the wipe
      // clears that with the rest of the draft. An undo that restored the
      // text without the flag would show the grid and log a QSO without it.
      await tester.pumpWidget(host(prefs: LoggingPreferences(showGridField: true)));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN31PR');
      await tester.pump();
      await tester.tap(find.byIcon(wipeIcon));
      await tester.pump();
      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).controller!.text, 'FN31pr');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirGrid, 'FN31pr');
    });

    testWidgets('wipe stays disabled for a fresh new QSO even though the Radio control shows the VFO frequency', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await openControl(tester, MdiIcons.radio);

      final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
      expect(freqField.controller!.text, '14285');
      expect(secondButton(tester, wipeIcon).onPressed, isNull);
    });

    testWidgets('the wipe undo option expires after 5 seconds even if the user starts typing again', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.byIcon(wipeIcon));
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2HAM');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget); // still available mid-retype

      await tester.pump(const Duration(seconds: 5));
      expect(find.byIcon(undoIcon), findsNothing);
      expect(find.byIcon(wipeIcon), findsOneWidget);

      // Expiry only hides the undo option — it doesn't touch what's typed.
      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, 'K2HAM');
    });

    testWidgets('editing an unmodified QSO shows delete; tapping stages it and offers undo', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW', 'sent': ''},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      expect(secondButton(tester, deleteIcon).onPressed, isNotNull);
      expect(find.byIcon(undoIcon), findsNothing);

      await tester.tap(find.byIcon(deleteIcon));
      await tester.pump();

      expect(find.textContaining('will be deleted'), findsOneWidget);
      expect(find.byIcon(deleteIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      expect(find.textContaining('will be deleted'), findsNothing);
      expect(find.byIcon(deleteIcon), findsOneWidget);
    });

    // Revert-changes is NOT on the chord: while editing, Cmd+Z means the last
    // keystroke, and claiming it would throw the whole edit away instead.
    testWidgets('Cmd+Z while editing a changed QSO does not revert it', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      // Two fields, so that whatever text undo does to the focused one, the
      // other still tells a revert apart from it.
      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AWX');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget, reason: 'the second button offers revert');

      await sendChord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyZ);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
    });

    testWidgets('editing changes the second button to revert-changes; tapping restores the original values', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      expect(find.byIcon(deleteIcon), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();

      expect(find.byIcon(deleteIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      final sentField = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
      expect(sentField.controller!.text, '59');
      expect(find.byIcon(deleteIcon), findsOneWidget);
      expect(find.byIcon(undoIcon), findsNothing);
    });

    testWidgets('reverting a typed grid takes back the edit itself, not just what the field shows', (tester) async {
      // A grid reaches the record only once the field was touched, and a
      // touched grid also stamps the square's center on it as lat/lon. So a
      // Revert that restores the VALUES and leaves the flag standing saves a
      // coordinate the operator never entered — and a coordinate outranks a
      // grid wherever one is read (docs/design/locations.md), so the invented
      // pair then wins over the square it was derived from.
      //
      // The test above reverts Sent, which no flag gates; it passes either
      // way. This one is why Revert resets the session before repopulating.
      // The fixture carries every field the panel itself would write, because
      // a record missing one never compares equal to the draft and would show
      // Revert from the moment it opened — a fixture that cannot reach
      // "unchanged" cannot test a button for returning to it.
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59', 'grid': 'FN31pr'},
          'our': {'call': 'KI2D', 'sent': '59'},
          'band': '20m',
          'mode': 'SSB',
          'freq': 14285.0,
          'startAtMillis': 1000000,
          'refs': <dynamic>[],
        }),
      ))!;
      expect((existing.data['their'] as Map)['lat'], isNull, reason: 'an imported record with a square and no fix');

      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existing, onEditCanceled: () {}),
          prefs: const LoggingPreferences(showGridField: true),
        ),
      );
      await tester.pump();
      expect(find.byIcon(deleteIcon), findsOneWidget, reason: 'nothing edited yet');

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget, reason: 'the edit is offered back');

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      // As stored, not uppercased: the formatter acts on what is typed, and
      // this value was put back by the panel.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).controller!.text, 'FN31pr');
      expect(find.byIcon(deleteIcon), findsOneWidget, reason: 'the record is unchanged again, so the button is Delete once more');
      expect(find.byIcon(undoIcon), findsNothing);

      // And the save that follows writes nothing new. Polled on the write
      // STAMP, not on the content: "unchanged" is the expected state, so
      // every assertion below is equally true of the record the fixture
      // created, and a save that never ran at all would read exactly the
      // same. The stamp moving is the only thing that says one happened.
      await tester.tap(find.byType(FilledButton));
      var saved = existing;
      for (var i = 0; i < 20 && saved.data['updatedAtMillis'] == existing.data['updatedAtMillis']; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(
        saved.data['updatedAtMillis'],
        isNot(existing.data['updatedAtMillis']),
        reason: 'the save really ran, so what follows is a claim about what it wrote',
      );

      final their = saved.data['their'] as Map;
      expect(their['grid'], 'FN31pr', reason: 'the stored square, exactly as it was');
      expect(their['lat'], isNull, reason: 'no coordinate was invented from the square the operator typed over');
      expect(their['lon'], isNull);
    });

    testWidgets('Escape while editing discards changes and ends the editing session, unlike Revert (issue #199)', (tester) async {
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        }),
      ))!;

      var editCanceled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso, onEditCanceled: () => editCanceled = true),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget); // a change is pending, same as the Revert test above

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Revert (the button above) only discards the typed change and stays
      // in edit mode — Escape closes the editing session entirely.
      expect(editCanceled, isTrue);

      // Nothing was saved: the typed '57' never reached the stored record.
      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      expect(stored.single.data['their']['sent'], '59');
    });

    testWidgets('viewing a deleted QSO locks the fields and offers restore; tapping it undeletes (issue #59)', (tester) async {
      final restoreIcon = MdiIcons.deleteRestore;
      final deletedQso = (await tester.runAsync(() async {
        final qso = await qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'mode': 'SSB',
        });
        await qsos.softDelete(qso);
        return (await qsos.watchForOperation(operation.uuid, includeDeleted: true).first).single;
      }))!;

      var editCanceled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: deletedQso, onEditCanceled: () => editCanceled = true),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      // Restore replaces delete/revert entirely, the fields are read-only,
      // and both save paths (button and Enter) are inert until restored.
      expect(find.textContaining('Deleted QSO'), findsOneWidget);
      expect(find.byIcon(deleteIcon), findsNothing);
      expect(secondButton(tester, restoreIcon).onPressed, isNotNull);
      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.enabled, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      var stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid, includeDeleted: true).first))!;
      expect(stored.single.deleted, isTrue);

      // Escape must not blank the locked view either — the fields are the
      // deleted record's only display and can't repopulate without
      // reselecting it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(callField.controller!.text, 'W1AW');

      await tester.tap(find.byIcon(restoreIcon));
      for (var i = 0; i < 20 && !editCanceled; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      expect(stored.single.deleted, isFalse);
      expect(editCanceled, isTrue);
    });
  });

  group('the composing draft survives a detour through an earlier QSO', () {
    // `editingQso` going non-null and back to null is exactly what Up into
    // the list, a list click, and Down back out all drive from the app (see
    // LoggingPanel) — exercising it directly here covers all three at once.
    testWidgets('Escape after browsing to an earlier QSO restores the draft, not a blank form', (tester) async {
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'mode': 'SSB',
          'freq': 14285.0,
        }),
      ))!;

      var editCanceled = false;
      await tester.pumpWidget(host(session: LoggingSession(onEditCanceled: () => editCanceled = true)));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();

      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existingQso, onEditCanceled: () => editCanceled = true),
        ),
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(editCanceled, isTrue);

      // The parent responds to onEditCanceled by clearing editingQso — same
      // as LoggingPanel's own wiring.
      await tester.pumpWidget(host(session: LoggingSession(onEditCanceled: () => editCanceled = true)));

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text,
        'N0CALL',
        reason: 'the draft the operator was composing comes back, not a blank form',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
    });

    testWidgets('the draft comes back after saving the edit too, not just after canceling it', (tester) async {
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'mode': 'SSB',
          'freq': 14285.0,
        }),
      ))!;

      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();

      await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));
      // 'Rcvd' (their.sent), not 'Sent' (our.sent) — matches the assertion
      // below on data['their']['sent'].
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '57');
      await tester.pump();
      // The FilledButton, not Enter: Rcvd's own onSubmitted doesn't reach
      // _log() the way the callsign field's does.
      await tester.tap(find.byType(FilledButton));

      await waitForQsosWhere(tester, 'the edited Rcvd', (logged) => logged.single.data['their']['sent'] == '57');

      // The parent responds to onLogged by clearing editingQso too.
      await tester.pumpWidget(host());
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text,
        'N0CALL',
        reason: 'saving an earlier edit must not lose the QSO being composed',
      );
    });

    testWidgets('switching directly between two earlier QSOs keeps the original draft, not the first one\'s', (tester) async {
      final first = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'mode': 'SSB',
          'freq': 14285.0,
        }),
      ))!;
      final second = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'K1ABC', 'sent': '59'},
          'mode': 'SSB',
          'freq': 14285.0,
        }),
      ))!;

      var editCanceled = false;
      await tester.pumpWidget(host(session: LoggingSession(onEditCanceled: () => editCanceled = true)));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();

      // Into the first, then straight across to the second — the way arrow
      // keys walk the list without ever passing back through null.
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: first, onEditCanceled: () => editCanceled = true),
        ),
      );
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: second, onEditCanceled: () => editCanceled = true),
        ),
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'K1ABC');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(editCanceled, isTrue);
      await tester.pumpWidget(host(session: LoggingSession(onEditCanceled: () => editCanceled = true)));

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text,
        'N0CALL',
        reason: 'the snapshot taken on the way into "first" must survive the trip through "second" too',
      );
    });
  });

  // The write gate refuses at the repository, which tells the operator AFTER
  // they typed a contact that it did not land. Locking the form is what makes
  // it never typeable — the difference between a refusal and a lost contact.
  group('an unwritable operation locks the form', () {
    /// How many of the panel's entry fields accept input right now.
    ///
    /// Counted across every TextField rather than singling one out: "the
    /// fields are disabled" is the actual claim, and an assertion on one
    /// field would pass while the rest of the row stayed typeable.
    int enabledFields(WidgetTester tester) => tester.widgetList<TextField>(find.byType(TextField)).where((f) => f.enabled ?? true).length;

    testWidgets('every entry field is disabled while the clock is travelled', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(enabledFields(tester), greaterThan(0), reason: 'sanity: a real operation is writable on a real clock');

      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(enabledFields(tester), 0);
    });

    testWidgets('the panel says why, in the operator\'s words', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(find.textContaining('only test operations and contacts can be changed'), findsOneWidget);
    });

    testWidgets('it unlocks again when the clock comes back', (tester) async {
      // The half a listener-less implementation gets wrong: locking on travel
      // is easy to notice, staying locked afterwards is not.
      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();
      expect(enabledFields(tester), 0);

      AppClock.instance.reset();
      await tester.pump();

      expect(enabledFields(tester), greaterThan(0));
    });

    testWidgets('a TEST operation stays typeable while travelled', (tester) async {
      // The gate is about which records may be written, not about travel
      // itself — a panel that locked regardless would make the feature
      // useless for the one thing it exists to allow.
      await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'stationCall': 'KI2D/T'}));
      operation = (await operations.get(operation.uuid))!;

      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(enabledFields(tester), greaterThan(0));
    });
  });
}
