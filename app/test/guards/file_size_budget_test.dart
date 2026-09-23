// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A file grows because the nearest code already lives there, and nothing
// pushes back: one reasonable addition at a time lands in the file every
// task already has open, until a file is a reading cost on every change to
// it and a merge conflict waiting for the next parallel session.
//
// So a first-party lib file stops at 1500 lines. The files already past it
// are listed below at the size they had when listed, and that number is a
// CEILING, not a licence: a listed file may drift a little above it — the
// same hundred lines the stale check tolerates below it, room for a fix, not
// for a feature — and never further on its own. When a change shrinks a
// listed file the entry comes down with it, off the list once it is under
// budget. Splitting a file is the way off it; adding a file to it is the
// last resort, with a card that says when it comes off.
//
// A number here goes UP only when the maintainer says so, asked directly and
// answered directly. Nothing else may raise one — not to land the change in
// hand, not as tidying, and never quietly: a budget that the work can edit
// is not a budget. Tripping this guard is a stop-and-ask, and an answer that
// moves a number is recorded against the entry, so the next reader sees a
// decision rather than a drift.
//
// Generated code is exempt: a `.g.dart` file is as long as its generator
// makes it and nobody reads it top to bottom.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _budget = 1500;

/// How far a listed file may sit above its ceiling before it has to be
/// split, and how far under it before the ceiling is stale. Generous enough
/// that a fix never trips it; tight enough that a feature cannot hide in it,
/// and that a real extraction has to bring the number down with it.
const _slack = 100;

/// Path → the line count it had when it was listed. Lower a number when
/// the file shrinks. Raising one is the maintainer's call and carries a
/// comment saying so, per the note at the top of this file.
const _ceilings = <String, int>{
  // Above the budget by the maintainer's answer, not by drift. HALO-673 is
  // the extraction; this number comes down with it.
  '../packages/halo_widgets/lib/src/logging_controls.dart': 3890,
  'lib/services/extension_service.dart': 3596,
  'lib/views/operation/spots_panel.dart': 3498,
  'lib/views/operation_view.dart': 3117,
  'lib/views/operation/activities_view.dart': 2911,
  '../packages/halo_widgets/lib/src/form_renderer.dart': 2737,
  'lib/views/logs_view.dart': 2701,
  'lib/services/cat/cat_service.dart': 2628,
  'lib/views/station_panel.dart': 1915,
  'lib/views/dock_host.dart': 2094,
  '../packages/halo_widgets/lib/src/qso_list.dart': 1822,
  'lib/services/halo_services.dart': 1987,
  '../packages/halo_widgets/lib/src/dock_layout.dart': 1817,
  'lib/views/home_view.dart': 1684,
  '../packages/halo_core/lib/src/sync/sync_engine.dart': 1553,
  'lib/services/settings_service.dart': 1690,
};

/// Every non-generated `.dart` file under the first-party `lib/` roots.
List<File> _sources() {
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing and pass while enforcing nothing at all.
  final packages = Directory('../packages');
  for (final root in [Directory('lib'), packages]) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  // Every package under packages/ except the vendored copies of third-party
  // plugins, which are as long as upstream made them. Derived, not listed,
  // so a package added later is under the budget from its first file.
  final vendored = RegExp(r'_(patched|stub)$');
  final roots = [
    Directory('lib'),
    for (final dir in packages.listSync().whereType<Directory>())
      if (!vendored.hasMatch(dir.path)) Directory('${dir.path}/lib'),
    // The distribution layer is first-party too, but absent from the public
    // mirror by design, so it counts only where it exists.
    if (Directory('../app_dist/lib').existsSync()) Directory('../app_dist/lib'),
  ];
  return [for (final root in roots) ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))];
}

void main() {
  test('no first-party lib file grows past its budget', () {
    final grew = <String>[];
    final unlisted = <String>[];
    final stale = <String>[];
    final seen = <String>{};
    for (final file in _sources()) {
      final lines = file.readAsLinesSync().length;
      final ceiling = _ceilings[file.path];
      if (ceiling == null) {
        if (lines > _budget) unlisted.add('${file.path}: $lines lines');
        continue;
      }
      seen.add(file.path);
      if (lines > ceiling + _slack) {
        grew.add(
          '${file.path}: $lines lines, ceiling $ceiling — split it, or move what you are adding '
          'to where it belongs. Do not raise the ceiling: if you think it has to move, stop and ask.',
        );
      } else if (lines <= _budget) {
        stale.add('${file.path}: now $lines lines, under the budget — remove it from the list');
      } else if (lines <= ceiling - _slack) {
        stale.add('${file.path}: now $lines lines, ceiling still $ceiling — lower it');
      }
    }
    final gone = _ceilings.keys.where((p) => !seen.contains(p)).map((p) => '$p: no longer exists — remove it').toList();
    expect(
      [...grew, ...unlisted, ...stale, ...gone],
      isEmpty,
      reason:
          'The file-size budget is $_budget lines, and a listed file may not grow past its ceiling by more than $_slack.\n'
          'Split the file, or move what you are adding to where it belongs.\n'
          'Found:\n${[...grew, ...unlisted, ...stale, ...gone].join('\n')}',
    );
  });
}
