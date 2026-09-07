// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// docs/design/user-interface.md: the app has NO hover labels. A label that
// pops up over whatever is under the pointer is noise on desktop, and on
// touch it never appears at all — an icon that needs one needs a better
// icon, or a visible text label. Icon-only buttons are named for screen
// readers with `Icon(..., semanticLabel: ...)` instead, which displays
// nothing.
//
// Nothing enforced that, and `tooltip:` is the obvious thing to reach for
// (it's what Flutter's own IconButton docs suggest), so this reads the UI
// SOURCE the way scoring_labels_test reads the scorers': a reintroduced
// tooltip gets caught the day it lands rather than at the next design pass.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';

import 'support/halo_test_support.dart';

/// Every `.dart` file under the app's and the widget package's `lib/`.
List<File> _uiSources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing, find nothing, and pass while enforcing nothing at all.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return [
    for (final root in roots)
      ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
  ];
}

void main() {
  test('no widget uses a hover tooltip', () {
    final offenders = <String>[];
    for (final file in _uiSources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments are how the convention gets explained, so only code counts.
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        if (RegExp(r'\btooltip:').hasMatch(line) || RegExp(r'\bTooltip\(').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Hover labels are not used in this app (docs/design/user-interface.md).\n'
          'Name the button for screen readers instead — Icon(..., semanticLabel: ...) —\n'
          'and expose it on a widget API as a `...Label` parameter, never `...Tooltip`.\n'
          'Found:\n${offenders.join('\n')}',
    );
  });

  // The scan above can only see tooltips we WRITE. Flutter's own built-ins
  // (BackButton, CloseButton, PopupMenuButton, Chip's delete icon) supply
  // theirs from MaterialLocalizations and take no parameter to turn it off,
  // so the app root suppresses them for the whole tree at once. That is the
  // half of the convention no source scan can enforce.
  testWidgets('the app root suppresses the tooltips Flutter supplies itself', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setReleaseNotesForTesting(const []);
    setTesterNotesForTesting(const []);
    final HaLoHarness(:services) = await makeHaLoServices(prefs: null);

    await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
    await tester.pumpAndSettle();

    // Asserted at a context INSIDE the app's content, not by finding the
    // widget: what matters is that ordinary UI actually inherits the
    // suppression, which is what a misplaced wrapper would break.
    final inside = tester.element(find.byType(Scaffold).first);
    expect(TooltipVisibility.of(inside), isFalse, reason: 'app content must inherit tooltip suppression');

    // Drain pending timers to avoid test errors.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
