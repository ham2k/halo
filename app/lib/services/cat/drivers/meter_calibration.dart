// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a radio's raw meter readings MEAN, in the units an operator uses.
//
// The tables themselves live in `info/`, as JSON, one file per model — not
// in this file and not in a driver. They are data, they are edited far more
// often than the code that reads them, and a table is easier to check
// against a manual or a bench sheet when it is a list of numbers rather than
// a Dart literal wearing punctuation. `info/README.md` is their format.
//
// Every protocol here answers its meters with a raw scale — 0-255 on a
// Yaesu, 0-255 on a CI-V — and none of them says what the number means. So
// this is the one place a raw reading becomes watts, or an SWR, or volts,
// and a radio with no table reports NOTHING rather than a guess: an invented
// SWR is measured against a threshold the operator is warned at.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

/// Which meter a table describes.
///
/// The names match the JSON keys, and the unit each one is measured in is
/// fixed by [meterCalibrationUnits] — a file naming a different unit for a
/// table is refused rather than read in whatever unit it offered, because a
/// silently mis-read table is an SWR of 5 shown as 1.2.
enum MeterTable { strength, power, powerFraction, swr, drain, voltage, compression, alc }

/// The JSON key each table's Y value carries, which is also its unit.
const meterCalibrationUnits = <MeterTable, String>{
  MeterTable.strength: 'db',
  MeterTable.power: 'watts',
  // The same meter, on a radio whose protocol expresses it as a share of
  // the rig's own maximum rather than in watts — every CI-V radio. The two
  // are separate tables rather than one with a unit field because they are
  // not interchangeable: watts are an answer, a fraction is an answer only
  // once something else says what the radio is rated for.
  MeterTable.powerFraction: 'fraction',
  MeterTable.swr: 'ratio',
  MeterTable.drain: 'amperes',
  MeterTable.voltage: 'volts',
  MeterTable.compression: 'db',
  // 0.0-1.0 of the radio's own ALC zone. A fraction rather than dB because
  // that is all any of these radios actually states.
  MeterTable.alc: 'level',
};

/// One point on a meter's scale: what the radio answered, and what it meant.
@immutable
class MeterPoint {
  /// The raw reading, as the radio reports it.
  final int value;

  /// What that reading means, in the table's own unit.
  final double y;

  const MeterPoint(this.value, this.y);

  @override
  bool operator ==(Object other) => other is MeterPoint && other.value == value && other.y == y;

  @override
  int get hashCode => Object.hash(value, y);

  @override
  String toString() => 'MeterPoint($value → $y)';
}

/// One radio's meter scales.
@immutable
class MeterCalibration {
  /// The model this describes, as the file names it — for diagnostics, and
  /// so a table that turns out to be wrong can be traced to a file.
  final String model;

  /// Where the numbers came from — the file's `_comments`, underscored the
  /// way these files mark a note for whoever is reading them rather than a
  /// table to be loaded.
  ///
  /// Kept because it is the first thing anyone asks of a calibration table,
  /// and the answer is not always the same: some of these are published by
  /// the manufacturer, some are copied, some are measured.
  final String? provenance;

  final Map<MeterTable, List<MeterPoint>> tables;

  const MeterCalibration({required this.model, required this.tables, this.provenance});

  /// [raw] in the table's own unit, or null when this radio has no table for
  /// [table] — which is a real answer, and the one that keeps a meter the
  /// radio cannot describe off the screen entirely.
  ///
  /// Between two points the scale is interpolated linearly; outside the
  /// table's ends it is CLAMPED, never extrapolated. A table states the
  /// range someone actually measured, and running its last slope out to 255
  /// invents readings at exactly the end an SWR table reaches — where the
  /// curve is steepest and least linear.
  double? convert(MeterTable table, int raw) {
    final points = tables[table];
    if (points == null || points.isEmpty) return null;
    if (raw <= points.first.value) return points.first.y;
    if (raw >= points.last.value) return points.last.y;
    for (var i = 1; i < points.length; i++) {
      final high = points[i];
      if (raw > high.value) continue;
      final low = points[i - 1];
      final span = high.value - low.value;
      if (span <= 0) return high.y;
      return low.y + (high.y - low.y) * (raw - low.value) / span;
    }
    return points.last.y;
  }

  bool has(MeterTable table) => (tables[table]?.isNotEmpty ?? false);

