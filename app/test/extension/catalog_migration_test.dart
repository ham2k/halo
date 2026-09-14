// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move to catalog extensions. Its whole safety property is that
// nothing is taken away until the replacements are in hand: the operator may
// defer it, may be offline when it is offered, and may lose the connection
// half way through — and in every one of those cases they keep the extensions
// they had. A migration that withdrew first and downloaded second would look
// identical on a good connection.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/services/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extension_disabled_since.dart';
import 'package:ham2k_logger/services/extension_info.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

const _builtIn = ExtensionInfo(key: 'wca', file: 'wca.js', core: false, name: 'WCA');

/// The pre-load is the first thing the migration does, and the flag is
/// already written by then.
class _PreloadThrows extends ExtensionServiceWithFakeHost {
  _PreloadThrows() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => throw StateError('no store on this platform');
}

Future<SettingsService> _settings({bool experiment = false, bool migrated = false}) async {
  SharedPreferences.setMockInitialValues(const {});
  final settings = SettingsService(await SharedPreferences.getInstance());
  if (experiment) await settings.setExperimentEnabled(kCatalogExperiment, true);
  if (migrated) await settings.setExtensionsMigrated(true);
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what the two flags mean together', () {
    test('the experiment alone withdraws nothing', () async {
      // The whole reason "Later" is safe to offer. Turning the experiment on
      // used to withdraw every built-in on the spot, so an operator who
      // deferred the upgrade — or who was offline when it was offered — was
      // left with no extensions at all.
      final settings = await _settings(experiment: true);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      expect(settings.catalogExtensionsInUse, isFalse);
      expect(extensions.isBuiltInOffered(_builtIn), isTrue);
    });

    test('migrated alone withdraws nothing either', () async {
      // Turning the experiment back off restores the built-ins without
      // forgetting the upgrade happened, so turning it on again does not
      // re-run it.
      final settings = await _settings(migrated: true);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      expect(settings.catalogExtensionsInUse, isFalse);
      expect(extensions.isBuiltInOffered(_builtIn), isTrue);
    });

    test('both together is what moves the app to the catalog', () async {
      final settings = await _settings(experiment: true, migrated: true);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      expect(settings.catalogExtensionsInUse, isTrue);
      expect(extensions.isBuiltInOffered(_builtIn), isFalse);
    });
  });

  test('a migration that throws leaves the operator with the extensions they had', () async {
    // The flag is written FIRST — that is what lets the downloads run while
    // the built-ins still work. So the one state this must never end in is
    // migrated with nothing adopted: every non-core built-in withdrawn, no
    // replacement on disk, and the gate never offering again because the flag
    // says it already happened. A clean failure reverts it; a THROWN one has
    // to as well.
    final settings = await _settings(experiment: true);
    final extensions = _PreloadThrows()..settings = settings;

    await withErrorHooks(() async {
      expect(await migrateToCatalogExtensions(extensions), isFalse);
    });

    expect(settings.extensionsMigrated, isFalse);
    expect(settings.catalogExtensionsInUse, isFalse);
    expect(extensions.isBuiltInOffered(_builtIn), isTrue);
  });

  group('the disabled-since stamp', () {
    // `ham2k-lookup` is both a bundle the app ships and one the catalog
    // serves, so it is the one key that appears TWICE in the available list.
    // Whichever copy is not the live one is inactive, and stamping per entry
    // hands the key a disabled-since date while its twin is running — seven
    // days on, the purge deletes the running extension's downloaded data.
    const asset = ExtensionInfo(key: 'ham2k-lookup', file: 'ham2k-lookup.js', core: false, name: 'Lookup');
    const installed = ExtensionInfo(
      key: 'ham2k-lookup',
      file: 'ham2k-lookup.js',
      core: false,
      name: 'Lookup',
      source: ExtensionSource.installed,
    );
    bool assetIsLive(ExtensionInfo info) => info.source == ExtensionSource.asset;

    test('a key with two entries is judged by the one that is live', () async {
      final settings = await _settings();
      await updateExtensionDisabledSince(
          settings: settings, available: const [asset, installed], isActive: assetIsLive);
      expect(settings.extensionDisabledSince, isEmpty);
    });

    test('and by the live one whichever order the two arrive in', () async {
      // The list is assets then disk today, which is the arrangement the test
      // above pins. This one holds the other way round, so a later change to
      // how the two lists are merged cannot quietly bring the stamp back.
      final settings = await _settings();
      await updateExtensionDisabledSince(
          settings: settings, available: const [installed, asset], isActive: assetIsLive);
      expect(settings.extensionDisabledSince, isEmpty);
    });

    test('a key with no live entry is still stamped', () async {
      final settings = await _settings();
      await updateExtensionDisabledSince(
          settings: settings, available: const [asset, installed], isActive: (_) => false);
      expect(settings.extensionDisabledSince.keys, ['ham2k-lookup']);
    });
  });
}
