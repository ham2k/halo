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

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/services/update_check_service.dart';
import 'package:ham2k_logger/services/update_service.dart';
import 'package:ham2k_logger/views/update_check_row.dart';

class _FakeUpdateCheckService extends UpdateCheckService {
  _FakeUpdateCheckService({this.outcome = UpdateCheckOutcome.upToDate, this.throwOnCheck = false, this.destination});

  final UpdateCheckOutcome outcome;
  final bool throwOnCheck;

  /// Where this implementation says to go, if anywhere — the store on mobile,
  /// nowhere on desktop, where Sparkle runs its own install UI.
  final Uri? destination;

  int checkCalls = 0;

  @override
  Future<Uri?> updateDestination() async => destination;

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

/// Captures what the row hands the platform, so the launch itself is asserted
/// rather than assumed — same seam as link_opener_test.dart.
class _RecordingLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  _RecordingLauncher({this.handles = true});

  /// Whether anything on the device claims the scheme. False is the real case
  /// for a store scheme whose app has been removed.
  final bool handles;
  final launched = <String>[];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => handles;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return handles;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingLauncher launcher;
  setUp(() {
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> pumpRow(WidgetTester tester, HaLoServices services) => tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: UpdateCheckRow(services: services)),
      ),
    ),
  );

  testWidgets('is not shown when no update mechanism applies to this build (the OSS default, off the web)', (tester) async {
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

  testWidgets('an unexpected exception from a check does not leave the row stuck on "Checking…" forever', (tester) async {
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

  testWidgets('an update with somewhere to go stops re-checking and offers the link instead', (tester) async {
    final updateCheck = _FakeUpdateCheckService(
      outcome: UpdateCheckOutcome.updateAvailable,
      destination: Uri.parse('market://details?id=com.ham2k.logger.next'),
    );
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    // The trap: leaving the refresh affordance in place means the tap that
    // looks like "go get it" silently re-runs a check that already answered.
    expect(find.byIcon(MdiIcons.openInNew), findsOneWidget);
    expect(find.byIcon(MdiIcons.refresh), findsNothing);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(updateCheck.checkCalls, 1, reason: 'the tap launches the store rather than checking again');
    // The assertion that matters: emptying _openDestination must fail this.
    expect(launcher.launched, ['market://details?id=com.ham2k.logger.next']);
  });

  testWidgets('a scheme nothing on the device handles is logged, not left as a silent dead tap', (tester) async {
    launcher = _RecordingLauncher(handles: false);
    UrlLauncherPlatform.instance = launcher;
    final updateCheck = _FakeUpdateCheckService(outcome: UpdateCheckOutcome.updateAvailable, destination: Uri.parse('itms-beta://'));
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // The row must survive a refused launch — still showing the update, still
    // tappable, rather than throwing into the zone from an unawaited future.
    expect(launcher.launched, ['itms-beta://']);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('an update the mechanism handles itself keeps the re-check tap (Sparkle owns its own UI)', (tester) async {
    final updateCheck = _FakeUpdateCheckService(outcome: UpdateCheckOutcome.updateAvailable);
    final services = await _makeServices(updateCheck: updateCheck);
    addTearDown(services.db.close);

    await pumpRow(tester, services);
    await tester.pumpAndSettle();

    expect(find.byIcon(MdiIcons.refresh), findsOneWidget);
    expect(find.byIcon(MdiIcons.openInNew), findsNothing);
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
