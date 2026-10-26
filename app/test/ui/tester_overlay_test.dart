// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart' show MarkdownBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show buildHaLoTheme;
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/tester_overlay.dart';
import 'package:ham2k_logger/views/version_label.dart';

void main() {
  // Deliberately BELOW kBuildNumber (125): the header must name the running
  // build, and a fixture whose newest entry equals kBuildNumber can't tell
  // that apart from a regression back to "newest entry's build".
  const entries = [
    TesterNotesEntry(build: 124, changes: ['Newest change']),
    TesterNotesEntry(build: 123, changes: ['Older change']),
  ];
  // The header's build line for the RUNNING binary. `bareBuildNumber`, because
  // `flutter test` runs as the Dev edition, where every other version display
  // suppresses the build number — this overlay must name it anyway.
  final runningBuildLine = versionBuildLine(bareBuildNumber: true);

  // The covering flag is process-global; a test that fails mid-overlay must
  // not leave it stuck for the next one.
  tearDown(() => testerOverlayCovering.value = false);

  testWidgets('shows the caution tape, the standing warning, the RUNNING build, and every pending build\'s changes; '
      'Continue triggers onDismiss exactly once', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TesterOverlayView(entries: entries, release: null, onDismiss: () => dismissCount++),
        ),
      ),
    );

    expect(find.byType(Ham2kBrandMark), findsOneWidget);
    expect(find.byType(CautionTape), findsOneWidget);
    expect(tester.widget<CautionTape>(find.byType(CautionTape)).label, 'CAUTION: UNDER CONSTRUCTION');
    // The RUNNING build (kBuildNumber), not the newest entry's 124 — the
    // notes can lag the build when one ships without entries of its own.
    // Spelled out rather than compared to versionBuildLine's own output: this
    // line is the notes KEY, so it must name the binary's number exactly —
    // a `130.2` from a code push still `contains('130')` and would slip past a
    // looser check while naming a build the notes index doesn't hold.
    expect(runningBuildLine, endsWith('(build $kBuildNumber)'));
    expect(find.text(runningBuildLine), findsOneWidget);
    // The warning and every pending build's section are lines within the
    // same MarkdownBody — a catch-up tester must get BOTH builds' notes,
    // not just the newest (the "since last seen" contract).
    expect(find.textContaining('work in progress'), findsOneWidget);
    expect(find.textContaining('check for updates regularly'), findsOneWidget);
    expect(find.textContaining("What's new in build 124"), findsOneWidget);
    expect(find.textContaining("What's new in build 123"), findsOneWidget);
    expect(find.textContaining('Newest change'), findsOneWidget);
    expect(find.textContaining('Older change'), findsOneWidget);
    // The under-construction GIF and the thank-you close the notes, a full
    // viewport below the text. The widget-level find only pins the path
    // STRING; the rootBundle load is what actually fails on a
    // deleted/renamed asset file, which otherwise only surfaces as a broken
    // image at runtime.
    expect(find.image(const AssetImage('assets/images/under.gif')), findsOneWidget);
    await tester.runAsync(() => rootBundle.load('assets/images/under.gif'));
    expect(find.textContaining('Thank you for putting your log at risk'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));

    // The overlay doesn't remove itself — main.dart's `_TesterOverlayGate`
    // stamps `lastSeenTesterBuild` and clears its pending state on this
    // callback. Checking the count (not just "button exists") catches an
    // unwired onDismiss.
    expect(dismissCount, 1);
  });

  testWidgets('the notes are scrollable in place — no expand/collapse — and tapping them dismisses', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TesterOverlayView(entries: entries, release: null, onDismiss: () => dismissCount++),
        ),
      ),
    );

    // The band starts (and stays) readable and genuinely scrollable — a
    // regression back to the release overlay's collapsed, scroll-locked
    // preview band would leave the drag below at offset zero.
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.maxScrollExtent, greaterThan(0), reason: 'the GIF sits a full viewport below the notes');
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    // With no toggle, a tap on the notes text falls through to the
    // view-wide dismiss handler rather than expanding anything.
    await tester.tap(find.textContaining('work in progress'));
    expect(dismissCount, 1);

    // The header, over the bare photo, dismisses too — tapped through
    // `hitTestable()` so a header that has slid under the notes band fails here
    // instead of quietly dismissing via the band's own handler.
    expect(find.text(runningBuildLine).hitTestable(), findsOneWidget);
    await tester.tap(find.text(runningBuildLine).hitTestable());
    expect(dismissCount, 2);
  });

  testWidgets('the panel is pinned to the light theme in dark mode', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          darkTheme: buildHaLoTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: TesterOverlayView(entries: entries, release: null, onDismiss: () {}),
        ),
      ),
    );

    // The whole subtree is pinned to the light theme, not forced color by
    // color — without the pin, anything NOT in the forced list (markdown
    // styles beyond p/listBullet/strong, scrollbars, button ink) paints
    // dark-mode colors onto the white band. Same contract as the release
    // and onboarding overlays.
    //
    // HaloMarkdown resolves its style sheet from `Theme.of` at its own
    // context, which is what this reads, so a light theme here is the light
    // markdown. Everything the panel resolves from its own `theme` is a font
    // size or a forced color, the same in both brightnesses.
    final ambient = Theme.of(tester.element(find.byType(MarkdownBody)));
    expect(ambient.brightness, Brightness.light);
  });

  testWidgets('flags testerOverlayCovering while mounted; Esc and Enter continue, other keys do not', (tester) async {
    var dismissCount = 0;
    expect(testerOverlayCovering.value, isFalse);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: TesterOverlayView(entries: entries, release: null, onDismiss: () => dismissCount++),
        ),
      ),
    );
    await tester.pump();

    // Global HardwareKeyboard handlers (onboarding's Enter shortcut, the
    // app chords in main.dart) dispatch AHEAD of the overlay's Focus node
    // and cannot be blocked by it — this flag is what they consult to
    // stand down, so the flag IS the leak protection. Without it, one
    // Enter would dismiss the overlay and advance onboarding beneath.
    expect(testerOverlayCovering.value, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(dismissCount, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissCount, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(dismissCount, 2);

    // Unmounting releases the flag, waking the global handlers back up.
    await tester.pumpWidget(const SizedBox());
    expect(testerOverlayCovering.value, isFalse);
  });
}
