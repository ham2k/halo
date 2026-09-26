// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On the web a SnackBar over the map hands its clicks and its swipe-to-dismiss
// to the map's element, unless it is shielded (platform_view_shield.dart) —
// and the shield has to span the whole bar, which only `haloSnackBar` arranges.
// A bare `SnackBar(` is the obvious thing to reach for, so this reads the UI
// source the way no_hover_tooltips_test does: a new one is caught the day it
// lands.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every SnackBar is a haloSnackBar', () {
    final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
    // Loudly, not vacuously: from an unexpected cwd this would scan nothing
    // and pass while enforcing nothing.
    for (final root in roots) {
      if (!root.existsSync()) fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
    final offenders = <String>[];
    for (final file in [for (final root in roots) ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))]) {
      // The helper itself, and only it.
      if (file.path == '../packages/halo_widgets/lib/src/halo_snack_bar.dart') continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.contains('//') ? line.substring(0, line.indexOf('//')) : line;
        if (RegExp(r'(?<![A-Za-z_])SnackBar\(').hasMatch(code)) offenders.add('${file.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'build it with haloSnackBar, which shields it from a map beneath');
  });
}
