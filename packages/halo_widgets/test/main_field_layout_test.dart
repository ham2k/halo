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

// Round numbers a test can reason about: a character is 10 wide, so with the
// caret's 3 a field of n characters has a value of 10n + 3, and 8 of padding
// on top of that.
const _metrics = (charWidth: 10.0, fullPadding: 8.0);
const _button = 44.0;
const _call = (min: 6, ideal: 10, max: null);

double _value(int chars) => mainFieldValueWidth(_metrics, chars);

MainField _field(FieldChars chars, {double gapBefore = 8, FocusNode? focus}) =>
    (gapBefore: gapBefore, chars: chars, focusNode: focus ?? FocusNode(), build: (_, _, _) => const SizedBox());

/// The width at which every one of [fields] and the callsign sit exactly at
/// their mins, with the gaps and padding whole — plus [slack].
double _atMins(List<MainField> fields, {double slack = 0}) =>
    _button +
    logButtonGap +
    (fields.length + 1) * _metrics.fullPadding +
    _value(_call.min) +
    fields.fold(0.0, (w, f) => w + f.gapBefore + _value(f.chars.min)) +
    slack;

({MainFieldLayout layout, bool squeezed}) _resolve(List<MainField> fields, double maxWidth) =>
    resolveMainFieldLayout(fields: fields, maxWidth: maxWidth, buttonWidth: _button, metrics: _metrics, call: _call);

/// The callsign's value width: whatever the row leaves it, being `Expanded`.
double _callValue(List<MainField> fields, ({MainFieldLayout layout, bool squeezed}) r, double maxWidth) =>
    maxWidth -
    _button -
    r.layout.gapScale * fields.fold(logButtonGap, (sum, f) => sum + f.gapBefore) -
    r.layout.fieldPadding -
    r.layout.widths.fold(0.0, (sum, w) => sum + w);

/// What a field resolved to, less its padding: its value width.
List<double> _values(({MainFieldLayout layout, bool squeezed}) r) => [for (final w in r.layout.widths) w - r.layout.fieldPadding];

Future<FocusNode> _focused(WidgetTester tester) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Focus(focusNode: focus, child: const SizedBox()),
    ),
  );
  focus.requestFocus();
  await tester.pump();
  return focus;
}

