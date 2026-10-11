// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Chasing view's log: contacts that belong to no operation — the bucket
// an ADIF import into Logs fills too — narrowed to the chasing station and
// the period. Without the narrowing, a club call's imported log shows up in
// an operator's own chasing, and editing one of those contacts restamps it
// with the operator's call.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/chase_view.dart';

import '../support/halo_test_support.dart';

void main() {
  testWidgets("the log holds the period's contacts for the chasing station, and nothing logged in an operation", (tester) async {
    final harness = await makeHaLoServices();
    final services = harness.services;
    await services.setOperatorCall('N0DEV');
    final now = nowMillis();
    final yesterday = now - const Duration(days: 1).inMilliseconds;
    Future<void> loose(String station, String call, int at) => services.qsos.add('', {
      'our': {'call': station},
      'their': {'call': call},
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': at,
    });
    await loose('N0DEV', 'K1ABC', now);
    await loose('W1AW', 'K2DEF', now);
    await loose('N0DEV', 'K3GHI', yesterday);
    final operation = await services.operations.create(stationCall: 'N0DEV');
    await services.qsos.add(operation.uuid, {
      'our': {'call': 'N0DEV'},
      'their': {'call': 'K4JKL'},
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': now,
    });

    await pumpHaLo(
      tester,
      (services) => ChaseView(services: services),
      harness: harness,
      size: const Size(1400, 900),
    );
    await settleFrames(tester);

    expect(find.text('K1ABC'), findsOneWidget, reason: "the chasing station's contact from today");
    expect(find.text('K2DEF'), findsNothing, reason: "another station's loose contact — an imported club log — is not this operator's chasing");
    expect(find.text('K3GHI'), findsNothing, reason: 'yesterday is outside Today');
    expect(find.text('K4JKL'), findsNothing, reason: 'a contact in an operation belongs to that operation');
  });

  // The operation sheet remembers its Activity Types band the same way: an
  // operator who folded it away does not want it back open every time.
  testWidgets('the extensions band stays as the operator left it, across closing and reopening the sheet', (tester) async {
    final harness = await makeHaLoServices();
    await harness.services.setOperatorCall('N0DEV');
    await pumpHaLo(
      tester,
      (services) => ChaseView(services: services),
      harness: harness,
      size: const Size(1400, 900),
    );
    await settleFrames(tester);

    Finder band() => find.byWidgetPredicate((w) => w is CollapsibleSection);
    Future<void> openSheet() async {
      await tester.tap(find.textContaining('chasing'));
      await settleFrames(tester);
    }

    await openSheet();
    expect(tester.widget<CollapsibleSection>(band()).expanded, isTrue, reason: 'open the first time');
    await tester.tap(find.text('Extensions that include chasing'));
    await settleFrames(tester);
    expect(tester.widget<CollapsibleSection>(band()).expanded, isFalse);

    await tester.tap(find.text('OK'));
    await settleFrames(tester);
    expect(band(), findsNothing, reason: 'the sheet closed');

    await openSheet();
    expect(tester.widget<CollapsibleSection>(band()).expanded, isFalse, reason: 'still folded away');
    expect(
      harness.settings.layoutData(LayoutKeys.chaseOptions)?['extensionsHidden'],
      isTrue,
      reason: "kept with the view's options, so it outlives the view itself",
    );
  });

  // The Chasing view stays mounted behind the other home destinations, held
  // out of the focus tree while hidden the way HomeView holds it. Coming
  // back, nothing else would put the keyboard where the operator left it.
  testWidgets('coming back to the view returns the keyboard to the field the operator was in', (tester) async {
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    final harness = await makeHaLoServices();
    await harness.services.setOperatorCall('N0DEV');
    var visible = true;
    late StateSetter setVisible;
    await pumpHaLo(
      tester,
      (services) => StatefulBuilder(
        builder: (context, setState) {
          setVisible = setState;
          return Offstage(
            offstage: !visible,
            child: ExcludeFocus(
              excluding: !visible,
              child: ChaseView(services: services, visible: visible),
            ),
          );
        },
      ),
      harness: harness,
      size: const Size(1400, 900),
    );
    await settleFrames(tester);

    TextField sent() => tester.widget<TextField>(find.widgetWithText(TextField, 'Sent', skipOffstage: false));
    await tester.tap(find.widgetWithText(TextField, 'Sent'));
    await settleFrames(tester, frames: 2);
    expect(sent().focusNode?.hasFocus, isTrue);

    setVisible(() => visible = false);
    await settleFrames(tester, frames: 2);
    expect(sent().focusNode?.hasFocus, isFalse, reason: 'hidden, the view holds no focus');

    setVisible(() => visible = true);
    await settleFrames(tester, frames: 2);
    expect(sent().focusNode?.hasFocus, isTrue);
  });
}
