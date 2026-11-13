// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `spectrum` control: the host draws the radio's sweeps, and the
// radio's scope runs only while a pane that shows one is on screen.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show AppClock;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';
import '../support/fake_clock.dart';

const _mainRadio = 'radio-1';
const _subRadio = 'radio-sub';

class _Source extends ChangeNotifier implements SceneSpectrumSource {
  /// A bundle from before API 17 unless a test says otherwise: these tests
  /// are about drawing, and a click there is the control's event.
  @override
  bool nativeGestures = false;
  @override
  int? maxWidthHz(String uuid) => null;
  @override
  int? minWidthHz(String uuid) => null;
  @override
  bool canTune(String uuid) => false;
  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) => false;
  @override
  bool fitSpan(String uuid, int widthHz, {int? centerHz, int offCenterHz = 0}) => false;
  int listening = 0;
  int subListening = 0;
  String? problemText;
  late final controller = StreamController<SpectrumFrame>.broadcast(onListen: () => listening++, onCancel: () => listening--);
  late final subController = StreamController<SpectrumFrame>.broadcast(onListen: () => subListening++, onCancel: () => subListening--);

  String defaultRadio = _mainRadio;
  @override
  String? resolve(String? radio) => radio ?? defaultRadio;
  @override
  Stream<SpectrumFrame> frames(String uuid) => uuid == _subRadio ? subController.stream : controller.stream;
  @override
  String? problem(String uuid) => problemText;
  @override
  double? vfoHz(String uuid) => uuid == _subRadio ? 7074000 : 14074000;
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
  final recentered = <int>[];
  final widths = <(String, Object), int>{};
  @override
  void showWidth(String uuid, Object owner, int? widthHz) => widthHz == null ? widths.remove((uuid, owner)) : widths[(uuid, owner)] = widthHz;
  final recenteredRadios = <String>[];
  @override
  bool canRecenter(String uuid) => true;
  @override
  bool recenter(String uuid, int centerHz) {
    recentered.add(centerHz);
    recenteredRadios.add(uuid);
    return true;
  }
}

SpectrumFrame _frame([double level = 20, int lowHz = 14000000]) =>
    SpectrumFrame(lowHz: lowHz, highHz: lowHz + 100000, levels: Float32List.fromList(List.filled(100, level)), floorDb: 0, ceilingDb: 80, atMillis: 0);

Map<String, dynamic> _doc({Map<String, dynamic> spectrum = const {}}) => {
  'version': 1,
  'width': 400,
  'height': 20,
  'values': {'hz': 0, 'db': 0, 'floor': 0, 'avg': 0},
  'layers': [
    {
      'id': 'readout',
      'x': 0,
      'y': 0,
      'width': 400,
      'height': 20,
      'text': {'value': 'hz', 'decimals': 0},
    },
    {
      'id': 'level',
      'x': 0,
      'y': 0,
      'width': 400,
      'height': 20,
      'text': {'value': 'db', 'decimals': 1, 'suffix': ' dB'},
    },
  ],
  'controls': [
    {'id': 'pan', 'kind': 'spectrum', 'label': 'Panadapter', 'event': 'tune', 'hoverHz': 'hz', 'hoverDb': 'db', 'floor': 'floor', ...spectrum},
  ],
  'layout': {
    'column': [
      {'control': 'pan', 'flex': 1},
      {'scene': true, 'height': 20},
    ],
    'crossAxisAlignment': 'stretch',
  },
};

