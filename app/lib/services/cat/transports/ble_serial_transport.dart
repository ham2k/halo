// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's serial CAT over a Bluetooth LE serial bridge — a LiNK500MP in
// its iOS mode, an HM-10 module on a cable, anything that turns a BLE service into a UART.
// Unlike Bluetooth serial (SPP), the OS never presents this as a port: the
// app scans for the bridge, connects to it, and moves the bytes through a
// pair of GATT characteristics itself. That is also why it reaches iOS,
// which has no serial ports at all.
//
// There is no baud rate here: the bridge's own wire to the radio has one,
// set on the bridge. See docs/design/cat.md § Bluetooth LE serial.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../transport.dart';
import 'ble_serial_gateway.dart';
import 'ble_serial_profiles.dart';

/// The stored device: the platform's handle for the bridge (see
/// [BleSerialSighting.deviceId]).
const bleDeviceConfigKey = 'bleDevice';

/// How fast the bridge's wire to the radio runs — never a field, and never
/// sent anywhere: the bridge has its own setting. Pinned per variant (see
/// `bleSerialVariantFor`) so a driver that paces by baud paces for that
/// wire, not for the radio link alone.
const bleSerialLinkBaudKey = 'baudRate';

/// The bridge's advertised name when it was picked — what the equipment row
/// shows, since the handle on an Apple platform is an opaque UUID.
const bleDeviceNameConfigKey = 'bleDeviceName';

/// The service UUIDs the bridge advertised when it was picked — what
/// [pickBleSerialProfile] prefers among unknown layouts. Stored, because a
/// connect after a restart has no scan to read them from.
const bleDeviceServicesConfigKey = 'bleDeviceServices';

class BleSerialTransport extends EquipmentTransport {
  const BleSerialTransport();

  static const transportKey = 'bleSerial';

  static const _scanActionKey = 'scanBleDevices';
  static const _scanMethod = 'scan';

  /// Long enough for a bridge advertising at a relaxed interval to be heard
  /// two or three times; short enough that the operator is still looking.
  static const scanDuration = Duration(seconds: 5);

  static const connectTimeout = Duration(seconds: 15);

  /// Replaces the platform gateway, for tests. Null in the app.
  @visibleForTesting
  static BleSerialGateway? debugGateway;

  static BleSerialGateway? _platformGateway;
  static bool _platformGatewayMade = false;

  static BleSerialGateway? get _gateway {
    if (debugGateway case final gateway?) return gateway..onNote = _note;
    if (!_platformGatewayMade) {
      _platformGateway = createBleSerialGateway()?..onNote = _note;
      _platformGatewayMade = true;
    }
    return _platformGateway;
  }

  /// What the picker offers: the last scan, plus every device this session
  /// has been told about by a stored node (see [describeTarget]) — without
  /// those, a node's device would show as nothing picked until a scan found
  /// it again. One list for the whole app, like the serial port list: there
  /// is one radio.
  static final Map<String, BleSerialSighting> _known = {};

  @visibleForTesting
  static void debugReset() => _known.clear();

  /// Where this transport's notes go besides the console: DEVLOGCAT's
  /// recording, wired by `HaLoServices`. A bridge nobody here has met is
  /// debugged from those alone — its GATT table, the pipe picked from it,
  /// what the platform said when a step failed — so every step says
  /// something. Never a device's handle: the recording leaves the device,
  /// and on Android the handle is the bridge's hardware address.
  static void Function(String text)? onNote;

  static void _note(String text) {
    debugPrint('[cat] BLE $text');
    onNote?.call(text);
  }

  /// A scan result as a line for [_note]. Named only when it advertises a
  /// known serial profile or a vendor's own UUID: a bridge, most likely, where
  /// the rest are phones and earbuds with their owners' names on them.
  static String _sightingLine(BleSerialSighting device) {
    final vendor = advertisesBleSerial(device.services) || device.services.any((uuid) => !uuid.endsWith(_sigBaseSuffix));
    return '${vendor ? '"${device.name}"' : 'a device'} ${device.rssi ?? '?'} dBm, advertising [${device.services.join(', ')}]';
  }

