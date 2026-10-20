// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The compass over a turned or tilted map: its needle has to point at north
// on the map under it, whichever backend reports the turn, and a tap has to
// reach the live backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/map/map_buttons.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';

void main() {
  Widget host(MapZoomController controller) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: MapCompassButton(controller: controller)),
      ),
    ),
  );

  /// Where the needle's north tip points, on screen (y down).
  Offset needle(WidgetTester tester) {
    final transform = tester.widget<Transform>(find.descendant(of: find.byType(MapCompassButton), matching: find.byType(Transform)));
    return MatrixUtils.transformPoint(transform.transform, const Offset(0, -1));
  }

  testWidgets('the needle points at north on the map', (tester) async {
    final controller = MapZoomController();
    await tester.pumpWidget(host(controller));

    // East at the top of the map puts north on its left.
    controller.reportOrientation(const MapOrientation(bearing: 90));
    await tester.pump();
    expect(needle(tester).dx, closeTo(-1, 1e-9));
    expect(needle(tester).dy, closeTo(0, 1e-9));

    // Tilted back 60°, the needle foreshortens as the map does.
    controller.reportOrientation(const MapOrientation(pitch: 60));
    await tester.pump();
    expect(needle(tester).dy, closeTo(-0.5, 1e-9));
  });

  testWidgets('a tap asks the live backend to set the map north-up', (tester) async {
    var resets = 0;
    final controller = MapZoomController()..onResetNorth = () => resets++;
    await tester.pumpWidget(host(controller));
    await tester.tap(find.byType(MapCompassButton));
    expect(resets, 1);
  });

  testWidgets('a GL backend coming up clears the turn the one before it was left in, once the frame is built', (tester) async {
    // A GL map says nothing of its orientation until it is turned, so only
    // resetOrientation takes down a compass the backend before it left up.
    // It is called from initState, during the rebuild of a pane that holds
    // the backend but not the buttons listening — as the Maps view's results
    // map is to its button column.
    final controller = MapZoomController();
    final pane = GlobalKey<_PaneState>();
    await tester.pumpWidget(
      Column(
        children: [
          ValueListenableBuilder(valueListenable: controller.turned, builder: (context, turned, _) => const SizedBox()),
          _Pane(key: pane, controller: controller),
        ],
      ),
    );
    controller.reportOrientation(const MapOrientation(bearing: 45));
    await tester.pump();

    pane.currentState!.swapBackend();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'marking the buttons dirty from outside the build in progress is an error');
    expect(controller.turned.value, isFalse);
  });

  test('turned only off north-up, whole turns of flutter_map included', () {
    final controller = MapZoomController();
    final flips = <bool>[];
    controller.turned.addListener(() => flips.add(controller.turned.value));
    controller.reportOrientation(const MapOrientation(bearing: 30));
    controller.reportOrientation(const MapOrientation(bearing: 31));
    controller.reportOrientation(const MapOrientation(bearing: -360));
    expect(flips, [true, false], reason: 'the buttons around the compass rebuild on a flip, never on a frame of a turn');
  });
}

/// Holds a backend, and brings up a new one in its place on [swapBackend].
class _Pane extends StatefulWidget {
  final MapZoomController controller;
  const _Pane({super.key, required this.controller});

  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  var _generation = 0;

  void swapBackend() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) => _Backend(key: ValueKey(_generation), controller: widget.controller);
}

/// Calls [MapZoomController.resetOrientation] where a backend does.
class _Backend extends StatefulWidget {
  final MapZoomController controller;
  const _Backend({super.key, required this.controller});

  @override
  State<_Backend> createState() => _BackendState();
}

class _BackendState extends State<_Backend> {
  @override
  void initState() {
    super.initState();
    widget.controller.resetOrientation();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
