// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an install writes to settings besides the files: the provenance
// record, the operator's own switch, the catalog's revocation record, the
// flags' force-disable, and what a replacement carries from the extension it
// replaces. The traps are one write standing in for another — an update
// turning on what the operator turned off, a switch standing in for a
// revocation — so each test here flips one and reads the others.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_force_disable.dart' show ExtensionForceDisable;
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late List<int> fixture;

  setUp(() {
    root = Directory.systemTemp.createTempSync('install-records');
    fixture = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// The fixture with its manifest rewritten, like installed_extensions_test.
  List<int> rebuilt(Map<String, dynamic> Function(Map<String, dynamic>) edit) {
    final archive = ZipDecoder().decodeBytes(fixture);
    final out = Archive();
    for (final file in archive.files) {
      if (file.name == 'manifest.json') {
        final manifest = edit(jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>);
        final bytes = utf8.encode(jsonEncode(manifest));
        out.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
      } else {
        out.addFile(file);
      }
    }
    return ZipEncoder().encode(out);
  }

  Future<(ExtensionService, SettingsService, InstalledExtensions)> setup(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues({for (final e in prefs.entries) e.key: jsonEncode(e.value)});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: root),
      reservedPrefixAllowed: (key) => BundleProvenance.fromJson(settings.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
    );
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))
      ..settings = settings
      ..debugInstalledStore = store
      ..debugSetAvailableExtensions(const []);
    return (extensions, settings, store);
  }

  Future<InspectedBundle> fromCatalog(InstalledExtensions store, List<int> bytes, String version) => store.inspect(
    bytes,
    provenance: BundleProvenance(host: kCatalogHost, sha256: sha256Hex(bytes), version: version),
  );

  test('a fresh catalog install turns the switch on; an update leaves it where the operator put it', () async {
    // The fresh case is the built-in that moved to the catalog: switched off
    // while it was built in, the operator installs it from the catalog to
    // use it, and an override that outlived the built-in would leave it dark
    // with nothing to say why. An UPDATE is the opposite case — the operator
    // switched off the installed version, and a newer one is not theirs to
    // switch on. Mutated to clear on every catalog install, the second
    // expectation fails.
    final (extensions, settings, store) = await setup({
      'extensionOverrides': {'ki2d-my-clock': false},
      'extensionDisabledSince': {'ki2d-my-clock': 1234},
    });
    await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
    expect(settings.extensionOverrides, isEmpty);
    expect(settings.extensionDisabledSince, isEmpty);
    expect(settings.extensionInstalledFrom['ki2d-my-clock']?['version'], '1.2.3');

    await settings.setExtensionOverrides({'ki2d-my-clock': false});
    await settings.setExtensionDisabledSince({'ki2d-my-clock': 5678});
    final newer = rebuilt((m) => {...m, 'version': '1.3.0'});
    await extensions.installBundle(await fromCatalog(store, newer, '1.3.0'));
    expect(settings.extensionOverrides, {'ki2d-my-clock': false});
    expect(settings.extensionDisabledSince, {'ki2d-my-clock': 5678});
    expect(settings.extensionInstalledFrom['ki2d-my-clock']?['version'], '1.3.0');
  });

  test('a file install never touches the switch, and clears the provenance record', () async {
    final (extensions, settings, store) = await setup({
      'extensionOverrides': {'ki2d-my-clock': false},
      'extensionInstalledFrom': {
        'ki2d-my-clock': {'host': kCatalogHost, 'sha256': 'a' * 64, 'version': '1.0.0'},
      },
    });
    await extensions.installBundle(await store.inspect(fixture));
    expect(settings.extensionOverrides, {'ki2d-my-clock': false});
    expect(settings.extensionInstalledFrom, isEmpty);
  });

  test('the track an install follows only widens: a stable release updating an unstable install keeps it on unstable', () async {
    // The operator chose unstable for this extension. The publisher then
    // ships 1.0.0 to stable, and the next unstable 1.0.1 must still reach
    // them — so the stable update leaves the record on unstable. Mutated to
    // record the release's own channel, the second expectation reads stable
    // and the update check stops asking for unstable releases.
    final (extensions, settings, store) = await setup({});
    Future<void> install(List<int> bytes, String version, CatalogChannel channel) async => extensions.installBundle(
      await store.inspect(
        bytes,
        provenance: BundleProvenance(host: kCatalogHost, sha256: sha256Hex(bytes), version: version, channel: channel),
      ),
    );
    String? track() => settings.extensionInstalledFrom['ki2d-my-clock']?['channel'];

    await install(rebuilt((m) => {...m, 'version': '0.1.0'}), '0.1.0', CatalogChannel.unstable);
    expect(track(), 'unstable');
    await install(rebuilt((m) => {...m, 'version': '1.0.0'}), '1.0.0', CatalogChannel.stable);
    expect(track(), 'unstable');
    // A rougher release widens it.
    await install(rebuilt((m) => {...m, 'version': '1.1.0'}), '1.1.0', CatalogChannel.bleeding);
    expect(track(), 'bleeding');
    // A file install is no catalog track at all, and the next catalog
    // install starts from its own release.
    await extensions.installBundle(await store.inspect(fixture));
    expect(settings.extensionInstalledFrom, isEmpty);
    await install(rebuilt((m) => {...m, 'version': '1.2.0'}), '1.2.0', CatalogChannel.stable);
    expect(track(), isNull);
  });

  group('a revoked release', () {
    const revoked = {
      'extensionRevoked': {
        'ki2d-my-clock': {'version': '1.2.3', 'note': 'It uploads the whole log.'},
      },
    };
    const info = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.3');

    test('does not run whatever the switch says', () async {
      // The switch is the operator's intent and the revocation is not theirs
      // to undo. Mutated to consult the override alone, `true` here would
      // load the revoked bytes on the next restart.
      final (extensions, settings, _) = await setup({
        ...revoked,
        'extensionOverrides': {'ki2d-my-clock': true},
      });
      expect(extensions.isExtensionRevoked(info), isTrue);
      expect(extensions.isExtensionEnabled(info), isFalse);
      expect(extensions.isExtensionActive(info), isFalse);
      // Another version of the same key is not what was revoked.
      const other = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.4');
      expect(extensions.isExtensionRevoked(other), isFalse);
      expect(extensions.isExtensionEnabled(other), isTrue);
      await settings.setExtensionOverrides({'ki2d-my-clock': false});
      expect(extensions.isExtensionEnabled(info), isFalse);
    });

    test('is forgotten by an install of another version, and not by one of the same', () async {
      final (extensions, settings, store) = await setup(revoked);
      // The same version again, from a file: the catalog's verdict on that
      // version stands.
      await extensions.installBundle(await store.inspect(fixture));
      expect(settings.extensionRevoked.keys, ['ki2d-my-clock']);

      final newer = rebuilt((m) => {...m, 'version': '1.3.0'});
      await extensions.installBundle(await fromCatalog(store, newer, '1.3.0'));
      expect(settings.extensionRevoked, isEmpty);
    });

    test('is forgotten by an uninstall', () async {
      // Kept, it would refuse a later reinstall of that version with nothing
      // to say why. `forgetExtension` is the settings half of an uninstall.
      final (_, settings, _) = await setup(revoked);
      await settings.forgetExtension('ki2d-my-clock');
      expect(settings.extensionRevoked, isEmpty);
    });
  });

  group('a release the flags force-disable', () {
    const info = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.3');
    const other = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.4');

    test('does not run whatever the switch says, for the versions it names', () async {
      // Mutated to consult the override alone, the switched-on version loads;
      // mutated to ignore `versions`, the fixed 1.2.4 stays off too.
      final (extensions, _, _) = await setup({
        'extensionForceDisabled': {
          'ki2d-my-clock': {
            'note': 'Crashes on start.',
            'versions': ['1.2.3'],
          },
        },
        'extensionOverrides': {'ki2d-my-clock': true},
      });
      expect(extensions.isExtensionForceDisabled(info), isTrue);
      expect(extensions.isExtensionEnabled(info), isFalse);
      expect(extensions.isExtensionActive(info), isFalse);
      expect(extensions.isExtensionEnabled(other), isTrue);
    });

    test('covers every version when it names none, and never a core extension', () async {
      // A core extension is the app's own code: taking it out is an install
      // quietly missing part of itself, which a release or a code push fixes.
      final (extensions, _, _) = await setup({
        'extensionForceDisabled': {
          'ki2d-my-clock': {'note': ''},
          'adif': {'note': ''},
        },
      });
      expect(extensions.isExtensionEnabled(info), isFalse);
      expect(extensions.isExtensionEnabled(other), isFalse);
      const core = ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF');
      expect(extensions.isExtensionForceDisabled(core), isFalse);
      expect(extensions.isExtensionEnabled(core), isTrue);
    });

    test('outlives an uninstall, unlike a revocation', () async {
      // It is about the key, not about one install of it: a reinstall of the
      // version that crashes the app must stay off. Dropped with the other
      // install records, the reinstall loads it.
      final (_, settings, _) = await setup({
        'extensionForceDisabled': {
          'ki2d-my-clock': {'note': ''},
        },
      });
      await settings.forgetExtension('ki2d-my-clock');
      expect(settings.extensionForceDisabled.keys, ['ki2d-my-clock']);
    });
  });

  group('a replacement the catalog offered', () {
    List<int> replacement() => rebuilt((m) => {...m, 'key': 'ki2d-new-clock', 'name': 'KI2D New Clock'});

    test('carries what the operator set, takes its place on screen, and takes the old one out', () async {
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({
        'settings.extension_ki2d-my-clock': {'format': '24h'},
        'extensionOverrides': {'ki2d-my-clock': false},
        'layout': {
          'home.dock.spec': {
            'panels': ['ext:ki2d-my-clock:clock', 'ext:ki2d-my-clock-other:clock', 'native:log'],
          },
        },
      });
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await settings.setExtensionOverrides({'ki2d-my-clock': false});
      await settings.prefs.setString('settingsPanel.ext:ki2d-my-clock:clock.color', jsonEncode('red'));
      const keychain = FlutterSecureStorage();
      await keychain.write(key: 'settingsPanel_secret_ext:ki2d-my-clock:clock_password', value: jsonEncode('hunter2'));

      final bytes = replacement();
      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'), replacing: 'ki2d-my-clock');

      expect(await store.isInstalled('ki2d-my-clock'), isFalse);
      expect(await store.isInstalled('ki2d-new-clock'), isTrue);
      expect(settings.settingsGroup('extension_ki2d-new-clock'), {'format': '24h'});
      expect(settings.prefs.getString('settingsPanel.ext:ki2d-new-clock:clock.color'), jsonEncode('red'));
      // A docked panel's secret too — a network radio's password, say, which
      // the operator would otherwise have to find and type again.
      expect(await keychain.read(key: 'settingsPanel_secret_ext:ki2d-new-clock:clock_password'), jsonEncode('hunter2'));
      // The operator's switch, not the fresh-catalog-install rule that turns
      // it on: Replace is not the operator choosing to run something new.
      expect(settings.extensionOverrides['ki2d-new-clock'], isFalse);
      // A `-…` hook key is left alone: it can as well be another
      // extension's key.
      expect(settings.layoutData('home.dock.spec'), {
        'panels': ['ext:ki2d-new-clock:clock', 'ext:ki2d-my-clock-other:clock', 'native:log'],
      });
      // Gone with the old extension, so nothing it stored comes back with a
      // later reinstall of it.
      expect(settings.extensionsInstalled.keys, ['ki2d-new-clock']);
      expect(settings.settingsGroup('extension_ki2d-my-clock'), isEmpty);
      expect(settings.extensionOverrides.containsKey('ki2d-my-clock'), isFalse);
    });
  });

  group('a replacement, around the edges', () {
    List<int> replacement() => rebuilt((m) => {...m, 'key': 'ki2d-new-clock', 'name': 'KI2D New Clock'});

    test('carries what the operator set even when the replacement got installed first', () async {
      // Replace's consent screen is up while a link installs the new key. The
      // commit then finds it installed — not fresh — and the old one is still
      // uninstalled. Carried only on a fresh install, the old extension's
      // settings and login go with it.
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({
        'settings.extension_ki2d-my-clock': {'format': '24h'},
      });
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      final bytes = replacement();
      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'));
      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'), replacing: 'ki2d-my-clock');
      expect(await store.isInstalled('ki2d-my-clock'), isFalse);
      expect(settings.settingsGroup('extension_ki2d-new-clock'), {'format': '24h'});
    });

    test('carries the switch the old one ran by, a manifest default included', () async {
      // Never toggled, the old extension ran by its own default and left no
      // override to copy; the replacement's manifest defaults to off. Without
      // carrying the effective switch, the extension the operator was using
      // lands switched off.
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({});
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await settings.setExtensionOverrides({});
      final bytes = rebuilt((m) => {...m, 'key': 'ki2d-new-clock', 'name': 'KI2D New Clock', 'enabledByDefault': false});
      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'), replacing: 'ki2d-my-clock');
      expect(settings.extensionOverrides['ki2d-new-clock'], isTrue);
    });

    test('onto one already installed, moves the docked panels and settings without an install', () async {
      // The "which you already have" row. A plain uninstall leaves the dock
      // naming panels nothing provides, and every one becomes a placeholder.
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({
        'settings.extension_ki2d-my-clock': {'format': '24h'},
        'layout': {
          'home.dock.spec': {
            'panels': ['ext:ki2d-my-clock:clock'],
          },
        },
      });
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await extensions.installBundle(await fromCatalog(store, replacement(), '1.2.3'));
      await extensions.replaceInstalledExtension(from: 'ki2d-my-clock', to: 'ki2d-new-clock');
      expect(await store.isInstalled('ki2d-my-clock'), isFalse);
      expect(settings.settingsGroup('extension_ki2d-new-clock'), {'format': '24h'});
      expect(settings.layoutData('home.dock.spec'), {
        'panels': ['ext:ki2d-new-clock:clock'],
      });
    });
  });

  test('an uninstall forgets its docked panels\' values and secrets', () async {
    // They hang off the panel id rather than the extension key. Left behind, a
    // reinstall docking the same panel brings the old credential back — the
    // resurrection the uninstall dialog promises does not happen.
    useInMemoryKeychain();
    final (extensions, settings, store) = await setup({});
    await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
    await settings.prefs.setString('settingsPanel.ext:ki2d-my-clock:clock.color', jsonEncode('red'));
    await settings.prefs.setString('settingsPanel.ext:ki2d-my-clock-other:clock.color', jsonEncode('blue'));
    const keychain = FlutterSecureStorage();
    await keychain.write(key: 'settingsPanel_secret_ext:ki2d-my-clock:clock_password', value: 'x');
    await extensions.uninstallExtension('ki2d-my-clock');
    expect(settings.prefs.getString('settingsPanel.ext:ki2d-my-clock:clock.color'), isNull);
    expect(await keychain.read(key: 'settingsPanel_secret_ext:ki2d-my-clock:clock_password'), isNull);
    // Positive control: another extension's panel, whose key only starts the same.
    expect(settings.prefs.getString('settingsPanel.ext:ki2d-my-clock-other:clock.color'), isNotNull);
  });

  test('what the boot read before settings arrived keeps the extension out', () async {
    // The first start can beat the settings, and with none every installed
    // extension loads. Consulting the kept list alone, the one the flags
    // stop runs on exactly the launch it would break.
    const info = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.3');
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))
      ..earlyForceDisabled = Future.value({'ki2d-my-clock': const ExtensionForceDisable(note: 'Crashes.')});
    await extensions.debugAwaitEarlyForceDisabled();
    expect(extensions.isExtensionEnabled(info), isFalse);
    expect(extensions.forceDisableOf(info)?.note, 'Crashes.');
    expect(extensions.dropEarlyForceDisabled(), isTrue);
    expect(extensions.isExtensionEnabled(info), isTrue);
  });

  group('a bundle the engine refused', () {
    const refused = {
      'extensionRefused': {'ki2d-my-clock': '1.2.3'},
    };
    const info = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.2.3');

    test('stays listed, and stays out of the runtime', () async {
      // Unavailable would hide the row, and the row is the one place an
      // operator can see that an extension they installed is doing nothing —
      // and update it, which is what lifts the refusal.
      final (extensions, _, _) = await setup({
        ...refused,
        'extensionOverrides': {'ki2d-my-clock': true},
      });
      expect(extensions.isExtensionRefused(info), isTrue);
      expect(extensions.isExtensionAvailable(info), isTrue);
      expect(extensions.isExtensionActive(info), isFalse);
    });

    test('is forgotten by an install of another version', () async {
      // The whole recovery the refusal is keyed by version for: a fixed
      // release arrives as an ordinary update and loads, with nobody having
      // to notice anything.
      final (extensions, settings, store) = await setup(refused);

      final newer = rebuilt((m) => {...m, 'version': '1.3.0'});
      await extensions.installBundle(await fromCatalog(store, newer, '1.3.0'));

      expect(settings.extensionRefused, isEmpty);
    });

    test('is forgotten by an uninstall, so a reinstall of the same bytes gets its chance', () async {
      // Uninstall-and-reinstall is the operator's own repair for a download
      // that arrived corrupt. Kept, the
      // reinstalled extension lands inert with nothing saying why — and a
      // sideloaded bundle has no catalog offer to lift it either.
      final (_, settings, _) = await setup(refused);
      await settings.forgetExtension('ki2d-my-clock');
      expect(settings.extensionRefused, isEmpty);
    });

    test('and not by an install of the same version', () async {
      // The same bytes will not evaluate this time either.
      final (extensions, settings, store) = await setup(refused);
      await extensions.installBundle(await store.inspect(fixture));
      expect(settings.extensionRefused.keys, ['ki2d-my-clock']);
    });
  });
}
