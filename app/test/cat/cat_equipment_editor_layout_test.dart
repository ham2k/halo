// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The equipment editor's layout — Connection, then More — and its Other
// menu, as an operator adding a radio meets them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_models_other_radios.dart' show placeholderRadioModel;
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';
import 'package:ham2k_logger/views/station_panel.dart';
import '../support/fake_serial_ports.dart';
import '../support/halo_test_support.dart';

void main() {
  late HaLoServices services;

  setUp(() async {
    useSerialPortsForTest(const []);
    services = (await makeHaLoServices()).services;
  });

  /// Fixed pumps, never `pumpAndSettle`: the Add dialog runs a discovery
  /// spinner, and an animation that never ends is a settle that never
  /// arrives.
  Future<void> showPanel(WidgetTester tester) async {
    // Tall enough that the whole form fits above the pane's footer, which
    // otherwise sits over More at the test's default 800x600.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: StationPanel(services: services)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pick(WidgetTester tester, String query, String name) async {
    await showPanel(tester);
    await tester.tap(find.text(t.settings.station.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump();
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    final fold = find.text(t.settings.station.advancedSettings);
    await tester.ensureVisible(fold);
    await tester.tap(fold);
    await tester.pump();
    await tester.pump(collapseDuration);
  }

  /// The row a label belongs to, counted only where a tap would reach it: a
  /// shut fold keeps its rows mounted, and a field's own label never takes
  /// the hit (its decorator does), so a bare text finder passes either way.
  Finder reachable(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is InputDecorator || w is ListTile || w is CheckboxListTile || w is SwitchListTile),
      )
      .first
      .hitTestable();

  bool? checked(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is CheckboxListTile || w is SwitchListTile || w is ListTile));
    final box = find.descendant(of: row.first, matching: find.byType(Checkbox));
    if (box.evaluate().isNotEmpty) return tester.widget<Checkbox>(box.first).value;
    return tester.widget<Switch>(find.descendant(of: row.first, matching: find.byType(Switch)).first).value;
  }

  testWidgets('a serial radio folds its lines into the connection, closed, and keeps its cadences under More', (tester) async {
    await pick(tester, 'FT-817', t.settings.station.models.ft817);
    final st = t.settings.station;
    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(find.text(st.transport), findsOneWidget, reason: 'the Connection band');
    expect(find.text(st.moreBand), findsOneWidget);
    // The trap: the lines filed with the driver's cadences, away from the
    // port they configure — or More folded shut over cadences again.
    expect(top(st.serialPort), lessThan(top(st.advancedSettings)));
    expect(top(st.advancedSettings), lessThan(top(st.moreBand)));
    expect(top(st.moreBand), lessThan(top(st.pollInterval)));
    expect(reachable(st.serialPort), findsOneWidget);
    expect(reachable(st.pollInterval), findsOneWidget, reason: 'More is a band, not a fold');
    expect(reachable(st.serialRtsHigh), findsNothing, reason: 'closed until the operator asks');

    await openAdvanced(tester);
    expect(reachable(st.serialRtsHigh), findsOneWidget);
    expect(reachable(st.serialDtrHigh), findsOneWidget);
    expect(reachable(st.telemetryInterval), findsOneWidget);
    expect(reachable(st.pollInterval), findsOneWidget);
    // What the boxes open on is what the connection does: an unchecked box
    // over a line held high is the operator being lied to.
    expect(checked(tester, st.serialRtsHigh), isFalse);
    expect(checked(tester, st.serialDtrHigh), isFalse);
  });

  testWidgets('a new Kenwood opens with RTS held high, its CAT handshake', (tester) async {
    await pick(tester, 'TS-590', t.settings.station.models.ts590sg);
    await openAdvanced(tester);
    expect(checked(tester, t.settings.station.serialRtsHigh), isTrue);
    expect(checked(tester, t.settings.station.serialDtrHigh), isFalse);
  });

  testWidgets('a Kenwood saved before its RTS prefill opens low, and a save keeps it low', (tester) async {
    // The trap: the entry's prefill seeds a box the node never stored, so it
    // opens ticked over a line the connection holds low, and an unrelated
    // save — a rename — raises RTS, keying a Digirig on a radio that worked.
    useSerialPortsForTest(const [SerialPortOption(name: '/dev/cu.usbserial-1', productName: 'CP2102N')]);
    final node = await services.cat.addNode(typeKey: 'ts480-serial', name: 'Shack Rig', config: {'port': '/dev/cu.usbserial-1', 'baudRate': 9600});
    expect(node.config.containsKey(serialRtsHighConfigKey), isFalse, reason: 'sanity: the node predates the setting');

    await showPanel(tester);
    await tester.tap(find.text('Shack Rig').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await openAdvanced(tester);
    expect(checked(tester, t.settings.station.serialRtsHigh), isFalse);

    await tester.tap(find.text(t.common.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(services.cat.nodes.single.config[serialRtsHighConfigKey], isFalse);
  });

  testWidgets('a placeholder Kenwood switched to serial starts from the prefill', (tester) async {
    // The trap: holding an existing node's absent lines low reaches a node
    // whose pairing never reads them, and a switch to serial in the editor
    // then saves a Kenwood that waits for RTS with RTS low.
    await services.cat.addNode(typeKey: 'ts480-placeholder', name: 'Shack Rig', config: placeholderRadioModel.variants.single.defaultConfig);

    await showPanel(tester);
    await tester.tap(find.text('Shack Rig').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(services.cat.registry.typeFor('ts480-serial')!.transportLabel));
    await tester.pump();
    await openAdvanced(tester);
    expect(checked(tester, t.settings.station.serialRtsHigh), isTrue);
  });

  testWidgets('the troubleshooting notes close the form, under More', (tester) async {
    // The notes arrive among the connection's own fields, so a form that
    // only pulls the advanced ones out leaves them sitting between the
    // fields the operator is filling in.
    await pick(tester, 'FT-891', t.settings.station.models.ft891);
    final st = t.settings.station;

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top(st.troubleshootingNotes), greaterThan(top(st.moreBand)));
    expect(top(st.troubleshootingNotes), greaterThan(top(st.pollInterval)), reason: "below More's fields too, not just its band");
  });

  group('the connection tabs', () {
    String label(String typeKey) => services.cat.registry.typeFor(typeKey)!.transportLabel;

    testWidgets('a radio offers its own ways in and the placeholder; Bluetooth LE waits behind Other', (tester) async {
      // The trap: every pairing the catalogue derives as a tab of its own,
      // the same few on every radio, burying the ways this one connects.
      await services.settings.setExperimentEnabled('500mp' /* stored key, see experiments.yaml */, true);
      await pick(tester, 'FT-817', t.settings.station.models.ft817);
      final st = t.settings.station;

      expect(find.text(label('ft817-serial')), findsOneWidget);
      expect(find.text(label('ft817-placeholder')), findsOneWidget);
      expect(find.text(st.transportOther), findsOneWidget);
      expect(find.text(label('ft817-ble')), findsNothing, reason: 'in the menu, not a tab');

      await tester.tap(find.text(st.transportOther));
      // The menu is placed a frame after it opens; a tap before then lands
      // on the barrier and only closes it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(label('ft817-ble')).last);
      // A menu item acts after its menu closes, a frame later.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(label('ft817-ble')), findsOneWidget, reason: 'the pick is a tab now');
      double left(String text) => tester.getTopLeft(find.text(text)).dx;
      expect(left(label('ft817-ble')), lessThan(left(label('ft817-placeholder'))), reason: 'among the real connections, ahead of "no control"');
      expect(find.text(st.transportOther), findsNothing, reason: 'nothing is left behind it');

      // Back to USB: the picked pairing stays a tab, so a second look at it
      // costs no second trip through the menu.
      await tester.tap(find.text(label('ft817-serial')));
      await tester.pump();
      expect(find.text(label('ft817-ble')), findsOneWidget);
      expect(reachable(st.serialPort), findsOneWidget);
    });

    testWidgets('a radio already on Bluetooth LE opens with it as a tab', (tester) async {
      await services.settings.setExperimentEnabled('500mp' /* stored key, see experiments.yaml */, true);
      await services.cat.addNode(typeKey: 'ft817-ble', name: 'Trail Rig', config: const {});
      await showPanel(tester);
      await tester.tap(find.text('Trail Rig').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(label('ft817-ble')), findsOneWidget);
      expect(find.text(t.settings.station.transportOther), findsNothing, reason: 'its one extra is already a tab');
    });

    testWidgets("an antenna's bands come straight after its name, under no band", (tester) async {
      // The trap: an antenna's one real question under a band called More,
      // with nothing before it to be more than.
      await services.cat.addNode(typeKey: 'antenna-none', name: 'Dipole', config: const {});
      await showPanel(tester);
      // The inventory's section opens folded; its row, not the antenna-in-use
      // picker's copy of the name, opens the editor.
      await tester.tap(find.text(t.settings.station.sectionAntennas(count: 1)));
      await tester.pump();
      await tester.pump(collapseDuration);
      await tester.tap(find.text('Dipole').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final st = t.settings.station;
      expect(find.text(st.antennaBands), findsOneWidget);
      expect(find.text(st.transport), findsNothing);
      expect(find.text(st.moreBand), findsNothing);
    });

    testWidgets('with EXP 500MP off there is no Other, since nothing waits behind it', (tester) async {
      await pick(tester, 'FT-817', t.settings.station.models.ft817);
      expect(find.text(t.settings.station.transportOther), findsNothing);
      expect(find.text(label('ft817-ble')), findsNothing);
    });
  });
}
