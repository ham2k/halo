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

  /// What the radio's voice keyer is doing for the app — playing or
  /// recording a memory — and null once it is idle again. Only from a
  /// [VoiceKeyerSession]; the keyer area shows it (docs/design/cat.md
  /// § Voice keying). Sessions report the end when the radio says so, or
  /// at [voiceActivityCeiling] when it never does.
  void reportVoiceActivity(VoiceActivity? activity);

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

  /// The equipment answered, and the answer carried nothing about its state —
  /// a command acknowledgement, a ping reply. Re-arms the silence watch
  /// ([EquipmentState.stale]) and nothing else.
  ///
  /// Only for a driver whose readings travel the SAME path the answer took,
  /// and only for something the RADIO sent. That is why this is a driver's
  /// call and not the manager counting bytes on the connection: a CI-V or
  /// RS-485 bus echoes our own polls back, so a byte counter keeps a
  /// powered-off radio on a serial adapter green forever — the drivers
  /// discard those echoes, and only they know one from an answer. And an
  /// acknowledgement on one channel says nothing about another: `stale`
  /// exists for a live session over a dead reading stream, so a driver
  /// whose control and reading paths differ never calls this. What it does
  /// NOT vouch for even on one socket is the radio's own subscription
  /// table; a driver that relies on it keeps its resync. A reading already
  /// counts as life, so a driver never calls this for one.
  void reportAlive();
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

/// A session that can key CW from text and set a keyer's speed — a
/// transceiver whose CAT protocol has it (the IC-7300 family's `0x17`, the
/// Yaesu keyer-memory playback, FlexRadio's CWX) or a keyer of its own, a
/// K1EL Winkeyer.
///
/// A capability of its own rather than three more methods on
/// [TransceiverSession], for the same reason [AntennaSwitchSession] is:
/// most radio protocols here (flrig, rigctld, Kenwood…) have no such
/// command, and "this radio ignores sendCw" must not look like "this radio
/// keyed nothing because the text was empty" — and a keyer has no VFO to be
/// a transceiver with at all. A transceiver that keys implements both.
/// [CatService] asks with `is` and offers the keying surfaces only when the
/// designated key's session answers yes.
///
/// Whether the radio actually TRANSMITS is the radio's own break-in setting;
/// with break-in off the CAT families key only the sidetone. Deliberately
/// not touched here: an app that flips break-in on so its message goes out
/// has put RF on the air from a radio the operator set up not to.
abstract class CwKeyerSession implements EquipmentSession {
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

/// One voice memory the radio is busy with on the app's behalf.
class VoiceActivity {
  /// The memory, 1-based, as the radio numbers it.
  final int memory;

  /// Recording into [memory] rather than playing it.
  final bool recording;

  /// The radio said it was over before it ever said it was going: a
  /// refused play (the memory empty, the radio not in a voice mode) or a
  /// very short one, which no protocol here tells apart. Shown with a
  /// question mark for [voiceDoubtLinger], then gone.
  final bool doubtful;

  const VoiceActivity({required this.memory, this.recording = false, this.doubtful = false});

  VoiceActivity asDoubtful() => VoiceActivity(memory: memory, recording: recording, doubtful: true);

  @override
  bool operator ==(Object other) =>
      other is VoiceActivity && other.memory == memory && other.recording == recording && other.doubtful == doubtful;

  @override
  int get hashCode => Object.hash(memory, recording, doubtful);

