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

  /// Something a DEVELOPER would want to know about this session — what a
  /// protocol negotiated, what a driver had to work out for itself. Not an
  /// error (nothing is wrong) and not a reading (it is about the session, not
  /// the radio's state), which is why it is neither of those.
  ///
  /// Shown only under developer mode and never persisted. A driver that has
  /// nothing to say never calls it, and null clears whatever it last said.
  ///
  /// The point is diagnosing a rig we do not have: the Kenwood driver works
  /// out where the mode sits in an `IF` packet, and if that goes wrong on
  /// someone's radio the alternative to reporting it is a bench session with
  /// hardware nobody on the project owns.
  void reportDiagnostic(String? note);
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

  /// How long the manager should expect to wait to hear about a change the
  /// operator has already made — the poll period, live, on a session that
  /// polls. **Null on a session that pushes**, which is a different claim
  /// from a short interval: it says a change is reported as it happens, so
  /// silence means the radio is not moving.
  ///
  /// The manager cannot infer this. Every session looks the same from
  /// outside — readings arrive — and the difference between "nothing has
  /// happened" and "nobody has asked yet" is invisible until a driver says
  /// which it is. Smart VFO Snap needs it to know when a quiet VFO is
  /// actually a settled one (docs/design/cat.md § Smart VFO Snap); the
  /// staleness watchdog wants the same number.
  ///
  /// No default: `implements` would ignore one anyway, and a driver that
  /// forgets to answer would silently claim to push.
  Duration? get expectedUpdateInterval;
}

abstract class EquipmentDriver {
  const EquipmentDriver();

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

  /// FormRenderer elements for this driver's own protocol settings (a CI-V
  /// bus address, for one). Nothing about how the bytes get there — that's
  /// [EquipmentTransport.configElements].
  ///
  /// See [EquipmentTransport.configElements] for what [overrides] and
  /// [restrictions] mean; a key this driver doesn't recognize is silently
  /// ignored — it belongs to the transport instead.
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      const [];

  /// Per-field version, for the editor. Null for a key this driver doesn't
  /// own.
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => null;

  /// Every config key this driver reads, whether or not it shows a field
  /// for it — see [EquipmentTransport.recognizedConfigKeys]. The IC-705's
  /// network controller address is the reason this exists: read directly
  /// in [createSession], on every pairing, never shown as a field on any
  /// of them.
  Set<String> get recognizedConfigKeys =>
      configElements().where((e) => e['type'] == 'field').map((e) => e['key'] as String).toSet();

  /// An optional trailing fragment for the equipment list's one-line
  /// summary — e.g. ` · CI-V A4`. Null for a driver with nothing to add.
  ///
  /// [overrides] is the same map [configElements] gets — a driver that
  /// hardcodes the value this suffix would show (never a field the user
  /// sees) should suppress the suffix too, the same way it suppresses the
  /// field.
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) => null;
}
