// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On the web a map's element takes every pointer event over it, whatever
// Flutter paints above; a dropdown's menu opened over a map has nothing of the
// app's own to put between them. The cover lays an element over the map while
// a route sits over its own — and must not lift it the moment that route
// starts to leave, or a click during a dialog's fade-out lands on the map.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  setUp(() => PlatformViewShield.debugOnWeb = true);
  tearDown(() => PlatformViewShield.debugOnWeb = false);

  final blocker = find.byKey(const ValueKey('platform-view-blocker'));

  Future<void> pumpMap(WidgetTester tester, Widget Function(BuildContext context) above) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const SizedBox(
                height: 200,
                child: PlatformViewCover(
                  child: ColoredBox(color: Colors.teal, child: SizedBox.expand()),
                ),
              ),
              above(context),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('covers a map while a dialog is over it, until the dialog has left', (tester) async {
    await pumpMap(
      tester,
      (context) => TextButton(
        onPressed: () => showHaloDialog<void>(
          context: context,
          builder: (_) => const HaloDialog(content: Text('over the map')),
        ),
        child: const Text('open'),
      ),
    );
    expect(blocker, findsNothing, reason: 'nothing over it yet');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PlatformViewCover), matching: blocker), findsOneWidget);

    Navigator.of(tester.element(find.text('over the map'))).pop();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(of: find.byType(PlatformViewCover), matching: blocker),
      findsOneWidget,
      reason: 'the dialog is still fading out',
    );
    await tester.pump(PlatformViewCover.exitTime);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PlatformViewCover), matching: blocker), findsNothing);
  });

  testWidgets("covers a map under a dropdown's menu, which nothing of the app's can shield", (tester) async {
    await pumpMap(
      tester,
      (context) => DropdownButton<int>(
        value: 1,
        items: const [
          DropdownMenuItem(value: 1, child: Text('one')),
          DropdownMenuItem(value: 2, child: Text('two')),
        ],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PlatformViewCover), matching: blocker), findsOneWidget);
  });

  testWidgets('elsewhere a cover is the map alone', (tester) async {
    PlatformViewShield.debugOnWeb = false;
    await pumpMap(
      tester,
      (context) => TextButton(
        onPressed: () => showHaloDialog<void>(
          context: context,
          builder: (_) => const HaloDialog(content: Text('over the map')),
        ),
        child: const Text('open'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PlatformViewCover), matching: blocker), findsNothing);
  });
}
