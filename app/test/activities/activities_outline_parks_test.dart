// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operation sheet's nearby list gains the POTA parks whose OUTLINE is
// near, not just those whose point is: a trail's point can sit a state away
// from where it passes the operator. A typed search is answered by what it
// names, so it never asks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/outline_grid_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';
import '../support/no_outline_grid.dart';

const _potaControl = {
  'key': 'pota/activation',
  'label': 'Parks on the Air',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

/// POTA running, suggesting nothing by its points.
class _PotaExtensions extends ExtensionServiceWithFakeHost {
  _PotaExtensions()
    : super(
        FakeExtensionHost({
          'activity:*:suggest': [
            {'key': 'pota', 'ok': true, 'value': <Object>[]},
          ],
        }),
      );

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const [_potaControl], loadFailed: false);
}

/// The Appalachian Trail, 170 m from the operation by its outline.
class _Trail extends NoOutlineGrid {
  final asked = <double>[];

  @override
  Future<OutlineParks> parksNear(GridLocation center, double radiusKm, {GridLocation? measureFrom, Set<String> known = const {}}) async {
    asked.add(radiusKm);
    return (
      distances: const <String, double?>{'US-4556': 0.17},
      found: const [
        {'type': 'potaActivation', 'ref': 'US-4556', 'shortLabel': 'POTA US-4556', 'name': 'Appalachian Trail', 'distance': 0.17, 'relevance': 1},
      ],
      settled: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the nearby list offers a park by its outline, and a typed search does not ask', (tester) async {
    final trail = _Trail();
    final HaLoHarness(:services) = await makeHaLoServices(extensions: _PotaExtensions(), outlineGrid: trail);
    final operation = Operation(uuid: 'op-1', data: const {'refs': [], 'grid': 'FN31ah'});

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: OperationSheet(services: services, operation: operation),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POTA US-4556'), findsOneWidget, reason: 'its point is nowhere near; its outline is');
    expect(trail.asked, [OutlineGridService.nearbyRadiusKm]);

    await tester.enterText(find.byType(TextField).first, 'bear');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(trail.asked, hasLength(1), reason: 'a typed search is answered by what it names, not by where the operator is');
  });
}
