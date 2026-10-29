// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rotator map is a control as much as a picture: a tap on it moves an
// antenna on a tower. So it must turn exactly where it was tapped, never
// turn anything while it cannot show where the antenna is, and say "turning"
// only while the antenna is on its way.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/rotator/rotator_map.dart';

void main() {
  final p = t.operation.layout.panels;
  final home = gridToLocation('FN31pr')!;
  final london = gridToLocation('IO91wm')!;

  const side = 400.0;
  final turns = <int>[];
  setUp(turns.clear);

  Future<void> pumpMap(WidgetTester tester, {bool live = true, int? azimuth = 0, int? target, GridLocation? dx}) async {
    // The DX snap needs the outlines, which load from the bundle: real
    // async, which the test's fake clock never runs.
    await tester.runAsync(
      () => tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: RotatorMap(home: home, dx: dx, azimuth: azimuth, target: target, live: live, onTurn: turns.add),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }

  Offset centre(WidgetTester tester) => tester.getCenter(find.byType(RotatorMap));

  testWidgets('a tap turns the antenna to the heading of the point tapped', (tester) async {
    await pumpMap(tester);
    await tester.tapAt(centre(tester) + const Offset(100, 0));
    await tester.tapAt(centre(tester) + const Offset(0, 100));
    await tester.tapAt(centre(tester) + const Offset(-70, -70));
    expect(turns, [90, 180, 315]);
  });

  testWidgets('a tap off the disc, or on a rotator that is not connected, turns nothing', (tester) async {
    await pumpMap(tester);
    await tester.tapAt(centre(tester) + const Offset(side / 2 - 2, side / 2 - 2));
    expect(turns, isEmpty, reason: 'a corner outside the rim is no heading at all');

    await pumpMap(tester, live: false);
    await tester.tapAt(centre(tester) + const Offset(100, 0));
    expect(turns, isEmpty);
  });

  testWidgets('a tap on the station being worked turns to its own heading, not the pixel\'s', (tester) async {
    await pumpMap(tester, dx: london);
    final heading = bearingOnEarthDeg(home, london);
    // A few pixels off the dot: without the snap this turns a degree or two
    // wide of a station whose heading the app knows exactly.
    final radius = side / 2 - 16;
    final distance = distanceOnEarthKm(home, london) / (math.pi * 6371) * radius;
    final angle = (heading - 90) * math.pi / 180;
    final dot = Offset(distance * math.cos(angle), distance * math.sin(angle));
    await tester.tapAt(centre(tester) + dot + const Offset(5, 5));
    expect(turns, [heading.round()]);
  });

  testWidgets('the corner reads current and target while turning, and the heading alone once there', (tester) async {
    await pumpMap(tester, azimuth: 45, target: 290);
    expect(find.text('45° ➜ 290°'), findsOneWidget);

    // Within a controller's coasting distance counts as there.
    await pumpMap(tester, azimuth: 288, target: 290);
    expect(find.text('288°'), findsOneWidget);

    await pumpMap(tester, live: false, azimuth: null);
    expect(find.text(p.rotatorDisconnected), findsOneWidget);
  });
}
