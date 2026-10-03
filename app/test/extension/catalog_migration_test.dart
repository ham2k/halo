// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The move off the built-ins the app no longer has, and the catch-up that
// keeps an install's catalog extensions in hand. The move is unasked and has
// nothing to fall back on, so what it must never do is drop what the operator
// had: every on/off choice follows its built-in to the twin — on a boot with
// no network, and over twins an earlier attempt already installed — and one
// twin that will not run costs only itself, never the rest.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extensions/extension_disabled_since.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

/// A catch-up whose pre-load and adoption answer as told, and whose runtime
/// always comes back.
class _CatchUp extends ExtensionServiceWithFakeHost {
  _CatchUp({this.preloaded = false}) : super(FakeExtensionHost({}));

  final bool preloaded;
  int restarts = 0;

  @override
  Future<bool> preloadShippedExtensions() async => preloaded;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// One twin will not evaluate. The runtime comes back only once that bundle
/// has been put aside, which is what a quarantine has to be worth.
class _OneBadBundle extends ExtensionServiceWithFakeHost {
  _OneBadBundle(this.culprit, {this.staysBroken = false}) : super(FakeExtensionHost({}));

  final String culprit;

  /// Nothing the catch-up does brings the runtime back — a second bundle is
  /// broken, or the fault was never the one the boot named.
  final bool staysBroken;

  int restarts = 0;

  bool get _quarantined => settings?.extensionRefused.containsKey(culprit) ?? false;

  @override
  ExtensionHost? get host => !staysBroken && _quarantined ? fakeHost : null;

  @override
  String? get lastStartFailureKey => staysBroken || !_quarantined ? culprit : null;

  @override
  Future<bool> preloadShippedExtensions() async => true;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

/// A catch-up that hangs where a real one does its installing, so a second
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

class _PreloadThrows extends ExtensionServiceWithFakeHost {
  _PreloadThrows() : super(FakeExtensionHost({}));

  @override
  Future<bool> preloadShippedExtensions() async => throw StateError('no store on this platform');
}

/// A catalog listing exactly [keys], or unreachable when [keys] is null.
/// Every download fails: nothing in these tests is meant to install.
class _Catalog extends CatalogService {
  _Catalog(this.keys, {super.settings});

  final List<String>? keys;

  /// The channel of every listing asked for.
  final asked = <CatalogChannel>[];

  @override
  Future<List<int>> download(CatalogRelease release, {void Function(double? fraction)? onProgress}) async => throw StateError('offline');

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false, CatalogChannel? channel}) async {
    asked.add(channel ?? searchChannel);
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

Future<SettingsService> _settings({bool migrated = false}) async {
  SharedPreferences.setMockInitialValues(const {});
  final settings = SettingsService(await SharedPreferences.getInstance());
  if (migrated) await settings.setExtensionsMigrated(true);
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which installs have a move to make', () {
    test('a new install has none', () async {
      final settings = await _settings();
      await settings.seedExtensionsMigratedDefault();
      expect(settings.extensionsMigrated, isTrue);
    });

    test('an install that has been through onboarding does', () async {
      // Its flag was never written, and it ran the built-ins: read as new, it
      // would skip the move and its twins would arrive without the choices it
      // made. A skipped onboarding writes an empty callsign, and counts.
      for (final call in ['KI2D', '']) {
        final settings = await _settings();
        await settings.setProfileOperatorCall(SettingsService.defaultProfileId, call);
        await settings.seedExtensionsMigratedDefault();
        expect(settings.extensionsMigrated, isFalse, reason: 'callsign "$call"');
      }
    });

    test('the answer is decided once, not on every boot', () async {
      // Onboarding sets a callsign after the first boot's seed; a second boot
      // re-deciding from that would put a new install through a move it has
      // nothing to carry for.
      final settings = await _settings();
      await settings.seedExtensionsMigratedDefault();
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      await settings.seedExtensionsMigratedDefault();
      expect(settings.extensionsMigrated, isTrue);
    });
  });

