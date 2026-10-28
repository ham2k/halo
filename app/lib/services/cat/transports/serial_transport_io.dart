// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial over libserialport (FFI, same shape as the halo_quickjs plugin) on
// desktop, and over usb-serial-for-android (`UsbSerialChannel.kt`, which
// drives the USB chips itself through Android's UsbManager) on Android —
// libserialport enumerates via Linux /dev/sysfs nodes, which a sandboxed
// Android app can't read. iOS has no
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
//     android:required="false" />` in AndroidManifest.xml. The channel puts
//     the runtime USB-permission dialog up itself, inside `open`.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show OSError, Platform;

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../os_error_detail_io.dart';
import '../transport.dart';
import 'android_usb_serial.dart';
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
/// list the X6100 as four. A port's position in this list is the port
/// number usb-serial-for-android opens: its bridge drivers number ports by
/// interface, and its CDC driver by data interface in the same order.
List<int> androidSerialInterfaceIndexes({required int? vendorId, required List<Map<dynamic, dynamic>> interfaces}) {
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
/// single entry under the bare device name, opened as the device's first
/// port — so every stored config predating the split still matches.
List<SerialPortOption> androidSerialPortOptions({
  required String deviceName,
  String? manufacturer,
  String? productName,
  String? serialNumber,
  int? vendorId,
  int? productId,
  bool noDriver = false,
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
        noDriver: noDriver,
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
        noDriver: noDriver,
      ),
  ];
}

/// The device path and interface index a stored Android port name carries.
/// A name without an index carries -1: the device's first port.
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
    final setHandler = ffi.DynamicLibrary.process().lookupFunction<ffi.Void Function(ffi.Pointer<ffi.Void>), void Function(ffi.Pointer<ffi.Void>)>(
      'sp_set_debug_handler',
    );
    setHandler(ffi.nullptr);
  } catch (e) {
    debugPrint('[cat] could not quiet libserialport debug logging: $e');
  }
}

/// Why the lines read back from an open port are not the ones asked for, or
/// null when they are. [rts] and [dtr] are libserialport's readings
/// ([SerialPortRts], [SerialPortDtr]); hardware flow control counts as
/// neither high nor low, because the driver moves the line on its own.
@visibleForTesting
String? serialLinesMismatch({required int rts, required int dtr, required bool rtsHigh, required bool dtrHigh}) {
  if (rts == SerialPortRts.flowControl || dtr == SerialPortDtr.flowControl) {
    return 'hardware flow control is on for this port, so RTS/DTR cannot be held — another program probably left it set; unplug and replug the cable';
  }
  if (rts != (rtsHigh ? SerialPortRts.on : SerialPortRts.off)) return 'RTS did not go ${rtsHigh ? 'high' : 'low'} as set';
  if (dtr != (dtrHigh ? SerialPortDtr.on : SerialPortDtr.off)) return 'DTR did not go ${dtrHigh ? 'high' : 'low'} as set';
  return null;
}

class SerialTransport extends EquipmentTransport with SerialTransportConfig {
  const SerialTransport();

  static const transportKey = 'serial';

  /// Supplies ports to catalogue/form tests without scanning local hardware.
  /// Shared by the catalogue's const instances, including Bluetooth serial.
  @visibleForTesting
  static List<SerialPortOption> Function()? debugPortEnumerator;

  /// One USB host controller for the whole device, same reasoning as
  /// `serial_transport_web.dart`'s granted-ports cache being static rather
  /// than per-instance.
  static List<SerialPortOption> _cachedAndroidPortOptions = const [];
  static Map<String, AndroidUsbDevice> _androidDevicesByName = const {};

  @override
  String get key => transportKey;

  /// iOS gives an app no serial port: no USB serial host, and a Bluetooth
  /// serial profile only to MFi accessories. A radio reaches an iPhone or
  /// iPad over a Bluetooth LE bridge or the network instead. Covers
  /// `BluetoothSerialTransport` too, which is this transport.
  @override
  bool get isSupportedOnThisPlatform => defaultTargetPlatform != TargetPlatform.iOS;

