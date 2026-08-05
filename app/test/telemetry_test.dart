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
import 'package:ham2k_logger/views/panel_use_tracker.dart';

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

  group('PanelUseTracker', () {
    test('reports each panel once, however often it is used', () {
      // The trap: the hooks are pointer-down listeners, so without the
      // de-dup a scroll or a run of taps in one panel would emit a signal
      // per touch — turning "which panels get used" into "who fidgets most".
      final seen = <(String, Map<String, Object?>)>[];
      final tracker = PanelUseTracker(
        track: (event, [properties = const {}]) => seen.add((event, properties)),
        screen: 'operation',
      );

      tracker.used('logging');
      tracker.used('logging');
      tracker.used('spots');
      tracker.used('logging');

      expect(seen.map((e) => e.$2['panel']), ['logging', 'spots']);
      expect(seen.every((e) => e.$1 == 'panel_used'), isTrue);
      expect(seen.first.$2['screen'], 'operation',
          reason: 'panel names are only unique within a screen');
    });

    test('a new instance reports again — the count is per screen VISIT', () {
      // Each screen's State owns a tracker, so leaving and coming back is a
      // fresh instance. Were this de-duplicated globally, the event could
      // never answer how often a panel is reached for.
      final seen = <String>[];
      void track(String event, [Map<String, Object?> properties = const {}]) =>
          seen.add(properties['panel'] as String);

      PanelUseTracker(track: track, screen: 'operation').used('map');
      PanelUseTracker(track: track, screen: 'operation').used('map');

      expect(seen, ['map', 'map']);
    });
  });
}
