// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Zoomed in, a map's ring round the world is millions of pixels long. Dashed
// whole, a dash every 10 pixels, it costs seconds a frame for the few hundred
// the pane shows, and a web build stops answering.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_world.dart';

void main() {
  const pane = Rect.fromLTWH(0, 0, 400, 300);

  test('only what passes through the pane is dashed', () {
    final ring = Path()..addOval(Rect.fromCircle(center: const Offset(200, 3e6), radius: 3e6 - 150));
    final dashes = dashedPath(ring, within: pane).computeMetrics().toList();
    expect(dashes.length, inInclusiveRange(39, 41), reason: 'a dash every 10 pixels across 400');
    for (final dash in dashes) {
      final at = dash.getTangentForOffset(0)!.position;
      expect(pane.inflate(7).contains(at), isTrue, reason: 'a dash that reaches into the pane is drawn whole, and the pane cuts it');
    }
  });

  test('the dashes keep their places along the run as the pane moves over it', () {
    Offset firstDash(Rect within) => dashedPath(
      Path()
        ..moveTo(0, 150)
        ..lineTo(1000, 150),
      within: within,
    ).computeMetrics().first.getTangentForOffset(0)!.position;
    expect(firstDash(const Rect.fromLTWH(103, 0, 400, 300)).dx, 100, reason: 'the dash from 100 to 106 reaches into the pane');
    expect(firstDash(const Rect.fromLTWH(107, 0, 400, 300)).dx, 110, reason: 'past it, the next dash where it always was');
    expect(firstDash(const Rect.fromLTWH(113, 0, 400, 300)).dx, 110);
  });
}
