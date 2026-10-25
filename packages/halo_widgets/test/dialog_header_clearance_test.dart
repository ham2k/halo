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
//
// All of that is the desktop rule, so those tests pin a desktop platform —
// a test runs as Android by default. A phone or tablet gets a plain margin
// inside its safe area instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const headerHeight = 48.0;
  const windowHeight = 800.0;
  const footerHeight = 24.0;
  const clearance = headerHeight - dialogHeaderOverlap;
  const statusBarHeight = 24.0;
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<BuildContext> pumpHost(WidgetTester tester, {double width = 900}) async {
    tester.view.physicalSize = Size(width, windowHeight);
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

  testWidgets('on a phone or tablet, a tall dialog keeps a plain margin inside the safe area', (tester) async {
    // No window controls to clear, and the safe area already keeps the card
    // off the status bar — the clearance arithmetic would instead count the
    // status bar as space below the route and sit the card on the footer.
    tester.view.padding = const FakeViewPadding(top: statusBarHeight);
    final context = await pumpHost(tester);
    unawaited(showHaloDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(card(tester).top, statusBarHeight + Space.xl);
    expect(card(tester).bottom, windowHeight - footerHeight - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on a phone or tablet, a tall Modal Pane keeps the same margin', (tester) async {
    tester.view.padding = const FakeViewPadding(top: statusBarHeight);
    final context = await pumpHost(tester);
    unawaited(showModalPane<void>(context, title: 'Tall', builder: (context) => const SizedBox(height: 5000)));
    await tester.pumpAndSettle();

    expect(card(tester).top, statusBarHeight + Space.xl);
    expect(card(tester).bottom, windowHeight - footerHeight - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on a phone with no safe area, the margin is still the plain one', (tester) async {
    // A landscape phone can have no status bar at all. The shared size cap
    // measured from the header would then bind before the frame does, and
    // the card would sit further from the edges than the margin.
    final context = await pumpHost(tester);
    unawaited(showHaloDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(card(tester).top, Space.xl);
    expect(card(tester).bottom, windowHeight - footerHeight - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on a phone, a dialog keeps the same plain margin at the sides', (tester) async {
    // A Dialog brings its own side inset; inside the frame it would add to
    // the margin rather than be it.
    const phoneWidth = 360.0;
    final context = await pumpHost(tester, width: phoneWidth);
    unawaited(showHaloDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(card(tester).left, Space.xl);
    expect(card(tester).right, phoneWidth - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on a tablet, a surface with no SafeArea of its own still keeps the margin inside the safe area', (tester) async {
    // showGeneralDialog brings no SafeArea, unlike showDialog and the Modal
    // Pane: a frame that assumed one would put the card under the status bar.
    tester.view.padding = const FakeViewPadding(top: statusBarHeight);
    final context = await pumpHost(tester);
    const surface = Key('surface');
    unawaited(
      showGeneralDialog<void>(
        context: context,
        pageBuilder: (context, _, _) => const HaloDialogFrame(child: SizedBox(key: surface, width: 300, height: 5000)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(surface)).top, statusBarHeight + Space.xl);
    expect(tester.getRect(find.byKey(surface)).bottom, windowHeight - footerHeight - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on a tablet, a tall top pane stops the plain margin above the bottom', (tester) async {
    // The desktop clearance is measured from the window's bottom edge, and
    // the footer and home indicator below the route can take more than that.
    tester.view.padding = const FakeViewPadding(top: statusBarHeight);
    final context = await pumpHost(tester);
    unawaited(showTopModalPane<void>(context, title: const Text('Tall'), builder: (context) => const SizedBox(height: 5000)));
    await tester.pumpAndSettle();

    expect(card(tester).top, statusBarHeight + headerHeight);
    expect(card(tester).bottom, windowHeight - footerHeight - Space.xl);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
  }, variant: desktop);

  testWidgets('a tall dialog from a bare showDialog keeps the same clearance from the header', (tester) async {
    // Material's own 24px inset would put this card halfway up the header.
    // Its bottom is a theme inset from the ROUTE's edge, above the footer.
    final context = await pumpHost(tester);
    unawaited(showDialog<void>(context: context, builder: tallDialog));
    await tester.pumpAndSettle();

    expect(cardTop(tester), clearance);
  }, variant: desktop);

  testWidgets('a tall Modal Pane keeps the same clearance at both ends', (tester) async {
    final context = await pumpHost(tester);
    unawaited(showModalPane<void>(context, title: 'Tall', builder: (context) => const SizedBox(height: 5000)));
    await tester.pumpAndSettle();

    expect(card(tester).top, clearance);
    expect(card(tester).bottom, windowHeight - clearance);
  }, variant: desktop);

  testWidgets('a tall top pane hangs from the header and stops the same clearance above the bottom edge', (tester) async {
    // It starts below the header rather than over it, so only its bottom
    // answers to the clearance; half a header there puts it under a footer
    // any taller than that.
    final context = await pumpHost(tester);
    unawaited(showTopModalPane<void>(context, title: const Text('Tall'), builder: (context) => const SizedBox(height: 5000)));
    await tester.pumpAndSettle();

    expect(card(tester).top, headerHeight);
    expect(card(tester).bottom, windowHeight - clearance);
  }, variant: desktop);

  testWidgets('a date range picker keeps the same clearance at both ends', (tester) async {
    // Its calendar is a Dialog with no inset at all, sized to the window:
    // without the frame it covers the header and the window controls in it.
    final context = await pumpHost(tester);
    unawaited(showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2030), builder: haloPickerFrame));
    await tester.pumpAndSettle();

    final picker = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
    expect(picker.top, clearance);
    expect(picker.bottom, windowHeight - clearance);
  }, variant: desktop);

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
  }, variant: desktop);
}
