// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Points the Everyware map switches that follow the station being worked
// (docs/design/cat.md § Green Heron Everyware). The call field's lookup is
// the operation view's, not CatService's, so the view hands it over.

import 'package:halo_core/halo_core.dart' show GridLocation, bearingOnEarthDeg;
import 'package:halo_widgets/halo_widgets.dart' show CallInfoData;

import '../../services/cat/cat_service.dart';
import '../dock_host.dart' show callInfoLocation;

/// Turns every following map switch toward the station [info] places, as
/// seen from [station]. Nothing without both ends: a direction measured
/// from nowhere, or toward nowhere, is not one to switch an antenna for.
void steerEverywareTowardCall(CatService cat, GridLocation? station, CallInfoData? info) {
  final dx = callInfoLocation(info);
  if (station == null || dx == null) return;
  cat.pointEverywareSwitchesToward(bearingOnEarthDeg(station, dx).round() % 360);
}
