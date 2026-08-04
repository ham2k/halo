// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial over the Web Serial API — Chromium browsers only (Chrome, Edge,
// Opera); Safari and Firefox have no equivalent, and behave exactly like
// the stub they'd otherwise get (empty port list, `connect()` throws).
//
// Two things this platform can't avoid, unlike the io transport:
//
//   - No stable port identity. Web Serial exposes only a USB vendor/product
//     pair per granted port — no OS device path, no serial number. Two
//     identical devices granted at once are only told apart by enumeration
//     order, which is best-effort; there is nothing more specific the API
//     will give a page.
//   - Granting access to a NEW device needs `requestPort()`, which only
//     works from inside a real user gesture and opens the browser's own
//     native picker. That's the `type: 'action'` button `configElements`
//     adds below — see `EquipmentTransport.runAction` and
//     `form_renderer.dart`'s `FormActionResult`.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../../i18n/strings.g.dart';
import '../transport.dart';
import 'serial_transport_config.dart';
import 'web_serial_interop.dart';
import 'web_serial_port_keys.dart';

class SerialTransport extends EquipmentTransport with SerialTransportConfig {
  const SerialTransport();

  static const transportKey = 'serial';

  static const _requestDeviceActionKey = 'requestWebSerialDevice';
  static const _requestDeviceMethod = 'requestDevice';

  /// Keyed the same way as [_cachedPortOptions]' options — see
  /// `assignWebSerialPortKeys`. Both are static — there is exactly one
  /// `navigator.serial` for the whole page, same reasoning as
  /// `serial_transport_io.dart`'s enumeration being a free function rather
  /// than per-instance state.
  static Map<String, SerialPort> _grantedPorts = const {};
  static List<SerialPortOption> _cachedPortOptions = const [];

  @override
  String get key => transportKey;

  @override
  List<SerialPortOption> get availablePorts => _cachedPortOptions;

  /// Populates [_grantedPorts]/[_cachedPortOptions] from `getPorts()` —
  /// already-authorized devices only, no picker, no gesture needed. Called
  /// by `station_panel.dart` right before the (synchronous)
  /// `configElements()` it feeds.
  @override
  Future<void> prepareConfigElements() async {
    final serial = navigatorSerial;
    if (serial == null) return;

    List<SerialPort> ports;
    try {
      ports = (await serial.getPorts().toDart).toDart;
    } catch (e) {
      debugPrint('[cat] web serial port enumeration unavailable: $e');
      return;
    }

    final infos = [for (final port in ports) port.getInfo()];
    final keys = assignWebSerialPortKeys([for (final info in infos) (info.usbVendorId, info.usbProductId)]);

    final granted = <String, SerialPort>{};
    final options = <SerialPortOption>[];
    for (var i = 0; i < ports.length; i++) {
      granted[keys[i]] = ports[i];
      options.add(SerialPortOption(
        name: keys[i],
        description: describeWebSerialUsbId(infos[i].usbVendorId, infos[i].usbProductId),
      ));
    }
    _grantedPorts = granted;
    _cachedPortOptions = options;
  }

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) {
    final fields = super.configElements(overrides: overrides, restrictions: restrictions);
    // No point offering to grant a device for a field the operator can't
    // even see, or on a browser that doesn't have the API to grant one on.
    if (overrides.containsKey('port') || navigatorSerial == null) return fields;
    // Lives INSIDE the port field's own options, not as a separate button
    // beside it — picking it runs the action instead of becoming the
    // field's value (FormRenderer's `isAction` option contract), so the
    // operator sees "add a device" exactly where they're already looking
    // for a device to pick.
    return [
      for (final field in fields)
        if (field['key'] == 'port')
          {
            ...field,
            'options': [
              ...(field['options'] as List),
              {
                'value': _requestDeviceActionKey,
                'label': t.settings.station.serialDeviceRequest,
                'isAction': true,
                'method': _requestDeviceMethod,
              },
            ],
          }
        else
          field,
    ];
  }

  @override
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) async {
    if (actionKey != _requestDeviceActionKey) return null;
    final serial = navigatorSerial;
    if (serial == null) return null;

    final SerialPort port;
    try {
      port = await serial.requestPort().toDart;
    } catch (e) {
      // The overwhelmingly common case is the operator dismissing the
      // browser's own picker — not a failure worth a toast over. A
      // genuinely broken browser would have hidden this button already
      // (configElements checks navigatorSerial), so anything else reaching
      // here is rare enough not to warrant telling them apart.
      return null;
    }

    await prepareConfigElements();
    String? name;
    for (final entry in _grantedPorts.entries) {
      if (entry.value == port) {
        name = entry.key;
        break;
      }
    }
    if (name == null) return null;
    return EquipmentActionResult(fieldUpdates: {'port': name});
  }

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    final serial = navigatorSerial;
    if (serial == null) {
      throw UnsupportedError(
          'CAT control over serial needs the Web Serial API, which this browser does not support — try Chrome, Edge, or Opera.');
    }

    final name = target['port'] as String? ?? '';
    final port = _grantedPorts[name];
    if (port == null) {
      throw SerialPortUnavailable(name, 'no longer granted — pick it again from the port list');
    }

    final baudRate = (target['baudRate'] as num?)?.toInt() ?? 4800;

    try {
      await port
          .open(SerialOptions(baudRate: baudRate, dataBits: 8, stopBits: 1, parity: 'none', flowControl: 'none'))
          .toDart;
    } catch (e) {
      throw SerialPortUnavailable(name, '$e');
    }

    if (cancel.isCancelled) {
      unawaited(port.close().toDart);
      throw const CatCancelledException();
    }

    try {
      // Best effort, and deliberately not awaited into the connect
      // failing: never assert either signal (RTS is PTT on common
      // interfaces — see web_serial_interop.dart), but a browser/OS that
      // refuses signal control entirely is not worth taking the whole
      // connection down for, especially since every browser observed so
      // far already leaves both deasserted after `open()` on its own.
      await port.setSignals(SerialOutputSignals(dataTerminalReady: false, requestToSend: false)).toDart;
    } catch (e) {
      debugPrint('[cat] could not set web serial signals: $e');
    }

    return _WebSerialConnection(port, name);
  }
}

