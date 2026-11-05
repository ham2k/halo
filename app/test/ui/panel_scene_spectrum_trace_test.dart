// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a spectrum's trace and the fill under it are drawn: colored by level,
// smoothed, dashed, and in an overlay's own look over its frequencies.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
  final tunes = <double>[];
  final controller = StreamController<SpectrumFrame>.broadcast();
  @override
  String? resolve(String? radio) => 'radio-1';
  @override
  Stream<SpectrumFrame> frames(String uuid) => controller.stream;
  @override
  String? problem(String uuid) => null;
  @override
  double? vfoHz(String uuid) => 14050000;
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
  void showWidth(String uuid, Object owner, int? widthHz) {}
  @override
  bool recenter(String uuid, int centerHz) => false;
  @override
  int? maxWidthHz(String uuid) => null;
  @override
  bool canTune(String uuid) => true;
  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) {
    tunes.add(hz);
    return true;
  }

  @override
  bool widen(String uuid, int widthHz) => false;
}

/// One spectrum over a 400 by 300 pane with no axis or level strip: its spectrum the top 120 pixels.
Map<String, dynamic> _doc(Map<String, dynamic> spectrum) => {
  'version': 1,
  'width': 400,
  'height': 300,
  'values': const <String, num>{},
  'layers': const <Object>[],
  'controls': [
    {'id': 'pan', 'kind': 'spectrum', 'label': 'Panadapter', 'event': 'tune', 'levelScale': false, 'scale': false, ...spectrum},
  ],
  'layout': {
    'column': [
      {'control': 'pan', 'flex': 1},
    ],
    'crossAxisAlignment': 'stretch',
  },
};

/// 14.000 to 14.100 MHz in 1000 bins, 0 to 80 dB, at [level] but for [spikes], the noise at [noise].
Future<void> _show(WidgetTester tester, Map<String, dynamic> spectrum, {double level = 0, Map<int, double> spikes = const {}, double? noise}) async {
  final radio = _Radio();
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DockPaneVisibility(
              visible: true,
              child: PanelSceneView(scene: PanelScene(_doc({'average': 0, ...spectrum})), onEvent: (e) async => {}, spectrum: radio),
            ),
          ),
        ),
      ),
    ),
  );
  final levels = Float32List(1000)..fillRange(0, 1000, level);
  for (final MapEntry(:key, :value) in spikes.entries) {
    levels[key] = value;
  }
  radio.controller.add(SpectrumFrame(lowHz: 14000000, highHz: 14100000, levels: levels, floorDb: 0, ceilingDb: 80, noiseDb: noise, atMillis: 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder get _pan => find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PanPainter');

/// The trace's stroke, as the spectrum last drew it.
Path _stroke(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  tester.widget<CustomPaint>(_pan).painter!.paint(canvas, tester.getSize(_pan));
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawPath && (call.invocation.positionalArguments[1] as Paint).style == PaintingStyle.stroke)
        call.invocation.positionalArguments[0] as Path,
  ].single;
}

/// The spectrum's pixels, read where the trace and its fill are drawn.
Future<Color Function(double x, double y)> _pixels(WidgetTester tester) async {
  final size = tester.getSize(_pan);
  final (w, h) = (size.width.ceil(), size.height.ceil());
  final recorder = ui.PictureRecorder();
  tester.widget<CustomPaint>(_pan).painter!.paint(Canvas(recorder), size);
  final bytes = (await tester.runAsync<ByteData?>(() async {
    final image = await recorder.endRecording().toImage(w, h);
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  }))!;
  return (double x, double y) {
    final i = (y.floor() * w + x.floor()) * 4;
    return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  };
}

