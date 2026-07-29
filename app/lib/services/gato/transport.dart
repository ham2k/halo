// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Transports open connections and move bytes. They know nothing about what
// those bytes mean — that's a driver's job (see driver.dart, and the
// transport/driver split in docs/design/gato.md).

import 'dart:async';
import 'dart:typed_data';

/// Cancels an in-flight [EquipmentTransport.connect].
///
/// Dart has no `AbortController`, and `Socket.connect(..., timeout:)`
/// returns a future that can't be cancelled — so without an explicit token
/// a superseded attempt holds its socket for the whole handshake timeout.
/// app-polo's note on why that's not merely untidy: "some radios don't take
/// kindly to two overlapping connection attempts hitting them at once."
///
/// This is in `connect`'s signature from the first commit on purpose;
/// retrofitting it across every transport is what cost polo a hardening pass.
class CatCancelToken {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called, never with an error. Transports
  /// race this against their connect.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Thrown when an attempt is cancelled — by a newer connect, or by a
/// disconnect. Callers treat it as a clean exit, not a failure worth
/// reporting to the user.
class CatCancelledException implements Exception {
  const CatCancelledException();

  @override
  String toString() => 'Superseded by a newer connection attempt';
}

/// A live byte pipe to one piece of equipment.
abstract class EquipmentConnection {
  /// Raw chunks as they arrive. NOT framed — a driver must handle a frame
  /// split across two chunks itself.
  Stream<Uint8List> get data;

  /// Completes when the connection is gone, for any reason.
  Future<void> get closed;

  /// Writes bytes. Never throws: drivers call this from unguarded timers,
  /// and a write to an already-dead socket must not blow up inside a timer
  /// callback. [closed] is what tells anyone the connection is gone.
  void send(List<int> bytes);

  Future<void> close();
}

abstract class EquipmentTransport {
  /// Stable id referenced by [EquipmentType.transportKey], e.g. `tcp`.
  String get key;

  /// Opens a connection to [target] — the map an [EquipmentType] builds
  /// from the user's configuration.
  ///
  /// Throws [CatCancelledException] if [cancel] fires first; any other
  /// throw is a real connection failure.
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel});
}
