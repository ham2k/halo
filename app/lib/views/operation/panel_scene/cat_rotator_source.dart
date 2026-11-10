// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;

import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import 'scene_rotator.dart';

/// A scene's rotator maps, fed by the station's CAT connections.
@immutable
class CatRotatorSource implements SceneRotatorSource {
  final CatService cat;

  /// Whether the panel may command the station — `requiresRadioWrite` — and
  /// so have its map turn a rotator on a click or a drag, and connect it.
  @override
  final bool canTurn;

  @override
  final GridLocation? home;

  @override
  final GridLocation? call;

  const CatRotatorSource(this.cat, {this.canTurn = false, this.home, this.call});

  @override
  String? resolve(String? rotator) {
    if (rotator == null) {
      for (final node in cat.nodes) {
        if (cat.typeFor(node)?.category == kCategoryRotator) return node.uuid;
      }
      return null;
    }
    final node = cat.nodeFor(rotator);
    return node != null && cat.typeFor(node)?.category == kCategoryRotator ? rotator : null;
  }

  @override
  SceneRotatorReading read(String uuid) {
    final node = cat.nodeFor(uuid);
    final state = cat.stateFor(uuid);
    // Connected and fresh: only then is a heading given and a turn sent.
    final live = state.status == EquipmentStatus.connected && !state.stale;
    return SceneRotatorReading(
      name: node == null ? '' : cat.displayNameFor(node),
      status: state.status,
      live: live,
      stale: state.status == EquipmentStatus.connected && state.stale,
      azimuth: live ? state.rotator?.azimuth : null,
      elevation: live ? state.rotator?.elevation : null,
      target: live ? state.rotatorTarget?.azimuth : null,
      beamWidth: state.rotator?.beamWidth,
      // Why no heading comes while connected; why the connection failed otherwise.
      problem: state.status == EquipmentStatus.connected ? state.problem : state.error,
    );
  }

  @override
  Listenable get changes => cat;

  @override
  bool turn(String uuid, double azimuth) => canTurn && cat.rotateTo(uuid, azimuth: azimuth % 360) != null;

  @override
  void stop(String uuid) {
    if (canTurn) cat.stopRotator(uuid);
  }

  @override
  void connect(String uuid, {required bool on}) {
    if (!canTurn) return;
    unawaited(on ? cat.connect(uuid) : cat.disconnect(uuid));
  }

  @override
  bool operator ==(Object other) =>
      other is CatRotatorSource && identical(other.cat, cat) && other.canTurn == canTurn && other.home == home && other.call == call;

  @override
  int get hashCode => Object.hash(identityHashCode(cat), canTurn, home, call);
}
