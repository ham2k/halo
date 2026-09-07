// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radio report an operator files from the equipment editor (HALO-69).
//
// The card IS the feature — nothing it carries is visible on screen, so a
// field that stopped reaching it, or a password that started to, would look
// exactly like a working report from inside the app. Hence the assertions
// here are about the body's contents rather than about the dialog.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_config.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/equipment_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = EquipmentRegistry();
  // The one shipped pairing with a credential of its own — the case the
  // secret-exclusion assertions need to be about something real.
  final ic705Network = registry.typeFor('ic705-network')!;
  // Its sibling over a cable: same radio, same editor form, no credential of
  // its own. The pairing a narrow secret check would wave a password through.
  final ic705Serial = registry.typeFor('ic705-serial')!;
  // The one shipped pairing whose picker labels are translated sentences
  // rather than the stored key — the case a label-for-value substitution
  // silently loses the machine truth on.
  final coax = registry.typeFor('sierra-coax-serial')!;
  // The same serial pairing with a KNOWN port list behind it. Real
  // enumeration answers whatever hardware is plugged into the machine
  // running the tests — on CI, nothing at all — so the port lines could
  // never be asserted against it.
  final portsType = EquipmentType(
    ic705Serial.model,
    EquipmentVariant(key: ic705Serial.key, driver: ic705Serial.driver, transport: const _FakePortsTransport()),
  );
  final throwingPortsType = EquipmentType(
    ic705Serial.model,
    EquipmentVariant(key: ic705Serial.key, driver: ic705Serial.driver, transport: const _ThrowingPortsTransport()),
  );

  EquipmentReport reportFor({
    Map<String, dynamic> values = const {},
    EquipmentType? type,
    Map<String, dynamic> config = const {},
    EquipmentState state = const EquipmentState(),
  }) {
    final resolvedType = type ?? ic705Network;
    return buildEquipmentReport(
      values: {
        'manufacturer': 'Icom',
        'model': 'IC-7300',
        'outcome': 'works',
        'comments': '',
        'hints': '',
        ...values,
      },
      node: EquipmentNode(uuid: 'u1', typeKey: resolvedType.key, name: 'Left Radio', config: config),
      type: resolvedType,
      state: state,
      registry: registry,
    );
  }

  group('the head start the form opens with', () {
    test('offers the brand alone as the manufacturer, and the operator\'s own name as the model', () {
      // Neither is a fact and both stay editable — but an operator who
      // renamed this radio has already told us its model, and asking again is
      // asking them to repeat themselves.
      final prefill = equipmentReportPrefill(
        EquipmentNode(uuid: 'u1', typeKey: ic705Network.key, name: 'IC-7300', config: const {}),
        ic705Network,
      );
      // The driver is named for a protocol family, not a manufacturer — the
      // whole point of taking the first word is that "Icom (CI-V)" in a
      // Manufacturer box is something every operator has to delete.
      expect(ic705Network.driver.name, 'Icom (CI-V)');
      expect(prefill['manufacturer'], 'Icom');
      expect(prefill['model'], 'IC-7300');
    });

    test('every shipped driver prefills something without a protocol in it', () {
      // Pins the shape rather than each string: a driver renamed to put the
      // protocol first, or a new one whose brand is two words, breaks the
      // heuristic silently and every report then arrives mislabelled.
      //
      // The one-word rule belongs to the DERIVATION, not to brands — a model
      // that states its own manufacturer is free to be "QRP Labs", and
      // applying the heuristic's shape check to it would forbid the very
      // answer declaring one exists to give.
      for (final type in EquipmentRegistry().types) {
        final brand = equipmentReportPrefill(
          EquipmentNode(uuid: 'u1', typeKey: type.key, name: '', config: const {}),
          type,
        )['manufacturer'] as String;
        expect(brand, isNotEmpty, reason: '${type.key} prefills no manufacturer at all');
        expect(brand, isNot(contains('(')), reason: '${type.key} prefills "$brand"');
        if (type.manufacturer == null) {
          expect(brand, isNot(contains(' ')), reason: '${type.key} prefills "$brand"');
        }
      }
    });

    test('a radio whose brand is not its protocol family says so itself', () {
      // The QMX speaks Kenwood CAT, so the driver-name heuristic labels it
      // Kenwood — a wrong brand on the one kind of card whose whole value is
      // naming the hardware correctly.
      final qmx = EquipmentRegistry().typeFor('qmx-serial')!;
      final brand = equipmentReportPrefill(
        EquipmentNode(uuid: 'u1', typeKey: qmx.key, name: 'QMX', config: const {}),
        qmx,
      )['manufacturer'];

      expect(qmx.driver.name, 'Kenwood (CAT)');
      expect(brand, 'QRP Labs');
    });

    test('does not answer the outcome', () {
      // The one field the whole report turns on: a default here is a verdict
      // put in the operator's mouth, and a report filed on it says nothing.
      final prefill = equipmentReportPrefill(
        EquipmentNode(uuid: 'u1', typeKey: ic705Network.key, name: 'Left Radio', config: const {}),
        ic705Network,
      );
      expect(prefill.containsKey('outcome'), isFalse);
    });
  });

  group('the card a radio report becomes', () {
    test('names the radio the operator says it is, not the one they picked', () {
      // The catalogue entry is a family ("Icom IC-705", "Yaesu - Generic")
      // and the prefill is only a guess; the title has to carry whatever the
      // operator corrected it to, or the report cannot be acted on.
      final report = reportFor(values: {'manufacturer': 'Elecraft', 'model': 'KX3'});
      expect(report.title, 'Elecraft KX3 works');
    });

    test('the verdict is in the title and in the kind, in step', () {
      // Two separate consumers: the title is what a human scans on the board,
      // the kind is what files it. A change to one that misses the other puts
      // a working radio in the bug queue, or a broken one out of it.
      expect(reportFor(values: {'outcome': 'works'}).title, endsWith('works'));
      expect(reportFor(values: {'outcome': 'works'}).kind, 'task');
      expect(reportFor(values: {'outcome': 'issues'}).title, endsWith('works with issues'));
      expect(reportFor(values: {'outcome': 'issues'}).kind, 'bug');
      expect(reportFor(values: {'outcome': 'fails'}).title, endsWith('does not work'));
      expect(reportFor(values: {'outcome': 'fails'}).kind, 'bug');
    });

    test('the operator prose leads the body, hints under their own heading', () {
      final report = reportFor(values: {
        'comments': 'Frequency tracks fine, mode is always USB.',
        'hints': 'Turn CAT RTS off in menu 05-08.',
      });
      expect(report.body, startsWith('Frequency tracks fine, mode is always USB.'));
      // The hints are a separate field precisely so they can be lifted into
      // the pairing's troubleshooting notes later; buried in the comments they
      // are prose nobody extracts.
      expect(report.body, contains('**Troubleshooting hints**'));
      expect(report.body, contains('Turn CAT RTS off in menu 05-08.'));
    });

    test('says what the app thought it was talking to', () {
      // Half of every report of the form "my Elecraft works": WHICH catalogue
      // entry it worked through. Without it, "Elecraft KX3 works" cannot be
      // turned into a change to anything.
      final report = reportFor();
      expect(report.body, contains(ic705Network.model.name));
      expect(report.body, contains('ic705-network'));
      expect(report.body, contains(ic705Network.transportLabel));
      expect(report.body, contains(ic705Network.driver.key));
    });

    test('reports the settings under the labels the editor uses', () {
      // The values are meaningless without the question they answered — "94"
      // says nothing, "Radio CI-V address: 94" is the whole report for a rig
      // that answered on the wrong address.
      final report = reportFor(config: {'host': '192.168.1.50', 'username': 'op'});
      expect(report.body, contains('192.168.1.50'));
      expect(report.body, contains('Radio username: op'));
    });

    test('never carries a credential, whatever the operator called the field', () {
      // The mutation this exists to catch is someone reporting `node.config`
      // wholesale. Both exclusion routes are asserted: the transport declares
      // `password` a secret field, and any element the form renders as
      // `fieldType: 'secret'` is dropped even if the transport forgot to.
      expect(ic705Network.secretFields, contains('password'));
      final report = reportFor(config: {'host': '10.0.0.2', 'password': 'hunter2'});
      expect(report.body, isNot(contains('hunter2')));
      expect(report.body, isNot(contains('password')));
      expect(report.body, contains('10.0.0.2'));
    });

    test('a secret belongs to the catalogue, not to the pairing the node is on', () {
      // The editor renders every variant's fields at once, so a node bound to
      // a transport with no credentials of its own can still be carrying the
      // password belonging to the transport beside it — an IC-705 switched
      // from WiFi to USB is exactly that. `EquipmentRegistry.allSecretFields`
      // exists for this question and says so in its own doc; asking the
      // pairing instead is what puts a password in a public card.
      expect(ic705Serial.secretFields, isNot(contains('password')));
      expect(registry.allSecretFields, contains('password'));
      final report = reportFor(type: ic705Serial, config: {'baudRate': 19200, 'password': 'hunter2'});
      expect(report.body, isNot(contains('hunter2')));
      expect(report.body, contains('19200'));
    });

    test('refuses to invent a verdict rather than filing one nobody gave', () {
      // The form's validator is the only thing standing between a missing
      // outcome and a card. It lives in another function and this builder is
      // exported, so a default here would file "works with issues" over an
      // answer the operator never gave — indistinguishable, on the board,
      // from one they did.
      expect(() => reportFor(values: {'outcome': null}), throwsArgumentError);
      expect(() => reportFor(values: {'outcome': 'mostly'}), throwsArgumentError);
    });

    test('a port is reported the way the picker showed it, not as the bare device name', () {
      // "COM8" identifies nothing — the same name is a different adapter on
      // the next machine, and on the machine next door. What makes a report
      // about a dual-port bridge actionable is which of its two ports the
      // operator picked, and that lives only in the option's label.
      final report = reportFor(type: portsType, config: {'port': 'COM8', 'baudRate': 38400});
      // The picker's row puts the device node in its own column, so the
      // label no longer carries it and `_shownValue` appends the raw value —
      // which is what keeps the report naming a port that can be looked up.
      expect(report.body, contains('Silicon Labs CP2105 Dual USB to UART Bridge (`COM8`)'));
      // The baud rate's own option label is the value itself: a picker field
      // must not lose its value to a label lookup that finds nothing useful.
      expect(report.body, contains('38400'));
    });

    test('the USB identity the label had no room for rides along', () {
      // The label carries `description` alone, and two adapters can share
      // one — the serial number and VID:PID are what say which silicon
      // answered. Hex because that is how every USB id is written down;
      // "4292:60016" matches nothing anyone can look up.
      final report = reportFor(type: portsType, config: {'port': 'COM8'});
      expect(report.body, contains('serial 01AF7D0E'));
      expect(report.body, contains('USB 10c4:ea70'));
    });

    test('a port the app cannot see says so, rather than going quiet', () {
      // Reporting a radio the app never found is a large share of what this
      // feature collects, and silence about the port reads exactly like a
      // port that was found and had nothing to say. The stored name still
      // stands in the config line above — it is the setting the report is
      // most often about.
      final report = reportFor(type: portsType, config: {'port': 'COM9'});
      expect(report.body, contains('COM9'));
      expect(report.body, contains('not among the 1 port(s) the app can see'));
    });

    test('a label that does not contain the stored value keeps it', () {
      // A picker whose labels are translated sentences — the coax switch's
      // layout, a Flex slice — would otherwise put "8 antennas, 1 radio", in
      // the operator's own language, where the machine value belongs. A fix
      // gets written against the value, not against the sentence.
      final report = reportFor(type: portsType, config: {'baudRate': 38400});
      expect(report.body, contains('38400'));
      final layout = buildEquipmentReport(
        values: const {'manufacturer': 'Sierra', 'model': 'Coax', 'outcome': 'works', 'comments': '', 'hints': ''},
        node: EquipmentNode(uuid: 'u1', typeKey: coax.key, name: 'Switch', config: const {'switchLayout': 'devicePorts'}),
        type: coax,
        state: const EquipmentState(),
        registry: registry,
      );
      expect(layout.body, contains('`devicePorts`'));
    });

    test('a scan that throws costs a detail line, never the report', () {
      // The form pane closed when the operator pressed Send, so everything
      // they wrote is gone with it — and building this card asks a serial
      // pairing to enumerate, which opens every port to read its descriptors.
      // A rig misbehaving at exactly the moment it is being reported is the
      // normal case here, not the exotic one.
      final report = reportFor(type: throwingPortsType, config: {'port': 'COM8'});
      expect(report.body, contains('enumeration failed'));
      expect(report.body, contains('Reported as:'));
      // The label lookup is gone with the elements, so the config line falls
      // back to the raw key — but it is still there, and still not a secret.
      expect(report.body, contains('port: COM8'));
    });

    test('carries the failure and the driver diagnostic when there is one', () {
      // The diagnostic is developer-mode-only on screen — meaningless to an
      // operator, and exactly what a report about a rig that defeated a
      // driver's autodetection is for.
      final report = reportFor(
        values: {'outcome': 'fails'},
        state: const EquipmentState(
          status: EquipmentStatus.error,
          error: 'No response from radio',
          diagnostic: 'IF offset unlearned',
        ),
      );
      expect(report.body, contains('Status: error'));
      expect(report.body, contains('No response from radio'));
      expect(report.body, contains('IF offset unlearned'));
    });

    test('a report with nothing typed but the radio still says something', () {
      // Comments and hints are optional: "this rig works" is a useful report
      // on its own, and an empty heading with nothing under it is not.
      final report = reportFor();
      expect(report.body, isNot(contains('**Troubleshooting hints**')));
      expect(report.body, contains('Reported as: Icom IC-7300 — works'));
    });
  });

  group('submitReport (real ham2k-lofi extension)', () {
    // Covers the seam the pure builder cannot see: that `submitReport` is
    // actually registered on the syncTransport hook and that the host's args
    // reach it. A method that was never registered would leave every test
    // above green and do nothing when the operator pressed Send.
    //
    // Offline BECAUSE of what it asserts: with no settings behind the service
    // `syncEnabled` reads false, so the hook refuses before `request()` —
    // which would otherwise register this device against the live server.
    late ExtensionService extensions;

    setUpAll(() async {
      extensions = ExtensionService();
      await extensions.start();
    });

    test('refuses without an account, in the REPORT command\'s own words', () async {
      final result = await extensions.submitReport(
        title: 'Elecraft KX3 works',
        body: 'Worked first time.',
        kind: 'task',
      );
      expect(result.ref, isNull);
      // The gate lives in the extension so both surfaces refuse identically;
      // a Dart-side copy of it would drift the moment either changed.
      expect(result.error, contains('enable sync in Settings'));
      // Not the host's own fallback: that would mean the hook never answered
      // at all, which is what an unregistered method looks like from here.
      expect(result.error, isNot(contains("can't be sent right now")));
    });
  });
}

/// A serial transport whose enumeration fails the way libserialport can: the
/// constructor and `dispose` in `availableSerialPorts` sit outside its try,
/// so a throw reaches whoever asked.
class _ThrowingPortsTransport extends EquipmentTransport with SerialTransportConfig {
  const _ThrowingPortsTransport();

  @override
  String get key => 'serial';

  @override
  List<SerialPortOption> get availablePorts => throw StateError('libserialport: no such device');

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      throw UnimplementedError();
}

/// A serial transport whose ports are fixtures rather than hardware.
class _FakePortsTransport extends EquipmentTransport with SerialTransportConfig {
  const _FakePortsTransport();

  @override
  String get key => 'serial';

  @override
  List<SerialPortOption> get availablePorts => const [
        SerialPortOption(
          name: 'COM8',
          description: 'Silicon Labs CP2105 Dual USB to UART Bridge',
          manufacturer: 'Silicon Labs',
          productName: 'CP2105 Dual USB to UART Bridge',
          serialNumber: '01AF7D0E',
          vendorId: 0x10c4,
          productId: 0xea70,
        ),
      ];

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      throw UnimplementedError();
}
