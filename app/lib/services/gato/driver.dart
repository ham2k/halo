// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Drivers speak a radio's protocol over an already-open connection. A
// driver never opens or closes anything, never discovers anything, and
// never writes to app state — it is handed a sink and reports through it.
//
// That last part is a deliberate departure from app-polo, whose drivers
// dispatched straight into the redux store: it works for exactly one radio
// and couples every driver to the app's state shape. Reporting to the
// manager is what makes a driver testable with a plain fake sink, and what
// makes a second device a map lookup rather than a rewrite.

import 'dart:typed_data';

import 'equipment.dart';

/// What a session is allowed to do: write bytes, and report what it read.
abstract class EquipmentSink {
  /// Never throws — see [EquipmentConnection.send].
  void send(List<int> bytes);

  /// A fresh reading from the equipment.
  void report(VfoReading reading);
}

/// One driver's state for one open connection.
abstract class EquipmentSession {
  /// A raw chunk off the wire. May contain a partial frame, several
  /// frames, or the tail of one and the head of the next — a session that
  /// assumes chunk boundaries are frame boundaries is wrong. (polo's
  /// FlexRadio driver split each chunk on `\n` with no residual buffer;
  /// this port keeps one.)
  void handleData(Uint8List chunk);

  /// Begin receiving state updates — subscribe on a push protocol, start
  /// polling on one that isn't.
  ///
  /// Called on connect, not when a UI subscriber appears: polo gated this
  /// on a subscriber refcount, so a connect with no screen mounted
  /// succeeded and then never asked the radio anything — a green status
  /// with a frozen frequency, and hard to diagnose.
  void startUpdates();

  void stopUpdates();

  /// Retunes the equipment. Frequency is kHz with decimals.
  void setFrequency(double freqKHz);

  /// Sets the mode. Always a concrete mode — `SSB` is resolved to `USB` or
  /// `LSB` by the manager before it reaches a driver, because no CAT
  /// protocol has an "SSB" mode.
  void setMode(String mode);

  /// Say goodbye over a still-open connection: unsubscribe, cancel timers.
  /// The manager calls this *before* closing, in its own guard. polo found
  /// abandoned sessions accumulating on an IC-705 until it refused new
  /// connections — surviving a power cycle.
  void teardown();
}

abstract class EquipmentDriver {
  /// Stable id, e.g. `flexradio`.
  String get key;

  /// Display name of the protocol/radio family.
  String get name;

  /// Whether this driver has been exercised against the actual hardware.
  ///
  /// Not decoration: polo shipped one verified driver, deleted one it
  /// could never make reliable, and caveated a third it never tested. The
  /// type picker shows this rather than presenting all drivers as equally
  /// trustworthy.
  bool get hardwareVerified;

  /// [config] is the node's stored configuration — the same map the type's
  /// `configElements` collected. Most drivers ignore it; a CI-V driver needs
  /// it, because the radio's bus address is per-radio and settable on the
  /// radio itself, and app-polo's IC-705 attempt is on record as having lost
  /// bench time to a wrong address it had no way to change.
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config);
}
