// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator installed, kept apart from the store that holds it, and
// put back when the store comes up short (docs/extensions/distribution.md,
// "When the store is lost"). The traps: the intent following the store, so a
// loss erases the very record that would repair it; boot pruning an absent
// extension's on/off choice before anything restores it; and one extension
// that will not download costing the others theirs.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extensions/extension_disabled_since.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late List<int> clock;

  setUp(() {
    root = Directory.systemTemp.createTempSync('missing-extensions');
    clock = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<(ExtensionService, SettingsService, InstalledExtensions)> setup({CatalogService? catalog}) async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: root),
      reservedPrefixAllowed: (key) => BundleProvenance.fromJson(settings.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
    );
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))
      ..settings = settings
      ..catalog = catalog
      ..debugInstalledStore = store
      ..debugSetAvailableExtensions(const []);
    return (extensions, settings, store);
  }

  Map<String, String> catalogRecord(String version) => {'host': kCatalogHost, 'sha256': sha256Hex(clock), 'version': version};

  test('an install is remembered, and only an uninstall forgets it', () async {
    final (extensions, settings, store) = await setup();
    await extensions.installBundle(await store.inspect(clock));
    expect(settings.extensionsInstalled, {'ki2d-my-clock': 'KI2D My Clock'});
    await extensions.uninstallExtension('ki2d-my-clock');
    expect(settings.extensionsInstalled, isEmpty);
  });

  test('an install that predates the record is seeded from its store once, and a store found short later does not shrink it', () async {
    // Following the store after the first read would erase the one record
    // that says what a lost store held — on the very launch that lost it.
    final (extensions, settings, store) = await setup();
    await store.install(await store.inspect(clock));
    expect(settings.extensionsInstalledRecorded, isFalse);
    await extensions.reloadAvailableExtensions();
    expect(settings.extensionsInstalled, {'ki2d-my-clock': 'KI2D My Clock'});

    await store.uninstall('ki2d-my-clock');
    await extensions.reloadAvailableExtensions();
    expect(settings.extensionsInstalled, {'ki2d-my-clock': 'KI2D My Clock'});
    expect(extensions.missingExtensions().map((m) => m.key), ['ki2d-my-clock']);
  });

  test('a missing extension says where it can come back from', () async {
    final (extensions, settings, _) = await setup(catalog: _Catalog(const {}));
    await settings.setExtensionsInstalled({'ham2k-pota': 'POTA', 'ki2d-cat': 'Cat', 'ki2d-dev': 'Dev', 'ki2d-file': 'File'});
    await settings.setExtensionInstalledFrom({
      'ham2k-pota': {'host': kPreloadHost, 'sha256': 'a' * 64, 'version': '0.2.4'},
      'ki2d-cat': catalogRecord('1.0.0'),
      'ki2d-dev': {'host': 'dev-catalog.example', 'sha256': 'b' * 64, 'version': '1.0.0'},
    });
    await extensions.reloadAvailableExtensions();
    expect(
      {for (final m in extensions.missingExtensions()) m.key: m.from},
      {
        'ham2k-pota': MissingFrom.shipped,
        'ki2d-cat': MissingFrom.catalog,
        // Not fetched from the catalog in use: those bytes come from a
        // publisher the operator never agreed to.
        'ki2d-dev': MissingFrom.otherCatalog,
        'ki2d-file': MissingFrom.file,
      },
    );
  });

  test('boot keeps the on/off choice of an installed extension the store lost', () async {
    // Pruned as an unknown key, the choice is gone before anything restores
    // the extension, and it comes back switched on — SOTA and WWFF too, off
    // by default as built-ins. A key nobody installed is still pruned.
    final (_, settings, _) = await setup();
    await settings.setExtensionsInstalled({'ham2k-sota': 'SOTA'});
    await settings.setExtensionOverrides({'ham2k-sota': false, 'long-gone': true});
    await updateExtensionDisabledSince(
      settings: settings,
      available: const [ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA')],
      isActive: (_) => true,
    );
    expect(settings.extensionOverrides, {'ham2k-sota': false});
  });

  test('each missing extension is restored on its own, keeping its choice, and the rest are named', () async {
    final (extensions, settings, store) = await setup(
      catalog: _Catalog({
        'ki2d-my-clock': clock,
        // Listed, but its download fails.
        'ki2d-broken': null,
      }),
    );
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'KI2D My Clock', 'ki2d-broken': 'Broken', 'ki2d-gone': 'Gone'});
    await settings.setExtensionInstalledFrom({
      'ki2d-my-clock': catalogRecord('1.0.0'),
      'ki2d-broken': catalogRecord('1.0.0'),
      'ki2d-gone': catalogRecord('1.0.0'),
    });
    await settings.setExtensionOverrides({'ki2d-my-clock': false});

    await extensions.reloadAvailableExtensions();
    late RestoreResult result;
    await withErrorHooks(() async => result = await restoreMissingExtensions(extensions, extensions.missingExtensions()));

    expect(result.installed, ['KI2D My Clock']);
    expect(result.failed, unorderedEquals(['Broken', 'Gone']));
    expect((await store.list()).map((info) => info.key), ['ki2d-my-clock']);
    // Reinstalled as the extension they had, not a new one: a fresh install
    // would drop the switch they had turned off.
    expect(settings.extensionOverrides, {'ki2d-my-clock': false});
    // Still missing, so still offered next launch.
    expect(extensions.missingExtensions().map((m) => m.key), unorderedEquals(['ki2d-broken', 'ki2d-gone']));
  });

  test('a bundle the store holds is not missing, whatever stands in front of it', () async {
    // The list leaves out an installed bundle a built-in of the same key is
    // offered over. Judged by that list, it reads as lost on every launch —
    // re-installed into a store that already has it, and offered back in a
    // dialog whose Install can only fail.
    final (extensions, settings, store) = await setup();
    await store.install(await store.inspect(clock));
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'KI2D My Clock'});
    final shadowed = InstalledExtensions(
      builtInKeys: () => const {'ki2d-my-clock'},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: root),
    );
    extensions.debugInstalledStore = shadowed;
    await extensions.reloadAvailableExtensions();
    expect(extensions.availableExtensions.where((info) => info.isInstalled), isEmpty, reason: 'the premise: the list hides it');
    expect(extensions.missingExtensions(), isEmpty);
  });

  test('a store that cannot be read has not lost anything', () async {
    // Every recorded extension would read as missing, and each launch would
    // offer them all back into the store that is failing.
    final (extensions, settings, _) = await setup();
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'KI2D My Clock'});
    final notADirectory = File('${root.path}/not-a-directory')..writeAsStringSync('');
    extensions.debugInstalledStore = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {},
      storage: FileBundleStorage(root: Directory(notADirectory.path)),
    );
    await withErrorHooks(() => extensions.reloadAvailableExtensions());
    expect(extensions.missingExtensions(), isEmpty);
  });

  test('a restored bundle that takes the runtime down is set aside and named, and the others run', () async {
    final radio = _renamed(clock, key: 'ki2d-radio', name: 'Radio');
    final extensions = _BootDiesOn('ki2d-my-clock');
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: root),
      reservedPrefixAllowed: (_) => true,
    );
    extensions
      ..settings = settings
      ..catalog = _Catalog({'ki2d-my-clock': clock, 'ki2d-radio': radio})
      ..debugInstalledStore = store
      ..debugSetAvailableExtensions(const []);
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'Clock', 'ki2d-radio': 'Radio'});
    await settings.setExtensionInstalledFrom({'ki2d-my-clock': catalogRecord('1.0.0'), 'ki2d-radio': catalogRecord('1.0.0')});

    await extensions.reloadAvailableExtensions();
    late RestoreResult result;
    await withErrorHooks(() async => result = await restoreMissingExtensions(extensions, extensions.missingExtensions()));

    expect(result.wouldNotRun, ['Clock']);
    expect(result.installed, ['Radio']);
    expect(extensions.runtimeIsHealthy, isTrue, reason: 'restarted without the one that killed it');
  });

  test('a restore that finds the runtime will not start at all says so, rather than "installed again"', () async {
    // The boot names no installed bundle, so there is nothing to set aside —
    // and without asking, the result reads as a success over a dead runtime.
    final extensions = _BootDiesOn('ki2d-my-clock', namesCulprit: false);
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsService(await SharedPreferences.getInstance());
    extensions
      ..settings = settings
      ..catalog = _Catalog({'ki2d-my-clock': clock})
      ..debugInstalledStore = InstalledExtensions(
        builtInKeys: () => const {},
        hostSharedModules: const {'i18next': '23.11.5'},
        storage: FileBundleStorage(root: root),
        reservedPrefixAllowed: (_) => true,
      )
      ..debugSetAvailableExtensions(const []);
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'Clock'});
    await settings.setExtensionInstalledFrom({'ki2d-my-clock': catalogRecord('1.0.0')});
    await extensions.reloadAvailableExtensions();

    late RestoreResult result;
    await withErrorHooks(() async => result = await restoreMissingExtensions(extensions, extensions.missingExtensions()));
    expect(result.runtimeDead, isTrue);
  });

  test('a missing extension comes back on the track it followed, whatever the panel searches', () async {
    // Its record outlives the store, and says unstable. Asked on stable —
    // the panel's default — the listing does not carry an unstable-only
    // release and the restore fails every launch; asked on the developer's
    // search track, it could put back a bleeding release nobody chose.
    final (extensions, settings, _) = await setup();
    await settings.setDeveloperMode(true);
    await settings.setCatalogSearchChannel(CatalogChannel.bleeding);
    final catalog = _TrackCatalog({'ki2d-my-clock': clock}, onlyOn: CatalogChannel.unstable, settings: settings);
    extensions.catalog = catalog;
    await settings.setExtensionsInstalled({'ki2d-my-clock': 'KI2D My Clock'});
    await settings.setExtensionInstalledFrom({
      'ki2d-my-clock': {...catalogRecord('1.0.0'), 'channel': 'unstable'},
    });
    await extensions.reloadAvailableExtensions();

    late RestoreResult result;
    await withErrorHooks(() async => result = await restoreMissingExtensions(extensions, extensions.missingExtensions()));
    expect(catalog.asked, [CatalogChannel.unstable]);
    expect(result.installed, ['KI2D My Clock']);
    expect(settings.extensionInstalledFrom['ki2d-my-clock']?['channel'], 'unstable');
  });

  test('a restore asked for while a catalog pass runs is busy, not a failure of every extension', () async {
    final extensions = _HeldPreload();
    SharedPreferences.setMockInitialValues(const {});
    extensions
      ..settings = SettingsService(await SharedPreferences.getInstance())
      ..catalog = _Catalog(const {});
    final catchUp = catchUpOnCatalogExtensions(extensions);
    await extensions.entered.future;
    final result = await restoreMissingExtensions(extensions, const [MissingExtension(key: 'ki2d-x', name: 'X', from: MissingFrom.catalog)]);
    expect(result.busy, isTrue);
    expect(result.failed, isEmpty);
    extensions.release.complete();
    await catchUp;
  });

  group('the restore offer waits for the boot to settle', () {
    test('not before the outermost catch-up ends, though the restart it triggers re-enters', () async {
      // Settled at the re-entry, the offer lists shipped bundles the boot is
      // still putting back — and an Install then meets the flag held.
      final extensions = _ReentersOnRestart();
      SharedPreferences.setMockInitialValues(const {});
      extensions.settings = SettingsService(await SharedPreferences.getInstance());
      var settledDuringRestart = true;
      extensions.onRestart = () async {
        expect(await catchUpOnCatalogExtensions(extensions), isFalse, reason: 'the premise: it steps aside');
        settledDuringRestart = extensions.firstCatchUpSettled;
      };
      await catchUpOnCatalogExtensions(extensions);
      expect(settledDuringRestart, isFalse);
      expect(extensions.firstCatchUpSettled, isTrue);
    });
  });

  test('one unreadable manifest costs only its own extension', () async {
    final (_, _, store) = await setup();
    await store.install(await store.inspect(clock));
    // A manifest on disk that will not read as text — what a corrupted
    // write leaves.
    File('${root.path}/ki2d-damaged/manifest.json')
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [0xff, 0xfe, 0xfd]);
    await withErrorHooks(() async {
      expect((await store.list()).map((info) => info.key), ['ki2d-my-clock']);
    });
    expect(store.storedKeys, containsAll(['ki2d-my-clock', 'ki2d-damaged']));
  });

  test('forgetting a missing extension forgets everything it had', () async {
    final (extensions, settings, _) = await setup();
    await settings.setExtensionsInstalled({'ki2d-file': 'File'});
    await settings.setExtensionOverrides({'ki2d-file': false});
    await extensions.forgetMissingExtension('ki2d-file');
    expect(settings.extensionsInstalled, isEmpty);
    expect(settings.extensionOverrides, isEmpty);
    expect(extensions.missingExtensions(), isEmpty);
  });
}

