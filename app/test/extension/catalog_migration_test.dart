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
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/services/catalog_service.dart';
import 'package:ham2k_logger/services/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extension_disabled_since.dart';
import 'package:ham2k_logger/services/extension_info.dart';
import 'package:ham2k_logger/services/extension_relevance.dart';
import 'package:ham2k_logger/services/installed_extensions.dart';
import 'package:ham2k_logger/services/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

const _builtIn = ExtensionInfo(key: 'wca', file: 'wca.js', core: false, name: 'WCA');

/// An adoption that installed some twins and could not finish.
class _PartialAdoption extends ExtensionServiceWithFakeHost {
  _PartialAdoption() : super(FakeExtensionHost({}));

  int reloads = 0;
  int restarts = 0;

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: false);

  @override
  Future<void> reloadAvailableExtensions() async => reloads++;

  @override
  Future<void> restartRuntime() async => restarts++;
}

/// The pre-load is the first thing the migration does, and the flag is
/// already written by then.
class _PreloadThrows extends ExtensionServiceWithFakeHost {
  _PreloadThrows() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => throw StateError('no store on this platform');
}

/// A catalog listing exactly [keys], or unreachable when [keys] is null.
/// Every download fails: nothing in these tests is meant to install.
class _Catalog extends CatalogService {
  _Catalog(this.keys);

  final List<String>? keys;

  @override
  Future<List<int>> download(CatalogRelease release) async => throw StateError('offline');

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async {
    final listed = keys;
    if (listed == null) return null;
    return [
      for (final key in listed)
        CatalogEntry(
          key: key,
          name: key,
          version: '1.0.0',
          sha256: 'a' * 64,
          bundleUrl: Uri.parse('https://catalog.example/api/v1/extensions/$key/versions/1.0.0/bundle'),
        ),
    ];
  }
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

  test('the extension service gets the real catalog, not the test override', () async {
    // The production graph passes no `catalog:`, so a `catalog` read from
    // inside the constructor resolves to that NULL parameter rather than to
    // the lazy field of the same name. Wired that way nothing is ever fetched
    // or adopted and the upgrade offer never appears — and no test sees it,
    // because a test that cares about the catalog always passes one in.
    final h = await makeHaLoServices();
    expect(identical(h.services.extensions.catalog, h.services.catalog), isTrue);
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

  test('twins that landed before the upgrade gave up are still picked up', () async {
    // The flag reverts, so the built-ins those twins supersede are back — and
    // the memoized extension list predates the installs. Left as it is, the
    // rest of the session loads from a list that does not know what is on
    // disk.
    final settings = await _settings(experiment: true);
    final extensions = _PartialAdoption()..settings = settings;

    expect(await migrateToCatalogExtensions(extensions), isFalse);

    expect(settings.extensionsMigrated, isFalse);
    expect(extensions.reloads, greaterThan(1), reason: 'the list still predates the twins that landed');
    expect(extensions.restarts, 1);
  });

  test('a withdrawn built-in is named the way the panel names it', () async {
    // The rest of the dialog is in the operator's language, and `qp` carries a
    // Spanish name. Naming it in English names something they have never seen
    // under that name and cannot find in the Extensions panel.
    await LocaleSettings.setLocale(AppLocale.es);
    addTearDown(() => LocaleSettings.setLocale(AppLocale.en));
    final settings = await _settings(experiment: true, migrated: true);
    final extensions = _PartialAdoption()
      ..settings = settings
      ..debugSetAvailableExtensions(const [
        ExtensionInfo(
          key: 'qp',
          file: 'qp.js',
          core: false,
          name: 'QSO Parties',
          translations: {'es': {'name': 'Concursos Estatales'}},
        ),
      ]);

    expect(unservedBuiltInNames(extensions), ['Concursos Estatales']);
  });

  group('which missing twins end the upgrade', () {
    // A listing lacks a twin the same way whether the catalog will never serve
    // it or has not published it yet. Only the first may be recorded as
    // answered: the record is permanent, the upgrade then withdraws the
    // built-in, and the operator is told the catalog has no replacement.
    ExtensionInfo builtIn(String key) => ExtensionInfo(key: key, file: '$key.js', core: false, name: key);
    const preloaded = ExtensionInfo(
        key: 'ham2k-pota', file: 'ham2k-pota.js', source: ExtensionSource.installed, core: false, name: 'POTA');

    Future<({bool landed, bool complete})> adopt(
      SettingsService settings,
      CatalogService catalog, {
      required List<String> enabled,
    }) =>
        adoptCatalogTwins(
          store: InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {}),
          settings: settings,
          catalog: catalog,
          available: [builtIn('pota'), preloaded, for (final key in enabled) builtIn(key)],
          isEnabled: (info) => info.key == 'pota' || enabled.contains(info.key),
          recordInstall: (_, {required fresh}) async => fail('nothing here installs'),
          copySecrets: ({required from, required to}) async {},
        );

    test('a built-in with no twin is answered without asking, and finishes the upgrade', () async {
      // `qp` is served one extension per party. Asking the listing for
      // `ham2k-qp` can only fail, so an operator with it switched on would
      // fail the upgrade on every launch, forever.
      final settings = await _settings(experiment: true, migrated: true);

      final result = await adopt(settings, _Catalog(null), enabled: const ['qp']);

      expect(result.complete, isTrue);
      // And NOT recorded as answered: a record would be read as "already
      // asked" the day the catalog serves it and it leaves the list.
      expect(settings.extensionAdopted, isEmpty);
    });

    test('a listing of only the pre-loads answers nothing about the rest', () async {
      // The pre-loads are published first and are already installed, so a
      // channel part way through publishing carries exactly these. Counting
      // them as proof the listing is whole retires every other twin for good.
      final settings = await _settings(experiment: true, migrated: true);

      // `qp` rides along so the record IS written here: nothing is persisted
      // when the only key is one the app answered itself.
      final result = await adopt(settings, _Catalog(const ['ham2k-pota']), enabled: const ['wca', 'qp']);

      expect(result.complete, isFalse);
      expect(settings.extensionAdopted, isEmpty);
    });

    test('a twin missing beside ones that are listed is asked for again', () async {
      // The listing is plainly real here, and `ham2k-gma` is still absent —
      // dropped as unparseable, or filtered by the `api` parameter, or not yet
      // published. None of those is the catalog saying it will never serve it.
      final settings = await _settings(experiment: true, migrated: true);

      // `ham2k-wca` is listed but not wanted, so nothing downloads and only
      // the absent `ham2k-gma` can leave the job incomplete.
      final result = await adopt(settings, _Catalog(const ['ham2k-pota', 'ham2k-wca']), enabled: const ['gma']);

      expect(result.complete, isFalse);

      expect(settings.extensionAdopted.containsKey('ham2k-gma'), isFalse);
    });
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
