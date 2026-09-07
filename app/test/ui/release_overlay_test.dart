// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/views/release_overlay.dart';
import 'package:ham2k_logger/views/version_label.dart';

void main() {
  const release = ReleaseNotesEntry(
    version: '26.8.0',
    name: "August '26",
    photoCaption: 'M1SDH at GB-4724',
    changes: ['First change', 'Second change'],
  );

  testWidgets('a short viewport does not overflow the photo', (tester) async {
    // The header (brand mark, credits, two version lines) sits in a
    // Stack-tight column with nothing to scroll, so anything that makes it
    // taller — a second version line, or a large Font Scale, which divides the
    // logical viewport (docs/design/ui-scaling.md) — paints overflow stripes
    // across the release photo instead. 600x300 is a phone in landscape.
    tester.view.physicalSize = const Size(600, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: ReleaseOverlayView(release: release, onDismiss: () {})),
    ));

    expect(tester.takeException(), isNull);
  });

  group('overlayVersionHeader', () {
    // Exercised directly rather than through an overlay: the overlays' notes
    // bands have their own layouts (and their own overflow at extreme heights),
    // so driving the header through one tests two things at once and reports
    // the wrong one.
    testWidgets('scales the block down when the viewport is too short for it, and never overflows', (tester) async {
      // Pumped through a builder so the header gets a real BuildContext.
      Future<Rect> render(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(builder: (context) => overlayVersionHeader(context, logoWidth: 180)),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        return tester.getRect(find.byType(Ham2kBrandMark));
      }

      final roomy = await render(const Size(800, 600));
      // Anchored to the TOP: under the Stack's tight constraints the block
      // would otherwise float down the middle of the photo.
      expect(roomy.top, lessThan(60));

      // Compared against the SAME mark on the roomy viewport rather than a
      // pixel constant: the numbers follow logoWidth and the header's spacing,
      // and a threshold tuned to today's version strings stops testing anything
      // the day a patch-0 cut empties the build line.
      final short = await render(const Size(600, 200));
      expect(short.width, lessThan(roomy.width));
      expect(short.height, greaterThan(0), reason: 'a mis-measured allowance collapses the box and paints nothing');
      expect(short.top, lessThan(60));
    });
  });

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
    // Anchored to the TOP of the photo. Asserted at this (roomy) viewport
    // rather than the short one below, where the header fills the height and a
    // centered block would land in the same place as a top-anchored one — the
    // FittedBox takes the whole Stack under its tight constraints, so its
    // alignment is the only thing keeping the header out of the middle.
    expect(tester.getRect(find.byType(Ham2kBrandMark)).top, lessThan(60));
    // The RUNNING build's version over its build line, NOT `release.name` from
    // the notes entry ("August '26") — the header names what the reader is
    // running, the notes below describe the release.
    expect(find.text(kVersionMainName), findsOneWidget);
    // Guarded on emptiness, not on today's `Patch 1`: the next release cut that
    // resets the patch to 0 makes versionBuildLine() empty in a Dev test run,
    // and VersionLabel then renders no second line at all.
    final buildLine = versionBuildLine();
    expect(find.text(buildLine), buildLine.isEmpty ? findsNothing : findsOneWidget);
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

    // The version name sits above the notes band, over the bare photo — not
    // covered by the notes' or Continue's own tap targets, so it must fall
    // through to the view-wide dismiss handler.
    await tester.tap(find.text(kVersionMainName));

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
    //
    // This asserts the pin EXISTS, and only that. It cannot tell whether the
    // overlay actually resolved through it: every context in the tree is
    // below the pin, so this reads light either way. The dark-app test below
    // is what covers the resolution.
    final ambient = Theme.of(tester.element(find.byType(MarkdownBody)));
    expect(ambient.brightness, Brightness.light);
  });

  testWidgets('in a DARK app the overlay is still built from the light theme', (tester) async {
    // Catches the overlay resolving its theme from anywhere but the pin: a
    // helper on the State reading `State.context` (an ancestor of the pin), or
    // a bare `buildHaLoTheme()` read. Either paints dark-mode colors onto this
    // white band, silently, with the light-mode case still perfectly correct.
    //
    // What it does NOT catch, so nobody assumes otherwise: reverting the
    // pin-above-content refactor. The shape before it was
    // `Builder(builder: _buildOverlay)` with a `BuildContext` PARAMETER, which
    // shadows `State.context` — that already resolved below the pin, and this
    // test passes green against it.
    //
    // Asserted on a value the build method RESOLVED: `codeblockDecoration`
    // comes from `theme.cardColor` via MarkdownStyleSheet.fromTheme and is
    // not overridden here.
    final light = buildHaLoTheme(Brightness.light);
    final dark = buildHaLoTheme(Brightness.dark);
    // Guards against the whole assertion being vacuous — if the two themes
    // ever agreed on cardColor this test could not fail.
    expect(light.cardColor, isNot(dark.cardColor));

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: dark,
        home: ReleaseOverlayView(release: release, onDismiss: () {}),
      ),
    ));

    final sheet = tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
    expect((sheet.codeblockDecoration as BoxDecoration).color, light.cardColor);
  });
}