  @override
  bool get offersUsbDriver => Platform.isAndroid;

  @override
  List<SerialPortOption> get availablePorts => debugPortEnumerator?.call() ?? (Platform.isAndroid ? _cachedAndroidPortOptions : availableSerialPorts());

  /// Android's device list is a MethodChannel round-trip, unlike
  /// libserialport's synchronous FFI scan — so it goes through the same
  /// prefetch-and-cache hook the web transport uses, populated before
  /// `configElements()` (which reads `availablePorts` synchronously) runs.
  @override
  Future<void> prepareConfigElements() async {
    if (!Platform.isAndroid) return;

    List<AndroidUsbDevice> devices;
    try {
      devices = await AndroidUsbSerial.list();
    } catch (e) {
      debugPrint('[cat] android usb device enumeration unavailable: $e');
      _androidDevicesByName = const {};
      _cachedAndroidPortOptions = const [];
      return;
    }

    final byName = <String, AndroidUsbDevice>{};
    final options = <SerialPortOption>[];
    for (final device in devices) {
      byName[device.deviceName] = device;
      options.addAll(
        androidSerialPortOptions(
          deviceName: device.deviceName,
          manufacturer: device.manufacturer,
          productName: device.product,
          serialNumber: device.serial,
          vendorId: device.vendorId,
          productId: device.productId,
          noDriver: device.driver == null,
          serialInterfaces: await androidSerialInterfaces(device.deviceName, vendorId: device.vendorId),
        ),
      );
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
    final rtsHigh = target[serialRtsHighConfigKey] == true;
    final dtrHigh = target[serialDtrHighConfigKey] == true;
    final manageLines = target[serialNoControlLinesKey] != true;

    final port = SerialPort(name);
    // `openReadWrite` returns false rather than throwing — the usual causes
    // are the port being gone since it was picked, another app (WSJT-X,
    // fldigi, rigctld) already holding it, or the macOS sandbox refusing it
    // for want of the device.serial entitlement. All three want saying out
    // loud rather than a bare false.
    if (!port.openReadWrite()) {
      final error = SerialPort.lastError;
      port.dispose();
      throw SerialPortUnavailable.fromSystem(name, error?.message, osError: error);
    }

    try {
      final config = SerialPortConfig()
        ..baudRate = baudRate
        // 8-N-1, which is what Yaesu CAT uses and what every rig's CAT menu
        // means by its baud setting.
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = stopBits
        ..setFlowControl(SerialPortFlowControl.none);
      // Both lines are driven to what the node says, explicitly.
      // setFlowControl(none) does not set them: libserialport leaves a line
      // it was not told about as the OS left it, and opening a port on macOS,
      // Linux and (for most drivers) Windows raises both — on a Digirig, a
      // SignaLink or most home-made cables that keys the transmitter, because
      // RTS *is* the PTT line there. Why each defaults off is at
      // serialRtsHighConfigKey and serialDtrHighConfigKey.
      if (manageLines) {
        config
          ..rts = rtsHigh ? SerialPortRts.on : SerialPortRts.off
          ..dtr = dtrHigh ? SerialPortDtr.on : SerialPortDtr.off;
      }
      port.config = config;
    } catch (e) {
      port.close();
      port.dispose();
      throw SerialPortUnavailable(name, '$e', osError: e is OSError ? e : null);
    }

    // Read the lines back rather than trusting the write. libserialport can
    // report success without having set them: it never clears hardware flow
    // control another program left on the port (it looks for CRTSCTS in the
    // wrong termios field), and with that on the driver raises RTS by itself;
    // and a setup error that sets no errno is not thrown at all. Either way a
    // Digirig's PTT would be held down with nothing said. A fresh wrapper
    // around the same open port, because `port.config` answers from what was
    // just written. Only its config is disposed — disposing the wrapper would
    // free the port under the connection.
    String? mismatch;
    if (manageLines) {
      final alias = SerialPort.fromAddress(port.address);
      try {
        mismatch = serialLinesMismatch(rts: alias.config.rts, dtr: alias.config.dtr, rtsHigh: rtsHigh, dtrHigh: dtrHigh);
      } catch (e) {
        port.close();
        port.dispose();
        throw SerialPortUnavailable(name, 'could not read back RTS/DTR: $e', failure: SerialFailure.lines);
      } finally {
        // The getter keeps the config it allocated even when reading into it
        // threw, and asking again answers from that cache without a second
        // read — so this frees it on both paths.
        try {
          alias.config.dispose();
        } catch (_) {}
      }
    }
    if (mismatch != null) {
      port.close();
      port.dispose();
      throw SerialPortUnavailable(name, mismatch, failure: SerialFailure.lines);
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
    final rtsHigh = target[serialRtsHighConfigKey] == true;
    final dtrHigh = target[serialDtrHighConfigKey] == true;
    final manageLines = target[serialNoControlLinesKey] != true;
    final (:deviceName, :iface) = androidPortTarget(name);

    var device = _androidDevicesByName[deviceName];
    if (device == null) {
      // Boot-time auto-reconnect and the panel's own Connect button call
      // this directly, without ever going through the equipment editor's
      // prepareConfigElements() — so the cache can still be at its empty
      // default here. Look the device up fresh rather than assuming gone.
      try {
        device = (await AndroidUsbSerial.list()).where((candidate) => candidate.deviceName == deviceName).firstOrNull;
      } catch (e) {
        throw SerialPortUnavailable(name, '$e');
      }
    }
    if (device == null) {
      throw SerialPortUnavailable(name, 'no longer plugged in', failure: SerialFailure.missing);
    }
    final usbId = device.usbId;

    // A device path is reused by whatever is plugged in next, so a stored
    // index can name an interface that is now audio, or nothing at all —
    // and opening another port of the right device in its place could put
    // the lines on a PTT port.
    var port = 0;
    if (iface >= 0) {
      port = (await androidSerialInterfaces(deviceName, vendorId: device.vendorId)).indexOf(iface);
      if (port < 0) {
        throw SerialPortUnavailable(name, 'not a serial port on this device — pick it again from the port list', usbId: usbId);
      }
    }

    // open() awaits Android's system USB-permission dialog, which can block
    // indefinitely on the operator — race it against cancellation the same
    // way tcp_transport_io.dart races Socket.connect, so a superseded attempt
    // doesn't leave the port claimed behind a newer one.
    final opening = Completer<int>();
    unawaited(
      AndroidUsbSerial.open(
        deviceName: deviceName,
        port: port,
        driver: target[serialUsbDriverConfigKey] as String?,
        baudRate: baudRate,
        stopBits: stopBits,
        // Explicitly, either way — see the desktop connect path above.
        dtr: manageLines ? dtrHigh : null,
        rts: manageLines ? rtsHigh : null,
      ).then(
        (handle) {
          if (opening.isCompleted) {
            // Nobody is waiting on this port, and a close that fails leaves
            // nothing open: the native side drops the handle either way.
            unawaited(AndroidUsbSerial.close(handle).catchError((Object _) {}));
          } else {
            opening.complete(handle);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!opening.isCompleted) opening.completeError(error, stackTrace);
        },
      ),
    );
    unawaited(
      cancel.whenCancelled.then((_) {
        if (!opening.isCompleted) opening.completeError(const CatCancelledException());
      }),
    );

    final int handle;
    try {
      handle = await opening.future;
    } on CatCancelledException {
      rethrow;
    } on PlatformException catch (e) {
      throw SerialPortUnavailable(name, e.message ?? e.code, failure: androidUsbFailure(e.code), usbId: usbId);
    } catch (e) {
      throw SerialPortUnavailable(name, '$e', usbId: usbId);
    }
    return _AndroidSerialConnection(handle);
  }
}

/// The port could not be opened, with the reason libserialport gave and, as
/// far as the throw site could tell, which KIND of failure it was.
///
/// The kind is set where it is known — the catch site in [CatService] can
/// only see the exception, and "Device or resource busy" is a very different
/// thing to tell an operator than "Device not found".
class SerialPortUnavailable implements SerialPortProblem {
  final String portName;
  final String? reason;

  /// libserialport's own error, when the failure came from it: the part of
  /// this exception `osErrorDetail` may quote, since [reason] sits beside a
  /// [portName] that carries the adapter's serial number.
  final OSError? osError;

  @override
  final SerialFailure failure;

  @override
  final String? usbId;

  const SerialPortUnavailable(this.portName, this.reason, {this.failure = SerialFailure.other, this.osError, this.usbId});

  /// libserialport hands back the OS's own wording rather than a code, so the
  /// kind has to be read out of it. Matched case-insensitively on the
  /// substrings POSIX and Windows agree on; anything else stays
  /// [SerialFailure.other] and keeps its own words.
  factory SerialPortUnavailable.fromSystem(String portName, String? reason, {OSError? osError}) {
    final text = (reason ?? '').toLowerCase();
    final failure = text.contains('busy')
        ? SerialFailure.busy
        : text.contains('permission denied') || text.contains('access is denied')
        ? SerialFailure.denied
        : text.contains('no such file') || text.contains('no such device') || text.contains('cannot find')
        ? SerialFailure.missing
        : SerialFailure.other;
    return SerialPortUnavailable(portName, reason, failure: failure, osError: osError);
  }

  @override
  String toString() => reason == null ? 'Could not open $portName' : 'Could not open $portName: $reason';
}

class _SerialConnection implements EquipmentConnection, ExplainsClose {
  final SerialPort _port;
  late final SerialPortReader _reader;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  @override
  String? closeReason;

  _SerialConnection(this._port) {
    _reader = SerialPortReader(_port);
    _reader.stream.listen(
      _dataController.add,
      // A USB-serial adapter unplugged mid-session surfaces here.
      onError: (Object e) => _markClosed('read error: ${osErrorDetail(e) ?? e.runtimeType}'),
      onDone: () => _markClosed('the port stopped reading'),
      cancelOnError: true,
    );
  }

  void _markClosed([String? reason]) {
    if (!_open) return;
    _open = false;
    closeReason = reason;
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

class _AndroidSerialConnection implements EquipmentConnection, ExplainsClose {
  final int _handle;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  @override
  String? closeReason;

  _AndroidSerialConnection(this._handle) {
    _sub = AndroidUsbSerial.events.where((event) => event['handle'] == _handle).listen((event) {
      final data = event['data'];
      if (data is Uint8List) {
        _dataController.add(data);
      } else {
        // A USB-serial adapter unplugged mid-session surfaces here; the
        // native side has already released the port.
        unawaited(_markClosed('read error: ${event['error']}'));
      }
    });
  }

  /// [closed] fires AFTER the native port is released, not before: `CatService`
  /// starts its own reconnect the moment [closed] fires, and reopening the
  /// same still-claimed USB interface before `close`'s MethodChannel
  /// round-trip lands would lose that race — same reasoning as the web
  /// transport's `_markClosed`.
  Future<void> _markClosed([String? reason]) async {
    if (!_open) return;
    _open = false;
    closeReason = reason;
    unawaited(_dataController.close());
    unawaited(_sub?.cancel());
    try {
      await AndroidUsbSerial.close(_handle);
    } catch (e) {
      // Only the channel itself can fail here: the native close of a handle
      // it no longer holds is a no-op.
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
    unawaited(
      AndroidUsbSerial.write(_handle, Uint8List.fromList(bytes)).catchError((Object e) {
        debugPrint('[cat] android usb write failed: $e');
      }),
    );
  }

  @override
  Future<void> close() async => _markClosed();
}

/// What each port's USB descriptors said, and when they were read.
///
/// The NAMES are never cached — a USB adapter can appear or vanish between
/// one look and the next — but reading these fields means OPENING the port,
/// and an open picker re-enumerates every few seconds. Repeating those opens
/// every tick would poke a port a live CAT session is holding, and is the
/// shape of the unbounded synchronous open that wedges the UI isolate on a
/// stuck COM port.
///
/// So each answer is kept, but only for [_descriptorTtl], because a port NAME
/// does not identify hardware: Windows hands `COM3` to whatever is plugged in
/// next, Linux the same with `/dev/ttyUSB0`. Cached for the life of the
/// process, one adapter swapped for another while no picker is open would
/// wear the old one's description, VID and PID — which is what a `suggest`
/// pattern matches on, what the duplicate numbering counts, and what an
/// equipment report quotes. An expiry bounds that lie to half a minute
/// instead of a session, and still spares all but one enumeration in ten.
///
/// The stamp is [realNowMillis]: this is a cache expiry, real elapsed time,
/// and must not travel with the app clock (docs/design/time.md §1).
final Map<String, ({SerialPortOption option, int readAtMillis})> _portDescriptors = {};

const _descriptorTtl = Duration(seconds: 30);

/// Ports the app could open, enumerated fresh — a USB adapter can appear or
/// vanish between one look and the next, so the LIST is never cached (see
/// [_portDescriptors] for what is).
List<SerialPortOption> availableSerialPorts() {
  _quietLibserialport();

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

  final now = realNowMillis();
  _portDescriptors.removeWhere((name, _) => !names.contains(name));

  return [
    for (final name in names)
      if (_portDescriptors[name] case final cached? when now - cached.readAtMillis < _descriptorTtl.inMilliseconds)
        cached.option
      else
        _remember(_describeSerialPort(name), now),
  ];
}

/// Keeps [option] as this port's answer for the next [_descriptorTtl].
///
/// A probe that read NOTHING is kept too, which looks wrong and is not: the
/// ports that refuse to be opened are exactly the busy ones — this app's own
/// live CAT session, or WSJT-X and fldigi holding a port — so re-probing them
/// on every tick is an open attempt against a busy port every three seconds,
/// on the UI isolate. The expiry is what recovers the descriptors once the
/// port frees up, at the cost of up to half a minute showing a bare name.
SerialPortOption _remember(SerialPortOption option, int nowMillis) {
  _portDescriptors[option.name] = (option: option, readAtMillis: nowMillis);
  return option;
}

SerialPortOption _describeSerialPort(String name) {
  final port = SerialPort(name);
  // Each attribute in its own try, because on macOS they do not fail
  // together: `vendorId`/`productId` throw for every port, while
  // `description` answers normally (a CP2105 reads back as "CP2105 Dual USB
  // to UART Bridge Controller" — observed on macOS 26). Fetched as one
  // block, the USB ids' throw would cost the description too, leaving the
  // picker showing bare device names like `cu.usbserial-01AF7D0E0`.
  T? probe<T>(String field, T Function() read) {
    try {
      return read();
    } catch (e) {
      debugPrint('[cat] port $name: no $field ($e)');
      return null;
    }
  }

  final option = SerialPortOption(
    name: name,
    description: probe<String?>('description', () => port.description),
    manufacturer: probe<String?>('manufacturer', () => port.manufacturer),
    productName: probe<String?>('productName', () => port.productName),
    serialNumber: probe<String?>('serialNumber', () => port.serialNumber),
    vendorId: probe<int?>('vendorId', () => port.vendorId),
    productId: probe<int?>('productId', () => port.productId),
  );
  port.dispose();
  return option;
}
