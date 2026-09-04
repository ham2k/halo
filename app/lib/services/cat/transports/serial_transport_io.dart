// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial over libserialport (FFI, same shape as the halo_quickjs plugin) on
// desktop, and over the usb_serial plugin (Android's UsbManager wrapped in a
// MethodChannel) on Android — libserialport enumerates via Linux
// /dev/sysfs nodes, which a sandboxed Android app can't read. iOS has no
// USB host API at all without MFi, so it stays on the (non-functional)
// libserialport path below like every other non-Android dart:io platform.
//
// PLATFORM COST, none of it optional:
//   - macOS needs `com.apple.security.device.serial` in BOTH entitlement
//     files. It is a sandbox relaxation, not one of the AMFI-restricted
//     entitlements that break spawning — but verify on a SIGNED Release
//     build, because Debug passes regardless.
//   - Linux CI needs `libudev-dev` to build libserialport.
//   - Android needs `<uses-feature android:name="android.hardware.usb.host"
//     android:required="false" />` in AndroidManifest.xml. usb_serial pops
//     the runtime USB-permission dialog itself, inside `UsbDevice.create()`.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial/usb_serial.dart' as usb;

import '../transport.dart';
import 'serial_transport_config.dart';

/// `UsbConstants.USB_CLASS_CDC_DATA`: the interface class of each serial
/// port a CDC/ACM device presents.
const _usbClassCdcData = 10;

/// `UsbConstants.USB_CLASS_VENDOR_SPEC`: what a bridge chip's UART
/// interfaces are, one per port.
const _usbClassVendorSpecific = 0xFF;

/// The two bridge families whose multi-port parts present one vendor-class
/// interface per port: FTDI (FT2232, FT4232) and Silicon Labs (CP2105,
/// CP2108). Their single-port parts present exactly one, so the rule
/// "every vendor-class interface is a port" holds across the family.
const _usbVendorFtdi = 0x0403;
const _usbVendorSiliconLabs = 0x10C4;

/// Answered by `UsbInterfacesChannel.kt`; see the note there.
const _androidUsbInterfacesChannel = MethodChannel('ham2k/usb_interfaces');

/// Joins a USB device path and an interface index into one port name, so
/// a composite device's second serial port is a `port` config value like
/// any other rather than a schema change.
const androidPortInterfaceSeparator = '#';

/// Interface indexes of [deviceName]'s serial ports, in descriptor order
/// — see [androidSerialInterfaceIndexes] for what counts. Empty when the
/// channel cannot answer, which leaves the device with its one
/// auto-detected port.
///
/// Only the two expected failures are absorbed: a native build without
/// the channel, and a device gone between enumeration and this call. A
/// malformed answer is a bug in our own Kotlin and stays loud — absorbed,
/// it would reproduce the exact symptom this exists to fix, with a cause
/// nobody could see.
Future<List<int>> androidSerialInterfaces(String deviceName, {required int? vendorId}) async {
  final List<dynamic>? raw;
  try {
    raw = await _androidUsbInterfacesChannel.invokeMethod<List<dynamic>>('list', {'deviceName': deviceName});
  } on MissingPluginException catch (e) {
    debugPrint('[cat] android usb interface enumeration unavailable for $deviceName: $e');
    return const [];
  } on PlatformException catch (e) {
    debugPrint('[cat] android usb interface enumeration failed for $deviceName: $e');
    return const [];
  }
  return androidSerialInterfaceIndexes(vendorId: vendorId, interfaces: [for (final entry in raw ?? const []) entry as Map]);
}

/// Which of a device's interfaces are serial ports, given its descriptors
/// as `UsbInterfacesChannel.kt` reports them.
///
/// An FTDI or Silicon Labs bridge is one port per vendor-class interface:
/// nothing in that class says "serial", so the vendor is what says it —
/// and the class still rules out the audio or HID interfaces the same
/// makers' non-UART parts present (CP2114, FT260), which would otherwise
/// be offered as ports and fail to open as "permission denied". Everything
/// else is a CDC/ACM device, whose ports are its CDC data interfaces —
/// never the control interfaces (class 2) paired with them, which would
/// list the X6100 as four. felHR85/UsbSerial addresses the chosen
/// interface correctly for all three: CP210x control transfers carry the
/// interface id, FTDI's carry the id plus one (port A is 1), and CDC's
/// data endpoints belong to the interface itself.
List<int> androidSerialInterfaceIndexes({required int? vendorId, required List<Map> interfaces}) {
  final bridge = vendorId == _usbVendorFtdi || vendorId == _usbVendorSiliconLabs;
  final portClass = bridge ? _usbClassVendorSpecific : _usbClassCdcData;
  return [
    for (final entry in interfaces)
      if (entry['interfaceClass'] == portClass) (entry['index'] as num).toInt(),
  ];
}

