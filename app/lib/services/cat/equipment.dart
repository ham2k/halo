// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One configured piece of station equipment, as the user set it up — see
// docs/design/data-model.md § Stations. Pure data: no I/O, no Flutter.
//
// The record holds only what the user configured. Everything about a live
// connection (status, last error, current frequency) is rebuilt at runtime
// and deliberately never persisted: app-polo shipped a stale `connected`
// flag that survived restarts and lied about the radio.

import 'package:flutter/foundation.dart';

import 'spectrum.dart';

/// General characteristics of a piece of equipment, per data-model.md.
/// A plain string rather than an enum: the vocabulary is open-ended
/// ("antenna", "amplifier", "relay board"…) and only `transceiver` has any
/// behaviour today, so an enum would churn for nothing.
const kCategoryTransceiver = 'transceiver';

/// A physical antenna — no live connection, only a type worth recording
/// against a QSO.
const kCategoryAntenna = 'antenna';

/// A physical CW key — no live connection, only a type worth recording
/// against a QSO.
const kCategoryKey = 'key';

/// A keyer the app can drive — a K1EL Winkeyer — as opposed to a
/// [kCategoryKey], which is a thing on the desk with nothing to connect to.
/// Both are offered in the same "key in use" pick, alongside a radio whose
/// CAT can key; whichever is picked is what keys the app's messages
/// (docs/design/cat.md § CW keying).
const kCategoryKeyer = 'keyer';

/// A switch routing a set of antennas to a set of devices — a 4O3A Antenna
/// Genius today.
///
/// Not an antenna. The distinction is what the whole category is for: an
/// [kCategoryAntenna] node is a piece of wire in the air that a QSO can
/// credit, and a switch is the thing that decides WHICH of them is connected
/// right now. Filing a switch under antennas would put a relay box in the
/// list the operator picks their antenna from.
const kCategoryAntennaSwitch = 'antennaSwitch';

/// A receive-only SDR — an RTL-SDR, an SDRplay, an Airspy — that shows the
/// spectrum for a radio which has no scope of its own, or a better one than
/// the radio's (docs/design/cat.md § SDR receivers). Never a transceiver:
/// nothing tunes it but the app, and nothing logs from it.
const kCategorySdr = 'sdr';

/// An antenna rotator controller — a Yaesu GS-232A today. Its state is
/// where the antenna points, which is live and never persisted: a
/// remembered heading is a claim about a mast nobody has asked in a while.
const kCategoryRotator = 'rotator';

/// The config key naming the radio an SDR shows the spectrum for: a node's
/// uuid, or [sdrRadioMain] (also what an absent value means).
const sdrRadioConfigKey = 'sdrRadio';

/// [sdrRadioConfigKey]'s value for whichever radio is Main at the time.
const sdrRadioMain = 'main';

/// Old [EquipmentNode.typeKey] values, mapped to what the catalogue calls
/// them now.
///
/// A node resolves to its pairing by this key alone, and a rename that
/// forgot to land here fails silently in the worst way available: the record
/// survives, the panel lists it as an unrecognized type, and everything the
/// operator configured is still inside it with no way to reach it. Applied
/// on read, so the new key is what gets written back at the next save.
///
/// Entries are permanent. The whole point is a record written by a build
/// that predates the rename, and there is no upper bound on how old that
/// build can be.
const renamedTypeKeys = {
  // Named for the protocol, which only finds you if you already know your
  // radio speaks CI-V.
  'icom-civ-serial': 'icom-generic-serial',
};

@immutable
class EquipmentNode {
  /// Stable id, also the key this record is stored under.
  final String uuid;

  /// Which [EquipmentType] handles this node — model × transport, e.g.
  /// `flexradio-tcp`.
  final String typeKey;

  /// User-defined name ("Left Radio"). Empty falls back to the type name.
  final String name;

  /// Transport parameters plus any device-specific settings, as collected
  /// by the type's `configElements`. Free-form so a type's settings can
  /// grow without schema churn — the same reasoning as `Profile.data`.
  final Map<String, dynamic> config;

