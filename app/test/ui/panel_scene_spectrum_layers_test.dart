// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spectrum's layers: what a scene places by frequency, moving with the
// window, and by pixels from it, keeping their size at any zoom.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';
import '../support/fake_clock.dart';

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
  bool fitSpan(String uuid, int widthHz) => false;
}

/// A scene with one spectrum, 400 by 300 with no level strip: 100 kHz across 400 pixels, 250 Hz a
/// pixel, until a `span` narrows it.
Map<String, dynamic> _doc(Map<String, dynamic> spectrum, {Map<String, num> values = const {}}) => {
  'version': 1,
  'width': 400,
  'height': 300,
  'values': values,
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

Future<List<Map<String, dynamic>>> _show(
  WidgetTester tester,
  _Radio radio,
  Map<String, dynamic> spectrum, {
  Map<String, num> values = const {},
  Map<String, dynamic>? doc,
}) async {
  final events = <Map<String, dynamic>>[];
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
                scene: PanelScene(doc ?? _doc(spectrum, values: values)),
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
  radio.controller.add(SpectrumFrame(lowHz: 14000000, highHz: 14100000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, atMillis: 0));
  await tester.pump();
  return events;
}

/// What the layers painted, on a recording canvas the size of the control.
List<RecordedInvocation> _painted(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_LayerPainter'))
      .single
      .painter!;
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, tester.getSize(find.byType(SceneSpectrumView)));
  return canvas.invocations.toList();
}