/// The picker entries for one Android USB device.
///
/// A device with more than one serial interface gets one entry per
/// interface, named `<device>#<interface index>` and numbered "port N of M"
/// in descriptor order — the order Linux and Windows number them in, which
/// is how the X6100's note can say CI-V is on the second, and which puts a
/// CP2105's Enhanced port (CAT, on a Yaesu) first. Anything else is a
/// single entry under the bare device name, opened with usb_serial's
/// auto-detection — so every stored config predating the split still
/// matches. The underlying felHR85/UsbSerial library opens the FIRST
/// interface (or the first CDC data one) when not told which, so without
/// the index the second port of any of these devices is unreachable.
List<SerialPortOption> androidSerialPortOptions({
  required String deviceName,
  String? manufacturer,
  String? productName,
  String? serialNumber,
  int? vendorId,
  int? productId,
  required List<int> serialInterfaces,
}) {
  if (serialInterfaces.length < 2) {
    return [
      SerialPortOption(
        name: deviceName,
        manufacturer: manufacturer,
        productName: productName,
        serialNumber: serialNumber,
        vendorId: vendorId,
        productId: productId,
      ),
    ];
  }
  return [
    for (final (i, iface) in serialInterfaces.indexed)
      SerialPortOption(
        name: '$deviceName$androidPortInterfaceSeparator$iface',
        manufacturer: manufacturer,
        productName: productName,
        serialNumber: serialNumber,
        vendorId: vendorId,
        productId: productId,
        portIndex: i,
        portCount: serialInterfaces.length,
      ),
  ];
}

/// The device path and interface index a stored Android port name carries.
/// A name without an index is the auto-detect value usb_serial takes, -1.
({String deviceName, int iface}) androidPortTarget(String name) {
  final at = name.lastIndexOf(androidPortInterfaceSeparator);
  if (at < 0) return (deviceName: name, iface: -1);
  final iface = int.tryParse(name.substring(at + 1));
  if (iface == null) return (deviceName: name, iface: -1);
  return (deviceName: name.substring(0, at), iface: iface);
}

/// libserialport ships with a debug handler installed, and it calls
/// `getenv("LIBSERIALPORT_DEBUG")` on EVERY debug statement — `serialport.c`
/// `sp_default_debug_handler`. The read loop emits several per byte
/// received, and `getenv` linear-scans the environment, so a profile of a
/// live FT-891 (4800 baud, one byte per wakeup) showed **~13% of a core**
/// burned looking up a variable nobody has set.
///
/// Clearing the handler short-circuits the macro before that call —
/// `libserialport_internal.h`: `#define DEBUG_FMT(...) if (sp_debug_handler)`.
/// Nothing is lost: with the variable unset the handler printed nothing
/// anyway.
///
/// Best-effort and once per process. A failed lookup costs only the saving,
/// so it must not take a connection down with it.
var _libserialportQuieted = false;

void _quietLibserialport() {
  if (_libserialportQuieted) return;
  _libserialportQuieted = true;
  try {
    final setHandler = ffi.DynamicLibrary.process().lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)>('sp_set_debug_handler');
    setHandler(ffi.nullptr);
  } catch (e) {
    debugPrint('[cat] could not quiet libserialport debug logging: $e');
  }
}

class SerialTransport extends EquipmentTransport with SerialTransportConfig {
  const SerialTransport();

  static const transportKey = 'serial';

  /// One USB host controller for the whole device, same reasoning as
  /// `serial_transport_web.dart`'s granted-ports cache being static rather
  /// than per-instance.
  static List<SerialPortOption> _cachedAndroidPortOptions = const [];
  static Map<String, usb.UsbDevice> _androidDevicesByName = const {};

