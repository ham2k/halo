// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Equipment that announces itself on the network.
//
// Discovery is a capability of an equipment TYPE, not of a transport: the
// announcement is protocol knowledge (a FlexRadio's VITA-49 broadcast means
// nothing to a rigctld bridge on the same transport), and putting radio
// identification inside a transport is the one architecture inversion
// app-polo's own review called out and undid.

import 'package:flutter/foundation.dart';

@immutable
class DiscoveredEquipment {
  /// Which [EquipmentType] found it, and therefore what will handle it.
  final String typeKey;

  /// Stable across repeated announcements — a serial number where the
  /// protocol offers one, otherwise the address. Radios re-announce every
  /// few seconds, so this is what keeps the list from growing forever.
  final String id;

  /// What to show: the radio's own nickname, falling back to its model.
  final String name;

  /// Model, serial, firmware — whatever the announcement carried that's
  /// worth showing under the name.
  final String? detail;

  /// Ready to hand to [EquipmentType.targetFor]: a discovered device is
  /// added with no typing at all.
  final Map<String, dynamic> config;

  const DiscoveredEquipment({required this.typeKey, required this.id, required this.name, required this.config, this.detail});
}

/// Implemented by an [EquipmentType] whose equipment announces itself.
///
/// The stream stays open until its subscription is cancelled; devices are
/// emitted every time they announce, not just the first time, so a radio
/// that changes address or comes back after a reboot updates rather than
/// leaving a stale entry behind.
abstract class EquipmentDiscoverer {
  Stream<DiscoveredEquipment> discover();
}
