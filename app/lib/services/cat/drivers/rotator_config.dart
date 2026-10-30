// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What every rotator collects the same way, whatever its protocol: how far
// the controller's own degrees are from true ones, and how far it may be
// told to turn. Shared, as poll_config.dart is, so the wording and the rules
// are the same on every rotator in the catalogue.
//
// Everything above the session speaks TRUE headings — the editor, the map,
// the target CatService holds. The session alone converts, both ways, with
// [RotatorCalibration]: a reading comes up with the offset added, and a turn
// goes down with it taken off and fitted inside the limits.

import 'package:halo_i18n/halo_i18n.dart';

import '../equipment.dart';

/// The config key for which axes the rotator turns — [rotatorAxesAzimuth]
/// or [rotatorAxesAzimuthElevation]. Absent means azimuth alone.
const rotatorAxesConfigKey = 'rotatorAxes';

const rotatorAxesAzimuth = 'az';
const rotatorAxesAzimuthElevation = 'azel';

/// Whether a node configured like [config] reports and takes an elevation.
bool rotatorHasElevation(Map<String, dynamic> config) => config[rotatorAxesConfigKey] == rotatorAxesAzimuthElevation;

/// The azimuth-only or az/el choice, as every rotator asks it.
Map<String, dynamic> rotatorAxesConfigElement() {
  final st = t.settings.station;
  return {
    'type': 'field',
    'fieldType': 'select',
    'key': rotatorAxesConfigKey,
    'label': st.rotatorAxes,
    'description': st.rotatorAxesDescription,
    'options': [
      {'value': rotatorAxesAzimuth, 'label': st.rotatorAxesAzimuth},
      {'value': rotatorAxesAzimuthElevation, 'label': st.rotatorAxesAzimuthElevation},
    ],
  };
}

/// Blank, or one of the two axes choices.
String? validateRotatorAxes(dynamic value) {
  if (value == null || value == '') return null;
  return (value == rotatorAxesAzimuth || value == rotatorAxesAzimuthElevation) ? null : t.settings.station.rotatorAxesRequired;
}

const rotatorAzimuthOffsetConfigKey = 'azimuthOffset';
const rotatorElevationOffsetConfigKey = 'elevationOffset';
const rotatorAzimuthMinConfigKey = 'azimuthMin';
const rotatorAzimuthMaxConfigKey = 'azimuthMax';
const rotatorElevationMinConfigKey = 'elevationMin';
const rotatorElevationMaxConfigKey = 'elevationMax';

/// What a blank limit means: a full turn, and horizon to zenith.
const _azimuthMinDefault = 0;
const _azimuthMaxDefault = 360;
const _elevationMinDefault = 0;
const _elevationMaxDefault = 90;

/// The widest limits offered: 450° for a rotator with overlap, 180° for an
/// elevation rotator that flips over — the most a GS-232 takes.
const _azimuthCeiling = 450;
const rotatorElevationCeiling = 180;

const _elevationOnly = {'field': rotatorAxesConfigKey, 'equals': rotatorAxesAzimuthElevation};

/// The offsets, then — with [limits] — the limits under Advanced. The
/// elevation fields carry their own `visibleWhen`, so they show only for an
/// az/el rotator. Without [limits] for a protocol that reports its own.
List<Map<String, dynamic>> rotatorConfigElements({bool limits = true}) {
  final st = t.settings.station;
  Map<String, dynamic> degrees(String key, String label, {String? description, int? placeholder, bool advanced = false, bool elevation = false}) => {
    'type': 'field',
    'fieldType': 'number',
    'key': key,
    'label': label,
    'description': ?description,
    if (placeholder != null) 'placeholder': '$placeholder',
    if (advanced) 'advanced': true,
    if (elevation) 'visibleWhen': _elevationOnly,
  };
  return [
    degrees(rotatorAzimuthOffsetConfigKey, st.rotatorAzimuthOffset, description: st.rotatorAzimuthOffsetDescription, placeholder: 0),
    degrees(rotatorElevationOffsetConfigKey, st.rotatorElevationOffset, placeholder: 0, elevation: true),
    if (limits) ...[
      degrees(rotatorAzimuthMinConfigKey, st.rotatorAzimuthMin, placeholder: _azimuthMinDefault, advanced: true),
      degrees(rotatorAzimuthMaxConfigKey, st.rotatorAzimuthMax, description: st.rotatorAzimuthMaxDescription, placeholder: _azimuthMaxDefault, advanced: true),
      degrees(rotatorElevationMinConfigKey, st.rotatorElevationMin, placeholder: _elevationMinDefault, advanced: true, elevation: true),
      degrees(
        rotatorElevationMaxConfigKey,
        st.rotatorElevationMax,
        description: st.rotatorElevationMaxDescription,
        placeholder: _elevationMaxDefault,
        advanced: true,
        elevation: true,
      ),
    ],
  ];
}

