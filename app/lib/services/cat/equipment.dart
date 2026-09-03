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

  const EquipmentNode({
    required this.uuid,
    required this.typeKey,
    this.name = '',
    this.config = const {},
  });

  /// [typeKey] changes when the operator picks a different transport for the
  /// same radio — the node is then bound to a different driver and transport,
  /// which is why [CatService.updateNode] drops any live connection rather
  /// than leaving a session built by the old pairing attached to it.
  EquipmentNode copyWith({String? typeKey, String? name, Map<String, dynamic>? config}) => EquipmentNode(
        uuid: uuid,
        typeKey: typeKey ?? this.typeKey,
        name: name ?? this.name,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'typeKey': typeKey,
        if (name.isNotEmpty) 'name': name,
        if (config.isNotEmpty) 'config': config,
      };

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
  bool operator ==(Object other) =>
      other is VfoReading && other.freqKHz == freqKHz && other.mode == mode;

  @override
  int get hashCode => Object.hash(freqKHz, mode);

  @override
  String toString() => 'VfoReading(freqKHz: $freqKHz, mode: $mode)';
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

  const EquipmentChannel({
    required this.key,
    required this.label,
    this.inUse = false,
    this.freqKHz,
    this.mode,
    this.usedBy,
    this.heldByUnknown = false,
  });

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
  String toString() => 'EquipmentChannel($key/$label, inUse: $inUse, freq: $freqKHz, '
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
  bool operator ==(Object other) =>
      other is SwitchAntenna && other.key == key && other.name == name && other.configured == configured;

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
  int get hashCode =>
      Object.hash(key, label, selectedAntennaKey, auto, band, radioName, freqKHz, transmitting, inhibited);

  @override
  String toString() => 'SwitchPort($key/$label -> ${selectedAntennaKey ?? 'none'}'
      '${auto ? ', auto' : ''}${band != null ? ', $band' : ''}'
      '${radioName != null ? ', $radioName' : ''}${freqKHz != null ? ', $freqKHz kHz' : ''}'
      '${transmitting ? ', TX' : ''}${inhibited ? ', inhibited' : ''})';
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

  /// The transceiver's keyer speed in WPM, when its driver can report one —
  /// see [EquipmentSink.reportKeyerSpeed]. Null on a driver that never asks.
  final int? keyerSpeed;

  /// Connected, but the radio has stopped saying anything.
  ///
  /// NOT the same as disconnected, and that distinction is the point: a
  /// session can be alive at the protocol level — keepalives flowing, the
  /// socket healthy — while the stream that carries actual readings is
  /// dead. Observed on an IC-705 reconnect: full handshake, stream request
  /// accepted, and then no CI-V at all, with the row showing a confident
  /// green and a frequency from several minutes earlier.
  ///
  /// Liveness that counts datagrams cannot see this. Only the readings can.
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

  const EquipmentState({
    this.status = EquipmentStatus.disconnected,
    this.error,
    this.errorDetail,
    this.vfo = const VfoReading(),
    this.power,
    this.keyerSpeed,
    this.stale = false,
    this.diagnostic,
    this.problem,
    this.channels = const [],
    this.switchAntennas = const [],
    this.switchPorts = const [],
  });

  EquipmentState copyWith({
    EquipmentStatus? status,
    String? error,
    String? errorDetail,
    VfoReading? vfo,
    num? power,
    int? keyerSpeed,
    bool? stale,
    String? diagnostic,
    bool clearDiagnostic = false,
    String? problem,
    bool clearProblem = false,
    List<EquipmentChannel>? channels,
    List<SwitchAntenna>? switchAntennas,
    List<SwitchPort>? switchPorts,
  }) =>
      EquipmentState(
        status: status ?? this.status,
        // An explicit null clears it: any transition out of `error` should
        // drop the stale message rather than carry it into the next state.
        error: status == null || status == EquipmentStatus.error ? (error ?? this.error) : null,
        errorDetail: status == null || status == EquipmentStatus.error ? (errorDetail ?? this.errorDetail) : null,
        vfo: vfo ?? this.vfo,
        power: power ?? this.power,
        keyerSpeed: keyerSpeed ?? this.keyerSpeed,
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
      );
}
