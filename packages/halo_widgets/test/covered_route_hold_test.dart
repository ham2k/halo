// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Counts how many rows of the background list have been disposed.
class _Row extends StatefulWidget {
  final int index;
  final List<int> disposed;

  const _Row({required this.index, required this.disposed});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  void dispose() {
    widget.disposed.add(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: 60, child: Text('Row ${widget.index}'));
}

void main() {
  const keyboard = 300.0;

  /// The app shell's shape, cut down to what matters here: the keyboard's
  /// inset shrinks the whole Navigator and is removed from what the routes
  /// read.
  Widget shell(Widget home) => MaterialApp(
    theme: buildHaLoTheme(Brightness.light),
    builder: (context, child) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(context: context, removeBottom: true, child: child!),
    ),
    home: home,
  );

  Widget page(List<int> disposed) => Scaffold(
    key: const Key('page'),
    body: Column(
      children: [
        const TextField(key: Key('page-field')),
        Expanded(
          child: ListView.builder(
            // No cache beyond the viewport, so a shorter page drops rows at once.
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            itemCount: 100,
            itemBuilder: (context, i) => _Row(index: i, disposed: disposed),
          ),
        ),
      ],
    ),
  );

  /// Opens a covering route with [open], focuses its field and raises the
  /// keyboard.
  Future<void> coverWithKeyboard(WidgetTester tester, void Function(BuildContext page) open) async {
    open(tester.element(find.byKey(const Key('page'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('covering-field')));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();
  }

  const coveringField = Material(child: TextField(key: Key('covering-field')));

  void openDialog(BuildContext page) => unawaited(showHaloDialog<void>(context: page, builder: (_) => coveringField));

  /// A tall lazy list, to put under a covering route in each route type the
  /// hold is wired into — the page itself, through the theme.
  Widget rows(List<int> disposed) => ListView.builder(
    key: const Key('covered'),
    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
    itemCount: 100,
    itemBuilder: (context, i) => _Row(index: i, disposed: disposed),
  );

  final coveredRoutes = <String, void Function(BuildContext page, List<int> disposed)>{
    'a Modal Pane': (page, disposed) => unawaited(showModalPane<void>(page, scrollable: false, builder: (_) => rows(disposed))),
    'a top Modal Pane': (page, disposed) => unawaited(showTopModalPane<void>(page, scrollable: false, builder: (_) => rows(disposed))),
    'a dialog': (page, disposed) => unawaited(
      showHaloDialog<void>(
        context: page,
        builder: (_) => Material(child: SizedBox(height: 500, child: rows(disposed))),
      ),
    ),
  };

  testWidgets('a dialog\'s keyboard leaves the page behind it unlaid-out', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    await tester.pumpWidget(shell(page(disposed)));
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;

    await coverWithKeyboard(tester, openDialog);

    // The trap: the shell shrinks every route, so without the hold the page
    // is laid out again and its lazy list disposes the rows that fall off
    // the bottom — any disposal with side effects then runs under the
    // covering route (an AutofillGroup finishing the context closes the iOS
    // keyboard).
    expect(disposed, isEmpty, reason: 'no row of the covered page may be disposed by the covering route\'s keyboard');
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight, reason: 'the covered page keeps its height');
  });

