// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingInfoFrame and LoggingActionButton on their own: the cross-fade key's
// contract, the room the frame reserves, and the button's footprint.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart';
import 'package:halo_widgets/src/spacing.dart';
import 'package:halo_widgets/src/ui_scale.dart';

const _footerKey = ValueKey('footer');
const _buttonKey = ValueKey('button');

Widget _host({
  String signature = 'stats',
  double diameter = 44,
  bool leftieMode = false,
  bool withFooter = false,
  bool entryRowAbove = false,
  double? contentHeight,
  double uiScale = 1,
}) => MaterialApp(
  home: UiScale(
    scale: uiScale,
    child: Scaffold(
      // Unbounded below, as the panel's column has it: the frame is as tall
      // as it makes itself.
      body: Column(
        children: [
          LoggingInfoFrame(
            buttonDiameter: diameter,
            leftieMode: leftieMode,
            signature: signature,
            footer: withFooter ? const _Footer(key: _footerKey) : null,
            actionButton: SizedBox(key: _buttonKey, width: diameter, height: diameter),
            entryRowAbove: entryRowAbove,
            child: contentHeight == null ? const Text('content') : SizedBox(height: contentHeight),
          ),
        ],
      ),
    ),
  ),
);

/// A footer with state of its own, as the keyer line has.
class _Footer extends StatefulWidget {
  const _Footer({super.key});

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

/// The switcher's CURRENT child, keyed by the generation — the last one in
/// its stack, since an outgoing child is still there mid-fade.
Key? _contentKey(WidgetTester tester) => tester.widgetList<KeyedSubtree>(find.byWidgetPredicate((w) => w is KeyedSubtree && w.key is ValueKey<int>)).last.key;

void main() {
  testWidgets('the cross-fade key holds while the signature holds, moves when it changes, and never repeats', (tester) async {
    await tester.pumpWidget(_host(signature: 'stats'));
    final first = _contentKey(tester);
    await tester.pumpWidget(_host(signature: 'stats'));
    expect(_contentKey(tester), first, reason: 'an in-place update (the stats tick) must not cross-fade');

    await tester.pumpWidget(_host(signature: 'call:W1AW'));
    final second = _contentKey(tester);
    expect(second, isNot(first));

    // The trap: a content-derived key (stats → call → stats) would hand the
    // AnimatedSwitcher a key its still-fading outgoing child holds, and its
    // Stack asserts. Going back to an earlier signature is a NEW key.
    await tester.pumpWidget(_host(signature: 'stats'));
    expect(_contentKey(tester), isNot(first));
    expect(_contentKey(tester), isNot(second));
    await tester.pumpAndSettle();
  });

  testWidgets('the area is at least the button tall, and its content and footer keep clear of its column', (tester) async {
    await tester.pumpWidget(_host(diameter: 60, withFooter: true));
    expect(tester.getSize(find.byType(ConstrainedBox).first).height, greaterThanOrEqualTo(60));
    final frame = tester.getRect(find.byType(LoggingInfoFrame));
    expect(tester.getTopRight(find.byKey(_buttonKey)).dx, frame.right, reason: 'pinned to the trailing edge');
    expect(tester.getBottomRight(find.byKey(_buttonKey)).dy, frame.bottom, reason: 'pinned to the bottom edge');
    expect(tester.getTopRight(find.byKey(_footerKey)).dx, frame.right - 60 - Space.md, reason: 'the footer stops short of the button, as the content does');
    expect(tester.getTopLeft(find.byKey(_footerKey)).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.text('content')).dy), reason: 'under the content');

    await tester.pumpWidget(_host(diameter: 60, withFooter: true, leftieMode: true));
    expect(tester.getTopLeft(find.byKey(_buttonKey)).dx, frame.left);
    expect(tester.getTopLeft(find.byKey(_footerKey)).dx, frame.left + 60 + Space.md);
  });

  testWidgets('the footer sits at the bottom of the room the area reserves, the slack above it', (tester) async {
    // The trap: the footer packed under the content with the slack below
    // it — then it grows DOWN into the slack when it appears, and reads as
    // dropping out of the content rather than rising from the fields' edge.
    await tester.pumpWidget(_host(diameter: 60, withFooter: true));
    // The room is the button's diameter from the content's top — the frame
    // itself the test host stretches to the screen.
    final top = tester.getTopLeft(find.text('content')).dy;
    expect(tester.getBottomLeft(find.byKey(_footerKey)).dy, top + 60, reason: 'against the fields\' edge');
    expect(tester.getTopLeft(find.byKey(_footerKey)).dy, greaterThan(tester.getBottomLeft(find.text('content')).dy), reason: 'the slack between');

    // The entry row above: the footer stays under the content, nearer the row.
    await tester.pumpWidget(_host(diameter: 60, withFooter: true, entryRowAbove: true));
    expect(tester.getTopLeft(find.byKey(_footerKey)).dy, tester.getBottomLeft(find.text('content')).dy);
  });

  // The keyer line is the footer: inside the cross-fade it would be torn down
  // and slide in again with every call-field keystroke, and keyboard mode
  // with it.
  testWidgets('the footer keeps its state when the content changes', (tester) async {
    await tester.pumpWidget(_host(signature: 'stats', withFooter: true));
    final before = tester.state(find.byKey(_footerKey));
    await tester.pumpWidget(_host(signature: 'call:W1AW', withFooter: true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(_footerKey)), same(before));
    expect(find.byKey(_footerKey), findsOneWidget, reason: 'not one per fading copy');
  });

  group('shrinking late', () {
    double frameHeight(WidgetTester tester) => tester.getSize(find.byType(LoggingInfoFrame)).height;

    /// A frame a vsync on: a release step shows whole in the frame after
    /// its own, once its microsecond has passed.
    Future<void> nextFrame(WidgetTester tester) => tester.pump(const Duration(milliseconds: 16));

    /// Pumps past the content's own 120 ms resize.
    Future<void> resize(WidgetTester tester, double contentHeight, {double uiScale = 1, bool withFooter = false}) async {
      await tester.pumpWidget(_host(contentHeight: contentHeight, uiScale: uiScale, withFooter: withFooter));
      await nextFrame(tester);
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('grows at once, holds its height five seconds after shrinking, then comes down a device pixel at a time over ten', (tester) async {
      // Under a UI scale, as every phone is: a logical pixel is not a whole
      // number of device pixels, and a step of 1/dpr would land between them.
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      const scale = 1.1;
      await resize(tester, 100, uiScale: scale);
      await resize(tester, 120, uiScale: scale);
      expect(frameHeight(tester), 120, reason: 'growing is never held back');
      final grid = PixelGrid.of(tester.element(find.byType(LoggingInfoFrame))).devicePixelsPerLogical;
      expect(grid, closeTo(2.2, 1e-9));

      await resize(tester, 100, uiScale: scale);
      // The trap: the frame following its content down at once, which moves
      // everything it pushed aside each time an FYI message or a call's
      // details come and go.
      await tester.pump(const Duration(milliseconds: 4700));
      expect(frameHeight(tester), 120, reason: 'held five seconds');

      // 20 px at 2.2 device px each is 44 steps, one every 227 ms.
      await tester.pump(const Duration(milliseconds: 600));
      await nextFrame(tester);
      final releasing = frameHeight(tester);
      expect(releasing, lessThan(120));
      final devicePixels = releasing * grid;
      expect(devicePixels, closeTo(devicePixels.roundToDouble(), 1e-6), reason: 'on a device pixel');
      await tester.pump(const Duration(milliseconds: 100));
      await nextFrame(tester);
      expect(frameHeight(tester), releasing, reason: 'a step per pixel, not a frame-paced animation');
      await tester.pump(const Duration(seconds: 5));
      await nextFrame(tester);
      expect(frameHeight(tester), allOf(greaterThan(100), lessThan(releasing)), reason: 'over ten seconds, not at once');
      await tester.pump(const Duration(seconds: 5));
      await nextFrame(tester);
      await nextFrame(tester);
      expect(frameHeight(tester), 100);
    });

    testWidgets('the footer stays at the fields\' edge while the frame holds and releases, the room opening above it', (tester) async {
      await resize(tester, 100, withFooter: true);
      await resize(tester, 60, withFooter: true);
      // The trap: the held room under the footer, which lifts an FYI message
      // off the fields by what the content lost and lets it creep back down.
      expect(frameHeight(tester), 110, reason: 'held');
      expect(tester.getBottomLeft(find.byKey(_footerKey)).dy, tester.getBottomLeft(find.byType(LoggingInfoFrame)).dy);
      await tester.pump(const Duration(seconds: 10));
      await nextFrame(tester);
      expect(frameHeight(tester), allOf(greaterThan(70), lessThan(110)), reason: 'releasing');
      expect(tester.getBottomLeft(find.byKey(_footerKey)).dy, tester.getBottomLeft(find.byType(LoggingInfoFrame)).dy);
      await tester.pump(const Duration(seconds: 10));
      await nextFrame(tester);
      await nextFrame(tester);
      expect(frameHeight(tester), 70);
    });

    testWidgets('a change while held starts the hold over; growing past it ends it', (tester) async {
      await resize(tester, 120);
      await resize(tester, 80);
      await tester.pump(const Duration(seconds: 4));
      await resize(tester, 90);
      // The trap: the first hold's timer still running, which releases the
      // frame a second after content that should have bought five more.
      await tester.pump(const Duration(seconds: 4));
      expect(frameHeight(tester), 120);

      await tester.pump(const Duration(seconds: 3));
      await nextFrame(tester);
      expect(frameHeight(tester), lessThan(120), reason: 'releasing');
      await resize(tester, 130);
      expect(frameHeight(tester), 130);
      await resize(tester, 130);
      await tester.pump(const Duration(seconds: 20));
      expect(frameHeight(tester), 130, reason: 'nothing left to release');
    });
  });

  testWidgets('the action button takes the diameter it is given, and a null callback disables it', (tester) async {
    var taps = 0;
    Widget button(VoidCallback? onPressed) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LoggingActionButton(diameter: 52, icon: Icons.undo, label: 'Undo', onPressed: onPressed, color: Colors.blue),
        ),
      ),
    );
    await tester.pumpWidget(button(() => taps++));
    expect(tester.getSize(find.byType(LoggingActionButton)), const Size(52, 52));
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);

    await tester.pumpWidget(button(null));
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}
