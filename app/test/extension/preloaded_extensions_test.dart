// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extensions the app ships already packaged (HALO-581).
//
// Two things can go wrong quietly here. The index can drift from the bundles
// beside it, which ships an app that pre-loads nothing and says nothing; and
// the decision to install can be got backwards, which either resurrects an
// extension the operator uninstalled or drags a catalog update backwards on
// the next launch.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_keychain.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/installed_extensions.dart';
import 'package:ham2k_logger/services/preloaded_extensions.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shipped index', () {
    // Read off disk rather than through rootBundle: the files are the source
    // of truth, and a test that went through the asset bundle would also be
    // testing pubspec wiring it cannot fix.
    final dir = Directory('assets/preloaded-extensions');
    final index = parsePreloadIndex(jsonDecode(File('${dir.path}/index.json').readAsStringSync()));

    test('names every bundle in the directory, and only those', () {
      // A bundle added and left out of the index ships dead weight and never
      // loads; an entry left in after its file went is a report on every
      // launch. Neither says anything on its own.
      final onDisk = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.h2kext'))
          .toList()
        ..sort();
      expect([for (final entry in index) entry.file]..sort(), onDisk);
      expect(onDisk, isNotEmpty, reason: 'the app ships no pre-loaded bundles at all');
    });

    test('states each bundle\'s real key, version and hash', () {
      // The index is what the pre-loader reads to decide anything: a version
      // ahead of the bundle's own makes the app record a pre-load it never
      // performed, and the key is what the whole migration hangs off.
      for (final entry in index) {
        final bytes = File('${dir.path}/${entry.file}').readAsBytesSync();
        expect(sha256.convert(bytes).toString(), entry.sha256, reason: entry.file);
        final archive = ZipDecoder().decodeBytes(bytes);
        final manifest = jsonDecode(utf8.decode(archive.findFile('manifest.json')!.content as List<int>));
        expect(manifest['key'], entry.key, reason: entry.file);
        expect(manifest['version'], entry.version, reason: entry.file);
      }
    });

    test('every key carries the reserved prefix, which is what lets it install', () {
      // The store refuses a `ham2k-` key to anything but a bundle Ham2K put
      // there, so a pre-load named anything else would be refused at its own
      // door. The prefix buys nothing beyond that: it opens no build secret,
      // and the values a twin once needed ship inside it as constants.
      for (final entry in index) {
        expect(entry.key, startsWith('ham2k-'), reason: entry.file);
      }
    });

    test('the eight the app promises are the eight it ships', () {
      expect({for (final entry in index) entry.key}, {
        'ham2k-pota',
        'ham2k-sota',
        'ham2k-wwff',
        'ham2k-lookup',
        'ham2k-qrz',
        'ham2k-call-notes',
        'ham2k-spot-history',
        'ham2k-call-history',
      });
    });

    test('each one that renames a built-in says which, and no name is claimed twice', () {
      // `kPreloadReplaces` is what carries an operator's settings and logins
      // across the rename. A missing entry loses them silently; two keys
      // naming one predecessor would have the second overwrite the first.
      final predecessors = kPreloadReplaces.values.toList();
      expect(predecessors.toSet().length, predecessors.length, reason: 'two pre-loads claim one built-in');
      for (final key in kPreloadReplaces.keys) {
        expect({for (final entry in index) entry.key}, contains(key), reason: '$key is not shipped');
      }
      // The one that keeps its name has nothing to carry, and saying so is
      // the difference between "no predecessor" and "we forgot".
      expect(kPreloadReplaces.containsKey('ham2k-lookup'), isFalse);
    });
  });

  group('parsePreloadIndex', () {
    test('a catalog key inherits the built-in it is named after', () {
      // The rule the seven named renames are exceptions to. Thirty-three
      // built-ins have no entry in `kPreloadReplaces` and are withdrawn by the
      // experiment all the same; without the rule, reinstalling one from the
      // catalog is a silent loss of everything the operator had set up.
      const builtIns = {'wca', 'cqww', 'pota', 'ham2k-lookup'};
      expect(predecessorBuiltInKey('ham2k-wca', builtIns), 'wca');
      expect(predecessorBuiltInKey('ham2k-cqww', builtIns), 'cqww');
      // The named ones still win, since their names do not follow the rule.
      expect(predecessorBuiltInKey('ham2k-pota', builtIns), 'pota');
    });

    test('a key that IS a built-in inherits nothing, whatever it starts with', () {
      // `ham2k-lookup` is called that as a built-in too. Stripping the prefix
      // would hand it `lookup`\'s state — a different extension entirely.
      expect(predecessorBuiltInKey('ham2k-lookup', {'ham2k-lookup', 'lookup'}), isNull);
    });

    test('a withdrawn built-in is still one the app ships', () {
      // The distinction the adoption turns on. `isBuiltInOffered` is false for
      // every non-core built-in once migrated, so a set built from what is
      // OFFERED is core-only by the time the adoption runs — and every
      // predecessor here would come back null, which is every adopted twin
      // arriving unconfigured and logged out.
      expect(predecessorBuiltInKey('ham2k-eca', const {'eca', 'adif'}), 'eca');
      expect(predecessorBuiltInKey('ham2k-eca', const {'adif'}), isNull);
    });

    test('a catalog key the app never shipped inherits nothing', () {
      // The prefix is Ham2K\'s, not proof that this app ever had the key.
      expect(predecessorBuiltInKey('ham2k-something-else', {'wca'}), isNull);
      expect(predecessorBuiltInKey('k2hrc-llota', {'llota'}), isNull);
    });

    test('drops an entry it cannot read rather than the whole list', () {
      final parsed = parsePreloadIndex({
        'preloaded': [
          {'key': 'ham2k-a', 'version': '1.0.0', 'file': 'ham2k-a-1.0.0.h2kext', 'sha256': 'a' * 64},
          {'key': 'ham2k-b', 'version': '1.0.0', 'file': 'ham2k-b.h2kext'},
          'nonsense',
        ],
      });
      expect([for (final e in parsed) e.key], ['ham2k-a']);
    });

    test('refuses a file name that is not a plain bundle beside the index', () {
      // The index is shipped, not fetched — but it is still the one string
      // that becomes an asset path, and a traversal there would read
      // whatever it named.
      for (final file in ['../secrets.json', 'a/b.h2kext', '/etc/passwd', 'x.js', '.h2kext']) {
        final parsed = parsePreloadIndex({
          'preloaded': [
            {'key': 'ham2k-a', 'version': '1.0.0', 'file': file, 'sha256': 'a' * 64},
          ],
        });
        expect(parsed, isEmpty, reason: file);
      }
    });

    test('a missing or unreadable index is no bundles, not a crash', () {
      expect(parsePreloadIndex(null), isEmpty);
      expect(parsePreloadIndex(const {}), isEmpty);
      expect(parsePreloadIndex(const {'preloaded': 'nope'}), isEmpty);
    });
  });

  group('shouldPreload', () {
    const bundle = PreloadedBundle(key: 'ham2k-pota', version: '0.2.0', file: 'x.h2kext', sha256: '');

    test('installs when nothing has been pre-loaded and nothing is installed', () {
      expect(shouldPreload(bundle), isTrue);
    });

    test('never installs a version it has already offered', () {
      // The rule that makes an uninstall stick. The operator removing an
      // extension leaves the record behind on purpose, and reading it as
      // "not installed, so install it" brings the extension back on the very
      // next launch, with nothing to explain it.
      expect(shouldPreload(bundle, preloadedVersion: '0.2.0'), isFalse);
      expect(shouldPreload(bundle, preloadedVersion: '0.3.0'), isFalse);
      expect(shouldPreload(bundle, preloadedVersion: '0.1.0'), isTrue, reason: 'an app update carries a newer one');
    });

    test('never installs over something at least as new', () {
      // An operator who took a catalog update must not have it undone by an
      // app that merely launched.
      expect(shouldPreload(bundle, installedVersion: '0.2.0'), isFalse);
      expect(shouldPreload(bundle, installedVersion: '1.0.0'), isFalse);
      expect(shouldPreload(bundle, installedVersion: '0.1.0'), isTrue);
    });

    test('an app update past a catalog release the operator already has does nothing', () {
      // Both records present and both ahead: the shipped bundle is the oldest
      // thing in the room and has no business installing.
      expect(shouldPreload(bundle, preloadedVersion: '0.1.0', installedVersion: '0.5.0'), isFalse);
    });

    test('a version nobody can order installs over nothing', () {
      const unreadable = PreloadedBundle(key: 'ham2k-pota', version: 'latest', file: 'x.h2kext', sha256: '');
      expect(shouldPreload(unreadable), isFalse);
      // And an unreadable record on the other side does not block a real one.
      expect(shouldPreload(bundle, installedVersion: 'whenever'), isTrue);
    });

    test('a pre-release is older than the release it precedes', () {
      // pub_semver's ordering, which is the catalog's too — `0.2.0-beta1`
      // must not read as newer than `0.2.0` and reinstall over it.
      const beta = PreloadedBundle(key: 'ham2k-pota', version: '0.2.0-beta1', file: 'x.h2kext', sha256: '');
      expect(shouldPreload(beta, installedVersion: '0.2.0'), isFalse);
      expect(shouldPreload(bundle, installedVersion: '0.2.0-beta1'), isTrue);
    });
  });

  group('moving to the catalog withdraws the app\'s own extensions', () {
    // The experiment says the upgrade is OFFERED; `extensionsMigrated` says it
    // was taken, and only both together withdraw anything — see
    // catalog_migration_test.dart, which holds that pair. Everything here is
    // about what withdrawal then does, so these set both.
    Future<void> moveToCatalog(SettingsService settings) async {
      await settings.setExperimentEnabled('catalog', true);
      await settings.setExtensionsMigrated(true);
    }

    Future<(ExtensionService, SettingsService)> harness() async {
      SharedPreferences.setMockInitialValues(const {});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA', category: 'activity'),
        ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF'),
        ExtensionInfo(key: 'ham2k-lofi', file: 'lofi.js', core: true, name: 'LoFi sync'),
        ExtensionInfo(
            key: 'ham2k-pota', file: 'index.js', core: false, name: 'POTA', category: 'activity',
            source: ExtensionSource.installed, version: '0.2.0'),
      ]);
      return (extensions, settings);
    }

    ExtensionInfo infoFor(ExtensionService extensions, String key) =>
        extensions.availableExtensions.firstWhere((info) => info.key == key);

    test('off the experiment, everything the app ships is offered', () async {
      final (extensions, _) = await harness();
      for (final key in ['pota', 'adif', 'ham2k-lofi']) {
        expect(extensions.isExtensionAvailable(infoFor(extensions, key)), isTrue, reason: key);
      }
    });

    test('on it, a non-core built-in is withdrawn and the core ones are not', () async {
      // `ham2k-lofi` is core, so sync keeps running — withdrawing it would
      // stop an operator's log syncing the moment they tried the experiment.
      final (extensions, settings) = await harness();
      await moveToCatalog(settings);
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'pota')), isFalse);
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'adif')), isTrue);
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'ham2k-lofi')), isTrue);
    });

    test('a refusal never reaches the built-in that shares its key', () async {
      // `ham2k-lookup` is both a bundle the app ships and one the catalog
      // serves. A record written for the downloaded copy must not take the
      // app's own out of the set — the two differ in version today, and
      // nothing enforces that they always will.
      final (extensions, settings) = await harness();
      const asset = ExtensionInfo(
          key: 'ham2k-lookup', file: 'ham2k-lookup.js', core: false, name: 'Lookup', version: '0.0.1');
      const installed = ExtensionInfo(
        key: 'ham2k-lookup',
        file: 'ham2k-lookup.js',
        source: ExtensionSource.installed,
        core: false,
        name: 'Lookup',
        version: '0.0.1',
      );
      await settings.setExtensionRefused({'ham2k-lookup': '0.0.1'});

      expect(extensions.isExtensionRefused(asset), isFalse, reason: 'the app would ship missing part of itself');
      expect(extensions.isExtensionRefused(installed), isTrue);
    });

    test('a refusal is judged against the version that failed, not against its absence', () async {
      // `extensionRefused[key]` is null for an extension nobody refused, and
      // a built-in's version is null too. Compared directly, those two nulls
      // are equal — which withdraws every extension the app ships, from an
      // empty refusal map.
      final (extensions, _) = await harness();
      expect(extensions.isExtensionActive(infoFor(extensions, 'pota')), isTrue);
    });

    test('a bundle the engine refused is kept out of the runtime but stays listed', () async {
      // One bundle that will not evaluate takes the whole runtime with it,
      // so it must not reach the load set. It must still reach the PANEL:
      // unavailable hides the row, and an extension that stopped working is
      // the one the operator comes to the panel to ask about — and updating
      // it there is how the refusal is lifted.
      final (extensions, settings) = await harness();
      await moveToCatalog(settings);
      final twin = infoFor(extensions, 'ham2k-pota');
      await settings.setExtensionRefused({twin.key: twin.version ?? ''});

      expect(extensions.isExtensionActive(twin), isFalse, reason: 'it would take the runtime down');
      expect(extensions.isExtensionAvailable(twin), isTrue, reason: 'the panel row is how it gets fixed');
    });

    test('and is offered again once the catalog serves a different version', () async {
      // Keyed by version so a fixed release recovers by itself: an ordinary
      // update installs it and the refusal no longer matches.
      final (extensions, settings) = await harness();
      await moveToCatalog(settings);
      final twin = infoFor(extensions, 'ham2k-pota');
      await settings.setExtensionRefused({twin.key: 'the-version-that-failed'});

      expect(extensions.isExtensionActive(twin), isTrue);
    });

    test('an installed extension is never withdrawn while the experiment is on', () async {
      // The whole point: the catalog's copies replace the built-ins, so
      // withdrawing them too would leave the app with nothing at all.
      final (extensions, settings) = await harness();
      await moveToCatalog(settings);
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'ham2k-pota')), isTrue);
    });

    test('with the experiment off, the pre-load stands down for the built-in it replaced', () async {
      // Otherwise turning the experiment off leaves both loaded: two POTA
      // rows in the panel, both registering `ref:pota`, and one of them
      // winning by position with nothing to say which.
      final (extensions, _) = await harness();
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'pota')), isTrue);
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'ham2k-pota')), isFalse);
    });

    test('an installed extension that replaces nothing is left alone either way', () async {
      // The rule is about a duplicate, not about being installed. Anything
      // the app never had a copy of has no built-in to stand down for.
      SharedPreferences.setMockInitialValues(const {});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      const llota = ExtensionInfo(
          key: 'ce1vk-llota', file: 'index.js', core: false, name: 'LLOTA', category: 'activity',
          source: ExtensionSource.installed, version: '1.0.0');
      extensions.debugSetAvailableExtensions(const [llota]);
      expect(extensions.isExtensionAvailable(llota), isTrue);
      await moveToCatalog(settings);
      expect(extensions.isExtensionAvailable(llota), isTrue);
    });

    test('nothing is withdrawn where no store can replace it', () async {
      // On web there is no installed-extension store, so the pre-loads never
      // land. Withdrawing the built-ins there would leave the app with the
      // core extensions and nothing else — and this suite runs native, where
      // the store exists, so the assertion is that the guard is CONSULTED.
      final (extensions, settings) = await harness();
      await moveToCatalog(settings);
      expect(InstalledExtensions.isSupported, isTrue, reason: 'this suite runs where a store exists');
      expect(extensions.isExtensionAvailable(infoFor(extensions, 'pota')), isFalse);
    });

    test('a withdrawn built-in stays in the list, so its on/off choice survives', () async {
      // `_updateDisabledSince` prunes overrides for any key absent from
      // `availableExtensions`. Gating by removal would delete the operator's
      // choice for every built-in the moment they tried the experiment, and
      // turning it back off would find them all reset.
      final (extensions, settings) = await harness();
      await settings.setExtensionOverrides({'pota': false});
      await moveToCatalog(settings);
      expect(extensions.availableExtensions.map((i) => i.key), contains('pota'));
      expect(settings.extensionOverrides['pota'], isFalse);
    });
  });

  group('carrying an operator\'s state across a rename', () {
    test('settings, panel values and the on/off choice follow, and the old key keeps its own', () async {
      // `ham2k-pota` is the built-in `pota` under a name the catalog can
      // serve. Copied, not moved: turning the experiment back off has to
      // find the built-in exactly as it was.
      SharedPreferences.setMockInitialValues(const {
        'settings.extension_pota': '{"spotting":true}',
        'settingsPanel.pota.token': 'abc',
        'settingsPanel.pota_spots.limit': 7,
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      await settings.setExtensionOverrides({'pota': false});

      await settings.copyExtensionRecords(from: 'pota', to: 'ham2k-pota');

      expect(settings.prefs.getString('settings.extension_ham2k-pota'), '{"spotting":true}');
      expect(settings.prefs.getString('settingsPanel.ham2k-pota.token'), 'abc');
      expect(settings.prefs.getInt('settingsPanel.ham2k-pota_spots.limit'), 7);
      expect(settings.extensionOverrides['ham2k-pota'], isFalse);
      // The originals are untouched.
      expect(settings.prefs.getString('settings.extension_pota'), '{"spotting":true}');
      expect(settings.extensionOverrides['pota'], isFalse);
    });

    test('a value already under the new key wins', () async {
      // This runs once per key, but "once" is a record that could be lost —
      // and overwriting a choice made under the new key with an older one
      // made under the old is the worse of the two mistakes.
      SharedPreferences.setMockInitialValues(const {
        'settings.extension_pota': '{"spotting":true}',
        'settings.extension_ham2k-pota': '{"spotting":false}',
        'settingsPanel.pota.token': 'old',
        'settingsPanel.ham2k-pota.token': 'new',
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      await settings.copyExtensionRecords(from: 'pota', to: 'ham2k-pota');
      expect(settings.prefs.getString('settings.extension_ham2k-pota'), '{"spotting":false}');
      expect(settings.prefs.getString('settingsPanel.ham2k-pota.token'), 'new');
    });

    test('a key that only looks like a prefix is left alone', () async {
      // `potato` starts with `pota` and belongs to somebody else. The
      // namespacing rule is the extension key followed by `.` or `_`, and
      // matching on the bare prefix would take a neighbour's settings.
      SharedPreferences.setMockInitialValues(const {
        'settingsPanel.potato.token': 'not mine',
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      await settings.copyExtensionRecords(from: 'pota', to: 'ham2k-pota');
      expect(settings.prefs.getString('settingsPanel.ham2k-potato.token'), isNull);
      expect(settings.prefs.getString('settingsPanel.potato.token'), 'not mine');
    });
  });

  group('the shipped bundles install through the real door', () {
    // Everything above tests a piece. This runs the whole path over the real
    // assets: the real zips, the real manifest validation (which now refuses
    // `enabledByDefault` and a leftover `geo`), the real shared-dependency
    // check against what this build's kernel carries, the reserved-prefix
    // waiver and the built-in collision rule. A bundle that would be refused
    // on a tester's machine is refused here.
    late Directory root;
    late InstalledExtensions store;
    late SettingsService settings;
    final assetDir = Directory('assets/preloaded-extensions');

    Future<ByteData> loadAsset(String key) async =>
        ByteData.view(File('${assetDir.path}/${key.split('/').last}').readAsBytesSync().buffer);
    Future<String> loadIndex(String key) async => File('${assetDir.path}/index.json').readAsStringSync();

    /// What `recordInstall` was told, per key — `fresh` is what decides
    /// whether the operator's on/off choice is thrown away.
    late Map<String, bool> freshness;

    Future<bool> runPreload({Map<String, String?> installed = const {}}) => installShippedExtensions(
          store: store,
          settings: settings,
          installedVersions: installed,
          recordInstall: (bundle, {required bool fresh}) async => freshness[bundle.key] = fresh,
          copySecrets: ({required String from, required String to}) async {},
          loadAsset: loadAsset,
          loadIndex: loadIndex,
        );

    setUp(() async {
      freshness = {};
      root = Directory.systemTemp.createTempSync('preload-test');
      SharedPreferences.setMockInitialValues(const {});
      settings = SettingsService(await SharedPreferences.getInstance());
      final index = jsonDecode(File('assets/extensions/index.json').readAsStringSync()) as Map<String, dynamic>;
      store = InstalledExtensions(
        // What the app ships. `ham2k-lookup` is in here on purpose: it is a
        // built-in AND a pre-load, and if the collision rule looked at what
        // the app CARRIES rather than what it offers, this is the bundle it
        // would refuse.
        builtInKeys: () => const {},
        hostSharedModules: ((index['sharedModules'] as Map?) ?? const {}).cast<String, String>(),
        rootOverride: root,
        // The provenance the pre-load writes is what waives the prefix.
        reservedPrefixAllowed: (_) => true,
      );
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('all eight land, at the versions the index names', () async {
      expect(await runPreload(), isTrue);
      final listed = {for (final info in await store.list()) info.key: info.version};
      final index = parsePreloadIndex(jsonDecode(File('${assetDir.path}/index.json').readAsStringSync()));
      expect(listed, {for (final entry in index) entry.key: entry.version});
    });

    test('a pre-load that carried a predecessor\'s state does not then throw it away', () async {
      // The two rules that used to collide. `copyExtensionRecords` carries the
      // operator\'s on/off choice across the rename; `fresh` exists to DROP a
      // stale choice so a key the store never had runs. Reported fresh, the
      // second undoes the first three lines later and every extension the
      // operator had switched off comes back on the moment the experiment is
      // flipped.
      await runPreload();
      // Seven of the eight take over from a built-in and carry its state.
      for (final key in kPreloadReplaces.keys) {
        expect(freshness[key], isFalse, reason: '$key carried ${kPreloadReplaces[key]}\'s state');
      }
      // The eighth renames nothing, so there is no choice to protect and the
      // ordinary rule applies.
      expect(freshness['ham2k-lookup'], isTrue);
    });

    test('a second run installs nothing, because the record says they were offered', () async {
      await runPreload();
      expect(settings.extensionPreloaded.length, 8);
      expect(await runPreload(), isFalse, reason: 'every launch would reinstall over the operator');
    });

    test('an uninstall is not undone by the next launch', () async {
      await runPreload();
      await store.uninstall('ham2k-pota');
      expect(await runPreload(), isFalse);
      expect((await store.list()).map((i) => i.key), isNot(contains('ham2k-pota')));
    });

    test('a catalog release ahead of the shipped one is left where it is', () async {
      expect(await runPreload(installed: const {'ham2k-pota': '9.9.9'}), isTrue);
      final listed = (await store.list()).map((i) => i.key).toSet();
      expect(listed, isNot(contains('ham2k-pota')), reason: 'the shipped bundle overwrote a newer release');
      expect(listed, contains('ham2k-sota'), reason: 'one key being current must not stop the others');
    });

    test('a bundle whose key the app is offering is refused, as any install would be', () async {
      // The rule this relaxes is still a rule: with `ham2k-lookup` offered as
      // a built-in, its pre-load must be refused exactly as a file install
      // would be — the relaxation is about WHEN the app offers it, not about
      // dropping the check.
      store = InstalledExtensions(
        builtInKeys: () => const {'ham2k-lookup'},
        hostSharedModules: store.hostSharedModules,
        rootOverride: root,
        reservedPrefixAllowed: (_) => true,
      );
      await runPreload();
      final listed = (await store.list()).map((i) => i.key).toSet();
      expect(listed, isNot(contains('ham2k-lookup')));
      expect(listed, contains('ham2k-pota'), reason: 'one refusal must not cost the other seven');
    });
  });

  group('the keychain copy where the platform will not enumerate', () {
    // The refusal is remembered for the process, so each case starts from a
    // platform that has not been asked yet.
    setUp(debugResetKeychainEnumeration);

    // macOS answers `readAll` with errSecParam (-50) against the FILE
    // keychain this build has to use. Treating enumeration as reliable meant
    // the copy did nothing at all and reported a platform exception in place
    // of the work it skipped — an operator saw their SOTA login simply gone.
    test('falls back to the account pair, whose names are fixed by convention', () async {
      final copied = <String, String>{};
      await copyExtensionKeychainItems(
        const FlutterSecureStorage(),
        from: 'sota',
        to: 'ham2k-sota',
        copyOne: (from, to) async => copied[from] = to,
      );
      expect(copied, {
        'account_creds_sota': 'account_creds_ham2k-sota',
        'account_session_sota': 'account_session_ham2k-sota',
      });
    });

    test('and the uninstall removes that same pair rather than nothing', () async {
      final deleted = <String>[];
      await forgetExtensionKeychainItems(
        const FlutterSecureStorage(),
        'ham2k-sota',
        deleteOne: (name) async => deleted.add(name),
      );
      expect(deleted, ['account_creds_ham2k-sota', 'account_session_ham2k-sota']);
    });
  });
}
