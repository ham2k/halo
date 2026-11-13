// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Archery: with Alt held, a drag of a spectrum's tuned frequency's line
// draws it like a bow's string; let go loaded, the line flies off as the
// arrow, the window chases it and is at rest to watch it land; short of it,
// the string twangs back.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

class _Radio extends ChangeNotifier implements SceneSpectrumSource {
  @override
  final bool nativeGestures = true;
  double vfo = 14050000;

  /// A scope in center mode: its sweeps are centred on wherever it is tuned.
  bool centred = false;
  final tunes = <double>[];
  final recentered = <int>[];
  final controller = StreamController<SpectrumFrame>.broadcast();

  @override
  String? resolve(String? radio) => 'radio-1';
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
  ({Map<String, num> numbers, Map<String, String> words}) equipment(String id, String kind) => (numbers: const {}, words: const {});

  @override
  Listenable get equipmentChanges => this;
  @override
  void showWidth(String uuid, Object owner, int? widthHz) {}
  @override
  bool canRecenter(String uuid) => true;
  @override
  bool recenter(String uuid, int centerHz) {
    recentered.add(centerHz);
    return true;
  }

  @override
  int? maxWidthHz(String uuid) => null;
  @override
  int? minWidthHz(String uuid) => null;
  @override
  bool canTune(String uuid) => true;
  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) {
    tunes.add(hz);
    if (centred) {
      controller.add(SpectrumFrame(lowHz: hz.round() - 50000, highHz: hz.round() + 50000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, atMillis: 0));
    }
    return true;
  }

  @override
  bool fitSpan(String uuid, int widthHz, {int? centerHz, int offCenterHz = 0}) => true;
}

/// 14.000–14.100 MHz across a spectrum 400 wide and 300 deep, the dial at
/// 14.050 MHz in the middle: 250 Hz a pixel. It follows the dial, as a band
/// scope does, which would glide the window its own way after a shot.
Future<Rect> _show(WidgetTester tester, _Radio radio, {Map<String, dynamic> spectrum = const {}}) async {
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
                scene: PanelScene({
                  'version': 1,
                  'width': 400,
                  'height': 300,
                  'values': const <String, num>{},
                  'layers': const <Object>[],
                  'controls': [
                    {'id': 'pan', 'kind': 'spectrum', 'label': 'Panadapter', 'event': 'tune', 'levelScale': false, 'follow': .15, ...spectrum},
                  ],
                  'layout': {
                    'column': [
                      {'control': 'pan', 'flex': 1},
                    ],
                    'crossAxisAlignment': 'stretch',
                  },
                }),
                onEvent: (e) async => {},
                spectrum: radio,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  radio.controller.add(SpectrumFrame(lowHz: 14000000, highHz: 14100000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, atMillis: 0));
  await tester.pump();
  return tester.getRect(find.byType(SceneSpectrumView));
}

dynamic _painter(WidgetTester tester, String type) =>
    (tester.widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == type)).single.painter as dynamic);

/// The tuned frequency's line as the panadapter draws it: null while a shot is in the air.
double? _line(WidgetTester tester) => _painter(tester, '_PanPainter').marks.vfoHz() as double?;

/// Whether the line is a bow's string, drawn over every part in its place.
bool _strung(WidgetTester tester) => _painter(tester, '_PanPainter').marks.strung() as bool;

/// The string's nock, pulled along the frequency, in pixels; null with the line straight.
double? _pull(WidgetTester tester) => _painter(tester, '_BowPainter').bow()?.pull as double?;

/// Where the string is drawn, and what it is doing.
double _bowHz(WidgetTester tester) => _painter(tester, '_BowPainter').bow().hz as double;
String _bowPhase(WidgetTester tester) => (_painter(tester, '_BowPainter').bow()?.phase as Enum?)?.name ?? 'none';

double _middle(WidgetTester tester) {
  final frame = _painter(tester, '_PanPainter').frame() as SpectrumFrame;
  return (frame.lowHz + frame.highHz) / 2;
}

