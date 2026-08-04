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

/// Everything the UI needs to know about one node's connection.
@immutable
class EquipmentState {
  final EquipmentStatus status;

  /// Set only when [status] is [EquipmentStatus.error] — the reason to show
  /// the user. app-polo's settings screen could only say Connected or Not
  /// Connected, with no way to tell why a connection had failed.
  final String? error;

  final VfoReading vfo;

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

  const EquipmentState({
    this.status = EquipmentStatus.disconnected,
    this.error,
    this.vfo = const VfoReading(),
    this.stale = false,
  });

  EquipmentState copyWith({EquipmentStatus? status, String? error, VfoReading? vfo, bool? stale}) =>
      EquipmentState(
        status: status ?? this.status,
        // An explicit null clears it: any transition out of `error` should
        // drop the stale message rather than carry it into the next state.
        error: status == null || status == EquipmentStatus.error ? (error ?? this.error) : null,
        vfo: vfo ?? this.vfo,
        stale: stale ?? this.stale,
      );
}
