// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingInfoFrame and LoggingActionButton on their own: the cross-fade key's
// contract, the room the frame reserves, and the button's footprint.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart';
import 'package:halo_widgets/src/spacing.dart';

const _footerKey = ValueKey('footer');
const _buttonKey = ValueKey('button');

Widget _host({String signature = 'stats', double diameter = 44, bool leftieMode = false, bool withFooter = false}) => MaterialApp(
  home: Scaffold(
    body: LoggingInfoFrame(
      buttonDiameter: diameter,
      leftieMode: leftieMode,
      signature: signature,
      footer: withFooter ? const _Footer(key: _footerKey) : null,
      actionButton: SizedBox(key: _buttonKey, width: diameter, height: diameter),
      child: const Text('content'),
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