  const EquipmentNode({required this.uuid, required this.typeKey, this.name = '', this.config = const {}});

  /// [typeKey] changes when the operator picks a different transport for the
  /// same radio — the node is then bound to a different driver and transport,
  /// which is why [CatService.updateNode] drops any live connection rather
  /// than leaving a session built by the old pairing attached to it.
  EquipmentNode copyWith({String? typeKey, String? name, Map<String, dynamic>? config}) =>
      EquipmentNode(uuid: uuid, typeKey: typeKey ?? this.typeKey, name: name ?? this.name, config: config ?? this.config);

  Map<String, dynamic> toJson() => {'typeKey': typeKey, if (name.isNotEmpty) 'name': name, if (config.isNotEmpty) 'config': config};

  /// Reads one stored record. Returns null for anything unrecognisable
  /// rather than throwing — a corrupt entry drops that one node, it does
  /// not take the whole equipment list down with it.
  static EquipmentNode? fromJson(String uuid, dynamic raw) {
    if (raw is! Map) return null;
    final typeKey = raw['typeKey'];
    if (typeKey is! String || typeKey.isEmpty) return null;
    final config = raw['config'];
    return EquipmentNode(
      uuid: uuid,
      typeKey: renamedTypeKeys[typeKey] ?? typeKey,
      name: raw['name'] is String ? raw['name'] as String : '',
      config: config is Map ? config.cast<String, dynamic>() : const {},
    );
  }
}

/// How a node's connection is doing right now. In-memory only.
/// [disconnecting] is its own state because saying goodbye takes real time
/// on some transports — the Icom network teardown sends a logout, closes the
/// serial stream and disconnects two sessions, deliberately spaced so the
/// datagrams are not lost. Without it the row sits looking connected through
/// all of that and then blinks, which reads as a hang.
enum EquipmentStatus { disconnected, connecting, connected, disconnecting, error }

/// A VFO reading pushed up by a session.
///
/// Frequency is always kHz with decimals, matching `Vfo.freq` — a driver
/// converts on its own boundary and the service never guesses. app-polo
/// shipped a driver reporting Hz and displayed frequencies 1000× too large.
@immutable
class VfoReading {
  final double? freqKHz;
  final String? mode;

  const VfoReading({this.freqKHz, this.mode});

  bool get isEmpty => freqKHz == null && mode == null;

  @override
  bool operator ==(Object other) => other is VfoReading && other.freqKHz == freqKHz && other.mode == mode;

  @override
  int get hashCode => Object.hash(freqKHz, mode);

  @override
  String toString() => 'VfoReading(freqKHz: $freqKHz, mode: $mode)';
}

/// One of the radio's meters — what it is DOING, as opposed to where
/// [VfoReading] says it is tuned.
///
/// Polled meters are normally collected during transmission. Push-based
/// receive meters (such as Flex slice LEVEL) arrive independently of that cycle.
enum RadioMeter {
  /// Receive signal power in dBm, measured in the selected receiver passband.
  signalDbm,

  /// RF actually leaving the radio, in watts.
  ///
  /// NOT [EquipmentState.power], which is the level the radio is SET to.
  /// The two disagree for real reasons — an ATU folding back, a rig on its
  /// own battery — and merging them would send a measured 4.7 W back at the
  /// radio as a power command the operator never gave.
  powerOut,

  /// Standing wave ratio, as a ratio: 1.0 is a perfect match. At or above
  /// [swrAlertThreshold] the operator is told.
  swr,

  /// How hard the radio's ALC is working, as 0.0-1.0 of its own scale.
  ///
  /// A fraction rather than dB because that is all any of these protocols
  /// actually says: every one of them reports a relative figure against a
  /// full scale it never states.
  alc,

  /// DC input to the radio, in volts.
  supplyVolts,
}

