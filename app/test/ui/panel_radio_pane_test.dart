// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Radio pane shows for a radio in each of the states it can be in.
//
// The states that matter are not "connected or not": a session can be alive
// at the protocol level while the stream carrying readings is dead
// (docs/design/cat.md), and cat.md records having shipped exactly that — a
// confident green status over a frequency from several minutes earlier. So
// STALE has to read as off here, and these tests are what keeps it that way.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/views/operation/radio/radio_faces.dart';
import 'package:ham2k_logger/views/operation/radio/radio_panel.dart';

/// A reading as fresh as one that just arrived off the radio.
MeterReading justRead(num value) => MeterReading(value, nowMillis());

void main() {
  final p = t.operation.layout.panels;

  const node = EquipmentNode(uuid: 'u1', typeKey: 'fake', name: 'Left Radio');
  const palette = RadioPalette(face: Colors.black, ink: Colors.amber, label: Colors.amber);

  Future<void> pumpReadout(
    WidgetTester tester, {
    EquipmentNode? node,
    required EquipmentState state,
    required bool live,
    num? power,
    Set<RadioMeter> meters = const {},
    String style = radioStyleModern,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RadioReadout(
            node: node,
            state: state,
            live: live,
            style: style,
            palette: live ? palette : palette.dimmed(0.3),
            power: power,
            meters: meters,
            onTune: null,
            powerButton: node == null
                ? null
                : RadioPowerButton(
                    status: state.status,
                    accent: palette.ink,
                    palette: palette,
                    style: style,
                    height: 22,
                    onPressed: () {},
                  ),
          ),
        ),
      ));

  testWidgets('a connected radio shows where it actually is, to the Hz', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(
        status: EquipmentStatus.connected,
        vfo: VfoReading(freqKHz: 14074.123, mode: 'USB'),
      ),
      live: true,
      power: 5,
    );
    // Split the way a QSO row splits one, so the digits an operator's eye is
    // trained to land on carry the same weight wherever a frequency appears:
    // MHz bold, kHz regular, Hz smaller.
    final mhz = tester.widget<Text>(find.text('14'));
    final khz = tester.widget<Text>(find.text('074'));
    final hz = tester.widget<Text>(find.text('123'));
    expect(mhz.style?.fontWeight, equals(FontWeight.w700));
    expect(khz.style?.fontWeight, isNot(equals(FontWeight.w700)));
    // Always three Hz digits here, unlike a QSO row's operation-wide count:
    // a width that changed as the last digits settled would twitch on every
    // report from the radio.
    expect(hz.style?.fontSize, lessThan(khz.style!.fontSize!));
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('5 ${p.radioWatts}'), findsOneWidget);
  });

  testWidgets('a disconnected radio still shows a power button to bring it up', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.disconnected),
      live: false,
    );
    expect(find.bySemanticsLabel(p.radioConnect), findsOneWidget);
  });

  testWidgets('a connected radio names its button Disconnect, not Connect', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.connected),
      live: true,
    );
    // The button is a SWITCH, not a one-way "fix this" prompt — a connected
    // radio that offered only "Connect" would leave no way down from here.
    expect(find.bySemanticsLabel(p.radioDisconnect), findsOneWidget);
  });

  testWidgets('a connect already in flight cannot be pressed again', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.connecting),
      live: false,
    );
    // CatService's own attempt sequence would supersede the first attempt,
    // leaving the operator watching a connection they did not start.
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });

  testWidgets('with no radio to show, the pane says so instead of drawing a dead display', (tester) async {
    await pumpReadout(tester, node: null, state: const EquipmentState(), live: false);
    expect(find.text(p.radioNoRadio), findsOneWidget);
    // No power button: there is nothing to switch on.
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a radio that is merely off shows no reading at all', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.disconnected),
      live: false,
    );
    // CatService installs a FRESH EquipmentState on disconnect, on a dropped
    // link and on a failed connect, so `vfo` is wiped in all three — a
    // disconnected state carrying a frequency is not a state the service can
    // produce, and a test that hand-built one would assert a behaviour that
    // never occurs while hiding the stale case behind it.
    expect(find.bySemanticsLabel(p.radioOff), findsOneWidget);
  });

  testWidgets('a failed connect shows the reason, not the same dark glass as "off"', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.error, error: 'Serial port in use'),
      live: false,
    );
    // CatService already translated this into something the operator can act
    // on. Collapsing it into "not connected" is what makes the power button
    // feel like it did nothing: press, flicker, identical panel, press again.
    expect(find.text('Serial port in use'), findsOneWidget);
    expect(find.bySemanticsLabel('Serial port in use'), findsOneWidget);
    expect(find.bySemanticsLabel(p.radioOff), findsNothing);
  });

  testWidgets('a stale session says its reading is old, and does not claim to be disconnected', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(
        status: EquipmentStatus.connected,
        stale: true,
        vfo: VfoReading(freqKHz: 7025.0, mode: 'CW'),
      ),
      live: false,
    );
    // The one state where dimmed digits actually appear: connected, readings
    // dead, the number minutes old. Announcing "not connected" here is false
    // and actively harmful — it sends the operator to reconnect a session
    // that is already up, instead of telling them the stream died.
    expect(find.text(p.radioStale), findsOneWidget);
    expect(find.bySemanticsLabel(p.radioOff), findsNothing);
    // The digits stay: they are still roughly where the rig is, and the
    // marker beside them says how much to trust that.
    expect(find.text('025'), findsOneWidget);
    expect(tester.widget<Text>(find.text('025')).style?.color?.a, lessThan(1.0));
  });

  testWidgets('the power slot shows only what the radio itself reported', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.disconnected),
      live: false,
      power: null,
    );
    // A dark panel printing the operator's manual Power setting would be a
    // claim about a rig that is not talking, in the slot reserved for a
    // measurement.
    expect(find.textContaining(p.radioWatts), findsNothing);
  });

  testWidgets('mode sits at the left of the row above the frequency, power at the right', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(
        status: EquipmentStatus.connected,
        vfo: VfoReading(freqKHz: 14074.123, mode: 'USB'),
      ),
      live: true,
      power: 5,
    );
    final modeX = tester.getTopLeft(find.text('USB')).dx;
    final powerX = tester.getTopLeft(find.text('5 ${p.radioWatts}')).dx;
    final freqY = tester.getTopLeft(find.text('074')).dy;
    // The two corners a rig's own display puts them in — and above the
    // frequency, which is what lets it have the full width rather than
    // sharing a line with them.
    expect(modeX, lessThan(powerX));
    expect(tester.getBottomLeft(find.text('USB')).dy, lessThanOrEqualTo(freqY));
  });

  testWidgets('the LCD spells the mode as a legend, never as segments', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(
        status: EquipmentStatus.connected,
        vfo: VfoReading(freqKHz: 7025.0, mode: 'CW'),
      ),
      live: true,
      style: radioStyleLcd,
      power: 100,
    );
    // There is no `W` on a seven-segment cell, so a segment-rendered mode
    // would be wrong for exactly the modes an operator most needs to trust.
    // A real display prints these as fixed legends that light up.
    expect(find.byType(LcdAnnunciator), findsOneWidget);
    expect(find.text('CW'), findsOneWidget);
  });

  testWidgets('the power button is bright when the radio is up and dim when it is down', (tester) async {
    Future<double?> alphaAt(EquipmentStatus status) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(status: status),
        live: status == EquipmentStatus.connected,
        style: radioStyleLcd,
      );
      return tester.widget<Icon>(find.descendant(of: find.byType(RadioPowerButton), matching: find.byType(Icon))).color?.a;
    }

    final up = await alphaAt(EquipmentStatus.connected);
    final down = await alphaAt(EquipmentStatus.disconnected);
    // The state of the thing, the way a rig's own power lamp reads — NOT a
    // prompt that lights up when there is something to press. Inverting this
    // is the tempting change: the button is most useful while the radio is
    // down, so an affordance argument says light it there. Every other lit
    // indicator in a shack means "this is running", and one that disagreed
    // would be read wrong at a glance.
    expect(down, lessThan(up!));
  });

  testWidgets('the power button fits the annunciator row rather than setting its height', (tester) async {
    await pumpReadout(
      tester,
      node: node,
      state: const EquipmentState(status: EquipmentStatus.connected),
      live: true,
    );
    // Material's default IconButton is 48px. Left at that, it would set the
    // height of the row built to sit ABOVE the frequency and leave the digits
    // whatever was left of a short pane.
    expect(tester.getSize(find.byType(RadioPowerButton)).height, equals(22));
  });

  group('the meter strip', () {
    /// A reading as fresh as one that just arrived off the radio.

    testWidgets('a keyed radio says TX and shows what its meters read', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          vfo: const VfoReading(freqKHz: 14074.0, mode: 'USB'),
          telemetry: RadioTelemetry(
            transmitting: true,
            meters: {
              RadioMeter.powerOut: justRead(48),
              RadioMeter.swr: justRead(1.3),
              RadioMeter.supplyVolts: justRead(13.8),
            },
          ),
        ),
        live: true,
        power: 100,
        meters: const {RadioMeter.powerOut, RadioMeter.swr, RadioMeter.supplyVolts},
      );
      expect(find.text(p.radioTransmitting), findsOneWidget);
      // The measured output, NOT the 100 W the radio is set to: the whole
      // reason powerOut is a meter and Vfo.power is not.
      expect(find.text('48 ${p.radioWatts}'), findsOneWidget);
      expect(find.text('${p.radioSwr} 1.3'), findsOneWidget);
      expect(find.text('13.8 ${p.radioVolts}'), findsOneWidget);
    });

    testWidgets('an SWR past the alert threshold is coloured and named', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.swr: justRead(2.4)}),
        ),
        live: true,
        meters: const {RadioMeter.swr},
      );
      final reading = tester.widget<Text>(find.text('${p.radioSwr} 2.4'));
      final context = tester.element(find.text('${p.radioSwr} 2.4'));
      expect(reading.style?.color, Theme.of(context).colorScheme.error);
      // Colour alone is never the whole message — an operator who cannot use
      // hue reads a red 2.4 as a black one (the same defect HALO-450 records
      // for the Radio control), and a screen reader reads digits that say
      // nothing about whether 2.4 is a problem.
      expect(find.bySemanticsLabel(RegExp(p.radioSwrHigh)), findsOneWidget);
      expect(find.byIcon(MdiIcons.alertOutline), findsOneWidget);
    });

    testWidgets('a healthy SWR is not dressed up as a warning', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.swr: justRead(1.7)}),
        ),
        live: true,
        meters: const {RadioMeter.swr},
      );
      // Just under the line, which is where an off-by-one lives.
      expect(find.byIcon(MdiIcons.alertOutline), findsNothing);
    });

    testWidgets('a reading nobody has refreshed stops being shown', (tester) async {
      // The failure this prevents: meters are read only while transmitting,
      // so every reading STOPS being refreshed at the end of every over. A
      // strip that kept the last value would show the SWR of a transmission
      // from an hour ago, on a different band, as though it were current.
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(
            meters: {
              RadioMeter.swr: MeterReading(2.4, nowMillis() - meterLinger.inMilliseconds - 1000),
            },
          ),
        ),
        live: true,
        meters: const {RadioMeter.swr},
      );
      expect(find.text('${p.radioSwr} 2.4'), findsNothing);
      expect(find.byIcon(MdiIcons.alertOutline), findsNothing);
      // The slot keeps its label rather than emptying: a strip that vanished
      // between overs would read as a fault, when the truth is only that the
      // radio is receiving.
      expect(find.text(p.radioSwr), findsOneWidget);
    });

    testWidgets('a radio whose driver reads no meters gets no strip at all', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: const EquipmentState(status: EquipmentStatus.connected),
        live: true,
      );
      expect(find.text(p.radioSwr), findsNothing);
    });
  });
  group('the meter bars', () {
    MeterBarPainter painterFor(WidgetTester tester, {required Finder within}) => tester
        .widgetList<CustomPaint>(find.descendant(of: within, matching: find.byType(CustomPaint)))
        .map((p) => p.painter)
        .whereType<MeterBarPainter>()
        .single;

    testWidgets('the SWR bar turns red where the operator is warned, not at the end', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.swr: MeterReading(2.0, nowMillis())}),
        ),
        live: true,
        meters: const {RadioMeter.swr},
      );
      final painter = painterFor(tester, within: find.byType(RadioReadout));
      // 1.0-3.0 across the bar, so the 1.8 threshold sits at 40% of it and
      // 2.0 lights half. A scale that started its red zone at the END would
      // mean the bar never disagreed with the number beside it about
      // anything, which is the whole reason it is there.
      expect(painter.alertFrom, closeTo(0.4, 0.001));
      expect(painter.fraction, closeTo(0.5, 0.001));
    });

    testWidgets('the red zone is drawn before the operator reaches it', (tester) async {
      // A meter face prints its red zone whether the needle is in it or not.
      // Painting it only once crossed would be a bar that says "fine" right
      // up to the moment it says "bad", with no sense of how close.
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.swr: MeterReading(1.1, nowMillis())}),
        ),
        live: true,
        meters: const {RadioMeter.swr},
      );
      expect(painterFor(tester, within: find.byType(RadioReadout)).alertFrom, closeTo(0.4, 0.001));
    });

    testWidgets('power is measured against what the radio was ASKED for', (tester) async {
      // No protocol here states a radio's rated maximum, so a "full power"
      // scale would be invented. The set level is a real number the operator
      // chose, and the question the bar answers — am I making what I asked
      // for? — is the one they actually have.
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.powerOut: MeterReading(25, nowMillis())}),
        ),
        live: true,
        power: 100,
        meters: const {RadioMeter.powerOut},
      );
      expect(painterFor(tester, within: find.byType(RadioReadout)).fraction, closeTo(0.25, 0.001));
    });

    testWidgets('a reading above the set power widens the scale rather than overflowing', (tester) async {
      await pumpReadout(
        tester,
        node: node,
        state: EquipmentState(
          status: EquipmentStatus.connected,
          telemetry: RadioTelemetry(transmitting: true, meters: {RadioMeter.powerOut: MeterReading(60, nowMillis())}),
        ),
        live: true,
        power: 50,
        meters: const {RadioMeter.powerOut},
      );
      expect(painterFor(tester, within: find.byType(RadioReadout)).fraction, 1.0);
    });

    testWidgets('a strip of four meters fits a narrow pane', (tester) async {
      // A Row gives a non-flex child unbounded width, so the plain readings
      // would take everything and the bars would collapse — the same shape
      // as the Wrap-in-a-Row overflow this codebase has been bitten by. The
      // wide test font makes this the case worth pinning: it is exactly what
      // the tightest Font Scale does to a real pane.
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 120,
                child: RadioReadout(
                  node: node,
                  state: EquipmentState(
                    status: EquipmentStatus.connected,
                    vfo: const VfoReading(freqKHz: 14074.0, mode: 'USB'),
                    telemetry: RadioTelemetry(
                      transmitting: true,
                      meters: {
                        RadioMeter.powerOut: justRead(48),
                        RadioMeter.swr: justRead(1.3),
                        RadioMeter.alc: justRead(0.4),
                        RadioMeter.supplyVolts: justRead(13.8),
                      },
                    ),
                  ),
                  live: true,
                  style: radioStyleModern,
                  palette: palette,
                  power: 100,
                  meters: const {
                    RadioMeter.powerOut,
                    RadioMeter.swr,
                    RadioMeter.alc,
                    RadioMeter.supplyVolts,
                  },
                  onTune: null,
                  powerButton: null,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('any reading at all lights a segment', () {
      // A 3 W reading against a 100 W set level rounds to nothing across ten
      // segments, and an empty bar during a real transmission reads as a
      // radio putting out zero — the one thing the strip must never say
      // while the rig is on the air.
      expect(MeterBarPainter.litSegments(0.03, 10), 1);
      expect(MeterBarPainter.litSegments(0, 10), 0, reason: 'nothing measured is still nothing');
      expect(MeterBarPainter.litSegments(0.5, 10), 5);
      expect(MeterBarPainter.litSegments(2.0, 10), 10, reason: 'past full scale pins, never overflows');
    });

    test('the segment straddling the threshold belongs to the side most of it is on', () {
      // Measured at the segment's middle. Measured at its leading edge, the
      // red zone would start one segment early on every bar in the app.
      expect(MeterBarPainter.isAlertSegment(3, 10, 0.4), isFalse);
      expect(MeterBarPainter.isAlertSegment(4, 10, 0.4), isTrue);
      expect(MeterBarPainter.isAlertSegment(9, 10, null), isFalse, reason: 'no zone, no red');
    });
  });

}
