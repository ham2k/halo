// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'transports/serial_transport_io.dart' show SerialPortUnavailable;
import 'transports/udp_transport_io.dart' show UdpReplyPortTaken;

/// The OS's message and code for [error] — "Network is unreachable (errno
/// 101)" — or null when it carries none.
///
/// Only those two fields, never `'$error'`: a SocketException's text names
/// the address and port, and a serial error's names the device path, which
/// on macOS carries the adapter's serial number. A libserialport
/// `SerialPortError` is an [OSError], so a serial failure reads the same way
/// as a network one.
String? osErrorDetail(Object error) => switch (error) {
  SocketException(osError: final os?) => _describe(os),
  OSError() => _describe(error),
  SerialPortUnavailable(osError: final os?) => _describe(os),
  UdpReplyPortTaken(osError: final os?) => _describe(os),
  _ => null,
};

String? _describe(OSError os) {
  final hasCode = os.errorCode != OSError.noErrorCode;
  if (os.message.isEmpty) return hasCode ? 'errno ${os.errorCode}' : null;
  return hasCode ? '${os.message} (errno ${os.errorCode})' : os.message;
}
