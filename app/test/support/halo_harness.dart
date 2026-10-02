// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/cat_traffic_log.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'fake_extension_host.dart';
import 'fake_secure_storage.dart';

/// The service graph a test runs against, with the pieces it most often
/// needs to reach past [services] for.
class HaLoHarness {
  final HaLoServices services;
  final HaLoDatabase db;
  final SettingsService settings;
  final ExtensionService extensions;

  HaLoHarness({required this.services, required this.db, required this.settings, required this.extensions});
}

/// Fresh prefs, settings, an in-memory database and a [HaLoServices] over
/// them, with the database closed at tearDown.
///
/// [stubs] feed a [FakeExtensionHost] (see its doc for the key shapes);
/// pass [extensions] instead to supply a service of your own — its
/// `settings` is set here either way, since forgetting that cascade is the
/// harness's most common silent failure. The host is a fake, never null:
/// a test of the unbooted state (every `extensions.host == null` guard in
/// lib) passes `extensions: ExtensionService()`. [prefs] replace the mock
/// SharedPreferences store; null leaves the store as the test already set
/// it. Secure storage is [FakeSecureStorage] unless [secureStorage] says
/// otherwise: the real plugin has no platform channel under test. [catalog]
/// replaces the lazy extension catalog for a test that opens it — the real
/// one would reach catalog.ham2k.net. [cat] builds a CatService over the
/// settings this creates — a builder, because CatService needs them and they
/// do not exist until here — and stands in for one that can otherwise only
/// reach a radio through hardware. [db] hands in a database double; one made
/// here is closed for you, one handed in is yours to manage.
Future<HaLoHarness> makeHaLoServices({
  Map<String, Object>? prefs = const {},
  Map<String, Object?> stubs = const {},
  ExtensionService? extensions,
  FlutterSecureStorage? secureStorage,
  CatalogService? catalog,
  HaLoDatabase? db,
  CatService Function(SettingsService settings)? cat,
  CatTrafficLog? catTrafficLog,
}) async {
  if (prefs != null) SharedPreferences.setMockInitialValues({...prefs});
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: secureStorage ?? FakeSecureStorage());
  // As the boot does before the services exist. Unseeded, every harness reads
  // as an install still on the retired built-ins, and a real runtime's
  // catch-up moves it — with a notice — under whatever the test is about.
  await settings.seedExtensionsMigratedDefault();
  // Only a database this harness OWNS gets closed for the caller: one handed
  // in may be a double whose close is the thing under test, and closing it
  // here would fail the test in teardown rather than in its body.
  final HaLoDatabase database;
  if (db != null) {
    database = db;
  } else {
    database = HaLoDatabase(NativeDatabase.memory());
    addTearDown(database.close);
  }
  final ext = (extensions ?? ExtensionServiceWithFakeHost(FakeExtensionHost(stubs)))..settings = settings;
  return HaLoHarness(
    services: HaLoServices(database, settings, extensions: ext, catalog: catalog, cat: cat?.call(settings), catTrafficLog: catTrafficLog),
    db: database,
    settings: settings,
    extensions: ext,
  );
}

/// Pumps [build]'s widget inside the `TranslationProvider` + `MaterialApp`
/// pair every app widget needs, over a [makeHaLoServices] graph (or
/// [harness], when the test had to prepare data before mounting), and pumps
/// one frame.
///
/// [size] sets the test view's logical size at pixel ratio 1 and restores it
/// at tearDown. [prefs], [stubs] and [extensions] build the harness, so they
/// are refused alongside [harness], which already has them.
///
/// The tree is replaced by an empty box at tearDown, BEFORE the database
/// closes (tearDowns run last-registered first). On a passing test the
/// binding has already unmounted everything; this is for a FAILING one,
/// where the tree stays up and a closed-database stream error would
/// otherwise land on top of the real failure. It is not an in-body
/// unmount: a test whose subject arms timers still drains them itself
/// before the binding's pending-timer check.
Future<HaLoHarness> pumpHaLo(
  WidgetTester tester,
  Widget Function(HaLoServices services) build, {
  HaLoHarness? harness,
  Map<String, Object>? prefs = const {},
  Map<String, Object?> stubs = const {},
  ExtensionService? extensions,
  Size? size,
  ThemeData? theme,
}) async {
  assert(
    harness == null || (extensions == null && stubs.isEmpty && (prefs?.isEmpty ?? true)),
    'pumpHaLo: a harness was passed, so prefs/stubs/extensions would be ignored',
  );
  final h = harness ?? await makeHaLoServices(prefs: prefs, stubs: stubs, extensions: extensions);
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(theme: theme, home: build(h.services)),
    ),
  );
  await tester.pump();
  return h;
}

/// Pumps [frames] frames of [step] each — bounded, where `pumpAndSettle`
/// would never return: anything with a `WallClock` in the tree schedules a
/// frame every second, so a settle loop always finds another one and runs
/// into its ten-minute timeout. The defaults are what the Home view's tests
/// settle on (its FAB and header animate for under a second); a subject
/// that needs longer says so in [frames] or [step].
Future<void> settleFrames(WidgetTester tester, {int frames = 12, Duration step = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}
