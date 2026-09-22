// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The calibration tables in drivers/info/, and the arithmetic that reads
// them.
//
// Every failure this file guards against is silent. A file that will not
// parse, a table that lost its rows, a unit key spelled wrong — none of them
// produce an error anywhere. They produce a radio that shows no meters,
// which is indistinguishable from a radio that has none, on a feature whose
// whole job is to be believed.
//
// The shipped files are read from DISK here rather than through the asset
// bundle: what has to be true is that the files in the tree are valid, and
// an asset-bundle test would pass on a stale bundle.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

/// Where the tables live, relative to the app package root — the same path
/// pubspec.yaml declares as an asset directory.
const _infoRoot = 'lib/services/cat/drivers/info';

void main() {
  group('the shipped tables', () {
    final files = Directory(_infoRoot).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).toList();

    test('there are some, and they are where the loader looks', () {
      // A file moved out of a declared folder is still in the tree, still
      // reviewed, still committed — and never loaded. The pubspec's asset
      // directories are not recursive, which is the trap: a new
      // manufacturer's folder needs a line of its own.
      expect(files, isNotEmpty);
      final declared = File('pubspec.yaml').readAsStringSync();
      for (final file in files) {
        final folder = '${File(file.path).parent.path}/';
        expect(declared, contains(folder), reason: '$folder is not declared in pubspec.yaml, so nothing in it is ever loaded');
      }
    });

    for (final file in files) {
      test('${file.uri.pathSegments.last} parses, and says where it came from', () {
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final calibration = MeterCalibration.fromJson(json);
        expect(calibration.model, isNotEmpty);
        // A file with no tables yet is fine — a radio somebody has started
        // and has no numbers for reports no meters, which is exactly what a
        // radio with no numbers should do. A file that HAS numbers must say
        // where they came from: these are measured, copied or published, and
        // which one decides how far to trust a reading that disagrees with
        // the radio's own meter.
        if (calibration.tables.isNotEmpty) {
          expect(calibration.provenance, isNotNull, reason: 'a calibration with no stated source cannot be checked by anyone later');
        }
      });
    }

    test('every table a radio ships is monotonic in its raw value', () {
      // [MeterCalibration.convert] walks the points in order and
      // interpolates between neighbours. Two rows out of order — an easy
      // typo in a hand-edited file — would answer nonsense over that
      // stretch, and the load sorts them precisely so the file need not be
      // trusted about it. This proves the sort, not the file.
      for (final file in files) {
        final calibration = MeterCalibration.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
        for (final entry in calibration.tables.entries) {
          final values = [for (final point in entry.value) point.value];
          expect(values, orderedEquals([...values]..sort()), reason: '${calibration.model} ${entry.key.name}');
        }
      }
    });

    test('every table stays inside the unit its key promises', () {
      // The unit is a contract the format states and nothing enforced. An
      // ALC row carrying 35 renders as "3500%" the day its radio is wired
      // up, and an SWR below 1 is not a match at all — both are silent until
      // somebody is looking at a panel, which is far too late for a number
      // an operator is warned about.
      for (final file in files) {
        final calibration = MeterCalibration.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
        final where = '${calibration.model} (${file.uri.pathSegments.last})';
        for (final point in calibration.tables[MeterTable.alc] ?? const <MeterPoint>[]) {
          // A fraction of the ALC zone, and a meter may genuinely read a
          // little past the top of it — the FTDX101's own table ends at 1.1,
          // which renders as 110% and means exactly that. What this is
          // catching is a table in some OTHER unit: a row reading 35 is not
          // an over-driven radio, it is dB or a raw span, and it renders as
          // 3500%.
          expect(point.y, inInclusiveRange(0, 2), reason: '$where alc is a fraction, not another unit');
        }
        for (final point in calibration.tables[MeterTable.swr] ?? const <MeterPoint>[]) {
          expect(point.y, greaterThanOrEqualTo(1.0), reason: '$where swr below 1 is not a match');
        }
        for (final point in calibration.tables[MeterTable.powerFraction] ?? const <MeterPoint>[]) {
          expect(point.y, inInclusiveRange(0, 1), reason: '$where powerFraction is a share of rated');
        }
        for (final table in [MeterTable.power, MeterTable.voltage, MeterTable.drain]) {
          for (final point in calibration.tables[table] ?? const <MeterPoint>[]) {
            expect(point.y, greaterThanOrEqualTo(0), reason: '$where ${table.name} cannot be negative');
          }
        }
      }
    });

    test('every calibration a catalogue entry names actually exists', () {
      // A typo in the override — `yaesu/ftdx-10`, a file renamed — costs
      // nothing anywhere and shows nothing anywhere: the radio simply has
      // no meters, exactly as if it had no table at all. This is the only
      // thing that can tell the two apart.
      final named = {
        for (final type in EquipmentRegistry().types)
          // The empty string is a radio saying it has NO meters, not a file
          // name — see the IC-706MKIIG below.
          if (type.overrides[meterInfoConfigKey] case final String key when key.isNotEmpty) key,
      };
      expect(named, isNotEmpty, reason: 'no entry names a calibration, so none of this is reachable');
      final shipped = {for (final file in files) MeterCalibrations.keyForAssetPath(file.path)};
      expect(shipped, containsAll(named));
    });

    test("the CI-V table keeps Icom's published breakpoints exactly", () {
      // These four are what Icom documents for the whole current line, and
      // they are the reason the CI-V scale is the DRIVER's default rather
      // than named by each of nine entries. Getting one wrong puts the
      // alert threshold in the wrong place — the number the operator is
      // actually being warned about.
      final calibration = _load('icom/civ-generic');
      expect(calibration.convert(MeterTable.swr, 0), 1.0);
      expect(calibration.convert(MeterTable.swr, 48), 1.5);
      expect(calibration.convert(MeterTable.swr, 80), 2.0);
      expect(calibration.convert(MeterTable.swr, 120), 3.0);
      // Interpolated between them, not snapped: 1.75 is the difference
      // between "fine" and the 1.8 the panel warns at.
      expect(calibration.convert(MeterTable.swr, 64), closeTo(1.75, 0.001));
    });

    test('CI-V power is a FRACTION of rated, and never more than all of it', () {
      // Unlike Yaesu's, which is in watts. CI-V states no wattage anywhere,
      // so the table can only say "this much of whatever the radio is rated
      // for" and the driver resolves it against that ceiling.
      final calibration = _load('icom/civ-generic');
      expect(calibration.has(MeterTable.power), isFalse, reason: 'watts would be an invented figure');
      // 143, as the guide writes it (`01 43`) — not the 141 this started
      // life with, which came from nobody's document.
      expect(calibration.convert(MeterTable.powerFraction, 143), closeTo(0.5, 0.001));
      expect(calibration.convert(MeterTable.powerFraction, 213), 1.0);
      // The published scale ends at 213. A radio reading above it is at full
      // output, not at 120% — which on a 100 W rig would print 120 W.
      expect(calibration.convert(MeterTable.powerFraction, 255), 1.0);
    });

    test('a radio that predates the meters says so, rather than inheriting them', () {
      // The IC-706MKIIG's CI-V gives command 0x15 two sub-commands, squelch
      // and S-meter; power, SWR and ALC arrived a generation later. Left to
      // inherit the driver's line-wide table it would reserve three slots on
      // the panel that can never fill, and poll for three answers the radio
      // can only reject.
      final registry = EquipmentRegistry();
      final old = registry.typeFor('ic706mkiig-serial')!;
      expect(old.telemetryMetersFor(const {}), isEmpty);
      // While the radios that DO have them still inherit.
      expect(registry.typeFor('ic7300-serial')!.overrides[meterInfoConfigKey], isNull);
    });

    test("the FTDX10's SWR table covers the range the alert is judged in", () {
      // The panel warns above 1.8 and draws its bar to 3.0. A table that
      // stopped at 1.5 would clamp everything worse than that to 1.5 — and
      // an SWR alert that can never fire is worse than no alert, because the
      // operator believes it is watching.
      final calibration = _load('yaesu/ftdx10');
      expect(calibration.convert(MeterTable.swr, 0), 1.0);
      expect(calibration.convert(MeterTable.swr, 89), 2.0);
      expect(calibration.convert(MeterTable.swr, 126), 3.0);
    });
  });

  group('reading a scale', () {
    final calibration = MeterCalibration(
      model: 'test',
      tables: const {
        MeterTable.swr: [MeterPoint(0, 1.0), MeterPoint(50, 2.0), MeterPoint(100, 3.0)],
      },
    );

    test('a point on the table is exactly what the table says', () {
      expect(calibration.convert(MeterTable.swr, 50), 2.0);
    });

    test('between two points the scale is interpolated, not snapped', () {
      // Snapping to the nearest row is the tempting simplification, and it
      // is wrong where it matters: an SWR is judged against a threshold that
      // sits between two rows on every table here.
      expect(calibration.convert(MeterTable.swr, 25), closeTo(1.5, 0.001));
      expect(calibration.convert(MeterTable.swr, 75), closeTo(2.5, 0.001));
    });

    test('past either end the scale is CLAMPED, never extrapolated', () {
      // A table states the range somebody measured. Running its last slope
      // out to 255 invents readings at exactly the end an SWR curve stops
      // being linear — and those are the readings the operator is warned
      // about.
      expect(calibration.convert(MeterTable.swr, 200), 3.0);
      expect(calibration.convert(MeterTable.swr, -5), 1.0);
    });

    test('a meter with no table answers null, which is not a zero', () {
      // The difference between "this radio has no ALC meter" and "the ALC
      // reads nothing". One leaves the slot off the panel; the other would
      // draw an empty bar for a meter that is working perfectly.
      expect(calibration.convert(MeterTable.alc, 100), isNull);
      expect(calibration.has(MeterTable.alc), isFalse);
      expect(calibration.has(MeterTable.swr), isTrue);
    });
  });

  group('reading a file', () {
    test('a row using the wrong unit key is refused, not read as something else', () {
      // The unit IS the key name. A `power` row carrying `ratio` is a table
      // pasted into the wrong place, and reading its numbers as watts would
      // put a plausible wrong figure on screen rather than nothing.
      expect(
        () => MeterCalibration.fromJson(const {
          'model': 'X',
          'meterCalibration': {
            'power': [
              {'value': 10, 'ratio': 1.5},
            ],
          },
        }),
        throwsFormatException,
      );
    });

    test('rows out of order are sorted rather than trusted', () {
      final calibration = MeterCalibration.fromJson(const {
        'model': 'X',
        'meterCalibration': {
          'swr': [
            {'value': 100, 'ratio': 3.0},
            {'value': 0, 'ratio': 1.0},
          ],
        },
      });
      expect(calibration.convert(MeterTable.swr, 50), closeTo(2.0, 0.001));
    });

    test('a file with no calibration at all is refused', () {
      expect(() => MeterCalibration.fromJson(const {'model': 'X'}), throwsFormatException);
    });
  });
}

MeterCalibration _load(String key) => MeterCalibration.fromJson(jsonDecode(File('$_infoRoot/$key.json').readAsStringSync()) as Map<String, dynamic>);