  @override
  String get key => transportKey;

  @override
  List<SerialPortOption> get availablePorts =>
      Platform.isAndroid ? _cachedAndroidPortOptions : availableSerialPorts();

  /// Android's device list is a MethodChannel round-trip, unlike
  /// libserialport's synchronous FFI scan — so it goes through the same
  /// prefetch-and-cache hook the web transport uses, populated before
  /// `configElements()` (which reads `availablePorts` synchronously) runs.
  @override
  Future<void> prepareConfigElements() async {
    if (!Platform.isAndroid) return;

    List<usb.UsbDevice> devices;
    try {
      devices = await usb.UsbSerial.listDevices();
    } catch (e) {
      debugPrint('[cat] android usb device enumeration unavailable: $e');
      _androidDevicesByName = const {};
      _cachedAndroidPortOptions = const [];
      return;
    }

    final byName = <String, usb.UsbDevice>{};
    final options = <SerialPortOption>[];
    for (final device in devices) {
      byName[device.deviceName] = device;
      options.addAll(androidSerialPortOptions(
        deviceName: device.deviceName,
        manufacturer: device.manufacturerName,
        productName: device.productName,
        serialNumber: device.serial,
        vendorId: device.vid,
        productId: device.pid,
        serialInterfaces: await androidSerialInterfaces(device.deviceName, vendorId: device.vid),
      ));
    }
    _androidDevicesByName = byName;
    _cachedAndroidPortOptions = options;
  }

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    if (Platform.isAndroid) return _connectAndroid(target, cancel: cancel);

    _quietLibserialport();

    final name = target['port'] as String? ?? '';
    final baudRate = (target['baudRate'] as num?)?.toInt() ?? 4800;
    final stopBits = (target['stopBits'] as num?)?.toInt() ?? 1;

    final port = SerialPort(name);
    // `openReadWrite` returns false rather than throwing — the usual causes
    // are the port being gone since it was picked, another app (WSJT-X,
    // fldigi, rigctld) already holding it, or the macOS sandbox refusing it
    // for want of the device.serial entitlement. All three want saying out
    // loud rather than a bare false.
    if (!port.openReadWrite()) {
      final reason = SerialPort.lastError?.message;
      port.dispose();
      throw SerialPortUnavailable(name, reason);
    }

    try {
      port.config = SerialPortConfig()
        ..baudRate = baudRate
        // 8-N-1, which is what Yaesu CAT uses and what every rig's CAT menu
        // means by its baud setting.
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = stopBits
        // RTS and DTR stay OFF, which is what setFlowControl(none) leaves
        // them as. NEVER assert them here: on the common interfaces —
        // Digirig, SignaLink, most home-brew cables — RTS *is* the PTT line,
        // so raising it keys the transmitter the moment the app connects.
        //
        // The cost is that a radio whose CAT menu has RTS handshaking
        // enabled (the FT-891 ships that way, menu 05-08 CAT RTS) waits for
        // a high RTS before it will answer, and stays silent forever if it
        // never comes. That has to be fixed at the radio by disabling CAT
        // RTS, not here — keying someone's transmitter to read a frequency
        // is not a trade worth making.
        ..setFlowControl(SerialPortFlowControl.none);
    } catch (e) {
      port.close();
      port.dispose();
      throw SerialPortUnavailable(name, '$e');
    }

    // Opening is synchronous, so there is no window to be cancelled in —
    // but a cancel that landed while we were configuring still means nobody
    // wants this port.
    if (cancel.isCancelled) {
      port.close();
      port.dispose();
      throw const CatCancelledException();
    }

