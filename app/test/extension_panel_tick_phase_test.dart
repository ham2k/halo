// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A panel ticks at every phase of the clock, not just the lucky ones.
//
// Ticks are aimed at wall-clock boundaries, so the first delay is whatever is
// left of the current period — a number that comes from the REAL clock while
// the timer runs on the test's FAKE one. That makes any single tick test
// phase-dependent: it passes or fails on where the clock happened to sit,
// which is a flake that only ever appears on `main`, since CI runs nowhere
// else.
//
// This walks the clock across a whole period instead, so every phase is
// covered deterministically. Two of these twenty fail without the guards that
// keep a tick from arriving faster than the throttle can serve it —
// `delayToBoundary`'s own clamp on a near-zero wait, and dropping a tick when
// a render is already scheduled. Without both, a tick arriving inside the
// throttle window cancels the pending render and re-arms it, indefinitely:
// the panel is starved, and at most phases nothing shows it.
//
// NOT the per-panel rate floor, which is inert here: `panelTickDelayMillis`
// widens the period only below `minPanelTickMillis * speed`, and this sweep
// runs `tick:5` at speed 1. That floor is pinned in the budget suite instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

void main() {
  tearDown(AppClock.instance.reset);

  // 250ms steps across a 5s period: fine enough to land inside the failing
  // window, coarse enough to stay a few seconds of suite time.
  for (var offsetMs = 0; offsetMs < 5000; offsetMs += 250) {
    testWidgets('phase +${offsetMs}ms still ticks', (tester) async {
      // A whole period on top of the offset, because `AppClock.travel`
      // DISCARDS a sub-second delta at speed 1 — it treats it as a request
      // for real time and resets. Travelling by the bare offset would leave
      // 0/250/500/750 all reading the real clock, so three of the twenty
      // phases would never run and the sweep would still turn on where the
      // real clock happened to sit: the very flake it exists to remove.
      // A multiple of the period keeps the phase the offset asks for.
      AppClock.instance.travel(delta: Duration(milliseconds: 5000 + offsetMs));
      final d = WallClock.delayToBoundary(periodMs: 5000, nowMillis: nowMillis(), speed: 1.0);

      final panels = _Panels();
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: true,
              child: ExtensionPanel(
                panel: const PanelDefinition(
                  id: 'ext:text:custom',
                  title: 'Custom Text',
                  source: PanelSource.extension,
                  hookKey: 'text',
                  panelKey: 'custom',
                ),
                panels: panels,
                renderContext: PanelRenderContext(
                  operation: Operation(uuid: 'op-1', data: const {'stationCall': 'N0DEV'}),
                  qsoCount: 0,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(panels.renders.length, greaterThan(1), reason: 'boundary delay was ${d}ms');
    });
  }
}

class _Panels extends PanelService {
  _Panels() : super(_Src());
  final renders = <String>[];
  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders.add(args['reason'] as String);
    return {'kind': 'markdown', 'content': 'ok', 'triggers': const ['tick:5']};
  }
}

class _Src implements PanelExtensionSource {
  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);
  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => const [];
  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;
  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};
  @override
  Future<void> forgetPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async {}
}