/// The SWR at which the operator is warned.
///
/// Not the point where a rig folds back — most survive well past it — but
/// the point where the ANTENNA is telling you something: a match this far
/// off is a wet feedline, a wrong band, or an ATU that never found a
/// solution, and all three are worth knowing before the next call rather
/// than after the session.
const swrAlertThreshold = 1.8;

/// How long a meter reading stands after the radio stops confirming it.
///
/// Meters are read only while transmitting, so every reading is about to
/// stop being refreshed by design — that is the normal end of a
/// transmission, not a fault. Long enough to still be on screen when the
/// operator looks down after letting go of the key; short enough that the
/// SWR from an hour ago is never mistaken for the antenna they are on now.
const meterLinger = Duration(seconds: 8);

/// One meter's value, and when it was read.
///
/// The timestamp is what makes expiry the reader's decision rather than a
/// driver's: nothing in any of these protocols announces that a reading has
/// gone stale, and a driver clearing its own meters at unkey would have to
/// guess how long a panel wanted them for.
@immutable
class MeterReading {
  final num value;

  /// App-clock millis ([nowMillis], never `DateTime.now()` — docs/design/time.md).
  final int atMillis;

  const MeterReading(this.value, this.atMillis);

  @override
  bool operator ==(Object other) => other is MeterReading && other.value == value && other.atMillis == atMillis;

  @override
  int get hashCode => Object.hash(value, atMillis);

  @override
  String toString() => 'MeterReading($value @$atMillis)';
}

/// What the radio is doing right now: keyed or not, and what its meters
/// read while it is.
///
/// Live-only and never persisted, like everything else in [EquipmentState].
@immutable
class RadioTelemetry {
  /// Null until the radio has said.
  ///
  /// A driver whose protocol cannot answer never reports one, and "the
  /// radio is receiving" is a different claim from "nobody knows" — the
  /// difference decides whether it is safe to throw an antenna relay.
  final bool? transmitting;

  final Map<RadioMeter, MeterReading> meters;

  const RadioTelemetry({this.transmitting, this.meters = const {}});

  /// Keyed, as far as anything knows. An unanswered radio reads as
  /// receiving here; every caller that must not assume that reads
  /// [transmitting] itself.
  bool get isTransmitting => transmitting ?? false;

  RadioTelemetry withTransmitting(bool value) => RadioTelemetry(transmitting: value, meters: meters);

  RadioTelemetry withMeter(RadioMeter meter, num value, int atMillis) =>
      RadioTelemetry(transmitting: transmitting, meters: {...meters, meter: MeterReading(value, atMillis)});

  /// [meter]'s reading if it is still worth showing at [nowMillis], else
  /// null — see [meterLinger].
  MeterReading? fresh(RadioMeter meter, int nowMillis, {Duration linger = meterLinger}) {
    final reading = meters[meter];
    if (reading == null) return null;
    return nowMillis - reading.atMillis <= linger.inMilliseconds ? reading : null;
  }

  @override
  bool operator ==(Object other) => other is RadioTelemetry && other.transmitting == transmitting && mapEquals(other.meters, meters);

  @override
  int get hashCode => Object.hash(transmitting, Object.hashAllUnordered(meters.entries.map((e) => Object.hash(e.key, e.value))));

  @override
  String toString() =>
      'RadioTelemetry(${transmitting == null
          ? 'tx unknown'
          : transmitting!
          ? 'TX'
          : 'RX'}'
      '${meters.isEmpty ? '' : ', ${meters.entries.map((e) => '${e.key.name}=${e.value.value}').join(', ')}'})';
}

/// One of several independently-tunable channels the same piece of
/// equipment offers — a FlexRadio's slices, and nothing else today.
///
/// A node tracks exactly one of these ([EquipmentDriver.channelKey] names
/// the config field that picks it). The list exists so the operator can see
/// what the radio is actually doing before choosing: a slice already held by
/// SmartSDR on another machine is one they probably do not want, and the
/// alternative to showing it is picking a letter blind.
///
/// Live-only, like everything else in [EquipmentState] — a channel list is
/// what the radio said a moment ago, never what was configured.
@immutable
class EquipmentChannel {
  /// The value [EquipmentDriver.channelKey]'s field takes to select this
  /// channel — `'0'`..`'7'` for a Flex slice.
  final String key;

