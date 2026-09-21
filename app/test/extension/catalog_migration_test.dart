// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move to catalog extensions. Its whole safety property is that
// nothing is taken away until the replacements are in hand: the operator may
// defer it, may be offline when it is offered, and may lose the connection
// half way through — and in every one of those cases they keep the extensions
// they had. A migration that withdrew first and downloaded second would look
// identical on a good connection.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
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
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// Every twin lands and the first restart brings nothing back; [revives] says
/// whether the revert's restart does, which is the difference between "the
/// ones you had are back" and an install running nothing at all.
class _RuntimeNeverComesBack extends ExtensionServiceWithFakeHost {
  _RuntimeNeverComesBack({this.revives = false});

  final bool revives;

  int restarts = 0;

  @override
  ExtensionHost? get host => revives && restarts > 1 ? fakeHost : null;

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// The runtime comes back, and something after the host was installed threw:
/// the host is in place and a backoff restart is queued behind it.
class _BootsThenSchedulesRestart extends ExtensionServiceWithFakeHost {
  _BootsThenSchedulesRestart() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}

  @override
  String? get lastStartFailureKey => null;
}

/// One twin will not evaluate. The runtime comes back only once that bundle
/// has been put aside, which is what a quarantine has to be worth.
class _OneBadBundle extends ExtensionServiceWithFakeHost {
  _OneBadBundle(this.culprit, {this.staysBroken = false}) : super(FakeExtensionHost({}));

  final String culprit;

  /// Nothing this migration does brings the runtime back — a second bundle
  /// is broken, or the fault was never the one the boot named.
  final bool staysBroken;

  int restarts = 0;

  bool get _quarantined => settings?.extensionRefused.containsKey(culprit) ?? false;

  @override
  ExtensionHost? get host => !staysBroken && _quarantined ? fakeHost : null;

  @override
  String? get lastStartFailureKey => staysBroken || !_quarantined ? culprit : null;

