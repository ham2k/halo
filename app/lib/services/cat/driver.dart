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

import 'drivers/cw_send_queue.dart' show CwSendProgress;
import 'equipment.dart';

/// What a session is allowed to do: write bytes, and report what it read.
abstract class EquipmentSink {
  /// Never throws — see [EquipmentConnection.send].
  void send(List<int> bytes);

  /// A fresh reading from the equipment.
  void report(VfoReading reading);

  /// A fresh RF output power reading, in watts. Only called by a driver
  /// whose protocol actually answers a power query — one that never asks
  /// never calls this, which is how [EquipmentState.power] tells "unknown"
  /// apart from "the radio said zero".
  void reportPower(num watts);

  /// The radio's keyer speed, in WPM, as the radio reports it — only from a
  /// [CwKeyerSession], and only after asking or being told. Like
  /// [reportPower], never called by a driver whose protocol has no keyer,
  /// which is how [EquipmentState.keyerSpeed] tells "unknown" from a value.
  void reportKeyerSpeed(int wpm);

  /// What the keyer is sending on the app's behalf — as each message starts,
  /// and null when it stops. Only from a [CwKeyerSession]; the status bar
  /// shows it (docs/design/cat.md § CW keying).
  void reportCwProgress(CwSendProgress? progress);

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

  /// Connected and answering, but what the operator configured cannot be
  /// honoured — see [EquipmentState.problem]. Null clears it, which is how a
  /// slice that comes back into use stops being reported as missing.
  ///
  /// Not an error: a driver calls this for a condition RECONNECTING WOULD
  /// NOT FIX. Anything a retry could clear belongs in the connection's own
  /// failure path instead.
  void reportProblem(String? message);

  /// The channels this equipment currently offers, for a driver whose
  /// equipment has more than one — see [EquipmentChannel]. Called with the
  /// full list each time any of it changes; a driver with a single channel
  /// never calls it.
  void reportChannels(List<EquipmentChannel> channels);

  /// What an antenna switch is routing where — the full picture each time
  /// any of it changes, like [reportChannels].
  ///
  /// Both lists together rather than one call each, because a port names its
  /// antenna by key and means nothing without the list to resolve it
  /// against. Reported separately, every reconnect would put a frame on
  /// screen where each port points at an antenna that has not arrived yet,
  /// and the panel would draw an empty selection over a switch that is
  /// perfectly well connected.
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports);
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

/// A session for equipment the app tunes: everything with a VFO.
///
/// Split out of [EquipmentSession] rather than left on it because the layer
/// now carries equipment that has no frequency at all — an antenna switch,
/// and the rotators and relay boards docs/design/cat.md expects after it.
/// Left on the base, a switch's session would have to no-op three tuning
/// methods, and "this radio ignores setFrequency" and "this is not a radio"
/// would be the same shape. [CatService] asks with `is` at the three call
/// sites that tune, all of which already act on the designated radio alone.
abstract class TransceiverSession implements EquipmentSession {
  /// Retunes the equipment. Frequency is kHz with decimals.
  void setFrequency(double freqKHz);

  /// Sets the mode. Always a concrete mode — `SSB` is resolved to `USB` or
  /// `LSB` by the manager before it reaches a driver, because no CAT
  /// protocol has an "SSB" mode.
  void setMode(String mode);

  /// Sets the transceiver's RF output power, in watts. A driver whose
  /// protocol represents power as a relative scale (Kenwood's `PC`, CI-V's
  /// 0-255 level) converts against the radio's own rated maximum — see each
  /// driver's own notes on how confident that conversion is.
  void setPower(num watts);
}

/// A session for equipment that routes antennas to devices.
///
/// Reading is not here: state arrives through [EquipmentSink.reportSwitchState]
/// like every other reading, so a panel that only displays a switch never
/// needs this type. Only changing the routing does.
abstract class AntennaSwitchSession implements EquipmentSession {
  /// Points [portKey]'s device port at [antennaKey].
  ///
  /// Both keys are the equipment's own, as reported in [SwitchPort.key] and
  /// [SwitchAntenna.key] — never an index into either list, which would
  /// silently address the wrong relay on equipment that numbers its ports
  /// from one or leaves a gap.
  ///
  /// A driver REFUSES this while the port is transmitting rather than
  /// queueing it: switching a relay under RF is what destroys one, and a
  /// selection the operator made a moment ago is not worth honouring late.
  void selectAntenna(String portKey, String antennaKey);
}