  /// What the equipment calls it: a Flex slice's own `index_letter`.
  final String label;

  /// False for a channel the radio knows about but is not running.
  final bool inUse;

  final double? freqKHz;
  final String? mode;

  /// Who has this channel, as the equipment describes them — "SmartSDR-Win
  /// (SHACK-PC)". Null when the equipment named nobody, which is not the
  /// same as nobody holding it — see [heldByUnknown].
  final String? usedBy;

  /// Something holds this channel and the equipment has not said what.
  ///
  /// Its own flag because the difference decides the operator's answer: an
  /// unowned channel is one to take, and a channel held by a program we
  /// could not name is one to leave alone. Collapsing both into a null
  /// [usedBy] renders the second as the first — worse than showing no
  /// inventory at all, because by then they believe they checked.
  final bool heldByUnknown;

  const EquipmentChannel({required this.key, required this.label, this.inUse = false, this.freqKHz, this.mode, this.usedBy, this.heldByUnknown = false});

  @override
  bool operator ==(Object other) =>
      other is EquipmentChannel &&
      other.key == key &&
      other.label == label &&
      other.inUse == inUse &&
      other.freqKHz == freqKHz &&
      other.mode == mode &&
      other.usedBy == usedBy &&
      other.heldByUnknown == heldByUnknown;

  @override
  int get hashCode => Object.hash(key, label, inUse, freqKHz, mode, usedBy, heldByUnknown);

  @override
  String toString() =>
      'EquipmentChannel($key/$label, inUse: $inUse, freq: $freqKHz, '
      'mode: $mode, usedBy: ${usedBy ?? (heldByUnknown ? 'unnamed' : 'nobody')})';
}

/// One antenna port on a switch, as the switch itself describes it.
///
/// Live-only, like [EquipmentChannel]: this is the switch's own inventory,
/// never the operator's. Which of the operator's antenna nodes is on this
/// port is configuration, and lives in the node's config against [key].
@immutable
class SwitchAntenna {
  /// The switch's own identifier for the port — `'1'`..`'8'` on an Antenna
  /// Genius. What a [SwitchPort.selectedAntennaKey] refers to, and what the
  /// operator's config keys its antenna-node link by, so it must be the
  /// equipment's own numbering and never a position in this list.
  final String key;

  /// What the switch calls it — an Antenna Genius' configured `name=`.
  final String name;

  /// False for a port the switch knows about but has nothing wired to.
  ///
  /// An Antenna Genius reports all eight ports whether or not they are set
  /// up, distinguishing them only by an all-zero band mask. Without this the
  /// operator picks their antenna out of a list padded with four entries
  /// called `Antenna_4` through `Antenna_7`.
  final bool configured;

  const SwitchAntenna({required this.key, required this.name, this.configured = true});

  @override
  bool operator ==(Object other) => other is SwitchAntenna && other.key == key && other.name == name && other.configured == configured;

  @override
  int get hashCode => Object.hash(key, name, configured);

  @override
  String toString() => 'SwitchAntenna($key/$name${configured ? '' : ', unconfigured'})';
}

/// One device port on a switch — where a radio plugs in — and what it is
/// currently routed to.
@immutable
class SwitchPort {
  /// The switch's own identifier, `'1'`/`'2'` on an Antenna Genius. See
  /// [SwitchAntenna.key] for why this is never an index.
  final String key;

  /// What the switch calls it. An Antenna Genius numbers its ports and the
  /// panel on the front letters them, so this is `'A'`/`'B'` where [key] is
  /// `'1'`/`'2'` — the operator reads the letters off the box.
  final String label;

  /// Which [SwitchAntenna.key] this port is routed to, or null when the
  /// switch says it is on nothing.
  final String? selectedAntennaKey;

