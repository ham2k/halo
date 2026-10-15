// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
    await tester.pump();
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
}
