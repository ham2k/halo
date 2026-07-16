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
}
