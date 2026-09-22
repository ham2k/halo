// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The solar pane's floors, swept against REAL type in panes of every shape.
//
// Two things this file has that the rest of the panel's tests cannot. The
// first is the app's own fonts: the default test font gives every glyph the
// same metrics, and a line of it is exactly its font size, where Roboto's
// ascent and descent make the same line taller. Every floor in the readout
// gates a band of type, so a floor measured against the test font is measured
// against type nobody runs — and a Column cannot shrink a Text, so what an
// underestimate produces is a RenderFlex overflow on every frame.
//
// The second is WIDTH. The pane's floors are heights, but the headline is
// sized at a fraction of the pane's height AND capped by its width, so a wide
// pane wears a bigger flux number than a narrow one of the same height, and
// only the wide one runs out of room. A sweep that stops at 440 never sees
// it.
//
// Fonts are loaded for the whole process, which is why this is a file of its
// own rather than a group in `panel_solar_test.dart`: registering Roboto
// there would silently re-measure every other test in it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/solar/solar_panel.dart';

void main() {
  setUpAll(() async {
    // The families the panel's type actually resolves to. Loaded together
    // because the theme picks between them by role, and a family left on the
    // test font would put the one line this sweep is measuring back on
    // uniform metrics.
    for (final family in ['Roboto', 'RobotoSlab', 'RobotoCondensed', 'RobotoMono']) {
      final bytes = await File('assets/fonts/$family.ttf').readAsBytes();
      await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
  });

  String conditions() => '''
<solar><solardata>
  <updated> 25 Aug 2026 1753 GMT</updated>
  <solarflux>143</solarflux>
  <aindex> 6</aindex>
  <kindex> 4</kindex>
  <xray>B9.9</xray>
  <sunspots>83</sunspots>
  <heliumline>120.4</heliumline>
  <solarwind>305.6</solarwind>
  <calculatedconditions>
    <band name="80m-40m" time="day">Good</band>
    <band name="30m-20m" time="day">Good</band>
    <band name="17m-15m" time="day">Good</band>
    <band name="12m-10m" time="day">Fair</band>
    <band name="80m-40m" time="night">Good</band>
    <band name="30m-20m" time="night">Good</band>
    <band name="17m-15m" time="night">Good</band>
    <band name="12m-10m" time="night">Poor</band>
  </calculatedconditions>
  <geomagfield>VR QUIET</geomagfield>
  <signalnoise>S0-S1</signalnoise>
</solardata></solar>''';

  /// Built around the real clock rather than a pinned instant: the panel
  /// slices both series against `now`, and a fixture dated 2026 would be an
  /// empty chart — and an empty chart is a section that never lays out, which
  /// is the one thing this sweep must not accidentally test.
  String fluxSeries() {
    final now = nowUtc();
    return '[${[for (var i = 30; i > 0; i--) '{"time_tag":"${now.subtract(Duration(days: i)).toIso8601String().split('.').first}","flux":${120 + i}}'].join(',')}]';
  }

  /// The propagated wind, an array of ARRAYS with a header row.
  String windSeries() {
    final now = nowUtc();
    return '[["time_tag","speed","density"],${[for (var i = 56; i > 0; i--) '["${now.subtract(Duration(minutes: i)).toIso8601String().split('.').first}Z",${300 + i % 12},1.8]'].join(',')}]';
  }

  String kpSeries() {
    final now = nowUtc();
    return '[${[for (var i = 24; i > 0; i--) '{"time_tag":"${now.subtract(Duration(hours: i * 3)).toIso8601String().split('.').first}","Kp":${(i % 7) + 1}}'].join(',')}]';
  }

  SolarFetch answering() => (url) async {
    final body = switch (url.path) {
      final path when path.contains('solarxml') => conditions(),
      final path when path.contains('f107') => fluxSeries(),
      final path when path.contains('solar-wind') => windSeries(),
      _ => kpSeries(),
    };
    return (status: 200, body: body);
  };

  Future<void> pump(WidgetTester tester, Size size, double textScale) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          // The app's own theme, not the default one: the floors gate type, and
          // type here is whatever the theme says it is.
          theme: buildHaLoTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: DockPaneVisibility(visible: true, child: SolarPanel(fetch: answering())),
          ),
        ),
      ),
    );
    // Deliberately not pumpAndSettle: the loading state is a
    // CircularProgressIndicator, which never settles.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Unmounts the pane so its periodic timer is cancelled — a live
  /// `Timer.periodic` fails the test it outlives, naming the next one.
  Future<void> endOfTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  // Either side of every floor rather than at it: the bug a floor carries is
  // never at the floor exactly, it is in the BAND above it, where the section
  // has been let in and the headline has not yet grown enough room for it.
  const heights = [
    40.0, 54.0, 90.0, 110.0, 140.0, 196.0, 200.0, 206.0, 210.0,
    214.0, 224.0, 240.0, 258.0, 262.0, 268.0, 300.0, 316.0, 320.0, 328.0, 420.0,
    // Either side of the wind curve's floor, which is the third chart's.
    424.0, 430.0, 440.0, 520.0, 700.0,
  ];
  // Out to a pane far wider than tall, which is what a dock row of one panel
  // is, and what nothing else in this panel's tests covers.
  const widths = [120.0, 184.0, 240.0, 440.0, 900.0];

  for (final scale in [1.0, 1.6, 2.5]) {
    testWidgets('nothing overflows at textScaler $scale', (tester) async {
      for (final height in heights) {
        for (final width in widths) {
          await pump(tester, Size(width, height), scale);
          expect(tester.takeException(), isNull, reason: 'overflowed at ${width}x$height, textScaler $scale');
          await endOfTest(tester);
        }
      }
    });
  }
}
