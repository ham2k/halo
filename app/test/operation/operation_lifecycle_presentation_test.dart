// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app hands the logging panel about an operation's lifecycle: when
// it counts the operator as present, and how it dates the last export.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/operation/operation_lifecycle_presentation.dart';

import '../support/halo_test_support.dart';

const _hour = 3600 * 1000;

Future<OperationLifecycleSpec?> _specIn(WidgetTester tester, HaLoServices services, Operation operation, {Locale? locale, int? loggedAtMillis}) async {
  OperationLifecycleSpec? spec;
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            spec = operationLifecycleSpec(context, services, operation, loggedAtMillis: loggedAtMillis);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return spec;
}

void main() {
  late HaLoServices services;

  setUp(() async {
    services = (await makeHaLoServices()).services;
    await services.settings.setExperimentEnabled('cycle', true);
  });

  testWidgets('an operator entering an old log is present, though the contacts are hours old', (tester) async {
    // The contacts' own times say hours of quiet. Measured from them alone,
    // the row locks between entries of a paper log being typed in.
    final created = await services.operations.create(stationCall: 'N0DEV');
    await services.operations.setStatus(created.uuid, OperationStatus.active, atMillis: nowMillis() - 5 * _hour);
    await services.qsos.writeBatch(
      operationUuid: created.uuid,
      inserts: [
        {
          'startAtMillis': nowMillis() - 5 * _hour,
          'band': '20m',
          'mode': 'CW',
          'their': {'call': 'W1AW'},
        },
      ],
    );
    final operation = (await services.operations.get(created.uuid))!;

    final unseen = await _specIn(tester, services, operation);
    expect(unseen!.quietAt(nowMillis()), isTrue);
    final logged = await _specIn(tester, services, operation, loggedAtMillis: nowMillis());
    expect(logged!.quietAt(nowMillis()), isFalse);
  });

  testWidgets('the last export is dated in the operator\'s language', (tester) async {
    // A month name is locale text and so is its order with the day: a fixed
    // English pattern reads "julio 21, 2026" in Spanish.
    final created = await services.operations.create(stationCall: 'N0DEV');
    await services.operations.setStatus(created.uuid, OperationStatus.processed, atMillis: DateTime.utc(2026, 7, 21, 12).millisecondsSinceEpoch);
    final operation = (await services.operations.get(created.uuid))!;

    final spec = await _specIn(tester, services, operation, locale: const Locale('es'));
    expect(spec!.lastExportNote!(nowMillis()), contains('21 de julio de 2026'));
  });
}