/// Alt held, the line taken hold of at [from] across the spectrum and drawn to [to].
Future<TestGesture> _draw(WidgetTester tester, Offset from, Offset to) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  final drag = await tester.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await drag.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  return drag;
}

void main() {
  testWidgets('a string drawn past 30° shoots the line the other way, by how far and how wide the window, the window chasing it to watch it land quivering', (
    tester,
  ) async {
    final radio = _Radio();
    final box = await _show(tester, radio);
    // Nocked 200 down the 300: the upper half, the longer, leans 30° at 115 pixels and 60° at 346.
    final drag = await _draw(tester, box.topLeft + const Offset(200, 40), box.topLeft + const Offset(0, 200));
    expect(_strung(tester), isTrue);
    expect(_pull(tester), -200);
    expect(radio.tunes, isEmpty, reason: 'drawing the string aims; only letting go tunes');
    expect(_line(tester), 14050000);

    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 16));
    // Pulled toward the lower frequencies, it flies toward the higher: 200 of the 346 a full draw
    // takes, of the 300 kHz a full draw flies from a window 100 kHz wide — 6.7 widths, as from 15 kHz
    // it flies 100 — is 173.2 kHz, on the 1 kHz coarse step.
    final shot = 14050000 + (300000 * 200 / (200 * math.tan(math.pi / 3)) / 1000).round() * 1000.0;
    expect(shot, 14223000);
    expect(radio.tunes, isEmpty, reason: 'the radio goes as the window does, not as the arrow leaves');
    expect(radio.recentered, isEmpty, reason: 'the window stays put as the arrow leaves');
    expect(_line(tester), isNull, reason: 'the line is the arrow, in the air: not yet where the dial is');
    expect(_bowPhase(tester), 'flight');
    expect(_pull(tester), lessThan(0), reason: 'arched back from the way it flies');
    // The window holds still while the arrow leaves it, then chases.
    final arrow = <double>[];
    while (_middle(tester) == 14050000 && arrow.length < 100) {
      arrow.add(_bowHz(tester));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(arrow.length, greaterThan(3), reason: 'the window waits for the arrow to get away');
    expect(radio.tunes, [shot], reason: 'tuned there as the window sets off');
    expect(_middle(tester) - 14050000, lessThan(arrow.last - arrow[arrow.length - 2]), reason: 'slow to set off, then quick to close');
    for (var i = 1; i < arrow.length; i++) {
      expect(arrow[i], greaterThan(arrow[i - 1]), reason: 'away from the bow, toward the higher frequencies');
    }
    expect(radio.recentered, contains(shot), reason: 'the window sets off for where the shot lands, the radio\'s scope with it');

    radio.vfo = shot;
    radio.notifyListeners();
    // At rest there before the arrow lands, to watch it come in.
    while (_middle(tester) != shot && arrow.length < 200) {
      arrow.add(_bowHz(tester));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_bowPhase(tester), 'flight');
    expect(_bowHz(tester), lessThan(shot));
    while (_line(tester) == null && arrow.length < 300) {
      arrow.add(_bowHz(tester));
      expect(_middle(tester), shot);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_line(tester), shot, reason: 'landed');
    // 1.7 widths of the window in a third of a second, as quick as 100 kHz in 1.1 s from 15 kHz wide.
    expect(arrow.length, inInclusiveRange(15, 22), reason: 'the arrow flies at a pace for the window\'s width');
    expect(_strung(tester), isTrue, reason: 'quivering where it landed');
    // Swinging the way it flew first.
    await tester.pump(const Duration(milliseconds: 16));
    expect(_pull(tester), greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    expect(_strung(tester), isFalse, reason: 'settled straight');
    expect(radio.tunes, [shot]);
  });

  testWidgets('a shot stops at the edge of the band the dial was in', (tester) async {
    final radio = _Radio();
    final box = await _show(tester, radio);
    // As far as the shot that lands at 14.108 MHz, the other way: 13.992 is past 20 m's foot.
    final drag = await _draw(tester, box.topLeft + const Offset(200, 40), box.topLeft + const Offset(400, 200));
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(radio.tunes, [14000000]);
    expect(_strung(tester), isFalse);
  });

  testWidgets('a string let go short of 30° twangs back straight and tunes nothing', (tester) async {
    final radio = _Radio();
    final box = await _show(tester, radio);
    // Nocked 40 down: the lower half, 260 long, leans 30° only at 150 pixels.
    final drag = await _draw(tester, box.topLeft + const Offset(200, 40), box.topLeft + const Offset(60, 40));
    expect(_pull(tester), -140);
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    // It swings through straight to the other side, less far each time.
    final pulls = <double>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      pulls.add(_pull(tester)!);
    }
    expect(pulls.reduce(math.max), allOf(greaterThan(0), lessThan(140)));
    expect(radio.tunes, isEmpty);
    expect(_line(tester), 14050000, reason: 'the line stays where the dial is, drawn as the string');
    await tester.pump(const Duration(seconds: 2));
    expect(_strung(tester), isFalse);
    expect(_pull(tester), isNull);
    expect(radio.tunes, isEmpty);
    expect(radio.recentered, isEmpty);
  });

  testWidgets('a string drawn as far as it goes shoots 6.7 widths of a narrow window, the window overtaking the arrow', (tester) async {
    final radio = _Radio();
    final box = await _show(tester, radio, spectrum: {'span': 10000});
    // Nocked in the middle, 150 from either end: fully drawn at 60°, 260 pixels, however far the pointer goes.
    final drag = await _draw(tester, box.topLeft + const Offset(200, 40), box.topLeft + const Offset(-100, 150));
    expect(_pull(tester), closeTo(-150 * math.tan(math.pi / 3), .01));
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 16));
    // 6.7 widths away, follow would put the window there at once, as for a band change, and nothing would chase.
    // The arrow out of sight ahead, then the window catching it up and leaving it out of sight behind.
    var (gotAway, leftBehind) = (false, false);
    for (var i = 0; i < 80 && _bowPhase(tester) == 'flight'; i++) {
      final (arrow, middle) = (_bowHz(tester), _middle(tester));
      if (arrow > middle + 5000) gotAway = true;
      if (gotAway && arrow < middle - 5000) leftBehind = true;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(gotAway, isTrue);
    expect(leftBehind, isTrue, reason: 'the window overtakes the arrow');
    // 66.7 kHz from a window 10 kHz wide, on its coarse step.
    expect(radio.tunes.single, closeTo(14116667, 500));
    final shot = radio.tunes.single;
    radio.vfo = shot;
    radio.notifyListeners();
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_middle(tester), shot);
    expect(_line(tester), shot);
    expect(_strung(tester), isFalse);
  });

  testWidgets('on a scope centred on its dial, the window still holds still as the arrow leaves it', (tester) async {
    // Tuned as the arrow leaves, the next sweep would arrive centred on the target and the
    // window, following the sweeps, would be there before the arrow had left.
    final radio = _Radio()..centred = true;
    final box = await _show(tester, radio);
    final drag = await _draw(tester, box.topLeft + const Offset(200, 40), box.topLeft + const Offset(0, 200));
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    var still = 0;
    while (_middle(tester) == 14050000 && still < 100) {
      expect(_bowPhase(tester), 'flight');
      still++;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(still, greaterThan(3), reason: 'the arrow gets away before the window moves');
    expect(radio.tunes, [14223000]);
    radio.vfo = 14223000;
    radio.notifyListeners();
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_middle(tester), 14223000);
    expect(_line(tester), 14223000);
  });

  testWidgets('without Alt, the line is dragged as ever', (tester) async {
    final radio = _Radio();
    final box = await _show(tester, radio);
    final drag = await tester.startGesture(box.topLeft + const Offset(200, 40));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(-20, 30));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_strung(tester), isFalse);
    await drag.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(radio.tunes.last, lessThan(14050000), reason: 'the dial follows the pointer down the frequencies');
  });
}
