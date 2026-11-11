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
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_force_disable.dart' show ExtensionForceDisable;
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/extension_keychain.dart' show debugResetKeychainEnumeration;
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

  /// A keychain that holds and deletes items but answers a listing with
  /// [listing] — errSecParam (-50) is the macOS file keychain, which never
  /// lists; errSecInteractionNotAllowed (-25308) a locked one, which lists
  /// once [unlocked]. Set before [setup], whose own keychain then stands
  /// aside.
  ({Map<String, String> items, void Function() unlock}) awkwardKeychain({int listing = -50}) {
    final items = <String, String>{};
    var locked = true;
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      switch (call.method) {
        case 'readAll':
          if (locked) throw PlatformException(code: 'keychain', details: listing);
          return Map<String, String>.of(items);
        case 'read':
          return items[args['key']];
        case 'write':
          items[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          if (locked && listing == -25308) throw PlatformException(code: 'keychain', details: listing);
          items.remove(args['key']);
          return null;
        default:
          throw UnsupportedError('test keychain: ${call.method}');
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugResetKeychainEnumeration();
    });
    return (items: items, unlock: () => locked = false);
  }

  Future<(ExtensionService, SettingsService, InstalledExtensions)> setup(Map<String, Object> prefs, {Map<String, Object?> stubs = const {}}) async {
    // An update from another source removes the installed copy's keychain
    // items, and refuses to install when it cannot.
    useInMemoryKeychain();
    SharedPreferences.setMockInitialValues({for (final e in prefs.entries) e.key: jsonEncode(e.value)});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final store = InstalledExtensions(
      builtInKeys: () => const {},
      hostSharedModules: const {'i18next': '23.11.5'},
      storage: FileBundleStorage(root: root),
      reservedPrefixAllowed: (key) => BundleProvenance.fromJson(settings.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
    );
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost(stubs))
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

  group("a link's publisher", () {
    // What an update from a link is compared with. Too coarse, and two
    // publishers sharing a host inherit each other's saved logins; too fine,
    // and every new version of one publisher's extension asks again.
    test('is the folder the bundle sits in', () {
      expect(linkPublisherOf(Uri.parse('https://K2ABC.example/ham/clock-1.2.h2kext?x=1#y')), 'k2abc.example/ham');
      expect(linkPublisherOf(Uri.parse('https://k2abc.example/clock.h2kext')), 'k2abc.example');
      expect(linkPublisherOf(Uri.parse('https://k2abc.example:8443/ham/clock.h2kext')), 'k2abc.example:8443/ham');
      expect(
        linkPublisherOf(Uri.parse('https://pages.example/k2abc/clock.h2kext')),
        isNot(linkPublisherOf(Uri.parse('https://pages.example/w1xyz/clock.h2kext'))),
      );
    });

    test("is a GitHub release's repository, whatever its tag", () {
      expect(linkPublisherOf(Uri.parse('https://github.com/K2ABC/Clock/releases/download/v1.2.3/clock.h2kext')), 'github.com/k2abc/clock');
      expect(linkPublisherOf(Uri.parse('https://github.com/k2abc/clock/releases/latest/download/clock.h2kext')), 'github.com/k2abc/clock');
      expect(linkPublisherOf(Uri.parse('https://github.com/w1xyz/clock/releases/download/v1.2.3/clock.h2kext')), isNot('github.com/k2abc/clock'));
    });

    test("is Ham2K's anywhere on the catalog's host", () {
      final publisher = linkPublisherOf(Uri.parse('https://$kCatalogHost/bundles/ki2d-my-clock/1.2.3/ki2d-my-clock.h2kext'));
      expect(installSource(linkPublisher: publisher), 'ham2k');
    });
  });

  group("an update's keychain items", () {
    // The trap: nothing ties two bundles claiming one key to one publisher,
    // so a link or a file reusing an installed extension's key would run with
    // the login the operator gave the extension they installed. Each test
    // stores a secret, installs over it, and reads what is left.
    const keychain = FlutterSecureStorage();
    const secret = 'settingsPanel_secret_ki2d-my-clock_password';
    const login = 'account_creds_ki2d-my-clock';

    Future<void> storeSecrets() async {
      await keychain.write(key: secret, value: jsonEncode('hunter2'));
      await keychain.write(key: login, value: jsonEncode({'username': 'n0dev'}));
    }

    Future<bool> secretsKept() async => await keychain.read(key: secret) != null && await keychain.read(key: login) != null;

    test('stay with an update from where the installed copy came from', () async {
      useInMemoryKeychain();
      final (extensions, _, store) = await setup({});
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await storeSecrets();
      final newer = rebuilt((m) => {...m, 'version': '1.3.0'});
      expect(await extensions.replacedSource(await fromCatalog(store, newer, '1.3.0')), isNull);
      await extensions.installBundle(await fromCatalog(store, newer, '1.3.0'));
      expect(await secretsKept(), isTrue, reason: 'a catalog update of a catalog install is the same extension');

      final linked = await store.inspect(fixture, linkPublisher: 'k2abc.example');
      await extensions.installBundle(linked);
      await storeSecrets();
      await extensions.installBundle(await store.inspect(newer, linkPublisher: 'k2abc.example'));
      expect(await secretsKept(), isTrue, reason: 'two links from one host');
    });

    test('are left behind by an update from anywhere else, unless the operator lets it keep them', () async {
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({});
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await storeSecrets();
      final takeover = rebuilt((m) => {...m, 'version': '9.0.0'});
      final linked = await store.inspect(takeover, linkPublisher: 'attacker.example');
      expect(await extensions.replacedSource(linked), 'ham2k');
      await extensions.installBundle(linked);
      expect(await keychain.read(key: secret), isNull);
      expect(await keychain.read(key: login), isNull);
      expect(settings.extensionLinkPublishers, {'ki2d-my-clock': 'attacker.example'});

      await storeSecrets();
      await extensions.installBundle(await store.inspect(takeover, linkPublisher: 'elsewhere.example'));
      expect(await secretsKept(), isFalse, reason: "another host's link is another source");

      await storeSecrets();
      await extensions.installBundle(await store.inspect(takeover));
      expect(await secretsKept(), isFalse, reason: "a file is not the link's host");
      expect(settings.extensionLinkPublishers, isEmpty);

      await storeSecrets();
      await extensions.installBundle((await store.inspect(takeover, linkPublisher: 'k2abc.example')).keepingSecrets());
      expect(await secretsKept(), isTrue, reason: 'the operator let it use them');
    });

    test('of a fresh install are not compared with anything', () async {
      // Settings and credentials a removal kept are the operator's to have
      // back (removeKeepingSettings), whatever the install that returns it.
      useInMemoryKeychain();
      final (extensions, _, store) = await setup({});
      await storeSecrets();
      final linked = await store.inspect(fixture, linkPublisher: 'k2abc.example');
      expect(await extensions.replacedSource(linked), isNull);
      await extensions.installBundle(linked);
      expect(await secretsKept(), isTrue);
    });

    group('on a keychain that will not list', () {
      // The macOS file keychain: only names known some other way can be
      // removed, and an update the operator refused them is not installed
      // while one may be left for it to read.
      const apiKey = 'settingsPanel_secret_ki2d-my-clock_apiKey';
      const login = 'account_creds_ki2d-my-clock_hamqth';
      final declares = <String, Object?>{
        'settingsPanel:*:getPanels': [
          {
            'key': 'ki2d-my-clock',
            'ok': true,
            'value': {'panelKey': 'ki2d-my-clock', 'hookKey': 'ki2d-my-clock'},
          },
        ],
        'settingsPanel:ki2d-my-clock:getDefinition': {
          'elements': [
            {'type': 'field', 'fieldType': 'secret', 'key': 'apiKey'},
            {'type': 'field', 'fieldType': 'text', 'key': 'endpoint'},
          ],
        },
        'account:*:getDefinition': [
          {
            'key': 'ki2d-my-clock',
            'ok': true,
            'value': {'kvKey': 'ki2d-my-clock_hamqth'},
          },
        ],
      };

      test('removes what the installed copy declares', () async {
        final keychain = awkwardKeychain();
        final (extensions, _, store) = await setup({}, stubs: declares);
        await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
        keychain.items.addAll({apiKey: '"k"', login: '"n0dev"'});
        (extensions as ExtensionServiceWithFakeHost).debugLoadedExtensionKeys = {'ki2d-my-clock'};
        await extensions.installBundle(await store.inspect(rebuilt((m) => {...m, 'version': '9.0.0'}), linkPublisher: 'k2abc.example'));
        expect(keychain.items, isEmpty);
      });

      test('refuses the install, removing nothing, when the installed copy cannot say', () async {
        final keychain = awkwardKeychain();
        final (extensions, settings, store) = await setup({});
        await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
        // The account pair is the one name that can always be built: removed
        // before the refusal, the version still installed would be logged out.
        keychain.items.addAll({apiKey: '"k"', login: '"n0dev"', 'account_creds_ki2d-my-clock': '"n0dev"'});
        final takeover = await store.inspect(rebuilt((m) => {...m, 'version': '9.0.0'}), linkPublisher: 'k2abc.example');
        await expectLater(extensions.installBundle(takeover), throwsA(isA<SecretsNotRemoved>()));
        expect(
          keychain.items.keys,
          unorderedEquals([apiKey, login, 'account_creds_ki2d-my-clock']),
          reason: 'the version installed still runs, with its logins',
        );
        expect(settings.extensionInstalledFrom['ki2d-my-clock']?['version'], '1.2.3');
      });

      test('removes what the app recorded writing, whatever the extension says', () async {
        final keychain = awkwardKeychain();
        final (extensions, settings, store) = await setup(
          {},
          stubs: {
            ...declares,
            'settingsPanel:ki2d-my-clock:getDefinition': {'elements': <Object>[]},
          },
        );
        await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
        keychain.items[apiKey] = '"k"';
        await settings.recordExtensionSecretName(apiKey);
        (extensions as ExtensionServiceWithFakeHost).debugLoadedExtensionKeys = {'ki2d-my-clock'};
        await extensions.installBundle(await store.inspect(rebuilt((m) => {...m, 'version': '9.0.0'}), linkPublisher: 'k2abc.example'));
        expect(keychain.items, isEmpty);
        expect(settings.extensionSecretNames, isEmpty);
      });
    });

    test('of a copy the store lost are compared with its record', () async {
      // The bundle is gone, but its record, its logins and the operator's
      // intent are not: a link reusing the key is still another source.
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({});
      await extensions.installBundle(await fromCatalog(store, fixture, '1.2.3'));
      await store.uninstall('ki2d-my-clock');
      expect(settings.extensionsInstalled.keys, ['ki2d-my-clock']);
      expect(await extensions.replacedSource(await store.inspect(fixture, linkPublisher: 'k2abc.example')), 'ham2k');
    });
  });

  group("a retired built-in's keychain items", () {
    const keychain = FlutterSecureStorage();
    List<int> twin(String key) => rebuilt((m) => {...m, 'key': key, 'name': key});

    test("go when its twin is uninstalled, and the next install of the twin carries nothing back", () async {
      useInMemoryKeychain();
      final (extensions, _, store) = await setup({});
      await keychain.write(key: 'account_creds_qrz', value: jsonEncode({'username': 'n0dev'}));
      final bytes = twin('ham2k-qrz');
      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'));
      expect(await keychain.read(key: 'account_creds_ham2k-qrz'), isNotNull, reason: 'the twin takes over the login');

      await extensions.uninstallExtension('ham2k-qrz');
      expect(await keychain.read(key: 'account_creds_ham2k-qrz'), isNull);
      expect(await keychain.read(key: 'account_creds_qrz'), isNull, reason: "left behind, the built-in's copy is what a reinstall carries back");

      await extensions.installBundle(await fromCatalog(store, bytes, '1.2.3'));
      expect(await keychain.read(key: 'account_creds_ham2k-qrz'), isNull);
    });

    test('go once nothing is left to carry them to, and stay for a twin still to be fetched', () async {
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({
        'extensionOverrides': {'sota': false},
      });
      for (final key in ['sota', 'pota', 'wca', 'qp']) {
        await keychain.write(key: 'account_creds_$key', value: jsonEncode({'username': 'n0dev'}));
      }
      // `pota` was on and its twin is still to come; `wca` was on too, and
      // its twin is installed; `sota` was switched off; `qp` has no twin.
      await settings.setExtensionOverrides({'sota': false, 'wca': true});
      await extensions.installBundle(await fromCatalog(store, twin('ham2k-wca'), '1.2.3'));
      await extensions.reloadAvailableExtensions();

      await extensions.forgetRetiredSecrets();
      expect(await keychain.read(key: 'account_creds_pota'), isNotNull, reason: 'the twin the catch-up fetches carries it');
      expect(await keychain.read(key: 'account_creds_wca'), isNull);
      expect(await keychain.read(key: 'account_creds_sota'), isNull);
      expect(await keychain.read(key: 'account_creds_qp'), isNull);
      expect(await keychain.read(key: 'account_creds_ham2k-wca'), isNotNull, reason: "the twin's own copy stays");
      expect(settings.extensionRetiredSecretsForgotten, containsAll(['wca', 'sota', 'qp']));
      expect(settings.extensionRetiredSecretsForgotten, isNot(contains('pota')));
    });

    test('are kept while the twin no longer holds its copy, and go once it does', () async {
      // A carry that failed, or a login the operator has since removed from
      // the twin: the built-in's copy is all there is, and goes only once
      // the twin is seen to hold its own.
      useInMemoryKeychain();
      final (extensions, settings, store) = await setup({});
      await keychain.write(key: 'account_creds_wca', value: jsonEncode({'username': 'n0dev'}));
      await settings.setExtensionOverrides({'wca': true});
      await extensions.installBundle(await fromCatalog(store, twin('ham2k-wca'), '1.2.3'));
      await extensions.reloadAvailableExtensions();
      await keychain.delete(key: 'account_creds_ham2k-wca');
      await extensions.forgetRetiredSecrets();
      expect(await keychain.read(key: 'account_creds_wca'), isNotNull);
      expect(settings.extensionRetiredSecretsForgotten, isNot(contains('wca')));
    });

    test('go once its twin was delivered, even after the operator removed it', () async {
      // Nothing fetches a twin the pre-load already delivered: kept for it,
      // they would wait forever, and the next install of the twin from the
      // catalog would carry them back.
      useInMemoryKeychain();
      final (extensions, settings, _) = await setup({
        'extensionPreloaded': {'ham2k-pota': '1.0.0'},
      });
      await keychain.write(key: 'account_creds_pota', value: jsonEncode({'username': 'n0dev'}));
      await extensions.forgetRetiredSecrets();
      expect(await keychain.read(key: 'account_creds_pota'), isNull);
      expect(settings.extensionRetiredSecretsForgotten, contains('pota'));
    });

    test('are tried again next launch when the keychain would not let them go', () async {
      // Recorded gone when they were not, a key is never tried again, and a
      // later install of its twin carries them back.
      final locked = awkwardKeychain(listing: -25308);
      final (extensions, settings, _) = await setup({
        'extensionOverrides': {'sota': false},
      });
      locked.items['account_creds_sota'] = '"n0dev"';
      await extensions.forgetRetiredSecrets();
      expect(locked.items, contains('account_creds_sota'));
      expect(settings.extensionRetiredSecretsForgotten, isNot(contains('sota')));

      locked.unlock();
      await extensions.forgetRetiredSecrets();
      expect(locked.items, isNot(contains('account_creds_sota')));
      expect(settings.extensionRetiredSecretsForgotten, contains('sota'));
    });
  });
}
