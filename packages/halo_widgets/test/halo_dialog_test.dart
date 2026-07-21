// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every dialog is banded: header and footer in the Modal Pane chrome colour
// (surfaceContainerHigh) around a surface-coloured content area — near-white
// in light mode, near-black in dark.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Future<ThemeData> pump(WidgetTester tester, Brightness brightness) async {
    final theme = buildHaLoTheme(brightness);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: HaloDialog(
          title: Text('Title'),
          content: Text('Body'),
          actions: [Text('OK')],
        ),
      ),
    ));
    return theme;
  }

  // The card colour IS the band colour — the header and footer are just it
  // showing around the content, so there's no separate band widget to find.
  Finder contentSurface(ThemeData theme) => find.descendant(
        of: find.byType(HaloDialog),
        matching: find.byWidgetPredicate((w) => w is Material && w.color == theme.colorScheme.surface),
      );

  testWidgets('light mode: bands in surfaceContainerHighest, content on near-white surface', (tester) async {
    final theme = await pump(tester, Brightness.light);

    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, theme.colorScheme.surfaceContainerHighest);
    expect(contentSurface(theme), findsOneWidget);
    // Guards the whole point: the content must not be the band colour.
    expect(theme.colorScheme.surface, isNot(theme.colorScheme.surfaceContainerHighest));
    expect(theme.colorScheme.surface, const Color(0xFFFBFCFE));
  });

  testWidgets('dark mode: content is the near-black surface, still distinct from the bands', (tester) async {
    final theme = await pump(tester, Brightness.dark);

    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, theme.colorScheme.surfaceContainerHighest);
    expect(contentSurface(theme), findsOneWidget);
    expect(theme.colorScheme.surface, isNot(theme.colorScheme.surfaceContainerHighest));
    expect(theme.colorScheme.surface, const Color(0xFF191C1E));
  });

  testWidgets('stays within the width cap even when the content is enormous', (tester) async {
    // Regression: showDialog hands its builder TIGHT full-screen constraints,
    // so showHaloDialog's ConstrainedBox silently did nothing until it was
    // wrapped in a Center — a 5000px-wide child rendered a 720px card on an
    // 800px screen, blowing straight past the cap.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showHaloDialog<void>(
            context: context,
            builder: (_) => const HaloDialog(
              title: Text('Wide'),
              content: SizedBox(width: 5000, child: Text('very wide content')),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final card = tester.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
    expect(card.width, lessThanOrEqualTo(maxDialogWidth));
  });

  testWidgets('a plain prompt stays compact; wide dialogs get the full cap', (tester) async {
    Future<double> cardWidth({required bool wide}) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showHaloDialog<void>(
              context: context,
              builder: (_) => HaloDialog(
                title: const Text('T'),
                wide: wide,
                // Far wider than either cap, so the cap is what's measured.
                content: const SizedBox(width: 5000, child: Text('x')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final width =
          tester.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first).width;
      // Dismiss, or the next measurement taps this dialog's barrier instead of
      // the button and just re-measures this one.
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      return width;
    }

    expect(await cardWidth(wide: false), compactDialogWidth);
    // Wide sits between the two caps: maxDialogWidth less Dialog's own insets.
    final wideWidth = await cardWidth(wide: true);
    expect(wideWidth, greaterThan(compactDialogWidth));
    expect(wideWidth, lessThanOrEqualTo(maxDialogWidth));
  });

  testWidgets('the header matches a view header: same type, same height', (tester) async {
    final theme = await pump(tester, Brightness.light);
    final appBarTitle = theme.appBarTheme.titleTextStyle!;

    // Same family/size/weight as an AppBar title, recoloured for the band.
    final style = DefaultTextStyle.of(tester.element(find.text('Title'))).style;
    expect(style.fontFamily, appBarTitle.fontFamily);
    expect(style.fontSize, appBarTitle.fontSize);
    expect(style.fontWeight, appBarTitle.fontWeight);
    expect(style.color, theme.colorScheme.onSurface);

    // And the band is a view header tall.
    final header = find.ancestor(of: find.text('Title'), matching: find.byType(ConstrainedBox)).first;
    expect(tester.getSize(header).height, theme.appBarTheme.toolbarHeight);
  });

  testWidgets('a Modal Pane uses the very same header as a dialog', (tester) async {
    // Regression: the pane hand-rolled its own header, so it kept headlineSmall
    // and a content-driven height while dialogs moved to the view-header type.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showModalPane<void>(
            context,
            title: 'Pane Title',
            builder: (_) => const Text('body'),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(HaloDialogHeader), findsOneWidget);
    final theme = Theme.of(tester.element(find.text('Pane Title')));
    final style = DefaultTextStyle.of(tester.element(find.text('Pane Title'))).style;
    expect(style.fontFamily, theme.appBarTheme.titleTextStyle!.fontFamily);
    expect(style.fontSize, theme.appBarTheme.titleTextStyle!.fontSize);
    expect(tester.getSize(find.byType(HaloDialogHeader)).height, theme.appBarTheme.toolbarHeight);
  });

  testWidgets('cancel sits at the leading edge, separate from the right-packed actions (issue #191)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: const Scaffold(
        body: HaloDialog(
          title: Text('Title'),
          content: Text('Body'),
          cancel: TextButton(onPressed: null, child: Text('Cancel')),
          actions: [FilledButton(onPressed: null, child: Text('Save'))],
        ),
      ),
    ));

    final cancelLeft = tester.getTopLeft(find.text('Cancel')).dx;
    final saveLeft = tester.getTopLeft(find.text('Save')).dx;

    // Not merely first among right-packed buttons: a real gap separates it
    // from Save, pinned to the opposite edge of the footer.
    expect(saveLeft - cancelLeft, greaterThan(150));
  });

  testWidgets('with no cancel, actions still pack to the trailing edge as before', (tester) async {
    await pump(tester, Brightness.light);
    final actionsRight = tester.getTopRight(find.text('OK')).dx;
    final cardRight = tester
        .getTopRight(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first)
        .dx;

    // OK hugs the card's own trailing edge (minus the footer's padding) —
    // unchanged from before `cancel` existed.
    expect(cardRight - actionsRight, lessThan(40));
  });

  testWidgets('header and footer are optional', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: const Scaffold(body: HaloDialog(content: Text('Body only'))),
    ));

    expect(find.text('Body only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