  static const _sigBaseSuffix = '-0000-1000-8000-00805f9b34fb';

  static void _remember(Map<String, dynamic> config) {
    final id = config[bleDeviceConfigKey];
    final name = config[bleDeviceNameConfigKey];
    if (id is! String || id.isEmpty || _known.containsKey(id)) return;
    _known[id] = BleSerialSighting(deviceId: id, name: name is String && name.isNotEmpty ? name : id, services: _storedServices(config));
  }

  static List<String> _storedServices(Map<String, dynamic> config) => [
    for (final uuid in config[bleDeviceServicesConfigKey] as List? ?? const []) ?(uuid is String ? uuid : null),
  ];

  /// What the editor stores beside a picked device.
  static Map<String, dynamic> _pickedFields(BleSerialSighting device) => {
    bleDeviceConfigKey: device.deviceId,
    bleDeviceNameConfigKey: device.name,
    bleDeviceServicesConfigKey: device.services,
  };

  @override
  String get key => transportKey;

  @override
  bool get isSupportedOnThisPlatform => _gateway != null;

  @override
  Set<String> get recognizedConfigKeys => {bleDeviceConfigKey, bleDeviceNameConfigKey, bleDeviceServicesConfigKey, bleSerialLinkBaudKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    if (overrides.containsKey(bleDeviceConfigKey)) return const [];
    final devices = _known.values.toList()
      ..sort((a, b) {
        // Bridges that say what they are first, then the strongest signal.
        final serial = (advertisesBleSerial(b.services) ? 1 : 0) - (advertisesBleSerial(a.services) ? 1 : 0);
        return serial != 0 ? serial : (b.rssi ?? -999) - (a.rssi ?? -999);
      });
    return [
      {
        'type': 'field',
        'fieldType': 'select',
        'key': bleDeviceConfigKey,
        'label': t.settings.station.bleDevice,
        'description': t.settings.station.bleDeviceDescription,
        'options': [
          for (final device in devices)
            {
              'value': device.deviceId,
              'label': device.name,
              // An icon on every row is what makes this a row picker, which
              // keeps a stored device not in this scan rather than blanking it.
              'icon': 'bluetooth',
              if (device.rssi != null) 'trailing': '${device.rssi} dBm',
              if (advertisesBleSerial(device.services)) 'emphasis': true,
            },
          {'value': _scanActionKey, 'label': t.settings.station.bleScan, 'isAction': true, 'method': _scanMethod, 'icon': 'magnify'},
        ],
      },
    ];
  }

