// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `spectrum` control: the host draws the radio's sweeps, and the
// radio's scope runs only while a pane that shows one is on screen.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

class _Source extends ChangeNotifier implements SceneSpectrumSource {
  int listening = 0;
  String? problemText;
  late final controller = StreamController<SpectrumFrame>.broadcast(onListen: () => listening++, onCancel: () => listening--);

  @override
  String? resolve(String? radio) => radio ?? 'radio-1';
  @override
  Stream<SpectrumFrame> frames(String uuid) => controller.stream;
  @override
  String? problem(String uuid) => problemText;
  @override
  double? vfoHz(String uuid) => 14074000;
  @override
  Listenable get changes => this;
  @override
  String get noRadio => 'no radio';
  @override
  String get waiting => 'waiting';
  @override
  Map<String, num> readings(String uuid) => const {};
  @override
  Listenable get readingChanges => this;
  final recentered = <int>[];
  final widths = <Object, int>{};
  @override
  void showWidth(String uuid, Object owner, int? widthHz) => widthHz == null ? widths.remove(owner) : widths[owner] = widthHz;
  @override
  bool recenter(String uuid, int centerHz) {
    recentered.add(centerHz);
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
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DockPaneVisibility(
              visible: visible,
              child: PanelSceneView(
                scene: PanelScene(_doc(spectrum: spectrum)),
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

void main() {
  group('the document', () {
    test('a spectrum is laid out without a rect, like a native control', () {
      expect(PanelScene(_doc()).controlsById['pan']!.spectrum!.hoverHz, 'hz');
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
      expect(spec.traceColor, const Color(0x80FF0000));
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

  test('a display width crops each sweep about its middle, and never widens one', () {
    // A radio's scope comes in a few widths; the display shows any narrower.
    final sweep = _frame(20, 14000000);
    final cropped = cropSpectrumFrame(sweep, 50000);
    expect((cropped.lowHz, cropped.highHz, cropped.levels.length), (14025000, 14075000, 50));
    expect(identical(cropSpectrumFrame(sweep, 200000), sweep), isTrue);
    expect(identical(cropSpectrumFrame(sweep, null), sweep), isTrue);
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
    // At most four moves a second while the radio's window catches up.
    source.controller.add(_frame(20, 14080000));
    await tester.pump();
    expect(source.recentered, hasLength(1));
    // Past the right margin (14.074 at 89% of 13.985–14.085): it sits at 85%.
    // The limit is on the real clock, which a pump does not move.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    source.controller.add(_frame(20, 13985000));
    await tester.pump();
    expect(source.recentered.last, 14039000);
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
    expect(source.widths, isEmpty, reason: 'with no span it asks for none');
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
}