/// Blank, or whole degrees in range — and a limit below its partner. Null
/// for a key that is not one of these.
String? validateRotatorField(String key, dynamic value, Map<String, dynamic> config) {
  final st = t.settings.station;
  final (int min, int max)? range = switch (key) {
    rotatorAzimuthOffsetConfigKey => (-180, 180),
    rotatorElevationOffsetConfigKey => (-90, 90),
    rotatorAzimuthMinConfigKey || rotatorAzimuthMaxConfigKey => (0, _azimuthCeiling),
    rotatorElevationMinConfigKey || rotatorElevationMaxConfigKey => (0, rotatorElevationCeiling),
    _ => null,
  };
  if (range == null) return null;
  if (value == null || (value is String && value.trim().isEmpty)) return null;
  final n = _degrees(value);
  if (n == null || n < range.$1 || n > range.$2) return st.rotatorDegreesInvalid(min: range.$1, max: range.$2);
  final calibration = RotatorCalibration.from({...config, key: n});
  if (calibration.azimuthMin >= calibration.azimuthMax || calibration.elevationMin >= calibration.elevationMax) return st.rotatorLimitsInvalid;
  return null;
}

/// Whole degrees from a stored value, or null for blank or not a number.
int? _degrees(Object? value) {
  final n = value is num ? value : num.tryParse('${value ?? ''}'.trim());
  if (n == null || !n.isFinite || n != n.roundToDouble()) return null;
  return n.toInt();
}

/// A node's offsets and limits, blanks read as the defaults.
class RotatorCalibration {
  final int azimuthOffset;
  final int elevationOffset;

  /// In the CONTROLLER's degrees: they are what its end stops are in.
  final int azimuthMin;
  final int azimuthMax;
  final int elevationMin;
  final int elevationMax;

  const RotatorCalibration({
    this.azimuthOffset = 0,
    this.elevationOffset = 0,
    this.azimuthMin = _azimuthMinDefault,
    this.azimuthMax = _azimuthMaxDefault,
    this.elevationMin = _elevationMinDefault,
    this.elevationMax = _elevationMaxDefault,
  });

  factory RotatorCalibration.from(Map<String, dynamic> config) => RotatorCalibration(
    azimuthOffset: _degrees(config[rotatorAzimuthOffsetConfigKey]) ?? 0,
    elevationOffset: _degrees(config[rotatorElevationOffsetConfigKey]) ?? 0,
    azimuthMin: _degrees(config[rotatorAzimuthMinConfigKey]) ?? _azimuthMinDefault,
    azimuthMax: _degrees(config[rotatorAzimuthMaxConfigKey]) ?? _azimuthMaxDefault,
    elevationMin: _degrees(config[rotatorElevationMinConfigKey]) ?? _elevationMinDefault,
    elevationMax: _degrees(config[rotatorElevationMaxConfigKey]) ?? _elevationMaxDefault,
  );

  /// These offsets inside another set of limits — the ones a protocol that
  /// knows its controller's travel reports, in place of the node's own.
  RotatorCalibration withLimits({required int azimuthMin, required int azimuthMax, required int elevationMin, required int elevationMax}) => RotatorCalibration(
    azimuthOffset: azimuthOffset,
    elevationOffset: elevationOffset,
    azimuthMin: azimuthMin,
    azimuthMax: azimuthMax,
    elevationMin: elevationMin,
    elevationMax: elevationMax,
  );

  /// What the controller reported, as a true heading.
  RotatorPosition toTrue(RotatorPosition reported) =>
      RotatorPosition(azimuth: (reported.azimuth + azimuthOffset) % 360, elevation: reported.elevation == null ? null : reported.elevation! + elevationOffset);

  /// The controller azimuth that points at true [azimuth], within the
  /// limits. With overlap there can be two — 30 and 390 — and the one
  /// nearer [from] (the controller's last reading) is the shorter turn.
  /// With none, the limit nearer the heading: as close as the mast goes.
  /// A range that starts below 0 — Hamlib's -180 to 180 — counts 270 as -90.
  int controllerAzimuth(num azimuth, {int? from}) {
    final base = (azimuth.round() - azimuthOffset) % 360;
    var lowest = base;
    while (lowest - 360 >= azimuthMin) {
      lowest -= 360;
    }
    final reachable = [
      for (var candidate = lowest; candidate <= azimuthMax; candidate += 360)
        if (candidate >= azimuthMin) candidate,
    ];
    if (reachable.isEmpty) {
      return rotatorHeadingGap(base, azimuthMin % 360) <= rotatorHeadingGap(base, azimuthMax % 360) ? azimuthMin : azimuthMax;
    }
    if (from == null) return reachable.first;
    reachable.sort((a, b) => (a - from).abs().compareTo((b - from).abs()));
    return reachable.first;
  }

  int controllerElevation(num elevation) => (elevation.round() - elevationOffset).clamp(elevationMin, elevationMax);
}