  /// The switch is choosing this port's antenna itself, from band data.
  ///
  /// Worth showing rather than hiding: a selection the operator makes here
  /// is honoured immediately but stands only until the next band change,
  /// and a port that silently reverted would read as the app failing to
  /// send the command.
  final bool auto;

  /// What the switch believes this port's band is, in its own words — an
  /// Antenna Genius' `160m`, `20m`. Null when it reports none.
  final String? band;

  /// The radio feeding this port its band data, by the name that radio gave
  /// itself — a FlexRadio's nickname.
  ///
  /// "Which radio feeds this port", not "which radio is using it": a switch
  /// names the radio a port is CONFIGURED to follow whether or not that
  /// radio is on a band right now.
  ///
  /// This is the switch answering, for free, most of the question a
  /// transceiver's own antenna ports exist to answer. Nothing joins it to an
  /// [EquipmentNode] yet — the operator's name for a radio and the name the
  /// radio gave itself are not the same string, and guessing that they are
  /// would silently mis-attribute a QSO.
  final String? radioName;

  /// What that radio is tuned to, kHz with decimals — the unit every
  /// frequency crosses this boundary in (docs/design/cat.md § Units).
  final double? freqKHz;

  /// The port is keyed. Nothing may switch a relay under RF.
  final bool transmitting;

  /// The switch is refusing to transmit on this port — an interlock with the
  /// other port holding the antenna it wants.
  final bool inhibited;

  const SwitchPort({
    required this.key,
    required this.label,
    this.selectedAntennaKey,
    this.auto = false,
    this.band,
    this.radioName,
    this.freqKHz,
    this.transmitting = false,
    this.inhibited = false,
  });

  @override
  bool operator ==(Object other) =>
      other is SwitchPort &&
      other.key == key &&
      other.label == label &&
      other.selectedAntennaKey == selectedAntennaKey &&
      other.auto == auto &&
      other.band == band &&
      other.radioName == radioName &&
      other.freqKHz == freqKHz &&
      other.transmitting == transmitting &&
      other.inhibited == inhibited;

  @override
  int get hashCode => Object.hash(key, label, selectedAntennaKey, auto, band, radioName, freqKHz, transmitting, inhibited);

  @override
  String toString() =>
      'SwitchPort($key/$label -> ${selectedAntennaKey ?? 'none'}'
      '${auto ? ', auto' : ''}${band != null ? ', $band' : ''}'
      '${radioName != null ? ', $radioName' : ''}${freqKHz != null ? ', $freqKHz kHz' : ''}'
      '${transmitting ? ', TX' : ''}${inhibited ? ', inhibited' : ''})';
}

/// One voice memory as the radio describes it — see
/// [EquipmentSink.reportVoiceMemories].
@immutable
class VoiceMemory {
  /// 1-based, as the radio numbers it.
  final int memory;

  /// Empty when the radio's name for it is only its default.
  final String name;

  /// How long the recording runs, zero for an empty memory.
  final int durationMs;

  const VoiceMemory({required this.memory, this.name = '', this.durationMs = 0});

  @override
  bool operator ==(Object other) => other is VoiceMemory && other.memory == memory && other.name == name && other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(memory, name, durationMs);

  @override
  String toString() => 'VoiceMemory($memory "$name" ${durationMs}ms)';
}

/// A receive passband: its edges in Hz from the tuned frequency, as the radio
/// shows them — `100`…`2800` in USB, `-2800`…`-100` in LSB, around zero in CW.
@immutable
class Passband {
  final int lowHz, highHz;
  const Passband(this.lowHz, this.highHz);

  int get widthHz => highHz - lowHz;

  @override
  bool operator ==(Object other) => other is Passband && other.lowHz == lowHz && other.highHz == highHz;

  @override
  int get hashCode => Object.hash(lowHz, highHz);

  @override
  String toString() => 'Passband($lowHz..$highHz)';
}

