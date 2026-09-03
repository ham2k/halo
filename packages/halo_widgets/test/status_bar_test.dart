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

  testWidgets('the COLLAPSED footer shows an item\'s title and never its text', (tester) async {
    // The contract a caller has to write to: the collapsed footer is the
    // always-visible surface and it renders `title ?? text`, so anything a
    // caller puts in `text` alone is invisible until the bar is expanded. A
    // fixed title with the changing part in `text` therefore reads as a static
    // label — see HaLoServices._refreshTimeTravelStatus, which puts a whole
    // one-line message in the title for exactly this reason. If this behaviour
    // is ever changed to show both, that caller can be simplified.
    await tester.pumpWidget(host([
      const StatusBarItemData(key: 'k', title: 'The title', text: 'the detail'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('The title'), findsOneWidget);
    expect(find.text('the detail'), findsNothing);
  });

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

  testWidgets('the icons open a menu of every status, and choosing one runs its action', (tester) async {
    // The statuses are NOT in the footer's expandable list — that surface is
    // the messages'. One menu for the whole group, whichever icon opened it:
    // an operator who taps the cloud to ask about the network is not asking
    // to be shown only the network.
    var ran = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [],
              onDismiss: _noop,
              perma: [
                StatusBarPermaData(key: 'net', icon: Icons.cloud_off, text: 'Offline', onTap: () => ran++),
                const StatusBarPermaData(key: 'radio', icon: Icons.radio, text: 'Fake Radio: Connected'),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsNothing, reason: 'the collapsed bar shows glyphs, not lines');

    // The RADIO icon, and the menu still lists both.
    await tester.tap(find.byIcon(Icons.radio));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Fake Radio: Connected'), findsOneWidget);

    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    expect(ran, 1);
    expect(find.text('Offline'), findsNothing, reason: 'choosing an entry closes the menu');
  });

  testWidgets('a badge rides beside the icon in the collapsed bar, dimmed when the status is muted', (tester) async {
    // The count is what the collapsed bar is FOR here: the line behind it
    // ("3 of 5 connected") only exists in the menu, so a badge that failed to
    // render would leave the operator a glyph that answers nothing, with the
    // menu still passing every other test in this file.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [],
              onDismiss: _noop,
              perma: const [
                StatusBarPermaData(key: 'peers', icon: Icons.lan, text: '2 of 5 connected', badge: '2'),
                StatusBarPermaData(
                  key: 'quiet',
                  icon: Icons.cloud_off,
                  text: '0 of 3 connected',
                  badge: '0',
                  muted: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2 of 5 connected'), findsNothing, reason: 'the line stays in the menu');

    // The mute has to reach the glyph AND its badge: dimming one of the two
    // reads as a rendering fault rather than as a status standing down.
    Color colorOf(Finder icon) => tester.widget<Icon>(icon).color!;
    final live = colorOf(find.byIcon(Icons.lan));
    final quiet = colorOf(find.byIcon(Icons.cloud_off));
    expect(quiet.a, lessThan(live.a), reason: 'a muted status is held back, not hidden');
    expect(tester.widget<Text>(find.text('0')).style!.color!.a, quiet.a);
    expect(tester.widget<Text>(find.text('2')).style!.color!.a, live.a);
  });

  testWidgets('the icons open the menu and the bar opens the message list, never each other', (tester) async {
    // Two surfaces, two gestures. The bar must not open the statuses and the
    // icons must not open the messages — and the icons ride ON the bar, so
    // they have to take their taps before it does.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [
                StatusBarItemData(key: 'a', title: 'Syncing'),
                StatusBarItemData(key: 'b', title: 'Downloading'),
              ],
              onDismiss: _noop,
              perma: const [StatusBarPermaData(key: 'net', icon: Icons.cloud_off, text: 'Offline')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.cloud_off));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Syncing'), findsNothing, reason: 'the menu carries no messages');

    // Away from the icons: the bar itself, which opens the list. Two taps,
    // because the first is eaten closing the menu (`consumeOutsideTap`) — so
    // the assertion below that the menu is gone would pass on that alone, and
    // the one that the list is open is what this is really checking.
    await tester.tapAt(tester.getCenter(find.byType(StatusBarFooter)));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(StatusBarFooter)));
    await tester.pumpAndSettle();
    expect(find.text('Syncing'), findsOneWidget);
    expect(find.text('Offline'), findsNothing, reason: 'the list carries no statuses');
  });

  testWidgets('an expanded row takes taps only in the middle, and the margins collapse the bar', (tester) async {
    // The window is wider than `idealPaneWidth`, so the rows run edge to edge
    // while their writing sits in a 500pt column in the middle. An InkWell
    // wrapped around the whole row would swallow the margins either side —
    // and those belong to the bar: a tap on anything that is not a message
    // means "put this list away", not "run whatever that line does".
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [
                StatusBarItemData(key: 'a', title: 'Syncing'),
                StatusBarItemData(key: 'b', title: 'Downloading'),
              ],
              onDismiss: _noop,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(StatusBarFooter)));
    await tester.pumpAndSettle();
    expect(find.text('Syncing'), findsOneWidget, reason: 'the bar opened the list');

    final open = tester.getRect(find.byType(StatusBarFooter));
    await tester.tapAt(Offset(open.left + Space.xs, open.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Syncing'), findsNothing, reason: 'the margin is the bar, not the row');
  });

  testWidgets('an expanded row\'s tap target is a semantics node of its own size', (tester) async {
    // The same contract as the tap test above, on the path that does not hit
    // test at all. An InkWell's `Semantics` merges UP, and the node above it
    // in a list is the full-width per-row one — so without a container of its
    // own, the row's action lands on a node spanning the whole row and every
    // assistive activation of it (VoiceOver, TalkBack, and Flutter web's DOM
    // element per node, which takes the click before the framework sees a
    // pointer at all) runs it from the margins.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [
                StatusBarItemData(key: 'a', title: 'Syncing'),
                StatusBarItemData(key: 'b', title: 'Downloading'),
              ],
              onDismiss: _noop,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(StatusBarFooter)));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.text('Syncing'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      node.rect.width,
      lessThan(tester.getSize(find.byType(StatusBarFooter)).width),
      reason: 'the tap action must not cover the margins that collapse the bar',
    );

    semantics.dispose();
  });

  testWidgets('a permanent status opens the bar on its own', (tester) async {
    // The whole reason a permanent status is not an item: the bar collapses
    // to nothing with no items, and "we have no network" is the answer to
    // "why is nothing updating?" precisely when nothing else is being said.
    // An item could not be on screen at that moment.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            StatusBarFooter(
              items: const [],
              onDismiss: _noop,
              perma: const [StatusBarPermaData(key: 'offline', icon: Icons.cloud_off, text: 'Offline')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(StatusBarFooter)).height, greaterThan(0));
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('a permanent status stays put while messages come and go', (tester) async {
    // It belongs to the bar, not to whatever is being said in it. An icon
    // inside the collapsed switcher would be rebuilt — and briefly duplicated
    // — on every message change.
    Widget withItems(List<StatusBarItemData> items) => MaterialApp(
          home: Column(
            children: [
              const Expanded(child: SizedBox.shrink()),
              StatusBarFooter(
                items: items,
                onDismiss: _noop,
                perma: const [StatusBarPermaData(key: 'offline', icon: Icons.cloud_off, text: 'Offline')],
              ),
            ],
          ),
        );

    await tester.pumpWidget(withItems([StatusBarItemData(key: 'a', title: 'Syncing', text: 'Syncing')]));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    await tester.pumpWidget(withItems([StatusBarItemData(key: 'b', title: 'Downloading', text: 'Downloading')]));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition, with both messages mounted: exactly one icon.
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

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
