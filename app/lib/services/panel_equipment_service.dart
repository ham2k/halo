// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's antenna switches and rotators as extensions see them
// (docs/extensions/radio.md § Antenna switches and rotators): what each one
// is and where it stands, and the commands that move one, under the radio's
// grants — reading needs `requiresRadioRead`, a command `requiresRadioWrite`
// (radio_host_calls.dart). Every command is checked here before it goes out,
// because the service calls behind it (CatService.selectAntenna, rotateTo,
// stopRotator) change nothing on a node that cannot take one and say so to
// no one.

import 'dart:async';

import 'package:halo_core/halo_core.dart' show realNowMillis;

import 'cat/cat_service.dart';
import 'cat/equipment.dart';

class PanelEquipmentService {
  PanelEquipmentService(this.cat);

  final CatService cat;

  /// The least time between two extension commands to one device: a dragged
  /// control or an extension in a loop would otherwise flood its link. A
  /// command inside it waits its turn rather than being dropped, or the last
  /// step of a drag — where the operator let go — would be the one lost. The
  /// app's own controls are not paced here.
  static const commandSpacing = Duration(milliseconds: 250);

  /// `PanelRadioService.set`'s rules, so a device answers as a radio does:
  /// how many of one extension's commands may wait at once, the one being
  /// sent included — a further one is answered `busy` and sends nothing, so
  /// a dragged control is not walked through where it has been — and how
  /// long after it was asked for one may still go out: past that, `expired`.
  static const maxWaiting = 4;
  static const maxWait = Duration(seconds: 2);

  final _lastCommandAt = <String, int>{};
  final _tails = <String, Future<void>>{};
  final _waiting = <String, int>{};

  /// Counts each device's stops: a turn queued before a stop must never go
  /// out after it.
  final _stops = <String, int>{};

  static const _kinds = {kCategoryAntennaSwitch, kCategoryRotator};

  /// Every antenna switch and rotator the operator has set up, connected or
  /// not.
  List<Map<String, dynamic>> list() => [
    for (final node in cat.nodes)
      if (_kinds.contains(cat.typeFor(node)?.category)) _read(node),
  ];

  Map<String, dynamic> _read(EquipmentNode node) {
    final state = cat.stateFor(node.uuid);
    final kind = cat.typeFor(node)!.category;
    return {
      'id': node.uuid,
      'kind': kind,
      'name': cat.displayNameFor(node),
      'connected': state.status == EquipmentStatus.connected,
      if (kind == kCategoryAntennaSwitch) ...{
        'antennas': [
          for (final antenna in state.switchAntennas)
            if (antenna.configured) {'key': antenna.key, 'name': antenna.name},
        ],
        'ports': [
          for (final port in state.switchPorts)
            {
              'key': port.key,
              'label': port.label,
              'antenna': ?port.selectedAntennaKey,
              'auto': port.auto,
              'band': ?port.band,
              'transmitting': port.transmitting,
            },
        ],
      },
      if (kind == kCategoryRotator) ...{
        'azimuth': ?state.rotator?.azimuth,
        'elevation': ?state.rotator?.elevation,
        'beamWidth': ?state.rotator?.beamWidth,
        if (state.rotatorTarget case final target?) 'target': {'azimuth': target.azimuth, 'elevation': ?target.elevation},
      },
    };
  }

  /// The node under `args['id']` when it is a [kind] that can take a command
  /// now, else the refusal to answer with. Connected means a live session,
  /// not the status alone: a reconnect drops the session before the status
  /// moves, and a command in between would be answered as sent.
  ({EquipmentNode? node, Map<String, dynamic>? refused}) _commandable(Map<String, dynamic> args, String kind) {
    final id = args['id'];
    final node = id is String ? cat.nodeFor(id) : null;
    if (node == null || cat.typeFor(node)?.category != kind) return (node: null, refused: {'accepted': false, 'reason': 'invalid', 'state': null});
    if (cat.connectedSession(node.uuid) == null) return (node: null, refused: _refused('disconnected', node));
    return (node: node, refused: null);
  }

  /// Runs [send] in the device's queue, [commandSpacing] after its last
  /// command went out. Refused at once what could not go now either; [send]
  /// judges the rest again as it goes, the device having moved meanwhile.
  Future<Map<String, dynamic>> _queued(Map<String, dynamic> args, String kind, Map<String, dynamic> Function() send) async {
    final (:node, :refused) = _commandable(args, kind);
    if (node == null) return refused!;
    final id = node.uuid;
    final caller = args['extensionKey'] as String?;
    if (caller != null) {
      final waiting = _waiting[caller] ?? 0;
      if (waiting >= maxWaiting) return _refused('busy', node);
      _waiting[caller] = waiting + 1;
    }
    final askedAt = realNowMillis(), stops = _stops[id] ?? 0;
    final done = (_tails[id] ?? Future<void>.value())
        .then((_) async {
          final delay = commandSpacing.inMilliseconds - (realNowMillis() - (_lastCommandAt[id] ?? 0));
          if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
          if ((_stops[id] ?? 0) != stops || realNowMillis() - askedAt > maxWait.inMilliseconds) return _refused('expired', node);
          return send();
        })
        .whenComplete(() {
          if (caller == null) return;
          final left = _waiting[caller]! - 1;
          if (left > 0) {
            _waiting[caller] = left;
          } else {
            _waiting.remove(caller);
          }
        });
    _tails[id] = done.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return done;
  }