/// A catalog listing [bundles] at the fixture's version — bytes to serve, or null for
/// a download that fails.
class _Catalog extends CatalogService {
  _Catalog(this.bundles, {super.settings});

  final Map<String, List<int>?> bundles;

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false, CatalogChannel? channel}) async => [
    for (final MapEntry(:key, :value) in bundles.entries)
      CatalogEntry(
        key: key,
        name: key,
        version: '1.2.3',
        sha256: value == null ? 'a' * 64 : sha256Hex(value),
        bundleUrl: Uri.parse('https://$kCatalogHost/api/v1/extensions/$key/versions/1.2.3/bundle'),
      ),
  ];

  @override
  Future<List<int>> download(CatalogRelease release, {void Function(double? fraction)? onProgress}) async =>
      bundles[release.key] ?? (throw const SocketException('offline'));
}

/// [_Catalog] whose listing carries its bundles only when asked for
/// [onlyOn] or rougher, as the catalog's cascade does, and which records the
/// channel of every listing asked for.
class _TrackCatalog extends _Catalog {
  _TrackCatalog(super.bundles, {required this.onlyOn, super.settings});

  final CatalogChannel onlyOn;
  final asked = <CatalogChannel>[];

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false, CatalogChannel? channel}) async {
    final asking = channel ?? searchChannel;
    asked.add(asking);
    if (!asking.sees(onlyOn)) return const [];
    return [
      for (final entry in (await super.fetchCatalog())!)
        CatalogEntry(key: entry.key, name: entry.name, version: entry.version, sha256: entry.sha256, bundleUrl: entry.bundleUrl, channel: onlyOn),
    ];
  }
}