  @override
  Future<bool> preloadShippedExtensions() async => false;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: true, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// A migration that hangs where a real one does its downloading, so a second
/// call arrives while the first still holds the flag.
class _StillRunning extends ExtensionServiceWithFakeHost {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> preloadShippedExtensions() async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return false;
  }

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
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
      expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.failed);
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

    expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.incomplete);

    expect(settings.extensionsMigrated, isFalse);
    expect(extensions.reloads, greaterThan(1), reason: 'the list still predates the twins that landed');
    expect(extensions.restarts, 1);
  });

  group('a runtime that does not come back', () {
    test('is not reported as a finished upgrade, and the built-ins are running again', () async {
      // `restartRuntime` cannot throw — `_start` catches a boot failure into
      // the crash backoff — so a migration that trusted it reported success
      // over an install with NO extensions at all: one twin that will not
      // evaluate takes the whole generation down with it.
      final settings = await _settings(experiment: true);
      final extensions = _RuntimeNeverComesBack(revives: true)..settings = settings;

      expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.runtimeReverted);

      expect(settings.extensionsMigrated, isFalse, reason: 'the twins stay out of the bundle set');
      expect(extensions.isBuiltInOffered(_builtIn), isTrue);
      // The flag alone only decides what a boot WOULD load. Without a second
      // restart the operator reads "your extensions are back" while none run.
      expect(extensions.restarts, 2, reason: 'nothing booted the reverted set');
    });

    test('and a revert that does not boot either is not called a recovery', () async {
      // The message for the case above is "the ones you had are back and
      // working". Said over an install running NO extensions — the second
      // boot failing for a reason the twins never caused — it is the worst
      // answer this can give, and the second restart cannot report its own
      // failure any more than the first could.
      final settings = await _settings(experiment: true);
      final extensions = _RuntimeNeverComesBack()..settings = settings;

      final reports = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.runtimeDead);
      }, backend: reports);

      expect(settings.extensionsMigrated, isFalse);
      expect(reports.exceptions.map((e) => e.error).whereType<UpgradeLeftNoRuntime>(), isNotEmpty,
          reason: 'the rate is the only way to tell one bad download from a broken release');
    });
  });

  test('a runtime that boots and then schedules a restart is still a finished upgrade', () async {
    // `_start` installs the host and keeps going — the activation wait, the
    // account-flag refresh that reaches the keychain and is refused on a
    // locked macOS. A throw there schedules a backoff restart over a
    // generation that is loaded and serving hooks. Read as a failure, one
    // keychain prompt reverts a perfectly good upgrade.
    final settings = await _settings(experiment: true);
    final extensions = _BootsThenSchedulesRestart()..settings = settings;

    expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.done);

    expect(settings.extensionsMigrated, isTrue);
    expect(settings.extensionRefused, isEmpty);
  });

  group('one twin that will not evaluate', () {
    test('is put aside so the other thirty still arrive', () async {
      // `EngineRuntime.load` throws if ANY bundle fails, so one bad download
      // takes the whole generation with it. Reverting the whole upgrade over
      // it costs the operator every extension they were promised, and the
      // boot names the culprit — so the rest do not have to go down with it.
      final settings = await _settings(experiment: true);
      final extensions = _OneBadBundle('ham2k-wca')
        ..settings = settings
        ..debugSetAvailableExtensions(const [
          ExtensionInfo(
            key: 'ham2k-wca',
            file: 'ham2k-wca.js',
            source: ExtensionSource.installed,
            core: false,
            name: 'WCA',
            version: '0.2.1',
          ),
        ]);

      expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.done);

      expect(settings.extensionsMigrated, isTrue, reason: 'the upgrade finished, minus one extension');
      expect(settings.extensionRefused, {'ham2k-wca': '0.2.1'});
      expect(extensions.restarts, 2);
      // Recorded against the VERSION, so the next release of the same
      // extension is given its chance by an ordinary update.
      // Its OWN sentence, not the no-twin one: this extension is installed
      // and served, and telling the operator the catalog has no replacement
      // would send them looking for a substitute that already exists.
      expect(refusedExtensionNames(extensions), ['WCA']);
      expect(unservedBuiltInNames(extensions), isEmpty);
    });

    test('is recorded against the INSTALLED copy when the key is also an asset', () async {
      // `ham2k-lookup` ships as an asset AND is pre-loaded from the catalog,
      // and the available list puts the asset first. Recording that one's
      // version refuses the app's own built-in for good, while the installed
      // bundle that actually failed stays in the set and fails again.
      final settings = await _settings(experiment: true);
      final extensions = _OneBadBundle('ham2k-lookup')
        ..settings = settings
        ..debugSetAvailableExtensions(const [
          ExtensionInfo(key: 'ham2k-lookup', file: 'ham2k-lookup.js', core: false, name: 'Lookup', version: '0.0.1'),
          ExtensionInfo(
            key: 'ham2k-lookup',
            file: 'ham2k-lookup.js',
            source: ExtensionSource.installed,
            core: false,
            name: 'Lookup',
            version: '0.2.1',
          ),
        ]);

      expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.done);

      expect(settings.extensionRefused, {'ham2k-lookup': '0.2.1'});
      // Named once, though the key is in the list twice.
      expect(refusedExtensionNames(extensions), ['Lookup']);
    });

    test('stays out even when putting it aside did not get a runtime back', () async {
      // Dropping the record here re-admits the bundle to the REVERTED set,
      // where an extension with no built-in behind it — a sideloaded one, or
      // a catalog-only one installed earlier — kills the boot that was about
      // to give the operator everything back. It still will not evaluate;
      // what that costs is a name, which every dialog carries.
      final settings = await _settings(experiment: true);
      final extensions = _OneBadBundle('ham2k-wca', staysBroken: true)
        ..settings = settings
        ..debugSetAvailableExtensions(const [
          ExtensionInfo(
            key: 'ham2k-wca',
            file: 'ham2k-wca.js',
            source: ExtensionSource.installed,
            core: false,
            name: 'WCA',
            version: '0.2.1',
          ),
        ]);

      await withErrorHooks(() async {
        expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.runtimeDead);
      });

      expect(settings.extensionRefused, {'ham2k-wca': '0.2.1'});
      expect(refusedExtensionNames(extensions), ['WCA'], reason: 'the dialog has to name what stayed out');
    });

    test('is not named once the revert has put its built-in back', () async {
      // After a revert the downloaded copy is superseded: its panel row is
      // gone, there is nothing to update, and the POTA the operator knows is
      // running. "Would not run: POTA" over a working POTA tells them
      // something false twice over.
      final settings = await _settings(experiment: true);
      await settings.setExtensionRefused({'ham2k-pota': '0.2.1'});
      final extensions = ExtensionServiceWithFakeHost()
        ..settings = settings
        ..debugSetAvailableExtensions(const [
          ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA'),
          ExtensionInfo(
            key: 'ham2k-pota',
            file: 'ham2k-pota.js',
            source: ExtensionSource.installed,
            core: false,
            name: 'POTA',
            version: '0.2.1',
          ),
        ]);

      expect(refusedExtensionNames(extensions), isEmpty);
    });

    test('is not put aside twice when it was already out of the set', () async {
      // The boot names the same key that is already refused at this version,
      // so putting it aside changes nothing. Unguarded, the upgrade restarts
      // the runtime for a set that cannot differ — a third boot on a path
      // that has already failed twice.
      final settings = await _settings(experiment: true);
      await settings.setExtensionRefused({'ham2k-wca': '0.2.1'});
      final extensions = _OneBadBundle('ham2k-wca', staysBroken: true)
        ..settings = settings
        ..debugSetAvailableExtensions(const [
          ExtensionInfo(
            key: 'ham2k-wca',
            file: 'ham2k-wca.js',
            source: ExtensionSource.installed,
            core: false,
            name: 'WCA',
            version: '0.2.1',
          ),
        ]);

      await withErrorHooks(() async {
        expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.runtimeDead);
      });

      expect(extensions.restarts, 2, reason: 'the upgrade boot and the revert boot, and no third');
    });
  });

  test('a pass already running is not reported as a failure', () async {
    // The boot's own catch-up holds the flag. Nothing failed, nothing was
    // withdrawn, and the same button works a moment later — telling the
    // operator the upgrade failed sends them chasing a problem they do not
    // have.
    final settings = await _settings(experiment: true);
    final extensions = _StillRunning()..settings = settings;

    final first = migrateToCatalogExtensions(extensions);
    await extensions.started.future;

    expect(await migrateToCatalogExtensions(extensions), UpgradeOutcome.busy);

    extensions.release.complete();
    expect(await first, UpgradeOutcome.done, reason: 'the pass that held the flag still finishes');
  });

  test('a service with no settings is a wiring defect, and says so', () async {
    // Answered false silently, it read as an ordinary failed upgrade — with
    // nothing in the console or the crash backend to say the graph was wrong.
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      expect(await migrateToCatalogExtensions(ExtensionServiceWithFakeHost()), UpgradeOutcome.notWired);
    }, backend: backend);

    expect(backend.exceptions.map((e) => e.error).whereType<SettingsNotWired>(), isNotEmpty);
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