  @override
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) async {
    if (actionKey != _scanActionKey) return null;
    final gateway = _gateway;
    if (gateway == null) return null;

    final readiness = await gateway.prepare(requestPermission: true);
    if (readiness != BleSerialReadiness.ready) {
      _note('scan: Bluetooth is ${readiness.name}');
      return EquipmentActionResult(message: _readinessMessage(readiness));
    }

    final List<BleSerialSighting> found;
    try {
      found = await gateway.scan(scanDuration);
    } on BleSerialPlatformError catch (e) {
      // Not "none found": that sends the operator to check the bridge, when
      // what failed is the scan itself — Bluetooth switched off under it, a
      // platform refusing to start one.
      _note('scan failed: $e');
      return EquipmentActionResult(message: t.settings.station.bleScanFailed(reason: e.message));
    }
    _note('scan found ${found.length} named devices${found.isEmpty ? '' : ':'}');
    for (final device in found) {
      _note('  ${_sightingLine(device)}');
    }
    for (final device in found) {
      _known[device.deviceId] = device;
    }
    if (found.isEmpty) return EquipmentActionResult(message: t.settings.station.bleScanNoneFound);

    // Picked for the operator only when there is nothing to choose between:
    // one bridge announcing a serial service, and nothing picked yet.
    final bridges = found.where((d) => advertisesBleSerial(d.services)).toList();
    final current = state[bleDeviceConfigKey];
    if (bridges.length == 1 && (current is! String || current.isEmpty)) {
      return EquipmentActionResult(fieldUpdates: _pickedFields(bridges.single));
    }
    // Empty, not null: an update of any kind is what has the editor rebuild
    // the picker with what the scan found.
    return const EquipmentActionResult(fieldUpdates: {});
  }

  /// The name and advertised services travel with the device, so the row
  /// can say which bridge, and a connect can find its pipe, without a scan.
  /// Answered here, as the operator picks, because the stored handle alone
  /// names nothing a person would recognize.
  @override
  Map<String, dynamic>? fieldChanged(String key, dynamic value) {
    if (key != bleDeviceConfigKey || value is! String) return null;
    final device = _known[value];
    return device == null ? null : (_pickedFields(device)..remove(bleDeviceConfigKey));
  }

  @override
  bool isUnconfigured(Map<String, dynamic> config) {
    final id = config[bleDeviceConfigKey];
    return id is! String || id.isEmpty;
  }

  @override
  String describeTarget(Map<String, dynamic> config) {
    _remember(config);
    final name = config[bleDeviceNameConfigKey];
    return name is String && name.isNotEmpty ? name : '';
  }

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();
    final gateway = _gateway;
    if (gateway == null) throw UnsupportedError('Bluetooth LE is not available on this platform');
    _remember(target);
    final deviceId = target[bleDeviceConfigKey] as String;
    final advertised = _known[deviceId]?.services ?? _storedServices(target);
    _note('connecting to "${target[bleDeviceNameConfigKey] ?? ''}", which advertised [${advertised.join(', ')}]');

    // Never prompts: a reconnect in the background is not the operator
    // asking. The editor's Scan is where permission is asked for.
    final readiness = await gateway.prepare(requestPermission: false);
    if (readiness != BleSerialReadiness.ready) {
      _note('not connecting: Bluetooth is ${readiness.name}');
      throw BleSerialUnavailable(_readinessMessage(readiness));
    }
    if (cancel.isCancelled) throw const CatCancelledException();

    final attempt = gateway.connect(deviceId, timeout: connectTimeout);
    final BleSerialDevice? device;
    try {
      device = await Future.any<BleSerialDevice?>([attempt, cancel.whenCancelled.then((_) => null)]);
    } on TimeoutException {
      // The bridge's message, not the shared timeout one: that says the
      // RADIO did not answer, and here nothing past the bridge was asked.
      _note('connect timed out');
      throw BleSerialUnavailable(t.settings.station.bleConnectFailed);
    } on BleSerialPlatformError catch (e) {
      _note('connect failed: ${scrubBleDeviceId(e, deviceId)}');
      throw BleSerialUnavailable(t.settings.station.bleConnectFailed);
    } catch (e) {
      // This app's own failure, so it stays loud — but the recording is
      // still where a tester's account of it is read.
      _note('connect failed in the app: ${scrubBleDeviceId(e, deviceId)}');
      rethrow;
    }
    if (device == null || cancel.isCancelled) {
      _note('connect cancelled');
      // The attempt goes on underneath; whatever it lands on is let go.
      unawaited(attempt.then((late) => late.disconnect(), onError: (Object _) {}));
      if (device != null) unawaited(device.disconnect());
      throw const CatCancelledException();
    }

    final table = describeBleServices(device.services);
    _note('connected; writes up to ${device.chunkLimit} bytes; services: ${table.isEmpty ? 'none beyond the standard ones' : table}');
    final pipe = pickBleSerialProfile(device.services, advertised: advertised);
    if (pipe == null) {
      _note('no serial pipe among those services');
      await device.disconnect();
      throw BleSerialUnavailable(t.settings.station.bleNoSerialService(services: table));
    }

    final connection = BleSerialConnection(device, pipe, deviceId: deviceId);
    _note(
      'pipe: ${pipe.name} in ${pipe.service}, writing ${pipe.rx}${pipe.withoutResponse ? ' without response' : ''} '
      'in chunks of ${connection.chunkSize}, listening on ${pipe.tx} by ${pipe.indicate ? 'indication' : 'notification'}',
    );
    try {
      await device.subscribe(pipe.service, pipe.tx, indicate: pipe.indicate, onData: connection.receive);
    } on BleSerialPlatformError catch (e) {
      _note('subscribe failed: ${scrubBleDeviceId(e, deviceId)}');
      await connection.close();
      throw BleSerialUnavailable(t.settings.station.bleConnectFailed);
    } catch (e) {
      _note('subscribe failed in the app: ${scrubBleDeviceId(e, deviceId)}');
      await connection.close();
      rethrow;
    }
    if (cancel.isCancelled) {
      await connection.close();
      throw const CatCancelledException();
    }
    return connection;
  }

  static String _readinessMessage(BleSerialReadiness readiness) => switch (readiness) {
    BleSerialReadiness.off => t.settings.station.bleOff,
    BleSerialReadiness.denied => t.settings.station.bleDenied,
    BleSerialReadiness.unsupported => t.settings.station.bleUnsupported,
    BleSerialReadiness.starting || BleSerialReadiness.ready => t.settings.station.bleStarting,
  };
}

