// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The main logging row's sizing rules on their own — the concessions
// docs/design/logging-fields.md lists, in the order it lists them. The
// widget suite sees them through rendered widths; these pin the arithmetic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_metrics.dart';
import 'package:halo_widgets/src/theme.dart';

// Round numbers a test can reason about: a callsign floor of 60, a field
// floor of 20, and 8 of padding, so a field's floor is 28.
const _floors = (callValue: 60.0, fieldValue: 20.0, fullPadding: 8.0);
const _button = 44.0;

MainField _field({double minWidth = 64, double gapBefore = 8, FocusNode? focus}) => (
      gapBefore: gapBefore,
      minWidth: minWidth,
      focusNode: focus ?? FocusNode(),
      build: (_, _, _) => const SizedBox(),
    );

/// The width at which [fields] fit with [slack] to spare — the gaps, the
/// button, and the callsign's floor plus its padding, all at full size. A
/// field's declared minimum already includes its own padding.
double _fits(List<MainField> fields, {double slack = 0}) =>
    _button +
    logButtonGap +
    fields.fold(0.0, (w, f) => w + f.gapBefore + f.minWidth) +
    _floors.fullPadding +
    _floors.callValue +
    slack;

void main() {
  test('everything fits: declared widths, nothing given up', () {
    final fields = [_field(), _field(), _field(minWidth: 76)];
    final r = resolveMainFieldLayout(fields: fields, maxWidth: _fits(fields, slack: 40), buttonWidth: _button, floors: _floors);
    expect(r.layout.widths, [64, 64, 76]);
    expect(r.layout.gapScale, 1);
    expect(r.layout.fieldPadding, 8);
    expect(r.squeezed, isFalse);
  });

  test('a shortfall comes off each field evenly, the same pixels off each', () {
    final fields = [_field(), _field(), _field(minWidth: 76)];
    final r = resolveMainFieldLayout(fields: fields, maxWidth: _fits(fields) - 30, buttonWidth: _button, floors: _floors);
    expect(r.layout.widths, [54, 54, 66], reason: 'the wider field stays wider by exactly what it asked');
    expect(r.layout.gapScale, 1, reason: 'the gaps are untouched while the fields can still give');
    expect(r.squeezed, isTrue);
  });

  test('a field at its floor gives no more; the others carry the rest', () {
    // Floors at 28: a 40 shortfall over three 64s would be 13.3 each, but
    // the narrow field can only give 4, so the other two give 18 each.
    final fields = [_field(minWidth: 32), _field(), _field()];
    final r = resolveMainFieldLayout(fields: fields, maxWidth: _fits(fields) - 40, buttonWidth: _button, floors: _floors);
    expect(r.layout.widths[0], 28);
    expect(r.layout.widths[1], closeTo(46, 0.5));
    expect(r.layout.widths[2], closeTo(46, 0.5));
  });

  testWidgets('the focused field is exempt, and its neighbours carry its share', (tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(home: Focus(focusNode: focus, child: const SizedBox())));
    focus.requestFocus();
    await tester.pump();
    final fields = [_field(focus: focus), _field(), _field()];
    final r = resolveMainFieldLayout(fields: fields, maxWidth: _fits(fields) - 30, buttonWidth: _button, floors: _floors);
    expect(r.layout.widths, [64, 49, 49]);
  });

  test('past the floors, gaps and padding shrink together and gradually', () {
    final fields = [_field(), _field()];
    // Even at their floors the fields need 28 each; take 20 more than that.
    final atFloors = _fits(fields) - 2 * (64 - 28);
    final r = resolveMainFieldLayout(fields: fields, maxWidth: atFloors - 20, buttonWidth: _button, floors: _floors);
    expect(r.layout.gapScale, lessThan(1));
    expect(r.layout.gapScale, greaterThan(0));
    expect(r.layout.fieldPadding, r.layout.gapScale * 8, reason: 'one fraction of both');
    expect(r.layout.widths, everyElement(lessThan(28)), reason: 'the floors shrink with the padding');
    expect(r.layout.widths, everyElement(closeTo(20 + r.layout.fieldPadding, 0.5)));
  });

  test('with nothing left to give, the callsign gives its own floor', () {
    final fields = [_field(), _field()];
    final r = resolveMainFieldLayout(fields: fields, maxWidth: _button + 40 + 2 * 20, buttonWidth: _button, floors: _floors);
    expect(r.layout.gapScale, 0);
    expect(r.layout.fieldPadding, 0);
    expect(r.layout.widths, [20, 20]);
    expect(r.squeezed, isTrue);
  });


  // The label half of the same squeeze: a field narrower than "QP Location"
  // shows "QP Loc" rather than an ellipsized "QP Loca…", which names the field
  // no better than nothing does.
  testWidgets('a squeezed field falls back to its short label, and only then', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        context = ctx;
        return const SizedBox();
      }),
    ));

    String pick(double width, {String? shortLabel}) => mainFieldLabel(
          context,
          label: 'QP Location',
          shortLabel: shortLabel,
          width: width,
          horizontalPadding: 8,
        );

    // Measured, not assumed: the threshold is whatever the label actually
    // paints at under this font and text scaler, so the test states the rule
    // rather than a pixel count that a font change would quietly invalidate.
    final full = textWidth(context, 'QP Location', poloFieldLabelStyle(context));
    final fits = full * floatingLabelScale + 8 - materialFilledInputGap;
    expect(pick(fits + 1, shortLabel: 'QP Loc'), 'QP Location');
    expect(pick(fits - 1, shortLabel: 'QP Loc'), 'QP Loc');

    // No short label declared: the decoration's own ellipsis is the fallback,
    // so the full label comes back however narrow the field is.
    expect(pick(20), 'QP Location');
    expect(pick(20, shortLabel: ''), 'QP Location');
  });

  // The arithmetic in [mainFieldLabelWidth] restates two things Material keeps
  // private — that a floating label is laid out at full size and painted at
  // `_kFinalLabelScale`, and that the extra gap on a filled field goes to the
  // content rather than the label. A restatement is only as good as the day it
  // was written, so this renders a real field and reads the box back: it fails
  // the day either of those changes, which is the whole point of it.
  testWidgets('the label budget is what InputDecorator actually hands the label', (tester) async {
    for (final (width, padding) in [(76.0, 16.0), (76.0, 8.0), (76.0, 0.0), (110.0, 16.0), (110.0, 0.0)]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (ctx) => TextField(
                  decoration: mainFieldDecoration(ctx, 'QP Location', horizontalPadding: padding),
                ),
              ),
            ),
          ),
        ),
      ));
      final painted = tester.getSize(find.text('QP Location')).width;
      expect(
        mainFieldLabelWidth(width: width, horizontalPadding: padding),
        moreOrLessEquals(painted, epsilon: 0.01),
        reason: 'width $width, padding $padding',
      );
    }
  });

  // The property the two tests above only approximate: with a short label
  // available, the label an operator actually SEES is never cut off, at any
  // width the row can hand a field. Under the real theme and the real Roboto,
  // because both matter — Material paints a floating label on `bodyLarge`,
  // whose letter spacing is wider than the ambient `bodyMedium` a bare
  // `textWidth` would measure with, and the stand-in test font has no letter
  // shapes to be wide with. Measured against that, "QP Location" read 2.75pt
  // narrower than it painted and was chosen for fields it did not fit.
  group('under the real theme and font', () {
    setUpAll(() async {
      final bytes = await File('../../app/assets/fonts/Roboto.ttf').readAsBytes();
      await (FontLoader('Roboto')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    });

    testWidgets('a label with a short form is never shown cut off', (tester) async {
      for (var width = 40.0; width <= 100.0; width += 1) {
        for (final padding in [0.0, 8.0, 16.0]) {
          await tester.pumpWidget(MaterialApp(
            theme: buildHaLoTheme(Brightness.light),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Builder(builder: (context) {
                    final label = mainFieldLabel(
                      context,
                      label: 'QP Location',
                      shortLabel: 'QP Loc',
                      width: width,
                      horizontalPadding: padding,
                    );
                    return TextField(decoration: mainFieldDecoration(context, label, horizontalPadding: padding));
                  }),
                ),
              ),
            ),
          ));
          final shown = find.byWidgetPredicate((w) => w is Text && (w.data == 'QP Location'));
          if (shown.evaluate().isEmpty) continue;
          final paragraph = tester.renderObject<RenderParagraph>(shown);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'at width $width, padding $padding the full label was chosen and then cut off',
          );
        }
      }
    });
  });
}