void main() {
  test('a trace is colored one way and its fill one way, and an overlay\'s look covers an area', () {
    PanelScene scene(Map<String, dynamic> spectrum) => PanelScene(_doc(spectrum));
    const two = ['#FF0000', '#0000FF'];
    // Given two ways, one would be silently ignored.
    expect(() => scene({'traceColor': '#FF0000', 'traceColors': two}), throwsFormatException);
    expect(() => scene({'fillColor': '#FF0000', 'fillColors': two}), throwsFormatException);
    expect(() => scene({'fillColorBottom': '#FF0000', 'fillColors': two}), throwsFormatException);
    expect(
      () => scene({
        'traceColors': ['#FF0000'],
      }),
      throwsFormatException,
      reason: 'one stop is a color, not a scale',
    );
    expect(() => scene({'traceColors': List.filled(9, '#FF0000')}), throwsFormatException);
    expect(() => scene({'traceSmooth': 21}), throwsFormatException);
    expect(() => scene({'traceDashed': 'yes'}), throwsFormatException);
    // A stop placed by level is on the spectrum; a plain color among placed ones has no place to take.
    const white = {'color': '#FFFFFF', 'at': 'noise'};
    expect(
      () => scene({
        'fillColors': [white, '#FF0000'],
      }),
      throwsFormatException,
    );
    expect(
      () => scene({
        'fillColors': [
          white,
          {'color': '#FF0000', 'at': 'waterfall+5s'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => scene({
        'fillColors': [
          white,
          {'color': '#FF0000'},
        ],
      }),
      throwsFormatException,
    );
    final look = {'color': '#00FF00'};
    // A line has no frequencies to cover, nor does the tuned frequency's.
    expect(
      () => scene({
        'overlays': [
          {'at': 0, 'trace': look},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => scene({
        'center': {'trace': look},
      }),
      throwsFormatException,
    );
    expect(
      () => scene({
        'overlays': [
          {
            'from': -100,
            'to': 100,
            'trace': {'color': '#00FF00', 'colors': two},
          },
        ],
      }),
      throwsFormatException,
    );
    // A look is a style of its own: an overlay with nothing else draws something.
    final overlay = scene({
      'overlays': [
        {'from': -100, 'to': 100, 'trace': look},
      ],
    }).controls.single.spectrum!.overlays.single;
    expect(overlay.trace!.color, const Color(0xFF00FF00));
  });

  testWidgets('the trace and its fill take colors by level, and an overlay its own look over its frequencies', (tester) async {
    // At 70 of 0 to 80 dB the trace runs 15 pixels down the 120; 14.050 to 14.060 MHz is 200 to 240 across.
    await _show(tester, {
      'traceWidth': 4,
      'traceColors': ['#0000FF', '#FF0000'],
      'fillColors': ['#00FF00', '#FF0000'],
      'overlays': [
        {
          'anchor': 'absolute',
          'from': 14050000,
          'to': 14060000,
          'trace': {'color': '#FFFFFF', 'fill': '#FFFF00'},
        },
      ],
    }, level: 70);
    final pixel = await _pixels(tester);
    // Lowest level first: the trace high up is nearly the last stop — red, which the theme's own trace is not —
    // and the fill the first at the bottom.
    final trace = pixel(100, 15);
    expect(trace.r, greaterThan(trace.b));
    final (low, high) = (pixel(100, 115), pixel(100, 25));
    expect(low.g, greaterThan(low.r));
    expect(high.r, greaterThan(high.g));
    // Inside the overlay its own look, both stops replaced by its colors.
    final (inside, under) = (pixel(220, 15), pixel(220, 80));
    expect([inside.r, inside.g, inside.b], everyElement(greaterThan(.94)));
    expect([under.r, under.g, under.b], [greaterThan(.94), greaterThan(.94), lessThan(.06)]);
    // Past it, the control's look again.
    expect(pixel(260, 115).g, greaterThan(pixel(260, 115).r));
  });

  testWidgets('a stop placed by the noise colors the fill from there, wherever the noise sits', (tester) async {
    // The noise at 20 of 0 to 80 dB is 90 pixels down the 120; the trace at 70 is 15.
    final stops = {
      'fillColors': [
        {'color': '#FFFFFF', 'at': 'noise'},
        {'color': '#FF0000', 'at': 'noise+1db'},
      ],
    };
    await _show(tester, stops, level: 70, noise: 20);
    var pixel = await _pixels(tester);
    final (below, above) = (pixel(100, 100), pixel(100, 80));
    expect([below.r, below.g, below.b], everyElement(greaterThan(.94)), reason: 'at or under the noise, the first stop');
    expect([above.r, above.g, above.b], [greaterThan(.94), lessThan(.1), lessThan(.1)], reason: 'a little over it, the next: not spread evenly up the height');
    // Ten dB more noise moves the edge up with it: 75 pixels down.
    await _show(tester, stops, level: 70, noise: 30);
    pixel = await _pixels(tester);
    expect(pixel(100, 80).g, greaterThan(.94));
    expect(pixel(100, 65).g, lessThan(.1));
    // A half-clear top-to-bottom fill is half clear: the paint's own alpha does not dim the gradient again.
    await _show(tester, const {'fillColor': '#80FF0000', 'fillColorBottom': '#80FF0000'}, level: 70);
    pixel = await _pixels(tester);
    expect(pixel(100, 100).a, closeTo(.5, .02));
  });

  testWidgets('a smoothed trace averages across pixels of frequency, and a dashed one is drawn in pieces', (tester) async {
    // One bin at 80 dB among silence: the plain trace reaches the top.
    await _show(tester, const {}, spikes: {500: 80});
    expect(_stroke(tester).getBounds().top, lessThan(1));
    expect(_stroke(tester).computeMetrics().length, 1);
    // Over 20 pixels — 25 bins either side at 0.4 pixels a bin — the spike is a fiftieth of itself.
    await _show(tester, const {'traceSmooth': 20}, spikes: {500: 80});
    expect(_stroke(tester).getBounds().top, closeTo(120 - 80 / 51 / 80 * 120, 1));
    await _show(tester, const {'traceDashed': true});
    expect(_stroke(tester).computeMetrics().length, greaterThan(30), reason: '400 pixels of trace in dashes ten apart');
  });
}
