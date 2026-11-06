// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spectrum's gestures: a click or the wheel tunes, a drag on the axis or a
// pinch zooms, a drag over the panadapter or waterfall pans — the host's by
// default from extension API 17, the extension's when the scene says so.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_gestures.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';
import '../support/fake_clock.dart';

class _Radio extends ChangeNotifier implements SceneSpectrumSource {
  _Radio({this.nativeGestures = true, this.commands = true, this.recenters = false, this.maxWidth});

  @override
  final bool nativeGestures;
  final bool commands, recenters;
  final int? maxWidth;
  double vfo = 14050000;
  final tunes = <(double, bool)>[];
  final recentered = <int>[];
  final fitted = <int>[];
  final widths = <int?>[];
  final controller = StreamController<SpectrumFrame>.broadcast();

  /// The designated radio, which the operator can switch.
  String designated = 'radio-1';

  @override
  String? resolve(String? radio) => designated;
  @override
  Stream<SpectrumFrame> frames(String uuid) => controller.stream;
  @override
  String? problem(String uuid) => null;
  @override
  double? vfoHz(String uuid) => vfo;
  @override
  Listenable get changes => this;
  @override
  String get noRadio => 'no radio';
  @override
  String get waiting => 'waiting';
  @override
  Map<String, num> readings(String uuid) => const {};
  @override
  Map<String, String> readingStrings(String uuid) => const {};
  @override
  List<Object?> dialState() => const [];
  @override
  Listenable get readingChanges => this;
  @override
  void showWidth(String uuid, Object owner, int? widthHz) => widths.add(widthHz);
  @override
  bool recenter(String uuid, int centerHz) {
    if (recenters) recentered.add(centerHz);
    return recenters;
  }

  @override
  int? maxWidthHz(String uuid) => maxWidth;
  @override
  bool canTune(String uuid) => commands;

  /// Answers every tune with no, as a radio that is transmitting does.
  bool refusing = false;

  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) {
    if (commands) tunes.add((hz, dial));
    if (commands && refusing) scheduleMicrotask(() => refused?.call());
    return commands;
  }

  @override
  bool fitSpan(String uuid, int widthHz) {
    if (commands) fitted.add(widthHz);
    return commands;
  }
}

/// 14.000–14.100 MHz in a thousand bins: fine enough to zoom well in.
SpectrumFrame _sweep({int lowHz = 14000000}) =>
    SpectrumFrame(lowHz: lowHz, highHz: lowHz + 100000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, atMillis: 0);

/// [document], where given, lays the spectrum control out in a scene of its own making.
Future<List<Map<String, dynamic>>> _show(
  WidgetTester tester,
  _Radio radio, {
  Map<String, dynamic> spectrum = const {},
  Map<String, dynamic> Function(Map<String, dynamic> control)? document,
}) async {
  final events = <Map<String, dynamic>>[];
  // No level strip unless a test asks: these measure across the whole box.
  final control = {'id': 'pan', 'kind': 'spectrum', 'label': 'Panadapter', 'event': 'tune', 'levelScale': false, ...spectrum};
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DockPaneVisibility(
              visible: true,
              child: PanelSceneView(
                scene: PanelScene(
                  document?.call(control) ??
                      {
                        'version': 1,
                        'width': 400,
                        'height': 300,
                        'values': const <String, num>{},
                        'layers': const <Object>[],
                        'controls': [control],
                        'layout': {
                          'column': [
                            {'control': 'pan', 'flex': 1},
                          ],
                          'crossAxisAlignment': 'stretch',
                        },
                      },
                ),
                onEvent: (e) async {
                  events.add(e);
                  return {};
                },
                spectrum: radio,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  radio.controller.add(_sweep());
  await tester.pump();
  return events;
}

Rect _box(WidgetTester tester) => tester.getRect(find.byType(SceneSpectrumView));

/// Where the panadapter draws the tuned frequency's line.
double? _drawnVfo(WidgetTester tester) =>
    (tester.widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter')).single.painter
                as dynamic)
            .marks
            .vfoHz()
        as double?;

/// How many digits past the kHz the dial's label shows now.
double _labelDigits(WidgetTester tester) =>
    (tester.widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_AnnotationPainter')).single.painter
                as dynamic)
            .vfoDigits()
        as double;

/// The frequency the dial's label shows now.
double? _labelHz(WidgetTester tester) =>
    (tester.widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_AnnotationPainter')).single.painter
                as dynamic)
            .vfoLabelHz()
        as double?;

/// The middle of the window the panadapter draws.
double _shownMiddle(WidgetTester tester) {
  final frame =
      (tester.widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter')).single.painter
                  as dynamic)
              .frame()
          as SpectrumFrame;
  return (frame.lowHz + frame.highHz) / 2;
}

double _panHeight(WidgetTester tester) =>
    tester.getSize(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter')).height;

/// Across the box at [fraction], on the panadapter.
Offset _onPan(WidgetTester tester, double fraction) => Offset(_box(tester).left + _box(tester).width * fraction, _box(tester).top + 40);

/// On the default axis: the gap under a panadapter that takes 0.4 of what it leaves.
Offset _onAxis(WidgetTester tester, double fraction) {
  final box = _box(tester);
  return Offset(box.left + box.width * fraction, box.top + (box.height - 20) * .4 + 10);
}

Future<void> _tap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 300));
}

/// A drag left on the axis from the middle: zooms in by e, to 36.8 kHz, carrying 14.050 MHz to an
/// eighth of the way across, which puts the window's middle at [_zoomed].
Future<void> _zoomIn(WidgetTester tester) async {
  await tester.dragFrom(_onAxis(tester, .5), const Offset(-150, 0));
  await tester.pump();
}

const _zoomed = 14050000 + .375 * 36788;

bool _drawsAxis(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(CustomPaint)))
    .any((paint) => paint.painter.runtimeType.toString() == '_ScalePainter');

