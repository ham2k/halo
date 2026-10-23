// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Bluetooth LE serial transport, which has met no bridge: the LiNK500MP's
// GATT table is not published, so the profiles are the common UART layouts and
// these tests are what stands between a wrong guess about the plumbing and a
// shipped one. The policy is what is tested — which pipe, written how, and
// what a failure says — against a fake gateway; the plugin calls themselves
// are hands-on territory.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_details.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/ble_serial_gateway.dart';
import 'package:ham2k_logger/services/cat/transports/ble_serial_profiles.dart';
import 'package:ham2k_logger/services/cat/transports/ble_serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/bluetooth_serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

const _nusService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const _nusRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const _nusTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

String _sig(String short) => '0000$short-0000-1000-8000-00805f9b34fb';

const _nus = BleSerialService(_nusService, [
  BleSerialCharacteristic(_nusRx, write: true, writeWithoutResponse: true),
  BleSerialCharacteristic(_nusTx, notify: true),
]);

final _hm10 = BleSerialService(_sig('ffe0'), [BleSerialCharacteristic(_sig('ffe1'), write: true, writeWithoutResponse: true, notify: true)]);

/// What every device carries besides its pipe — GAP with a writable name.
final _gap = BleSerialService(_sig('1800'), [BleSerialCharacteristic(_sig('2a00'), write: true, notify: true)]);

class _FakeDevice implements BleSerialDevice {
  _FakeDevice(this.services);

  @override
  final List<BleSerialService> services;

  @override
  int get chunkLimit => 244;

  final writes = <(String, Uint8List, bool)>[];
  ({String service, String characteristic, bool indicate})? subscribed;
  void Function(Uint8List)? _onData;
  int disconnects = 0;
  final _dropped = Completer<void>();

  /// Each write waits on this when set, so a test can hold writes in flight.
  Completer<void>? writeGate;
  Object? failWrites;

  void push(String text) => _onData!(Uint8List.fromList(ascii.encode(text)));
  void drop() => _dropped.complete();

  @override
  Future<void> subscribe(String service, String characteristic, {required bool indicate, required void Function(Uint8List data) onData}) async {
    _onData = onData;
    subscribed = (service: service, characteristic: characteristic, indicate: indicate);
  }

  @override
  Future<void> write(String service, String characteristic, Uint8List bytes, {required bool withoutResponse}) async {
    if (failWrites != null) throw failWrites!;
    await writeGate?.future;
    writes.add((characteristic, bytes, withoutResponse));
  }

  @override
  Future<void> get disconnected => _dropped.future;

  @override
  Future<void> disconnect() async => disconnects++;
}

class _FakeGateway implements BleSerialGateway {
  @override
  set onNote(void Function(String text)? note) {}

  BleSerialReadiness readiness = BleSerialReadiness.ready;
  Object? scanError;
  final prepares = <bool>[];
  List<BleSerialSighting> sightings = const [];
  int scans = 0;
  _FakeDevice? device;
  Completer<BleSerialDevice>? pendingConnect;
  Object? connectError;

  @override
  Future<BleSerialReadiness> prepare({required bool requestPermission}) async {
    prepares.add(requestPermission);
    return readiness;
  }

  @override
  Future<List<BleSerialSighting>> scan(Duration duration) async {
    scans++;
    if (scanError case final error?) throw error;
    return sightings;
  }

  @override
  Future<BleSerialDevice> connect(String deviceId, {required Duration timeout}) async {
    if (connectError != null) throw connectError!;
    if (pendingConnect != null) return pendingConnect!.future;
    return device!;
  }
}

/// Takes whatever a session reports and keeps none of it.
class _SilentSink implements EquipmentSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _vendorService = '12345678-0000-0000-0000-000000000000';
const _vendor = BleSerialService(_vendorService, [
  BleSerialCharacteristic('12345678-0000-0000-0000-000000000001', write: true),
  BleSerialCharacteristic('12345678-0000-0000-0000-000000000002', notify: true),
]);
const _update = BleSerialService('abcdef00-0000-0000-0000-000000000000', [
  BleSerialCharacteristic('abcdef00-0000-0000-0000-000000000001', write: true, notify: true),
]);

const _target = {bleDeviceConfigKey: 'AA:BB', bleDeviceNameConfigKey: 'LiNK500'};

