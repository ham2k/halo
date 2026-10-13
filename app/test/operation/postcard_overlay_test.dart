// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The band legend on the map postcard keeps clear of the footer and the
// attribution in every shape. Laid out in the real fonts: the test font's
// square glyphs are far wider than Roboto's, and would put the legend over
// a footer it clears in the picture.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/operation_postcard.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'RobotoSlab']) {
      final loader = FontLoader(family)..addFont(File('assets/fonts/$family.ttf').readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
  });

  group('the overlay', () {
    final colors = HaLoColors.light.bands;
    final text = PostcardText(
      title: 'N0CALL',
      subtitle: '',
      stats: '1,120 QSOs',
      date: '',
      bands: [
        for (final band in ['160m', '80m', '40m', '20m', '15m', '10m', '6m']) (band: band, color: colors[band]!, count: '1,120 Qs'),
      ],
    );

    Future<void> pumpOverlay(WidgetTester tester, PostcardShape shape, {required bool legend}) async {
      tester.view.physicalSize = shape.logicalSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PostcardOverlay(shape: shape, text: text, attribution: '© OpenStreetMap contributors', isDark: false, legend: legend),
        ),
      );
    }

    Rect boxAround(WidgetTester tester, Finder text) => tester.getRect(find.ancestor(of: text, matching: find.byType(DecoratedBox)).first);

    for (final shape in PostcardShape.values) {
      testWidgets('a ${shape.name} legend clears the footer and the attribution', (tester) async {
        await pumpOverlay(tester, shape, legend: true);
        final legend = boxAround(tester, find.text('160m'));
        // The portrait's corner is narrower than the legend beside the footer.
        expect(legend.overlaps(boxAround(tester, find.textContaining('Ham2K', findRichText: true))), isFalse);
        expect(legend.overlaps(tester.getRect(find.text('© OpenStreetMap contributors'))), isFalse);
        expect((Offset.zero & shape.logicalSize).intersect(legend), legend, reason: 'on the page whole');
      });
    }

    testWidgets('only the map page asks for the legend', (tester) async {
      await pumpOverlay(tester, PostcardShape.portrait, legend: false);
      expect(find.text('40m'), findsNothing);
    });
  });
}
