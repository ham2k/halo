// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A card floating over the window may overlap the header by
// [dialogHeaderOverlap] and no more: the window controls (macOS traffic
// lights, Windows caption buttons) live in that header. It stops the same
// distance above the window's bottom edge. Each way of opening one is
// checked, because each reaches its position differently — the shared frame,
// a bare Dialog's theme inset, a Modal Pane's own card — and the frame and
// the inset stack if both apply.
//
// The host draws a footer band BELOW the Navigator, as the app's status
// footer is: routes stop above it while MediaQuery reports the whole window,
// and a card merely centered in its route sits half the band too high.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const headerHeight = 48.0;
  const windowHeight = 800.0;
  const footerHeight = 24.0;
  const clearance = headerHeight - dialogHeaderOverlap;

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, windowHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        builder: (context, navigator) => Column(
          children: [
            Expanded(child: navigator!),
            const SizedBox(height: footerHeight),
          ],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  Widget tallDialog(BuildContext context) => const HaloDialog(title: Text('Tall'), content: SizedBox(height: 5000));

  double cardTop(WidgetTester tester) => tester.getTopLeft(find.byType(HaloDialogHeader)).dy;

  /// The Dialog's card, or the Modal Pane's — the Material holding the header.
  Rect card(WidgetTester tester) => tester.getRect(find.ancestor(of: find.byType(HaloDialogHeader), matching: find.byType(Material)).first);

  test('the header is the height these tests assume', () {
    expect(buildHaLoTheme(Brightness.light).appBarTheme.toolbarHeight, headerHeight);
  });

  testWidgets('a tall showHaloDialog reaches the header by exactly the overlap, and the bottom edge by the same', (tester) async {
    // Without the inset zeroed inside the frame, the frame's clearance and
    // the Dialog's inset add up and the card stops well short of the header.
    final context = await pumpHost(tester);
    unawaited(showHaloDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(card(tester).top, clearance);
    expect(card(tester).bottom, windowHeight - clearance);
  });

  testWidgets('a tall dialog from a bare showDialog keeps the same clearance from the header', (tester) async {
    // Material's own 24px inset would put this card halfway up the header.
    // Its bottom is a theme inset from the ROUTE's edge, above the footer.
    final context = await pumpHost(tester);
    unawaited(showDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(cardTop(tester), clearance);
  });

  testWidgets('a tall Modal Pane keeps the same clearance at both ends', (tester) async {
    final context = await pumpHost(tester);
    unawaited(showModalPane<void>(context, title: 'Tall', builder: (context) => const SizedBox(height: 5000)));
    await tester.pumpAndSettle();

    expect(card(tester).top, clearance);
    expect(card(tester).bottom, windowHeight - clearance);
  });

  testWidgets('a short dialog stays centered, clear of the header', (tester) async {
    // The clearance is a limit, not a position: a short card must not be
    // pinned up against the header.
    final context = await pumpHost(tester);
    unawaited(
      showHaloDialog<void>(
        context: context,
        builder: (context) => const HaloDialog(title: Text('Short'), content: Text('Body')),
      ),
    );
    await tester.pumpAndSettle();

    expect(card(tester).top, greaterThan(headerHeight));
    expect(card(tester).center.dy, closeTo(windowHeight / 2, 1));
  });
}
