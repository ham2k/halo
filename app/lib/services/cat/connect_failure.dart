// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a failed connect is called: the bounded class that telemetry and a
// DEVLOGCAT recording carry, and the words the equipment row shows for it.

import 'dart:async';

import 'package:halo_i18n/halo_i18n.dart';

import 'transport.dart';

/// A bounded classification, never the exception's text: `'$e'` routinely
/// carries the port path or host that failed. Matched on the type NAME for
/// SocketException because dart:io does not exist on web, where CatService
/// runs over Web Serial.
String connectFailureReason(Object error) {
  if (error is TimeoutException) return 'timeout';
  if (error.runtimeType.toString() == 'SocketException') return 'network';
  // A real type test, not a name match: SerialPortProblem lives in
  // transport.dart precisely so the two serial transports — which never
  // compile into the same binary — can both be recognized here. Its own
  // classification is carried from the throw site, which is the only place
  // that knows whether the port was absent, held or refused.
  if (error is SerialPortProblem) return 'serial:${error.failure.name}';
  return 'other';
}

/// What the equipment row shows for a failed connect. [reason] is
/// [connectFailureReason]'s classification, reused rather than re-derived so
/// there's one place deciding what counts as a network or timeout error.
/// `'other'` keeps the exception's own words — `error.toString()` — since
/// guessing at an unfamiliar cause would be more likely to mislead an
/// operator than a raw Dart message already is.
String friendlyConnectError(String reason, Object error) {
  switch (reason) {
    case 'timeout':
      return t.settings.station.connectFailedTimeout;
    case 'network':
      return t.settings.station.connectFailedNetwork;
    // "Could not open /dev/cu.usbserial-FTB6SPL3: No such file or directory"
    // names a path the operator never typed and a POSIX errno they cannot
    // act on. Each of these says what to do about it instead — and they are
    // three different things to do, which is why one message for all of
    // them would send an operator to check a cable that is fine.
    case 'serial:missing':
      return t.settings.station.connectFailedDevice;
    case 'serial:busy':
      return t.settings.station.connectFailedBusy;
    case 'serial:denied':
      return t.settings.station.connectFailedDenied;
    case 'serial:lines':
      return t.settings.station.connectFailedLines;
    default:
      // 'serial:other' included: a cause the transport could not place
      // keeps its own words rather than being translated into a guess.
      return '$error';
  }
}