  /// Reads one of the `info/` files.
  ///
  /// Throws on a malformed file rather than returning a partial calibration:
  /// these are loaded together at startup, and a file that silently lost its
  /// SWR table would show a radio with power and no SWR, which reads as the
  /// radio not having the meter.
  factory MeterCalibration.fromJson(Map<String, dynamic> json) {
    final calibration = json['meterCalibration'];
    if (calibration is! Map) throw FormatException('no meterCalibration in ${json['model']}');
    final tables = <MeterTable, List<MeterPoint>>{};
    for (final table in MeterTable.values) {
      final rows = calibration[table.name];
      if (rows == null) continue;
      if (rows is! List) throw FormatException('${table.name} is not a list');
      final unit = meterCalibrationUnits[table]!;
      final points = <MeterPoint>[
        for (final row in rows)
          if (row is Map)
            MeterPoint(
              (row['value'] as num).toInt(),
              (row[unit] as num?)?.toDouble() ??
                  (throw FormatException('${table.name} row has no "$unit": $row')),
            ),
      ];
      // Sorted here rather than trusted from the file: [convert] walks the
      // points in order, and a file with two rows swapped would answer
      // nonsense over that stretch and nothing anywhere would say so.
      points.sort((a, b) => a.value.compareTo(b.value));
      if (points.isNotEmpty) tables[table] = points;
    }
    return MeterCalibration(
      model: '${json['model'] ?? 'unnamed'}',
      provenance: calibration['_comments'] as String?,
      tables: tables,
    );
  }
}

/// Where a catalogue entry names its calibration file, without the `.json` —
/// `yaesu/ftdx10`. An entry that names none has no meters converted, which
/// is the right answer for a generic entry: it does not know which radio is
/// behind it.
const meterInfoConfigKey = 'meterInfo';

/// The calibration describing a node: what its catalogue entry names, or
/// [fallbackKey] — the driver's own, for a protocol whose meter scale is a
/// fact about the whole line rather than about one radio.
///
/// Both cases are real and they are not the same. Yaesu aligns its meters
/// per radio and publishes no scale, so every table is a model's own and an
/// entry has to name it. Icom publishes ONE set of breakpoints for the
/// current CI-V line, so its driver carries the default and an entry names
/// something else only where a particular radio is known to differ.
/// An entry naming the EMPTY string says this radio has no meters and must
/// not inherit the driver's default — an IC-706MKIIG, whose CI-V has only
/// squelch and an S-meter under command 0x15. Distinct from naming nothing
/// at all, which is what inherits.
MeterCalibration? calibrationForConfig(Map<String, dynamic> config, {String? fallbackKey}) {
  final named = config[meterInfoConfigKey] as String?;
  if (named != null && named.isEmpty) return null;
  return MeterCalibrations.instance[named ?? fallbackKey];
}

/// Every shipped calibration, by the key an entry names it with.
///
/// Loaded once, asynchronously, and read synchronously afterwards — a driver
/// creating a session cannot await anything. Nothing orders the two: a
/// session asks for its table each time it converts a reading, so one built
/// before the load finished simply starts converting when the data lands.
class MeterCalibrations {
  MeterCalibrations._();

  static final MeterCalibrations instance = MeterCalibrations._();

  final Map<String, MeterCalibration> _byKey = {};
  Future<void>? _loading;

  /// The calibration for [key], or null — for a radio with no file, and for
  /// the window before the load has landed.
  MeterCalibration? operator [](String? key) => key == null ? null : _byKey[key];

  /// Every key loaded, for diagnostics and tests.
  Iterable<String> get keys => _byKey.keys;

  /// Reads every file the bundle carries under `info/`.
  ///
  /// Discovered from the asset manifest rather than from a list in Dart:
  /// the whole point of the folder is that a new radio's table is a file
  /// somebody drops in, and a list here would be a second place to forget.
  /// (The folder itself still has to be declared in pubspec.yaml — asset
  /// directories are not recursive, so a new MANUFACTURER needs a line
  /// there; `info/README.md` says so.)
  Future<void> load({AssetBundle? bundle}) => _loading ??= _load(bundle ?? rootBundle);

  Future<void> _load(AssetBundle bundle) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final paths = manifest.listAssets().where((p) => p.contains('$_assetRoot/') && p.endsWith('.json'));
      for (final path in paths) {
        try {
          final json = jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;
          _byKey[keyForAssetPath(path)] = MeterCalibration.fromJson(json);
        } catch (e) {
          // One bad file must not cost the others. It is also worth saying
          // out loud: the symptom otherwise is a radio quietly showing no
          // meters, which looks exactly like a radio that has none.
          debugPrint('[cat] meter calibration $path could not be read: $e');
        }
      }
    } catch (e) {
      debugPrint('[cat] meter calibrations could not be listed: $e');
    }
  }

  static const _assetRoot = 'lib/services/cat/drivers/info';

  /// `…/info/yaesu/ftdx10.json` → `yaesu/ftdx10`.
  static String keyForAssetPath(String path) {
    final start = path.indexOf('$_assetRoot/') + _assetRoot.length + 1;
    return path.substring(start, path.length - '.json'.length);
  }

  /// For tests, which must not depend on an asset load having happened —
  /// the same escape hatch release_notes.dart and tester_notes.dart keep.
  @visibleForTesting
  void setForTesting(Map<String, MeterCalibration> calibrations) {
    _byKey
      ..clear()
      ..addAll(calibrations);
    _loading = Future.value();
  }
}
