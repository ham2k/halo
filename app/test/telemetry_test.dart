// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Telemetry consent gating (ham2k/halo-dist#255): without "Share app
// usage data" nothing may reach the MetricsService, because that consent
// check is the app's entire privacy guarantee for analytics. The concrete
// analytics backend lives in the private distribution layer and has its
// own tests there; this file covers the generic seam.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/metrics_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

class RecordingMetrics implements MetricsService {
  final events = <(String, Map<String, Object?>)>[];
  @override
  void logEvent(String name, {Map<String, Object?> properties = const {}}) => events.add((name, properties));
  @override
  void setUserProperty(String name, String? value) {}
}

Future<HaLoServices> makeServices({required bool consent, required MetricsService metrics}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  if (consent) {
    await settings.setSettingValue(SettingsService.privacyGroup, 'consentAppData', true);
  }
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
  return HaLoServices(db, settings, extensions: extensions, metrics: metrics);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('track drops events without consent — the privacy guarantee', () async {
    final metrics = RecordingMetrics();
    final services = await makeServices(consent: false, metrics: metrics);

    services.track('app_started', {'a': 1});
    expect(metrics.events, isEmpty);
  });

  test('track forwards events with consent, and stops when consent is revoked', () async {
    final metrics = RecordingMetrics();
    final services = await makeServices(consent: true, metrics: metrics);

    services.track('qso_added', {'their_prefix': 'EA'});
    expect(metrics.events.single.$1, 'qso_added');
    expect(metrics.events.single.$2['their_prefix'], 'EA');

    // Revoking consent silences tracking immediately — checked per call.
    await services.settings.setSettingValue(SettingsService.privacyGroup, 'consentAppData', false);
    services.track('qso_added');
    expect(metrics.events, hasLength(1));
  });
}