/// [bytes] with its manifest's key and name replaced.
List<int> _renamed(List<int> bytes, {required String key, required String name}) {
  final out = Archive();
  for (final file in ZipDecoder().decodeBytes(bytes).files) {
    if (file.name == 'manifest.json') {
      final manifest = {...jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>, 'key': key, 'name': name};
      final encoded = utf8.encode(jsonEncode(manifest));
      out.addFile(ArchiveFile('manifest.json', encoded.length, encoded));
    } else {
      out.addFile(file);
    }
  }
  return ZipEncoder().encode(out);
}

/// A runtime that will not start while [culprit] is loaded and not refused —
/// what a bundle that throws on evaluation does to the real one.
class _BootDiesOn extends ExtensionServiceWithFakeHost {
  _BootDiesOn(this.culprit, {this.namesCulprit = true}) : super(FakeExtensionHost({}));

  final String culprit;

  /// False for a boot that fails without naming any installed bundle.
  final bool namesCulprit;

  @override
  bool get runtimeIsHealthy => !availableExtensions.any((info) => info.key == culprit && info.isInstalled && !isExtensionRefused(info));

  @override
  String? get lastStartFailureKey => runtimeIsHealthy || !namesCulprit ? null : culprit;

  @override
  Future<void> restartRuntime({bool fresh = false}) async {}
}

/// A catalog pass whose pre-load waits for [release] — holding the flag every
/// other pass steps aside for.
class _HeldPreload extends ExtensionServiceWithFakeHost {
  _HeldPreload() : super(FakeExtensionHost({}));

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> preloadShippedExtensions() async {
    if (!entered.isCompleted) entered.complete();
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

/// A catch-up whose pre-load lands, so it restarts the runtime — and the
/// restart's own boot calls [onRestart], as `_start` re-enters the catch-up.
class _ReentersOnRestart extends ExtensionServiceWithFakeHost {
  _ReentersOnRestart() : super(FakeExtensionHost({}));

  Future<void> Function()? onRestart;

  @override
  Future<bool> preloadShippedExtensions() async => true;

  @override
  Future<({bool complete, bool landed})> adoptTwins() async => (landed: false, complete: true);

  @override
  Future<void> reloadAvailableExtensions() async {}

  @override
  Future<void> restartRuntime({bool fresh = false}) async => onRestart?.call();
}
