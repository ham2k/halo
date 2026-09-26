// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every other shield and cover test stands the VM's placeholder in for the
// web's element. This one runs in the browser, where the conditional import
// has to reach the real element — or every shield in the app silently becomes
// a SizedBox and a map takes the clicks over it again.

@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  testWidgets('a shield lays an element of its own under its child, out of Flutter hit testing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: PlatformViewShield(child: SizedBox(width: 100, height: 60))),
      ),
    );
    final element = find.byKey(const ValueKey('platform-view-blocker'));
    expect(element, findsOneWidget);
    final view = tester.widget<HtmlElementView>(element);
    expect(view.hitTestBehavior, PlatformViewHitTestBehavior.transparent, reason: 'a tap beside a dialog card must reach its barrier');
    expect(tester.getSize(element), const Size(100, 60));
  });
}
