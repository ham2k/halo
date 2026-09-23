// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The searchable-options exchange field: its suggestions, the keys that take
// one, the menu the offers float in, and one field holding several values.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

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
}