  @override
  String toString() => 'VoiceActivity(${recording ? 'recording' : 'playing'} $memory${doubtful ? '?' : ''})';
}

/// The config key a catalogue entry pins a radio's voice memory count
/// under, for any driver whose sessions are [VoiceKeyerSession]s — zero for
/// a rig on a line whose driver otherwise assumes one (an IC-706 on the
/// CI-V driver). Absent means the driver's own default. A GENERIC entry
/// pins nothing and prefills zero, and shows the field under developer
/// mode: the catalogue does not know which rig is behind it, so a
/// developer says (docs/design/cat.md § Voice keying).
const voiceMemoriesConfigKey = 'voiceMemories';

/// The most memories any surface offers: one per function key, and the
/// number of labels stored (`voiceMessageLabel1..8`). A count above it is
/// clamped here rather than crashing a strip indexing eight icons.
const maxVoiceMemories = 8;

/// The config key under which a catalogue entry says whether the radio's
/// CAT keys CW — `true`/`false` on a driver that keys by default (Icom,
/// Yaesu), where absent means it does; the Kenwood driver keys only with a
/// dialect named (`cwDialect`, kenwood_driver.dart). Like
/// [voiceMemoriesConfigKey]: pinned on the named entries, asked under
/// developer mode on the generics.
const cwKeyerConfigKey = 'cwKeyer';

/// [voiceMemoriesConfigKey]'s value as a count, or [fallback] when absent —
/// a number field stores a num, a pinned override an int, and a value typed
/// into a text-shaped form arrives as a String.
int voiceMemoriesFromConfig(Map<String, dynamic> config, {required int fallback}) {
  final raw = config[voiceMemoriesConfigKey];
  final count = raw is num ? raw.round() : (raw is String ? int.tryParse(raw.trim()) : null);
  return (count != null && count >= 0 ? count : fallback).clamp(0, maxVoiceMemories);
}

/// [cwKeyerConfigKey] as a bool: absent is [fallback], and a checkbox
/// stores a bool.
bool cwKeyerFromConfig(Map<String, dynamic> config, {required bool fallback}) => switch (config[cwKeyerConfigKey]) {
      final bool on => on,
      'true' => true,
      'false' => false,
      _ => fallback,
    };

/// The longest a session lets a memory play or record without the radio
/// confirming it is over, when nothing better is known: a memory is a CQ or
/// an exchange, seconds long, and a radio whose protocol never answers
/// "still playing?" clears at this — and is told to stop — rather than
/// showing a message playing on. A radio whose memory length IS known
/// ([voiceCeilingConfigKey], [VoiceKeyerSession.voiceMemoryCeiling]) gets
/// that instead: the memory cannot run longer than it holds.
const voiceActivityCeiling = Duration(seconds: 15);

/// The config key a catalogue entry pins how long the radio's memories hold,
/// in seconds — from its manual (an IC-7300's 90, an FT-891's 20, a KX3's
/// 15). Absent means [voiceActivityCeiling]: a generic entry, or a radio
/// whose manual has not been read for it.
const voiceCeilingConfigKey = 'voiceCeilingSeconds';

/// [voiceCeilingConfigKey] as a duration, or [voiceActivityCeiling].
Duration voiceCeilingFromConfig(Map<String, dynamic> config) {
  final raw = config[voiceCeilingConfigKey];
  final seconds = raw is num ? raw.round() : (raw is String ? int.tryParse(raw.trim()) : null);
  return seconds != null && seconds > 0 ? Duration(seconds: seconds) : voiceActivityCeiling;
}

/// How long a doubtful activity shows its question mark before clearing.
const voiceDoubtLinger = Duration(seconds: 1);

/// A transceiver whose CAT can play — and sometimes record — the voice
/// memories it holds itself. The counterpart of [CwKeyerSession] for Phone
/// modes: the messages are audio in the radio, so the app keys a memory
/// NUMBER, never text, and the only thing it stores is a label.
///
/// A capability, like the CW one, and for the same reasons: most protocols
/// here have no such command, and "this radio has no voice memories" must
/// never look like "the memory was empty". Unlike CW there is no break-in
/// question — a voice memory transmits — which is why the surfaces that
/// play one exist only in a Phone mode.
abstract class VoiceKeyerSession implements EquipmentSession {
  /// How many memories this radio has, 1-based up to here. Zero means
  /// none: a driver shared across a line (Kenwood CAT) creates sessions
  /// that implement this for rigs that have no voice keyer at all.
  int get voiceMemoryCount;

  /// Whether [recordVoiceMemory] does anything — the Yaesu line and the
  /// K4 record over CAT, Icom's is front-panel only.
  bool get canRecordVoice;

  /// The longest a memory can play or record on this radio — its memory
  /// length when the entry pinned one ([voiceCeilingConfigKey]),
  /// [voiceActivityCeiling] otherwise. Past it a session stops the radio
  /// and clears what it showed (voice_activity_tracker.dart).
  Duration get voiceMemoryCeiling;

  /// Plays memory [n] through the transmitter. Reported through
  /// [EquipmentSink.reportVoiceActivity] as it starts and when the radio
  /// says it is over.
  void playVoiceMemory(int n);

  /// Starts recording into memory [n] from the radio's own microphone;
  /// [stopVoice] ends it. Nothing on a session whose [canRecordVoice] is
  /// false.
  void recordVoiceMemory(int n);

  /// Stops whatever is playing or recording.
  void stopVoice();
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

  /// Whether this driver's sessions are [CwKeyerSession]s — known without a
  /// session, so the "key in use" pick can offer a radio's own keyer while
  /// the radio is not connected. A driver that says true here must create
  /// sessions that are.
  bool get canKeyCw => false;

  /// [canKeyCw] for one node: [config] is the node's merged configuration
  /// (the entry's overrides included), and a driver whose keyer is a
  /// per-entry fact — [cwKeyerConfigKey] — answers from it. The service
  /// asks THIS, never the bare getter: a generic Icom picked for a rig with
  /// no keyer must not be offered as the key in use.
  bool canKeyCwWith(Map<String, dynamic> config) => canKeyCw;

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
