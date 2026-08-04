// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host(List<StatusBarItemData> items) => MaterialApp(
        home: Scaffold(
          body: StatusBarFooter(items: items, onDismiss: (_) {}),
        ),
      );

  StatusBarItemData item(String key) => StatusBarItemData(key: key, title: key, text: key);

  Widget noticeHost(String text) => MaterialApp(
        home: Scaffold(
          body: NoticeStack(
            notices: [StatusBarNoticeData(key: 'n', title: 'Heads up', text: text, createdAt: DateTime(2026))],
            onDismiss: (_) {},
          ),
        ),
      );

  testWidgets(
    'collapsed AnimatedSwitcher survives the item count oscillating within '
    'one transition window (e.g. two overlapping data-file syncs)',
    (tester) async {
      // AnimatedSwitcher keeps every not-yet-dismissed outgoing child around,
      // and only filters out the one that matches the *current* key. Cycling
      // the derived key A -> B -> A -> B within a single 200ms transition
      // window produces two distinct outgoing entries that both carry key A
      // at the same time (neither matches the current key B), which used to
      // throw a duplicate-key error when the key was derived directly from
      // `(last.key, items.length)` — both of which can repeat.
      await tester.pumpWidget(host([item('dataFile:a')])); // key "dataFile:a|1"
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(host([item('dataFile:a'), item('dataFile:b')])); // key "dataFile:b|2"
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(host([item('dataFile:a')])); // key "dataFile:a|1" again
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(host([item('dataFile:a'), item('dataFile:b')])); // key "dataFile:b|2" again
      await tester.pump(const Duration(milliseconds: 30));

      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a progress item gives its bar at most half the row and left-aligns the title',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host([const StatusBarItemData(key: 'sync', title: 'Syncing data files', progressValue: 0.5)]),
      );
      await tester.pumpAndSettle();

      // The bar never spans more than half the (ideal-width) message.
      final bar = tester.getSize(find.byType(LinearProgressIndicator));
      expect(bar.width, lessThanOrEqualTo(idealPaneWidth / 2));

      final title = tester.widget<Text>(find.text('Syncing data files'));
      expect(title.textAlign, TextAlign.left);
    },
  );

  testWidgets(
    'a status message is capped at the ideal pane width and centered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(host([const StatusBarItemData(key: 'msg', title: 'A plain status message')]));
      await tester.pumpAndSettle();

      // The message sits inside the centered ideal-width band, not spanning
      // the full 1200px window.
      final textRect = tester.getRect(find.text('A plain status message'));
      expect(textRect.left, greaterThanOrEqualTo((1200 - idealPaneWidth) / 2));
      expect(textRect.right, lessThanOrEqualTo((1200 + idealPaneWidth) / 2));
    },
  );

  testWidgets(
    'a notice card is capped at the ideal pane width and centered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(noticeHost('A notice body'));
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(NoticeCard).first);
      expect(cardRect.width, lessThanOrEqualTo(idealPaneWidth + 0.5));
      expect(cardRect.center.dx, closeTo(600, 1)); // centered in the 1200px window
    },
  );

  testWidgets(
    'the expanded status list is capped at 40% of the screen height',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Far more rows than 40% of the screen can hold, so the cap bites.
      await tester.pumpWidget(host([for (var i = 0; i < 20; i++) item('msg:$i')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(StatusBarFooter)); // >1 item => expandable
      await tester.pumpAndSettle();

      final screenHeight = MediaQuery.of(tester.element(find.byType(ListView))).size.height;
      expect(tester.getSize(find.byType(ListView)).height, closeTo(screenHeight * 0.4, 1));
    },
  );

  testWidgets(
    'a tall notice is capped at 40% of the screen height and scrolls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(noticeHost(List.filled(200, 'A long line of notice text.').join('\n\n')));
      await tester.pumpAndSettle();

      // The overflowing body stays reachable by scrolling rather than blowing
      // the layout. The 40% bounds the whole STACK — the band around the card
      // included — so the card's own viewport is that much shorter. It used to
      // bound the card, which left the stack 20pt over whatever it was given
      // and overran a tight budget by exactly that.
      const bandHeight = NoticeStack.bandHeight;
      final viewport = find.byType(SingleChildScrollView).first;
      final screenHeight = MediaQuery.of(tester.element(viewport)).size.height;
      expect(tester.getSize(viewport).height, closeTo(screenHeight * 0.4 - bandHeight, 1));
    },
  );

  testWidgets(
    'an empty footer collapses to nothing, so the screen content behind it '
    'fills the bottom safe area with its own colour instead of one footer '
    'colour being imposed over every screen',
    (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 102); // 34 logical px
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetDevicePixelRatio);

      // In the real status-bar overlay the footer is the last child of a
      // Column whose Expanded screen sits above it; collapsing to zero lets
      // that screen (its Scaffold, Quick Lookup, or split panes) paint the
      // safe area itself, so the home-indicator strip matches the screen.
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              const Expanded(child: SizedBox.shrink()),
              StatusBarFooter(items: const [], onDismiss: _noop),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byType(StatusBarFooter)).height, 0);
    },
  );
}

void _noop(String _) {}