/// A transceiver's own antenna ports, as its radio names them, and which it is
/// using. [separate]: the radio picks its receive and transmit antennas
/// independently — a FlexRadio — rather than one port for both.
@immutable
class RadioAntennas {
  final List<String> rxPorts, txPorts;
  final String? rx, tx;
  final bool separate;
  const RadioAntennas({required this.rxPorts, required this.txPorts, this.rx, this.tx, this.separate = false});

  @override
  bool operator ==(Object other) =>
      other is RadioAntennas &&
      listEquals(other.rxPorts, rxPorts) &&
      listEquals(other.txPorts, txPorts) &&
      other.rx == rx &&
      other.tx == tx &&
      other.separate == separate;

  @override
  int get hashCode => Object.hash(Object.hashAll(rxPorts), Object.hashAll(txPorts), rx, tx, separate);
}

/// A transceiver's antenna tuner, as its radio reports it.
enum TunerStatus {
  /// In line, matching.
  inline,

  /// Out of the path.
  bypassed,

  /// Finding a match — on the air.
  tuning,

  /// The last tune found no match.
  failed,
}

/// Where a rotator says its antenna points, in degrees — azimuth from true
/// north as the controller is calibrated, elevation above the horizon.
///
/// Whole degrees, because that is all any controller here reports.
@immutable
class RotatorPosition {
  final int azimuth;

  /// Null for a rotator that turns in azimuth alone, and for an az/el
  /// controller that has not said.
  final int? elevation;

  const RotatorPosition({required this.azimuth, this.elevation});

  @override
  bool operator ==(Object other) => other is RotatorPosition && other.azimuth == azimuth && other.elevation == elevation;

  @override
  int get hashCode => Object.hash(azimuth, elevation);

  @override
  String toString() => 'RotatorPosition($azimuth${elevation == null ? '' : '/$elevation'})';
}

/// How close, in degrees, a rotator's azimuth has to come to its target to
/// count as there. Controllers coast and settle a degree or two short, and
/// report whole degrees; a target held until it is hit exactly could be held
/// forever.
const int rotatorArrivedWithin = 3;

/// How many readings in a row may show a rotator standing still, short of its
/// target, before the target is let go: it was stopped at the controller's
/// own panel, or met a stop of its own short of the node's limits. Counted
/// in readings rather than seconds so a slow poll interval is not taken for
/// a stall, and more than a brake's release delay at the default one.
const int rotatorStalledAfterReadings = 5;

/// Whether [position] is [target], on every axis the target names, to within
/// [rotatorArrivedWithin]. An elevation the controller has not reported is
/// taken as there: nothing will ever say otherwise.
bool rotatorArrived(RotatorPosition position, RotatorPosition target) =>
    rotatorHeadingGap(position.azimuth, target.azimuth) <= rotatorArrivedWithin &&
    (target.elevation == null || position.elevation == null || (position.elevation! - target.elevation!).abs() <= rotatorArrivedWithin);

/// How far apart two azimuths are, the short way round: 0–180. A controller
/// with overlap reports past 360, which is the same heading as 360 less.
int rotatorHeadingGap(int a, int b) {
  final gap = (a - b) % 360;
  return gap > 180 ? 360 - gap : gap;
}

/// Everything the UI needs to know about one node's connection.
@immutable
class EquipmentState {
  final EquipmentStatus status;

  /// Set only when [status] is [EquipmentStatus.error] — the reason to show
  /// the user. app-polo's settings screen could only say Connected or Not
  /// Connected, with no way to tell why a connection had failed.
  final String? error;

  /// The connect failure's own words, kept alongside [error] when that field
  /// has been translated into something friendlier for the row. Only the
  /// equipment report feature reads this — a developer triaging a report
  /// needs the address/port/errno a translated message drops, in the
  /// language the report expects. Null when [error] IS the raw text (no
  /// translation happened), never a duplicate of it.
  final String? errorDetail;

  final VfoReading vfo;