  group('the move', () {
    test('carries each built-in choice over twins an earlier attempt installed', () async {
      // The pre-load carries a choice only on a twin's first install. Twins a
      // previous build's upgrade left behind still hold that attempt's
      // choices — SOTA switched on in between would stay off.
      final settings = await _settings();
      await settings.setExtensionOverrides({'sota': true, 'ham2k-sota': false});
      await catchUpOnCatalogExtensions(_CatchUp()..settings = settings);
      expect(settings.extensionOverrides['ham2k-sota'], isTrue);
      expect(settings.extensionsMigrated, isTrue);
    });

    test('is made once: a later choice on the twin is not undone by the built-in\'s', () async {
      // After the move the twin is the extension the operator switches. The
      // built-in's override outlives it, so re-carrying on every boot would
      // put every twin back the way its built-in was left.
      final settings = await _settings(migrated: true);
      await settings.setExtensionOverrides({'sota': true, 'ham2k-sota': false});
      await catchUpOnCatalogExtensions(_CatchUp()..settings = settings);
      expect(settings.extensionOverrides['ham2k-sota'], isFalse);
    });

    test('completes with no catalog to reach', () async {
      // The twins are shipped. A boot with no network still moves the install
      // onto them; waiting for the catalog would leave it on core alone, with
      // the built-ins gone and nothing in their place.
      final settings = await _settings();
      await catchUpOnCatalogExtensions(_CatchUp(preloaded: true)..settings = settings);
      expect(settings.extensionsMigrated, isTrue);
    });

    test('that throws part way is reported, and made again next boot', () async {
      // The flag is written last, so the next boot carries the choices again
      // rather than leaving twins the pre-load never reached without them.
      final settings = await _settings();
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async => catchUpOnCatalogExtensions(_PreloadThrows()..settings = settings), backend: backend);
      expect(backend.exceptions, isNotEmpty);
      expect(settings.extensionsMigrated, isFalse);
    });

    test('tells the operator, naming what came along with no twin', () async {
      // Unasked and usually unnoticed — except by an operator whose QSO
      // Parties are gone. That one line is the only way they learn to look
      // for the per-party extensions.
      final settings = await _settings();
      await settings.setExtensionOverrides({'qp': true});
      final statusBar = StatusBarService(settings.prefs);
      await catchUpOnCatalogExtensions(
        _CatchUp()
          ..settings = settings
          ..statusBar = statusBar,
      );
      final notice = statusBar.activeNotices.firstWhere((notice) => notice.key == 'extensions:upgradeResult');
      expect(notice.text, contains('QSO Parties'));
      expect(notice.text, isNot(contains('State Parks')), reason: 'switched off, so not something they lost');
    });

    test('says nothing to an install that never ran the built-ins', () async {
      final settings = await _settings(migrated: true);
      final statusBar = StatusBarService(settings.prefs);
      await catchUpOnCatalogExtensions(
        _CatchUp(preloaded: true)
          ..settings = settings
          ..statusBar = statusBar,
      );
      expect(statusBar.activeNotices.where((notice) => notice.key == 'extensions:upgradeResult'), isEmpty);
    });
  });

  group('the notice', () {
    StatusBarNotice? noticeOf(StatusBarService statusBar) => statusBar.activeNotices.where((n) => n.key == 'extensions:upgradeResult').firstOrNull;
    const wca = ExtensionInfo(key: 'ham2k-wca', file: 'ham2k-wca.js', source: ExtensionSource.installed, core: false, name: 'WCA', version: '0.2.1');

    test('never calls a runtime that will not start "ready"', () async {
      // The one thing this notice must not do is reassure over an install
      // running no extensions at all.
      final settings = await _settings();
      final statusBar = StatusBarService(settings.prefs);
      await withErrorHooks(
        () async => catchUpOnCatalogExtensions(
          _OneBadBundle('ham2k-wca', staysBroken: true)
            ..settings = settings
            ..statusBar = statusBar
            ..debugSetAvailableExtensions(const [wca]),
        ),
      );
      final notice = noticeOf(statusBar)!;
      expect(notice.title, t.extensionsPanel.upgradeRuntimeDeadTitle);
      expect(notice.text, contains(t.extensionsPanel.runtimeDeadBody));
    });

    test('names an extension put aside on any catch-up, not only the move', () async {
      // An app update's newer pre-load that will not evaluate is set aside on
      // an ordinary boot; without a word, the operator's extension is simply
      // gone.
      final settings = await _settings(migrated: true);
      final statusBar = StatusBarService(settings.prefs);
      await catchUpOnCatalogExtensions(
        _OneBadBundle('ham2k-wca')
          ..settings = settings
          ..statusBar = statusBar
          ..debugSetAvailableExtensions(const [wca]),
      );
      final notice = noticeOf(statusBar)!;
      expect(notice.title, t.extensionsPanel.refusedTitle);
      expect(notice.text, contains('WCA'));
    });

    test('counts the twins that have not arrived yet', () async {
      // The move is done, and recorded so, before every twin is in hand when
      // one has to come from an unreachable catalog. Saying "ready" alone
      // leaves the operator looking for an extension with no word of it.
      final settings = await _settings();
      await settings.setExtensionOverrides({'wca': true});
      final statusBar = StatusBarService(settings.prefs);
      await catchUpOnCatalogExtensions(
        _CatchUp()
          ..settings = settings
          ..statusBar = statusBar
          // What the pre-load leaves: the five on by default, installed.
          ..debugSetAvailableExtensions([
            for (final key in ['pota', 'qrz', 'call-notes', 'spot-history', 'call-history'])
              ExtensionInfo(key: twinOf(key), file: 'index.js', source: ExtensionSource.installed, core: false, name: key),
          ]),
      );
      expect(noticeOf(statusBar)!.text, contains(t.extensionsPanel.upgradeDoneMissing(count: 1)), reason: 'WCA, switched on and not yet here');
    });
  });

  test('a catch-up with no settings wired yet does not count as the first', () async {
    // The boot starts the runtime before the services wire settings in. A
    // catch-up that ran then and counted would leave the whole session on the
    // core extensions alone: no move, no pre-load, and nothing to run it again.
    final extensions = _CatchUp();
    expect(await catchUpOnCatalogExtensions(extensions), isFalse);
    expect(extensions.firstCatchUpSettled, isFalse);
  });

  test('a retired built-in with no twin is named in the operator\'s language', () async {
    // The rest of the notice is in their language. Naming it in English
    // names something they have never seen under that name.
    await LocaleSettings.setLocale(AppLocale.es);
    addTearDown(() => LocaleSettings.setLocale(AppLocale.en));
    final settings = await _settings();
    await settings.setExtensionOverrides({'qp': true});
    expect(unservedBuiltInNames(settings), ['Concursos Estatales']);
  });

  test('the extension service gets the real catalog, not the test override', () async {
    // The production graph passes no `catalog:`, so a `catalog` read from
    // inside the constructor resolves to that NULL parameter rather than to
    // the lazy field of the same name. Wired that way nothing is ever fetched
    // or adopted — and no test sees it, because a test that cares about the
    // catalog always passes one in.
    final h = await makeHaLoServices();
    expect(identical(h.services.extensions.catalog, h.services.catalog), isTrue);
  });

  group('one twin that will not evaluate', () {
    const wca = ExtensionInfo(key: 'ham2k-wca', file: 'ham2k-wca.js', source: ExtensionSource.installed, core: false, name: 'WCA', version: '0.2.1');

    test('is put aside so the others still run', () async {
      // `EngineRuntime.load` throws if ANY bundle fails, so one bad bundle
      // takes the whole generation with it — every extension the operator
      // has, with no built-ins left to fall back on. The boot names the
      // culprit, so the rest do not have to go down with it.
      final settings = await _settings();
      final extensions = _OneBadBundle('ham2k-wca')
        ..settings = settings
        ..debugSetAvailableExtensions(const [wca]);

      await catchUpOnCatalogExtensions(extensions);

      // Recorded against the VERSION, so the next release of the same
      // extension is given its chance by an ordinary update.
      expect(settings.extensionRefused, {'ham2k-wca': '0.2.1'});
      expect(extensions.restarts, 2);
      // Its OWN sentence, not the no-twin one: this extension is installed
      // and served, and telling the operator the catalog has no replacement
      // would send them looking for a substitute that already exists.
      expect(refusedExtensionNames(extensions), ['WCA']);
      expect(unservedBuiltInNames(settings), isEmpty);
    });

    test('stays out, and is reported, when putting it aside did not get a runtime back', () async {
      // Re-admitted, it kills the next boot too. What keeping it out costs is
      // a name, which the notice carries; the report is the only way to tell
      // one corrupt download from a release broken for everybody.
      final settings = await _settings();
      final extensions = _OneBadBundle('ham2k-wca', staysBroken: true)
        ..settings = settings
        ..debugSetAvailableExtensions(const [wca]);

      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async => catchUpOnCatalogExtensions(extensions), backend: backend);

      expect(settings.extensionRefused, {'ham2k-wca': '0.2.1'});
      expect(backend.exceptions.map((e) => e.error).whereType<UpgradeLeftNoRuntime>(), isNotEmpty);
    });

    test('is not put aside twice when it was already out of the set', () async {
      // The boot names the same key that is already refused at this version,
      // so putting it aside changes nothing. Unguarded, the catch-up restarts
      // the runtime for a set that cannot differ.
      final settings = await _settings();
      await settings.setExtensionRefused({'ham2k-wca': '0.2.1'});
      final extensions = _OneBadBundle('ham2k-wca', staysBroken: true)
        ..settings = settings
        ..debugSetAvailableExtensions(const [wca]);

      await withErrorHooks(() async => catchUpOnCatalogExtensions(extensions));

      expect(extensions.restarts, 1, reason: 'the catch-up\'s own boot, and no second');
    });
  });

  test('a pass already running is stepped aside from, not run twice', () async {
    // Every restart re-enters the catch-up from `_start`. A second pass over
    // the same snapshot installs the same keys twice, and whichever writes its
    // records last discards the other's.
    final settings = await _settings();
    final extensions = _StillRunning()..settings = settings;

    final first = catchUpOnCatalogExtensions(extensions);
    await extensions.started.future;

    expect(await catchUpOnCatalogExtensions(extensions), isFalse);

    extensions.release.complete();
    expect(await first, isTrue, reason: 'the pass that held the flag still finishes');
  });

  group('which twins the adoption asks the catalog for', () {
    // A listing lacks a twin the same way whether the catalog will never serve
    // it or has not published it yet. Only the first may be treated as
    // answered, and those are named in `kBuiltInsWithoutTwin`.
    ExtensionInfo installed(String key) => ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.installed, core: false, name: key);

    /// The five retired built-ins that were on by default, installed — as the
    /// pre-load leaves them.
    final preloaded = [
      for (final key in ['pota', 'qrz', 'call-notes', 'spot-history', 'call-history']) installed(twinOf(key)),
    ];

    Future<({bool landed, bool complete})> adopt(SettingsService settings, CatalogService catalog) => adoptCatalogTwins(
      store: InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {}),
      settings: settings,
      catalog: catalog,
      available: preloaded,
      recordInstall: (_, {required fresh}) async => fail('nothing here installs'),
      copySecrets: ({required from, required to}) async {},
    );

    test('an install that never switched anything asks for nothing', () async {
      // It falls back to each built-in's default, and the ones on by default
      // are the ones pre-loaded — so an unreachable catalog is never even
      // asked, and a new install is never told its extensions are incomplete.
      final settings = await _settings(migrated: true);
      final result = await adopt(settings, _Catalog(null));
      expect(result.complete, isTrue);
    });

    test('twins are read from stable releases, whatever the developer searches', () async {
      // Twins install with no consent screen. Reading the developer's search
      // track here would install bleeding releases unseen, and record each
      // as following bleeding for good.
      final settings = await _settings(migrated: true);
      await settings.setDeveloperMode(true);
      await settings.setCatalogSearchChannel(CatalogChannel.bleeding);
      await settings.setExtensionOverrides({'wca': true});
      final catalog = _Catalog(null, settings: settings);

      await adopt(settings, catalog);
      expect(catalog.asked, [CatalogChannel.stable]);
    });

    test('a pre-loaded twin the operator uninstalled is not fetched back', () async {
      // Its built-in's choice — or its default, on for QRZ — still reads as
      // on. Fetched again, the uninstall is undone at the next restart, and
      // the old login is copied back with it.
      final settings = await _settings(migrated: true);
      await settings.setExtensionPreloaded({'ham2k-qrz': '0.2.0'});
      final result = await adoptCatalogTwins(
        store: InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {}),
        settings: settings,
        catalog: _Catalog(const ['ham2k-qrz']),
        available: [
          for (final installed in preloaded)
            if (installed.key != 'ham2k-qrz') installed,
        ],
        recordInstall: (_, {required fresh}) async => fail('nothing here installs'),
        copySecrets: ({required from, required to}) async {},
      );
      expect(result.complete, isTrue);
    });

    test('a retired built-in with no twin is never asked for, and not recorded', () async {
      // Asking the listing for `ham2k-qp` can only fail, so an operator with
      // it switched on would never have a complete adoption. And a record
      // would be read as "already asked" the day the catalog serves it.
      final settings = await _settings(migrated: true);
      await settings.setExtensionOverrides({'qp': true, 'stateparks': true});

      final result = await adopt(settings, _Catalog(null));

      expect(result.complete, isTrue);
      expect(settings.extensionAdopted, isEmpty);
    });

    test('a listing of only the pre-loads answers nothing about the rest', () async {
      // A channel part way through publishing carries exactly these. Counting
      // them as proof the listing is whole retires every other twin for good.
      final settings = await _settings(migrated: true);
      await settings.setExtensionOverrides({'wca': true});

      final result = await adopt(settings, _Catalog(const ['ham2k-pota']));

      expect(result.complete, isFalse);
      expect(settings.extensionAdopted, isEmpty);
    });

    test('a twin missing beside ones that are listed is asked for again', () async {
      // The listing is plainly real here, and `ham2k-gma` is still absent —
      // dropped as unparseable, or filtered by the `api` parameter, or not yet
      // published. None of those is the catalog saying it will never serve it.
      final settings = await _settings(migrated: true);
      await settings.setExtensionOverrides({'gma': true});

      final result = await adopt(settings, _Catalog(const ['ham2k-pota', 'ham2k-wca']));

      expect(result.complete, isFalse);
      expect(settings.extensionAdopted.containsKey('ham2k-gma'), isFalse);
    });
  });

  group('the disabled-since stamp', () {
    // Judged by KEY: should the list ever hold a key twice, the inactive copy
    // would stamp the key its live twin runs under, and seven days on the
    // purge deletes the running extension's downloaded data.
    const asset = ExtensionInfo(key: 'ham2k-lookup', file: 'ham2k-lookup.js', core: false, name: 'Lookup');
    const installed = ExtensionInfo(key: 'ham2k-lookup', file: 'ham2k-lookup.js', core: false, name: 'Lookup', source: ExtensionSource.installed);
    bool assetIsLive(ExtensionInfo info) => info.source == ExtensionSource.asset;

    test('a key with two entries is judged by the one that is live', () async {
      final settings = await _settings();
      await updateExtensionDisabledSince(settings: settings, available: const [asset, installed], isActive: assetIsLive);
      expect(settings.extensionDisabledSince.containsKey('ham2k-lookup'), isFalse);
    });

    test('and by the live one whichever order the two arrive in', () async {
      final settings = await _settings();
      await updateExtensionDisabledSince(settings: settings, available: const [installed, asset], isActive: assetIsLive);
      expect(settings.extensionDisabledSince.containsKey('ham2k-lookup'), isFalse);
    });

    test('a key with no live entry is still stamped', () async {
      final settings = await _settings();
      await updateExtensionDisabledSince(settings: settings, available: const [asset, installed], isActive: (_) => false);
      expect(settings.extensionDisabledSince.containsKey('ham2k-lookup'), isTrue);
    });

    test('a retired built-in is stamped, so the purge clears what it left', () async {
      // It never runs again, and nothing lists it: unstamped, the data files
      // it downloaded would stay on disk beside its twin's for good.
      final settings = await _settings();
      await updateExtensionDisabledSince(settings: settings, available: const [installed], isActive: (_) => true);
      expect(settings.extensionDisabledSince.keys, containsAll(['pota', 'wca', 'qp']));
    });
  });
}