void main() {
  group('picking the pipe', () {
    test('the Nordic UART layout writes RX and listens on TX', () {
      final pipe = pickBleSerialProfile([_gap, _nus])!;
      expect(pipe.name, 'Nordic UART');
      expect((pipe.rx, pipe.tx), (_nusRx, _nusTx));
      expect(pipe.withoutResponse, isTrue, reason: 'a response per write halves a poll\'s throughput');
      expect(pipe.indicate, isFalse);
    });

    test('an HM-10 is one characteristic both ways, held to 20-byte writes', () {
      // The module drops a longer write rather than refusing it: a CAT
      // command past 20 bytes would vanish with no error anywhere.
      final pipe = pickBleSerialProfile([_hm10])!;
      expect(pipe.rx, pipe.tx);
      expect(pipe.maxWrite, 20);
    });

    test('a known profile wins over a vendor service that merely looks like one', () {
      const vendor = BleSerialService('12345678-0000-0000-0000-000000000000', [
        BleSerialCharacteristic('12345678-0000-0000-0000-000000000001', write: true),
        BleSerialCharacteristic('12345678-0000-0000-0000-000000000002', notify: true),
      ]);
      expect(pickBleSerialProfile([vendor, _nus])!.name, 'Nordic UART');
    });

    test('an unknown layout is used only when it is the only candidate', () {
      const one = BleSerialService('12345678-0000-0000-0000-000000000000', [
        BleSerialCharacteristic('12345678-0000-0000-0000-000000000001', write: true),
        BleSerialCharacteristic('12345678-0000-0000-0000-000000000002', indicate: true),
      ]);
      final pipe = pickBleSerialProfile([_gap, one])!;
      expect(pipe.name, 'by shape');
      expect(pipe.indicate, isTrue, reason: 'a characteristic that only indicates is subscribed as one');
      expect(pipe.withoutResponse, isFalse, reason: 'its RX takes only acknowledged writes');

      // Two candidates is a guess about where CAT goes, and a wrong one
      // writes into some vendor's settings characteristic.
      const other = BleSerialService('87654321-0000-0000-0000-000000000000', [
        BleSerialCharacteristic('87654321-0000-0000-0000-000000000001', write: true, notify: true),
      ]);
      expect(pickBleSerialProfile([one, other]), isNull);
    });

    test('among unknown layouts, the one the device advertises is the pipe', () {
      // The LiNK500MP's own guidance: its pipe is the service it announces.
      // An update service beside it has the same shape, and without the
      // advertisement to go by the two are a guess.
      expect(pickBleSerialProfile([_vendor, _update]), isNull);
      final pipe = pickBleSerialProfile([_vendor, _update], advertised: [_vendorService.toUpperCase()])!;
      expect(pipe.service, _vendorService);
    });

    test('a GAP name characteristic is never mistaken for a pipe', () {
      expect(pickBleSerialProfile([_gap]), isNull);
    });
  });

  group('the transport', () {
    late _FakeGateway gateway;
    const transport = BleSerialTransport();

    setUp(() {
      gateway = _FakeGateway();
      BleSerialTransport.debugGateway = gateway;
      BleSerialTransport.debugReset();
    });
    tearDown(() => BleSerialTransport.debugGateway = null);

    test('subscribes before handing the connection over, and bytes reach the driver', () async {
      final device = gateway.device = _FakeDevice([_gap, _nus]);
      final connection = await transport.connect(_target, cancel: CatCancelToken());
      expect(device.subscribed, (service: _nusService, characteristic: _nusTx, indicate: false));

      final received = <String>[];
      connection.data.listen((chunk) => received.add(ascii.decode(chunk)));
      device.push('FA00014074000;');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['FA00014074000;']);
    });

    test('a background connect never raises the permission prompt', () async {
      // Only the operator pressing Scan has asked for it. A prompt out of a
      // reconnect ladder would appear on launch, over whatever they opened.
      gateway.device = _FakeDevice([_nus]);
      await transport.connect(_target, cancel: CatCancelToken());
      expect(gateway.prepares, [false]);

      gateway.readiness = BleSerialReadiness.denied;
      await expectLater(transport.connect(_target, cancel: CatCancelToken()), throwsA(isA<BleSerialUnavailable>()));
    });

    test('a failure is the equipment\'s, so it stays out of the crash reports', () async {
      gateway.connectError = const BleSerialPlatformError('peripheral not found');
      await expectLater(transport.connect(_target, cancel: CatCancelToken()), throwsA(isA<CatUnreachable>()));
    });

    test('a failure in this app\'s own code stays loud', () async {
      // Tagged as the equipment's, a bug in the GATT mapping would read as a
      // bridge out of range and never reach a crash report.
      gateway.connectError = StateError('a bug');
      await expectLater(transport.connect(_target, cancel: CatCancelToken()), throwsA(isA<StateError>()));
    });

    test('a bridge that never answers is the bridge\'s failure, not the radio\'s', () async {
      // The shared timeout message tells the operator to check the RADIO is
      // on, when nothing past the bridge was ever asked.
      gateway.connectError = TimeoutException('connect');
      await expectLater(transport.connect(_target, cancel: CatCancelToken()), throwsA(isA<BleSerialUnavailable>()));
    });

    test('a device with no pipe is let go, and the failure names its services', () async {
      // That table is the one thing an operator can send that lets an unknown
      // bridge be added to the list.
      const vendor = BleSerialService('12345678-0000-0000-0000-000000000000', [BleSerialCharacteristic('12345678-0000-0000-0000-000000000001', notify: true)]);
      final device = gateway.device = _FakeDevice([vendor]);
      await expectLater(
        transport.connect(_target, cancel: CatCancelToken()),
        throwsA(isA<BleSerialUnavailable>().having((e) => e.message, 'message', contains('12345678-0000-0000-0000-000000000001'))),
      );
      expect(device.disconnects, 1);
    });

    test('a connect cancelled mid-flight lets go of the device it lands on', () async {
      gateway.pendingConnect = Completer();
      final cancel = CatCancelToken();
      final attempt = transport.connect(_target, cancel: cancel);
      await Future<void>.delayed(Duration.zero);
      cancel.cancel();
      await expectLater(attempt, throwsA(isA<CatCancelledException>()));

      final late = _FakeDevice([_nus]);
      gateway.pendingConnect!.complete(late);
      await Future<void>.delayed(Duration.zero);
      expect(late.disconnects, 1, reason: 'a second app asking the bridge would otherwise find it taken');
    });

    test('writes are cut to the pipe\'s limit and go out one at a time, in order', () {
      fakeAsync((async) {
        final device = gateway.device = _FakeDevice([_hm10]);
        late EquipmentConnection connection;
        transport.connect(_target, cancel: CatCancelToken()).then((c) => connection = c);
        async.flushMicrotasks();

        device.writeGate = Completer();
        final command = ascii.encode('FA00014074000;MD2;IF;PC;ID;');
        connection.send(command);
        async.flushMicrotasks();
        expect(device.writes, isEmpty, reason: 'the first write is still in flight');

        device.writeGate!.complete();
        async.flushMicrotasks();
        expect([for (final w in device.writes) w.$2.length], [20, command.length - 20]);
        expect(ascii.decode([for (final w in device.writes) ...w.$2]), ascii.decode(command));
      });
    });

    test('a failed write closes the connection instead of throwing into the driver', () async {
      final device = gateway.device = _FakeDevice([_nus]);
      final connection = await transport.connect(_target, cancel: CatCancelToken());
      device.failWrites = Exception('link lost');
      connection.send(ascii.encode('FA;'));
      await connection.closed.timeout(const Duration(seconds: 1));
      expect(device.disconnects, 1);
    });

    test('a link that drops says so, and lets go of the plugin\'s stream', () async {
      final device = gateway.device = _FakeDevice([_nus]);
      final connection = await transport.connect(_target, cancel: CatCancelToken());
      device.drop();
      await connection.closed.timeout(const Duration(seconds: 1));
      expect(device.disconnects, 1);
    });

    test('a scan asks for permission, and lists what it found to pick from', () async {
      gateway.sightings = const [
        BleSerialSighting(deviceId: 'speaker', name: 'Kitchen', rssi: -40),
        BleSerialSighting(deviceId: 'bridge', name: 'LiNK500', rssi: -70, services: [_nusService]),
      ];
      final result = await transport.runAction('scanBleDevices', 'scan', const {});
      expect(gateway.prepares, [true]);

      // The bridge announcing a serial service is the only real choice, so it
      // is picked — with its name, which the row shows.
      expect(result!.fieldUpdates, {
        bleDeviceConfigKey: 'bridge',
        bleDeviceNameConfigKey: 'LiNK500',
        bleDeviceServicesConfigKey: [_nusService],
      });
      final options = transport.configElements().single['options'] as List;
      expect([for (final o in options) (o as Map)['value']], ['bridge', 'speaker', 'scanBleDevices'], reason: 'serial bridges first, even when weaker');
    });

    test('a scan never replaces a device the operator already picked', () async {
      gateway.sightings = const [
        BleSerialSighting(deviceId: 'bridge', name: 'LiNK500', services: [_nusService]),
      ];
      final result = await transport.runAction('scanBleDevices', 'scan', const {bleDeviceConfigKey: 'other'});
      expect(result!.fieldUpdates, isEmpty, reason: 'empty still rebuilds the picker with what was found');
    });

    test('a scan that fails says so, rather than that nothing is there', () async {
      // "None found" sends the operator to check the bridge, when what failed
      // is the scan — Bluetooth switched off under it.
      gateway.scanError = const BleSerialPlatformError('Bluetooth not enabled');
      final result = await transport.runAction('scanBleDevices', 'scan', const {});
      expect(result!.message, contains('Bluetooth not enabled'));
    });

    test('a scan Bluetooth cannot run says why, rather than finding nothing', () async {
      gateway.readiness = BleSerialReadiness.off;
      final result = await transport.runAction('scanBleDevices', 'scan', const {});
      expect(result!.message, isNotEmpty);
      expect(gateway.scans, 0);
    });

    test('picking a device brings its name and advertised services along', () async {
      gateway.sightings = const [
        BleSerialSighting(deviceId: 'a', name: 'First'),
        BleSerialSighting(deviceId: 'b', name: 'Second', services: [_vendorService]),
      ];
      await transport.runAction('scanBleDevices', 'scan', const {});
      expect(transport.fieldChanged(bleDeviceConfigKey, 'b'), {
        bleDeviceNameConfigKey: 'Second',
        bleDeviceServicesConfigKey: [_vendorService],
      });
      expect(transport.fieldChanged('other', 'b'), isNull);
    });

    test('after a restart, the stored advertisement still picks the pipe', () async {
      // No scan has run, so nothing but the node remembers what the bridge
      // announced; without it a bridge with an update service never connects.
      gateway.device = _FakeDevice([_gap, _vendor, _update]);
      final connection = await transport.connect({
        ..._target,
        bleDeviceServicesConfigKey: [_vendorService],
      }, cancel: CatCancelToken());
      expect(gateway.device!.subscribed?.service, _vendorService);
      await connection.close();
    });

    test('a stored device is offered before any scan, so the editor does not show it unpicked', () {
      expect(transport.describeTarget(_target), 'LiNK500');
      final options = transport.configElements().single['options'] as List;
      expect((options.first as Map)['value'], 'AA:BB');
    });

    group('what DEVLOGCAT records', () {
      // A bridge nobody here has met is debugged from a field recording and
      // nothing else, and every BLE step's own words otherwise go only to a
      // console the tester's build never shows.
      final notes = <String>[];
      setUp(() {
        notes.clear();
        BleSerialTransport.onNote = notes.add;
      });
      tearDown(() => BleSerialTransport.onNote = null);

      test('a connect records the GATT table and the pipe picked from it', () async {
        gateway.device = _FakeDevice([_gap, _vendor]);
        await transport.connect({
          ..._target,
          bleDeviceServicesConfigKey: [_vendorService],
        }, cancel: CatCancelToken());
        expect(notes.join('\n'), allOf(contains('12345678-0000-0000-0000-000000000002 n'), contains('pipe: by shape in $_vendorService')));
      });

      test('a failure is recorded in the platform\'s words, without the bridge\'s address', () async {
        // On Android the handle is the bridge's hardware address, and the
        // recording leaves the device.
        gateway.connectError = const BleSerialPlatformError('GATT error 133 on aa:bb');
        await expectLater(transport.connect(_target, cancel: CatCancelToken()), throwsA(isA<BleSerialUnavailable>()));
        expect(notes.join('\n'), allOf(contains('GATT error 133'), isNot(contains('aa:bb'))));
      });

      test('a scan names the bridges and nobody\'s earbuds', () async {
        gateway.sightings = const [
          BleSerialSighting(deviceId: 'bridge', name: 'LiNK500MP', services: [_vendorService]),
          BleSerialSighting(deviceId: 'buds', name: 'Jane\'s Buds', services: ['0000fe2c-0000-1000-8000-00805f9b34fb']),
        ];
        await transport.runAction('scanBleDevices', 'scan', const {});
        final recorded = notes.join('\n');
        expect(recorded, allOf(contains('"LiNK500MP"'), contains(_vendorService), contains('0000fe2c'), isNot(contains('Jane'))));
      });

      test('the radio setup sent with a recording never states the bridge\'s address', () {
        final type = EquipmentRegistry().typeFor('tx500mp-ble')!;
        final node = EquipmentNode(
          uuid: 'u1',
          typeKey: type.key,
          name: 'TX-500MP',
          config: const {bleDeviceConfigKey: 'AA:BB:CC', bleDeviceNameConfigKey: 'LiNK500MP'},
        );
        final lines = configLines(node, type, EquipmentRegistry()).join('\n');
        expect(lines, allOf(contains('LiNK500MP'), isNot(contains('AA:BB:CC'))));
      });
    });

    test('a node with no device yet is unconfigured, not failing', () {
      expect(transport.isUnconfigured(const {}), isTrue);
      expect(transport.isUnconfigured(_target), isFalse);
    });
  });

  group('every serial radio over Bluetooth LE', () {
    final registry = EquipmentRegistry();

    test('carries its serial pairing\'s driver pins, and none of the port\'s settings', () {
      // The pins are the whole of what a named radio adds over the generic;
      // a BLE variant without them is that radio misread over a new link.
      final ble = registry.typeFor('tx500mp-ble')!;
      expect(ble.transportKey, BleSerialTransport.transportKey);
      expect(ble.overrides[KenwoodDriver.modeDialectKey], KenwoodModeDialect.lab599.name);
      expect(ble.defaultConfig.containsKey('baudRate'), isFalse, reason: 'the bridge has the baud rate, not this link');

      final ic705 = registry.typeFor('ic705-ble')!;
      expect(ic705.defaultConfig['civAddress'], 'A4');
    });

    test('paces for the wire behind the bridge, so a slow one is not offered the scope', () {
      // With no baud at all a driver budgets as for a network link: an Icom
      // would offer its spectrum, and stream sweeps into a 19200 UART until
      // VFO and keyer replies starve.
      final ic705 = registry.typeFor('ic705-ble')!;
      expect(ic705.driverConfig(const {})['baudRate'], 19200);
      final session = ic705.driver.createSession(_SilentSink(), ic705.driverConfig(const {})) as IcomCivSession;
      expect(session.spectrumUnavailable, isNotNull);
      expect([for (final e in ic705.configElements()) e['key']], isNot(contains('baudRate')), reason: 'the bridge has its own setting');
    });

    test('a model reached only by network or a bridge program gets none', () {
      expect(registry.typeFor('flexradio-ble'), isNull);
      expect(registry.typeFor('flrig-ble'), isNull);
    });

    group('on iOS', () {
      setUp(() {
        BleSerialTransport.debugGateway = _FakeGateway();
        addTearDown(() => BleSerialTransport.debugGateway = null);
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
      });

      List<String> offeredTransports() => [for (final type in registry.offeredVariants(tx500mpModel, tx500Experiment: true)) type.transportKey];

      test('a radio is offered over Bluetooth LE, and never over a serial port iOS does not have', () {
        // An iPhone has no USB serial and no Classic Bluetooth serial; picked
        // there, either pairing only fails once the operator has set it up.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(offeredTransports(), contains(BleSerialTransport.transportKey));
        expect(offeredTransports(), isNot(contains(SerialTransport.transportKey)));
        expect(offeredTransports(), isNot(contains(BluetoothSerialTransport.transportKey)));

        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        expect(offeredTransports(), containsAll([SerialTransport.transportKey, BluetoothSerialTransport.transportKey, BleSerialTransport.transportKey]));
      });

      test('a radio iOS can reach only as a placeholder is not offered, unless a node is already on it', () {
        // The placeholder is supported everywhere, so without the iOS rule
        // every serial-only rig stays in the catalogue with nothing behind it.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(registry.offeredVariants(ft891Model, tx500Experiment: false), isEmpty);
        expect([for (final type in registry.offeredVariants(ft891Model, tx500Experiment: true)) type.transportKey], contains(BleSerialTransport.transportKey));
        expect(registry.offeredVariants(ic705Model, tx500Experiment: false), isNotEmpty);
        expect(registry.offeredVariants(placeholderRadioModel, tx500Experiment: false), isNotEmpty);
        final saved = registry.typeFor(placeholderVariantFor(ft891Model.key).key);
        expect(registry.offeredVariants(ft891Model, tx500Experiment: false, current: saved), [saved]);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(registry.offeredVariants(ft891Model, tx500Experiment: false), isNotEmpty);
      });

      test('a node already on a serial pairing keeps it in its editor on iOS', () {
        // Dropped, the node opens to a form with no connection to show and
        // no other pairing to move it to.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final saved = registry.typeFor('ft891-serial')!;
        expect(registry.offeredVariants(ft891Model, tx500Experiment: false, current: saved), contains(saved));
      });

      test('the TX-500 notes give the LiNK500MP\'s Mode 4 alone, and elsewhere Mode 3 beside it', () {
        // Mode 3 is Classic Bluetooth, which iOS does not offer: set to it,
        // the LiNK500MP never shows up in the iPhone's scan.
        String notes() => [for (final note in registry.typeFor('tx500mp-ble')!.notes) note['text']].join();
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(notes(), allOf(contains('Mode 4'), isNot(contains('Mode 3'))));
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        expect(notes(), allOf(contains('Mode 4'), contains('Mode 3')));
      });
    });
  });
}
