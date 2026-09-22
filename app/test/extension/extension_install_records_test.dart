// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an install writes to settings besides the files: the provenance
// record, the operator's own switch, and the catalog's revocation record. The
// traps are one write standing in for another — an update turning on what
// the operator turned off, a switch standing in for a revocation — so each
// test here flips one and reads the others.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/installed_extensions.dart';
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
      rootOverride: root,
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