/// A session for a transceiver whose CAT protocol can key CW from text and
/// set its internal keyer's speed — the IC-7300 family's `0x17`, the Yaesu
/// keyer-memory playback.
///
/// A capability of its own rather than three more methods on
/// [TransceiverSession], for the same reason [AntennaSwitchSession] is:
/// most radio protocols here (FlexRadio, flrig, rigctld…) have no such
/// command, and "this radio ignores sendCw" must not look like "this radio
/// keyed nothing because the text was empty". [CatService] asks with `is`
/// and offers the keying surfaces only when the answer is yes.
///
/// Whether the radio actually TRANSMITS is the radio's own break-in setting;
/// with break-in off both families key only the sidetone. Deliberately not
/// touched here: an app that flips break-in on so its message goes out has
/// put RF on the air from a radio the operator set up not to.
abstract class CwKeyerSession implements TransceiverSession {
  /// Keys [text] through the radio's keyer, in the order given, after
  /// whatever is already queued. Longer than the radio's own command
  /// buffer is fine — the session splits and paces it (see
  /// cw_send_queue.dart). Characters the keyer has no code for are dropped
  /// rather than sent, since a radio's reaction to one is undocumented.
  void sendCw(String text);

  /// Abandons whatever [sendCw] still has to send. Also aborts the message
  /// the radio is keying right now on a protocol that can (CI-V); a
  /// protocol that cannot finishes the current chunk and stops there.
  void stopCw();

  /// Whether a message is still going out — queued here, or estimated to
  /// still be keying on the radio.
  bool get cwSending;

  /// Drops one message waiting behind the current one, by the [id] the last
  /// report's `pendingIds` gave it — an id rather than a position, so a tap
  /// that lands after the queue moved on drops nothing rather than the
  /// wrong one. The rest, and what is keying, are left alone.
  void dropQueuedCw(int id);

  /// Sets the radio's keyer speed, in WPM, clamped to [keyerSpeedRange].
  /// The radio's reply — or the session's own read-back — comes up through
  /// [EquipmentSink.reportKeyerSpeed], never assumed from the set.
  void setKeyerSpeed(int wpm);

  /// The speeds the radio's keyer accepts, inclusive, from its CAT manual.
  ({int min, int max}) get keyerSpeedRange;

  /// Asks the radio for its keyer speed again. Sessions read it once on
  /// connect and never poll it — neither protocol announces a knob turn —
  /// so a surface about to show the value asks first.
  void refreshKeyerSpeed();
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

  /// The config field that picks which of the equipment's channels this
  /// node tracks, for equipment that has more than one — `slice` on a
  /// FlexRadio. Null for every other driver, where one target is one node.
  ///
  /// Two things read this. [CatService] uses it to tell two nodes on the
  /// SAME radio apart, so adding the second one is not mistaken for a
  /// duplicate of the first; the Station panel uses it to find the field
  /// whose options it should annotate with what each channel is doing.
  String? get channelKey => null;

  /// Every value [channelKey]'s field may take, in the order they are
  /// offered. Empty when [channelKey] is null.
  ///
  /// The FIRST is what a node that names no channel is tracking — a record
  /// written before the setting existed, which must keep pointing at the
  /// same channel it always did. Both this driver and [CatService] rely on
  /// that, so the order is a contract, not a presentation choice.
  ///
  /// Declared rather than read back out of [configElements] so the service
  /// can reason about free channels without parsing form definitions.
  List<String> get channelValues => const [];

  /// How many antenna ports this equipment has when nobody has asked it yet.
  ///
  /// Zero for everything that is not an antenna switch. A switch reports its
  /// real inventory over the wire, and that always wins — this is only what
  /// the editor offers to map antennas onto while the switch is
  /// disconnected, which is exactly when an operator sets one up for the
  /// first time.
  ///
  /// A catalogue fact rather than a config field: an 8x2 has eight antenna
  /// ports whatever the operator does with them, and asking would be asking
  /// them to read a number off the box that the box already told us.
  int get antennaPortCount => 0;

  /// How many device ports this equipment has when nobody has asked it yet —
  /// where the radios plug in. Zero for everything that is not a switch.
  ///
  /// Same standing as [antennaPortCount]: what the switch reports always
  /// wins, and this is only what a first-time setup is offered.
  int get devicePortCount => 0;

  /// An optional trailing fragment for the equipment list's one-line
  /// summary — e.g. ` · CI-V A4`. Null for a driver with nothing to add.
  ///
  /// [overrides] is the same map [configElements] gets — a driver that
  /// hardcodes the value this suffix would show (never a field the user
  /// sees) should suppress the suffix too, the same way it suppresses the
  /// field.
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) => null;
}
