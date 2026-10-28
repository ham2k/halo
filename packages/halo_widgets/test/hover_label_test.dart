// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget app() => MaterialApp(
    // The app root hides every Tooltip; the label must show regardless.
    home: TooltipVisibility(
      visible: false,
      child: Scaffold(
        body: Center(
          child: HoverLabel(label: 'DX Cluster', child: Icon(MdiIcons.accessPointNetwork, size: 16)),
        ),
      ),
    ),
  );

  testWidgets('names the icon while the mouse is over it, and only then', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('DX Cluster'), findsNothing, reason: 'nothing pops up unasked');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(MdiIcons.accessPointNetwork)));
    await tester.pump(HoverLabel.restDelay);
    expect(find.text('DX Cluster'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('DX Cluster')).dy,
      lessThan(tester.getTopLeft(find.byIcon(MdiIcons.accessPointNetwork)).dy),
      reason: 'above the icon, not over it',
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('DX Cluster'), findsNothing);
  });

  testWidgets('the name is the icon\'s accessible label, which is all touch gets', (tester) async {
    await tester.pumpWidget(app());
    expect(find.bySemanticsLabel('DX Cluster'), findsOneWidget);
  });

  // Taking a button's semantics over would leave a screen reader a name with
  // nothing to press, and a test finding the button by its label unable to tap it.
  testWidgets('around a button it labels on hover and leaves the button pressable by its own name', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoverLabel(
              label: 'Import',
              namesChild: false,
              child: IconButton(
                onPressed: () => pressed++,
                icon: Icon(MdiIcons.fileImport, semanticLabel: 'Import'),
              ),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(find.bySemanticsLabel('Import'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Import'));
    expect(pressed, 1);
    semantics.dispose();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
    await tester.pump(HoverLabel.restDelay);
    expect(find.text('Import'), findsOneWidget);
  });

  // A pointer crossing a row of icons on its way elsewhere would flash a
  // label at each; one that only shows after the hand stops never does.
  testWidgets('waits for the pointer to rest, forgiving a twitch but not a move', (tester) async {
    await tester.pumpWidget(app());
    final icon = tester.getCenter(find.byIcon(MdiIcons.accessPointNetwork));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(icon);

    await tester.pump(HoverLabel.restDelay - const Duration(milliseconds: 50));
    expect(find.text('DX Cluster'), findsNothing, reason: 'not yet at rest');

    // A twitch is still resting: the wait that started on arrival runs out.
    await mouse.moveTo(icon + const Offset(HoverLabel.twitch - 1, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DX Cluster'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(icon);
    await tester.pump(HoverLabel.restDelay - const Duration(milliseconds: 50));
    // A real move starts the wait over.
    await mouse.moveTo(icon + const Offset(HoverLabel.twitch + 2, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DX Cluster'), findsNothing, reason: 'the move restarted the wait');
    await tester.pump(HoverLabel.restDelay);
    expect(find.text('DX Cluster'), findsOneWidget);
  });

  // A wait left running would pop a label up over wherever the pointer went.
  testWidgets('a pointer that leaves before the wait is up shows nothing', (tester) async {
    await tester.pumpWidget(app());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byIcon(MdiIcons.accessPointNetwork)));
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(Offset.zero);
    await tester.pump(HoverLabel.restDelay * 2);
    expect(find.text('DX Cluster'), findsNothing);
  });
}
