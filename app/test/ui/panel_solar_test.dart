// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The solar pane's states, what it puts on the wire, and what it sheds as the
// pane shrinks.
//
// The fetch is injected, so nothing here opens a socket. That is not only
// about speed: the two failure states an operator is told apart — the service
// never answered versus answered with nonsense — are unreachable from a test
// that depends on hamqsl really being down in a particular way. The three
// sources' INDEPENDENCE is the other thing only an injected fetch can show:
// SWPC failing must cost a chart and nothing else.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/solar/solar_charts.dart';
import 'package:ham2k_logger/views/operation/solar/solar_panel.dart';
import 'package:ham2k_logger/views/operation/solar/solar_reading.dart';

void main() {
  final t = AppLocale.en.buildSync().operation.layout.panels;

  /// N0NBH's document as the panel gets it, with the leading spaces the real
  /// feed puts in its indices.
  String conditions({int sfi = 143, int k = 1, String band = 'Good'}) =>
      '''
<solar><solardata>
  <updated> 25 Aug 2026 1753 GMT</updated>
  <solarflux>$sfi</solarflux>
  <aindex> 6</aindex>
  <kindex> $k</kindex>
  <xray>B9.9</xray>
  <sunspots>83</sunspots>
  <heliumline>120.4</heliumline>
  <solarwind>305.6</solarwind>
  <calculatedconditions>
    <band name="80m-40m" time="day">$band</band>
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

  /// Built around the real clock rather than a pinned instant, so nothing
  /// here rots on a future run — the panel slices both series against `now`.
  /// F10.7 as the feed sends it: three observations a day, at 17:00, 20:00
  /// and 22:00 UT — the instrument's own cadence, and what the curve draws.
  String fluxSeries({int days = 30}) {
    final now = nowUtc();
    return '[${[
      for (var i = days; i > 0; i--)
        for (final hour in [17, 20, 22]) '{"time_tag":"${DateTime.utc(now.year, now.month, now.day - i, hour).toIso8601String().split('.').first}",'
              '"flux":${120 + i}}',
    ].join(',')}]';
  }

  /// SWPC's Kp, stamped on the 00/03/06 UTC grid the real feed uses.
  ///
  /// ALIGNED, not just three hours apart. Offset by whatever minute the test
  /// happens to run at, this fixture would hide the one property the wind's
  /// buckets exist to have — that a wind mark and the bar under it name the
  /// same period.
  String kpSeries({int hours = 72, double kp = 2}) {
    final now = nowUtc();
    final grid = DateTime.utc(now.year, now.month, now.day, (now.hour ~/ 3) * 3);
    return '[${[for (var i = hours ~/ 3; i > 0; i--) '{"time_tag":"${grid.subtract(Duration(hours: i * 3)).toIso8601String().split('.').first}","Kp":$kp}'].join(',')}]';
  }

  /// SWPC's propagated wind, which is an array of ARRAYS with a header row —
  /// a different shape from the other two series, and the reason the parser
  /// reads the header rather than trusting a column index.
  String windSeries({int minutes = 56}) {
    final now = nowUtc();
    return '[["time_tag","speed","density","temperature"],${[for (var i = minutes; i > 0; i--) '["${now.subtract(Duration(minutes: i)).toIso8601String().split('.').first}Z",${300 + i % 12},1.8,32000]'].join(',')}]';
  }

  /// A week of wind at ten-minute cadence — what the big file looks like once
  /// the panel buckets it. The hourly feed alone is one three-hour bucket, or
  /// two when the hour straddles a bucket boundary — never more.
  String windHistory({int days = 7}) {
    final now = nowUtc();
    final readings = days * 24 * 6;
    return '[["time_tag","speed","density"],${[for (var i = readings; i > 0; i--) '["${now.subtract(Duration(minutes: i * 10)).toIso8601String().split('.').first}Z",'
          '${300 + (i % 40)},1.8]'].join(',')}]';
  }

  late List<Uri> requested;

  setUp(() => requested = []);

  /// Answers each URL independently. Missing conditions, flux or Kp bodies
  /// simulate transport failures. Wind defaults to one valid point, enough
  /// for a successful response without adding a chart to layout-only tests.
  SolarFetch answering({String? solar, String? flux, String? kp, String? wind, String? windHistoryBody, bool failWindHistory = false, int status = 200}) =>
      (url) async {
        requested.add(url);
        // Matched on the PATH, not the host: on web the conditions URL is
        // proxied through services.ham2k.net, so a host match would silently
        // route it to the Kp branch there.
        final body = switch (url.path) {
          final path when path.contains('solarxml') => solar,
          final path when path.contains('f107') => flux,
          final path when path.contains('propagated-solar-wind-1-hour') => wind ?? windSeries(minutes: 1),
          final path when path.contains('propagated-solar-wind') => failWindHistory ? null : windHistoryBody ?? wind ?? windSeries(minutes: 1),
          _ => kp,
        };
        if (body == null) throw const SocketishFailure();
        return (status: status, body: body);
      };

  Future<void> pump(WidgetTester tester, {required SolarFetch fetch, bool dockVisible = true, Size size = const Size(440, 420), double textScale = 1.0}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          // The OS text size, which composes ON TOP of the app's own Font Scale
          // and — unlike Font Scale — does not come out of the MediaQuery size
          // (docs/design/ui-scaling.md §3). Applied here rather than on the
          // view, so it reaches the pane the way the platform's does.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: DockPaneVisibility(
              visible: dockVisible,
              child: SolarPanel(fetch: fetch),
            ),
          ),
        ),
      ),
    );
    // Deliberately NOT pumpAndSettle: the loading state is a
    // CircularProgressIndicator, which never settles, so a settle here would
    // time out and be reported against whatever ran next.
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

  /// A chart is found by its KEY, not its painter: the charts lost their
  /// captions when the labels moved onto the marks, so no text on the pane
  /// says one is there — and the flux and wind curves share a painter, so
  /// the type does not tell them apart either.
  Finder chart(String which) => find.descendant(of: find.byKey(ValueKey('solar-chart-$which')), matching: find.byType(CustomPaint));
  Finder fluxChart() => chart('flux');
  Finder kpChart() => chart('kp');
  Finder windChart() => chart('wind');

  group('a reading on screen', () {
    testWidgets('leads with the flux index and the sunspot number', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
      );

      // The flux is one string; the sunspot number is a label and a value in
      // its own column beside it.
      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.text('SN'), findsOneWidget);
      expect(find.text('83'), findsOneWidget);
      await endOfTest(tester);
    });

    testWidgets('credits both feeds on one centred line at the foot', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
      );

      // BOTH, and this is the whole reason the line is plural: hamqsl carries
      // every number and the band grid, and both charts are NOAA's. A credit
      // naming only the first puts hamqsl's name on a month of SWPC data.
      final credit = find.text(t.solarSources(primary: solarSourceHost, secondary: solarSeriesSource));
      expect(credit, findsOneWidget);

      final footer = tester.getRect(credit);
      final pane = tester.getRect(find.byType(SolarPanel));

      // At the foot, below the numbers.
      expect(footer.top, greaterThan(tester.getRect(find.text('SFI 143')).bottom));

      // And BELOW the charts, which run to the pane's edges. The credit is a
      // line of the Column like any other, but the thing above it paints
      // edge to edge, so a footer that merely followed it in the child list
      // while sharing its band would read as an axis label on the bars.
      expect(footer.top, greaterThanOrEqualTo(tester.getRect(kpChart().last).bottom));

      // Centred, within a point: the pane is symmetrical about it, and a
      // left-aligned credit under a centred one is the kind of drift a rect
      // comparison catches and an eye does not.
      expect((footer.center.dx - pane.center.dx).abs(), lessThan(1.0));
      await endOfTest(tester);
    });

    testWidgets('carries the four columns of numbers', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(900, 420),
      );

      // The flux leads, and the two stacked pairs follow it: what is on the
      // disc (SN, 304A) and what the field is doing (A, Kp).
      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.text('83'), findsOneWidget, reason: 'sunspot number');
      expect(find.text('305.6'), findsOneWidget, reason: 'solar wind speed, km/s');
      expect(find.text('SW'), findsOneWidget);
      expect(find.text('6'), findsOneWidget, reason: 'A index, past the feed\'s leading space');
      expect(find.text('1'), findsOneWidget, reason: 'Kp');
      expect(find.text(t.solarAIndex), findsOneWidget);
      expect(find.text(t.solarKIndex), findsOneWidget);
      await endOfTest(tester);
    });

    testWidgets('the pairs stack, and the labels line up under one another', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(900, 420),
      );

      // Two ROWS, not one run: this is the whole shape the block was moved
      // into, and a Row that quietly laid all four out side by side would
      // still pass every text assertion above it.
      final a = tester.getTopLeft(find.text(t.solarAIndex));
      final kp = tester.getTopLeft(find.text(t.solarKIndex));
      expect(kp.dy, greaterThan(a.dy), reason: 'Kp sits under A, not beside it');
      expect(kp.dx, a.dx, reason: 'the labels are what an operator scans, so they align');
      await endOfTest(tester);
    });

    testWidgets('draws the band grid with both day and night', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
      );

      // Both columns, always: this panel has no location — which is the whole
      // reason it needs no settings — so which of the two is in force is not
      // something it can know, and picking one would be a guess an operator
      // cannot see through.
      expect(find.text(t.solarBandDay), findsOneWidget);
      expect(find.text(t.solarBandNight), findsOneWidget);
      expect(find.text('80m-40m'), findsOneWidget);
      expect(find.text(t.solarBandPoor), findsOneWidget, reason: '12m-10m at night');
      await endOfTest(tester);
    });

    testWidgets('the block never overflows, whatever the pane width', (tester) async {
      // The block scales rather than sheds, which means the failure it can
      // have is not a missing number — it is a Row wider than the pane. A
      // FittedBox is what prevents that, and a FittedBox given unbounded
      // width does not.
      for (final width in [900.0, 620.0, 460.0, 360.0, 280.0, 200.0, 140.0]) {
        await pump(
          tester,
          fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
          size: Size(width, 420),
        );

        expect(tester.takeException(), isNull, reason: 'the block overflowed at width $width');
        // The flux survives every width — it is what a pane this narrow
        // exists to show.
        expect(find.text('SFI 143'), findsOneWidget, reason: 'the flux went at width $width');
        await endOfTest(tester);
      }
    });
  });

  group('labels on the charts', () {
    /// The Kp chart's painter, which is where the labels now live: they are
    /// drawn onto the canvas, so there is no Text widget to find. Asserting
    /// on the instruction list is the same bargain `panel_solar_charts_test`
    /// makes — a Canvas cannot be read back, a painter's inputs can.
    SolarKpChartPainter kpPainter(WidgetTester tester) => tester.widget<CustomPaint>(kpChart().last).painter! as SolarKpChartPainter;

    SolarLineChartPainter fluxPainter(WidgetTester tester) => tester.widget<CustomPaint>(fluxChart().last).painter! as SolarLineChartPainter;

    SolarLineChartPainter windPainter(WidgetTester tester) => tester.widget<CustomPaint>(windChart().last).painter! as SolarLineChartPainter;

    /// A mouse the test can move. Hover is a pointer KIND, not a gesture: a
    /// synthesized touch move produces no hover event at all, and a test
    /// written with one passes for the wrong reason forever.
    Future<TestGesture> mouse(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      return gesture;
    }

    testWidgets('says nothing until something points at it', (tester) async {
      // No standing labels at all. They crowded each other in a real pane and
      // the curve ran through them; the chart is the shape, and the reading
      // is what you ask it for.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(900, 600),
      );

      expect(fluxPainter(tester).labels, isEmpty);
      expect(kpPainter(tester).labels, isEmpty);
      await endOfTest(tester);
    });

    testWidgets('reads down as cause, then response', (tester) async {
      // Flux, wind, Kp. The first two are what the sun sent; the third is
      // what the earth's field made of it, so the pane reads top to bottom in
      // the order the physics happens.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory()),
        size: const Size(900, 700),
      );

      final flux = tester.getRect(fluxChart().last);
      final wind = tester.getRect(windChart().last);
      final kp = tester.getRect(kpChart().last);
      // A hair of tolerance: the bands are exactly adjacent, and an equal
      // split of an odd height lands the two edges a float's width apart.
      expect(wind.top, greaterThanOrEqualTo(flux.bottom - 0.01));
      expect(kp.top, greaterThanOrEqualTo(wind.bottom - 0.01));
      await endOfTest(tester);
    });

    testWidgets('a chart fills the width it is given', (tester) async {
      // The charts have no caption to give the band its width any more, and a
      // `CustomPaint` with no child collapses to nothing under loose
      // constraints. A chart that drew, hit-tested and hovered as a
      // zero-width strip is invisible in a way every painter test above still
      // passes through.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(900, 600),
      );

      expect(tester.getRect(kpChart().last).width, 900);
      expect(tester.getRect(fluxChart().last).width, 900);
      await endOfTest(tester);
    });

    testWidgets('hovering a bar reads it out, with the hour it covers', (tester) async {
      // Ending AT now, not after it: the window these charts are sliced
      // against is bounded at both ends, so a fixture whose last point is in
      // the future quietly loses it and every index below shifts.
      final at = nowUtc().subtract(const Duration(hours: 9));
      final kp =
          '[${[
            for (final (index, value) in [4, 2, 7, 3].indexed) '{"time_tag":"${at.add(Duration(hours: index * 3)).toIso8601String().split('.').first}","Kp":$value}',
          ].join(',')}]';
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kp),
        size: const Size(900, 600),
      );

      final pointer = await mouse(tester);
      final chart = tester.getRect(kpChart().last);
      // The second of four bars.
      await pointer.moveTo(Offset(chart.left + chart.width * 0.30, chart.center.dy));
      await tester.pump();

      final label = kpPainter(tester).labels.single;
      expect(label.index, 1);
      expect(label.metric, '${t.solarKIndex} 2');
      // Date AND time: a bar is one three-hour period, and three days of them
      // means a date alone names eight different bars.
      final when = at.add(const Duration(hours: 3));
      expect(label.detail, contains(DateFormat('HH:mm').format(when)));
      expect(label.detail, endsWith('z'), reason: 'UTC, like every other time in the app');
      await endOfTest(tester);
    });

    testWidgets('the flux curve names the hour too, since the day has three', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory()),
        size: const Size(900, 700),
      );

      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(fluxChart().last));
      await tester.pump();

      final label = fluxPainter(tester).labels.single;
      expect(label.metric, startsWith('SFI '));
      // F10.7 is observed at 17:00, 20:00 and 22:00 UT, so a date alone would
      // name three different marks.
      expect(label.detail, contains(':'));
      expect(label.detail, endsWith('z'));
      await endOfTest(tester);
    });

    testWidgets('one pointer, three answers, all at the same instant', (tester) async {
      // The question an operator has is never about one series — it is
      // whether the wind that arrived on Tuesday is the wind that shut the
      // band — so pointing at any chart answers on all of them.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(hours: 168), wind: windSeries(), windHistoryBody: windHistory()),
        size: const Size(900, 700),
      );

      final pointer = await mouse(tester);
      final bars = tester.getRect(kpChart().last);
      await pointer.moveTo(Offset(bars.left + bars.width * 0.4, bars.center.dy));
      await tester.pump();

      expect(kpPainter(tester).labels, hasLength(1));
      expect(windPainter(tester).labels, hasLength(1), reason: 'the wind answered too');
      expect(fluxPainter(tester).labels, hasLength(1), reason: 'and so did the flux');

      // And they are answering the SAME moment, not the same position: the
      // flux has three marks a day where the other two have eight, so equal
      // indices would be different days.
      final kpLabel = kpPainter(tester).labels.single;
      final windLabel = windPainter(tester).labels.single;
      expect(windLabel.detail, kpLabel.detail, reason: 'wind and Kp share a grid, so they name the same period');
      await endOfTest(tester);
    });

    testWidgets('and stops reading out when the pointer leaves', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(900, 600),
      );

      final pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(kpChart().last));
      await tester.pump();
      expect(kpPainter(tester).labels, hasLength(1));

      // Off the chart entirely. A readout that outlived the pointer would be
      // claiming the operator is still asking about a bar they have left.
      await pointer.moveTo(tester.getTopLeft(find.text('SFI 143')));
      await tester.pump();

      expect(kpPainter(tester).labels, isEmpty);
      await endOfTest(tester);
    });
  });

  group('what a small pane sheds', () {
    testWidgets('numbers outlive the graphics', (tester) async {
      final fetch = answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries());

      // A chart nobody can read the axis of is decoration; "K 1" in a 90pt
      // pane is still the reason the band went quiet. So as the pane shrinks
      // the charts go first, then the grid, and the headline is last.
      await pump(tester, fetch: fetch, size: const Size(440, 420));
      expect(fluxChart(), findsOneWidget);
      expect(find.text(t.solarBandDay), findsOneWidget);
      await endOfTest(tester);

      // 300 rather than 280: the credit line at the foot is a line the pane
      // now always pays for before any section above it chooses, so every
      // size in this ladder carries it.
      await pump(tester, fetch: fetch, size: const Size(440, 300));
      expect(fluxChart(), findsNothing, reason: 'the curve goes first');
      expect(kpChart(), findsOneWidget);
      expect(find.text(t.solarBandDay), findsOneWidget);
      await endOfTest(tester);

      await pump(tester, fetch: fetch, size: const Size(440, 160));
      expect(kpChart(), findsNothing);
      expect(find.text(t.solarBandDay), findsNothing);
      expect(find.text(t.solarAIndex), findsOneWidget, reason: 'the pairs outlast the grid');
      expect(find.text('SFI 143'), findsOneWidget);
      await endOfTest(tester);

      await pump(tester, fetch: fetch, size: const Size(440, 90));
      expect(find.text(t.solarAIndex), findsNothing);
      expect(find.text('SFI 143'), findsOneWidget, reason: 'the headline is what must survive every size');
      await endOfTest(tester);
    });

    testWidgets('the wind curve is the first chart to go', (tester) async {
      final fetch = answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory());

      await pump(tester, fetch: fetch, size: const Size(440, 700));
      expect(windChart(), findsOneWidget);
      await endOfTest(tester);

      // An hour of a quiet wind is a flat line, and the band it takes is one
      // the flux month and the Kp bars both use better.
      await pump(tester, fetch: fetch, size: const Size(440, 420));
      expect(windChart(), findsNothing);
      expect(fluxChart(), findsOneWidget);
      expect(kpChart(), findsOneWidget);
      await endOfTest(tester);
    });

    testWidgets('a pane too small for one line of type draws nothing at all', (tester) async {
      // A Column cannot shrink a Text, so what happens instead of standing
      // down is a RenderFlex overflow on every frame — in a pane far too
      // small to read. The dock only enforces its 120pt minimum while
      // DRAGGING, so a layout saved in a big window reopens at sizes like
      // this.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(440, 30),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('SFI 143'), findsNothing);
      await endOfTest(tester);
    });

    testWidgets('a narrow pane drops the grid rather than crushing it', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries()),
        size: const Size(120, 420),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(t.solarBandDay), findsNothing);
      await endOfTest(tester);
    });
  });

  group('at OS text sizes', () {
    // Every section floor gates a band of TYPE, and type grows with the OS
    // text size while the pane does not. Compared raw, a section keeps its
    // place in the Column while taking half again its budget — and a Column
    // cannot shrink a Text, so what happens is a RenderFlex overflow on every
    // frame, for an operator who did nothing but turn system text up.
    //
    // A sweep rather than three cases: the bug is not at one size, it is in a
    // BAND either side of each floor, and which band moves whenever a floor
    // does.
    for (final scale in [1.0, 1.3, 1.6, 2.0, 2.5, 3.0]) {
      testWidgets('nothing overflows at textScaler $scale', (tester) async {
        final fetch = answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries());
        for (final height in [40.0, 47.0, 54.0, 70.0, 90.0, 110.0, 140.0, 200.0, 210.0, 224.0, 240.0, 270.0, 300.0, 330.0, 420.0]) {
          for (final width in [120.0, 162.0, 184.0, 240.0, 440.0]) {
            await pump(tester, fetch: fetch, size: Size(width, height), textScale: scale);
            expect(tester.takeException(), isNull, reason: 'overflowed at ${width}x$height, textScaler $scale');
            await endOfTest(tester);
          }
        }
      });
    }
  });

  group('three services, one panel', () {
    testWidgets('a failing history fetch costs its own chart and nothing else', (tester) async {
      // The megabyte is the one request that can plausibly fail on its own —
      // 1.13MB over a summit's cellular link — and it must not take the round
      // with it or be re-asked inside it.
      await pump(
        tester,
        fetch: answering(
          solar: conditions(),
          flux: fluxSeries(),
          kp: kpSeries(),
          wind: windSeries(minutes: 1),
          windHistoryBody: windHistory(),
          failWindHistory: true,
        ),
        size: const Size(440, 700),
      );

      expect(requested.where((url) => url == solarWindHistoryUrl()), hasLength(1));
      expect(find.text('SFI 143'), findsOneWidget, reason: 'the round still landed');
      expect(fluxChart(), findsOneWidget, reason: 'and the other series still drew');
      expect(kpChart(), findsOneWidget);
      expect(windChart(), findsNothing, reason: 'the failed history leaves too few points for its chart');
      await endOfTest(tester);
    });

    // NOT covered here, and worth knowing: that a SECOND round does not ask
    // for the megabyte again. `_windHistoryAtReal` is private to the State
    // and the retry floor runs on the real clock, so no widget test can reach
    // the second round. What holds it is that the stamp is written before
    // the await, whatever the answer — see `_fetchWindHistory`.

    testWidgets('the week waits until hamqsl has answered', (tester) async {
      // Asked beside hamqsl, the megabyte shares a slow link with the one
      // request the pane cannot draw without, inside that request's eight
      // seconds — and the operator is told "no network" while the network is
      // busy fetching for them.
      final hamqsl = Completer<({int status, String body})>();
      final others = answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory());
      await pump(
        tester,
        fetch: (url) {
          if (url != solarConditionsUrl()) return others(url);
          requested.add(url);
          return hamqsl.future;
        },
        size: const Size(900, 700),
      );
      expect(requested, isNot(contains(solarWindHistoryUrl())));

      hamqsl.complete((status: 200, body: conditions()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(requested.where((url) => url == solarWindHistoryUrl()), hasLength(1));
      // More marks than the hourly feed can make, so these are the week's —
      // which reach the screen only through a rebuild after the round's own.
      final wind = tester.widget<CustomPaint>(windChart().last).painter! as SolarLineChartPainter;
      expect(wind.values.length, greaterThan(2));
      await endOfTest(tester);
    });

    testWidgets('a pane hidden while hamqsl answers does not ask for the week', (tester) async {
      // A tab switched or an app backgrounded mid-round would otherwise pull
      // the megabyte for a chart nobody sees — and on a suspended app spend
      // the six-hour stamp on a request that cannot finish.
      final hamqsl = Completer<({int status, String body})>();
      final others = answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory());
      Future<({int status, String body})> fetch(Uri url) {
        if (url != solarConditionsUrl()) return others(url);
        requested.add(url);
        return hamqsl.future;
      }

      await pump(tester, fetch: fetch);
      await pump(tester, fetch: fetch, dockVisible: false);
      hamqsl.complete((status: 200, body: conditions()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(requested, contains(solarConditionsUrl()), reason: 'the round itself did run');
      expect(requested, isNot(contains(solarWindHistoryUrl())));
      await endOfTest(tester);
    });

    testWidgets('asks all five on the first round, once each', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries()),
      );

      // Five: hamqsl, the flux, the Kp, the wind hour, and — once the first
      // round has landed — the wind WEEK.
      expect(requested, hasLength(5));
      expect(requested.map((u) => u.host), containsAll(['www.hamqsl.com', 'services.swpc.noaa.gov']));
      await endOfTest(tester);
    });

    testWidgets('SWPC failing costs its chart and nothing else', (tester) async {
      // The two series are ADDITIVE. Treating either as fatal would blank a
      // pane whose headline numbers and band grid arrived perfectly well —
      // and SWPC is the service most likely to be the one that is down.
      await pump(tester, fetch: answering(solar: conditions(), flux: null, kp: null));

      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.text(t.solarBandDay), findsOneWidget);
      expect(fluxChart(), findsNothing);
      expect(kpChart(), findsNothing);
      await endOfTest(tester);
    });

    testWidgets('hamqsl failing leaves the pane with nothing to show', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: null, flux: fluxSeries(), kp: kpSeries()),
      );

      // It carries every headline number and the whole grid; a pane holding
      // only two SWPC curves would be a solar panel with no solar reading on
      // it.
      expect(find.text(t.solarUnreachable), findsOneWidget);
      // Nor is the megabyte asked for: there is no reading to draw it on, and
      // on the slow link most likely to have failed hamqsl it is the most
      // expensive thing the pane could do next.
      expect(requested, isNot(contains(solarWindHistoryUrl())));
      await endOfTest(tester);
    });
  });

  group('a good reading with a failed refresh behind it', () {
    /// The readout with a reading already in hand. The pane's own refresh
    /// cannot be driven from here — the retry floor runs on the real clock
    /// and staleness on the app clock, and `fakeAsync` moves neither — so
    /// this state, which takes two rounds to reach, is built directly.
    Future<void> pumpReadout(WidgetTester tester, {required bool staleFetch, Size size = const Size(440, 420)}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final reading = parseSolarReading(conditions(), fetchedAtUtc: nowUtc())!;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: solarReadoutForTest(reading: reading, staleFetch: staleFetch),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('says so with a shape, not only a colour', (tester) async {
      await pumpReadout(tester, staleFetch: false);
      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.byIcon(MdiIcons.alertOutline), findsNothing, reason: 'nothing stale yet');
      await endOfTest(tester);

      await pumpReadout(tester, staleFetch: true);
      // The reading STAYS — a failed refresh must never erase a good one —
      // but it stops claiming to be current. An error colour on the age text
      // is not enough on its own: it is invisible to a red-green deficiency,
      // and to anyone who has never seen that text in its other colour.
      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.byIcon(MdiIcons.alertOutline), findsOneWidget);
      await endOfTest(tester);
    });

    testWidgets('still says so in a pane too small for the stamp', (tester) async {
      // Where the stamp is dropped for want of room, the news it carries has
      // to go somewhere — and a pane this size is where a stale number looks
      // most current.
      await pumpReadout(tester, staleFetch: true, size: const Size(150, 200));

      expect(find.text('SFI 143'), findsOneWidget);
      expect(find.text(t.panelAgeNow), findsNothing, reason: 'the stamp is gone at this width');
      expect(find.byIcon(MdiIcons.alertOutline), findsOneWidget);
      await endOfTest(tester);
    });
  });

  group('failures the operator is told apart', () {
    testWidgets('an answer that is not a reading is not "no network"', (tester) async {
      // Told "no network", an operator goes hunting for signal — wasted
      // effort when the truth is a reshaped feed or a captive portal's login
      // page, neither of which they can do anything about.
      await pump(
        tester,
        fetch: answering(solar: '<html>hello</html>', flux: fluxSeries(), kp: kpSeries()),
      );

      expect(find.text(t.solarUnreadable), findsOneWidget);
      expect(find.text(t.solarUnreachable), findsNothing);
      await endOfTest(tester);
    });

    testWidgets('a non-200 is an answer, not a silence', (tester) async {
      await pump(
        tester,
        fetch: answering(solar: 'Service Unavailable', flux: fluxSeries(), kp: kpSeries(), status: 503),
      );

      expect(find.text(t.solarUnreadable), findsOneWidget);
      await endOfTest(tester);
    });
  });

  group('when it asks', () {
    testWidgets('a hidden pane does not fetch', (tester) async {
      // A pane in a dock group stays MOUNTED behind its neighbour, so without
      // the visibility gate every solar pane in a saved layout keeps three
      // fetches running for a view nobody is looking at.
      await pump(tester, fetch: answering(solar: conditions()), dockVisible: false);

      expect(requested, isEmpty);
      await endOfTest(tester);
    });

    testWidgets('a hidden pane does not lay out either', (tester) async {
      // The dock keeps a group's panes in an `IndexedStack`, which paints only
      // the selected one but LAYS OUT all of them. Without this, the three
      // tabs behind the front one each rebuild a numbers block, a band grid
      // and three charts on every frame of a pane being dragged — which is
      // what a divider that moves in steps rather than following the pointer
      // is made of.
      await pump(
        tester,
        fetch: answering(solar: conditions(), flux: fluxSeries(), kp: kpSeries(), wind: windSeries(), windHistoryBody: windHistory()),
        dockVisible: false,
        size: const Size(900, 700),
      );

      expect(find.text('SFI 143'), findsNothing);
      expect(fluxChart(), findsNothing);
      expect(kpChart(), findsNothing);
      expect(windChart(), findsNothing);
      await endOfTest(tester);
    });

    test('the megabyte is asked for once, then not again for six hours', () {
      final real = realNowUtc();

      // The whole point of splitting the wind into two feeds. Asked for every
      // round it would be ~54MB a day with the pane open; this is what makes
      // it ~1.5MB.
      expect(solarWindHistoryIsDue(fetchedAtReal: null, realNow: real), isTrue);
      expect(solarWindHistoryIsDue(fetchedAtReal: real, realNow: real), isFalse);
      expect(solarWindHistoryIsDue(fetchedAtReal: real, realNow: real.add(solarWindHistoryInterval - const Duration(minutes: 1))), isFalse);
      expect(solarWindHistoryIsDue(fetchedAtReal: real, realNow: real.add(solarWindHistoryInterval)), isTrue);
    });

    test('the retry floor outranks everything, including having no reading', () {
      final real = realNowUtc();
      final now = nowUtc();

      // Every visibility change reaches the refresh, and a failing round
      // leaves `_reading` null — so without the floor an operator with no
      // signal, switching between two dock tabs, sends a request per switch.
      expect(solarFetchIsDue(attemptedAtReal: real, realNow: real, reading: null, now: now), isFalse);
      expect(solarFetchIsDue(attemptedAtReal: null, realNow: real, reading: null, now: now), isTrue);
    });

    test('a reading goes stale on the APP clock, and the floor runs on the real one', () {
      final real = realNowUtc();
      final now = nowUtc();
      final fresh = _readingAt(now);

      // Two clocks on purpose (docs/design/time.md): staleness follows DEVTT
      // so the panel ages in step with the rest of the app, while the request
      // pacing must NOT travel — a developer jumping a day forward must not
      // turn into a burst against three third parties.
      expect(solarFetchIsDue(attemptedAtReal: real.subtract(const Duration(minutes: 5)), realNow: real, reading: fresh, now: now), isFalse);
      expect(
        solarFetchIsDue(attemptedAtReal: real.subtract(const Duration(minutes: 5)), realNow: real, reading: fresh, now: now.add(solarMaxAge)),
        isTrue,
        reason: 'the app clock moved past maxAge; the real one did not move at all',
      );
    });
  });
}

SolarReading _readingAt(DateTime fetchedAtUtc) => SolarReading(
  solarFlux: 143,
  sunspots: 83,
  aIndex: 6,
  kIndex: 1,
  xray: null,
  geomagneticField: null,
  signalNoise: null,
  heliumLine: null,
  solarWind: null,
  bands: const [],
  fetchedAtUtc: fetchedAtUtc,
);

/// Stands in for a transport failure — anything that is not the panel's own
/// "the service answered badly" exception.
class SocketishFailure implements Exception {
  const SocketishFailure();
}