  Map<String, dynamic> _refused(String reason, EquipmentNode node) => {'accepted': false, 'reason': reason, 'state': _read(node)};

  /// Answers a command that went out, and starts the device's spacing: only
  /// a command sent counts toward it.
  Map<String, dynamic> _sent(EquipmentNode node) {
    _lastCommandAt[node.uuid] = realNowMillis();
    return {'accepted': true, 'state': _read(node)};
  }

  /// Routes a switch's port to one of its antennas. Refused as `transmitting`
  /// while the port, or a radio the switch may be feeding, is keyed: a relay
  /// thrown under RF is a relay destroyed.
  Future<Map<String, dynamic>> setAntenna(Map<String, dynamic> args) => _queued(args, kCategoryAntennaSwitch, () {
    final (:node, :refused) = _commandable(args, kCategoryAntennaSwitch);
    if (node == null) return refused!;
    final state = cat.stateFor(node.uuid);
    // A switch says what it has once its startup exchanges are done, ports
    // and antennas each in their own; until then every key would be
    // `invalid`, which tells an extension its key is wrong for good.
    if (state.switchPorts.isEmpty || state.switchAntennas.isEmpty) return _refused('disconnected', node);
    final port = state.switchPorts.where((p) => p.key == args['port']).firstOrNull;
    final antenna = state.switchAntennas.where((a) => a.key == args['antenna'] && a.configured).firstOrNull;
    if (port == null || antenna == null) return _refused('invalid', node);
    if (port.transmitting) return _refused('transmitting', node);
    if (cat.selectAntenna(node.uuid, port.key, antenna.key) case final reason?) return _refused(reason, node);
    return _sent(node);
  });

  /// Turns a rotator to `azimuth`, and `elevation` on one that has it. The
  /// node's limits may turn it somewhere else; the answer's `target` is where.
  ///
  /// An azimuth is a bearing, taken modulo 360: the drivers do not agree on
  /// one outside 0–360 (GS-232 and rotctld wrap -10 to 350, PstRotator
  /// clamps it to 0). An elevation outside 0–180 is no elevation at all, and
  /// PstRotator would send it as given.
  Future<Map<String, dynamic>> setRotator(Map<String, dynamic> args) async {
    final azimuth = args['azimuth'], elevation = args['elevation'];
    if (azimuth is! num || !azimuth.isFinite || (elevation != null && (elevation is! num || !elevation.isFinite || elevation < 0 || elevation > 180))) {
      return {'accepted': false, 'reason': 'invalid', 'state': null};
    }
    return _queued(args, kCategoryRotator, () {
      final (:node, :refused) = _commandable(args, kCategoryRotator);
      if (node == null) return refused!;
      if (cat.rotationHeldByTransmit(node.uuid)) return _refused('transmitting', node);
      // With a live session and no hold checked just above, nothing sent is
      // a driver that threw.
      if (cat.rotateTo(node.uuid, azimuth: azimuth % 360, elevation: elevation as num?) == null) return _refused('failed', node);
      return _sent(node);
    });
  }

  /// Connects or disconnects a switch or a rotator, as the station's own
  /// plug does. Never queued: it changes the link the queue sends over, and
  /// the device's status, not this answer, says when it is done.
  Map<String, dynamic> setConnection(Map<String, dynamic> args) {
    final id = args['id'];
    final node = id is String ? cat.nodeFor(id) : null;
    if (node == null || !_kinds.contains(cat.typeFor(node)?.category) || args['connected'] is! bool) {
      return {'accepted': false, 'reason': 'invalid', 'state': node == null ? null : _read(node)};
    }
    unawaited(args['connected'] == true ? cat.connect(node.uuid) : cat.disconnect(node.uuid));
    return {'accepted': true, 'state': _read(node)};
  }

  /// Stops a rotator wherever it has got to, and takes every turn still
  /// queued for it out with it: they answer `expired`.
  Map<String, dynamic> stopRotator(Map<String, dynamic> args) {
    // Never queued: a stop is the one command that must always go now.
    final (:node, :refused) = _commandable(args, kCategoryRotator);
    if (node == null) return refused!;
    _stops[node.uuid] = (_stops[node.uuid] ?? 0) + 1;
    if (!cat.stopRotator(node.uuid)) return _refused('failed', node);
    return {'accepted': true, 'state': _read(node)};
  }
}

/// What the `equipment` trigger compares: each device's connection, every
/// switch's antennas and each port's routing, automatic selection and band,
/// and every rotator's target. Not a port's `transmitting`, which flips with
/// every over, nor a rotator's heading, which a turning rotator reports
/// several times a second: a turn ordered and a turn finished each move it,
/// the readings between do not.
List<Object?> equipmentSignature(CatService cat) => [
  for (final node in cat.nodes)
    if (cat.typeFor(node)?.category case kCategoryAntennaSwitch || kCategoryRotator)
      if (cat.stateFor(node.uuid) case final state) ...[
        node.uuid,
        state.status,
        for (final antenna in state.switchAntennas) ...[antenna.key, antenna.name, antenna.configured],
        for (final port in state.switchPorts) ...[port.key, port.selectedAntennaKey, port.auto, port.band],
        state.rotatorTarget,
      ],
];
