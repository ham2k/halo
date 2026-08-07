// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
    'item changes move the footer\'s semantics LABEL without changing the shape of its tree',
    (tester) async {
      // The invariant this pins, and why it is not cosmetic: on web the engine
      // gives every semantics node a DOM element chosen by its ROLE, and
      // disposes that element the moment the role changes ("Role changed. This
      // should be avoided as much as possible" — the engine's own comment in
      // semantics.dart). The framework recycles SemanticsNodes as the tree
      // churns, so a footer that creates and destroys nodes on every item
      // frees them to be handed to some other widget — and when the node
      // handed on is the one hosting a FOCUSED TEXT FIELD, the engine disposes
      // its `<input>` and the operator's keystrokes stop arriving mid-word,
      // with the caret still blinking as if nothing were wrong.
      //
      // So the footer may say something different; it may not grow or lose
      // nodes. What moves with the item count and is deliberately not pinned
      // here: the tap action the expand affordance contributes once a second
      // item makes the list expandable. That changes the node's actions and
      // flags, not the set of nodes, and the engine picks a node's DOM element
      // by role — which a bare tap does not change.
      final handle = tester.ensureSemantics();

      int nodeCount() {
        var total = 0;
        void walk(SemanticsNode node) {
          total++;
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
        return total;
      }

      await tester.pumpWidget(host([item('dataFile:a')]));
      await tester.pumpAndSettle();
      final before = nodeCount();
      expect(
        tester.getSemantics(find.byType(StatusBarFooter)).label,
        'dataFile:a',
        reason: 'the message has to reach assistive tech from the stable node, not the animated row',
      );

      // A different item, a different count, a different switcher key — the
      // whole visual row is torn down and rebuilt here.
      await tester.pumpWidget(host([item('dataFile:a'), item('dataFile:b')]));
      await tester.pumpAndSettle();

      expect(nodeCount(), before, reason: 'an item change must not add or remove semantics nodes');
      expect(tester.getSemantics(find.byType(StatusBarFooter)).label, 'dataFile:b');
      // A count alone is satisfied just as well by "the control has no node at
      // all" as by "it has one that survives" — and putting the dismiss button
      // back inside the excluded switcher passes every other assertion here
      // while making the footer's only control invisible to assistive tech.
      expect(
        find.bySemanticsLabel('Dismiss'),
        findsOneWidget,
        reason: 'the one control down here keeps its own node across item changes',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'the notice peeking behind the top one is seen and not heard',
    (tester) async {
      // The peek is a few pixels of card edge saying "there is another one".
      // Neither wrapper around it keeps it out of the semantics tree —
      // IgnorePointer defaults `ignoringSemantics` to null (read as false) and
      // 0.7 opacity is not zero — so without an explicit exclusion assistive
      // tech is read the SECOND notice in full, ahead of the one on top, plus
      // a close button deliberately wired to a no-op. It is churn as well:
      // a card's worth of nodes appearing and vanishing as notices stack, and
      // freed nodes get recycled onto other widgets — on web, onto a focused
      // text field, whose `<input>` the engine then disposes mid-word.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoticeStack(
            notices: [
              StatusBarNoticeData(key: 'older', title: 'Older', text: 'the one underneath', createdAt: DateTime(2026)),
              StatusBarNoticeData(key: 'newer', title: 'Newer', text: 'the one on top', createdAt: DateTime(2026, 1, 2)),
            ],
            onDismiss: (_) {},
            dismissLabel: 'Dismiss',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Both cards are built — the peek is visible, and the invisible ghost
      // sizes the stack — so this is really about what is ANNOUNCED.
      expect(find.text('the one underneath'), findsWidgets);

      expect(
        find.bySemanticsLabel('the one underneath'),
        findsNothing,
        reason: 'the stacked notice is decoration until it reaches the top',
      );
      expect(find.bySemanticsLabel('the one on top'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Dismiss'),
        findsOneWidget,
        reason: 'one real close button — not the peek\'s no-op copy, nor the ghost\'s',
      );

      handle.dispose();
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

  testWidgets(
    'under the dark theme the notice is still black ink on post-it yellow, '
    'markdown roles included',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildHaLoTheme(Brightness.dark),
        home: Scaffold(
          body: NoticeCard(
            notice: StatusBarNoticeData(
              key: 'n',
              title: 'Heads up',
              text: '# Head\n\nBody `code` [link](x)',
              createdAt: DateTime(2026),
            ),
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final paper = tester
          .widgetList<Material>(find.descendant(of: find.byType(NoticeCard), matching: find.byType(Material)))
          .first;
      expect(paper.color, const Color(0xFFFCF4A7));

      // Every markdown role has to be pinned, not just `p`: the rest of
      // MarkdownStyleSheet.fromTheme is derived from the ambient (here dark)
      // surface, so a heading or an inline code span would render near-white
      // on the yellow paper and be unreadable.
      final sheet = tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;
      const ink = Color(0xFF15140A);
      expect(sheet.p!.color, ink);
      expect(sheet.h1!.color, ink);
      expect(sheet.code!.color, ink);
      expect(sheet.blockquote!.color, ink);
      expect(sheet.listBullet!.color, ink);
      // Links stay a distinct color, but one that reads on yellow rather than
      // fromTheme's mid-blue. Color and nothing else: the markdown builder
      // merges the link style onto its parent and `merge` takes every non-null
      // field, so a body-derived style here shrinks the `# Head` above to body
      // size the moment a link appears inside a heading or a bold run.
      expect(sheet.a!.color, Colors.blue.shade900);
      expect(sheet.a!.fontSize, isNull);
      expect(sheet.a!.fontWeight, isNull);

      // The dismiss button's state layer follows its foregroundColor; left to
      // the ambient dark theme it is a near-white wash, invisible on yellow.
      final dismiss = tester.widget<IconButton>(find.byType(IconButton));
      expect(dismiss.style?.foregroundColor?.resolve({}), ink);

      final title = tester.widget<Text>(find.text('Heads up'));
      expect(title.style!.color, ink);
    },
  );
}

void _noop(String _) {}
