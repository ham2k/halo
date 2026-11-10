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
import 'package:ham2k_logger/services/cat/drivers/antenna_genius_driver.dart' show switchPortNameConfigKey;
import 'package:ham2k_logger/services/cat/drivers/everyware_server.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_models_green_heron.dart';
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

  /// The input box a field's label belongs to.
  Rect box(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(InputDecorator)).first);

  testWidgets('an address sits beside its port, two to one, on every networked equipment', (tester) async {
    // A radio, not a rotator: the trap is pairing these fields for rotators only.
    await pick(tester, 'rigctld', t.settings.station.models.rigctld);
    final st = t.settings.station;
    final host = box(tester, st.host), port = box(tester, st.port);
    expect(port.top, host.top, reason: 'one line');
    expect(port.left, greaterThan(host.right));
    expect(host.width / port.width, closeTo(2, 0.1));
  });

  testWidgets("a radio's login is one line, half each", (tester) async {
    await pick(tester, 'IC-705', t.settings.station.models.ic705);
    final st = t.settings.station;
    final network = find.text(st.transports.wifi);
    if (network.evaluate().isNotEmpty) {
      await tester.tap(network.first);
      await tester.pump();
    }
    final user = box(tester, st.radioUser), password = box(tester, st.radioPass);
    expect(password.top, user.top, reason: 'one line');
    expect(user.width, closeTo(password.width, 1));
  });

  /// The editor of equipment saved as [typeKey], under "other" equipment.
  Future<EquipmentNode> editSaved(WidgetTester tester, String typeKey, String name, Map<String, dynamic> config) async {
    final node = await services.cat.addNode(typeKey: typeKey, name: name, config: config);
    await showPanel(tester);
    if (find.text(name).evaluate().isEmpty) {
      // The server, and any device it already made: every node here is "other".
      await tester.tap(find.text(t.settings.station.sectionOtherEquipment(count: services.cat.nodes.length)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return node;
  }

  /// The editor of an Everyware server saved with [config].
  Future<EquipmentNode> editServer(WidgetTester tester, Map<String, dynamic> config) =>
      editSaved(tester, everywareServerTypeKey, 'Shack server', {'host': '10.0.0.9', 'port': 17220, ...config});

  testWidgets('a switch port is named and wired on one line, and both are kept', (tester) async {
    final node = await editSaved(tester, 'sierra-coax-serial', 'Coax relay', const {});
    final st = t.settings.station;
    // Never connected, the CX-1's four ports are offered by number.
    final name = find.ancestor(of: find.text('1'), matching: find.byType(InputDecorator)).first;
    final antenna = find.ancestor(of: find.text(st.switchPortAntenna).first, matching: find.byType(InputDecorator)).first;
    // One line, aligned on the text: a select and a text box are laid out
    // differently above their baselines, so their tops do not quite agree.
    expect(tester.getRect(antenna).center.dy, closeTo(tester.getRect(name).center.dy, 12), reason: 'the antenna on the port sits beside the name');
    expect(tester.getRect(antenna).left, greaterThan(tester.getRect(name).right));

    await tester.enterText(find.descendant(of: name, matching: find.byType(EditableText)), 'Hex');
    await tester.tap(find.text(t.common.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(services.cat.nodeFor(node.uuid)!.config[switchPortNameConfigKey('1')], 'Hex');
  });

  testWidgets('Connection ends in Connect, and beside it what the connection says', (tester) async {
    await editServer(tester, const {});
    final st = t.settings.station;
    final connect = find.widgetWithText(TextButton, st.connect);
    // The station row's plug, unplugged, and no outline: a toggle, not a form button.
    expect(find.descendant(of: connect, matching: find.byIcon(MdiIcons.powerPlugOff)), findsOneWidget);
    expect(connect, findsOneWidget);
    // On the button's line, not under it: the answer belongs beside the
    // question, and a status line below reads as another field.
    expect(tester.getCenter(find.text(st.statusDisconnected)).dy, closeTo(tester.getCenter(connect).dy, 12));
    // Last in Connection: after its address, before what comes next.
    expect(tester.getTopLeft(connect).dy, greaterThan(tester.getTopLeft(find.text(st.host)).dy));
    expect(tester.getTopLeft(connect).dy, lessThan(tester.getTopLeft(find.text(st.everywareDevicesHeader)).dy));
  });

  testWidgets('a rotator under a server has Connect too, though it has no connection fields of its own', (tester) async {
    await editServer(tester, {
      everywareDevicesConfigKey: ['rotor:Tower 3'],
    });
    await tester.tap(find.text(t.common.cancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tower 3').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(TextButton, t.settings.station.connect), findsOneWidget);
  });

  testWidgets("a server lists every device it last had, each with a switch, and a save keeps the switches' word", (tester) async {
    final node = await editServer(tester, {
      everywareDevicesConfigKey: ['rotor:Tower 3'],
      everywareKnownDevicesConfigKey: [
        {'key': 'rotor:Tower 3'},
        {'key': 'switchBox:80m 4 sq', 'kind': 'map'},
        {'key': 'switchBox:Bank', 'kind': 'bank'},
      ],
    });
    final st = t.settings.station;
    Switch switchOf(String label) => tester.widget<Switch>(
      find.descendant(
        of: find.ancestor(of: find.text(label).last, matching: find.byType(ListTile)).first,
        matching: find.byType(Switch),
      ),
    );
    expect(find.text(st.everywareDevicesLastSeen), findsOneWidget, reason: 'listed while disconnected, and saying from when');
    expect(switchOf('Tower 3').value, isTrue);
    expect(switchOf('80m 4 sq').value, isFalse, reason: 'listed though not enabled');
    expect(switchOf('Bank').onChanged, isNull, reason: 'shown, but nothing here can drive a bank');

    // The editor's rows, over the station list's own row for the same device.
    await tester.tap(find.text('80m 4 sq').last);
    await tester.pump();
    await tester.tap(find.text('Tower 3').last);
    await tester.pump();
    await tester.tap(find.text(t.common.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final saved = services.cat.nodeFor(node.uuid)!.config;
    expect(saved[everywareDevicesConfigKey], ['switchBox:80m 4 sq']);
    expect(saved.keys.where((key) => key.startsWith('everywareDevice/')), isEmpty, reason: 'the switches are the list, not settings of their own');
  });

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
