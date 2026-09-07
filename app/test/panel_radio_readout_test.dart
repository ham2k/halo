// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio panel's two moving parts that a rendered pane cannot show you
// went wrong: the readout's column layout, and whether a re-registered
// descriptor carrying a CHANGED radio list still reads as the same panel.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/radio/radio_faces.dart';

import 'support/fake_panel_extensions.dart';

void main() {
  group('frequency cells', () {
    // A rig's display keeps the decimal point in one column. If a suppressed
    // leading zero were DROPPED rather than blanked, the readout would slide
    // sideways the moment the operator crossed 10 MHz — legible in a
    // screenshot, invisible in a test that only checks the digits.
    test('the decimal point sits in the same column at 3.5 and 145 MHz', () {
      final low = lcdCellsForFrequency(3573.0);
      final high = lcdCellsForFrequency(145500.0);
      expect(low.indexOf(LcdCell.dot), equals(high.indexOf(LcdCell.dot)));
      expect(low.length, equals(high.length));
    });

    test('a leading zero is a blank cell, not a missing one', () {
      final cells = lcdCellsForFrequency(7025.0);
      // "  7,025.000" — two blanks, then the digits.
      expect(cells.take(2), everyElement(equals(LcdCell.blank)));
      expect(cells.contains(LcdCell.comma), isTrue);
    });

    // The comma is drawn per grouping position, so a rule that ignored what
    // precedes it would put one after a blank column — a separator floating
    // with no digits to separate.
    test('no comma is drawn after a blank column', () {
      final cells = lcdCellsForFrequency(3573.0);
      for (var i = 1; i < cells.length; i++) {
        if (cells[i] == LcdCell.comma) expect(cells[i - 1], isNot(equals(LcdCell.blank)));
      }
    });

    test('Hz precision is kept, not rounded away', () {
      final cells = lcdCellsForFrequency(14074.123);
      expect(cells.sublist(cells.indexOf(LcdCell.dot) + 1), equals([1, 2, 3]));
    });

    // The painter solves its cell size from the TOTAL slot count, so a
    // readout one column narrower draws BIGGER digits with the decimal point
    // moved. That makes width equality the real contract, not a tidiness
    // check: get it wrong and the whole display re-pitches the instant the
    // first reading replaces the blank placeholder, and again whenever an
    // LF/MF operator crosses 1 MHz into the first frequency with a comma.
    test('the blank placeholder is the same width as a reading', () {
      final blank = lcdCellsForFrequency(null);
      expect(blank.length, equals(lcdCellsForFrequency(14074.0).length));
      expect(blank.indexOf(LcdCell.dot), equals(lcdCellsForFrequency(14074.0).indexOf(LcdCell.dot)));
    });

    test('a sub-MHz reading is the same width as an HF one', () {
      // 630 m — below the first grouping mark, so the column it would occupy
      // has to be reserved rather than skipped.
      final lf = lcdCellsForFrequency(472.0);
      final hf = lcdCellsForFrequency(14074.0);
      expect(lf.length, equals(hf.length));
      expect(lf.indexOf(LcdCell.dot), equals(hf.indexOf(LcdCell.dot)));
    });

    // The reserve is what keeps the pitch fixed, and 70 cm is the top of
    // what it covers. A band ABOVE it must still render correctly rather
    // than losing its leading digit — it just takes the column it needs.
    test('the reserve holds from 630 m through 70 cm', () {
      final widths =
          [472.0, 1800.0, 14074.0, 50313.0, 145500.0, 435000.0].map(lcdCellsForFrequency).map((c) => c.length);
      expect(widths.toSet(), hasLength(1));
    });

    test('23 cm keeps every digit, at the cost of one extra column', () {
      final cells = lcdCellsForFrequency(1296000.0);
      expect(cells.whereType<int>().take(7), equals([1, 2, 9, 6, 0, 0, 0]));
      expect(cells.length, greaterThan(lcdCellsForFrequency(435000.0).length));
    });
  });

  group('a descriptor whose options changed is not the same descriptor', () {
    PanelDefinition withRadios(List<String> names) => PanelDefinition(
          id: 'radio',
          title: 'Radio',
          source: PanelSource.native,
          formFields: [
            {
              'type': 'field',
              'key': 'radio',
              'fieldType': 'select',
              'options': [for (final name in names) {'label': name, 'value': name}],
            },
          ],
        );

    // The trap this exists to catch: comparing only `formFields.length` reads
    // a rebuilt picker as identical, so `registerNative` no-ops and the
    // operator chooses from a list frozen at whenever the view first mounted.
    // Both descriptors below have exactly one field either way.
    test('renaming a radio changes the descriptor', () {
      expect(withRadios(['Left Radio']) == withRadios(['Right Radio']), isFalse);
    });

    test('adding a radio changes the descriptor', () {
      expect(withRadios(['Left Radio']) == withRadios(['Left Radio', 'Right Radio']), isFalse);
    });

    test('an unchanged list is still equal, so a live rig costs no churn', () {
      expect(withRadios(['Left Radio']) == withRadios(['Left Radio']), isTrue);
    });

    test('re-registering an unchanged descriptor notifies nobody', () {
      var notifications = 0;
      final service = PanelService(FakePanelExtensions());
      service.addListener(() => notifications++);
      service.registerNative(withRadios(['Left Radio']));
      expect(notifications, equals(1));
      service.registerNative(withRadios(['Left Radio']));
      expect(notifications, equals(1), reason: 'a status change must not rebuild the catalog');
      service.registerNative(withRadios(['Left Radio', 'Right Radio']));
      expect(notifications, equals(2), reason: 'a new radio must reach the picker');
    });
  });

  group('power', () {
    // 0 W is a MEANINGFUL reading — a dead transmitter — so rounding a QRPp
    // rig's 0.5 W down to it does not merely lose precision, it invents the
    // one answer an operator must be able to trust.
    test('a QRPp reading is never rounded to zero', () {
      expect(powerText(0.5), equals('0.5'));
      expect(lcdCellsForPower(0.5), equals([0, LcdCell.dot, 5]));
    });

    test('a whole reading carries no decimals, however the driver typed it', () {
      // One spelling for the segments, the Modern face and the screen reader
      // — a driver reporting the double 100.0 and one reporting the int 100
      // must not produce two different numbers on the same pane.
      expect(powerText(100.0), equals('100'));
      expect(powerText(100), equals('100'));
      expect(lcdCellsForPower(100.0), equals([1, 0, 0]));
    });
  });
}
