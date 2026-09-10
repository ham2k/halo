// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The main logging row's sizing rules on their own — the concessions
// docs/design/logging-fields.md lists, in the order it lists them. The
// widget suite sees them through rendered widths; these pin the arithmetic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_metrics.dart';

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
}