    return _SerialConnection(port);
  }

  Future<EquipmentConnection> _connectAndroid(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final name = target['port'] as String? ?? '';
    final baudRate = (target['baudRate'] as num?)?.toInt() ?? 4800;
    final stopBits = (target['stopBits'] as num?)?.toInt() ?? 1;
    final (:deviceName, :iface) = androidPortTarget(name);

    var device = _androidDevicesByName[deviceName];
    if (device == null) {
      // Boot-time auto-reconnect and the panel's own Connect button call
      // this directly, without ever going through the equipment editor's
      // prepareConfigElements() — so the cache can still be at its empty
      // default here. Look the device up fresh rather than assuming gone.
      try {
        for (final candidate in await usb.UsbSerial.listDevices()) {
          if (candidate.deviceName == deviceName) {
            device = candidate;
            break;
          }
        }
      } catch (e) {
        throw SerialPortUnavailable(name, '$e');
      }
    }
    if (device == null) {
      throw SerialPortUnavailable(name, 'no longer plugged in — pick it again from the port list');
    }
    // A device path is reused by whatever is plugged in next, so a stored
    // index can name an interface that is now audio, or nothing at all.
    // Opening it anyway fails as "permission denied", which sends the
    // operator to re-grant a permission that was never the problem.
    if (iface >= 0) {
      final serialInterfaces = await androidSerialInterfaces(deviceName, vendorId: device.vid);
      if (serialInterfaces.isNotEmpty && !serialInterfaces.contains(iface)) {
        throw SerialPortUnavailable(name, 'not a serial port on this device — pick it again from the port list');
      }
    }

    // On a CDC device, line coding and DTR/RTS go to interface 0 whichever
    // port this opens: felHR85/UsbSerial addresses every CDC control
    // transfer to wIndex 0. Data flows through the chosen interface's own
    // endpoints regardless; on a composite device the baud rate below
    // reaches its port only if interface 0 happens to be that port's
    // control interface. The FTDI and CP210x paths carry the interface in
    // theirs, so a bridge's second port gets its own settings.
    //
    // device.create() awaits Android's system USB-permission dialog, which
    // can block indefinitely on the operator — race it against cancellation
    // the same way tcp_transport_io.dart races Socket.connect, so a
    // superseded attempt doesn't leave the port claimed behind a newer one.
    final createCompleter = Completer<usb.UsbPort?>();
    unawaited(device.create('', iface).then(
      (port) {
        if (createCompleter.isCompleted) {
          unawaited(port?.close().catchError((Object _) => false));
        } else {
          createCompleter.complete(port);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!createCompleter.isCompleted) createCompleter.completeError(error, stackTrace);
      },
    ));
    unawaited(cancel.whenCancelled.then((_) {
      if (!createCompleter.isCompleted) createCompleter.completeError(const CatCancelledException());
    }));

    final usb.UsbPort? port;
    try {
      port = await createCompleter.future;
    } on CatCancelledException {
      rethrow;
    } catch (e) {
      throw SerialPortUnavailable(name, '$e');
    }
    if (port == null) throw SerialPortUnavailable(name, 'could not open a serial connection to this device');

    final bool opened;
    try {
      opened = await port.open();
    } catch (e) {
      throw SerialPortUnavailable(name, '$e');
    }
    if (!opened) throw SerialPortUnavailable(name, 'permission denied, or the port is already in use');

    try {
      await port.setPortParameters(
        baudRate,
        usb.UsbPort.DATABITS_8,
        stopBits == 2 ? usb.UsbPort.STOPBITS_2 : usb.UsbPort.STOPBITS_1,
        usb.UsbPort.PARITY_NONE,
      );
      await port.setFlowControl(usb.UsbPort.FLOW_CONTROL_OFF);
      // RTS and DTR stay OFF — see the RTS-as-PTT note on the desktop
      // connect path above; the same wiring risk applies here.
      await port.setDTR(false);
      await port.setRTS(false);
    } catch (e) {
      unawaited(port.close().catchError((Object _) => false));
      throw SerialPortUnavailable(name, '$e');
    }

    if (cancel.isCancelled) {
      unawaited(port.close().catchError((Object _) => false));
      throw const CatCancelledException();
    }

    return _AndroidSerialConnection(port);
  }
}

/// The port could not be opened, with the reason libserialport gave.
class SerialPortUnavailable implements CatUnreachable {
  final String portName;
  final String? reason;

  const SerialPortUnavailable(this.portName, this.reason);

  @override
  String toString() =>
      reason == null ? 'Could not open $portName' : 'Could not open $portName: $reason';
}

