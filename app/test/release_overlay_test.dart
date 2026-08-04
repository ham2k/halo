// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/release_overlay.dart';

void main() {
  const release = ReleaseNotesEntry(
    version: '26.8.0',
    name: "August '26",
    photoCaption: 'M1SDH at GB-4724',
    changes: ['First change', 'Second change'],
  );

  testWidgets(
      'shows the brand mark, release name, caption, and "What\'s new in this release" changes; '
      'Continue triggers onDismiss exactly once', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: ReleaseOverlayView(release: release, onDismiss: () => dismissCount++),
      ),
    ));

    expect(find.byType(Ham2kBrandMark), findsOneWidget);
    expect(find.text("August '26"), findsOneWidget);
    // The caption is its own Text (centered, outside the notes band) — the
    // heading and changes are lines within the same MarkdownBody, so
    // textContaining matches the whole rendered line rather than an exact
    // standalone string.
    expect(find.text('M1SDH at GB-4724'), findsOneWidget);
    expect(find.textContaining("What's new in this release"), findsOneWidget);
    expect(find.textContaining('First change'), findsOneWidget);
    expect(find.textContaining('Second change'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));

    // The overlay itself doesn't remove its own child — that's the caller's
    // job (main.dart's `_ReleaseOverlayGate` sets `lastSeenReleaseVersion`
    // and clears `_pending` on this callback). A test that only checked "the
    // button exists" would pass even if onDismiss were never wired up.
    expect(dismissCount, 1);
  });

  testWidgets('tapping the notes area expands it (scrollable) without triggering onDismiss', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: ReleaseOverlayView(release: release, onDismiss: () => dismissCount++),
      ),
    ));

    // Collapsed: scrolling is disabled (the view itself only exists so the
    // notes' natural height doesn't overflow a clipped, fixed-height band —
    // see release_overlay.dart) — a tap that lands on the notes text must
    // not be swallowed by (or bubble into) the Continue button below it.
    SingleChildScrollView scrollView() => tester.widget(find.byType(SingleChildScrollView));
    expect(scrollView().physics, isA<NeverScrollableScrollPhysics>());

    await tester.tap(find.textContaining("What's new in this release"));
    await tester.pumpAndSettle();

    expect(scrollView().physics, isNot(isA<NeverScrollableScrollPhysics>()));
    expect(dismissCount, 0);
  });

  testWidgets('expanding the notes fades the caption out, collapsing fades it back in', (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: ReleaseOverlayView(release: release, onDismiss: () {}),
      ),
    ));

    AnimatedOpacity captionOpacity() => tester.widget(
          find.ancestor(of: find.text('M1SDH at GB-4724'), matching: find.byType(AnimatedOpacity)),
        );
    expect(captionOpacity().opacity, 1);

    await tester.tap(find.textContaining("What's new in this release"));
    await tester.pumpAndSettle();
    expect(captionOpacity().opacity, 0);

    await tester.tap(find.textContaining("What's new in this release"));
    await tester.pumpAndSettle();
    expect(captionOpacity().opacity, 1);
  });

  testWidgets('tapping the view outside the notes area and the Continue button dismisses it', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: ReleaseOverlayView(release: release, onDismiss: () => dismissCount++),
      ),
    ));

    // The release name ("August '26") sits above the notes band, over the
    // bare photo — not covered by the notes' or Continue's own tap targets,
    // so it must fall through to the view-wide dismiss handler.
    await tester.tap(find.text("August '26"));

    expect(dismissCount, 1);
  });

  testWidgets('the notes text stays black in dark mode — this panel ignores the app theme', (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        darkTheme: buildHaLoTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: ReleaseOverlayView(release: release, onDismiss: () {}),
      ),
    ));

    final styleSheet = tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
    expect(styleSheet.p!.color, Colors.black);
    expect(styleSheet.listBullet!.color, Colors.black);
    expect(styleSheet.strong!.color, Colors.black);

    // The whole subtree is pinned to the light theme, not forced color by
    // color — without the pin, anything NOT in the forced list (markdown
    // headers, scrollbars, button ink) paints dark-mode colors onto the
    // white band.
    final ambient = Theme.of(tester.element(find.byType(MarkdownBody)));
    expect(ambient.brightness, Brightness.light);
  });
}
