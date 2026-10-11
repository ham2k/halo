// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots panel's current-row reveal, driven against a list made of
// numbers: which call gets scrolled to, when, how far, and the one measured
// correction after the scroll lands. spots_panel_reveal_test.dart covers the
// same machine through a real panel; this one reaches the latches a widget
// test can only infer.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

/// Rows are [_row] tall and headers [_header], so a row's top is a sum the
/// tests can do by hand.
const _row = 50.0;
const _header = 30.0;

Map<String, dynamic> _spot(String call) => {
  'their': {'call': call},
  'freq': 14250.0,
  'band': '20m',
  'mode': 'SSB',
};

/// [count] spots, `C0` to `C{count-1}`.
List<Map<String, dynamic>> _spots(int count, {String prefix = 'C'}) => [for (var i = 0; i < count; i++) _spot('$prefix$i')];

class _List implements SpotListView {
  @override
  bool onScreen = true;

  bool attached = true;

  @override
  bool get canScroll => attached && onScreen;

  double pixels = 0;
  double viewport = 300;
  double maxExtent = 5000;
  bool laidOut = true;

  @override
  ({double pixels, double viewport, double minExtent, double maxExtent})? get geometry =>
      laidOut ? (pixels: pixels, viewport: viewport, minExtent: 0, maxExtent: maxExtent) : null;

  @override
  double sectionHeaderHeight = _header;

  /// Every scroll asked for, and the one still running.
  final scrolls = <double>[];
  Completer<void>? running;

  @override
  Future<void> animateTo(double target) {
    scrolls.add(target);
    running = Completer<void>();
    return running!.future;
  }

  /// Lands the running scroll where it was aimed.
  Future<void> land() async {
    pixels = scrolls.last;
    running!.complete();
    await pumpEventQueue();
  }

  /// The current row as the viewport paints it; null for one never mounted.
  ({double top, double height})? paintedRow;
  double? paintedCalibration;

  @override
  ({double top, double height})? measureCurrentRow() => paintedRow;

  @override
  double? measureCalibrationRow() => paintedCalibration;

  final frames = <VoidCallback>[];

  @override
  void afterFrame(VoidCallback callback) => frames.add(callback);

  /// Runs what was scheduled for after this frame.
  void endFrame() {
    final due = [...frames];
    frames.clear();
    for (final callback in due) {
      callback();
    }
  }

  int rebuilds = 0;

  @override
  void rebuild() => rebuilds++;
}

