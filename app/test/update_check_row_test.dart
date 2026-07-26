// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The About panel's "Check for Updates" row. The row itself is generic — it
// only talks to HaLoServices.updateCheck (services/update_check_service.dart)
// — so these tests drive it entirely through a fake UpdateCheckService
// rather than the OSS WebFreshnessUpdateCheckService default, which is
// gated on kIsWeb (never true in a test binary — see
// build_freshness_service_test.dart's own note on this) and so can never be
// exercised applicable here. That default's own delegation to
// BuildFreshnessService is covered by build_freshness_service_test.dart.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/services/update_check_service.dart';
import 'package:ham2k_logger/services/update_service.dart';
import 'package:ham2k_logger/views/update_check_row.dart';

class _FakeUpdateCheckService implements UpdateCheckService {
  _FakeUpdateCheckService({
    this.outcome = UpdateCheckOutcome.upToDate,
    this.throwOnCheck = false,
  });

  final UpdateCheckOutcome outcome;
  final bool throwOnCheck;
  int checkCalls = 0;

  @override
  bool isApplicable({required UpdateService updates}) => true;

  @override
  Future<UpdateCheckOutcome> check({required UpdateService updates, required StatusBarService statusBar}) async {
    checkCalls++;
    if (throwOnCheck) throw StateError('unexpected updater failure');
    return outcome;
  }
}

Future<HaLoServices> _makeServices({UpdateCheckService? updateCheck}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  return HaLoServices(db, settings, updateCheck: updateCheck);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRow(WidgetTester tester, HaLoServices services) => tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(home: Scaffold(body: UpdateCheckRow(services: services))),
        ),
      );

  testWidgets('is not shown when no update mechanism applies to this build (the OSS default, off the web)',
      (tester) async {
    final services = await _makeServices();
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();

    expect(find.text('Check for Updates'), findsNothing);
  });

  testWidgets('checks automatically on mount and reports "up to date" when nothing new is found', (tester) async {
    final updateCheck = _FakeUpdateCheckService();
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pump(); // let initState's check kick off
    await tester.pumpAndSettle();

    expect(updateCheck.checkCalls, 1);
    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets('reports a downloaded patch, prompting a restart', (tester) async {
    final updateCheck = _FakeUpdateCheckService(outcome: UpdateCheckOutcome.restartToApply);
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();

    expect(find.text('An update has been downloaded. Restart to apply it.'), findsOneWidget);
  });

  testWidgets('an unexpected exception from a check does not leave the row stuck on "Checking…" forever',
      (tester) async {
    final updateCheck = _FakeUpdateCheckService(throwOnCheck: true);
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();

    expect(updateCheck.checkCalls, 1);
    expect(find.text('Checking for updates…'), findsNothing);
    // Falls back to "up to date" rather than crashing or hanging — the row
    // stays usable, and the exception itself is reported, not swallowed
    // silently (see ErrorReportingService.report in _check()).
    expect(find.text('Up to date'), findsOneWidget);

    // The tap target must not stay disabled after the failure.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(updateCheck.checkCalls, 2);
  });

  testWidgets('tapping the row re-checks', (tester) async {
    final updateCheck = _FakeUpdateCheckService();
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();
    expect(updateCheck.checkCalls, 1);

    // The fake resolves instantly (no real await), so there's no frame where
    // the transient "checking" state is observable — just confirm the tap
    // triggered a second, real check.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(updateCheck.checkCalls, 2);
  });
}
