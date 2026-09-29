// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Raw bindings for the parts of the Web Serial API this app uses.
// `package:web` 1.1.1 doesn't generate these — Web Serial isn't in the
// stable web-standards set it covers — so this is hand-written, the first
// `@JS()` extern anywhere in this codebase (every other `_web.dart` file
// rides on `package:web`'s own generated bindings). Kept to exactly the
// surface `serial_transport_web.dart` needs, nothing more.
//
// https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API
// Chromium-only (Chrome, Edge, Opera) — Safari and Firefox have no Web
// Serial API at all, which is why every access here goes through a
// nullable getter rather than assuming the browser supports it.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// `undefined` — not an exception — on a browser with no Web Serial
/// support at all, which `external` getters map straight to Dart `null`.
@JS('navigator.serial')
external Serial? get navigatorSerial;

@JS()
extension type Serial._(JSObject _) implements JSObject {
  /// Devices this origin already has permission for — no picker, no user
  /// gesture required.
  external JSPromise<JSArray<SerialPort>> getPorts();

  /// Opens the browser's own native device-picker. Only honored from
  /// inside a real user gesture (a click), and rejects if the operator
  /// cancels it or nothing matches.
  external JSPromise<SerialPort> requestPort([SerialPortRequestOptions options]);
}

@JS()
extension type SerialPort._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(SerialOptions options);
  external JSPromise<JSAny?> close();

  /// DTR/RTS, set to what the pairing says on every connect — on the common
  /// interfaces (Digirig, SignaLink, most home-brew cables) RTS *is* the PTT
  /// line, so it is never left to the browser.
  external JSPromise<JSAny?> setSignals([SerialOutputSignals signals]);

  external SerialPortInfo getInfo();

  /// Non-null only between a successful [open] and [close].
  external web.ReadableStream? get readable;
  external web.WritableStream? get writable;
}

@JS()
extension type SerialOptions._(JSObject _) implements JSObject {
  external factory SerialOptions({required int baudRate, int dataBits, int stopBits, String parity, String flowControl});
}

@JS()
extension type SerialOutputSignals._(JSObject _) implements JSObject {
  external factory SerialOutputSignals({bool dataTerminalReady, bool requestToSend});
}

/// All Web Serial exposes about a granted port: the USB vendor/product
/// pair. No manufacturer/product NAME, no serial number, nothing string-y
/// like libserialport's enumeration gets on desktop — the browser only
/// ever lets a page see numeric USB identifiers, on purpose.
@JS()
extension type SerialPortInfo._(JSObject _) implements JSObject {
  external int? get usbVendorId;
  external int? get usbProductId;
}

@JS()
extension type SerialPortRequestOptions._(JSObject _) implements JSObject {
  external factory SerialPortRequestOptions({JSArray<SerialPortFilter>? filters});
}

@JS()
extension type SerialPortFilter._(JSObject _) implements JSObject {
  external factory SerialPortFilter({int? usbVendorId, int? usbProductId});
}