  /// The transceiver's RF output power, in watts, when the driver's protocol
  /// can report it — null on a driver that has never asked, not on a rig
  /// reporting zero.
  final num? power;

  /// What the radio is doing — keyed or not, and its meters while it is.
  ///
  /// Its own value rather than more fields on this class because the pieces
  /// travel together and expire together: a panel asks "is this reading
  /// still worth showing?" of the set, not of each meter's own timestamp
  /// field. Empty on a driver that reports no telemetry at all.
  final RadioTelemetry telemetry;

  /// The transceiver's keyer speed in WPM, when its driver can report one —
  /// see [EquipmentSink.reportKeyerSpeed]. Null on a driver that never asks.
  final int? keyerSpeed;

  /// The radio's antenna tuner, when its driver reads one — see [TunerSink].
  /// Null for a radio that has none, or a driver that never asks.
  final TunerStatus? tuner;

  /// The radio's receive passband, when its driver reads one — see
  /// [PassbandSink]. Null for a driver that cannot.
  final Passband? passband;

  /// The radio's own antenna ports, when its driver reads them — see
  /// [RadioAntennaSink]. Not an antenna switch's: those are [switchAntennas].
  final RadioAntennas? antennas;

  /// Connected, but the radio has stopped saying anything.
  ///
  /// NOT the same as disconnected, and that distinction is the point: a
  /// session can be alive at the protocol level — keepalives flowing, the
  /// socket healthy — while the stream that carries actual readings is
  /// dead. Observed on an IC-705 reconnect: full handshake, stream request
  /// accepted, and then no CI-V at all, with the row showing a confident
  /// green and a frequency from several minutes earlier.
  ///
  /// Liveness that counts bytes cannot see this — and would be fooled the
  /// other way too, by a bus echoing our own polls. So what clears it is a
  /// reading, or the one thing a driver may vouch for instead: an
  /// acknowledgement that travelled the same path a reading takes
  /// ([EquipmentSink.reportAlive], with its condition).
  final bool stale;

  /// What the driver worked out about this session, for developer mode only —
  /// see [EquipmentSink.reportDiagnostic]. In-memory like everything else
  /// here, and cleared with the connection it belonged to.
  final String? diagnostic;

  /// Connected, and the equipment is answering, but what the operator
  /// configured cannot be honoured — a Flex node pointed at a slice the
  /// radio is not running.
  ///
  /// Deliberately NOT [EquipmentStatus.error]: the link is up, and the
  /// connect-time error path feeds a retry ladder. Reconnecting cannot fix a
  /// wrong slice, so routing this through [error] would hammer the radio
  /// forever over a setting only the operator can change. The row shows it
  /// with the same weight as an error because to the operator it is one.
  final String? problem;

  /// Every channel the equipment currently offers, when it has more than one
  /// — see [EquipmentChannel]. Empty for equipment with a single channel,
  /// and for one that has not said yet.
  final List<EquipmentChannel> channels;

  /// The antenna ports an antenna switch offers — see [SwitchAntenna]. Empty
  /// for everything that is not a switch, and for a switch that has not said
  /// yet.
  final List<SwitchAntenna> switchAntennas;

  /// The device ports an antenna switch offers, and what each is routed to —
  /// see [SwitchPort]. Always reported together with [switchAntennas], since
  /// a port names its antenna by key.
  final List<SwitchPort> switchPorts;

  /// Where a rotator's antenna points — see [RotatorSink]. Null for
  /// everything that is not a rotator, and for one that has not said yet.
  final RotatorPosition? rotator;

  /// Where a rotator was last told to turn to, in true degrees, until it gets
  /// there ([rotatorArrived]), is stopped, or stands still short of it for
  /// [rotatorStalledAfterReadings]. Null when it was not told, so a heading
  /// changed at the controller's own knob is not drawn as a turn the app
  /// asked for.
  final RotatorPosition? rotatorTarget;