void main() {
  late _List list;
  late SpotRevealState reveal;

  setUp(() {
    list = _List();
    reveal = SpotRevealState(list);
  });

  /// One build of the list: [sections] placed, [call] armed.
  void build(List<List<Map<String, dynamic>>> sections, String? call) {
    reveal.locate(sections, call, declaredHeightOf: (_) => _row);
    reveal.arm(call);
  }

  group('which call is revealed', () {
    test('a call whose row is below the viewport is scrolled just into view', () {
      build([_spots(20)], 'C10');
      expect(list.scrolls, isEmpty, reason: 'not until the frame has laid the list out');
      list.endFrame();

      // C10's top is a header plus ten rows; its bottom must clear the
      // viewport's, and no more.
      expect(list.scrolls, [_header + 11 * _row - 300]);
    });

    test('a row already in view does not move the list', () {
      build([_spots(20)], 'C2');
      list.endFrame();
      expect(list.scrolls, isEmpty);
    });

    // Every rebuild arms again; without the latch, a list the operator
    // scrolled away would be yanked back on each one.
    test('a call is revealed once, however many builds follow', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.endFrame();
      list.pixels = 0;

      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });

    test('a call typed while the pane is hidden is revealed when it comes back', () {
      list.onScreen = false;
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, isEmpty);

      list.onScreen = true;
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });

    // Flipping to another pane in the dock group and back must not yank the
    // list away from wherever the operator scrolled it: builds behind
    // another pane leave the latch alone.
    test('a call already revealed stays revealed across calls typed while hidden', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.endFrame();
      list.pixels = 0;

      list.onScreen = false;
      build([_spots(20)], 'C12');
      list.endFrame();
      build([_spots(20)], 'C10');
      list.endFrame();
      list.onScreen = true;
      build([_spots(20)], 'C10');
      list.endFrame();

      expect(list.scrolls, hasLength(1));
    });

    // A call typed against a board that has no spot for it is not a reveal,
    // and must not cost the last one its latch.
    test('a call with no row leaves the last revealed call revealed', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.endFrame();
      list.pixels = 0;

      build([_spots(20)], 'K1ABC');
      list.endFrame();
      build([_spots(20)], 'C10');
      list.endFrame();

      expect(list.scrolls, hasLength(1));
    });

    test('a call with no spot yet is revealed when its spot arrives', () {
      build([_spots(5)], 'K1ABC');
      list.endFrame();
      expect(list.scrolls, isEmpty);

      build([
        [..._spots(10), _spot('K1ABC')],
      ], 'K1ABC');
      list.endFrame();
      expect(list.scrolls, [_header + 11 * _row - 300]);
    });

    // The one give-up a later frame cannot recover from: if the latch stays
    // set, that call is never revealed again this session.
    test('a reveal that could not scroll leaves the call to the next build', () {
      build([_spots(20)], 'C10');
      list.attached = false;
      list.endFrame();
      expect(list.scrolls, isEmpty);

      list.attached = true;
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });

    // A list attached but not yet laid out has no geometry to aim with; a
    // reveal that took that for "already in view" would retire the call.
    test('a reveal against a list not yet laid out leaves the call to the next build', () {
      build([_spots(20)], 'C10');
      list.laidOut = false;
      list.endFrame();
      expect(list.scrolls, isEmpty);

      list.laidOut = true;
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });

    test('a reveal superseded before its frame scrolls nothing and keeps the newer latch', () {
      build([_spots(20)], 'C10');
      build([_spots(20)], 'C15');
      list.endFrame();

      expect(list.scrolls, [_header + 16 * _row - 300], reason: "only C15's");
    });

    test('forget lets the same call be revealed again', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.endFrame();
      list.pixels = 0;

      reveal.forget();
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(2));
    });
  });

  group('a peek', () {
    // The operator is dragging that very row; scrolling would pull it out
    // from under the finger.
    test('the call a slide put in the fields does not scroll the list', () {
      reveal.peekedCall = 'C10';
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, isEmpty);
    });

    test('and is not revealed late once the row closes with it still in the fields', () {
      reveal.peekedCall = 'C10';
      build([_spots(20)], 'C10');
      list.endFrame();

      reveal.peekedCall = null;
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, isEmpty);
    });

    test('any other call still reveals while a row is open', () {
      reveal.peekedCall = 'C3';
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });
  });

  group('the measured correction', () {
    // The sum is exact for the row shapes it knows; a note emoji that arrived
    // after it was taken is not one of them.
    test('a row that landed short of where the sum put it is nudged once', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      // Measured once the scroll lands — a row in flight reads a position it
      // is about to leave.
      list.paintedRow = (top: 280, height: 50);
      await list.land();
      expect(list.scrolls, [280, 280 + 280 + 50 - 300]);

      list.paintedRow = (top: 290, height: 50);
      await list.land();
      list.endFrame();
      expect(list.scrolls, hasLength(2), reason: 'one correction per reveal, not a loop against a drift it cannot close');
    });

    test('a row already in view is still measured', () {
      build([_spots(20)], 'C2');
      list.endFrame();
      list.paintedRow = (top: 400, height: 50);

      list.endFrame();
      expect(list.scrolls, [400 + 50 - 300]);
    });

    test('a row the viewport never mounted is left to the estimate', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.paintedRow = null;
      list.endFrame();
      expect(list.scrolls, hasLength(1));
    });

    test('a row painted beyond the viewport and its cache is a stale transform, not a row to nudge', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      list.paintedRow = (top: 5000, height: 50);
      await list.land();
      expect(list.scrolls, hasLength(1));
    });

    test('a correction for a call the list has since given to another measures nothing', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      reveal.locate([_spots(20)], 'C12', declaredHeightOf: (_) => _row);
      list.paintedRow = (top: 280, height: 50);
      await list.land();
      expect(list.scrolls, hasLength(1));
    });
  });

  group('row heights', () {
    test('the first row calibrates the scale, and every height and header follows it', () {
      build([_spots(20)], null);
      list.paintedCalibration = 60;
      reveal.calibrate();

      expect(reveal.rowHeightScale, 1.2);
      expect(list.rebuilds, 1);
      expect(reveal.sectionHeaderExtent, _header * 1.2);

      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, [(_header + 11 * _row) * 1.2 - 300]);
    });

    test('a reading within half a percent changes nothing, so a rebuild does not re-trigger one', () {
      build([_spots(20)], null);
      list.paintedCalibration = 50.2;
      reveal.calibrate();
      expect(reveal.rowHeightScale, 1.0);
      expect(list.rebuilds, 0);
    });

    // A scale that moves after a reveal was armed means that reveal's offsets
    // were wrong when they were summed.
    test('a new scale lets a call already revealed be revealed again', () async {
      build([_spots(20)], 'C10');
      list.endFrame();
      await list.land();
      list.endFrame();

      list.paintedCalibration = 60;
      reveal.calibrate();
      build([_spots(20)], 'C10');
      list.endFrame();
      expect(list.scrolls, hasLength(2));
    });

    test('the current row is never the calibration row', () {
      build([_spots(20)], 'C0');
      list.paintedCalibration = 60;
      reveal.calibrate();
      expect(reveal.rowHeightScale, 1.0);
    });
  });

  group('a call on the board twice', () {
    // "Calls of Note" pins a copy above its band section's.
    List<List<Map<String, dynamic>>> twice() => [
      [_spot('K1ABC')],
      [..._spots(15), _spot('K1ABC')],
    ];

    test('the reveal goes to the copy that moves the list least', () {
      list.pixels = 650;
      build(twice(), 'K1ABC');
      list.endFrame();

      // The band section's copy — two headers, the pinned row and 15 more
      // above it — is already in view at 650..950; the pinned one is not.
      expect(list.scrolls, isEmpty);
      expect(reveal.isCurrentRow(1, 15), isTrue);
    });

    test('the copy it chose holds while that call stays revealed', () async {
      build(twice(), 'K1ABC');
      list.endFrame();
      expect(reveal.isCurrentRow(0, 0), isTrue);

      // A build landing with the list scrolled down prices the other copy
      // cheaper; switching would send the correction to a row the reveal
      // never aimed at.
      list.pixels = 600;
      reveal.locate(twice(), 'K1ABC', declaredHeightOf: (_) => _row);
      expect(reveal.isCurrentRow(0, 0), isTrue);
    });
  });
}