Future<void> _show(
  WidgetTester tester, {
  SceneSpectrumSource? source,
  bool visible = true,
  SceneEventHandler? onEvent,
  Map<String, dynamic> spectrum = const {},
  Map<String, dynamic>? document,
  Size size = const Size(400, 300),
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: DockPaneVisibility(
              visible: visible,
              child: PanelSceneView(
                scene: PanelScene(document ?? _doc(spectrum: spectrum)),
                onEvent: onEvent,
                spectrum: source,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _spectrum(String id) => find.byWidgetPredicate((widget) => widget is SceneSpectrumView && widget.control.id == id);

/// The panadapter's painter: its `sweep()` is the bins the trace draws.
dynamic _trace(WidgetTester tester, String id) => tester
    .widgetList<CustomPaint>(find.descendant(of: _spectrum(id), matching: find.byType(CustomPaint)))
    .map((paint) => paint.painter)
    .firstWhere((painter) => painter.runtimeType.toString() == '_PanPainter');

dynamic _waterfall(WidgetTester tester, String id) => tester
    .widgetList<CustomPaint>(find.descendant(of: _spectrum(id), matching: find.byType(CustomPaint)))
    .map((widget) => widget.painter)
    .singleWhere((painter) => painter.runtimeType.toString() == '_WaterfallPainter');

Future<void> _waitForRows(WidgetTester tester, String id, int count) async {
  final rows = _waterfall(tester, id).rows as List;
  await tester.runAsync(() async {
    final elapsed = Stopwatch()..start();
    while (rows.length < count && elapsed.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(rows, hasLength(count), reason: 'native row rasterization must finish before inspecting retained history');
  });
  await tester.pump();
}

Map<String, dynamic> _dualDoc(String view) {
  final document = _doc();
  document['controls'] = [
    for (final channel in ['main', 'sub']) ...[
      if (view == 'both' || view == channel) {'id': '$channel-heading', 'kind': 'nativeText', 'label': channel},
      {
        'id': '$channel-pan',
        'kind': 'spectrum',
        'label': channel,
        'radio': channel == 'main' ? _mainRadio : _subRadio,
        'event': '$channel:tune',
        'opacity': view == 'both' || view == channel ? 1 : 0,
      },
    ],
  ];
  document['layout'] = {
    'column': [
      for (final channel in ['main', 'sub'])
        {
          'column': [
            if (view == 'both' || view == channel) {'control': '$channel-heading', 'height': 20},
            {'control': '$channel-pan', 'flex': 1},
          ],
          if (view == 'both' || view == channel) 'flex': 1 else 'height': 0,
          'crossAxisAlignment': 'stretch',
        },
      {'scene': true, 'height': 20},
    ],
    'crossAxisAlignment': 'stretch',
  };
  return document;
}

// The band scope panel's compact Both toolbar. Its TypeScript contract tests keep the
// controls and dimensions in sync; this exercises their native Flutter layout.
Map<String, dynamic> _compactBothDoc() => {
  'version': 1,
  'width': 600,
  'height': 48,
  'values': {
    for (final channel in ['main', 'sub']) '$channel-ref': 0,
  },
  'strings': {
    'channels': 'both',
    for (final channel in ['main', 'sub']) '$channel-span': '100000',
  },
  'layers': [
    for (final (index, channel) in ['main', 'sub'].indexed)
      {
        'id': '$channel-readout',
        'x': 0,
        'y': index * 24,
        'width': 600,
        'height': 24,
        'text': {'literal': channel, 'size': 14},
      },
  ],
  'controls': [
    {
      'id': 'channels',
      'kind': 'nativeSegmented',
      'label': 'Receiver',
      'value': 'channels',
      'event': 'channels',
      'options': [
        {'label': 'Main', 'value': 'main'},
        {'label': 'Sub', 'value': 'sub'},
        {'label': 'Both', 'value': 'both'},
      ],
    },
    for (final channel in ['main', 'sub']) ...[
      {'id': '$channel-heading', 'kind': 'nativeText', 'label': channel == 'main' ? 'Main' : 'Sub'},
      {
        'id': '$channel-span',
        'kind': 'nativeDropdown',
        'label': '$channel span',
        'value': '$channel-span',
        'event': '$channel:span',
        'options': [
          {'label': '±50 kHz', 'value': '50000'},
          {'label': '±100 kHz', 'value': '100000'},
        ],
      },
      {'id': '$channel-label-Ref', 'kind': 'nativeText', 'label': 'Ref'},
      {
        'id': '$channel-ref',
        'kind': 'nativeSlider',
        'label': '$channel reference level',
        'value': '$channel-ref',
        'event': '$channel:ref',
        'min': -30,
        'max': 30,
        'step': 1,
      },
      {
        'id': '$channel-pan',
        'kind': 'spectrum',
        'label': '$channel panadapter',
        'radio': channel == 'main' ? _mainRadio : _subRadio,
        'scale': {'gap': 26},
      },
    ],
  ],
  'layout': {
    'column': [
      {'control': 'channels'},
      for (final channel in ['main', 'sub'])
        {
          'column': [
            {
              'wrap': [
                {'control': '$channel-heading'},
                {'control': '$channel-span', 'width': 120},
                {
                  'wrap': [
                    {'control': '$channel-label-Ref'},
                    {'control': '$channel-ref', 'width': 120},
                  ],
                  'spacing': 4,
                  'crossAxisAlignment': 'center',
                },
              ],
              'spacing': 8,
              'runSpacing': 4,
              'padding': 4,
            },
            {'control': '$channel-pan', 'flex': 1},
          ],
          'flex': 1,
          'crossAxisAlignment': 'stretch',
        },
      {'scene': true, 'height': 48},
    ],
    'crossAxisAlignment': 'stretch',
  },
};

void main() {
  group('the document', () {
    test('a spectrum is laid out without a rect, like a native control', () {
      expect(PanelScene(_doc()).controlsById['pan']!.spectrum!.hoverHz, 'hz');
    });

    test('a spectrum names one logical radio and has no separate channel selector', () {
      expect(PanelScene(_doc()).controlsById['pan']!.spectrum!.radio, isNull);
      expect(PanelScene(_doc(spectrum: {'radio': _subRadio})).controlsById['pan']!.spectrum!.radio, _subRadio);
      // Unknown fields stay forward-compatible; only the radio ID selects a source.
      expect(PanelScene(_doc(spectrum: {'radio': _subRadio, 'channel': 'sub'})).controlsById['pan']!.spectrum!.radio, _subRadio);
    });

    test('is refused for a value the spectrum names but the scene lacks', () {
      expect(() => PanelScene(_doc(spectrum: {'hoverDb': 'missing'})), throwsFormatException);
    });

    test('colors are #RRGGBB or #AARRGGBB, and a waterfall takes 2 to 8 of them', () {
      final spec = PanelScene(
        _doc(
          spectrum: {
            'traceColor': '#80FF0000',
            'waterfallColors': ['#000000', '#FFFFFF'],
          },
        ),
      ).controlsById['pan']!.spectrum!;
      expect(spec.trace.color, const Color(0x80FF0000));
      expect(() => PanelScene(_doc(spectrum: {'fillColor': 'red'})), throwsFormatException);
      expect(
        () => PanelScene(
          _doc(
            spectrum: {
              'waterfallColors': ['#000000'],
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('a number is a literal or names a value the scene has', () {
      final spec = PanelScene(_doc(spectrum: {'average': 'avg', 'fps': 30})).controlsById['pan']!.spectrum!;
      expect((spec.average!.value, spec.fps!.literal), ('avg', 30.0));
      expect(() => PanelScene(_doc(spectrum: {'fps': 'missing'})), throwsFormatException);
      expect(() => PanelScene(_doc(spectrum: {'fps': 600})), throwsFormatException);
    });

    test('an overlay is a line at one offset or an area between two, drawn on a part it styles', () {
      final spec = PanelScene(
        _doc(
          spectrum: {
            'overlays': [
              {
                'from': 100,
                'to': 2800,
                'pan': {'fill': '#262EC5F0'},
              },
              {
                'at': 'floor',
                'waterfall': {'color': '#FF0000', 'width': 2},
              },
            ],
          },
        ),
      ).controlsById['pan']!.spectrum!;
      expect((spec.overlays[0].from!.literal, spec.overlays[0].waterfall), (100.0, null));
      expect(spec.overlays[1].at!.value, 'floor');
      void refused(Map<String, dynamic> overlay, String why) => expect(
        () => PanelScene(
          _doc(
            spectrum: {
              'overlays': [overlay],
            },
          ),
        ),
        throwsFormatException,
        reason: why,
      );
      refused({
        'from': 100,
        'pan': {'fill': '#000000'},
      }, 'half an area');
      refused({
        'at': 0,
        'from': 1,
        'to': 2,
        'pan': {'fill': '#000000'},
      }, 'a line and an area at once');
      refused({'at': 0}, 'no part to draw on');
      refused({
        'at': 'missing',
        'pan': {'color': '#000000'},
      }, 'an offset naming a value the scene lacks');
    });

    test('an absolute overlay is scenery behind the trace unless it says otherwise', () {
      final spec = PanelScene(
        _doc(
          spectrum: {
            'overlays': [
              {
                'at': 14000000,
                'anchor': 'absolute',
                'pan': {'color': '#FF0000', 'width': 3},
              },
              {
                'from': 13900000,
                'to': 14000000,
                'anchor': 'absolute',
                'behind': false,
                'waterfall': {'fill': '#40FF0000'},
              },
              {
                'at': -700,
                'pan': {'color': '#FF0000'},
              },
            ],
          },
        ),
      ).controlsById['pan']!.spectrum!;
      expect(
        [for (final o in spec.overlays) (o.anchor, o.behind)],
        [(SceneSpectrumAnchor.absolute, true), (SceneSpectrumAnchor.absolute, false), (SceneSpectrumAnchor.vfo, false)],
      );
    });

    test('a scale on its own leaves a gap with centered labels and no ticks', () {
      final scale = PanelScene(_doc(spectrum: {'scale': true})).controlsById['pan']!.spectrum!.scale!;
      expect((scale.gap, scale.labels?.offset, scale.ticks), (null, null, null));
      expect(
        PanelScene(
          _doc(
            spectrum: {
              'scale': {'labels': false, 'ticks': true},
            },
          ),
        ).controlsById['pan']!.spectrum!.scale!.labels,
        isNull,
      );
      expect(
        () => PanelScene(
          _doc(
            spectrum: {
              'scale': {
                'labels': {'offset': 'missing'},
              },
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('annotations need a frequency and an id of their own', () {
      expect(
        () => PanelScene(
          _doc(
            spectrum: {
              'annotations': [
                {'id': 'a', 'text': 'A'},
              ],
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => PanelScene(
          _doc(
            spectrum: {
              'annotations': [
                {'id': 'a', 'text': 'A', 'hz': 1},
                {'id': 'a', 'text': 'B', 'hz': 2},
              ],
            },
          ),
        ),
        throwsFormatException,
        reason: 'the click names which one, so two of one name would be the same click',
      );
    });

    test('an annotation points at its frequency unless told not to', () {
      SceneSpectrumAnnotation only(Object? pointer) => PanelScene(
        _doc(
          spectrum: {
            'annotations': [
              {'id': 'a', 'text': 'A', 'hz': 1, 'pointer': ?pointer},
            ],
          },
        ),
      ).controlsById['pan']!.spectrum!.annotations.single;
      expect(only(null).pointer, isNotNull);
      expect(only(false).pointer, isNull);
      expect(only({'show': false}).pointer, isNull);
      expect(only({'size': 6, 'corner': 'top'}).pointer!.corner, 'top');
      expect(() => only({'corner': 'left'}), throwsFormatException);
    });

    test("an annotation's icon is a name and a color that may be see-through, as the text's may", () {
      SceneSpectrumAnnotation only(Object? icon) => PanelScene(
        _doc(
          spectrum: {
            'annotations': [
              {'id': 'a', 'text': 'A', 'hz': 1, 'icon': ?icon},
            ],
          },
        ),
      ).controlsById['pan']!.spectrum!.annotations.single;
      expect(only(null).icon, isNull);
      expect(only({'name': 'pine-tree'}).icon, (name: 'pine-tree', color: null));
      // A fading spot fades its icon with its call.
      expect(only({'name': 'pine-tree', 'color': '#802E7D32'}).icon!.color, const Color(0x802E7D32));
      expect(() => only('pine-tree'), throwsFormatException);
      expect(() => only({'color': '#2E7D32'}), throwsFormatException);
    });

    test("an annotation's border goes all around unless it asks for only the edge facing its part's", () {
      SceneSpectrumAnnotation only(String? edges) => PanelScene(
        _doc(
          spectrum: {
            'annotations': [
              {'id': 'a', 'text': 'A', 'hz': 1, 'borderColor': '#FFFFFF', 'borderEdges': ?edges},
            ],
          },
        ),
      ).controlsById['pan']!.spectrum!.annotations.single;
      expect([only(null).borderNear, only('all').borderNear, only('near').borderNear], [false, false, true]);
      expect(() => only('bottom'), throwsFormatException, reason: 'the edge depends on the part, which the flow may turn');
    });

    test('a center with no parts, or false, is no tuned-frequency line', () {
      for (final center in [<String, dynamic>{}, false]) {
        final mark = PanelScene(_doc(spectrum: {'center': center})).controlsById['pan']!.spectrum!.center!;
        expect((mark.pan, mark.waterfall), (null, null));
      }
    });

    test('a number bound to a value is held to the limits a literal is checked against', () {
      final range = PanelScene(_doc(spectrum: {'range': 'floor'})).controlsById['pan']!.spectrum!.range!;
      // 0 would be a display height the painters divide by.
      expect(range.resolve({'floor': 0}), 1);
      expect(range.resolve({'floor': 500}), 200);
    });

    test('the axis\'s labels align by their start, center or end, its ticks by their start or end; nothing else', () {
      SceneSpectrumScale scale(Map<String, dynamic> json) => PanelScene(_doc(spectrum: {'scale': json})).controlsById['pan']!.spectrum!.scale!;
      expect(scale(const {}).labels!.align, isNull, reason: 'the gap\'s middle, or the top at an offset');
      for (final align in ['start', 'center', 'end']) {
        expect(
          scale({
            'labels': {'align': align},
          }).labels!.align,
          align,
        );
      }
      for (final align in ['start', 'end']) {
        expect(
          scale({
            'ticks': {'align': align},
          }).ticks!.align,
          align,
        );
      }
      expect(scale({'ticks': true}).ticks!.align, isNull, reason: 'growing toward the waterfall');
      expect(
        () => scale({
          'labels': {'align': 'middle'},
        }),
        throwsFormatException,
      );
      expect(
        () => scale({
          'ticks': {'align': 'center'},
        }),
        throwsFormatException,
        reason: 'a tick has two ends, no middle to stand on',
      );
    });

    test('a centerHz is a frequency in Hz, or none', () {
      expect(SceneSpectrumSpec(const {}).centerHz, isNull);
      expect(SceneSpectrumSpec(const {'centerHz': 14074000}).centerHz, 14074000);
      expect(() => SceneSpectrumSpec(const {'centerHz': -1}), throwsFormatException);
      expect(() => SceneSpectrumSpec(const {'centerHz': '14074000'}), throwsFormatException);
    });

    test('an annotation\'s baseline, stretch, padding, badge, more and collapsed width are checked as it loads', () {
      SceneSpectrumAnnotation annotation(Map<String, dynamic> json) => SceneSpectrumAnnotation({'id': 'a', 'text': 'K1ABC', 'hz': 14074000, ...json});
      expect(annotation(const {}).baseline, isFalse);
      expect(annotation(const {'baseline': true}).baseline, isTrue);
      expect((annotation(const {'secondaryEvent': 'forget'}).secondaryEvent, annotation(const {}).secondaryEvent), ('forget', null));
      expect(() => annotation(const {'secondaryEvent': 3}), throwsFormatException);
      expect(() => annotation(const {'baseline': 'yes'}), throwsFormatException);

      final stretch = annotation(const {
        'stretch': {'from': -1500, 'to': 1500},
      }).stretch!;
      expect((stretch.from.literal, stretch.to.literal), (-1500, 1500));
      expect(
        () => annotation(const {
          'stretch': {'from': -1500},
        }),
        throwsFormatException,
        reason: 'a passband has two edges',
      );
      expect(() => annotation(const {'stretch': 3000}), throwsFormatException);

      final even = annotation(const {'padding': 4});
      expect((even.padding!.literal, even.paddingY!.literal), (4, 4));
      final apart = annotation(const {
        'padding': {'x': 6, 'y': 1},
      });
      expect((apart.padding!.literal, apart.paddingY!.literal), (6, 1));
      final across = annotation(const {
        'padding': {'x': 6},
      });
      expect((across.padding!.literal, across.paddingY), (6, null), reason: 'the default above and below');
      // Named values, as every other number of a spectrum's: one the scene does not have refuses it at load.
      final named = annotation(const {
        'padding': {'x': 2, 'y': 'tall'},
        'stretch': {'from': 'low', 'to': 'high'},
        'openBorder': {'color': '#FF000000', 'width': 'edge'},
      });
      expect(named.valueNames, containsAll(['tall', 'low', 'high', 'edge']));
      expect(
        () => annotation(const {
          'padding': {'x': 41},
        }),
        throwsFormatException,
      );

      final badge = annotation(const {
        'badge': {'text': '3', 'color': '#FFFFFF', 'background': '#FF0000'},
      }).badge!;
      expect((badge.text, badge.color, badge.background), ('3', const Color(0xFFFFFFFF), const Color(0xFFFF0000)));
      expect(
        annotation(const {
          'badge': {'text': '+2'},
        }).badge!.background,
        isNull,
        reason: 'the app\'s own pill',
      );
      expect(() => annotation(const {'badge': '3'}), throwsFormatException);

      final more = annotation(const {
        'more': [
          'W1OLD',
          {
            'text': 'N2XYZ',
            'icon': {'name': 'pine-tree'},
          },
        ],
      }).more!;
      expect([for (final line in more) (line.text, line.icon?.name)], [('W1OLD', null), ('N2XYZ', 'pine-tree')]);
      expect(() => annotation({'more': List.filled(33, 'K1ABC')}), throwsFormatException, reason: 'up to 32 lines');
      expect(
        () => annotation(const {
          'more': [42],
        }),
        throwsFormatException,
      );

      final box = annotation(const {
        'collapsed': {'width': 'box'},
      });
      expect((box.collapsed, box.collapsedBox, box.collapsedWidth), (true, true, null));
      final pixels = annotation(const {
        'collapsed': {'width': 30},
      });
      expect((pixels.collapsed, pixels.collapsedBox, pixels.collapsedWidth), (true, false, 30));
      expect(
        () => annotation(const {
          'collapsed': {'width': 'half'},
        }),
        throwsFormatException,
      );
    });

    test("is refused for a spectrum's fields on another kind of control", () {
      final doc = _doc();
      (doc['controls'] as List).add({'id': 'b', 'kind': 'nativeButton', 'label': 'B', 'event': 'b', 'palette': 'heat'});
      (doc['layout']['column'] as List).add({'control': 'b'});
      expect(() => PanelScene(doc), throwsFormatException);
    });
  });

  testWidgets('the radio streams only while the pane is seen', (tester) async {
    final source = _Source();
    // A pane behind another dock tab stays mounted; were it to subscribe, the
    // radio would stream its scope for a display nobody can see.
    await _show(tester, source: source, visible: false);
    expect(source.listening, 0);
    await _show(tester, source: source, visible: true);
    expect(source.listening, 1);
    await _show(tester, source: source, visible: false);
    expect(source.listening, 0);
  });

  testWidgets('main and sub retain separate histories across single and dual layouts', (tester) async {
    final source = _Source();
    await _show(tester, source: source, document: _dualDoc('both'));
    final mainState = tester.state(_spectrum('main-pan'));
    final subState = tester.state(_spectrum('sub-pan'));
    expect((source.listening, source.subListening), (1, 1));
    source.controller.add(_frame(20));
    source.subController.add(_frame(60, 7000000));
    await tester.pump();
    await _waitForRows(tester, 'main-pan', 1);
    await _waitForRows(tester, 'sub-pan', 1);

    await _show(tester, source: source, document: _dualDoc('sub'));
    expect(tester.takeException(), isNull, reason: 'a hidden receiver must not overflow its zero-height slot');
    expect((source.listening, source.subListening), (0, 1));
    expect(tester.state(_spectrum('main-pan')), same(mainState));
    expect(tester.state(_spectrum('sub-pan')), same(subState));
    source.controller.add(_frame(100));
    source.subController.add(_frame(80, 7000000));
    await tester.pump();
    await _waitForRows(tester, 'sub-pan', 2);
    expect(_waterfall(tester, 'main-pan').rows, hasLength(1));

    await _show(tester, source: source, document: _dualDoc('main'));
    expect((source.listening, source.subListening), (1, 0));
    expect(tester.state(_spectrum('main-pan')), same(mainState));
    source.controller.add(_frame(40));
    await tester.pump();
    await _waitForRows(tester, 'main-pan', 2);
    expect((_trace(tester, 'main-pan').sweep() as SpectrumFrame).levels.first, 32);
    expect((_trace(tester, 'sub-pan').sweep() as SpectrumFrame).levels.first, 72);
    expect((_waterfall(tester, 'main-pan').frame() as SpectrumFrame).lowHz, 14000000);
    expect((_waterfall(tester, 'sub-pan').frame() as SpectrumFrame).lowHz, 7000000);

    await _show(tester, source: source, document: _dualDoc('both'));
    expect((source.listening, source.subListening), (1, 1));
    expect(tester.state(_spectrum('main-pan')), same(mainState));
    expect(tester.state(_spectrum('sub-pan')), same(subState));
    expect(_waterfall(tester, 'main-pan').rows, hasLength(2));
    expect(_waterfall(tester, 'sub-pan').rows, hasLength(2));
  });

  testWidgets('compact Both keeps two drawable receivers on a narrow phone', (tester) async {
    const size = Size(360, 640);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _Source();
    await _show(tester, source: source, document: _compactBothDoc(), size: size);
    expect((source.listening, source.subListening), (1, 1));
    source.controller.add(_frame(20));
    source.subController.add(_frame(60, 7000000));
    await tester.pump();
    await _waitForRows(tester, 'main-pan', 1);
    await _waitForRows(tester, 'sub-pan', 1);

    expect(tester.takeException(), isNull, reason: 'both compact toolbars must fit without a RenderFlex overflow');
    for (final channel in ['main', 'sub']) {
      final spectrum = _spectrum('$channel-pan');
      expect(tester.getSize(spectrum).height, greaterThan(120), reason: '$channel needs room for its trace and waterfall');
      for (final painter in ['_PanPainter', '_WaterfallPainter']) {
        final painted = find.descendant(
          of: spectrum,
          matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == painter),
        );
        expect(painted, findsOneWidget);
        expect(tester.getSize(painted).width, 360);
        expect(tester.getSize(painted).height, greaterThan(40), reason: '$channel $painter must retain visible paint area');
      }
    }
    expect(tester.getRect(_spectrum('main-pan')).bottom, lessThan(tester.getRect(_spectrum('sub-pan')).top));
  });

  testWidgets('changing a control radio or source cannot mix traces or waterfall rows', (tester) async {
    final source = _Source();
    await _show(tester, source: source);
    source.controller.add(_frame(20));
    await tester.pump();
    await _waitForRows(tester, 'pan', 1);
    // A row may still be rasterizing when this control changes identity.
    source.controller.add(_frame(30));
    await tester.pump();
    await _show(tester, source: source, spectrum: {'radio': _subRadio});
    expect((source.listening, source.subListening), (0, 1));
    expect(_waterfall(tester, 'pan').rows, isEmpty);
    expect(_waterfall(tester, 'pan').frame(), isNull);
    source.subController.add(_frame(60));
    await tester.pump();
    await _waitForRows(tester, 'pan', 1);
    expect((_trace(tester, 'pan').sweep() as SpectrumFrame).levels.first, 60);

    await _show(tester, source: source, spectrum: {'radio': 'radio-2'});
    expect(_waterfall(tester, 'pan').rows, isEmpty);
    expect(_waterfall(tester, 'pan').frame(), isNull);
    source.controller.add(_frame(80));
    await tester.pump();
    await _waitForRows(tester, 'pan', 1);
    final replacement = _Source();
    await _show(tester, source: replacement, spectrum: {'radio': 'radio-2'});
    expect((source.listening, source.subListening), (0, 0));
    expect(replacement.listening, 1);
    expect(_waterfall(tester, 'pan').rows, isEmpty);
    expect(_waterfall(tester, 'pan').frame(), isNull);
  });

  testWidgets('a changed designated radio clears its old trace and waterfall', (tester) async {
    final source = _Source();
    await _show(tester, source: source);
    source.controller.add(_frame(20));
    await tester.pump();
    await _waitForRows(tester, 'pan', 1);

    source.defaultRadio = _subRadio;
    source.notifyListeners();
    await tester.pump();
    expect((source.listening, source.subListening), (0, 1));
    expect(_waterfall(tester, 'pan').rows, isEmpty);
    expect(_waterfall(tester, 'pan').frame(), isNull);
    source.subController.add(_frame(60, 7000000));
    await tester.pump();
    await _waitForRows(tester, 'pan', 1);
    expect((_waterfall(tester, 'pan').frame() as SpectrumFrame).lowHz, 7000000);
  });

  testWidgets('each logical radio uses its own VFO marker, follow and tuning event', (tester) async {
    final source = _Source();
    final events = <Map<String, dynamic>>[];
    final document = _dualDoc('both');
    for (final control in document['controls'] as List) {
      if (control['kind'] == 'spectrum') control['follow'] = .15;
    }
    await _show(
      tester,
      source: source,
      document: document,
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    source.controller.add(_frame(20, 14080000));
    source.subController.add(_frame(60, 7080000));
    await tester.pump();
    expect(source.recenteredRadios, [_mainRadio, _subRadio]);
    expect(source.recentered, [14109000, 7109000]);
    expect(_waterfall(tester, 'main-pan').marks.vfoHz(), 14074000);
    expect(_waterfall(tester, 'sub-pan').marks.vfoHz(), 7074000);
    for (final receiver in ['main', 'sub']) {
      await tester.tapAt(tester.getRect(_spectrum('$receiver-pan')).center);
      await tester.pump();
    }
    expect(events.map((event) => event['action']), ['main:tune', 'sub:tune']);
    expect(events.map((event) => event['value']), [14130000, 7130000]);
  });

  testWidgets('a click sends the frequency under it as a commit', (tester) async {
    final source = _Source();
    final events = <Map<String, dynamic>>[];
    await _show(
      tester,
      source: source,
      onEvent: (e) async {
        events.add(e);
        return {};
      },
    );
    source.controller.add(_frame());
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
    await tester.pump();
    expect(events.single['action'], 'tune');
    expect(events.single['phase'], 'commit');
    expect(events.single['value'] as double, closeTo(14025000, 500));
  });

  testWidgets('the control writes the width it shows, a click\'s step and the dial for text layers, as they change', (tester) async {
    final source = _Source()..nativeGestures = true;
    var calls = 0;
    Future<void> show(Map<String, dynamic> spectrum) async {
      await _show(
        tester,
        source: source,
        spectrum: {'hoverHz': null, 'hoverDb': null, ...spectrum},
        onEvent: (e) async {
          calls++;
          return {};
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      // The sweep is drawn on the first; the values it wrote, on the next.
      await tester.pump();
    }

    await show(const {'widthHz': 'hz', 'stepHz': 'db'});
    // The whole sweep before any zoom, 250 Hz a pixel across 400: a click lands on twice the 500 that covers one.
    expect(find.text('100000'), findsOneWidget);
    expect(find.text('1000.0 dB'), findsOneWidget);
    // A narrower span is a narrower window: the readouts follow what is drawn, not what the radio sweeps.
    await show(const {'widthHz': 'hz', 'stepHz': 'db', 'span': 50000});
    expect(find.text('50000'), findsOneWidget);
    expect(find.text('500.0 dB'), findsOneWidget);
    await show(const {'vfoHz': 'hz'});
    expect(find.text('14074000'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('the pointer writes the frequency under it for a text layer, without the extension', (tester) async {
    final source = _Source();
    var calls = 0;
    await _show(
      tester,
      source: source,
      onEvent: (e) async {
        calls++;
        return {};
      },
    );
    source.controller.add(_frame());
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(box.left + box.width / 2, box.center.dy));
    await mouse.moveTo(Offset(box.left + box.width / 2 + 1, box.center.dy));
    await tester.pump();
    expect(find.text('14050250'), findsOneWidget);
    expect(calls, 0);
    await mouse.removePointer();
  });

  test('a display width shows the middle of each sweep, and never widens one the app cannot move', () {
    // A radio's scope comes in a few widths; the display shows any narrower.
    final sweep = _frame(20, 14000000);
    expect(spectrumWindow(sweep, 50000), (14025000, 14075000));
    expect(spectrumWindow(sweep, 200000), (14000000, 14100000));
    expect(spectrumWindow(sweep, null), (14000000, 14100000));
    // Not whole bins: a window that moved by a bin at a time would pan in steps.
    expect(spectrumWindow(sweep, 50000, centerHz: 14050333), (14025333, 14075333));
    // On a scope that stays put, its middle held within the sweep, the rest past it; anywhere where
    // the scope follows. Stopped at the edge, nothing past a scope held on the dial could be seen.
    expect(spectrumWindow(sweep, 50000, centerHz: 14090000), (14065000, 14115000));
    expect(spectrumWindow(sweep, 50000, centerHz: 14130000), (14075000, 14125000));
    expect(spectrumWindow(sweep, 50000, centerHz: 14090000, held: false), (14065000, 14115000));
    // A scene's own widest lets a window run past a scope that stays put, holding the sweep inside it
    // instead: the live part never leaves the picture.
    expect(spectrumWindow(sweep, 300000, widestHz: 200000), (13950000, 14150000));
    expect(spectrumWindow(sweep, 200000, centerHz: 14300000, widestHz: 400000), (14000000, 14200000));
    expect(spectrumWindow(sweep, 200000, centerHz: 14080000, widestHz: 400000), (13980000, 14180000));
  });

  test('the dial label\'s arrow takes a color and a size, or false for none', () {
    final styled = SceneSpectrumVfoLabel({
      'arrow': {'color': '#FF0000', 'size': 12},
    });
    expect((styled.arrowColor, styled.noArrow), (const Color(0xFFFF0000), false));
    expect(SceneSpectrumVfoLabel({'arrow': false}).noArrow, isTrue);
    expect(() => SceneSpectrumVfoLabel({'arrow': 'left'}), throwsFormatException);
  });

  test('a spectrum\'s zoom limits are a number of Hz or the radio\'s own', () {
    SceneSpectrumSpec spec(Map<String, dynamic> extra) => SceneSpectrumSpec({'id': 'pan', 'kind': 'spectrum', ...extra});
    expect((spec({}).minWidthHz, spec({}).maxWidthHz), (null, null));
    final own = spec({'minWidthHz': 1000, 'maxWidthHz': 'radio'});
    expect((own.minWidthHz, own.maxWidthHz), (1000, null));
    expect(() => spec({'maxWidthHz': 'band'}), throwsFormatException);
    expect(() => spec({'minWidthHz': 0}), throwsFormatException);
  });

  test('short ticks mark every 1 kHz on a wide window and every 100 Hz once labels are a kHz apart, never a solid bar', () {
    // 100 kHz on 400 pixels, labels every 10 kHz: 1 kHz is 4 pixels, 100 Hz under one.
    expect(spectrumMinorTick(100000, 400, 10000), 1000);
    // 10 kHz on 400, labels every 1 kHz: 100 Hz is 4 pixels.
    expect(spectrumMinorTick(10000, 400, 1000), 100);
    // 10 kHz on 800 but labelled every 2 kHz: 100 Hz would fit, but waits for kHz labels.
    expect(spectrumMinorTick(10000, 800, 2000), 1000);
    // 200 kHz on 400: even the kHz is 2 pixels.
    expect(spectrumMinorTick(200000, 400, 20000), isNull);
    // Labelled every 100 Hz already: nothing finer to add.
    expect(spectrumMinorTick(2000, 400, 100), isNull);
  });

  test('the dial is labelled with the Hz it has, over the passband the scene draws', () {
    expect(spectrumVfoLabel(14074000), '14.074');
    expect(spectrumVfoLabel(14074500), '14.0745');
    expect(spectrumVfoLabel(14074250), '14.07425');
    // Zeros where more are asked for; fewer cut, not rounded: 14.0743 would be a frequency the dial is not on.
    expect(spectrumVfoLabel(14074000, 2), '14.07400');
    expect(spectrumVfoLabel(14074250, 1), '14.0742');
    expect(spectrumVfoLabel(7074000), '7.074');
    expect(spectrumVfoLabel(144174000, 1), '144.1740');
    expect([14074000, 14074500, 14074250, 14074255].map((hz) => spectrumVfoDigits(hz.toDouble())), [0, 1, 2, 3]);
    double? number(SceneNumber? n) => n?.literal;
    int side(List<Map<String, dynamic>> overlays) => spectrumPassbandSide(
      SceneSpectrumSpec({
        'overlays': [
          for (final o in overlays)
            {
              ...o,
              'pan': const {'fill': '#40FFFFFF'},
            },
        ],
      }),
      number,
    );
    expect(
      side([
        {'from': 100, 'to': 2800},
      ]),
      1,
      reason: 'upper sideband: the label goes on the high side of the line, over the passband',
    );
    expect(
      side([
        {'from': -2800, 'to': -100},
      ]),
      -1,
    );
    expect(
      side([
        {'from': -250, 'to': 250},
      ]),
      0,
      reason: 'CW straddles the dial: centred',
    );
    expect(
      side([
        {'from': 14000000, 'to': 14150000, 'anchor': 'absolute'},
      ]),
      0,
      reason: 'a band edge is not a passband',
    );
  });

  test('axis labels read like every other frequency in the app: MHz bold, kHz plain, Hz smaller', () {
    const style = TextStyle(fontSize: 10);
    List<(String, FontWeight?, double?)> parts(String mhz) => [
      for (final span in (spectrumAxisLabel(mhz, style) as TextSpan).children!.cast<TextSpan>()) (span.text!, span.style?.fontWeight, span.style?.fontSize),
    ];
    expect(parts('14.0505'), [('14', FontWeight.w700, 10), ('.050', null, null), ('.', null, null), ('5', null, 8)]);
    expect(parts('14.050'), [('14', FontWeight.w700, 10), ('.050', null, null)]);
    // Below 1 MHz the kHz is the reading, as on the radio panel: no bold 0.
    expect(parts('0.472'), [('472', FontWeight.w700, 10)]);
  });

  test('the dial\'s label is bold MHz and light kHz and Hz by default, each part styled from the one before', () {
    double? number(SceneNumber? n) => n?.literal;
    const base = TextStyle(fontSize: 20, color: Color(0xFFFF0000));
    (FontWeight?, double?, Color?, FontStyle?, String?) look(TextStyle s) => (s.fontWeight, s.fontSize, s.color, s.fontStyle, s.fontFamily);
    var (mhz, khz, hz) = spectrumVfoLabelStyles(base, SceneSpectrumSpec(const {}).vfoLabel, number);
    expect(
      [look(mhz), look(khz), look(hz)],
      [
        (FontWeight.w700, 20, const Color(0xFFFF0000), null, null),
        (FontWeight.w300, 20, const Color(0xFFFF0000), null, null),
        (FontWeight.w300, 16, const Color(0xFFFF0000), null, null),
      ],
    );
    // Named once, on the MHz, a size or a font is the whole label's; the weight is the one thing
    // the kHz does not take from it, or naming a bold MHz would turn the kHz bold too.
    (mhz, khz, hz) = spectrumVfoLabelStyles(
      base,
      SceneSpectrumSpec(const {
        'vfoLabel': {
          'mhz': {'size': 30, 'weight': 900, 'fontFamily': 'RobotoMono', 'italic': true},
          'khz': {'weight': 500},
          'hz': {'color': '#00FF00', 'italic': false},
        },
      }).vfoLabel,
      number,
    );
    expect(
      [look(mhz), look(khz), look(hz)],
      [
        (FontWeight.w900, 30, const Color(0xFFFF0000), FontStyle.italic, 'RobotoMono'),
        (FontWeight.w500, 30, const Color(0xFFFF0000), FontStyle.italic, 'RobotoMono'),
        (FontWeight.w500, 24, const Color(0xFF00FF00), FontStyle.normal, 'RobotoMono'),
      ],
    );
  });

  test('the dial\'s label sets its MHz, kHz and Hz in their own styles', () {
    const mhz = TextStyle(fontSize: 1), khz = TextStyle(fontSize: 2), hz = TextStyle(fontSize: 3);
    List<(String, double?)> parts(String label) => [
      for (final span in (spectrumVfoLabelSpan(label, mhz, khz, hz) as TextSpan).children!.cast<TextSpan>()) (span.text!, span.style?.fontSize),
    ];
    // The marks have no style of their own: the kHz's, the label's root.
    expect((spectrumVfoLabelSpan('14.074', mhz, khz, hz) as TextSpan).style, khz);
    expect(parts('14.07425'), [('14', 1), ('.074', null), ('.', null), ('25', 3)]);
    expect(parts('14.074'), [('14', 1), ('.074', null)]);
    expect(parts('0.47250'), [('472', 1), ('.', null), ('50', 3)]);
  });

  test('a scene\'s vfoLabel settings are checked as it loads', () {
    SceneSpectrumVfoLabel label(Object? raw) => SceneSpectrumSpec({'vfoLabel': raw}).vfoLabel;
    expect(label(null).hzDigits, isNull);
    expect(label(const {'hzDigits': 'auto'}).hzDigits, isNull);
    expect(label(const {'hzDigits': 0}).hzDigits, 0);
    expect(label(const {'hzDigits': 3}).hzDigits, 3);
    expect(SceneSpectrumSpec(const {'vfoLabel': false}).noVfoLabel, isTrue);
    for (final bad in [
      {'hzDigits': 4},
      {'hzDigits': 1.5},
      {'hzDigits': 'some'},
      {'mhz': 'bold'},
      {
        'khz': {'weight': 1000},
      },
      {
        'hz': {'italic': 'yes'},
      },
    ]) {
      expect(() => label(bad), throwsFormatException, reason: '$bad');
    }
    expect(() => label('big'), throwsFormatException);
    // A named size is a scene value like any other, and one the scene lacks is refused.
    expect(
      () => PanelScene(
        _doc(
          spectrum: {
            'vfoLabel': {
              'mhz': {'size': 'missing'},
            },
          },
        ),
      ),
      throwsFormatException,
    );
  });

  test('waterfall history stays on its frequencies as the window moves or widens', () {
    // Drawn where it was taken, a signal's trail lines up under the signal;
    // stretched across the new window it would sit at a frequency it was never on.
    expect(waterfallRowExtent(14000000, 14100000, 14000000, 14100000, 400), (0, 400));
    // Tuned up by half a window: the old row slides half off the left.
    expect(waterfallRowExtent(14000000, 14100000, 14050000, 14150000, 400), (-200, 200));
    // Twice as wide around the same centre: the old row shrinks into the middle.
    expect(waterfallRowExtent(14000000, 14100000, 13950000, 14150000, 400), (100, 300));
  });

  testWidgets('follow scrolls the window just far enough to put the dial on its margin', (tester) async {
    // Centring instead would jump the picture on every step of the dial; not
    // moving at all leaves the tuned frequency off the display.
    //
    // The move limit is real time, which the app clock reads off the wall
    // unless told to follow the test's fake one — and on the wall, two pumps
    // on a loaded machine can be a quarter second apart.
    followFakeClock();
    final source = _Source();
    await _show(tester, source: source, spectrum: {'follow': .15});
    // The VFO (14.074) sits at 74% of 14.000–14.100: inside the margins.
    source.controller.add(_frame());
    await tester.pump();
    expect(source.recentered, isEmpty);
    // Below the window: centred 35% of the width above it, so it sits at 15%.
    source.controller.add(_frame(20, 14080000));
    await tester.pump();
    expect(source.recentered, [14109000]);
    // At most four moves a second while the radio's window catches up: the
    // next sweep, a tenth of a second on, moves nothing. Real seconds, and
    // only those — measured on the app clock, a hop of the clock would move
    // the window on the sweep after it, and a sped-up clock on every sweep.
    await tester.pump(const Duration(milliseconds: 100));
    AppClock.instance.travel(delta: const Duration(days: 3));
    source.controller.add(_frame(20, 14080000));
    await tester.pump();
    expect(source.recentered, hasLength(1));
    // The radio gets there: the window, held where the scope was sent while the picture glided, is
    // the sweeps' again — so when the radio's scope moves on its own (to 13.985–14.085, the dial at
    // 89%), follow brings the dial back to 85% rather than keeping a window the radio has left.
    await tester.pump(const Duration(milliseconds: 300));
    source.controller.add(_frame(20, 14059000));
    await tester.pump();
    source.controller.add(_frame(20, 13985000));
    await tester.pump();
    expect(source.recentered.last, 14039000);
  });

  testWidgets('the level strip brightens the waterfall along with the spectrum', (tester) async {
    // A gray ramp, so a row's red byte is how far up the waterfall's window the level sits.
    Future<int> shade(Map<String, dynamic> levels, double level) async {
      final source = _Source();
      await _show(
        tester,
        source: source,
        spectrum: {
          'waterfallFloor': 8,
          'waterfallRange': 30,
          'waterfallColors': ['#000000', '#FFFFFF'],
          ...levels,
        },
      );
      source.controller.add(_frame(level));
      await tester.pump();
      await _waitForRows(tester, 'pan', 1);
      final image = ((_waterfall(tester, 'pan').rows as List).first as dynamic).image as ui.Image;
      final bytes = (await tester.runAsync(() => image.toByteData()))!;
      await tester.pumpWidget(const SizedBox());
      return bytes.getUint8(0);
    }

    // Untouched, the window is 8–38 dB of the radio's 0–80.
    expect(await shade(const {}, 23), closeTo(128, 1));
    // The strip's floor at 20 and range at 40 (half the radio's): the window is the same part of
    // the spectrum's, 24–39 dB. Held to the radio's scale, 31.5 dB would read 78% up, not half.
    expect(await shade(const {'floor': 20, 'range': 40}, 31.5), closeTo(128, 1));
  });

  testWidgets('without follow the window is the radio\'s', (tester) async {
    final source = _Source();
    await _show(tester, source: source);
    source.controller.add(_frame(20, 14080000));
    await tester.pump();
    expect(source.recentered, isEmpty);
  });

  testWidgets('says why there is nothing to draw', (tester) async {
    await _show(tester);
    expect(find.text(t.settings.station.spectrumUnavailable), findsOneWidget, reason: 'a panel that may not read the radio');
    final source = _Source()..problemText = 'Requires CAT at 115200 bps';
    await _show(tester, source: source);
    expect(find.text('Requires CAT at 115200 bps'), findsOneWidget);
    source.problemText = null;
    source.notifyListeners();
    await tester.pump();
    expect(find.text('waiting'), findsOneWidget, reason: 'connected, but no sweep yet');
    source.controller.add(_frame());
    // The sweep lands in a microtask after the first pump's build.
    await tester.pump();
    await tester.pump();
    expect(find.text('waiting'), findsNothing);
  });

  testWidgets('a display goes quiet on real seconds of silence, not on a travelled clock', (tester) async {
    // The silence watch measures the real clock. Swapped for the app clock,
    // a hop of the clock would mark every live display as waiting on its
    // next tick, and the swap reads as an ordinary application of the
    // app-clock rule — nothing but this notices.
    followFakeClock();
    final source = _Source();
    await _show(tester, source: source);
    source.controller.add(_frame());
    await tester.pump();
    await tester.pump();
    expect(find.text('waiting'), findsNothing);
    AppClock.instance.travel(delta: const Duration(days: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('waiting'), findsNothing, reason: 'three days of travel are not three seconds of silence');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('waiting'), findsOneWidget, reason: 'four seconds without a sweep');
  });

  group('averaging', () {
    Future<String> levelAfter(WidgetTester tester, Map<String, dynamic> spectrum) async {
      final source = _Source();
      await _show(tester, source: source, spectrum: spectrum);
      for (final level in [20.0, 40.0]) {
        source.controller.add(_frame(level));
        await tester.pump();
      }
      final box = tester.getRect(find.byType(SceneSpectrumView));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: box.center);
      await mouse.moveTo(box.center.translate(1, 0));
      await tester.pump();
      await mouse.removePointer();
      return tester.widgetList<Text>(find.textContaining(' dB')).map((t) => t.data).join();
    }

    testWidgets('defaults to 40: the trace keeps 40% of what it showed', (tester) async {
      expect(await levelAfter(tester, const {}), '32.0 dB');
    });

    testWidgets('0 draws each sweep as it is', (tester) async {
      expect(await levelAfter(tester, const {'average': 0}), '40.0 dB');
    });

    testWidgets('follows a value, so a local slider retunes it', (tester) async {
      // avg is 0 in the document: bound to it, averaging is off.
      expect(await levelAfter(tester, const {'average': 'avg'}), '40.0 dB');
    });
  });

  testWidgets('a click with a step tunes to the nearest multiple of it', (tester) async {
    final source = _Source();
    final events = <Map<String, dynamic>>[];
    await _show(
      tester,
      source: source,
      spectrum: const {'tuneStep': 1000},
      onEvent: (e) async {
        events.add(e);
        return {};
      },
    );
    source.controller.add(_frame());
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    // A quarter of 14.000–14.100 MHz, nudged off the step so rounding shows.
    await tester.tapAt(Offset(box.left + box.width * .2535, box.center.dy));
    await tester.pump();
    expect(events.single['value'], 14025000);
  });

  testWidgets('the gap sits between the panadapter and the waterfall, and the split shares what is left', (tester) async {
    await _show(
      tester,
      source: _Source(),
      spectrum: const {
        'scale': {'gap': 30},
      },
    );
    final spectrum = tester.getRect(find.byType(SceneSpectrumView));
    final placed = [
      for (final p in tester.widgetList<Positioned>(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(Positioned)))) (p.top, p.height),
    ];
    final panHeight = (spectrum.height - 30) * .4;
    // Panadapter, gap, waterfall: a split taken of the whole height would put
    // the waterfall's top inside the gap.
    expect(placed, containsAll([(0.0, panHeight), (panHeight, 30.0), (panHeight + 30, spectrum.height - panHeight - 30)]));
  });

  group('annotations', () {
    Future<List<Map<String, dynamic>>> clickOn(WidgetTester tester, Map<String, dynamic> annotation) async {
      final source = _Source();
      final events = <Map<String, dynamic>>[];
      await _show(
        tester,
        source: source,
        spectrum: {
          'annotations': [annotation],
        },
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      final box = tester.getRect(find.byType(SceneSpectrumView));
      // The middle of the sweep, just above the panadapter's bottom edge.
      await tester.tapAt(Offset(box.center.dx, box.top + box.height * .4 - 10));
      await tester.pump();
      return events;
    }

    testWidgets('one with an event takes the click, and the radio is not tuned', (tester) async {
      final events = await clickOn(tester, {'id': 'spot-1', 'text': 'K1ABC', 'hz': 14050000, 'event': 'spot'});
      expect(events.single['action'], 'spot');
      expect(events.single['annotation'], 'spot-1');
      expect(events.single['value'], 14050000);
    });

    testWidgets('one at the edge of the window is cut off there, not drawn over what lies beside the scope', (tester) async {
      final source = _Source();
      await _show(
        tester,
        source: source,
        spectrum: {
          'annotations': [
            // Centred on the window's low edge: half its box lies off the scope.
            {'id': 'edge', 'text': 'IU8QGR', 'hz': 14000000, 'background': '#FFFF0000'},
          ],
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      final painted = tester.renderObjectList(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(CustomPaint)));
      final size = tester.getSize(find.byType(SceneSpectrumView));
      expect(
        painted,
        anyElement(
          paints
            ..clipRect(rect: Offset.zero & size)
            ..path(color: const Color(0xFFFF0000)),
        ),
      );
    });

    testWidgets('the dial\'s frequency is drawn over one on the dial', (tester) async {
      // Spots crowd the frequency tuned; drawn after the label, theirs would cover the readout.
      final source = _Source()..nativeGestures = true;
      await _show(
        tester,
        source: source,
        spectrum: {
          'backgroundColor': '#FF00FF00',
          'annotations': [
            {'id': 'on-dial', 'text': 'K1ABC', 'hz': 14074000, 'background': '#FFFF0000'},
          ],
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      final painted = tester.renderObjectList(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(CustomPaint)));
      expect(
        painted,
        anyElement(
          paints
            ..path(color: const Color(0xFFFF0000))
            ..path(color: const Color(0xFF00FF00).withValues(alpha: .7)),
        ),
      );
    });

    testWidgets('a click on the dial\'s frequency over a spot does not work the spot it hides', (tester) async {
      // The label is drawn over the annotations; hit-tested under it, a click on the readout would
      // put a station the operator cannot see in the logging fields.
      final source = _Source()..nativeGestures = true;
      final events = <Map<String, dynamic>>[];
      await _show(
        tester,
        source: source,
        spectrum: {
          'annotations': [
            {'id': 'on-dial', 'text': 'K1ABCDEFGH', 'hz': 14074000, 'event': 'spot', 'y': 'spectrum+28px', 'align': 'center'},
          ],
        },
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      final box = tester.getRect(find.byType(SceneSpectrumView));
      await tester.tapAt(Offset(box.left + box.width * .74 + 6, box.top + 6));
      await tester.pump(const Duration(milliseconds: 500));
      expect(events.where((e) => e['annotation'] != null), isEmpty);
    });

    testWidgets('its icon is part of the box a click lands on', (tester) async {
      // Starting at the middle of the sweep, the text alone is 24 px wide at this size; the icon
      // before it widens the box past where this click lands. Drawn beside the box, the icon would
      // look clickable and tune the radio instead.
      Future<List<Map<String, dynamic>>> clickBeyondText(Map<String, dynamic>? icon) async {
        final source = _Source();
        final events = <Map<String, dynamic>>[];
        await _show(
          tester,
          source: source,
          spectrum: {
            'annotations': [
              {'id': 'spot-1', 'text': 'K', 'hz': 14050000, 'event': 'spot', 'align': 'start', 'size': 20, 'icon': ?icon},
            ],
          },
          onEvent: (e) async {
            events.add(e);
            return {};
          },
        );
        source.controller.add(_frame());
        await tester.pump();
        await tester.pump();
        final box = tester.getRect(find.byType(SceneSpectrumView));
        await tester.tapAt(Offset(box.center.dx + 34, box.top + box.height * .4 - 14));
        await tester.pump();
        return events;
      }

      expect((await clickBeyondText(null)).where((e) => e['annotation'] != null), isEmpty);
      expect((await clickBeyondText({'name': 'pine-tree'})).single['annotation'], 'spot-1');
    });

    testWidgets('a click on it while another event is in flight is not swallowed by the next click', (tester) async {
      final source = _Source();
      final events = <Map<String, dynamic>>[];
      final gate = Completer<void>();
      await _show(
        tester,
        source: source,
        spectrum: {
          'annotations': [
            {'id': 'spot-1', 'text': 'K1ABC', 'hz': 14050000, 'event': 'spot'},
          ],
        },
        onEvent: (e) async {
          events.add(e);
          if (events.length == 1) await gate.future;
          return {};
        },
      );
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      final box = tester.getRect(find.byType(SceneSpectrumView));
      await tester.tapAt(Offset(box.left + 20, box.top + 20)); // a tune, held in flight
      await tester.pump();
      await tester.tapAt(Offset(box.center.dx, box.top + box.height * .4 - 10)); // the spot
      await tester.pump();
      await tester.tapAt(Offset(box.left + 30, box.top + 20)); // another tune
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(events.map((e) => e['action']), ['tune', 'spot', 'tune']);
    });

    testWidgets('one without an event is something to read: the click tunes', (tester) async {
      final events = await clickOn(tester, {'id': 'net', 'text': 'Net', 'hz': 14050000});
      expect(events.single['action'], 'tune');
      expect(events.single.containsKey('annotation'), isFalse);
    });
  });

  group('flow', () {
    test('defaults to down, and takes only the four directions', () {
      expect(PanelScene(_doc()).controlsById['pan']!.spectrum!.flow, SceneSpectrumFlow.down);
      expect(PanelScene(_doc(spectrum: {'flow': 'right'})).controlsById['pan']!.spectrum!.flow, SceneSpectrumFlow.right);
      expect(() => PanelScene(_doc(spectrum: {'flow': 'sideways'})), throwsFormatException);
    });

    testWidgets('up puts the panadapter at the bottom, the waterfall above it', (tester) async {
      await _show(tester, source: _Source(), spectrum: const {'flow': 'up'});
      final spectrum = tester.getRect(find.byType(SceneSpectrumView));
      final placed = [
        for (final p in tester.widgetList<Positioned>(find.descendant(of: find.byType(SceneSpectrumView), matching: find.byType(Positioned))))
          (p.top, p.height),
      ];
      final panHeight = spectrum.height * .4;
      expect(placed, containsAll([(spectrum.height - panHeight, panHeight), (0.0, spectrum.height - panHeight)]));
    });

    testWidgets('turned, frequency runs as down turned a quarter, and a click tunes where it lands', (tester) async {
      for (final (flow, quarterDown) in [('right', 14075000.0), ('left', 14025000.0)]) {
        final source = _Source();
        final events = <Map<String, dynamic>>[];
        await _show(
          tester,
          source: source,
          spectrum: {'flow': flow},
          onEvent: (e) async {
            events.add(e);
            return {};
          },
        );
        source.controller.add(_frame());
        await tester.pump();
        final box = tester.getRect(find.byType(SceneSpectrumView));
        // A quarter of the way down 14.000–14.100 MHz: rising up the control for `right`, down it for `left`.
        await tester.tapAt(Offset(box.center.dx, box.top + box.height / 4));
        await tester.pump();
        expect(events.single['value'] as double, closeTo(quarterDown, 500), reason: flow);
      }
    });

    test('rising takes only the two ways across the flow', () {
      SceneSpectrumSpec spec(Map<String, dynamic> s) => PanelScene(_doc(spectrum: s)).controlsById['pan']!.spectrum!;
      expect(spec({}).reversed, isFalse);
      expect(spec({'rising': 'right'}).reversed, isFalse);
      expect(spec({'rising': 'left'}).reversed, isTrue);
      expect(spec({'flow': 'left', 'rising': 'up'}).reversed, isTrue);
      expect(spec({'flow': 'right', 'rising': 'down'}).reversed, isFalse);
      expect(spec({'flow': 'right'}).reversed, isTrue, reason: 'up, as down turned a quarter');
      expect(spec({'flow': 'left'}).reversed, isFalse, reason: 'down, as down turned a quarter');
      expect(() => spec({'rising': 'up'}), throwsFormatException);
      expect(() => spec({'flow': 'right', 'rising': 'left'}), throwsFormatException);
    });

    test('a rising the flow does not take names the ones it does', () {
      Object? error(Map<String, dynamic> s) {
        try {
          PanelScene(_doc(spectrum: s));
        } on FormatException catch (e) {
          return e.message;
        }
        return null;
      }

      expect(error({'rising': 'up'}), 'Invalid scene rising: up for flow down, which rises right or left');
      expect(error({'flow': 'left', 'rising': 'right'}), 'Invalid scene rising: right for flow left, which rises down or up');
    });

    testWidgets('rising against its default, a click tunes from the other end', (tester) async {
      for (final (flow, rising, at) in [
        ('down', 'left', (Size s) => Offset(s.width / 4, s.height / 2)),
        ('up', 'left', (Size s) => Offset(s.width / 4, s.height / 2)),
        ('right', 'down', (Size s) => Offset(s.width / 2, s.height * 3 / 4)),
        ('left', 'up', (Size s) => Offset(s.width / 2, s.height / 4)),
      ]) {
        final source = _Source();
        final events = <Map<String, dynamic>>[];
        await _show(
          tester,
          source: source,
          spectrum: {'flow': flow, 'rising': rising},
          onEvent: (e) async {
            events.add(e);
            return {};
          },
        );
        source.controller.add(_frame());
        await tester.pump();
        final box = tester.getRect(find.byType(SceneSpectrumView));
        // A quarter of the way in from where frequency now starts: three quarters up the sweep.
        await tester.tapAt(box.topLeft + at(box.size));
        await tester.pump();
        expect(events.single['value'] as double, closeTo(14075000, 500), reason: '$flow $rising');
      }
    });
  });

  testWidgets('a control tells the source the width it crops to while it draws, and nothing once it goes', (tester) async {
    final source = _Source();
    await _show(tester, source: source, spectrum: const {'span': 50000});
    expect(source.widths.values, [50000]);
    await _show(tester, source: source, spectrum: const {'span': 20000});
    expect(source.widths.values, [20000]);
    await _show(tester, source: source, visible: false, spectrum: const {'span': 20000});
    expect(source.widths, isEmpty, reason: 'hidden, it draws nothing');
    await _show(tester, source: source);
    expect(source.widths.values, [0], reason: 'with no span it draws the whole sweep: no width, but a display a radio-set span must not cut');
  });

  testWidgets('retained receiver views release only their own viewport demand when hidden or replaced', (tester) async {
    Map<String, dynamic> document(String view, {String mainRadio = _mainRadio}) {
      final result = _dualDoc(view);
      for (final control in result['controls'] as List) {
        if (control['kind'] != 'spectrum') continue;
        control['span'] = control['id'] == 'main-pan' ? 20000 : 40000;
        if (control['id'] == 'main-pan') control['radio'] = mainRadio;
      }
      return result;
    }

    Map<String, int> widthsByRadio(_Source source) => {for (final entry in source.widths.entries) entry.key.$1: entry.value};
    final source = _Source();
    await _show(tester, source: source, document: document('both'));
    final mainState = tester.state(_spectrum('main-pan'));
    final subState = tester.state(_spectrum('sub-pan'));
    expect(widthsByRadio(source), {_mainRadio: 20000, _subRadio: 40000});

    await _show(tester, source: source, document: document('sub'));
    expect(widthsByRadio(source), {_subRadio: 40000});
    expect(tester.state(_spectrum('main-pan')), same(mainState));
    await _show(tester, source: source, document: document('main'));
    expect(widthsByRadio(source), {_mainRadio: 20000});
    expect(tester.state(_spectrum('sub-pan')), same(subState));

    final replacement = _Source();
    await _show(tester, source: replacement, document: document('both'));
    expect(source.widths, isEmpty, reason: 'a retained widget must release the source it stopped drawing');
    expect(widthsByRadio(replacement), {_mainRadio: 20000, _subRadio: 40000});
    await _show(
      tester,
      source: replacement,
      document: document('both', mainRadio: 'another-main'),
    );
    expect(widthsByRadio(replacement), {'another-main': 20000, _subRadio: 40000});

    await tester.pumpWidget(const SizedBox());
    expect(replacement.widths, isEmpty, reason: 'disposing retained views releases every viewport owner');
  });

  testWidgets('a disabled spectrum shows, and sends nothing', (tester) async {
    final source = _Source();
    final events = <Map<String, dynamic>>[];
    final doc = _doc(
      spectrum: const {
        'disabled': true,
        'annotations': [
          {'id': 'spot-1', 'text': 'K1ABC', 'hz': 14050000, 'event': 'spot'},
        ],
      },
    );
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
                  scene: PanelScene(doc),
                  spectrum: source,
                  onEvent: (e) async {
                    events.add(e);
                    return {};
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    source.controller.add(_frame());
    await tester.pump();
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    await tester.tapAt(Offset(box.left + 20, box.top + 20));
    await tester.tapAt(Offset(box.center.dx, box.top + box.height * .4 - 10));
    await tester.pump();
    expect(events, isEmpty);
  });

  testWidgets("a refused tune does not take a spot's click queued behind it with it", (tester) async {
    final source = _Source();
    final events = <Map<String, dynamic>>[];
    final gate = Completer<void>();
    await _show(
      tester,
      source: source,
      spectrum: {
        'annotations': [
          {'id': 'spot-1', 'text': 'K1ABC', 'hz': 14050000, 'event': 'spot'},
        ],
      },
      onEvent: (e) async {
        events.add(e);
        if (e['action'] == 'tune') {
          await gate.future;
          throw StateError('refused');
        }
        return {};
      },
    );
    source.controller.add(_frame());
    await tester.pump();
    await tester.pump();
    final box = tester.getRect(find.byType(SceneSpectrumView));
    await tester.tapAt(Offset(box.left + 20, box.top + 20));
    await tester.pump();
    await tester.tapAt(Offset(box.center.dx, box.top + box.height * .4 - 10));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    // The spot carries its own frequency, so it never acted on the value
    // the extension refused.
    expect(events.map((e) => e['action']), ['tune', 'spot']);
  });

  group('window', () {
    const band = {'lowHz': 14000000, 'highHz': 14350000};

    Future<List<Map<String, dynamic>>> clicks(WidgetTester tester, {SceneSpectrumSource? source, Map<String, dynamic> spectrum = const {}}) async {
      final events = <Map<String, dynamic>>[];
      await _show(
        tester,
        source: source,
        spectrum: {'window': band, ...spectrum},
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      return events;
    }

    Future<void> clickAt(WidgetTester tester, double share) async {
      final box = tester.getRect(find.byType(SceneSpectrumView));
      await tester.tapAt(Offset(box.left + box.width * share, box.top + box.height * .7));
      await tester.pump();
    }

    testWidgets('with no radio, the window is the band: no message, and a click is at its frequency', (tester) async {
      final events = await clicks(tester);
      expect(find.text(t.settings.station.spectrumUnavailable), findsNothing);
      await clickAt(tester, .5);
      expect(events.single['action'], 'tune');
      expect(events.single['value'] as double, closeTo(14175000, 2000));
    });

    testWidgets('a radio with no scope says nothing either, and its annotations take their clicks', (tester) async {
      final source = _Source()..problemText = 'This radio has no scope';
      final events = await clicks(
        tester,
        source: source,
        spectrum: {
          'display': 'spectrum',
          'annotations': [
            {'id': 'spot-1', 'text': 'K1ABC', 'hz': 14175000, 'event': 'spot'},
          ],
        },
      );
      await tester.pump();
      expect(find.text('This radio has no scope'), findsNothing);
      expect(find.text('waiting'), findsNothing);
      final box = tester.getRect(find.byType(SceneSpectrumView));
      // Just above the spectrum's foot, where an annotation stands.
      await tester.tapAt(Offset(box.center.dx, box.bottom - 10));
      await tester.pump();
      expect(events.single['action'], 'spot');
      expect(events.single['annotation'], 'spot-1');
    });

    testWidgets('a sweep takes its place, and one that stops gives it back', (tester) async {
      // The silence watch reads the real clock, which this has follow the test's.
      followFakeClock();
      final source = _Source();
      final events = await clicks(tester, source: source);
      await clickAt(tester, .5);
      expect(events.last['value'] as double, closeTo(14175000, 2000), reason: 'before the first sweep');
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      await clickAt(tester, .5);
      // The sweep's own width, still about the band's middle: the window stays where the scene put it.
      expect(events.last['value'] as double, closeTo(14175000, 1000), reason: 'over the sweep');
      await clickAt(tester, .1);
      expect(events.last['value'] as double, closeTo(14135000, 1000), reason: 'the sweep\'s width across');
      expect(find.text('waiting'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('waiting'), findsNothing, reason: 'the band stands in, rather than a message');
      await clickAt(tester, .5);
      expect(events.last['value'] as double, closeTo(14175000, 2000), reason: 'the band again');
    });

    testWidgets('over a sweep, the window centres on it until the operator pans', (tester) async {
      final source = _Source();
      final events = await clicks(tester, source: source, spectrum: {'span': 350000, 'maxWidthHz': 350000});
      source.controller.add(_frame());
      await tester.pump();
      await tester.pump();
      await clickAt(tester, .5);
      expect(events.last['value'] as double, closeTo(14175000, 2000), reason: 'the band\'s middle, not the sweep\'s');
      await clickAt(tester, .1);
      expect(events.last['value'] as double, closeTo(14035000, 2000));
    });

    testWidgets('a scene that drops it says why there is nothing to draw again', (tester) async {
      final source = _Source();
      await clicks(tester, source: source);
      expect(find.text('waiting'), findsNothing);
      await _show(tester, source: source);
      expect(find.text('waiting'), findsOneWidget);
    });

    test('is refused unless its high edge is above its low', () {
      expect(
        () => SceneSpectrumSpec({
          'window': {'lowHz': 14350000, 'highHz': 14000000},
        }),
        throwsFormatException,
      );
      expect(() => SceneSpectrumSpec({'window': 14000000}), throwsFormatException);
      expect(SceneSpectrumSpec({'window': band}).window, (14000000.0, 14350000.0));
    });
  });
}