  /// What the radio calls its voice memories and how long each runs, for a
  /// radio that holds them itself — see [EquipmentSink.reportVoiceMemories].
  /// Null for every other radio, and for one that has not said yet; empty
  /// for one that said it holds none (a FlexRadio without the DVK licence).
  final List<VoiceMemory>? voiceMemories;

  /// What the radio's scope is set to, while a display has it running —
  /// see [SpectrumSession]. The sweeps themselves are a stream, never state.
  final SpectrumSettings? spectrum;

  /// See [SpectrumSink.reportSpectrumProblem].
  final String? spectrumProblem;

  const EquipmentState({
    this.status = EquipmentStatus.disconnected,
    this.error,
    this.errorDetail,
    this.vfo = const VfoReading(),
    this.power,
    this.telemetry = const RadioTelemetry(),
    this.keyerSpeed,
    this.tuner,
    this.passband,
    this.antennas,
    this.stale = false,
    this.diagnostic,
    this.problem,
    this.channels = const [],
    this.switchAntennas = const [],
    this.switchPorts = const [],
    this.rotator,
    this.rotatorTarget,
    this.voiceMemories,
    this.spectrum,
    this.spectrumProblem,
  });

  EquipmentState copyWith({
    EquipmentStatus? status,
    String? error,
    String? errorDetail,
    VfoReading? vfo,
    num? power,
    RadioTelemetry? telemetry,
    int? keyerSpeed,
    TunerStatus? tuner,
    bool clearTuner = false,
    Passband? passband,
    bool clearPassband = false,
    RadioAntennas? antennas,
    bool clearAntennas = false,
    bool? stale,
    String? diagnostic,
    bool clearDiagnostic = false,
    String? problem,
    bool clearProblem = false,
    List<EquipmentChannel>? channels,
    List<SwitchAntenna>? switchAntennas,
    List<SwitchPort>? switchPorts,
    RotatorPosition? rotator,
    RotatorPosition? rotatorTarget,
    bool clearRotatorTarget = false,
    List<VoiceMemory>? voiceMemories,
    SpectrumSettings? spectrum,
    bool clearSpectrum = false,
    String? spectrumProblem,
    bool clearSpectrumProblem = false,
  }) => EquipmentState(
    status: status ?? this.status,
    // An explicit null clears it: any transition out of `error` should
    // drop the stale message rather than carry it into the next state.
    error: status == null || status == EquipmentStatus.error ? (error ?? this.error) : null,
    errorDetail: status == null || status == EquipmentStatus.error ? (errorDetail ?? this.errorDetail) : null,
    vfo: vfo ?? this.vfo,
    power: power ?? this.power,
    telemetry: telemetry ?? this.telemetry,
    keyerSpeed: keyerSpeed ?? this.keyerSpeed,
    tuner: clearTuner ? null : (tuner ?? this.tuner),
    passband: clearPassband ? null : (passband ?? this.passband),
    antennas: clearAntennas ? null : (antennas ?? this.antennas),
    stale: stale ?? this.stale,
    // Needs its own flag rather than a null argument: a driver saying
    // "nothing to report any more" and a caller not mentioning it at all
    // are different, and `??` cannot tell them apart.
    diagnostic: clearDiagnostic ? null : (diagnostic ?? this.diagnostic),
    // Same flag-not-null reasoning as [diagnostic]: "the slice is back"
    // has to be sayable.
    problem: clearProblem ? null : (problem ?? this.problem),
    channels: channels ?? this.channels,
    switchAntennas: switchAntennas ?? this.switchAntennas,
    switchPorts: switchPorts ?? this.switchPorts,
    rotator: rotator ?? this.rotator,
    rotatorTarget: clearRotatorTarget ? null : (rotatorTarget ?? this.rotatorTarget),
    voiceMemories: voiceMemories ?? this.voiceMemories,
    spectrum: clearSpectrum ? null : (spectrum ?? this.spectrum),
    spectrumProblem: clearSpectrumProblem ? null : (spectrumProblem ?? this.spectrumProblem),
  );
}
