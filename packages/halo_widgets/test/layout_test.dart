// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The shirt-size boundaries are the app-wide layout contract
// (docs/design/layouts.md): every root view reflows at exactly these widths,
// and idealPaneWidth must stay strictly between the S and L boundaries (the
// "no M" gap) or two-pane defaults stop making sense.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('ShirtSize.fromWidth', () {
    test('boundary values land on the documented sizes', () {
      expect(ShirtSize.fromWidth(320), ShirtSize.xs);
      expect(ShirtSize.fromWidth(359.9), ShirtSize.xs);
      expect(ShirtSize.fromWidth(360), ShirtSize.s);
      expect(ShirtSize.fromWidth(430), ShirtSize.s);
      expect(ShirtSize.fromWidth(659.9), ShirtSize.s);
      expect(ShirtSize.fromWidth(660), ShirtSize.l);
      expect(ShirtSize.fromWidth(1199.9), ShirtSize.l);
      expect(ShirtSize.fromWidth(1200), ShirtSize.xl);
    });

    test('only L and XL are two-pane', () {
      expect(ShirtSize.xs.isTwoPane, isFalse);
      expect(ShirtSize.s.isTwoPane, isFalse);
      expect(ShirtSize.l.isTwoPane, isTrue);
      expect(ShirtSize.xl.isTwoPane, isTrue);
    });

    test('idealPaneWidth sits strictly inside the S–L gap', () {
      expect(idealPaneWidth, greaterThan(ShirtSize.xsMax));
      expect(idealPaneWidth, lessThan(ShirtSize.sMax));
      expect(minPaneWidth, lessThan(idealPaneWidth));
    });
  });

  group('ShirtSize.of', () {
    testWidgets('reads the MediaQuery width (the UiScale-divided space)', (tester) async {
      // ui-scaling.md rule 4: breakpoints see the scaled logical width, so a
      // larger font scale reflows to narrower layouts. ShirtSize must read
      // MediaQuery, not the physical view.
      late ShirtSize size;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (context) {
              size = ShirtSize.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(size, ShirtSize.l);
    });
  });

  group('paneDividerWidth', () {
    // Two independent axes, and the mobile one is the easy one to lose: the
    // test platform IS mobile, so a hard-coded desktop constant would pass
    // every widget test in this package and ship a 7pt bar to fingertips.
    test('the four widths are the ones docs/design/layouts.md records', () {
      // Pinned by VALUE, not by ordering: an ordering-only assertion survives
      // a retune that puts the mobile viewing width above the desktop editing
      // one, which collapses the grab-target distinction the widening exists
      // for while leaving the docs describing numbers the code no longer has.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(paneDividerWidth(), 7.0);
      expect(paneDividerWidth(editing: true), 11.0);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(paneDividerWidth(), 9.0);
      expect(paneDividerWidth(editing: true), 16.0);
    });
  });
}