class _SerialConnection implements EquipmentConnection {
  final SerialPort _port;
  late final SerialPortReader _reader;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  _SerialConnection(this._port) {
    _reader = SerialPortReader(_port);
    _reader.stream.listen(
      _dataController.add,
      // A USB-serial adapter unplugged mid-session surfaces here.
      onError: (Object _) => _markClosed(),
      onDone: _markClosed,
      cancelOnError: true,
    );
  }

  void _markClosed() {
    if (!_open) return;
    _open = false;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
    try {
      _reader.close();
      _port.close();
      _port.dispose();
    } catch (e) {
      // Already gone — an unplugged adapter takes the handle with it.
      debugPrint('[cat] serial port teardown: $e');
    }
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  void send(List<int> bytes) {
    if (!_open) return;
    // Drivers write from unguarded poll timers, so a write to a port that
    // has gone away must not throw into a timer callback.
    try {
      _port.write(Uint8List.fromList(bytes), timeout: 0);
    } catch (e) {
      debugPrint('[cat] serial write failed: $e');
    }
  }

  @override
  Future<void> close() async => _markClosed();
}

class _AndroidSerialConnection implements EquipmentConnection {
  final usb.UsbPort _port;
  StreamSubscription<Uint8List>? _sub;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  _AndroidSerialConnection(this._port) {
    _sub = _port.inputStream?.listen(
      _dataController.add,
      // A USB-serial adapter unplugged mid-session surfaces here.
      onError: (Object _) => unawaited(_markClosed()),
      onDone: () => unawaited(_markClosed()),
      cancelOnError: true,
    );
  }

  /// [closed] fires AFTER the native port is released, not before: `CatService`
  /// starts its own reconnect the moment [closed] fires, and reopening the
  /// same still-claimed USB interface before `port.close()`'s MethodChannel
  /// round-trip lands would lose that race — same reasoning as the web
  /// transport's `_markClosed`.
  Future<void> _markClosed() async {
    if (!_open) return;
    _open = false;
    unawaited(_dataController.close());
    unawaited(_sub?.cancel());
    try {
      await _port.close();
    } catch (e) {
      // Already gone — an unplugged adapter takes the handle with it.
      debugPrint('[cat] android usb port teardown: $e');
    }
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  void send(List<int> bytes) {
    if (!_open) return;
    // Drivers write from unguarded poll timers, so a write to a port that
    // has gone away must not throw into a timer callback.
    unawaited(_port.write(Uint8List.fromList(bytes)).catchError((Object e) {
      debugPrint('[cat] android usb write failed: $e');
    }));
  }

  @override
  Future<void> close() async => _markClosed();
}

/// Ports the app could open, enumerated fresh — a USB adapter can appear or
/// vanish between one look and the next, so this is never cached.
List<SerialPortOption> availableSerialPorts() {
  _quietLibserialport();

  final options = <SerialPortOption>[];
  final List<String> names;
  try {
    names = SerialPort.availablePorts;
  } catch (e) {
    // libserialport is loaded through dart:ffi, so this throws outright
    // when the native library is missing — a Linux box without libudev at
    // runtime, a bundle built without it, or any test process. The port
    // picker must be able to say "no serial ports found" rather than take
    // the equipment editor down with it.
    debugPrint('[cat] serial port enumeration unavailable: $e');
    return const [];
  }

  for (final name in names) {
    final port = SerialPort(name);
    // Each attribute in its own try. libserialport reads several of these by
    // opening the port, and on macOS that fails with EAGAIN for every port —
    // so fetching them together would throw on `description` and silently
    // cost us the USB identity as well, leaving the picker showing bare
    // device names like `cu.usbserial-01AF7D0E0`.
    T? probe<T>(String field, T Function() read) {
      try {
        return read();
      } catch (e) {
        debugPrint('[cat] port $name: no $field ($e)');
        return null;
      }
    }

    options.add(SerialPortOption(
      name: name,
      description: probe<String?>('description', () => port.description),
      manufacturer: probe<String?>('manufacturer', () => port.manufacturer),
      productName: probe<String?>('productName', () => port.productName),
      serialNumber: probe<String?>('serialNumber', () => port.serialNumber),
      vendorId: probe<int?>('vendorId', () => port.vendorId),
      productId: probe<int?>('productId', () => port.productId),
    ));
    port.dispose();
  }

  return options;
}