/// A connect that failed for a reason about the bridge or the machine's
/// Bluetooth, never about this app: off, out of range, a permission withheld,
/// a device with no serial service. Its text is what the equipment row shows.
class BleSerialUnavailable implements CatUnreachable {
  const BleSerialUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The byte pipe over one [BleSerialPipe].
@visibleForTesting
class BleSerialConnection implements EquipmentConnection {
  BleSerialConnection(this._device, this._pipe, {this._deviceId = ''}) {
    // Through [close], not just [_markClosed]: a link that dropped still
    // holds the plugin's value-stream subscription until it is let go.
    unawaited(
      _device.disconnected.then((_) {
        if (_open) BleSerialTransport._note('the link dropped: the bridge or the platform ended it');
        return close();
      }),
    );
  }

  final BleSerialDevice _device;
  final BleSerialPipe _pipe;

  /// Only to keep it out of the notes.
  final String _deviceId;
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  bool _open = true;

  /// Writes go out one at a time, in order: two in flight at once may land
  /// in either order, and a CAT command split across them would be garbled.
  Future<void> _tail = Future.value();

  void receive(Uint8List chunk) {
    if (_open) _data.add(chunk);
  }

  int get chunkSize {
    final limit = _pipe.maxWrite;
    return limit == null || limit > _device.chunkLimit ? _device.chunkLimit : limit;
  }

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  void send(List<int> bytes) {
    if (!_open || bytes.isEmpty) return;
    final size = chunkSize;
    for (var start = 0; start < bytes.length; start += size) {
      final end = start + size < bytes.length ? start + size : bytes.length;
      final chunk = Uint8List.fromList(bytes.sublist(start, end));
      _tail = _tail.then((_) async {
        if (!_open) return;
        try {
          await _device.write(_pipe.service, _pipe.rx, chunk, withoutResponse: _pipe.withoutResponse);
        } catch (e) {
          // A write that fails is a link that is gone; [closed] is what says
          // so, never a throw into the driver's timer.
          BleSerialTransport._note('write failed, closing: ${scrubBleDeviceId(e, _deviceId)}');
          unawaited(close());
        }
      });
    }
  }

  void _markClosed() {
    if (!_open) return;
    _open = false;
    unawaited(_data.close());
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _markClosed();
    await _device.disconnect();
  }
}
