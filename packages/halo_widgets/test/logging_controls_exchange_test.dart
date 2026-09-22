// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The primary fields an activity contributes: contest exchanges, the
// searchable-options field, serial numbers, and the reference lists an
// activity control writes to.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('only a running activity gets the entry row', () {
    // The entry row is the scarcest space in the app, and EVERY enabled
    // extension is asked for logging controls on every operation. So the core
    // decides who gets in: a primary field only if the operation carries a ref
    // of the type it writes to. Extensions may short-circuit for their own
    // efficiency, but they are not what enforces this — an extension that
    // forgets must not be able to put its exchange in front of someone logging
    // an ordinary QSO, and a stray `serial` field would be worse still,
    // handing out numbers from a series nobody is keeping.
    const exchange = {
      'key': 'contest/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
    };
    const serial = {
      'key': 'contest/ourSerial',
      'label': 'Our #',
      'icon': 'flag-checkered',
      'input': {
        'kind': 'serial',
        'refType': 'contest',
        'field': 'ourSerial',
        'sequence': {'key': 'serial'},
      },
    };
    // POTA's hunter chip is the reason secondary controls are NOT gated: you
    // chase a park from whatever operation you happen to be running.
    const hunter = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'potaHunter'},
    };

    Widget hostFor(Operation op, List<Map<String, dynamic>> controls, {QsosRepository? repo}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: op, qsosRepository: repo ?? qsos),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: controls),
        ),
      ),
    );

    testWidgets('an exchange field is hidden when the operation is not running that contest', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('the same field appears once the activity is added', (tester) async {
      await tester.pumpWidget(hostFor(running(['contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);
    });

    testWidgets('another contest running does not let this one in', (tester) async {
      // The gate is per ref type, not "is any contest active" — two contests
      // can be set up at once and only one may own a given field.
      await tester.pumpWidget(hostFor(running(['other-contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a secondary chip is still offered from an operation running nothing', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [hunter]));
      await tester.pump();
      expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
    });

    testWidgets('a serial from a contest that is not running allocates no number', (tester) async {
      // The severe case. A number issued here is spent forever — the counter
      // never rolls back — so a log for a contest the operator never entered
      // would silently consume the series.
      final repo = QsosRepository(db, sequences: SequencesRepository(db));
      await tester.pumpWidget(hostFor(operation, const [serial], repo: repo));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Our #'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, isEmpty, reason: 'no contest ref, and no number spent');
    });

    testWidgets("an inactive contest's exchange survives editing a QSO that carries it", (tester) async {
      // Removing the activity must not destroy what already went out on the
      // air. The field is hidden, so nothing can edit it — and it has to
      // round-trip untouched rather than being dropped on the next save.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'refs': [
          {'type': 'contest', 'exchange': 'MA 042'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existing),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: const [exchange]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'contest', 'exchange': 'MA 042'},
      ]);
    });
  });

  group('decorateQsoBeforeSave', () {
    // An activity's last chance to project data it owns into generic QSON
    // fields. It has to run on EVERY save path — a QSO decorated only when
    // logged one way would export differently depending on how it was typed.
    Widget hostWith(Future<Map<String, dynamic>> Function(Map<String, dynamic>, Map<String, dynamic>) decorate, {Qso? editing, List<Qso> log = const []}) =>
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: operation, qsos: log, qsosRepository: qsos, decorateQsoBeforeSave: decorate),
              session: LoggingSession(editingQso: editing),
              radio: baseRadio(),
            ),
          ),
        );

    Future<Map<String, dynamic>> addExchange(Map<String, dynamic> qso, Map<String, dynamic> _) async => {
      ...qso,
      'their': {...(qso['their'] as Map?)?.cast<String, dynamic>() ?? {}, 'exchange': 'ZN5'},
    };

    testWidgets('decorates a single logged QSO', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirExchange, 'ZN5');
      expect(logged.single.theirCall, 'W1AW', reason: 'the patch must not clobber the callsign');
    });

    testWidgets('decorates every call of a call list, not just the first', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC,N1XYZ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 3);
      expect(logged, hasLength(3));
      expect(logged.map((q) => q.theirExchange), everyElement('ZN5'));
    });

    testWidgets('decorates an edited QSO too', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      });
      await tester.pumpWidget(hostWith(addExchange, editing: existing));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirExchange, 'ZN5');
    });

    testWidgets('the hook is handed the operation that was true when the contact was made', (tester) async {
      // A rover changes county at a `break`; a hook that projects "our county"
      // onto a contact has to see the segment the contact falls in, or an
      // EDIT of an old contact would carry it to wherever the operator is now
      // — which is exactly what stamping the county at save time used to
      // guard against, and what handing over the right operation makes
      // unnecessary.
      final breakRow = Qso(
        uuid: 'break',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'startAtMillis': 2000,
          'event': {
            'event': 'break',
            'operation': {
              'refs': [
                {'type': 'qp', 'location': 'WRRN'},
              ],
            },
          },
        },
      );
      final earlier = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': 1000,
      });
      final seen = <String?>[];
      Future<Map<String, dynamic>> record(Map<String, dynamic> qso, Map<String, dynamic> op) async {
        final refs = (op['refs'] as List?) ?? const [];
        seen.add(refs.isEmpty ? null : (refs.first as Map)['location'] as String?);
        return qso;
      }

      Future<void> untilSeen(int count) async {
        for (var i = 0; i < 50 && seen.length < count; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      // Editing the contact made BEFORE the break: the base operation (which
      // carries no `qp` ref) is what was true then, not the break's county.
      await tester.pumpWidget(hostWith(record, editing: earlier, log: [earlier, breakRow]));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await untilSeen(1);
      expect(seen, [null]);

      // A NEW contact belongs to the current segment — the county the break set.
      await tester.pumpWidget(hostWith(record, log: [earlier, breakRow]));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await untilSeen(2);
      expect(seen, [null, 'WRRN']);
    });

    testWidgets('a QSO still saves when no decorator is wired', (tester) async {
      // Every test and tooling path leaves it null; saving must not depend on it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(log: baseLog(), radio: baseRadio()),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirCall, 'W1AW');
      expect(logged.single.theirExchange, isNull);
    });
  });

  testWidgets('activity text control folds a contest exchange into the logged QSO', (tester) async {
    // The on-air exchange is the whole point of a contest control: whatever the
    // operator types must reach the QSO's contest ref, or the log is unusable
    // for submission.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange', 'placeholder': '59 001'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['simple-contest']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA 042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA 042'},
    ]);

    // Logging wiped the field, so the next QSO starts clean rather than
    // silently repeating the previous station's exchange.
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
    expect(field.controller?.text, '');
  });

  group('searchable options exchange', () {
    // A `kind: 'options'` field is a text field that searches a known set. It
    // joins the same pipeline as `text`, so save, restore, focus cycling and
    // the blank rule are inherited rather than reimplemented — these cover what
    // is genuinely new: validation against the set, the suggestion line, and
    // Space accepting the top hit BEFORE it advances.
    const counties = [
      {'code': 'ASD', 'name': 'Ashland'},
      {'code': 'CUY', 'name': 'Cuyahoga'},
      {'code': 'WAS', 'name': 'Washington'},
    ];

    List<Map<String, dynamic>> controlsWith(Map<String, dynamic> extra) => [
      {
        'key': 'qp/county',
        'label': 'County',
        'icon': 'flag-checkered',
        'input': {'kind': 'options', 'refType': 'qp', 'field': 'county', 'options': counties, ...extra},
      },
    ];

    Widget hostWithExtra({Map<String, dynamic> extra = const {}}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: running(['qp']), qsosRepository: qsos),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: controlsWith(extra)),
        ),
      ),
    );

    testWidgets('is a primary field, so it saves onto the ref like any exchange', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'CUY'},
      ]);
    });

    testWidgets('Arrow Up walks the open menu rather than stepping out to the pills (APP-19)', (tester) async {
      // Up and Down belong to the suggestion menu for as long as it is
      // showing. The focus ladder's Arrow Up (main field → pill strip) has to
      // stand aside for it, or the menu becomes unusable from the keyboard on
      // exactly the fields that offer one.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets, reason: 'the menu is up');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // Still in the field with the menu still up — not parked on a pill.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus, isTrue);
      expect(find.textContaining('Ashland'), findsWidgets);
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        expect(chip.focusNode?.hasFocus ?? false, isFalse);
      }
    });

    testWidgets('suggests matches for what is typed, best first', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // ASD by code prefix, then WAS by code substring. The line shows names
      // too, since a name is often what the operator actually remembers.
      expect(find.textContaining('ASD'), findsWidgets);
      expect(find.textContaining('Ashland'), findsWidgets);
      expect(find.textContaining('WAS'), findsWidgets);
    });

    testWidgets('Space accepts the top suggestion AND still advances', (tester) async {
      // The advance is what an operator's hands expect on every field; losing
      // it to a searchable one would be worse than never suggesting at all.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'CUY', reason: 'the partial "CU" was completed from the set');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus,
        isFalse,
        reason: 'and focus moved on, as Space always does',
      );
    });

    testWidgets('Space with no match just advances, changing nothing', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'ZZ',
        reason: 'nothing matched, so nothing was rewritten under the operator',
      );
    });

    testWidgets('a value outside the set is flagged, because it is a lost multiplier', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      InputDecoration decoration() => tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration!;
      final errorColor = Theme.of(tester.element(find.widgetWithText(TextField, 'County'))).colorScheme.error;

      // The field's own underline carries the tint. NOT `errorText`: a decorator
      // with an error reserves its error slot even when the text is empty and
      // styled to zero height, which made the field taller and pushed every
      // primary control down as the operator typed — see the layout test below.
      expect(decoration().errorText, isNull, reason: 'no error slot, so no resize');
      expect((decoration().enabledBorder as UnderlineInputBorder).borderSide.color, errorColor);
      expect((decoration().focusedBorder as UnderlineInputBorder).borderSide.color, errorColor);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'WAS');
      await tester.pump();
      expect(decoration().enabledBorder, isNull, reason: 'a recognized value gets the ordinary border back');
      expect((decoration().focusedBorder as UnderlineInputBorder).borderSide.color, isNot(errorColor));
    });

    testWidgets('allowFreeform accepts a value the set does not know', (tester) async {
      // Some exchanges are genuinely open-ended; the set is then a shortcut,
      // not a constraint.
      await tester.pumpWidget(hostWithExtra(extra: const {'allowFreeform': true}));
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration?.errorText, isNull);
    });

    testWidgets('minCharsForSuggestions holds the line back until it is useful', (tester) async {
      await tester.pumpWidget(hostWithExtra(extra: const {'minCharsForSuggestions': 2}));
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'A');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets);
    });

    testWidgets('Space on an EMPTY field writes nothing — it is just "next field"', (tester) async {
      // An empty query's suggestion list is the whole SET, so accepting the top
      // hit logged whichever option happened to be declared first — for an
      // operator who simply hadn't been given the exchange yet and was moving on.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        '',
        reason: 'ASD is first in the set and must not have been written',
      );
    });

    testWidgets('Space refuses a suggestion the typed text does not START', (tester) async {
      // A substring hit is worth SHOWING — it is how you find a county from the
      // middle of its name — but swapping it in replaces what the operator typed
      // with a code their own text isn't a prefix of.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets, reason: 'matched by name substring');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'SH', reason: 'shown, not accepted');
    });

    testWidgets('the offers float over the fields as a menu, the best row nearest the field', (tester) async {
      // They started as a line in the info area, which cost the call-info panel
      // — the DUPE warning with it — its space for as long as an exchange field
      // had focus. As a floating menu they cover that area instead: nothing in
      // the layout moves as the operator types, and the panel keeps saying what
      // it said.
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      final menu = find.byKey(exchangeSuggestionsKey);
      expect(menu, findsOneWidget);
      Finder inMenu(String text) => find.descendant(of: menu, matching: find.text(text));

      // ASD matches by code prefix, WAS only by code substring.
      expect(inMenu('ASD'), findsOneWidget);
      expect(inMenu('Ashland'), findsOneWidget, reason: 'the name reads beside the code');
      expect(inMenu('WAS'), findsOneWidget);

      // BOTTOM is best: the eye is already at the field, and Space takes this one.
      expect(
        tester.getCenter(inMenu('ASD')).dy,
        greaterThan(tester.getCenter(inMenu('WAS')).dy),
        reason: 'the best match sits nearest the field, at the bottom of the menu',
      );
      // ...and it is the only one in bold.
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontWeight, FontWeight.w700);
      expect(tester.widget<Text>(inMenu('WAS')).style?.fontWeight, FontWeight.w400);

      // One rectangle with a shadow, not a stack of chips, and in the DIALOG
      // colours rather than the panel's accent — it floats over the panel.
      final material = tester.widget<Material>(find.descendant(of: menu, matching: find.byType(Material)).first);
      expect(material.elevation, greaterThan(0));
      expect(material.color, Theme.of(tester.element(menu)).colorScheme.surface);

      // Monospace codes: log data, read as a column and compared character by
      // character against what is in the field.
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontFamily, 'RobotoMono');

      // The codes line up in a column of one width, whatever their names measure:
      // a ragged column reads as unrelated chips, and the code is what the
      // operator is scanning for because it is what lands in the log.
      expect(tester.getSize(inMenu('ASD')).width, tester.getSize(inMenu('WAS')).width);
      expect(tester.getTopLeft(inMenu('ASD')).dx, tester.getTopLeft(inMenu('WAS')).dx);

      // Hung off THIS field: the menu's bottom-LEFT against the field's top-left,
      // then shifted left by exactly the name column — which puts the CODE
      // column's left edge on the field's own left edge. Asserted through the link
      // and the offset rather than by measuring, because a follower's offset is
      // applied when its layer paints and the render box still reports
      // unpositioned geometry here.
      final follower = tester.widget<CompositedTransformFollower>(menu);
      final target = tester.widget<CompositedTransformTarget>(
        find.ancestor(of: find.widgetWithText(TextField, 'County'), matching: find.byType(CompositedTransformTarget)),
      );
      expect(follower.link, same(target.link), reason: 'anchored to the exchange field, not the panel');
      expect(follower.targetAnchor, Alignment.topLeft);
      expect(follower.followerAnchor, Alignment.bottomLeft);
      final rowWidth = tester.getSize(find.descendant(of: menu, matching: find.byType(InkWell)).first).width;
      final codeCell = find.ancestor(of: inMenu('ASD'), matching: find.byType(Container)).first;
      expect(
        follower.offset.dx,
        -(rowWidth - tester.getSize(codeCell).width),
        reason: 'shifted left by the name column, so the code column starts at the field',
      );

      // And the info area still has its own content.
      expect(find.textContaining('W1AW'), findsWidgets);
    });

    testWidgets('tapping a row takes that value, even one Space would not', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // WAS is a substring hit, which Space deliberately refuses — a tap is not a
      // guess, it is the operator pointing at the row they want.
      //
      // The row's own callback rather than `tester.tap`: a follower's offset is
      // applied when its layer paints, so the geometry `tap()` derives is the
      // menu's unpositioned layout box and the tap lands nowhere near the row
      // (it warns about exactly that). Whether a painted follower hit-tests
      // correctly is `RenderFollowerLayer`'s business; what this pins is that a
      // row's tap writes the value.
      final row = find.ancestor(
        of: find.descendant(of: find.byKey(exchangeSuggestionsKey), matching: find.text('WAS')),
        matching: find.byType(InkWell),
      );
      tester.widget<InkWell>(row.first).onTap!();
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus,
        isTrue,
        reason: 'the field keeps focus: a menu row is a value, not somewhere to land',
      );
    });

    testWidgets('Escape closes the menu and nothing else — the QSO survives it', (tester) async {
      // What else Escape does in this panel throws away work: it discards an
      // edit, or deselects. With a menu up, Escape
      // means "not that" — and losing a half-typed contact to a keystroke aimed
      // at a dropdown is not a recoverable mistake. It takes the menu whether or
      // not the highlight was ever touched.
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(exchangeSuggestionsKey), findsNothing, reason: 'the menu is gone');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller?.text,
        'W1AW',
        reason: 'and the contact being typed is untouched',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'AS');

      // A further keystroke is a new question, so the offer comes back.
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ASD');
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);

      // With no menu left to close, a further Escape has nothing to take.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // closes the menu
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller?.text, 'W1AW');
    });

    testWidgets('Tab takes the offer on the way out, like Space — Shift+Tab does not', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'CUY',
        reason: 'leaving the field forward is the same statement Space makes',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus, isFalse, reason: 'and Tab still traverses');

      // Shift+Tab is stepping BACK to a field the operator may return to, so it
      // leaves the partial value alone.
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'CU');
    });

    testWidgets('Enter takes a highlighted suggestion instead of logging the QSO', (tester) async {
      // A highlight the operator walked to is a pending choice. Logging on that
      // Enter would commit a QSO whose exchange they were still picking, and
      // unlike a wrong exchange, a sent QSO can't be undone with another Enter.
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // onto WAS
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
      expect(
        (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!,
        isEmpty,
        reason: 'that Enter chose a value; it did not send the contact',
      );

      // And the next one logs, because accepting cleared the highlight: pick,
      // then send, which is the sequence the hands were making anyway.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'WAS'},
      ]);
    });

    testWidgets('Enter with the highlight untouched logs, as it does everywhere else', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      // A PREFIX, not the whole code: an exact match would make `acceptSuggestion`
      // bail on `typed == chosen.code` and this test would pass even if Enter
      // stopped checking whether anything was pending at all.
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      // The menu is open and CUY is the top hit, but nothing is PENDING — the
      // operator hasn't chosen anything, so Enter has to mean send.
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'CU'},
      ], reason: 'logged as typed — Enter did not quietly complete it first');
    });

    testWidgets('the arrow keys walk the highlight, and Space takes what is highlighted', (tester) async {
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // The menu reads (top to bottom) WAS, ASD — so Up moves off the best match
      // and onto the row above it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      Finder inMenu(String text) => find.descendant(of: find.byKey(exchangeSuggestionsKey), matching: find.text(text));
      expect(tester.widget<Text>(inMenu('WAS')).style?.fontWeight, FontWeight.w700, reason: 'the highlight moved up');
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontWeight, FontWeight.w400);

      // Space now takes the highlighted one rather than the best one — having
      // moved the highlight IS the choice, so the prefix rule doesn't apply.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
    });

    testWidgets('opening the menu moves nothing: the fields stay exactly where they were', (tester) async {
      // The jump this pins was NOT the menu — it was the invalid-value tint. An
      // `errorText`, even an empty one styled to zero height, still makes the
      // decorator reserve its error slot, and through the row's IntrinsicHeight
      // that pushed every primary control and the submit button down 5px. A
      // contest exchange is invalid for most of the keystrokes it takes to type,
      // so it happened on every QSO.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      Rect callField() => tester.getRect(find.widgetWithText(TextField, 'Their call'));
      final before = callField();

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS'); // invalid + menu open
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);
      expect(callField(), before, reason: 'a partial value is invalid, and must not resize the row');

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ASD'); // valid, menu still open
      await tester.pump();
      expect(callField(), before);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ'); // invalid, no menu
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsNothing);
      expect(callField(), before, reason: 'and neither must an unrecognized one');
    });

    testWidgets('an arrow that cannot move the highlight is not a choice', (tester) async {
      // The menu is drawn best-at-the-bottom, so ↓ from an untouched selection has
      // nowhere to go — and neither arrow moves anything on a one-row menu. Those
      // keystrokes used to arm "the operator chose this" anyway, which took the
      // prefix guard off the NEXT Space: `SH` matches Ashland and Washington by
      // name substring only, and Space turned the field into `ASD`, a county
      // nobody worked.
      await tester.pumpWidget(hostWithExtra());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      String text() => tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text ?? '';

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // already at the bottom
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(text(), 'SH', reason: 'nothing moved, so nothing was chosen, so the guard still applies');

      // Enter is the other reader of the same flag: with nothing chosen it has to
      // mean "log", not "pick".
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1), reason: 'that Enter had no pending choice to take, so it sent the contact');
      expect(text(), '', reason: 'and the field was not rewritten under the operator');
    });

    testWidgets('editing a QSO restores the exchange, and focus alone paints the offer', (tester) async {
      // On an existing QSO nothing else is repainting the panel — the callsign
      // isn't being typed — so without a focus listener the offer never appeared
      // while Space would still have rewritten the field.
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
          'refs': [
            {'type': 'qp', 'county': 'CUY'},
          ],
        }),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['qp']), qsosRepository: qsos),
              session: LoggingSession(editingQso: existing),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controlsWith(const {})),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'CUY',
        reason: 'the saved exchange comes back into the field',
      );

      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cuyahoga'), findsWidgets, reason: 'focus alone paints the offer');
    });

    group('several values in one field — a county line', () {
      // A QSO party's station may be on a county line and send both counties as
      // one exchange. Every value is checked, and the suggestion line and Space
      // act on the one the cursor is in — accepting a suggestion for the second
      // county must never rewrite the first, which the operator typed.
      Widget lineHost() => hostWithExtra(
        extra: const {
          'multiValue': {'separator': '/'},
        },
      );

      testWidgets('both values are checked, not just the last', (tester) async {
        await tester.pumpWidget(lineHost());
        InputDecoration decoration() => tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration!;

        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WAS');
        await tester.pump();
        expect(decoration().enabledBorder, isNull, reason: 'both counties are in the set');

        // A typo in the FIRST value is the case a last-value-only check misses,
        // and it costs a multiplier just as surely.
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ/WAS');
        await tester.pump();
        final errorColor = Theme.of(tester.element(find.widgetWithText(TextField, 'County'))).colorScheme.error;
        expect((decoration().enabledBorder as UnderlineInputBorder).borderSide.color, errorColor);
      });

      testWidgets('the suggestion line answers for the value being typed', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/AS');
        await tester.pump();

        // Matches for "AS", not for the whole string — which matches nothing at
        // all, so without this the menu simply never appears on a county line.
        expect(find.textContaining('Ashland'), findsWidgets);
      });

      testWidgets('Space completes the second county and leaves the first alone', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WA');
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'CUY/WAS');
      });

      testWidgets('a borrowed prefix beats a same-named county in another state', (tester) async {
        // 7QP's `ORDES/JEF` means Oregon's Jefferson — the first county says
        // which state. But `JEF` matches `IDJEF`, `MTJEF`, `ORJEF` and `WAJEF`
        // by NAME, so the literal reading always matched and Space took the
        // first of them: Idaho's Jefferson, silently, for an unambiguous
        // shorthand.
        const jeffersons = [
          {'code': 'IDJEF', 'name': 'Jefferson ID'},
          {'code': 'MTJEF', 'name': 'Jefferson MT'},
          {'code': 'ORDES', 'name': 'Deschutes OR'},
          {'code': 'ORJEF', 'name': 'Jefferson OR'},
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoggingControls(
                log: LogHooks(operation: running(['qp']), qsosRepository: qsos),
                radio: baseRadio(),
                activities: ActivityHooks(
                  activityControls: [
                    {
                      'key': 'qp/county',
                      'label': 'County',
                      'input': {
                        'kind': 'options',
                        'refType': 'qp',
                        'field': 'county',
                        'options': jeffersons,
                        'multiValue': {'separator': '/', 'inheritPrefix': 2},
                      },
                    },
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'ORDES/JEF');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
          'ORDES/ORJEF',
          reason: 'the shorthand names Oregon, and no other Jefferson may be written for it',
        );
      });

      testWidgets('the whole line is what gets logged', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WAS');
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        final logged = await waitForQsos(tester, 1);
        expect(logged.single.refs, [
          {'type': 'qp', 'county': 'CUY/WAS'},
        ]);
      });
    });
  });

  testWidgets('the controls are refreshed again once the online lookup lands', (tester) async {
    // The offline pass knows the caller's COUNTRY; only the online one knows
    // their STATE — and a QSO party's suggestion is the state. Refreshed off
    // the offline pass alone, W1WA's field stayed blank until the operator
    // happened to retype the call and hit the cache.
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            radio: baseRadio(),
            lookups: LookupHooks(
              lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {
                'guess': online ? {'state': 'MA'} : <String, dynamic>{},
              },
            ),
            activities: ActivityHooks(
              activityControls: const [exchange],
              // The hint is whatever state the QSO carries when asked — the shape
              // a QSO party's control takes.
              refreshActivityControls: (qso) async {
                final state = ((qso['their'] as Map?)?['guess'] as Map?)?['state'] as String?;
                return [
                  {
                    ...exchange,
                    'input': {...exchange['input'] as Map, 'placeholder': ?state},
                  },
                ];
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1WA');
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
    expect(field.decoration?.hintText, 'MA', reason: 'the state arrived with the online pass, and was asked for');
  });

  group('a prefill and the callsign it was made for', () {
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };

    /// A contest that suggests `CA` for W6ABC and cannot fetch at all for
    /// anybody else — the refresh a withdrawal must not depend on.
    Future<void> pumpPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                refreshActivityControls: (qso) async => (qso['their'] as Map?)?['call'] == 'W6ABC'
                    ? [
                        {
                          ...exchange,
                          'input': {...exchange['input'] as Map, 'suggestedValue': 'CA'},
                        },
                      ]
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    String exch(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).controller!.text;

    testWidgets('is taken back when the call is corrected, even if nothing is fetched for the new one', (tester) async {
      // Correcting W6ABC to K2XYZ whose refresh fails: nothing refreshes, so a
      // withdrawal that waited on a refresh would leave `CA` in an untouched
      // field — a legal code nothing tints, logged as K2XYZ's exchange.
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ');
      await tester.pumpAndSettle();
      expect(exch(tester), '', reason: "W6ABC's exchange must not be logged for K2XYZ");
    });

    testWidgets('is never made for a field holding several calls', (tester) async {
      // One exchange field is logged for every call in the list, so one
      // station's exchange in it would be logged for all of them.
      await pumpPanel(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), 'CA');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2XYZ,W6ABC');
      await tester.pumpAndSettle();
      expect(exch(tester), '', reason: 'a second call joined, and the lookup for W6ABC fills nothing now');
    });
  });

  group('a refresh that could not fetch', () {
    // `refreshActivityControls` fires when a callsign lookup resolves, mid-QSO,
    // while the operator is typing. Its result is installed over
    // `activityControls` — so a fan-out that failed and answered with an empty
    // list would take every activity field off the panel with no message. Null
    // is how "I could not fetch them" is said; an empty list still means "no
    // controls for this QSO" and must keep working.
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };

    Future<void> pumpTyping(
      WidgetTester tester,
      Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic>) refresh, {
      List<Map<String, dynamic>> panelControls = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(activityControls: panelControls, refreshActivityControls: refresh),
            ),
          ),
        ),
      );
    }

    testWidgets('a later failure keeps what an earlier refresh fetched', (tester) async {
      // The panel-level set is EMPTY here on purpose. Assigning null on
      // failure would look harmless — `ActivityRefsModel.controls` falls back
      // to `widget.activityControls` — which is exactly why the fallback must
      // not be the thing under test: with nothing to fall back to, dropping
      // the guard takes the field away and only this shape notices.
      var call = 0;
      await pumpTyping(tester, (_) async => call++ == 0 ? [exchange] : null);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the first refresh fetched it');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'a refresh that could not fetch must not blank the QSO in progress');
    });

    testWidgets('an empty answer still means the activities want no controls', (tester) async {
      // The mutation this catches: folding empty in with null would make a
      // control impossible to remove for a QSO once it had been shown.
      // Keyed on the callsign, not on how many times it was asked: a call is
      // refreshed once per lookup pass, and a counter would read the second
      // pass for W1AW as the answer for K1ABC.
      await pumpTyping(tester, (qso) async => (qso['their'] as Map?)?['call'] == 'W1AW' ? [exchange] : const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a ref added to the operation is not shadowed by an earlier empty refresh', (tester) async {
      // The scenario the refs model's refreshed set traps: a callsign lookup
      // resolved BEFORE the contest was added to the operation, caching an
      // empty per-QSO refresh. Adding the contest gives the operation a fresh
      // `activityControls` list — that has to win, not the stale cache, or
      // the exchange field stays invisible for the rest of the session.
      await pumpTyping(tester, (_) async => const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing, reason: 'nothing configured yet');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                // A real per-QSO refresh reads the same operation data the
                // operation-level one does, so it agrees once the ref exists —
                // this isn't the fixed-forever-empty callback pumpTyping's other
                // tests use, because a resolved lookup re-fires this on the ref
                // add (see the test below), and that has to see the new field
                // too rather than race the operation-level fetch to install it.
                refreshActivityControls: (_) async => const [exchange],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: "the operation's own refresh must not be shadowed by the stale per-QSO one");
    });

    testWidgets('a per-QSO refresh already in flight when a ref is added cannot reshadow it on return', (tester) async {
      // Distinct from the test above: there the stale refresh had already
      // LANDED before the ref was added. Here it's still IN FLIGHT — issued
      // before, resolving after. Two guards stop it here, because the ref add
      // also re-issues a refresh: the generation it started against, and the
      // refresh ticket, which the newer refresh has moved past. This test is
      // the end-to-end property; the generation guard on its own — a
      // `controlsChanged` with no refresh issued after it — is pinned in
      // activity_refs_model_test.dart.
      final completers = <Completer<List<Map<String, dynamic>>?>>[];
      await pumpTyping(tester, (_) {
        final completer = Completer<List<Map<String, dynamic>>?>();
        completers.add(completer);
        return completer.future;
      });

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 300)); // past the lookup debounce
      await tester.pump(); // the lookup resolves and a refresh is issued per pass
      // Every refresh issued before the ref is added is stale once it is — how
      // many there are depends on how many lookup passes landed, which is not
      // what this test is about.
      final staleCount = completers.length;
      expect(staleCount, greaterThan(0));

      // The ref is added — a fresh `activityControls` identity — WHILE
      // refresh #1 is still pending. Per the fix above, that also re-issues
      // a refresh (#2) against the new activityControls, since a lookup is
      // already resolved for the active call.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['c']), qsosRepository: qsos),
              radio: baseRadio(),
              lookups: LookupHooks(
                lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
              ),
              activities: ActivityHooks(
                activityControls: const [exchange],
                refreshActivityControls: (_) {
                  final completer = Completer<List<Map<String, dynamic>>?>();
                  completers.add(completer);
                  return completer.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(completers, hasLength(staleCount + 1), reason: 'adding the ref re-issued a refresh for the resolved lookup');

      // Resolve the stale, pre-ref-add refreshes AFTER the fresh one — the
      // actual race, not just calls that happen to finish in issue order.
      completers.last.complete(const [exchange]);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the fresh refresh landed');

      for (final stale in completers.take(staleCount)) {
        stale.complete(const []);
      }
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the stale refresh landing late must not blank the field the fresh one just set');
    });
  });

  group('clearing an exchange', () {
    // An empty field means two different things and a contest has to tell them
    // apart: never filled in, or emptied on purpose. Only the latter is
    // recorded, as `field: ''`, and that record is the only thing stopping
    // `processQsoBeforeSave` from guessing the value straight back.
    const clearingControls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    Widget clearingHost({Qso? editing}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(operation: running(['c']), qsosRepository: qsos, qsos: editing == null ? const [] : [editing]),
          session: LoggingSession(editingQso: editing),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: clearingControls),
        ),
      ),
    );

    testWidgets('a field never filled in leaves no trace on the ref', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, isEmpty, reason: 'an untouched empty field is not a decision');
    });

    testWidgets('a field the operator empties is recorded as an explicit blank', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
      await tester.pump();
      // …thought better of it.
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'c', 'exchange': ''},
      ]);
    });

    testWidgets('reopening a QSO with a blanked exchange restores it as blank', (tester) async {
      // The other half: an explicit blank comes back as operator input, so a
      // lookup resolving after the record opens cannot helpfully fill it.
      final existing = Qso(
        uuid: 'existing',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'refs': [
            {'type': 'c', 'exchange': ''},
          ],
        },
      );
      await tester.pumpWidget(clearingHost(editing: existing));
      await tester.pump(const Duration(milliseconds: 500));

      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
      expect(field.controller?.text, '');
    });
  });

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

    testWidgets('shows no number until the operator starts a contact', (tester) async {
      // A shown number is held against every other position from that moment
      // (docs/design/contests.md §5.8.1), so an idle panel holds nothing —
      // and a blank is the only honest display of nothing. The same on a
      // single device: one rule, not a peers-connected special case.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');

      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
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

      final logged = await waitForQsos(tester, 2, repository: repo);
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

      final logged = await waitForQsos(tester, 1, repository: repo);
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

      final logged = await waitForQsos(tester, 1, repository: repo);
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

  testWidgets('a text control uppercases by default, and honours uppercase:false', (tester) async {
    // Contest exchanges are conventionally uppercase, and every other logging
    // field forces it — a lowercase state would also fail a case-sensitive
    // pattern. Names are the exception, hence the opt-out.
    const controls = [
      {
        'key': 'c/state',
        'label': 'St',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'state'},
      },
      {
        'key': 'c/name',
        'label': 'Name',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'name', 'uppercase': false},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'St'), 'ma');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Steve');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs.single['state'], 'MA');
    expect(logged.single.refs.single['name'], 'Steve');
  });

  testWidgets('clearing a text control blanks the field on the ref', (tester) async {
    // Blanking an exchange while editing has to actually blank it — otherwise
    // the old value silently stays in the log and gets exported.
    //
    // It is recorded as `exchange: ''` rather than dropped, which is a change
    // from simply removing it: a contest guesses an exchange onto an ABSENT
    // field at save (docs/design/contests.md §8), so a removed field would be
    // indistinguishable from one never filled in, and the value the operator
    // just deleted would come straight back.
    const controls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    final existing = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'c', 'exchange': 'MA'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['c']), qsosRepository: qsos),
            session: LoggingSession(editingQso: existing),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await tester.pump();

    // The saved value is restored into the field...
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).controller?.text, 'MA');

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    // Reading the repo has to go through runAsync — a drift stream can't
    // resolve inside testWidgets' fake async (see waitForQsos above).
    final stored = (await waitForQsos(tester, 1)).single;
    final ref = stored.refs.firstWhere((r) => r['type'] == 'c');
    expect(ref['exchange'], '', reason: 'the old value must not survive, and the blank must be recorded');
  });

  testWidgets('two text controls sharing a ref type merge into one ref', (tester) async {
    // A contest's setup writes several fields of the SAME ref, so they must
    // merge rather than the last one winning.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange'},
      },
      {
        'key': 'simple-contest/serial',
        'label': 'Nr',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'serial', 'numeric': true},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: running(['simple-contest']), qsosRepository: qsos),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Nr'), '042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA', 'serial': '042'},
    ]);
  });

  testWidgets('activity refList control folds refs into the logged QSO', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);

    // Wipe cleared the control's field too.
    await openControl(tester, MdiIcons.pineTree);
    final potaField = tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
    expect(potaField.controller?.text, '');
  });

  // A reference the pattern rejects is kept and logged, so the chip counts it
  // and reads "✓ POTA" like any other. The tint that says otherwise lives in
  // the expanded field — and the field is shut for most of a QSO, and shut
  // again the moment the contact is logged. Without the chip's own mark the
  // operator is left a check mark over the one reference needing attention.
  testWidgets('the activity chip wears the error pair while a reference fails its pattern', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#00AA00',
        'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    ChoiceChip potaChip() => tester.widget<ChoiceChip>(find.ancestor(of: find.text('✓ POTA'), matching: find.byType(ChoiceChip)).first);

    final scheme = Theme.of(tester.element(find.byType(LoggingControls))).colorScheme;

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'NOT-A-PARK');
    await tester.pump();
    expect(potaChip().selectedColor, scheme.error, reason: 'open chip alerts');

    // Shut, which is how the chip spends most of a QSO — the state in which it
    // is the ONLY thing that can report this.
    await openControl(tester, MdiIcons.pineTree);
    expect(
      tester.widget<ChoiceChip>(find.ancestor(of: find.text('✓ POTA'), matching: find.byType(ChoiceChip)).first).backgroundColor,
      scheme.errorContainer,
      reason: 'closed chip alerts',
    );

    // And it clears: correcting the code takes the alert away rather than
    // leaving the chip red for the rest of the operation.
    await openControl(tester, MdiIcons.pineTree);
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();
    expect(potaChip().selectedColor, isNot(scheme.error));
  });

  testWidgets("activity control's chip icon accents to the extension's color once a reference is entered (issue #187)", (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    // No reference yet: the icon stays the default theme color, not the
    // extension's accent — the accent marks a filled-in field.
    Color? iconColor() => tester.widget<Icon>(find.byIcon(MdiIcons.pineTree)).color;
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await openControl(tester, MdiIcons.pineTree);

    // Still open, no reference yet: no accent.
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    // Still open, but the entered text now matches the control's own
    // pattern and has been accepted as a reference: the accent shows even
    // while the panel is expanded (issue #187 follow-up).
    expect(iconColor(), const Color(0xFF068541));
    // A single reference gets a single check ahead of the label.
    expect(find.text('✓ POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree); // close the panel

    // Closed: the accent stays.
    expect(iconColor(), const Color(0xFF068541));
    expect(find.text('✓ POTA'), findsOneWidget);
  });

  testWidgets('activity control chip label gets a check per reference, or a check plus count past two (issue #187 follow-up)', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );

    // No reference yet: plain label.
    expect(find.text('POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree);

    // A twofer (two parks activated together) gets two checks, not "×2" —
    // it's the common case worth spelling out rather than abbreviating.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();
    expect(find.text('✓✓ POTA'), findsOneWidget);

    // A third reference collapses to a single check plus the total count,
    // so the label doesn't grow one glyph per park on a bigger rove.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678, US-9012');
    await tester.pump();
    expect(find.text('✓×3 POTA'), findsOneWidget);
  });

  testWidgets('activity refList control accepts a comma-separated list of references', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(activityControls: controls),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
      {'type': 'pota', 'ref': 'US-5678'},
    ]);
  });
}