  for (final MapEntry(key: name, value: openCovered) in coveredRoutes.entries) {
    testWidgets('$name under a dialog\'s keyboard is not laid out again', (tester) async {
      addTearDown(tester.view.reset);
      final pageRows = <int>[];
      final disposed = <int>[];
      await tester.pumpWidget(shell(page(pageRows)));
      openCovered(tester.element(find.byKey(const Key('page'))), disposed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('covered')), findsOneWidget);

      // Opened from the covered route, so the dialog stacks above it.
      await coverWithKeyboard(tester, (_) => openDialog(tester.element(find.byKey(const Key('covered')))));

      expect(disposed, isEmpty, reason: '$name must hold its size under another route\'s keyboard');
    });
  }

  testWidgets('a page whose own field has the keyboard shrinks above it', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    await tester.pumpWidget(shell(page(disposed)));
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;

    await tester.tap(find.byKey(const Key('page-field')));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();

    // Holding every route would put the page's own bottom — and whatever
    // the operator is typing into — behind the keyboard.
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight - keyboard);
  });

  testWidgets('closing a dialog before its keyboard goes leaves the page unlaid-out', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    await tester.pumpWidget(shell(page(disposed)));
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;
    await coverWithKeyboard(tester, openDialog);

    // The usual order on a phone: a button closes the dialog while its field
    // still has the keyboard, which animates down afterwards. The page
    // becomes current at the pop, so a hold that ended there would shrink it
    // under the fading dialog and drop its rows anyway.
    Navigator.of(tester.element(find.byKey(const Key('covering-field')))).pop();
    await tester.pumpAndSettle();
    expect(disposed, isEmpty, reason: 'the pop must not end the hold while the keyboard is still up');
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight);
    expect(disposed, isEmpty);
  });

  testWidgets('a field drawn above the Navigator leaves the current page unlaid-out', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    // Onboarding's shape: its own Overlay over the routes, so the page under
    // it is still the CURRENT route while its keyboard is up.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        builder: (context, child) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Stack(
              children: [
                child!,
                Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => const Align(alignment: Alignment.topCenter, child: coveringField),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        home: page(disposed),
      ),
    );
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;
    await tester.tap(find.byKey(const Key('covering-field')));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();

    expect(disposed, isEmpty, reason: 'a page that does not hold the focus holds its size, current route or not');
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight);
  });

  testWidgets('a page whose focus rests on a bare nested scope holds through a dialog closed before its keyboard goes', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    // The logging panel's shape: its fields sit in a FocusScope of their
    // own, and a field letting go leaves the focus on that scope.
    await tester.pumpWidget(
      shell(
        Scaffold(
          key: const Key('page'),
          body: Column(
            children: [
              const FocusScope(child: TextField(key: Key('scoped-field'))),
              Expanded(
                child: ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                  itemCount: 100,
                  itemBuilder: (context, i) => _Row(index: i, disposed: disposed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;
    await tester.tap(find.byKey(const Key('scoped-field')));
    await tester.pump();
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

    await coverWithKeyboard(tester, openDialog);
    Navigator.of(tester.element(find.byKey(const Key('covering-field')))).pop();
    await tester.pumpAndSettle();

    // The pop hands the focus back to the nested scope, which types nothing:
    // counting it as the page's own would shrink the page under the fading
    // dialog.
    expect(disposed, isEmpty);
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight);
  });

  testWidgets('a dialog that hands the focus back to a page field lets the page shrink', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    await tester.pumpWidget(shell(page(disposed)));
    final pageHeight = tester.getSize(find.byKey(const Key('page'))).height;
    await tester.tap(find.byKey(const Key('page-field')));
    await tester.pump();
    await coverWithKeyboard(tester, openDialog);

    // The route restores the focus to the field it had, which keeps the
    // keyboard: the page is typed into again, so its bottom must come out
    // from behind the keyboard rather than wait for a keyboard that stays.
    Navigator.of(tester.element(find.byKey(const Key('covering-field')))).pop();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>()?.key, const Key('page-field'));
    expect(tester.getSize(find.byKey(const Key('page'))).height, pageHeight - keyboard);
  });

  testWidgets('a width change drops the held height', (tester) async {
    addTearDown(tester.view.reset);
    final disposed = <int>[];
    await tester.pumpWidget(shell(page(disposed)));
    await coverWithKeyboard(tester, openDialog);

    // A rotation while held: the height remembered belongs to the old width,
    // and laying the new width out at it puts the page's content wherever
    // that other layout had it.
    tester.view.physicalSize = Size(tester.view.physicalSize.height, tester.view.physicalSize.width);
    await tester.pumpAndSettle();
    final offered = tester.view.physicalSize.height / tester.view.devicePixelRatio - keyboard;
    expect(tester.getSize(find.byKey(const Key('page'))).height, offered);
  });
}
