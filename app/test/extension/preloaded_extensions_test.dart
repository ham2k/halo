// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extensions the app ships already packaged.
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
import 'package:ham2k_logger/services/extensions/extension_keychain.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/extensions/preloaded_extensions.dart';
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
      final onDisk = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((name) => name.endsWith('.h2kext')).toList()..sort();
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

    test('every retired built-in with a twin has it shipped', () {
      // An install that ran the built-ins moves onto their twins at its first
      // boot without them, offline or not. A twin that is not shipped has to
      // come from the catalog, and until it does the extension the operator
      // used is simply gone. Shrinking this to the long-term eight is a
      // deliberate later step (docs/extensions/distribution.md).
      expect(
        {for (final entry in index) entry.key},
        {
          for (final builtIn in kRetiredBuiltIns.keys)
            if (!kBuiltInsWithoutTwin.contains(builtIn)) twinOf(builtIn),
          'ham2k-lookup',
        },
      );
    });
  });

  group('parsePreloadIndex', () {
    test('a catalog key inherits the retired built-in it is named after', () {
      // Without it, a twin arrives unconfigured and logged out: the settings,
      // credentials and on/off choice all hang off the built-in's name.
      expect(predecessorBuiltInKey('ham2k-wca'), 'wca');
      expect(predecessorBuiltInKey('ham2k-cqww'), 'cqww');
      expect(predecessorBuiltInKey('ham2k-pota'), 'pota');
    });

    test('a key that kept its name inherits nothing', () {
      // `ham2k-lookup` was built in under that very name. Stripping the prefix
      // would hand it `lookup`\'s state — a different extension entirely.
      expect(predecessorBuiltInKey('ham2k-lookup'), isNull);
    });

    test('a catalog key the app never built in inherits nothing', () {
      // The prefix is Ham2K\'s, not proof that this app ever had the key.
      expect(predecessorBuiltInKey('ham2k-something-else'), isNull);
      expect(predecessorBuiltInKey('k2hrc-llota'), isNull);
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

  group('what loads, once the app builds in only its core', () {
    Future<(ExtensionService, SettingsService)> harness() async {
      SharedPreferences.setMockInitialValues(const {});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF'),
        ExtensionInfo(key: 'ham2k-lofi', file: 'lofi.js', core: true, name: 'LoFi sync'),
        ExtensionInfo(
          key: 'ham2k-pota',
          file: 'index.js',
          core: false,
          name: 'POTA',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '0.2.0',
        ),
      ]);
      return (extensions, settings);
    }

    ExtensionInfo infoFor(ExtensionService extensions, String key) => extensions.availableExtensions.firstWhere((info) => info.key == key);

    test('an installed twin loads whether or not the move off the built-ins has run', () async {
      // Nothing is left to run in its place. Gating the twin on the move
      // leaves an install that has not made it yet — its first boot on this
      // build, before the catch-up — running core alone.
      final (extensions, settings) = await harness();
      for (final moved in [false, true]) {
        await settings.setExtensionsMigrated(moved);
        expect(extensions.isExtensionActive(infoFor(extensions, 'ham2k-pota')), isTrue, reason: 'moved: $moved');
        expect(extensions.isExtensionActive(infoFor(extensions, 'ham2k-lofi')), isTrue, reason: 'sync must never stop');
      }
    });

    test('a refusal never reaches a bundle the app builds in', () async {
      // Only an installed bundle is ever put aside: one the app builds in that
      // will not evaluate is a defect in the app, and skipping it would ship
      // an install quietly missing part of itself.
      final (extensions, settings) = await harness();
      await settings.setExtensionRefused({'adif': '0.0.1'});
      expect(extensions.isExtensionRefused(const ExtensionInfo(key: 'adif', file: 'adif.js', core: false, name: 'ADIF', version: '0.0.1')), isFalse);
    });

    test('a refusal is judged against the version that failed, not against its absence', () async {
      // `extensionRefused[key]` is null for an extension nobody refused.
      // Compared against a version that can be null, the two nulls are equal
      // — which withdraws everything, from an empty refusal map.
      final (extensions, _) = await harness();
      expect(extensions.isExtensionActive(infoFor(extensions, 'ham2k-pota')), isTrue);
    });

    test('a bundle the engine refused is kept out of the runtime but stays listed', () async {
      // One bundle that will not evaluate takes the whole runtime with it,
      // so it must not reach the load set. It must still reach the PANEL:
      // unavailable hides the row, and an extension that stopped working is
      // the one the operator comes to the panel to ask about — and updating
      // it there is how the refusal is lifted.
      final (extensions, settings) = await harness();
      final twin = infoFor(extensions, 'ham2k-pota');
      await settings.setExtensionRefused({twin.key: twin.version ?? ''});

      expect(extensions.isExtensionActive(twin), isFalse, reason: 'it would take the runtime down');
      expect(extensions.isExtensionAvailable(twin), isTrue, reason: 'the panel row is how it gets fixed');
    });

    test('and is offered again once the catalog serves a different version', () async {
      // Keyed by version so a fixed release recovers by itself: an ordinary
      // update installs it and the refusal no longer matches.
      final (extensions, settings) = await harness();
      final twin = infoFor(extensions, 'ham2k-pota');
      await settings.setExtensionRefused({twin.key: 'the-version-that-failed'});

      expect(extensions.isExtensionActive(twin), isTrue);
    });

    test('a choice named by its built-in key lands on the twin that runs', () async {
      // Onboarding names POTA as `pota`. Written under that key alone it
      // reaches nothing, and `ham2k-pota` runs whatever the operator said.
      final (extensions, settings) = await harness();
      await extensions.setExtensionsEnabled({'pota': false});
      expect(settings.extensionOverrides['ham2k-pota'], isFalse);
      expect(extensions.isExtensionActive(infoFor(extensions, 'ham2k-pota')), isFalse);
      // And under the built-in's key: the twin's is pruned while the twin is
      // not yet installed, and this is what the pre-load or the adoption
      // carries when it lands.
      expect(settings.extensionOverrides['pota'], isFalse);
    });

    test('a retired built-in\'s choice outlives the built-in, for its twin to inherit', () async {
      // The prune drops overrides for keys nothing lists, and the retired
      // built-ins are listed nowhere. A twin the app does not pre-load arrives
      // whenever the catalog is next reachable; by then a pruned `wca: true`
      // has become WCA arriving switched off, its default.
      final (extensions, settings) = await harness();
      await settings.setExtensionOverrides({'wca': true, 'hamdb': false});
      await extensions.applyExtensionAvailability();
      expect(settings.extensionOverrides['wca'], isTrue);
      expect(settings.extensionOverrides.containsKey('hamdb'), isFalse, reason: 'a key nothing ever shipped under is still pruned');
    });
  });

  group('carrying an operator\'s state across a rename', () {
    test('settings, panel values and the on/off choice follow, and the old key keeps its own', () async {
      // `ham2k-pota` is the built-in `pota` under a name the catalog can
      // serve. Copied, not moved: the built-in's own records stay exactly as
      // they were.
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
      SharedPreferences.setMockInitialValues(const {'settingsPanel.potato.token': 'not mine'});
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

    Future<ByteData> loadAsset(String key) async => ByteData.view(File('${assetDir.path}/${key.split('/').last}').readAsBytesSync().buffer);
    Future<String> loadIndex(String key) async => File('${assetDir.path}/index.json').readAsStringSync();

    /// What `recordInstall` was told, per key — `fresh` is what decides
    /// whether the operator's on/off choice is thrown away.
    late Map<String, bool> freshness;

    Future<bool> runPreload({
      Map<String, String?>? installed,
      Set<String> restoring = const {},
      Future<void> Function({required String from, required String to})? copySecrets,
    }) async => installShippedExtensions(
      store: store,
      settings: settings,
      installedVersions: installed ?? {for (final info in await store.list()) info.key: info.version},
      restoring: restoring,
      recordInstall: (bundle, {required bool fresh}) async => freshness[bundle.key] = fresh,
      copySecrets: copySecrets ?? ({required String from, required String to}) async {},
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
        // The app builds in none of the extensions it pre-loads.
        builtInKeys: () => const {},
        hostSharedModules: ((index['sharedModules'] as Map?) ?? const {}).cast<String, String>(),
        storage: FileBundleStorage(root: root),
        // The provenance the pre-load writes is what waives the prefix.
        reservedPrefixAllowed: (_) => true,
      );
    });
    tearDown(() => root.deleteSync(recursive: true));

    final shipped = parsePreloadIndex(jsonDecode(File('${assetDir.path}/index.json').readAsStringSync()));

    Future<void> switchAllOn() => settings.setExtensionOverrides({for (final entry in shipped) entry.key: true});

    Future<Set<String>> listed() async => {for (final info in await store.list()) info.key};

    test('every shipped bundle switched on lands, at the version the index names', () async {
      await switchAllOn();
      expect(await runPreload(), isTrue);
      final versions = {for (final info in await store.list()) info.key: info.version};
      expect(versions, {for (final entry in shipped) entry.key: entry.version});
    });

    test('only what is switched on lands, by the operator\'s choice else the built-in\'s default', () async {
      // Installed whatever its switch, an extension switched off is a dead row
      // in the Extensions panel and an update nobody runs — for a new install
      // most of the thirty-odd bundles the app ships.
      await settings.setExtensionOverrides({'wwff': true, 'pota': false});
      await runPreload();
      final keys = await listed();
      expect(keys, containsAll(['ham2k-qrz', 'ham2k-lookup', 'ham2k-wwff']));
      expect(keys, isNot(contains('ham2k-sota')), reason: 'off by default as a built-in');
      expect(keys, isNot(contains('ham2k-pota')), reason: 'the operator switched POTA off');
    });

    test('one skipped while switched off lands once it is switched on', () async {
      // Recorded as offered, it never would: the record is what stops a
      // pre-load installing a key again, and onboarding switches SOTA on only
      // after the first boot's pre-load has been and gone.
      await runPreload();
      expect(settings.extensionPreloaded.containsKey('ham2k-sota'), isFalse);
      await settings.setExtensionOverrides({...settings.extensionOverrides, 'sota': true});
      expect(await runPreload(), isTrue);
      expect(await listed(), contains('ham2k-sota'));
    });

    test('one removed while switched off stays out when the app ships a newer copy', () async {
      // The one-time removal keeps the switch and the pre-load record. Read
      // as on, the next app update carrying a newer bundle installs it again.
      await settings.setExtensionOverrides({'wwff': true});
      await runPreload();
      await store.uninstall('ham2k-wwff');
      await settings.setExtensionOverrides({...settings.extensionOverrides, 'ham2k-wwff': false});
      await settings.setExtensionPreloaded({...settings.extensionPreloaded, 'ham2k-wwff': '0.0.1'});
      await runPreload();
      expect(await listed(), isNot(contains('ham2k-wwff')));
    });

    test('a pre-load that carried a predecessor\'s state does not then throw it away', () async {
      // The two rules that used to collide. `copyExtensionRecords` carries the
      // operator\'s on/off choice across the rename; `fresh` exists to DROP a
      // stale choice so a key the store never had runs. Reported fresh, the
      // second undoes the first three lines later and every extension the
      // operator had switched off comes back on the moment they move.
      await runPreload();
      for (final key in freshness.keys) {
        final predecessor = predecessorBuiltInKey(key);
        if (predecessor != null) expect(freshness[key], isFalse, reason: '$key carried $predecessor\'s state');
      }
      // `ham2k-lookup` renames nothing, so there is no choice to protect and
      // the ordinary rule applies.
      expect(freshness['ham2k-lookup'], isTrue);
    });

    test('a shipped bundle the store lost comes back, without its state being reset', () async {
      // The pre-load record says it was already offered, which is true and
      // beside the point. Read as a first install instead, `ham2k-lookup` —
      // which replaces nothing — is recorded fresh, and a lookup the operator
      // had switched off comes back on.
      await runPreload();
      await store.uninstall('ham2k-lookup');
      freshness.clear();
      expect(await runPreload(), isFalse, reason: 'already offered, so not pre-loaded again on its own');
      expect(await runPreload(restoring: const {'ham2k-lookup'}), isTrue);
      expect(freshness, {'ham2k-lookup': false});
    });

    test('a choice made before the twin lands still reaches it', () async {
      // Onboarding can finish before the pre-load: the twin's override is
      // pruned as an unknown key, and only the built-in's — which the pre-load
      // carries — survives.
      await settings.setExtensionOverrides({'sota': true});
      await runPreload();
      expect(settings.extensionOverrides['ham2k-sota'], isTrue);
    });

    test('a choice already under the pre-load\'s own name decides it', () async {
      // `ham2k-lookup` was built in under that very name, so nothing carries
      // its choice — it is already where the twin reads it. Read past, a
      // lookup the operator had switched off is installed, and on.
      await settings.setExtensionOverrides({'ham2k-lookup': false});
      await runPreload();
      expect(await listed(), isNot(contains('ham2k-lookup')));
      expect(settings.extensionOverrides['ham2k-lookup'], isFalse);
    });

    test('a pre-load that failed for a reason that may pass is tried again', () async {
      // Recorded as offered, it never would be, and the adoption does not
      // fetch a twin the pre-load has offered.
      await settings.setExtensionOverrides({'sota': true});
      await withErrorHooks(() async {
        await runPreload(copySecrets: ({required from, required to}) async => from == 'sota' ? throw StateError('the keychain is locked') : null);
      });
      expect(settings.extensionPreloaded.containsKey('ham2k-sota'), isFalse);
      expect(await runPreload(), isTrue);
      expect((await store.list()).map((i) => i.key), contains('ham2k-sota'));
    });

    test('a second run installs nothing, because the record says they were offered', () async {
      await switchAllOn();
      await runPreload();
      expect(settings.extensionPreloaded.length, shipped.length);
      expect(await runPreload(), isFalse, reason: 'every launch would reinstall over the operator');
    });

    test('an uninstall is not undone by the next launch', () async {
      await runPreload();
      await store.uninstall('ham2k-pota');
      expect(await runPreload(), isFalse);
      expect((await store.list()).map((i) => i.key), isNot(contains('ham2k-pota')));
    });

    test('a catalog release ahead of the shipped one is left where it is', () async {
      await switchAllOn();
      expect(await runPreload(installed: const {'ham2k-pota': '9.9.9'}), isTrue);
      final listed = (await store.list()).map((i) => i.key).toSet();
      expect(listed, isNot(contains('ham2k-pota')), reason: 'the shipped bundle overwrote a newer release');
      expect(listed, contains('ham2k-sota'), reason: 'one key being current must not stop the others');
    });

    test('a bundle whose key the app is offering is refused, as any install would be', () async {
      // A pre-load is an install like any other: one claiming a key the app
      // builds in is refused exactly as a file install would be.
      store = InstalledExtensions(
        builtInKeys: () => const {'ham2k-lookup'},
        hostSharedModules: store.hostSharedModules,
        storage: FileBundleStorage(root: root),
        reservedPrefixAllowed: (_) => true,
      );
      await withErrorHooks(() async => runPreload());
      final listed = (await store.list()).map((i) => i.key).toSet();
      expect(listed, isNot(contains('ham2k-lookup')));
      expect(listed, contains('ham2k-pota'), reason: 'one refusal must not cost the others');
      // Refused for what the bundle is, so asked for again on every launch it
      // would cost a zip parse and the same report forever.
      expect(settings.extensionPreloaded.containsKey('ham2k-lookup'), isTrue);
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
      await copyExtensionKeychainItems(const FlutterSecureStorage(), from: 'sota', to: 'ham2k-sota', copyOne: (from, to) async => copied[from] = to);
      expect(copied, {'account_creds_sota': 'account_creds_ham2k-sota', 'account_session_sota': 'account_session_ham2k-sota'});
    });

    test('and the uninstall removes that same pair rather than nothing', () async {
      final deleted = <String>[];
      await forgetExtensionKeychainItems(const FlutterSecureStorage(), 'ham2k-sota', deleteOne: (name) async => deleted.add(name));
      expect(deleted, ['account_creds_ham2k-sota', 'account_session_ham2k-sota']);
    });
  });
}
