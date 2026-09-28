// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pin an operation's location wears, wherever it is shown: the setup
// sheet's location button, and the operation's own marker on the Map tab.
// One answer, so the two can't disagree about where a location came from.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// The icon and fill for an operation that has a location: a GPS fix is a
/// map marker on green, a location typed or picked by hand a pin on slate.
///
/// [deviceGrid] is the device's own 6-character fix, and matters only for an
/// operation stored before `gridSource` existed: those carry a 6-character
/// grid, so matching them against a fix's own displayed locator could never
/// be reliably equal, and every legacy GPS-set operation would quietly lose
/// its green pin.
({IconData icon, Color color}) operationLocationPin(Operation operation, {String? deviceGrid}) {
  final location = operation.location;
  final gridSource =
      asQsonString(operation.data['gridSource']) ??
      ((location != null && deviceGrid != null && locationToGrid6(location.latitude, location.longitude) == deviceGrid) ? 'gps' : 'manual');
  return gridSource == 'gps' ? (icon: MdiIcons.mapMarker, color: const Color(0xFF1B5E20)) : (icon: MdiIcons.pin, color: const Color(0xFF455A64));
}
