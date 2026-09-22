// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reverse bearing is the great-circle bearing BACK to us, which on a
// long path is not the forward bearing plus 180° — the tempting shortcut that
// would be wrong by tens of degrees across an ocean, exactly where an
// operator turning a dish relies on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/call_location_line.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> line(WidgetTester tester, {required bool reverse}) async {
    String? result;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              result = callLocationLine(
                context,
                {'grid': 'JO01aa', 'location': 'London', 'country': 'England', 'entityPrefix': 'G'},
                ourLocation: gridToLocation('FN31pr'),
                miles: false,
                showBearing: true,
                showReverseBearing: reverse,
                ourEntityPrefix: 'K',
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('with the option on, the line carries both bearings, and the reverse is not the forward plus 180°', (tester) async {
    final our = gridToLocation('FN31pr')!;
    final their = gridToLocation('JO01aa')!;
    final forward = bearingOnEarthDeg(our, their).round();
    final back = bearingOnEarthDeg(their, our).round();
    // The premise of the test: a transatlantic path where the shortcut is wrong.
    expect(back, isNot((forward + 180) % 360));

    final text = await line(tester, reverse: true);
    expect(text, contains('($forward° / $back°) to London'));
  });

  testWidgets('with the option off, only the forward bearing shows', (tester) async {
    final our = gridToLocation('FN31pr')!;
    final forward = bearingOnEarthDeg(our, gridToLocation('JO01aa')!).round();
    final text = await line(tester, reverse: false);
    expect(text, contains('($forward°) to London'));
    expect(text, isNot(contains('/')));
  });
}