void main() {
  setUp(followFakeClock);

  test('the tuning step follows the zoom, in rungs of 1, 2 and 5 above what a pixel tells apart', () {
    expect(spectrumTuneStep(250), 500);
    expect(spectrumTuneStep(92), 100);
    expect(spectrumTuneStep(5), 5);
    expect(spectrumTuneStep(250, pixels: 10), 5000);
    expect(spectrumTuneStep(.01), 1);
    // 1, 2, 5, 10: a doubling would put 400 and 40 Hz steps on a dial nobody tunes by.
    expect(
      [
        for (final shift in [-1, 1, 2, 3]) spectrumTuneStep(150, shift: shift),
      ],
      [100, 500, 1000, 2000],
    );
    expect(spectrumTuneStep(1, shift: -3), 1, reason: 'never under a hertz');
  });

  test('gestures name tune, zoom, pan, split and levels, each native, event or off, and what scrolling each way does', () {
    expect(SceneSpectrumGestures.parse({'tune': 'event'}).tune, SceneSpectrumGesture.event);
    expect(SceneSpectrumGestures.parse({'split': 'off'}).split, SceneSpectrumGesture.off);
    expect(() => SceneSpectrumGestures.parse({'tune': 'host'}), throwsFormatException);
    // Up and down tune and sideways pans unless the scene says otherwise, each way on its own.
    final none = SceneSpectrumGestures.parse(null);
    expect((none.vertical, none.horizontal), (SceneSpectrumScroll.tune, SceneSpectrumScroll.pan));
    final swapped = SceneSpectrumGestures.parse({
      'scroll': {'horizontal': 'tune'},
    });
    expect((swapped.vertical, swapped.horizontal), (SceneSpectrumScroll.tune, SceneSpectrumScroll.tune));
    expect(() => SceneSpectrumGestures.parse({'scroll': 'off'}), throwsFormatException);
    expect(
      () => SceneSpectrumGestures.parse({
        'scroll': {'vertical': 'zoom'},
      }),
      throwsFormatException,
    );
    expect(
      () => SceneSpectrumGestures.parse({
        'scroll': {'wheel': 'tune'},
      }),
      throwsFormatException,
    );
  });

  testWidgets('a click on an API 17 panel tunes the radio itself, and the extension hears nothing of it', (tester) async {
    final radio = _Radio();
    final events = await _show(tester, radio);
    // 25.35 kHz into the sweep, far from the dial: two rungs above the 500 Hz a pixel of 100 kHz
    // across 400 covers, where one pixel's step lands on digits nobody tunes by. A jump's coarser
    // step stops at 1 kHz, which this already is.
    await _tap(tester, _onPan(tester, .2535));
    expect(radio.tunes, [(14025000.0, false)]);
    expect(events, isEmpty, reason: 'the host tuned: the extension tuning too would tune twice');
  });

  testWidgets('soon after a tune, a click is on a finer step the nearer the dial; any other on the coarse; drawn at once', (tester) async {
    final radio = _Radio();
    // 10 kHz across 400 pixels: 25 Hz a pixel, fine 100 Hz, medium 200, coarse 500.
    await _show(tester, radio, spectrum: const {'span': 10000});
    double at(double hz) => (hz - 14045000) / 10000;
    // Near the dial, but nothing tuned yet: a jump, coarse, where fine would land on 14.0507.
    await _tap(tester, _onPan(tester, at(14050660)));
    expect(radio.tunes.last.$1, 14050500);
    expect(_drawnVfo(tester), 14050500, reason: 'the line moves with the click, not with the report');
    // 430 Hz from there, right after: fine, where medium and coarse land on 14.051.
    await _tap(tester, _onPan(tester, at(14050930)));
    expect(radio.tunes.last.$1, 14050900);
    // 1.76 kHz: medium, where fine lands on 14.0527 and coarse on 14.0525.
    await _tap(tester, _onPan(tester, at(14052660)));
    expect(radio.tunes.last.$1, 14052600);
    // 3.97 kHz: a jump, coarse, where fine and medium land on 14.0486.
    await _tap(tester, _onPan(tester, at(14048630)));
    expect(radio.tunes.last.$1, 14048500);
    // Close by, but five seconds on: a jump again, where fine would land on 14.0488.
    await tester.pump(const Duration(seconds: 6));
    await _tap(tester, _onPan(tester, at(14048830)));
    expect(radio.tunes.last.$1, 14049000);

    // 60 kHz across 400: 150 Hz a pixel, fine 500; two rungs coarser is 2 kHz, held to 1.
    final wide = _Radio();
    await _show(tester, wide, spectrum: const {'span': 60000});
    await _tap(tester, _onPan(tester, (14071300 - 14020000) / 60000));
    expect(wide.tunes.last.$1, 14071000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('clicks near an edge glide the window, once they rest, just far enough to bring the last one in; one inside stays put', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio);
    await tester.tapAt(_onPan(tester, .5 + .3 * .2535));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_shownMiddle(tester), 14050000, reason: 'away from the edges the window is left alone');
    // In the top 15%, twice in quick succession: each click tunes at once, but the window waits for
    // the clicks to rest and glides once, from the last — a glide started on each would jerk the
    // picture back and forth.
    await tester.tapAt(_onPan(tester, .95));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(_onPan(tester, .97));
    await tester.pump(const Duration(milliseconds: 16));
    expect(radio.tunes.last.$1, 14097000);
    expect(radio.recentered, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    expect(radio.recentered, isEmpty);
    // At rest it ends 15% in from the edge, not in the middle, which would move the picture further
    // than the click needs. The scope goes at once, the drawing over a moment.
    await tester.pump(const Duration(milliseconds: 50));
    expect(radio.recentered, [14097000 - 35000]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_shownMiddle(tester), allOf(greaterThan(14050000), lessThan(14062000)), reason: 'a jump loses the signal clicked');
    await tester.pump(const Duration(milliseconds: 150));
    expect(_shownMiddle(tester), 14062000);
    expect(_drawnVfo(tester), 14097000);

    // A scope the panel cannot move, shown whole: nowhere to glide.
    final fixed = _Radio();
    await _show(tester, fixed);
    await tester.tapAt(_onPan(tester, .95));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_shownMiddle(tester), 14050000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('in a scene that scrolls up and down, a trackpad swipe that way is the scroll\'s, not a tune', (tester) async {
    final radio = _Radio();
    // Twice as tall as the pane, the spectrum at its top, scrolling with it.
    await _show(
      tester,
      radio,
      document: (control) => {
        'version': 1,
        'width': 400,
        'height': 600,
        'values': {'pos': 0},
        'scroll': {'axis': 'y', 'value': 'pos'},
        'layers': const <Object>[],
        'controls': [
          {...control, 'x': 0, 'y': 0, 'width': 400, 'height': 300},
        ],
      },
    );
    final pad = TestPointer(3, PointerDeviceKind.trackpad);
    final at = _onPan(tester, .5);
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var y = -10.0; y >= -60; y -= 10) {
      await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: Offset(0, y)));
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 600));
    // The scroll view takes the same swipe: both taking it would retune the radio as the scene scrolls.
    expect(radio.tunes, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a tune the radio refuses puts the dial back at once, not after the hold runs out', (tester) async {
    final radio = _Radio()..refusing = true;
    await _show(tester, radio);
    await tester.tapAt(_onPan(tester, .6));
    await tester.pump();
    expect(radio.tunes, hasLength(1));
    // Transmitting, say: drawn at 14.060 for a second and a half, the dial would claim a frequency the radio never took.
    expect(_drawnVfo(tester), 14050000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('where a tune can go nowhere, nothing is drawn as though it went', (tester) async {
    // No leave to command the radio, and no event to hear the click instead.
    final radio = _Radio(commands: false);
    final events = await _show(tester, radio, spectrum: const {'event': null});
    await tester.tapAt(_onPan(tester, .6));
    await tester.pump(const Duration(milliseconds: 300));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(_onPan(tester, .5)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_drawnVfo(tester), 14050000, reason: 'a dial that moved and wandered back would say the radio was tuned');
    expect(events, isEmpty);
    // The line is no handle either: a drag on it is the picture's.
    await tester.dragFrom(_onPan(tester, .5), const Offset(40, 0));
    await tester.pump();
    expect(_drawnVfo(tester), 14050000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a pan just after a tune holds against follow, before the radio has reported the tune', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio, spectrum: const {'follow': .15});
    await tester.tapAt(_onPan(tester, .6));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.dragFrom(_onPan(tester, .3), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 50));
    final panned = radio.recentered.length;
    // Compared with the radio's stale report rather than the dial as drawn, the pan reads as a dial
    // that moved, and follow glides the window back over it.
    for (var i = 0; i < 6; i++) {
      radio.controller.add(_sweep(lowHz: 14100000));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(radio.recentered, hasLength(panned));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('switching radios leaves the last one\'s tuning behind', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(_onPan(tester, .5)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(radio.tunes.last.$1, 14051000);
    // An SO2R swap, a notch within the second that would carry the last radio's run on.
    radio
      ..designated = 'radio-2'
      ..vfo = 7074000
      ..notifyListeners();
    radio.controller.add(_sweep(lowHz: 7024000));
    await tester.pump();
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(radio.tunes.last.$1, 7075000, reason: 'from this radio\'s dial, not a notch on from the other\'s');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('without leave to command the radio, a click is the control\'s event, at the zoom\'s step', (tester) async {
    final radio = _Radio(commands: false);
    final events = await _show(tester, radio);
    await _tap(tester, _onPan(tester, .2535));
    expect(events.single['phase'], 'commit');
    expect(events.single['value'], 14025000);
    expect(events.single.containsKey('gesture'), isFalse, reason: 'a tune keeps the shape it had before API 17');
  });

  testWidgets('a bundle from before API 17 hears its click where it landed, and gets no axis it did not draw', (tester) async {
    final radio = _Radio(nativeGestures: false);
    final events = await _show(tester, radio);
    expect(_drawsAxis(tester), isFalse);
    await _tap(tester, _onPan(tester, .2535));
    expect(radio.tunes, isEmpty, reason: 'the extension tunes on its event; the host tuning too would tune twice');
    expect(events.single['value'] as double, closeTo(14025350, 1));
  });

  testWidgets('an API 17 scene that names no scale gets the host\'s axis, and one that says false none', (tester) async {
    await _show(tester, _Radio());
    expect(_drawsAxis(tester), isTrue);
    await _show(tester, _Radio(), spectrum: const {'scale': false});
    expect(_drawsAxis(tester), isFalse);
  });

  testWidgets('a drag on the axis away from its middle zooms in, and clicks land in the narrower window', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    await _zoomIn(tester);
    await _tap(tester, _onPan(tester, .9));
    // 0.4 of 36.8 kHz above the middle, where before the zoom it was 0.4 of 100 kHz.
    // Far from the dial, the click is on a jump's 1 kHz step: within half of it.
    expect(radio.tunes.single.$1, closeTo(_zoomed + .4 * 36788, 500));
    expect(radio.widths.last, closeTo(36788, 2), reason: 'the scope is told the width shown, so an app-sized one narrows to it');
  });

  testWidgets('a drag over the waterfall pans within the sweep without moving the radio', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio);
    await _zoomIn(tester);
    final box = _box(tester);
    // The finger left by 100 of 400 pixels: the window right by a quarter of its 36.8 kHz.
    await tester.dragFrom(Offset(box.center.dx, box.bottom - 40), const Offset(-100, 0));
    await tester.pump();
    await _tap(tester, _onPan(tester, .5));
    expect(radio.tunes.single.$1, closeTo(_zoomed + 36788 / 4, 100));
    expect(radio.recentered, isEmpty, reason: 'a window inside the sweep is only a crop');
  });

  testWidgets('a pan past the sweep moves the scope where the radio lets it, and stops at the edge where not', (tester) async {
    final moves = _Radio(recenters: true);
    await _show(tester, moves);
    await _zoomIn(tester);
    await tester.dragFrom(_onPan(tester, .9), const Offset(-1000, 0));
    await tester.pump();
    expect(moves.recentered.last, closeTo(_zoomed + 1000 * 36788 / 400, 500));

    final stays = _Radio();
    await _show(tester, stays);
    await _zoomIn(tester);
    await tester.dragFrom(_onPan(tester, .9), const Offset(-1000, 0));
    await tester.pump();
    await _tap(tester, _onPan(tester, .5));
    // Half the window short of the sweep's top.
    expect(stays.tunes.single.$1, closeTo(14100000 - 36788 / 2, 500));
  });

  testWidgets(
    'on the axis, away from the middle zooms in and toward it zooms out, whichever side the drag begins on, the pressed frequency under the pointer',
    (tester) async {
      // A direction fixed to the screen (one way always narrows) fails one of these two rightward drags.
      final rightHalf = _Radio();
      await _show(tester, rightHalf);
      await tester.dragFrom(_onAxis(tester, .6), const Offset(150, 0));
      await tester.pump();
      expect(rightHalf.widths.last, closeTo(36788, 2));
      // 14.060 MHz, pressed at 0.6, is carried along to where the pointer let go; held where it was
      // pressed, a click there would land 13.8 kHz higher.
      await _tap(tester, _onPan(tester, .975));
      expect(rightHalf.tunes.single.$1, closeTo(14060000, 100));

      final fromLeft = _Radio(maxWidth: 400000);
      await _show(tester, fromLeft);
      await tester.dragFrom(_onAxis(tester, .4), const Offset(150, 0));
      await tester.pump();
      expect(fromLeft.widths.last, closeTo(271828, 2));
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('zooming out past the sweep widens the scope as far as it goes, the radio\'s own only on command', (tester) async {
    final radio = _Radio(maxWidth: 400000);
    await _show(tester, radio);
    await tester.dragFrom(_onAxis(tester, .5), const Offset(300, 0));
    await tester.pump();
    expect(radio.widths.last, 400000);
    expect(radio.fitted.last, 400000);

    final narrow = _Radio(commands: false);
    await _show(tester, narrow);
    await tester.dragFrom(_onAxis(tester, .5), const Offset(300, 0));
    await tester.pump();
    expect(narrow.widths.last, 100000, reason: 'a scope the panel cannot widen bounds the zoom at the sweep');
    expect(narrow.fitted, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a zoom in narrows the radio\'s own scope once it ends, to cover the window where it sits', (tester) async {
    // Cropped and never narrowed, a zoom in on a radio's widest span draws a handful of its points.
    final radio = _Radio(maxWidth: 400000);
    await _show(tester, radio);
    final drag = await tester.startGesture(_onAxis(tester, .5));
    for (var i = 0; i < 5; i++) {
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump();
    }
    expect(radio.fitted, isEmpty, reason: 'narrowed on the way in, the radio would step through every span');
    await drag.up();
    await tester.pump();
    // The window's middle sits .375 of its width off the sweep's, which the dial centres.
    expect(radio.fitted.single, closeTo(36788 * 1.75, 50));
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(_onAxis(tester, .9));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_onAxis(tester, .9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(radio.fitted.last, 100000, reason: 'left narrow, the reset would only crop the narrowed sweep');

    final narrow = _Radio(commands: false);
    await _show(tester, narrow);
    await _zoomIn(tester);
    expect(narrow.fitted, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag across the axis moves it: toward the waterfall the panadapter grows, and nothing zooms', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final widths = [...radio.widths];
    // 280 pixels shared, the panadapter's 0.4 of them; 56 more make it 0.6.
    expect(_panHeight(tester), closeTo(112, .5));
    // In steps, each after the rebuild the last one caused: measured from anywhere but where the
    // drag took hold, the axis would jump to the pointer.
    final drag = await tester.startGesture(_onAxis(tester, .5));
    for (var i = 0; i < 4; i++) {
      await drag.moveBy(const Offset(0, 14));
      await tester.pump();
    }
    await drag.up();
    await tester.pump();
    expect(_panHeight(tester), closeTo(168, .5));
    expect(radio.widths, widths, reason: 'a drag across the axis is not a zoom');
    // Held between a tenth and nine tenths, so neither part can be dragged away.
    await tester.dragFrom(_onAxis(tester, .5) + const Offset(0, 56), const Offset(0, 1000));
    await tester.pump();
    expect(_panHeight(tester), closeTo(252, .5));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a scene that hears its split gets the share as change and commit, and keeps its own', (tester) async {
    final radio = _Radio();
    final events = await _show(
      tester,
      radio,
      spectrum: {
        'gestures': {'split': 'event'},
      },
    );
    await tester.dragFrom(_onAxis(tester, .5), const Offset(0, 56));
    await tester.pump();
    final splits = events.where((e) => e['gesture'] == 'split').toList();
    expect(splits.last['phase'], 'commit');
    expect(splits.last['value'] as double, closeTo(.6, .001));
    expect(_panHeight(tester), closeTo(112, .5), reason: 'the scene moves its own axis, by its next render');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a scene that hears its zoom gets the width as change and commit, and keeps its own window', (tester) async {
    final radio = _Radio();
    final events = await _show(
      tester,
      radio,
      spectrum: const {
        'gestures': {'zoom': 'event'},
      },
    );
    await _zoomIn(tester);
    final zooms = events.where((e) => e['gesture'] == 'zoom').toList();
    expect(zooms.last['phase'], 'commit');
    expect(zooms.last['value'] as double, closeTo(36788, 2));
    await _tap(tester, _onPan(tester, .9));
    expect(radio.tunes.single.$1, 14090000, reason: 'the extension decides the width; until it does, the window is the scene\'s');
  });

  testWidgets('the wheel steps finer the slower it turns, each notch from the last', (tester) async {
    final radio = _Radio();
    // 10 kHz across 400 pixels: fine 100 Hz, medium 200, coarse 500.
    await _show(tester, radio, spectrum: const {'span': 10000});
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(_onPan(tester, .5)));
    final drawn = <double?>[];
    Future<void> notch(Duration after) async {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      drawn.add(_drawnVfo(tester));
      await tester.pump(after);
    }

    // A notch at a time: fine, from the dial and then from the notch before.
    await notch(const Duration(milliseconds: 300));
    await notch(const Duration(milliseconds: 70));
    // Turned briskly: medium, onto its grid, where fine would make 14.0503 and 14.0505.
    await notch(const Duration(milliseconds: 70));
    await notch(Duration.zero);
    // Spun: coarse, where medium would make 14.0508.
    await notch(const Duration(milliseconds: 300));
    expect(drawn, [14050100, 14050200, 14050400, 14050600, 14051000]);
    // Paced to the radio, the newest kept, so it is left where the line is.
    expect(radio.tunes.last, (14051000.0, true));
    // The radio never got there: once the dial it was sent to is let go, the next notch is from its own.
    await tester.pump(const Duration(seconds: 2));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(radio.tunes.last, (14049900.0, true));
  });

  testWidgets('the dial is labelled at the top of its line with no annotations of its own; not when the scene says no, nor before API 17', (tester) async {
    Color? label() =>
        (tester
                        .widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_AnnotationPainter'))
                        .firstOrNull
                        ?.painter
                    as dynamic)
                ?.vfoLabel
            as Color?;
    // Built only for annotations, the layer that draws the label would leave every plain scope unlabelled.
    await _show(tester, _Radio());
    expect(label(), isNotNull);
    await _show(tester, _Radio(), spectrum: const {'vfoLabel': false});
    expect(label(), isNull);
    await _show(tester, _Radio(nativeGestures: false));
    expect(label(), isNull);
  });

  test('level labels sit far enough apart to read: dB on the panadapter, seconds down the waterfall', () {
    // 112 pixels for 80 dB: 1.4 a dB, so every 20.
    expect(spectrumLevelStep(112 / 80), 20);
    expect(spectrumLevelStep(4), 5);
    // Two rows a second, a pixel each: every 15 seconds; ten times faster, every 2.
    expect(spectrumAgeStep(2), 15);
    expect(spectrumAgeStep(20), 2);
  });

  testWidgets('the level strip sits at the end from API 17, at the start or nowhere as the scene says, upright or sideways', (tester) async {
    Rect? strip() {
      final found = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_LevelPainter');
      return found.evaluate().isEmpty ? null : tester.getRect(found);
    }

    await _show(tester, _Radio(), spectrum: const {'levelScale': null});
    expect(strip()?.right, _box(tester).right);
    expect(strip()?.width, 40);
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'levelScale': {'side': 'start', 'width': 50},
      },
    );
    expect(strip()?.left, _box(tester).left);
    expect(strip()?.width, 50);
    await _show(tester, _Radio(), spectrum: const {'levelScale': false});
    expect(strip(), isNull);
    await _show(tester, _Radio(nativeGestures: false), spectrum: const {'levelScale': null});
    expect(strip(), isNull, reason: 'a bundle before API 17 gets no strip it did not draw');
    // Sideways it lies along the bottom, as deep as a label is tall, or along the top at its start.
    await _show(tester, _Radio(), spectrum: const {'levelScale': null, 'flow': 'right'});
    final box = _box(tester);
    expect(strip(), Rect.fromLTWH(box.left, box.bottom - 24, box.width, 24));
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'levelScale': {'side': 'start'},
        'flow': 'left',
      },
    );
    expect(strip(), Rect.fromLTWH(box.left, box.top, box.width, 24));
    // Beside the picture, it takes its depth from the frequency's way across the screen.
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'levelScale': {'over': false},
        'flow': 'right',
      },
    );
    expect(tester.getSize(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter')).height, box.height - 24);
    expect(strip(), Rect.fromLTWH(box.left, box.bottom - 24, box.width, 24));
    await _show(tester, _Radio(), spectrum: const {'levelScale': false, 'flow': 'right'});
    expect(strip(), isNull);
  });

  testWidgets('sideways, the strip is dragged along the flow: the floor by the spectrum\'s base, the speed along the waterfall', (tester) async {
    Rect painted(String painter) => tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == painter));
    final radio = _Radio();
    Map<String, double> told(List<Map<String, dynamic>> events) => {
      for (final e in events.where((e) => e['gesture'] != null)) e['gesture'] as String: (e['value'] as num).toDouble(),
    };
    // Flowing right, the spectrum is on the left and its base at its right edge: a drag right lowers the trace.
    var events = await _show(tester, radio, spectrum: const {'levelScale': true, 'waterfallSpeed': 2, 'flow': 'right'});
    var pan = painted('_PanPainter'), y = _box(tester).bottom - 12;
    await tester.dragFrom(Offset(pan.right - 20, y), const Offset(30, 0));
    await tester.pump();
    expect(told(events)['floor'], closeTo(30 * 80 / pan.width, .01));
    // Its labels lie in the strip, upright and side by side along it.
    final canvas = TestRecordingCanvas();
    final strip = painted('_LevelPainter');
    tester
        .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_LevelPainter'))
        .painter!
        .paint(canvas, strip.size);
    final labels = [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawParagraph) call.invocation.positionalArguments[1] as Offset,
    ];
    expect(labels.length, greaterThan(3));
    expect(labels.map((at) => at.dy), everyElement(inInclusiveRange(0, 24)));
    expect(labels.map((at) => at.dx).toSet().length, labels.length);
    await tester.pump(const Duration(seconds: 2));

    // Flowing left, mirrored: the spectrum on the right with its base at its left edge, the waterfall's
    // age growing leftward from its right edge. Shown afresh, with the scene's own floor.
    // 75 dB tall, its labels every 10 from the floor: ticked at the base, not at the far edge.
    await tester.pumpWidget(const SizedBox());
    events = await _show(tester, radio, spectrum: const {'levelScale': true, 'waterfallSpeed': 2, 'flow': 'left', 'range': 75});
    pan = painted('_PanPainter');
    final ticks = TestRecordingCanvas();
    tester
        .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_LevelPainter'))
        .painter!
        .paint(ticks, strip.size);
    final across = [
      for (final call in ticks.invocations)
        if (call.invocation.memberName == #drawLine)
          if ((call.invocation.positionalArguments[0] as Offset, call.invocation.positionalArguments[1] as Offset) case (final a, final b) when a.dx == b.dx)
            a.dx,
    ];
    expect(across, contains(closeTo(pan.left - strip.left, .01)));
    expect(across, isNot(contains(closeTo(pan.right - strip.left, .01))));
    await tester.dragFrom(Offset(pan.left + 20, y), const Offset(-30, 0));
    await tester.pump();
    expect(told(events)['floor'], closeTo(30 * 75 / pan.width, .01));
    final fall = painted('_WaterfallPainter');
    events.clear();
    await tester.dragFrom(Offset(fall.right - 40, y), const Offset(-40, 0));
    await tester.pump();
    expect(told(events)['speed'], closeTo(4, .01), reason: 'the age taken hold of twice as far along: twice the rows a second');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a scene says what scrolling each way does, upright or sideways, a trackpad\'s swipe as the wheel', (tester) async {
    final radio = _Radio();
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    Future<void> scroll(Offset by) async {
      await tester.sendEventToBinding(mouse.hover(_box(tester).center));
      await tester.sendEventToBinding(mouse.scroll(by));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Upright, swapped: up and down pan — down toward lower frequencies, as the wheel tunes — and sideways tunes.
    await _show(
      tester,
      radio,
      spectrum: const {
        'span': 50000,
        'gestures': {
          'scroll': {'vertical': 'pan', 'horizontal': 'tune'},
        },
      },
    );
    await scroll(const Offset(0, 100));
    expect(_shownMiddle(tester), closeTo(14050000 - 100 * 50000 / 400, 1));
    expect(radio.tunes, isEmpty);
    await scroll(const Offset(100, 0));
    expect(radio.tunes.single.$1, greaterThan(14050000), reason: 'rightward, along the frequency, is up');
    await tester.pump(const Duration(seconds: 2));

    // Sideways, by default: up and down along the frequency tune the way the pointer moves on screen —
    // up, toward the lower frequencies of a spectrum flowing left, whose frequency runs down the screen.
    radio.tunes.clear();
    await _show(tester, radio, spectrum: const {'span': 50000, 'flow': 'left'});
    await scroll(const Offset(0, -100));
    expect(radio.tunes.single.$1, lessThan(14050000));
    await tester.pump(const Duration(seconds: 2));

    // Told to, up and down pan along it instead, and sideways does nothing.
    radio.tunes.clear();
    await _show(
      tester,
      radio,
      spectrum: const {
        'span': 50000,
        'flow': 'left',
        'gestures': {
          'scroll': {'vertical': 'pan', 'horizontal': 'off'},
        },
      },
    );
    final middle = _shownMiddle(tester);
    await scroll(const Offset(0, -60));
    expect(_shownMiddle(tester), lessThan(middle));
    final panned = _shownMiddle(tester);
    await scroll(const Offset(60, 0));
    expect(_shownMiddle(tester), panned);
    expect(radio.tunes, isEmpty);
    // A trackpad's swipe is the scroll the other way: fingers down move the window as a scroll up does.
    final pad = TestPointer(3, PointerDeviceKind.trackpad);
    final at = _box(tester).center;
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var y = 10.0; y <= 40; y += 10) {
      await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: Offset(0, y)));
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 400));
    expect(_shownMiddle(tester), lessThan(panned));
    expect(radio.tunes, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('on the level strip, the panadapter\'s bottom third moves its floor and the rest its range; the waterfall its speed', (tester) async {
    final radio = _Radio();
    // 300 high, a 20 pixel axis: the panadapter 112 at the top, the waterfall 168 below; 0–80 dB.
    final events = await _show(tester, radio, spectrum: const {'levelScale': true, 'waterfallSpeed': 2});
    final box = _box(tester), x = box.right - 20;
    Map<String, double> told() => {for (final e in events.where((e) => e['gesture'] != null)) e['gesture'] as String: (e['value'] as num).toDouble()};

    // The trace follows the pointer: 30 pixels down at 80 dB on 112 is 21.4 dB more floor.
    await tester.dragFrom(Offset(x, box.top + 100), const Offset(0, 30));
    await tester.pump();
    expect(told()['floor'], closeTo(30 * 80 / 112, .01));

    // Above the middle, 20 pixels up is away from it: the range narrows by e^(20/150), and the
    // level taken hold of — 51.4 dB above that floor — stays under the pointer.
    final floor = told()['floor']!;
    events.clear();
    await tester.dragFrom(Offset(x, box.top + 40), const Offset(0, -20));
    await tester.pump();
    final range = 80 / math.exp(20 / 150);
    expect(told()['range'], closeTo(range, .01));
    expect(told()['floor'], closeTo(floor + 72 / 112 * 80 - 92 / 112 * range, .01));

    // The age taken hold of 40 pixels down the waterfall, dragged to 80: twice the rows a second.
    events.clear();
    await tester.dragFrom(Offset(x, box.top + 132 + 40), const Offset(0, 40));
    await tester.pump();
    expect(told()['speed'], closeTo(4, .01));

    // A double click hands them all back: 0 each, for a scene keeping them in its own numbers.
    events.clear();
    await tester.tapAt(Offset(x, box.top + 60));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(Offset(x, box.top + 60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(told(), {'floor': 0, 'range': 0, 'speed': 0});
    expect(radio.tunes, isEmpty, reason: 'the strip lies over the picture, but its clicks are its own');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('each axis lies over the picture or takes room beside it, as the scene says', (tester) async {
    double panWidth() => tester.getSize(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter')).width;
    // The level strip lies over the picture unless told otherwise; beside it, it takes its width.
    await _show(tester, _Radio(), spectrum: const {'levelScale': true});
    expect(panWidth(), 400);
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'levelScale': {'over': false},
      },
    );
    expect(panWidth(), 360);
    // The frequency axis takes a gap unless told otherwise; over, the parts share all 300.
    await _show(tester, _Radio());
    expect(_panHeight(tester), closeTo(112, .5));
    // Over, the parts share all 300, and the axis lies across the waterfall's head unless told the spectrum's foot.
    double axisTop() => tester.getRect(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(DecoratedBox)).first).top - _box(tester).top;
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'scale': {'over': true, 'ticks': true},
      },
    );
    expect(_panHeight(tester), closeTo(120, .5));
    expect(axisTop(), closeTo(120, .5));
    await _show(
      tester,
      _Radio(),
      spectrum: const {
        'scale': {'over': 'spectrum', 'ticks': true},
      },
    );
    expect(axisTop(), closeTo(100, .5));
  });

  testWidgets('the waterfall\'s time scale holds still as sweeps come unevenly, with a speed set or not', (tester) async {
    double? scale() =>
        (tester
                        .widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_WaterfallPainter'))
                        .single
                        .painter
                    as dynamic)
                .rowsPerSecond()
            as double?;
    Future<List<double?>> sweeps(_Radio radio) async {
      final seen = <double?>[];
      for (final gap in const [100, 120, 90, 115, 95]) {
        radio.controller.add(_sweep());
        await tester.pump(Duration(milliseconds: gap));
        seen.add(scale());
      }
      return seen;
    }

    // Every row lies at its age on this scale: one that followed each sweep's timing would shake
    // the whole history up and down.
    final free = _Radio();
    await _show(tester, free);
    expect((await sweeps(free)).skip(1).toSet(), hasLength(1));
    // A speed set past the sweeps' rate is the scale, not the rate the sweeps happen to come at.
    final set = _Radio();
    await _show(tester, set, spectrum: const {'waterfallSpeed': 20});
    expect((await sweeps(set)).toSet(), {20});
  });

  testWidgets('frequency labels stay clear of a level strip lying over the picture', (tester) async {
    List<double> labelsAt() {
      final paint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_ScalePainter'));
      final canvas = TestRecordingCanvas();
      paint.painter!.paint(canvas, tester.getSize(find.byWidget(paint)));
      return [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawParagraph) (call.invocation.positionalArguments[1] as Offset).dx,
      ];
    }

    final radio = _Radio();
    // 10 kHz across 400, a label every kHz: the last ones run under a strip 40 wide on the right.
    await _show(tester, radio, spectrum: const {'span': 10000, 'levelScale': false});
    radio.controller.add(_sweep());
    await tester.pump();
    final beside = labelsAt();
    // The test font's glyphs are 14 pixels wide: a label starting at 275 runs past 360, into the strip.
    expect(beside.any((x) => x > 270), isTrue, reason: 'the test needs a label where the strip would lie: $beside');
    await _show(tester, radio, spectrum: const {'span': 10000, 'levelScale': true});
    radio.controller.add(_sweep());
    await tester.pump();
    final clear = labelsAt();
    expect(clear, isNotEmpty);
    expect(clear.every((x) => x < 270), isTrue, reason: 'labels at $clear');
    await tester.pump(const Duration(seconds: 2));
  });

  test('a waterfall row lies at its age, down to the row before it, so a change of speed re-spaces the history', () {
    // 20 pixels a second: a row taken a second after the newest-but-one lies 20 down, as deep as the gap.
    expect(waterfallRowSpan(10000, 9000, 8500, 20, 1), (20.0, 30.0));
    // Twice as fast, the same rows twice as far: what was taken a second ago is where a second now reads.
    expect(waterfallRowSpan(10000, 9000, 8500, 40, 1), (40.0, 60.0));
    // The oldest has no row before it: a row deep.
    expect(waterfallRowSpan(10000, 9000, null, 20, 1.5), (20.0, 21.5));
  });

  testWidgets('a click on the axis tunes once no second click follows; a double click resets the zoom and tunes nothing', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    await _zoomIn(tester);
    // Tuning at once, the first click of a reset would also move the dial.
    await tester.tapAt(_onAxis(tester, .9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(radio.tunes, isEmpty, reason: 'a second click may yet make it a reset');
    await tester.pump(const Duration(milliseconds: 300));
    expect(radio.tunes, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(_onAxis(tester, .9));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_onAxis(tester, .9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(radio.tunes, hasLength(1), reason: 'a double click is the reset, not a tune');
    expect(radio.widths.last, 0, reason: 'the zoom handed back: the scene names no width, so it draws the whole sweep');
    // On the picture a click is not held back: there is no double click to wait for.
    await tester.tapAt(_onPan(tester, .3));
    await tester.pump(const Duration(milliseconds: 16));
    expect(radio.tunes, hasLength(2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a double tap on the axis puts the scene\'s window back, about the dial', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    await _zoomIn(tester);
    await tester.tapAt(_onAxis(tester, .3));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_onAxis(tester, .3));
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, _onPan(tester, .9));
    expect(radio.tunes.last.$1, 14090000);
  });

  testWidgets('where a native zoom, pan or split leaves things is told to the scene once, when it ends, to keep', (tester) async {
    final radio = _Radio();
    final events = await _show(tester, radio);
    List<String> told() => [
      for (final e in events.where((e) => e['gesture'] != null))
        '${e['gesture']} ${e['phase']} ${(e['value'] as num).toStringAsFixed(e['gesture'] == 'split' ? 2 : 0)}',
    ];
    final drag = await tester.startGesture(_onAxis(tester, .5));
    for (var i = 0; i < 5; i++) {
      await drag.moveBy(const Offset(-30, 0));
      await tester.pump();
    }
    expect(told(), isEmpty, reason: 'a scene saving its preferences wants where the zoom ended, not every step of it');
    await drag.up();
    await tester.pump();
    expect(told(), ['zoom commit 36788']);

    events.clear();
    await tester.dragFrom(Offset(_box(tester).center.dx, _box(tester).bottom - 40), const Offset(-100, 0));
    await tester.pump();
    // A quarter of the window right of where the zoom left its middle.
    expect(told(), ['pan commit 14072992']);

    // A double click hands the width back: 0, for a scene keeping the operator's in its span to drop it.
    events.clear();
    await tester.tapAt(_onAxis(tester, .3));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_onAxis(tester, .3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(told(), ['zoom commit 0']);

    events.clear();
    await tester.dragFrom(_onAxis(tester, .5), const Offset(0, 56));
    await tester.pump();
    expect(told(), ['split commit 0.60']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a bundle before API 17 is told nothing of a native zoom: its commits are its clicks', (tester) async {
    final radio = _Radio(nativeGestures: false);
    final events = await _show(tester, radio, spectrum: const {'scale': true});
    await _zoomIn(tester);
    expect(events, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag on the tuned frequency\'s line, or a finger\'s width from it, moves the dial, landing on the fine step', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    // The dial at 14.050 MHz, the middle of 400 pixels; 8 off the line still takes hold of it.
    final drag = await tester.startGesture(_onPan(tester, .5) + const Offset(8, 0));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(7, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await drag.up();
    await tester.pump(const Duration(milliseconds: 300));
    // 42 pixels of 250 Hz is 10.5 kHz, landing on the 1 kHz fine step the label showed.
    expect(radio.tunes.last.$1, 14061000);
    expect(radio.tunes.length, lessThan(6), reason: 'paced like the wheel, not a tune for every move');
    expect(radio.recentered, isEmpty, reason: 'the line is not the picture: nothing pans');

    // Further off, the drag is the picture's: it pans and tunes nothing.
    final panned = _Radio(recenters: true);
    await _show(tester, panned);
    await tester.dragFrom(_onPan(tester, .5) + const Offset(30, 0), const Offset(-300, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(panned.tunes, isEmpty);
    expect(panned.recentered, isNotEmpty);
  });

  test('a dragged line\'s pan lands on the step the wheel would be on, spun as fast', () {
    double land(double hzPerMs) => spectrumLandingStep(hzPerMs, fine: 50, medium: 100, coarse: 200);
    // 50 Hz notches 125 ms apart, slow enough for the fine step; 100 Hz ones 50 ms apart; faster, coarse.
    expect(land(.4), 50);
    expect(land(2), 100);
    expect(land(3), 200);
  });

  testWidgets('a line panned at an edge is tuned exactly under the pointer, then lands on a step for its speed when let go', (tester) async {
    final radio = _Radio(recenters: true);
    // 10 kHz across 400 pixels, 25 Hz a pixel: fine, medium and coarse steps of 100, 200 and 500 Hz.
    await _show(tester, radio, spectrum: const {'span': 10000});
    Future<double> panAndLetGo(double share) async {
      // On the line, wherever the last pan left it.
      final drag = await tester.startGesture(_onPan(tester, (_drawnVfo(tester)! - _shownMiddle(tester) + 5000) / 10000));
      await drag.moveTo(_onPan(tester, share));
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // On no step while it moves: the line exactly where the pointer is, as the picture slides under it.
      final under = _shownMiddle(tester) - 5000 + share * 10000;
      expect(_drawnVfo(tester), closeTo(under, 1));
      final moving = _drawnVfo(tester)!;
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(radio.tunes.last.$1, _drawnVfo(tester));
      return moving;
    }

    // Near the edge, as fast as a quick spin: the coarse step.
    final fast = await panAndLetGo(.99);
    expect(_drawnVfo(tester), (fast / 500).round() * 500);
    // Barely in, slower than a slow turn: the fine.
    final slow = await panAndLetGo(.855);
    expect(_drawnVfo(tester), (slow / 100).round() * 100);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a line dragged near an edge pans the window under it, faster the nearer the edge, the dial staying under the pointer', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio, spectrum: const {'follow': .15});
    final drag = await tester.startGesture(_onPan(tester, .5));
    Future<void> hold(double share, int ms) async {
      await drag.moveTo(_onPan(tester, share));
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // The frequency under the pointer at [share]: the line on it, give or take its half-pixel step.
    void underPointer(double share) => expect(_drawnVfo(tester), closeTo(_shownMiddle(tester) - 50000 + share * 100000, 500));

    await hold(.8, 300);
    expect(_shownMiddle(tester), 14050000, reason: 'inside the outer 15%, the line moves and the picture does not');
    underPointer(.8);
    // Two thirds of the way into the outer 15%, then almost at the edge: the window pans the faster,
    // and the dial goes with it, never trailing the pointer as a window chasing it would make it.
    await hold(.95, 496);
    final slower = _shownMiddle(tester) - 14050000;
    underPointer(.95);
    final at = _shownMiddle(tester);
    await hold(.99, 496);
    final faster = _shownMiddle(tester) - at;
    underPointer(.99);
    expect(slower, greaterThan(12000));
    expect(faster, greaterThan(slower * 1.25));
    // Back inside, the picture stands.
    await hold(.6, 16);
    final stood = _shownMiddle(tester);
    await hold(.6, 300);
    expect(_shownMiddle(tester), stood);
    underPointer(.6);
    await drag.up();
    await tester.pump();
    expect(radio.recentered.last, stood, reason: 'the scope goes where the drag left the window');
    expect(radio.tunes.last.$1, _drawnVfo(tester));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the dial\'s label keeps its digits while the dial moves, drops them once it stands, and slides each in or out', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    expect(_labelDigits(tester), 0, reason: '14.050: as many digits as it has');
    Future<void> turn(double hz) async {
      radio.vfo = hz;
      radio.notifyListeners();
      await tester.pump();
    }

    await turn(14050500);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_labelDigits(tester), allOf(greaterThan(0), lessThan(1)), reason: 'a digit slides in, not popped');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_labelDigits(tester), 1);
    // On to 14.051 and on: it reads 14.0510, not a digit shorter and back on each step.
    await turn(14051000);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_labelDigits(tester), 1);
    await turn(14051500);
    await turn(14052000);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_labelDigits(tester), 1, reason: 'still moving a quarter second ago');
    // It stands at 14.052: the zero goes, sliding out from the frame after.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_labelDigits(tester), 1);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_labelDigits(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_labelDigits(tester), 0);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a scene that fixes the label\'s Hz digits shows that many whatever the dial is on', (tester) async {
    final radio = _Radio();
    await _show(
      tester,
      radio,
      spectrum: const {
        'vfoLabel': {'hzDigits': 2},
      },
    );
    expect(_labelDigits(tester), 2, reason: '14.050 reads 14.05000');
    radio.vfo = 14050500;
    radio.notifyListeners();
    await tester.pump(const Duration(milliseconds: 75));
    expect(_labelDigits(tester), 2, reason: 'fixed, nothing slides');
    await tester.pump(const Duration(seconds: 2));
    expect(_labelDigits(tester), 2);
  });

  test('the text cache tells apart a label built from different part styles', () {
    // Keyed on its text and root style alone, a scene restyling only the Hz would keep drawing the old.
    final cache = SpectrumTextCache();
    const style = TextStyle(fontSize: 14);
    TextSpan span(double hz) => TextSpan(
      text: 'x',
      style: TextStyle(fontSize: hz),
    );
    final a = cache.get('x', style, spanKey: 1, span: () => span(10));
    final b = cache.get('x', style, spanKey: 2, span: () => span(20));
    expect(identical(a, b), isFalse);
    expect(identical(cache.get('x', style, spanKey: 1, span: () => span(10)), a), isTrue);
    cache.dispose();
  });

  test('a full text cache lets one painter go at a time, never one a paint has just been handed', () {
    // The dial's label is two lookups a frame, the digits either side of the one sliding in or out:
    // a cache emptied whole when full disposed the first while the paint still held it.
    final cache = SpectrumTextCache();
    const style = TextStyle(fontSize: 14);
    for (var i = 0; i < SpectrumTextCache.limit - 1; i++) {
      cache.get('$i', style);
    }
    final held = cache.get('14.074', style);
    cache.get('14.0745', style);
    expect(held.width, greaterThan(0));
    // And one in use stays: the oldest goes, not the last asked for.
    final reused = cache.get('0', style);
    for (var i = 0; i < 5; i++) {
      cache.get('new $i', style);
    }
    expect(identical(cache.get('0', style), reused), isTrue);
    cache.dispose();
  });

  testWidgets('a dragged line is drawn where the pointer puts it, not where the radio last said, until the radio answers', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final drag = await tester.startGesture(_onPan(tester, .5));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(7, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The radio has said nothing new: a line waiting on its report trails the finger by the pacing and the round trip.
    // On no step: the line moves smoothly with the pointer, its label on the fine step.
    expect(radio.vfo, 14050000);
    expect(_drawnVfo(tester), 14060500);
    expect(_labelHz(tester), 14061000);
    await drag.moveBy(const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_drawnVfo(tester), 14060750, reason: 'a pixel of 250 Hz, not a step of 500 or 1000');
    await drag.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_drawnVfo(tester), 14061000, reason: 'let go on the fine step the label showed, and left there while the radio catches up');
    // A radio that never gets there wins in the end.
    await tester.pump(const Duration(seconds: 2));
    expect(_drawnVfo(tester), 14050000);
  });

  testWidgets('follow glides the window to a dial that jumps, once it stands, and is there at once for a band change', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio, spectrum: const {'follow': .15});
    // A memory recalled on the radio, 14.095, past the 85% margin: a jump. Not followed at once, so a
    // run of jumps glides once, from the last.
    radio.vfo = 14095000;
    radio.notifyListeners();
    radio.controller.add(_sweep());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(radio.recentered, isEmpty);
    // A fifth of a second on, the window moves to put it on the margin, quickly: a tenth of the width
    // in 150 ms.
    await tester.pump(const Duration(milliseconds: 60));
    expect(radio.recentered.last, 14095000 - 35000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_shownMiddle(tester), allOf(greaterThan(14050000), lessThan(14060000)), reason: 'a jump loses the place the eye was on');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_shownMiddle(tester), 14060000);

    // Two and a half widths up the band: still a glide, the longest, so the eye sees which way it went.
    radio.vfo = 14320000;
    radio.notifyListeners();
    await tester.pump(const Duration(milliseconds: 210));
    expect(radio.recentered.last, 14320000 - 35000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_shownMiddle(tester), allOf(greaterThan(14060000), lessThan(14285000)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_shownMiddle(tester), 14285000);

    // A band change, more than three widths away: there at once. A glide would sweep the picture
    // across every frequency between, none of which the operator tuned.
    radio.vfo = 21074000;
    radio.notifyListeners();
    await tester.pump();
    expect(radio.recentered.last, 21074000 - 35000);
    expect(_shownMiddle(tester), 21039000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('follow chases a spinning dial, trailing it by more the faster it spins, and settles on the margin', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio, spectrum: const {'follow': .15});
    radio.controller.add(_sweep());
    await tester.pump();
    // Whatever turns it — the radio's knob here — a dial moving in steps of a small share of the
    // window is spun, not jumped: waiting for it to stand would leave it running off the edge.
    Future<double> spin(int stepHz, int steps) async {
      for (var i = 0; i < steps; i++) {
        radio.vfo += stepHz;
        radio.notifyListeners();
        // Sweeps keep coming from where the scope was, so the picture is live, not waiting.
        radio.controller.add(_sweep());
        for (var f = 0; f < 3; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      // How far past the middle the dial is: 35 kHz on the margin, more as the window trails it.
      return radio.vfo - _shownMiddle(tester);
    }

    // 14.050 to 14.085, the margin, without a move; then on, 20 kHz a second.
    await spin(1000, 35);
    expect(_shownMiddle(tester), 14050000);
    final slow = await spin(1000, 20);
    expect(_shownMiddle(tester), greaterThan(14065000), reason: 'the window keeps up with the dial');
    expect(slow, greaterThan(35000), reason: 'a window held to the dial on every step jerks along with it');
    // Four times as fast: the window trails it further, still keeping it in.
    final fast = await spin(4000, 10);
    expect(fast, greaterThan(slow + 3000));
    expect(fast, lessThan(50000));
    // Once it stands, the window settles with the dial on the margin, the scope sent there last.
    for (var f = 0; f < 60; f++) {
      if (f % 4 == 0) radio.controller.add(_sweep());
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_shownMiddle(tester), radio.vfo - 35000);
    expect(radio.recentered.last, radio.vfo - 35000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('after a pan, follow leaves the window where the operator put it until the dial moves', (tester) async {
    final radio = _Radio(recenters: true);
    await _show(tester, radio, spectrum: const {'follow': .15});
    // Clear of the dial's line, which a drag would take hold of instead.
    await tester.dragFrom(_onPan(tester, .6), const Offset(-200, 0));
    await tester.pump(const Duration(seconds: 1));
    final panned = radio.recentered.length;
    expect(panned, greaterThan(0));
    // The scope has moved half its width up: the dial sits on its low edge, inside follow's margin.
    radio.controller.add(_sweep(lowHz: 14050000));
    await tester.pump(const Duration(seconds: 1));
    radio.controller.add(_sweep(lowHz: 14050000));
    await tester.pump();
    expect(radio.recentered.length, panned, reason: 'follow pulling the window straight back would undo every pan');
    radio.vfo = 14051000;
    radio.notifyListeners();
    for (var f = 0; f < 60; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(radio.recentered.last, 14051000 + 35000);
  });

  testWidgets('two fingers pinch the window, the frequency between them staying there', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final a = await tester.startGesture(_onPan(tester, .375), pointer: 1);
    final b = await tester.startGesture(_onPan(tester, .625), pointer: 2);
    for (var i = 1; i <= 5; i++) {
      await a.moveTo(_onPan(tester, .375 - .025 * i));
      await b.moveTo(_onPan(tester, .625 + .025 * i));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();
    await _tap(tester, _onPan(tester, .9));
    // Spread from a quarter of the box to half of it: 50 kHz about 14.050 MHz.
    expect(radio.tunes.last.$1, closeTo(14070000, 200));
  });

  testWidgets('a trackpad pinch zooms; its swipe along the frequency pans', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final pad = TestPointer(3, PointerDeviceKind.trackpad);
    final at = _onPan(tester, .5);
    await tester.sendEventToBinding(pad.panZoomStart(at));
    await tester.sendEventToBinding(pad.panZoomUpdate(at, scale: 2));
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump();
    await _tap(tester, _onPan(tester, .9));
    expect(radio.tunes.last.$1, closeTo(14070000, 200));
    await tester.sendEventToBinding(pad.panZoomStart(at));
    await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: const Offset(-80, 0)));
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump();
    await _tap(tester, _onPan(tester, .5));
    // Fingers left by a fifth of the box: the window right by a fifth of its 50 kHz.
    expect(radio.tunes.last.$1, closeTo(14060000, 200));
  });

  testWidgets('a trackpad swipe across the frequency turns the dial like the wheel, a notch for each wheel notch of travel', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    final pad = TestPointer(3, PointerDeviceKind.trackpad);
    final at = _onPan(tester, .5);
    // Fingers down 50 pixels, in steps: two notches up from the dial, at 250 Hz a pixel both on 1 kHz.
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var y = 10.0; y <= 50; y += 10) {
      await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: Offset(1, y)));
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 600));
    expect(radio.tunes.last.$1, 14052000);
    expect(radio.recentered, isEmpty, reason: 'across the frequency is not a pan');
    // Begun along the frequency, the swipe is a pan to its end: drifting across never tunes.
    final tunes = radio.tunes.length;
    await tester.sendEventToBinding(pad.panZoomStart(at));
    await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: const Offset(-20, 0)));
    await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: const Offset(-20, 80)));
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 600));
    expect(radio.tunes.length, tunes);
  });

  testWidgets('gestures a scene turns off do nothing, and a disabled spectrum takes none', (tester) async {
    final radio = _Radio();
    final events = await _show(
      tester,
      radio,
      spectrum: const {
        'gestures': {'tune': 'off', 'zoom': 'off'},
      },
    );
    await _zoomIn(tester);
    await _tap(tester, _onPan(tester, .9));
    expect(radio.tunes, isEmpty);
    expect(events, isEmpty);

    final disabled = _Radio();
    final heard = await _show(tester, disabled, spectrum: const {'disabled': true});
    await _tap(tester, _onPan(tester, .9));
    expect(disabled.tunes, isEmpty);
    expect(heard, isEmpty);
  });

  testWidgets('a level strip whose drags are off lets the picture under it take its clicks', (tester) async {
    final radio = _Radio();
    await _show(
      tester,
      radio,
      spectrum: const {
        'levelScale': true,
        'gestures': {'levels': 'off'},
      },
    );
    // Over the picture, the strip lies on top: taking hits it does nothing with, a click there tuned nothing.
    await _tap(tester, Offset(_box(tester).right - 20, _box(tester).top + 40));
    expect(radio.tunes, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a tune that goes out as the control\'s event moves no dial: the extension may tune or not', (tester) async {
    final radio = _Radio();
    final events = await _show(
      tester,
      radio,
      // Narrower than the sweep, so the window has somewhere to glide.
      spectrum: const {
        'gestures': {'tune': 'event'},
        'span': 50000,
      },
    );
    await _tap(tester, _onPan(tester, .6));
    expect(events.single['value'], 14055000);
    expect(radio.tunes, isEmpty);
    // Drawn at the click for a second and a half, the line would show a dial the radio never took.
    expect(_drawnVfo(tester), 14050000);
    // And a click near the edge glides nothing in after a tune that may never come.
    await _tap(tester, _onPan(tester, .95));
    await tester.pump(const Duration(seconds: 1));
    expect(_shownMiddle(tester), 14050000);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a spectrum turned while shown drags along its frequency and across its axis where each now lies', (tester) async {
    final radio = _Radio();
    await _show(tester, radio);
    // Turned, the drag along the frequency and the one across the axis swap recognizers, each kept
    // by its type: holding the old one's region, a sideways drag over the waterfall moves the split.
    final events = await _show(tester, radio, spectrum: const {'flow': 'right'});
    expect(find.byType(SceneSpectrumView), findsOneWidget);
    await tester.dragFrom(Offset(_box(tester).right - 40, _box(tester).center.dy), const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(events.where((e) => e['gesture'] == 'split'), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('along a scene\'s scroll, a sideways wheel and a trackpad swipe scroll the scene; a mouse wheel still tunes', (tester) async {
    Map<String, dynamic> scrolling(Map<String, dynamic> control, String axis) => {
      'version': 1,
      'width': axis == 'x' ? 800 : 400,
      'height': axis == 'y' ? 600 : 300,
      'values': {'pos': 0},
      'scroll': {'axis': axis, 'value': 'pos'},
      'layers': const <Object>[],
      'controls': [
        {...control, 'x': 0, 'y': 0, 'width': 400, 'height': 300},
      ],
    };
    final across = _Radio();
    await _show(tester, across, spectrum: const {'span': 50000}, document: (c) => scrolling(c, 'x'));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(_onPan(tester, .5)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(100, 0)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_shownMiddle(tester), 14050000, reason: 'the wheel would pan the spectrum and the scene stop scrolling');

    // A scene of its own, not the last one's state at its scroll.
    await tester.pumpWidget(const SizedBox());
    final down = _Radio();
    await _show(tester, down, document: (c) => scrolling(c, 'y'));
    // As a browser delivers a trackpad's swipe: a scroll, not a pan-zoom.
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.hover(_onPan(tester, .5)));
    await tester.sendEventToBinding(pad.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(down.tunes, isEmpty);
    await tester.sendEventToBinding(mouse.hover(_onPan(tester, .5)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(down.tunes, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a bundle before API 17 that draws a scale gets the plain one it was written against', (tester) async {
    List<double> ticks() {
      final painter = tester
          .widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_ScalePainter'))
          .single
          .painter!;
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, _box(tester).size);
      return [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawLine) (call.invocation.positionalArguments[2] as Paint).strokeWidth,
      ];
    }

    const scale = {
      'scale': {'ticks': true},
    };
    await _show(tester, _Radio(nativeGestures: false), spectrum: scale);
    final plain = ticks();
    expect(plain, isNotEmpty);
    expect(plain.toSet(), {1.0}, reason: 'one tick at each label, as it always drew');
    await _show(tester, _Radio(), spectrum: scale);
    final styled = ticks();
    expect(styled.toSet(), {1.0, 2.0});
    expect(styled.length, greaterThan(plain.length), reason: 'short ticks between the labels');
  });
}