List<Rect> _rects(WidgetTester tester) => [
  for (final call in _painted(tester))
    if (call.invocation.memberName == #drawRRect) (call.invocation.positionalArguments[0] as RRect).outerRect,
];

List<(Offset, Offset)> _lines(WidgetTester tester) => [
  for (final call in _painted(tester))
    if (call.invocation.memberName == #drawLine) (call.invocation.positionalArguments[0] as Offset, call.invocation.positionalArguments[1] as Offset),
];

SceneSpectrumLayer _layer(Map<String, dynamic> json) => SceneSpectrumLayer(json);

void main() {
  setUp(followFakeClock);

  test('a coordinate along the frequency is a frequency or the dial, then Hz that zoom and pixels that do not', () {
    double? at(Object coordinate, {double low = 14000000, double high = 14100000, Map<String, double> values = const {}}) =>
        SceneSpectrumAlong.parse({'x': coordinate}, 'x')!.at(low, high, 1000, 14050000, values);
    expect(at('freq:14074000'), 740);
    expect(at('freq:14074000+40px'), 780);
    // Twice the zoom: the frequency moves, the pixels after it stay forty.
    expect(at('freq:14074000+40px', low: 14050000, high: 14100000), 480 + 40);
    expect(at('vfo-1000hz'), 490);
    expect(at('vfo+500hz-3px'), 502);
    expect(at('freq:spot', values: {'spot': 14020000}), 200);
    expect(at('freq:spot'), isNull, reason: 'a value the scene has not set yet puts it nowhere');
    expect(at(12), 12, reason: 'a number is pixels from the low edge');
    expect(at('12px'), 12);
    for (final bad in ['freq:', '14074000', 'vfo*2', 'vfo+10', 'freq:14074000+5em', 'vfo:main', '', 'freq:1 +2px']) {
      expect(() => SceneSpectrumAlong.parse({'x': bad}, 'x'), throwsFormatException, reason: bad);
    }
  });

  test('a coordinate across it is a part\'s edge, then a share, an age or pixels, or dB above the noise', () {
    ({double top, double bottom})? parts(SceneSpectrumPart part) => switch (part) {
      SceneSpectrumPart.spectrum => (top: 0, bottom: 112),
      SceneSpectrumPart.axis => (top: 112, bottom: 132),
      SceneSpectrumPart.waterfall => (top: 132, bottom: 300),
    };
    double? at(Object coordinate, {double? noise = -110, double? secondsPerPixel = .5}) =>
        SceneSpectrumAcross.parse({'y': coordinate}, 'y')!.at(parts, 300, noise: noise, floor: -120, range: 80, secondsPerPixel: secondsPerPixel);
    expect(at('spectrum'), 0);
    expect(at('spectrum:bottom-12px'), 100);
    expect(at('axis:top+2px'), 114);
    expect(at(30), 30);
    expect(SceneSpectrumAcross.parse({'y': 'waterfall'}, 'y')!.at((_) => null, 300), isNull, reason: 'a part not shown draws nothing on it');
    // A share is of the part it is on, so it keeps its place in it whatever the part's height.
    expect(at('spectrum+25%'), 28);
    expect(at('spectrum:bottom-25%+2px'), 86);
    expect(at('axis+50%'), 122);
    expect(at('10%'), 30, reason: 'with no part, of the control');
    // An age down the waterfall, at its speed now: half a second a pixel.
    expect(at('waterfall+5s'), 142);
    expect(at('waterfall+5s+50%'), 226);
    expect(at('waterfall+5s', secondsPerPixel: null), isNull, reason: 'no speed yet, no age');
    // dB above the noise, on the spectrum as its trace is drawn: -120 to -40 dB down 112 pixels.
    expect(at('noise'), 98);
    expect(at('noise+20db'), 70);
    expect(at('noise+20db-2px'), 68);
    expect(at('noise+20db', noise: null), isNull, reason: 'a source that says no noise puts it nowhere');
    expect(at('noise+20db+25%'), 98, reason: 'a share from the noise is of the spectrum');
    for (final bad in [
      'spectrum:middle',
      'spectrum+5hz',
      'pan',
      'fall',
      'dbm:-90',
      'db:-90',
      'spectrum+5',
      'spectrum%',
      'spectrum+1001%',
      'spectrum+5s',
      '5s',
      'spectrum+20db',
      'noise+5s',
      'noise:bottom',
    ]) {
      expect(() => SceneSpectrumAcross.parse({'y': bad}, 'y'), throwsFormatException, reason: bad);
    }
  });

  test('a layer is refused where it would draw nothing, or a scene could not tell it from another', () {
    expect(() => _layer({'id': 'a', 'kind': 'rect', 'x': 'vfo', 'fill': '#ff0000'}), throwsFormatException, reason: 'a box needs x2');
    expect(() => _layer({'id': 'a', 'kind': 'rect', 'x': 'vfo', 'x2': 'vfo+5px'}), throwsFormatException, reason: 'no color or fill');
    expect(() => _layer({'id': 'a', 'kind': 'text', 'x': 'vfo'}), throwsFormatException);
    expect(() => _layer({'id': 'a', 'kind': 'text', 'x': 'vfo', 'text': 'A', 'value': 'v'}), throwsFormatException);
    expect(() => _layer({'id': 'a', 'kind': 'shape', 'x': 'vfo'}), throwsFormatException);
    expect(() => _layer({'id': 'a', 'kind': 'line', 'x': 'vfo', 'svg': '<svg/>'}), throwsFormatException);
    // A click opens the menu, so an event beside it would never be sent.
    final menu = [
      {'label': 'Wake', 'event': 'wake'},
    ];
    expect(() => _layer({'id': 'a', 'kind': 'line', 'x': 'vfo', 'menu': menu, 'event': 'poke'}), throwsFormatException);
    expect(() => _layer({'id': 'a', 'kind': 'line', 'x': 'vfo', 'menu': <Object>[]}), throwsFormatException);
    expect(() => SceneSpectrumAnnotation({'id': 'a', 'text': 'A', 'hz': 14074000, 'menu': menu, 'event': 'poke'}), throwsFormatException);
    expect(_layer({'id': 'a', 'kind': 'line', 'x': 'vfo', 'menu': menu}).clickable, isTrue);
    final line = {'id': 'a', 'kind': 'line', 'x': 'vfo'};
    expect(
      () => PanelScene(
        _doc({
          'layers': [line, line],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => PanelScene(
        _doc({
          'layers': [
            {'id': 'a', 'kind': 'line', 'x': 'freq:spot'},
          ],
        }),
      ),
      throwsFormatException,
      reason: 'a scene value the scene does not have',
    );
  });

  testWidgets('a rect with one edge on a frequency and the other forty pixels on keeps its width through a zoom; one on two frequencies scales', (
    tester,
  ) async {
    final radio = _Radio();
    Map<String, dynamic> layers(num span) => {
      'span': span,
      'layers': [
        {'id': 'tag', 'kind': 'rect', 'x': 'freq:14060000', 'x2': 'freq:14060000+40px', 'y': 'spectrum', 'y2': 'spectrum:top+6px', 'fill': '#ff0000'},
        {'id': 'band', 'kind': 'rect', 'x': 'freq:14040000', 'x2': 'freq:14060000', 'fill': '#3366ff80'},
      ],
    };
    await _show(tester, radio, layers(100000));
    var [tag, band] = _rects(tester);
    // 250 Hz a pixel: 14.060 is 240 in, 14.040 is 160.
    expect((tag.left, tag.width, tag.top, tag.height), (240, 40, 0, 6));
    expect((band.left, band.width, band.height), (160, 80, 300));
    await _show(tester, radio, layers(50000));
    [tag, band] = _rects(tester);
    // 125 Hz a pixel about 14.050: 14.060 is 280 in, 14.040 is 120.
    expect((tag.left, tag.width), (280, 40));
    expect((band.left, band.width), (120, 160));
  });

  testWidgets('a line by the dial follows it, and across a turned spectrum it runs across the screen', (tester) async {
    final radio = _Radio();
    await _show(tester, radio, {
      'layers': [
        {'id': 'edge', 'kind': 'line', 'x': 'vfo-2500hz', 'y': 'spectrum', 'y2': 'spectrum:bottom'},
      ],
    });
    final (a, b) = _lines(tester).single;
    expect((a.dx, b.dx), (190, 190));
    await _show(tester, radio, {
      'flow': 'right',
      'layers': [
        {'id': 'edge', 'kind': 'line', 'x': 'vfo-2500hz'},
      ],
    });
    // Frequency rises up a spectrum flowing right: 300 pixels for 100 kHz, 14.0475 MHz 142.5 from the bottom.
    final (c, d) = _lines(tester).single;
    expect((c.dy, d.dy), (157.5, 157.5));
    expect((c.dx, d.dx), (0, 400));
  });

  testWidgets('a layer behind is drawn under the spectrum\'s trace, and a click reaches it where none over it is', (tester) async {
    final radio = _Radio();
    Map<String, dynamic> spec({required bool dragon}) => {
      'layers': [
        if (dragon)
          {
            'id': 'dragon',
            'kind': 'rect',
            'x': 'freq:14060000',
            'x2': 'freq:14080000',
            'y': 'spectrum',
            'y2': 'spectrum:bottom',
            'fill': '#00FF00',
            'behind': true,
            'event': 'poke',
          },
        {'id': 'tag', 'kind': 'rect', 'x': 'freq:14070000', 'x2': 'freq:14080000', 'y': 'spectrum', 'y2': 'spectrum+50%', 'fill': '#FF0000', 'event': 'poke'},
      ],
    };
    var events = await _show(tester, radio, spec(dragon: true));
    await tester.pump();
    // Painted in the stack's order: the one behind before the trace, the other after it.
    final painters = [
      for (final paint in tester.widgetList<CustomPaint>(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(CustomPaint))))
        switch (paint.painter?.runtimeType.toString()) {
          '_LayerPainter' => 'layers ${[for (final l in (paint.painter as dynamic).layers as List) l.id].join(',')}',
          '_PanPainter' => 'trace',
          _ => null,
        },
    ].nonNulls;
    expect(painters, ['layers dragon', 'trace', 'layers tag']);
    final box = tester.getRect(find.byType(SceneSpectrumView));
    Future<String?> click(Offset at) async {
      events.clear();
      await tester.tapAt(box.topLeft + at);
      await tester.pump(const Duration(milliseconds: 400));
      return events.isEmpty ? null : events.single['layer'] as String;
    }

    // 14.060 to 14.080 MHz is 240 to 320 pixels; the tag over its upper half from 280.
    expect(await click(const Offset(300, 20)), 'tag', reason: 'the one over the picture is on top');
    expect(await click(const Offset(250, 20)), 'dragon');
    expect(await click(const Offset(300, 100)), 'dragon', reason: 'below the tag, the one behind');
    // Gone from the scene, it takes no clicks where it was drawn: the picture tunes there.
    events = await _show(tester, radio, spec(dragon: false));
    await tester.pump();
    expect(await click(const Offset(250, 20)), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a click on a layer with an event is the extension\'s, with its id and the frequency clicked, and tunes nothing', (tester) async {
    final radio = _Radio();
    final events = await _show(tester, radio, {
      'layers': [
        {'id': 'ft8', 'kind': 'text', 'x': 'freq:14074000', 'y': 'spectrum:top+10px', 'text': 'FT8', 'event': 'spot'},
        {'id': 'plain', 'kind': 'line', 'x': 'freq:14020000'},
      ],
    });
    // Drawn on the first frame: the hits are where the last paint put them.
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    await tester.tapAt(box.topLeft + const Offset(300, 16));
    await tester.pump(const Duration(milliseconds: 400));
    expect(events.single['action'], 'spot');
    expect(events.single['phase'], 'activate');
    expect(events.single['layer'], 'ft8');
    expect(events.single['value'] as double, closeTo(14075000, 250));
    expect(radio.tunes, isEmpty);
    // One without an event is the picture's: a click there tunes.
    await tester.tapAt(box.topLeft + const Offset(80, 150));
    await tester.pump(const Duration(milliseconds: 400));
    expect(radio.tunes, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a click says where it landed: the part, the frequency, the level on the spectrum and the age on the waterfall', (tester) async {
    final radio = _Radio();
    final events = await _show(tester, radio, {
      'waterfallSpeed': 2,
      'layers': [
        {'id': 'all', 'kind': 'rect', 'x': 0, 'x2': 'freq:14100000', 'fill': '#00000000', 'event': 'poke'},
      ],
    });
    radio.controller.add(SpectrumFrame(lowHz: 14000000, highHz: 14100000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, noiseDb: 10, atMillis: 0));
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    Future<Map<String, dynamic>> click(Offset at) async {
      events.clear();
      await tester.tapAt(box.topLeft + at);
      final clicked = nowMillis();
      await tester.pump(const Duration(milliseconds: 400));
      return {...events.single['at'] as Map<String, dynamic>, 'clicked': clicked};
    }

    // The spectrum's 120 pixels hold 0 to 80 dB: three quarters up is 60, fifty above the noise at 10.
    final spectrum = await click(const Offset(100, 30));
    expect(spectrum['part'], 'spectrum');
    expect([spectrum['x'], spectrum['y']], [100, 30]);
    expect(spectrum['hz'] as double, closeTo(14025000, 1));
    expect(spectrum['db'] as double, closeTo(60, .01));
    expect(spectrum['aboveNoiseDb'] as double, closeTo(50, .01));
    expect(spectrum.keys, isNot(contains('ageSeconds')));
    expect(spectrum.keys, isNot(contains('sceneX')), reason: 'placed by the layout, it has no place in the artwork');
    // A hundred pixels down the waterfall at half a second a pixel: the row taken fifty seconds before the click.
    final waterfall = await click(const Offset(100, 220));
    expect(waterfall['part'], 'waterfall');
    expect(waterfall['ageSeconds'] as double, closeTo(50, .01));
    expect(waterfall['atMillis'], (waterfall['clicked'] as int) - 50000);
    expect(waterfall.keys, isNot(contains('db')));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a band scope placed over the artwork says where a click landed in scene units', (tester) async {
    final radio = _Radio();
    // The 800 by 600 artwork fits the 400 by 300 panel at half size: the control's 400 by 300 units are 200 by 150 on
    // screen, while it lays out (and its layers' pixels measure) at its full 400 by 300.
    final events = await _show(
      tester,
      radio,
      const {},
      doc: {
        'version': 1,
        'width': 800,
        'height': 600,
        'values': const <String, num>{},
        'layers': const <Object>[],
        'controls': [
          {
            'id': 'pan',
            'kind': 'spectrum',
            'label': 'Panadapter',
            'levelScale': false,
            'scale': false,
            ...{'x': 100, 'y': 100, 'width': 400, 'height': 300},
            'layers': [
              {'id': 'all', 'kind': 'rect', 'x': 0, 'x2': 'freq:14100000', 'fill': '#00000000', 'event': 'poke'},
            ],
          },
        ],
      },
    );
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    expect(box.size, const Size(200, 150));
    await tester.tapAt(box.topLeft + const Offset(100, 50));
    await tester.pump(const Duration(milliseconds: 400));
    final at = events.single['at'] as Map<String, dynamic>;
    expect([at['x'], at['y']], [200, 100], reason: 'the pixels a layer measures');
    expect([at['sceneX'], at['sceneY']], [300, 200]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a layer with a menu opens it where it was clicked, and sends the item picked with where the click landed', (tester) async {
    final radio = _Radio();
    final events = await _show(tester, radio, {
      'layers': [
        {
          'id': 'tape',
          'kind': 'rect',
          'x': 'freq:14060000',
          'x2': 'freq:14080000',
          'y': 'spectrum',
          'y2': 'spectrum:bottom',
          'fill': '#FFD400',
          'menu': [
            {'label': 'Wake', 'event': 'wake'},
            {'label': 'Dismiss', 'event': 'dismiss'},
          ],
        },
      ],
    });
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    final clicked = box.topLeft + const Offset(280, 60);
    await tester.tapAt(clicked);
    await tester.pumpAndSettle();
    expect(events, isEmpty, reason: 'nothing is sent until an item is picked');
    expect(radio.tunes, isEmpty);
    // At the pointer, not at the control's corner.
    expect((tester.getTopLeft(find.text('Wake')) - clicked).distance, lessThan(48));
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(events.single['action'], 'dismiss');
    expect(events.single['layer'], 'tape');
    expect(events.single['value'] as double, closeTo(14070000, 250));
    expect((events.single['at'] as Map)['part'], 'spectrum');
    // Closed without a pick, it sends nothing.
    events.clear();
    await tester.tapAt(clicked);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 295));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    expect(radio.tunes, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('artwork is drawn into its box once it has loaded, upright and stretched to it', (tester) async {
    final radio = _Radio();
    await _show(tester, radio, {
      'layers': [
        {
          'id': 'logo',
          'kind': 'svg',
          'x': 'freq:14060000',
          'x2': 'freq:14060000+20px',
          'y': 'waterfall',
          'y2': 'waterfall:top+10px',
          'svg': '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="#f00"/></svg>',
        },
      ],
    });
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    final calls = _painted(tester);
    expect(calls.any((call) => call.invocation.memberName == #drawPicture), isTrue);
    // 10 by 10 artwork in a 20 by 10 box 240 in, at the waterfall's top: 300 high, a 0.4 panadapter.
    final scale = calls.firstWhere((call) => call.invocation.memberName == #scale).invocation.positionalArguments;
    final at = calls.firstWhere((call) => call.invocation.memberName == #translate).invocation.positionalArguments;
    expect(scale, [2, 1]);
    expect(at, [240, 120]);
  });

  testWidgets('a line at a share of a part stays at that share of it as the split moves', (tester) async {
    final radio = _Radio();
    Map<String, dynamic> split(num share) => {
      'split': share,
      'layers': [
        {'id': 'spectrum', 'kind': 'line', 'x': 0, 'x2': 'freq:14100000', 'y': 'spectrum+50%', 'y2': 'spectrum+50%'},
        {'id': 'waterfall', 'kind': 'line', 'x': 0, 'x2': 'freq:14100000', 'y': 'waterfall:bottom-25%', 'y2': 'waterfall:bottom-25%'},
      ],
    };
    // 300 pixels, no axis: the spectrum's 40% is 120 of them, the waterfall the 180 below.
    await _show(tester, radio, split(.4));
    expect(_lines(tester).map((line) => line.$1.dy), [closeTo(60, .01), closeTo(255, .01)]);
    await _show(tester, radio, split(.5));
    expect(_lines(tester).map((line) => line.$1.dy), [closeTo(75, .01), closeTo(262.5, .01)]);
  });

  testWidgets('a line above the noise stays there as the contrast moves the picture, and one at an age moves with the speed', (tester) async {
    final radio = _Radio();
    Map<String, dynamic> spec(num floor, num speed) => {
      'floor': floor,
      'waterfallSpeed': speed,
      'layers': [
        {'id': 'noise', 'kind': 'line', 'x': 0, 'x2': 'freq:14100000', 'y': 'noise+20db', 'y2': 'noise+20db'},
        {'id': 'age', 'kind': 'line', 'x': 0, 'x2': 'freq:14100000', 'y': 'waterfall+5s', 'y2': 'waterfall+5s'},
      ],
    };
    Future<void> sweep() async {
      radio.controller.add(SpectrumFrame(lowHz: 14000000, highHz: 14100000, levels: Float32List(1000), floorDb: 0, ceilingDb: 80, noiseDb: 10, atMillis: 0));
      await tester.pump();
    }

    // 0 to 80 dB down a 120-pixel spectrum, the noise at 10: 30 dB up is 45 pixels from its top.
    // The waterfall's 180 pixels below at two rows a second are half a second a pixel: 5 s is 10 down.
    await _show(tester, radio, spec(0, 2));
    await sweep();
    expect(_lines(tester).map((line) => line.$1.dy), [closeTo(75, .01), closeTo(130, .01)]);
    // Ten dB more floor lowers the trace by an eighth of the spectrum, the noise with it; at four rows a second 5 s of history is twice as tall.
    await _show(tester, radio, spec(10, 4));
    await sweep();
    expect(_lines(tester).map((line) => line.$1.dy), [closeTo(90, .01), closeTo(140, .01)]);
  });

  test('the band scope reads its names from before extension API 17 the same as its own', () {
    SceneSpectrumSpec spec(Map<String, dynamic> spectrum, {String kind = 'bandScope'}) => PanelScene({
      ..._doc(spectrum),
      'controls': [
        {'id': 'scope', 'kind': kind, 'label': 'Band scope', ...spectrum},
      ],
      'layout': {'control': 'scope'},
    }).controlsById['scope']!.spectrum!;
    expect(
      PanelScene({
        ..._doc(const {}),
        'controls': [
          {'id': 'scope', 'kind': 'bandScope', 'label': 'Band scope'},
        ],
        'layout': {'control': 'scope'},
      }).controlsById['scope']!.kind,
      'spectrum',
    );
    for (final kind in ['bandScope', 'spectrum']) {
      for (final name in ['spectrum', 'pan']) {
        final s = spec({
          'display': name,
          'center': {
            name: {'color': '#FF0000'},
          },
          'annotations': [
            {'id': 'a', 'text': 'A', 'hz': 14074000, 'part': name},
          ],
        }, kind: kind);
        expect((s.pan, s.waterfall), (true, false), reason: '$kind $name');
        expect(s.center!.pan!.color, const Color(0xFFFF0000));
        expect(s.annotations.single.onWaterfall, isFalse);
      }
    }
    expect(
      spec({
        'scale': {'over': 'spectrum'},
      }).scale!.over,
      'spectrum',
    );
    expect(
      spec({
        'scale': {'over': true},
      }).scale!.over,
      'waterfall',
    );
    expect(
      () => spec({
        'scale': {'over': 'pan'},
      }),
      throwsFormatException,
      reason: 'new in API 17, under the new names only',
    );
  });
}
