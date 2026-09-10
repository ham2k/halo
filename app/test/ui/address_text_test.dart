// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a device is, clipped from the FRONT: two serial ports in one shack
// differ in their last characters and agree on the first eighteen, so a
// trailing ellipsis names neither of them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/equipment_glyphs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> shown(WidgetTester tester, String address, double width) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: width, child: AddressText(address)))),
    ));
    await tester.pumpAndSettle();
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('keeps the end and drops the beginning when it does not fit', (tester) async {
    const port = '/dev/cu.usbserial-FTB6SPL3';
    final clipped = await shown(tester, port, 90);

    expect(clipped.startsWith('…'), isTrue, reason: 'the cut is at the front');
    expect(clipped.endsWith('SPL3'), isTrue, reason: 'and the distinguishing tail survives it');
    expect(clipped.length, lessThan(port.length));
  });

  testWidgets('two ports that differ only at the end stay distinguishable', (tester) async {
    // The whole point. These share their first eighteen characters, so a
    // trailing ellipsis renders both as the same string.
    final a = await shown(tester, '/dev/cu.usbserial-FTB6SPL3', 90);
    final b = await shown(tester, '/dev/cu.usbserial-00F8E1EB0', 90);
    expect(a, isNot(b));
  });

  testWidgets('a column too narrow for even one character still shows the cut', (tester) async {
    // Reachable at the tightest geometry this app targets (landscape at font
    // scale 1.90). Seeded with the empty string instead of the ellipsis, the
    // loop breaks on its first pass and the row paints NOTHING where an
    // address should be — which reads as a device that has no address rather
    // than one whose address did not fit.
    expect(await shown(tester, '/dev/cu.usbserial-FTB6SPL3', 4), '…');
  });

  testWidgets('an address that fits is left alone', (tester) async {
    expect(await shown(tester, '10.0.0.9:4992', 400), '10.0.0.9:4992');
  });
}
