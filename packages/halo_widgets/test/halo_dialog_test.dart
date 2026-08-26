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
  // The footer's full width. `find.byType(OverflowBar)` is only the TRAILING
  // group now — destructive sits outside it — so measuring edges against the
  // bar would compare a button to the group it is deliberately not in.
  Finder footerRow() => find.ancestor(of: find.byType(OverflowBar), matching: find.byType(Row)).first;
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

  testWidgets('a row inset captured from the calling pane does not reach the dialog', (tester) async {
    // The trap: `showDialog` re-installs the inherited themes in force where
    // it was called, and a settings pane's ambient ListTileTheme carries its
    // centring offset — so the dialog's own rows indent by a settings pane's
    // width unless the shell puts the row theme back.
    //
    // Measured against the SAME dialog opened with nothing ambient, not
    // against a threshold: the fix has to leave every dialog that never had a
    // theme to inherit exactly where it was, and a bound that only rules out
    // the 220px leak would pass for any inset this shell invented instead.
    Future<double> rowLeft({EdgeInsets? ambient}) async {
      Widget app = MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showHaloDialog<void>(
              context: context,
              builder: (_) => const HaloDialog(
                title: Text('T'),
                wide: true,
                content: ListTile(title: Text('a row')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      if (ambient != null) app = ListTileTheme.merge(contentPadding: ambient, child: app);
      await tester.pumpWidget(app);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
      final left = tester.getRect(find.text('a row')).left - card.left;
      // Dismiss, or the next open taps this dialog's barrier instead.
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      return left;
    }

    expect(
      await rowLeft(ambient: const EdgeInsets.symmetric(horizontal: 220)),
      await rowLeft(),
    );
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

  testWidgets('cancel joins the trailing group, one deliberate gap short of the primary', (tester) async {
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

    final cancel = tester.getRect(find.text('Cancel'));
    final save = tester.getRect(find.text('Save'));
    // The footer's own box, not the dialog's: the Dialog fills the window, so
    // measuring against it compares button positions to the screen rather
    // than to the space the footer actually lays out in.
    final footer = tester.getRect(footerRow());

    // Cancel is immediately left of the primary, per Material.
    expect(cancel.right, lessThan(save.left));
    // And nowhere near the leading edge: pinning Cancel there instead leaves
    // this distance at the footer's padding alone, so that layout fails here
    // rather than merely looking different.
    expect(cancel.left - footer.left, greaterThan(100));

    // The gap between them is the app's one divergence from Material, so it
    // is asserted as a real distance rather than left to look right. Measured
    // between the LABELS, so it carries the buttons' own padding too — the
    // floor only has to prove the deliberate gap is there and larger than the
    // Space.md separating ordinary neighbours.
    expect(save.left - cancel.right, greaterThan(haloDialogCancelGap));
  });

  testWidgets('destructive stays alone at the leading edge, far from the primary', (tester) async {
    // `wide`, because four verbs do not fit a compact dialog and the footer
    // correctly STACKS instead — see the test below, which covers that case.
    // This one is about the side-by-side order, so it needs the room for it.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: const Scaffold(
        body: HaloDialog(
          wide: true,
          title: Text('Title'),
          content: Text('Body'),
          destructive: TextButton(onPressed: null, child: Text('Remove')),
          secondary: TextButton(onPressed: null, child: Text('Report')),
          cancel: TextButton(onPressed: null, child: Text('Cancel')),
          actions: [FilledButton(onPressed: null, child: Text('Save'))],
        ),
      ),
    ));

    final remove = tester.getRect(find.text('Remove'));
    final report = tester.getRect(find.text('Report'));
    final cancel = tester.getRect(find.text('Cancel'));
    final save = tester.getRect(find.text('Save'));
    final footer = tester.getRect(footerRow());
    final trailingGroup = tester.getRect(find.byType(OverflowBar));

    // A verb that destroys the operator's work sits at the leading edge, as
    // far from Save as the row allows — the whole reason it is a slot and not
    // just another action. It is outside the trailing group entirely.
    expect(remove.left - footer.left, lessThan(20));
    expect(remove.right, lessThanOrEqualTo(trailingGroup.left));
    // Order within the trailing group: secondary, cancel, then the primary.
    // Cancel stays immediately beside Save so the gap separates that pair and
    // not some other one.
    expect(report.right, lessThan(cancel.left));
    expect(cancel.right, lessThan(save.left));
    // The wide gap belongs to the cancel/primary pair specifically, not to
    // every neighbour in the group: secondary sits at the ordinary spacing.
    expect(save.left - cancel.right, greaterThan(cancel.left - report.right));
  });

  testWidgets('a footer with only a primary keeps it at the trailing edge', (tester) async {
    // spaceBetween aligns a lone child to the START, so the empty leading
    // placeholder is load-bearing: without it every footer that has no
    // destructive action — nearly all of them — throws its buttons to the
    // wrong edge.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: const Scaffold(
        body: HaloDialog(
          title: Text('Title'),
          content: Text('Body'),
          actions: [FilledButton(onPressed: null, child: Text('Done'))],
        ),
      ),
    ));

    final done = tester.getRect(find.text('Done'));
    final footer = tester.getRect(footerRow());
    // The label sits one button-padding in from the footer's trailing edge,
    // i.e. the button itself is flush with it.
    expect(footer.right - done.right, lessThan(32));
  });

  testWidgets('a cancel-only footer aligns to the same edge as a primary-only one', (tester) async {
    // The gap belongs BETWEEN cancel and the primary. Emitted when there is no
    // primary it becomes trailing padding inside a min-width Row, and every
    // dialog whose one button is Done — most of the ones this convention
    // creates — sits a gap's width short of where every other footer's button
    // lands. Measured against the actions-only case rather than a constant, so
    // the two shapes are held to each other.
    Future<double> inset({required bool useCancelSlot}) async {
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(useCancelSlot),
        theme: buildHaLoTheme(Brightness.light),
        home: Scaffold(
          body: HaloDialog(
            title: const Text('T'),
            content: const Text('B'),
            cancel: useCancelSlot ? const TextButton(onPressed: null, child: Text('Done')) : null,
            actions: useCancelSlot ? const [] : const [TextButton(onPressed: null, child: Text('Done'))],
          ),
        ),
      ));
      final button = tester.getRect(find.widgetWithText(TextButton, 'Done'));
      return tester.getRect(footerRow()).right - button.right;
    }

    expect(await inset(useCancelSlot: true), await inset(useCancelSlot: false));
  });

  testWidgets('four verbs on a compact dialog stack instead of overflowing', (tester) async {
    // The fallback the OverflowBar exists for: a Row would paint red stripes
    // across the primary action rather than give ground. The groups stack,
    // trailing edge aligned, so the primary stays where the thumb expects it.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: const Scaffold(
        body: HaloDialog(
          title: Text('Title'),
          content: Text('Body'),
          destructive: TextButton(onPressed: null, child: Text('Remove')),
          secondary: TextButton(onPressed: null, child: Text('Report')),
          cancel: TextButton(onPressed: null, child: Text('Cancel')),
          actions: [FilledButton(onPressed: null, child: Text('Save'))],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final remove = tester.getRect(find.text('Remove'));
    final save = tester.getRect(find.text('Save'));
    // Deliberately also covered WITHOUT a destructive, below: a footer whose
    // leading slot is empty is the shape almost every dialog has, and it is
    // the one where an OverflowBar handed a pre-grouped Row silently stops
    // stacking — the Row clamps itself to maxWidth and reports that it fits.
    // Stacked, not side by side: the destructive group is on its own line
    // above the trailing group.
    expect(remove.bottom, lessThanOrEqualTo(save.top));
    // Still trailing-aligned, so Save has not wandered to the leading edge.
    final footer = tester.getRect(footerRow());
    expect(footer.right - save.right, lessThan(32));
  });

  testWidgets('a footer with no destructive still stacks rather than overflowing', (tester) async {
    // The configuration almost every dialog has, and the one a grouped-Row
    // footer cannot stack at all: with the leading slot empty the bar sees a
    // single child that has clamped itself to maxWidth, concludes it fits, and
    // lets it paint red stripes instead.
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 220,
            child: haloDialogFooterRow(
              cancel: const TextButton(onPressed: null, child: Text('Cancelar')),
              actions: const [FilledButton(onPressed: null, child: Text('Guardar operación'))],
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull, reason: 'a footer this narrow must stack, not overflow');
    final cancel = tester.getRect(find.text('Cancelar'));
    final save = tester.getRect(find.text('Guardar operación'));
    expect(cancel.center.dy, isNot(save.center.dy));
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
