// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Taking out of the store the pre-loaded bundles and built-ins' twins an
// install holds switched off, which the app put there whatever their switch
// said. The traps: removing what the operator went and got themselves;
// removing as an uninstall would, so a reinstall arrives unconfigured; leaving
// the install records behind, so the next launch offers it back as missing;
// recording the job done over a store it could not read; and a reinstall from
// the catalog landing switched off, its old switch kept.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/extension_catalog_migration.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

/// A store whose listing fails while [unreadable] — a store failing whole,
/// which the list reads as holding nothing.
class _FlakyStorage extends FileBundleStorage {
  _FlakyStorage({super.root});

  bool unreadable = false;

  /// Keys whose files will not come off the disk.
  final stuck = <String>{};

  @override
  Future<Map<String, String?>> manifests() async => unreadable ? throw const FileSystemException('the disk went away') : super.manifests();

  @override
  Future<void> remove(String key) async => stuck.contains(key) ? throw FileSystemException('held open', key) : super.remove(key);
}

/// A catch-up with nothing to pre-load or adopt, over a real store.
class _Boot extends ExtensionServiceWithFakeHost {
  int preloads = 0;
  int adoptions = 0;
  int restarts = 0;

  /// Called after every re-read of the list.
  void Function()? onReload;

  @override
  Future<void> reloadAvailableExtensions() async {
    await super.reloadAvailableExtensions();
    onReload?.call();
  }

  @override
  Future<bool> preloadShippedExtensions() async {
    preloads++;
    return false;
  }

  @override
  Future<({bool complete, bool landed})> adoptTwins() async {
    adoptions++;
    return (landed: false, complete: true);
  }

  @override
  Future<void> restartRuntime({bool fresh = false}) async => restarts++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late List<int> clock;
  late _Boot extensions;
  late SettingsService settings;
  late InstalledExtensions store;
  late _FlakyStorage storage;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('switched-off-removal');
    clock = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
    SharedPreferences.setMockInitialValues(const {});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: storage = _FlakyStorage(root: root),
      reservedPrefixAllowed: (key) => BundleProvenance.fromJson(settings.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
    );
    extensions = _Boot()
      ..settings = settings
      ..debugInstalledStore = store
      ..debugSetAvailableExtensions(const []);
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// The clock fixture under another key.
  List<int> keyed(String key) {
    final out = Archive();
    for (final file in ZipDecoder().decodeBytes(clock).files) {
      if (file.name == 'manifest.json') {
        final manifest = {...jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>, 'key': key};
        final bytes = utf8.encode(jsonEncode(manifest));
        out.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
      } else {
        out.addFile(file);
      }
    }
    return ZipEncoder().encode(out);
  }

  /// Installs [key] through the operator's own door, from [host] — or from a
  /// file when null — and switches it as [on] says.
  Future<void> install(String key, {String? host, required bool on}) async {
    final bytes = keyed(key);
    final provenance = host == null ? null : BundleProvenance(host: host, sha256: sha256Hex(bytes), version: '1.2.3');
    await extensions.installBundle(await store.inspect(bytes, provenance: provenance));
    await settings.setExtensionOverrides({...settings.extensionOverrides, key: on});
  }

  Future<Set<String>> stored() async => {for (final info in await store.list()) info.key};

