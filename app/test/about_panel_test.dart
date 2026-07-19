// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The About panel (Issue #42 restyle): a two-line version row (info icon +
// VersionLabel(detailed: true)) replaces the old "About the App" paragraph,
// followed by a "Release Notes" preview of the last few releases. "Recent
// Notices" moved out to its own top-level "Notices & Messages" settings
// panel, so it's no longer part of About. Tapping the preview opens the
// same content in a Modal Pane; tapping the version row copies it; tapping
// the wordmark opens a photo+caption modal.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/settings_view.dart';
import 'package:ham2k_logger/views/version_label.dart';

const _testRelease = ReleaseNotesEntry(
  version: '26.8.0',
  name: "August '26",
  photoCaption: 'M1SDH at GB-4724',
  changes: ['First change', 'Second change'],
);

class _MockExtensionHost implements ExtensionHost {
  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExtensionServiceWithMockHost extends ExtensionService {
  final _MockExtensionHost mockHost = _MockExtensionHost();

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo.setMockInitialValues(
    appName: 'Ham2K Logger',
    packageName: 'com.ham2k.halo.prod',
    version: '0.1.0',
    buildNumber: '260807291',
    buildSignature: '',
  );

  testWidgets('shows the version row and a Release Notes preview; '
      'tapping the preview opens the full text in a Modal Pane', (tester) async {
    // Bypasses the real assets/release-notes.yaml load: a widget test that
    // repeatedly mounts/tears down the full app (database, extension host,
    // asset channel) across several testWidgets blocks can leave a later
    // test's real asset load hanging indefinitely even though it resolved
    // fine on an earlier one — and none of these tests are testing yaml
    // parsing anyway (release_notes_test.dart covers that). Called from
    // inside the test body (not setUp()) — flutter_test's per-test Zone
    // means a Future set up outside it may never notify a FutureBuilder
    // listening from within it.
    setReleaseNotesForTesting([_testRelease]);

    // Wide viewport: settings shows sidebar + panel side by side, so
    // selecting "About" updates the panel in place (no route push needed).
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'About'));
    await tester.pumpAndSettle();

    // Version row: an info icon plus two lines from VersionLabel(detailed).
    // The header above no longer repeats it — just the brand mark there now.
    expect(find.byType(VersionLabel), findsOneWidget);

    // "Release Notes" heading present, and "Recent Notices" is gone from
    // this panel entirely — it moved to its own settings panel.
    expect(find.text('Release Notes'), findsOneWidget);
    expect(find.text('Recent Notices'), findsNothing);

    // Tapping the preview opens the same title as a Modal Pane — the
    // clipped/faded preview never scrolls itself (see settings_view.dart),
    // so a tap must be the only way to read the rest.
    await tester.tap(find.byKey(const Key('aboutReleaseNotesPreview')));
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsNWidgets(2));
  });

  testWidgets('tapping the version row copies the app name and version details to the clipboard', (tester) async {
    setReleaseNotesForTesting([_testRelease]);

    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'About'));
    await tester.pumpAndSettle();

    // VersionLabel renders SelectableText, which owns its own tap recognizer
    // for cursor placement — an IgnorePointer around it (settings_view.dart)
    // is what lets a tap anywhere on the row reach the ListTile's onTap
    // instead of being consumed as a text-selection tap.
    await tester.tap(find.ancestor(of: find.byType(VersionLabel), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();

    // Full app name (platform-dependent: "Ham2K Logger" vs "Ham2K Portable
    // Logger") plus both VersionLabel(detailed) lines, so it's useful pasted
    // straight into a bug report — not just the bare version number.
    expect(copiedText, isNotNull);
    expect(copiedText, contains(ham2kAppName));
    expect(copiedText, contains(kVersionName));
    expect(copiedText, contains(kPublicVersion));
    // Exactly once: this is a two-pane viewport (1000x800), and each pane owns
    // its own ScaffoldMessenger, so the toast must not appear in both halves.
    expect(find.text('Copied version details to clipboard'), findsOneWidget);
  });

  testWidgets('tapping the wordmark opens a photo+wordmark modal with the caption but no notes or Continue button',
      (tester) async {
    setReleaseNotesForTesting([_testRelease]);

    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    // The modal's top section reuses ReleaseOverlayView's credits line,
    // which needs a TranslationProvider ancestor.
    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'About'));
    await tester.pumpAndSettle();

    expect(find.byType(Ham2kBrandMark), findsOneWidget);

    // A tap-coordinate hit test here is unreliable in this harness — the
    // mock extension host's "not ready" status notice (unrelated to this
    // widget) overlaps the header area — so invoke the wired callback
    // directly instead of going through hit-testing.
    final wordmarkTap = tester.widget<GestureDetector>(find.byKey(const Key('aboutWordmark'))).onTap!;
    wordmarkTap();
    await tester.pumpAndSettle();

    // The modal adds its own brand mark on top of the header's, laid out
    // the same as the startup release overlay's top section — brand mark,
    // "by KI2D and friends" credits, the full version name — plus the photo
    // credit at the bottom. Unlike that overlay (release_overlay_test.dart),
    // there's no notes band or Continue button to dismiss.
    expect(find.byType(Ham2kBrandMark), findsNWidgets(2));
    expect(find.textContaining('KI2D'), findsOneWidget);
    // The modal shows the full release name (kVersionName), matching the
    // splash/onboarding — not the shorter release-notes name. The version row
    // behind shows the edition-qualified name, a different exact string.
    expect(find.text(kVersionName), findsOneWidget);
    expect(find.text(_testRelease.photoCaption), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    // Tapping the modal dismisses it, same as the release overlay.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(Ham2kBrandMark), findsOneWidget);
  });
}
