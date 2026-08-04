// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial over libserialport (FFI, same shape as the halo_quickjs plugin).
// Desktop only for now: Android's USB host stack needs a different package
// and a runtime permission flow, and iOS has no USB host API at all without
// MFi.
//
// PLATFORM COST, none of it optional:
//   - macOS needs `com.apple.security.device.serial` in BOTH entitlement
//     files. It is a sandbox relaxation, not one of the AMFI-restricted
//     entitlements that break spawning — but verify on a SIGNED Release
//     build, because Debug passes regardless.
//   - Linux CI needs `libudev-dev` to build libserialport.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../transport.dart';
import 'serial_transport_config.dart';

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

  @override
  String get key => transportKey;

  @override
  List<SerialPortOption> get availablePorts => availableSerialPorts();

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    _quietLibserialport();

    final name = target['port'] as String? ?? '';
    final baudRate = (target['baudRate'] as num?)?.toInt() ?? 4800;

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
        ..stopBits = 1
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