  group('the one-time removal', () {
    setUp(() async {
      await install('ki2d-shipped-off', host: kPreloadHost, on: false);
      await install('ham2k-wwff', host: kCatalogHost, on: false);
      await install('ki2d-catalog-off', host: kCatalogHost, on: false);
      await install('ki2d-shipped-on', host: kPreloadHost, on: true);
      await install('ki2d-file-off', on: false);
      await settings.prefs.setString('settings.extension_ham2k-wwff', '{"units":"metric"}');
      extensions.restarts = 0;
    });

    test('takes out the pre-loaded bundles and twins switched off, and nothing else', () async {
      // A catalog extension the operator went and got is theirs to keep
      // switched off — a QSO party's, between parties — and a file install
      // has nothing to come back from.
      await catchUpOnCatalogExtensions(extensions);
      expect(await stored(), {'ki2d-catalog-off', 'ki2d-shipped-on', 'ki2d-file-off'});
      expect(extensions.restarts, 1, reason: 'the runtime loses them in one restart');
    });

    test('keeps what the operator set, so a reinstall arrives configured', () async {
      await catchUpOnCatalogExtensions(extensions);
      expect(settings.prefs.getString('settings.extension_ham2k-wwff'), '{"units":"metric"}');
      expect(settings.extensionOverrides['ham2k-wwff'], isFalse);
    });

    test('does not leave any of them recorded as installed, to be offered back as missing', () async {
      await catchUpOnCatalogExtensions(extensions);
      await extensions.reloadAvailableExtensions();
      expect(extensions.missingExtensions(), isEmpty);
      expect(settings.extensionsInstalled.keys, isNot(anyOf(contains('ki2d-shipped-off'), contains('ham2k-wwff'))));
      expect(settings.extensionInstalledFrom.keys, isNot(anyOf(contains('ki2d-shipped-off'), contains('ham2k-wwff'))));
    });

    test('runs once: one switched off afterwards is the operator\'s to keep', () async {
      await catchUpOnCatalogExtensions(extensions);
      await extensions.setExtensionEnabled('ki2d-shipped-on', false);
      await catchUpOnCatalogExtensions(extensions);
      expect(await stored(), contains('ki2d-shipped-on'));
    });

    test('is not recorded done over a store it could not read', () async {
      // The list then holds nothing installed, so there is nothing to take
      // out — and recorded done, what the store does hold stays for good.
      storage.unreadable = true;
      await withErrorHooks(() async {
        await extensions.reloadAvailableExtensions();
        await catchUpOnCatalogExtensions(extensions);
      });
      expect(settings.extensionsSwitchedOffRemoved, isFalse);

      storage.unreadable = false;
      await extensions.reloadAvailableExtensions();
      await catchUpOnCatalogExtensions(extensions);
      expect(await stored(), isNot(contains('ki2d-shipped-off')));
      expect(settings.extensionsSwitchedOffRemoved, isTrue);
    });

    test('one that will not come out is tried again next launch, not on every restart', () async {
      // Every runtime restart runs a catch-up — each toggle, each crash — and
      // each would retry it and report it again.
      storage.stuck.add('ham2k-wwff');
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        await catchUpOnCatalogExtensions(extensions);
        await catchUpOnCatalogExtensions(extensions);
      }, backend: backend);
      expect(backend.exceptions, hasLength(1));
      expect(settings.extensionsSwitchedOffRemoved, isFalse);

      storage.stuck.clear();
      final nextLaunch = _Boot()
        ..settings = settings
        ..debugInstalledStore = store;
      await nextLaunch.reloadAvailableExtensions();
      await catchUpOnCatalogExtensions(nextLaunch);
      expect(await stored(), isNot(contains('ham2k-wwff')));
      expect(settings.extensionsSwitchedOffRemoved, isTrue);
    });
  });

  group('onboarding', () {
    test('a catch-up before it is answered installs nothing', () async {
      // The bundles to pre-load are the activities onboarding asks about.
      // Installed on their defaults first, whichever the operator then turns
      // down stays installed and switched off.
      SharedPreferences.setMockInitialValues(const {});
      extensions.settings = settings = SettingsService(await SharedPreferences.getInstance());
      await catchUpOnCatalogExtensions(extensions);
      expect(extensions.preloads, 0);
    });

    test('settling installs what it switched on and takes out what it switched off', () async {
      // A catch-up between the callsign step and the last one installs on the
      // defaults, and the one-time removal has already run by then.
      await settings.setExtensionsSwitchedOffRemoved(true);
      await install('ki2d-shipped-off', host: kPreloadHost, on: false);
      await settleOnboardingExtensions(extensions, firstRun: true);
      expect(extensions.preloads, 1);
      expect(await stored(), isEmpty);
    });

    test('a replay settles what it switched on and takes nothing out', () async {
      // DEVONBOARD replays onboarding over an install in use, where what the
      // operator keeps switched off is theirs.
      await settings.setExtensionsSwitchedOffRemoved(true);
      await install('ki2d-shipped-off', host: kPreloadHost, on: false);
      await settleOnboardingExtensions(extensions, firstRun: false);
      expect(extensions.preloads, 1);
      expect(await stored(), {'ki2d-shipped-off'});
    });

    test('settling before the store has been read leaves it to the boot', () async {
      // ONBOARD_AS, or a Skip, as the app comes up. Run then, it pre-loads
      // into no store and marks the boot's first catch-up settled, which
      // holds back the restore offer for the launch.
      final early = _Boot()..settings = settings;
      await settleOnboardingExtensions(early, firstRun: true);
      expect(early.preloads, 0);
      expect(early.firstCatchUpSettled, isFalse);
    });

    test('settling fetches nothing from the catalog', () async {
      // Done waits for it, and what onboarding offers ships with the app: a
      // slow network would hold the operator on "finishing setup".
      await settleOnboardingExtensions(extensions, firstRun: true);
      expect(extensions.adoptions, 0);
    });
  });

  test('a removed twin reinstalled from the catalog lands switched on', () async {
    // Its switch was kept, and a fresh install of a built-in's twin carries
    // the built-in's switch too — off on both counts. The operator just went
    // and installed it, which is asking to run it.
    await settings.setExtensionOverrides({'sota': false, 'ham2k-sota': false});
    await install('ham2k-sota', host: kCatalogHost, on: true);
    await settings.setExtensionOverrides({...settings.extensionOverrides, 'ham2k-sota': false});
    await catchUpOnCatalogExtensions(extensions);
    expect(await stored(), isNot(contains('ham2k-sota')), reason: 'the premise: it was removed');

    final bytes = keyed('ham2k-sota');
    await extensions.installBundle(
      await store.inspect(
        bytes,
        provenance: BundleProvenance(host: kCatalogHost, sha256: sha256Hex(bytes), version: '1.2.3'),
      ),
    );
    expect(settings.extensionOverrides['ham2k-sota'], isTrue);
  });

  test('a pre-loaded extension uninstalled while switched on is not pre-loaded again', () async {
    // The pre-load record outlives the uninstall, but the next app update
    // carrying a newer copy asks the switch — and forgotten, it reads as on.
    await settings.setExtensionPreloaded({'ki2d-shipped-on': '1.2.3'});
    await install('ki2d-shipped-on', host: kPreloadHost, on: true);
    await extensions.uninstallExtension('ki2d-shipped-on');
    expect(shippedBundleSwitchedOn(settings, 'ki2d-shipped-on'), isFalse);
  });

  test('a built-in\'s twin the catalog fetched, uninstalled, is not pre-loaded the next launch', () async {
    // Never recorded as pre-loaded — the pre-load failed, and the adoption
    // fetched it — so the pre-load still offers it, and with its own switch
    // forgotten reads the built-in's, on.
    await settings.setExtensionOverrides({'wwff': true});
    await install('ham2k-wwff', host: kCatalogHost, on: true);
    await extensions.uninstallExtension('ham2k-wwff');
    expect(shippedBundleSwitchedOn(settings, 'ham2k-wwff'), isFalse);
  });

  test('a shipped extension the operator forgets stays forgotten', () async {
    // Forget is the uninstall of one the store already lost.
    await settings.setExtensionPreloaded({'ki2d-shipped-on': '1.2.3'});
    await settings.setExtensionOverrides({'ki2d-shipped-on': true});
    await extensions.forgetMissingExtension('ki2d-shipped-on');
    expect(shippedBundleSwitchedOn(settings, 'ki2d-shipped-on'), isFalse);
  });

  test('an uninstall forgets the switch of an extension the app does not pre-load', () async {
    // Kept, it is a record of an extension that no longer exists.
    await install('ki2d-catalog-on', host: kCatalogHost, on: true);
    await extensions.uninstallExtension('ki2d-catalog-on');
    expect(settings.extensionOverrides, isEmpty);
  });

  test('an uninstalled extension is never missing on the way out', () async {
    // Recorded as installed and gone from the store, it reads as missing, and
    // a catch-up a restart starts meanwhile restores it.
    await install('ki2d-shipped-on', host: kPreloadHost, on: true);
    final missing = <String>[];
    extensions.onReload = () => missing.addAll(extensions.missingExtensions().map((m) => m.key));
    await extensions.uninstallExtension('ki2d-shipped-on');
    expect(missing, isEmpty);
  });

  test('an uninstalled extension leaves the list before its switch is forgotten', () async {
    // Forgotten first, the Extensions panel redraws a row still listed with
    // no switch, which reads as on — an installed extension's default — and
    // shows it flipping on for as long as the keychain takes to clear.
    await install('ki2d-catalog-off', host: kCatalogHost, on: false);
    final listedWhenForgotten = <bool>[];
    settings.addListener(() {
      if (!settings.extensionOverrides.containsKey('ki2d-catalog-off')) {
        listedWhenForgotten.add(extensions.availableExtensions.any((info) => info.key == 'ki2d-catalog-off'));
      }
    });
    await extensions.uninstallExtension('ki2d-catalog-off');
    expect(listedWhenForgotten, isNotEmpty, reason: 'the premise: the switch is forgotten');
    expect(listedWhenForgotten, everyElement(isFalse));
  });
}