void main() {
  test('a declared width fills in what it leaves out, in order', () {
    expect(fieldChars(), (min: 3, ideal: 3, max: 3));
    expect(fieldChars(min: 2, max: 8), (min: 2, ideal: 2, max: 8));
    // The trap: a max under the ideal taken as given would shrink the field as
    // the row grows past its ideal.
    expect(fieldChars(min: 4, ideal: 6, max: 5), (min: 4, ideal: 6, max: 6));
    expect(fieldChars(min: 5, ideal: 3), (min: 5, ideal: 5, max: 5));
  });

  test("an extension field's width comes from input.chars, then maxLength, then six", () {
    expect(exchangeFieldChars(const {'kind': 'text'}), (min: 3, ideal: 6, max: 6));
    expect(exchangeFieldChars(const {'kind': 'text', 'maxLength': 12}), (min: 3, ideal: 6, max: 12));
    expect(exchangeFieldChars(const {'kind': 'text', 'maxLength': 2}), (min: 2, ideal: 2, max: 2), reason: 'never wider than it can hold');
    expect(
      exchangeFieldChars(const {
        'kind': 'text',
        'maxLength': 12,
        'chars': {'min': 2},
      }),
      (min: 2, ideal: 2, max: 12),
    );
    expect(
      exchangeFieldChars(const {
        'kind': 'text',
        'chars': {'min': 2, 'ideal': 4.0, 'max': 5},
      }),
      (min: 2, ideal: 4, max: 5),
    );
  });

  test('no extension field asks for more than twenty characters', () {
    // The trap: a width written in pixels. Sixty characters is a phone's whole
    // row, with the log button pushed off it — and fine on a desktop.
    expect(
      exchangeFieldChars(const {
        'kind': 'text',
        'chars': {'min': 60, 'ideal': 80},
      }),
      (min: 20, ideal: 20, max: 20),
    );
    expect(exchangeFieldChars(const {'kind': 'text', 'maxLength': 50}), (min: 3, ideal: 6, max: 20));
  });

  test('a declaration the row cannot take as written is named on the console, once', () {
    final lines = <String>[];
    final saved = debugPrint;
    debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    addTearDown(() => debugPrint = saved);

    // Untrusted extension JSON: a count that is no count leaves the default.
    expect(
      exchangeFieldChars(const {
        'kind': 'text',
        'chars': {'min': 'wide', 'ideal': 0},
      }, key: 'qp/county'),
      (min: 3, ideal: 3, max: 3),
    );
    expect(exchangeFieldChars(const {'kind': 'text', 'chars': 8}, key: 'qp/name'), (min: 3, ideal: 6, max: 6));
    expect(
      exchangeFieldChars(const {
        'kind': 'text',
        'chars': {'ideal': 10, 'max': 6},
      }, key: 'qp/loc'),
      (min: 3, ideal: 10, max: 10),
    );
    // Laid out on every frame: still one line each.
    exchangeFieldChars(const {'kind': 'text', 'chars': 8}, key: 'qp/name');
    expect(lines, hasLength(3));
    expect(lines.every((line) => line.startsWith('[extensions] ')), isTrue);
    expect(lines.map((line) => RegExp(r'qp/\w+').firstMatch(line)?[0]), ['qp/county', 'qp/name', 'qp/loc']);

    // A declaration taken as written says nothing.
    exchangeFieldChars(const {
      'kind': 'text',
      'chars': {'min': 2, 'ideal': 4, 'max': 5},
    }, key: 'qp/fine');
    expect(lines, hasLength(3));
  });

  test('the callsign reaches its ideal before any field leaves its min', () {
    final fields = [_field((min: 3, ideal: 4, max: 6)), _field((min: 3, ideal: 6, max: 6))];
    final r = _resolve(fields, _atMins(fields, slack: 30));
    expect(_values(r), [_value(3), _value(3)], reason: 'the 30 went to the callsign, 40 short of its ideal');
    expect(r.layout.gapScale, 1);
    expect(r.squeezed, isTrue);
  });

  test('the fields reach their ideals together, each in proportion to what it needs', () {
    // The callsign takes 40 to its ideal; the 20 left is half of the 10 + 30
    // the fields need, so each gets half of its own need.
    final fields = [_field((min: 3, ideal: 4, max: 6)), _field((min: 3, ideal: 6, max: 6))];
    final r = _resolve(fields, _atMins(fields, slack: 40 + 20));
    expect(_values(r)[0], moreOrLessEquals(_value(3) + 5));
    expect(_values(r)[1], moreOrLessEquals(_value(3) + 15));
    expect(r.squeezed, isTrue);
  });

  test('past the ideals the room goes in proportion to width, so the wider field gets more', () {
    final fields = [_field((min: 3, ideal: 4, max: 20)), _field((min: 3, ideal: 6, max: 20))];
    final atIdeals = _atMins(fields, slack: 40 + 10 + 30);
    final r = _resolve(fields, atIdeals + 50);
    final grown = [_values(r)[0] - _value(4), _values(r)[1] - _value(6)];
    expect(grown[1], greaterThan(grown[0]));
    expect(grown[0] / _value(4), moreOrLessEquals(grown[1] / _value(6)), reason: 'the same share of each one\'s width');
    expect(r.squeezed, isFalse);
  });

  test('a field stops at its max and the callsign takes the rest', () {
    final fields = [_field((min: 3, ideal: 4, max: 4)), _field((min: 3, ideal: 4, max: 6))];
    final r = _resolve(fields, _atMins(fields, slack: 1000));
    expect(_values(r), [_value(4), _value(6)]);
    expect(r.squeezed, isFalse);
  });

  testWidgets('the focused field has its ideal even on a squeezed row, and the gaps pay before the callsign', (tester) async {
    final focus = await _focused(tester);
    final fields = [_field((min: 3, ideal: 6, max: 6), focus: focus), _field((min: 3, ideal: 6, max: 6))];
    final maxWidth = _atMins(fields);
    final r = _resolve(fields, maxWidth);
    expect(_values(r), [_value(6), _value(3)]);
    // The trap: a focused field's extra width taken straight out of the
    // Expanded callsign drives it under its own min — or to nothing, for an
    // extension field with a wide ideal — while the gaps stay whole.
    expect(r.layout.gapScale, lessThan(1), reason: 'the focused field\'s ideal counts as its min');
    expect(_callValue(fields, r, maxWidth), moreOrLessEquals(_value(_call.min)));
    expect(r.squeezed, isTrue, reason: 'the field it is not in is under its ideal, so the next focus change must rebuild');
  });

  testWidgets('a callsign short of its ideal keeps the row squeezed, so leaving the focused field gives it back', (tester) async {
    final focus = await _focused(tester);
    final fields = [_field((min: 3, ideal: 6, max: 6), focus: focus), _field((min: 3, ideal: 3, max: 3))];
    final focusedIdeal = _value(6) - _value(3);
    final short = _resolve(fields, _atMins(fields, slack: focusedIdeal + 20));
    expect(short.squeezed, isTrue, reason: 'the callsign gave up 20 of its ideal to the focused field');

    final roomy = _resolve(fields, _atMins(fields, slack: focusedIdeal + 40));
    expect(roomy.squeezed, isFalse, reason: 'everything besides the focused field has its ideal');
  });

  test('short of the mins, gaps and padding shrink together and gradually', () {
    final fields = [_field((min: 3, ideal: 4, max: 6)), _field((min: 3, ideal: 4, max: 6))];
    final r = _resolve(fields, _atMins(fields) - 20);
    expect(r.layout.gapScale, lessThan(1));
    expect(r.layout.gapScale, greaterThan(0));
    expect(r.layout.fieldPadding, r.layout.gapScale * 8, reason: 'one fraction of both');
    expect(_values(r), [_value(3), _value(3)], reason: 'the characters themselves are never given up');
    expect(r.squeezed, isTrue);
  });

  test('with the gaps and padding gone, the fields go under their mins together, before the callsign', () {
    final fields = [_field((min: 3, ideal: 4, max: 6)), _field((min: 4, ideal: 6, max: 6))];
    // Zero gaps and padding, the callsign at its min, and 15 short of the
    // fields' mins: they have 10 and 20 above the two-character floor, so
    // they give 5 and 10 of it.
    final maxWidth = _button + _value(_call.min) + _value(3) + _value(4) - 15;
    final r = _resolve(fields, maxWidth);
    expect(r.layout.gapScale, 0);
    expect(_values(r)[0], moreOrLessEquals(_value(3) - 5));
    expect(_values(r)[1], moreOrLessEquals(_value(4) - 10));
    expect(_callValue(fields, r, maxWidth), moreOrLessEquals(_value(_call.min)), reason: 'the callsign\'s min is the last thing given');
    expect(r.squeezed, isTrue);
  });

  testWidgets('a focused field keeps its ideal while the others go under their mins', (tester) async {
    final focus = await _focused(tester);
    final fields = [_field((min: 3, ideal: 6, max: 6), focus: focus), _field((min: 4, ideal: 6, max: 6))];
    final maxWidth = _button + _value(_call.min) + _value(6) + _value(4) - 15;
    final r = _resolve(fields, maxWidth);
    expect(_values(r), [moreOrLessEquals(_value(6)), moreOrLessEquals(_value(4) - 15)]);
  });

  test('with nothing left to give, the callsign gives its own min', () {
    final fields = [_field((min: 3, ideal: 4, max: 6)), _field((min: 3, ideal: 4, max: 6))];
    final r = _resolve(fields, _button + 2 * _value(fieldFloorChars));
    expect(r.layout.gapScale, 0);
    expect(r.layout.fieldPadding, 0);
    expect(r.layout.widths, [_value(fieldFloorChars), _value(fieldFloorChars)], reason: 'no field goes under the floor');
    expect(r.squeezed, isTrue);
  });

  // The label half of the same squeeze: a field narrower than "QP Location"
  // shows "QP Loc" rather than an ellipsized "QP Loca…", which names the field
  // no better than nothing does.
  testWidgets('a squeezed field falls back to its short label, and only then', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );

    String pick(double width, {String? shortLabel}) =>
        mainFieldLabel(context, label: 'QP Location', shortLabel: shortLabel, width: width, horizontalPadding: 8);

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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (ctx) => TextField(decoration: mainFieldDecoration(ctx, 'QP Location', horizontalPadding: padding)),
                ),
              ),
            ),
          ),
        ),
      );
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
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHaLoTheme(Brightness.light),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: Builder(
                      builder: (context) {
                        final label = mainFieldLabel(context, label: 'QP Location', shortLabel: 'QP Loc', width: width, horizontalPadding: padding);
                        return TextField(decoration: mainFieldDecoration(context, label, horizontalPadding: padding));
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          final shown = find.byWidgetPredicate((w) => w is Text && (w.data == 'QP Location'));
          if (shown.evaluate().isEmpty) continue;
          final paragraph = tester.renderObject<RenderParagraph>(shown);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'at width $width, padding $padding the full label was chosen and then cut off');
        }
      }
    });
  });
}