/// The port could not be opened, or was granted once but isn't any more —
/// Web Serial revokes a grant if the device is unplugged, and the browser
/// gives no event for that beyond the next `getPorts()` simply not listing
/// it. Same shape as the io transport's exception of the same name; never
/// both compiled into one binary, so nothing forces them to match.
class SerialPortUnavailable implements CatUnreachable {
  final String portName;
  final String reason;

  const SerialPortUnavailable(this.portName, this.reason);

  @override
  String toString() => 'Could not open $portName: $reason';
}

class _WebSerialConnection implements EquipmentConnection {
  final SerialPort _port;
  final String _name;
  late final web.ReadableStreamDefaultReader _reader;
  late final web.WritableStreamDefaultWriter _writer;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  _WebSerialConnection(this._port, this._name) {
    _reader = _port.readable!.getReader() as web.ReadableStreamDefaultReader;
    _writer = _port.writable!.getWriter();
    unawaited(_pump());
  }

  Future<void> _pump() async {
    try {
      while (true) {
        final result = await _reader.read().toDart;
        if (result.done) break;
        final value = result.value;
        if (value != null) _dataController.add((value as JSUint8Array).toDart);
      }
    } catch (e) {
      // The read errors when the device drops mid-session — a USB-serial
      // adapter unplugged, same event `_Socket.done` erroring reports for
      // the io transport.
      debugPrint('[cat] web serial $_name dropped: $e');
    } finally {
      await _markClosed();
    }
  }

  /// Unlike a real `Socket`, a dropped `SerialPort` does NOT release itself
  /// when its read rejects — Chromium keeps it marked open until `close()`
  /// is called explicitly, drop or not. `CatService` never calls
  /// [close] again for a connection that closed on its own (by design —
  /// see its `_closeSession` doc), so this path has to do that release
  /// itself, or the next `open()` on this same cached [SerialPort] throws
  /// `InvalidStateError: The port is already open.`
  ///
  /// [closed] is deliberately completed AFTER the release below, not
  /// before: `CatService` starts its own reconnect attempt — reopening
  /// this very [_port] — the moment [closed] fires. Completing it early
  /// would race that reopen against this teardown, and lose.
  Future<void> _markClosed() async {
    if (!_open) return;
    _open = false;
    unawaited(_dataController.close());
    try {
      _reader.releaseLock();
    } catch (_) {}
    try {
      _writer.releaseLock();
    } catch (_) {}
    try {
      await _port.close().toDart;
    } catch (e) {
      // Already gone — an unplugged adapter takes the handle with it.
      debugPrint('[cat] web serial port teardown: $e');
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
    // has gone away must not throw into a timer callback — and `write`'s
    // returned promise, unlike a synchronous call, would otherwise reject
    // unhandled in the JS console rather than reach a Dart catch at all.
    try {
      unawaited(_writer.write(Uint8List.fromList(bytes).toJS).toDart.catchError((Object e) {
        debugPrint('[cat] web serial write failed: $e');
        return null;
      }));
    } catch (e) {
      debugPrint('[cat] web serial write failed: $e');
    }
  }

  @override
  Future<void> close() => _markClosed();
}
