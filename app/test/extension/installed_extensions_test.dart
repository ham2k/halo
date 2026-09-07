// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Installing a `.h2kext` (HALO-422).
//
// The fixture is a real bundle, written by the real packer
// (extensions/tools/h2kext-pack.mjs) rather than assembled here. A hand-built
// zip would only ever test what this file already believes about the format;
// the point of these is that the two ends agree.
//
// Most of what follows is refusals. An extension is code the app will execute,
// arriving as a file from anyone, so what gets turned away matters more than
// what gets through.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/installed_extensions.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late List<int> fixture;

  setUp(() {
    root = Directory.systemTemp.createTempSync('installed-ext');
    fixture = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  InstalledExtensions store({
    Set<String> builtIn = const {'pota', 'sota'},
    Map<String, String>? shared,
    bool Function(String key)? catalogInstalled,
  }) =>
      InstalledExtensions(
        builtInKeys: builtIn,
        hostSharedModules: shared ?? const {'i18next': '23.11.5', '@ham2k/lib-callsigns': '1.0.2'},
        rootOverride: root,
        catalogInstalled: catalogInstalled,
      );

  /// The fixture with its manifest rewritten — for the cases the packer would
  /// never produce, which are exactly the ones an attacker would.
  List<int> rebuilt(Map<String, dynamic> Function(Map<String, dynamic>) edit, {String? extraEntry}) {
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
    if (extraEntry != null) {
      final bytes = utf8.encode('gotcha');
      out.addFile(ArchiveFile(extraEntry, bytes.length, bytes));
    }
    return ZipEncoder().encode(out);
  }

  group('inspecting', () {
    test('reads what the operator is about to be asked to approve', () async {
      final bundle = await store().inspect(fixture);

      expect(bundle.key, 'ki2d-my-clock');
      expect(bundle.name, 'KI2D My Clock');
      expect(bundle.version, '1.2.3');
      // The domains ARE its network access: host.fetch permits nothing else.
      expect(bundle.domains, ['time.example.org']);
      expect(bundle.claimsCapabilities, isTrue);
    });

    test('writes nothing — the consent screen comes between this and installing', () async {
      await store().inspect(fixture);

      // A screen that could only be shown after the thing was already unpacked
      // would not be a consent screen.
      expect(root.listSync(), isEmpty);
    });
  });

  group('what it refuses', () {
    test('a file that is not an archive', () async {
      // Sniffed rather than trusted from the name: Android's picker returns a
      // cache copy whose extension the platform rewrote from the MIME type.
      await expectLater(
        store().inspect(utf8.encode('<html>not a bundle</html>')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.notAnArchive)),
      );
    });

    test('a key the app already ships', () async {
      // Hook identity has to stay unambiguous, and secret visibility is by key
      // prefix — an installed extension calling itself `sota` would be asking
      // to read SOTA_*.
      await expectLater(
        store().inspect(rebuilt((m) => {...m, 'key': 'sota'})),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.collidesWithBuiltIn)),
      );
    });

    test('the reserved ham2k- prefix', () async {
      // There is no signing, so anyone could claim it, and the key is what the
      // app shows when it says where a hook came from.
      await expectLater(
        store().inspect(rebuilt((m) => {...m, 'key': 'ham2k-lofi'})),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.reservedKey)),
      );
    });

    test('the reserved prefix is waived for bytes the catalog vouched for, and for nothing else', () async {
      // The waiver hinges on the BYTES matching the listing's hash, not on a
      // caller's word: a provenance naming the catalog over the wrong hash is
      // refused as a mismatch before the key is even read, and a matching
      // hash from any other host still meets the reserved-prefix refusal.
      final bytes = rebuilt((m) => {...m, 'key': 'ham2k-clock'});
      final hash = sha256Hex(bytes);
      BundleProvenance provenance({String host = kCatalogHost, String sha256 = '', String version = '1.2.3'}) =>
          BundleProvenance(host: host, sha256: sha256.isEmpty ? hash : sha256, version: version);

      final bundle = await store().inspect(bytes, provenance: provenance());
      expect(bundle.key, 'ham2k-clock');
      expect(bundle.provenance?.isCatalog, isTrue);

      await expectLater(
        store().inspect(bytes, provenance: provenance(host: 'mirror.example.org')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.reservedKey)),
      );
      await expectLater(
        store().inspect(bytes, provenance: provenance(sha256: 'f' * 64)),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.hashMismatch)),
      );
      // The listing named one version and the bundle carries another: the
      // record would otherwise vouch for a version the catalog never served.
      await expectLater(
        store().inspect(bytes, provenance: provenance(version: '9.9.9')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.hashMismatch)),
      );
      // Not a waiver of the built-in collision: hook identity and secret
      // visibility are keyed by name whatever the source.
      await expectLater(
        store(builtIn: const {'ham2k-clock'}).inspect(bytes, provenance: provenance()),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.collidesWithBuiltIn)),
      );
      expect(
        () => store(builtIn: const {'ham2k-clock'}).checkKeyInstallable('ham2k-clock', provenance: provenance()),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.collidesWithBuiltIn)),
      );
    });

    test('a key the runtime could not carry', () async {
      for (final key in ['UPPER', 'has space', 'semi;colon', '']) {
        await expectLater(
          store().inspect(rebuilt((m) => {...m, 'key': key})),
          throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.invalidKey)),
          reason: 'expected "$key" to be refused',
        );
      }
    });

    test('an extension built for a newer app', () async {
      await expectLater(
        store().inspect(rebuilt((m) => {...m, 'api': kExtensionApiVersion + 1})),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.apiTooNew)),
      );
    });

    test('a shared dependency this build cannot satisfy', () async {
      // The alternative is a hook dying at a call into a major the author
      // never tested, with nothing to connect it to the cause.
      await expectLater(
        store(shared: const {'i18next': '22.0.0'}).inspect(fixture),
        throwsA(isA<BundleException>()
            .having((e) => e.reason, 'reason', BundleRejection.unsatisfiedDependency)
            .having((e) => e.message, 'message', allOf(contains('i18next'), contains('22.0.0')))),
      );
    });

    test('a shared dependency this build does not carry at all', () async {
      await expectLater(
        store(shared: const {}).inspect(fixture),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.unsatisfiedDependency)),
      );
    });
  });

  group('installing', () {
    test('unpacks, and the extension is then listed and loadable', () async {
      final s = store();
      await s.install(await s.inspect(fixture));

      final listed = await s.list();
      expect(listed.map((i) => i.key), ['ki2d-my-clock']);
      // Provenance travels with it, and is what withholds build secrets.
      expect(listed.single.source, ExtensionSource.installed);
      expect(listed.single.domains, ['time.example.org']);
      expect(await s.sourceFor('ki2d-my-clock'), contains('defineExtension'));
      expect(File(p.join(root.path, 'ki2d-my-clock', 'assets', 'note.txt')).existsSync(), isTrue);
    });

    test('an installed ham2k- key is listed only while its provenance record vouches for it', () async {
      // Re-judged on EVERY read: the record is what waives the prefix, so a
      // read after the record is gone (an uninstall, a file install of the
      // same key) must refuse the directory that is still on disk. A waiver
      // that stuck once granted would hand a sideloaded bundle Ham2K's name.
      final bytes = rebuilt((m) => {...m, 'key': 'ham2k-clock'});
      final vouched = <String>{'ham2k-clock'};
      final s = store(catalogInstalled: vouched.contains);
      await s.install(await s.inspect(bytes,
          provenance: BundleProvenance(host: kCatalogHost, sha256: sha256Hex(bytes), version: '1.2.3')));

      expect((await s.list()).map((i) => i.key), ['ham2k-clock']);
      vouched.clear();
      expect(await s.list(), isEmpty);
      // The directory is untouched — refused on read, not deleted.
      expect(Directory(p.join(root.path, 'ham2k-clock')).existsSync(), isTrue);
    });

    test('version and geo travel from the manifest on disk to the listing', () async {
      // An update check compares `version` and the panel ranks by `geo`, both
      // for an extension that may be DISABLED — so both must come off the
      // manifest on disk, not out of a running bundle.
      final s = store();
      await s.install(await s.inspect(rebuilt((m) => {
            ...m,
            'version': '4.5.6',
            'geo': {
              'entities': ['CE'],
              'ituRegions': [2],
            },
          })));

      final listed = (await s.list()).single;
      expect(listed.version, '4.5.6');
      expect(listed.geo!.entities, ['CE']);
      expect(listed.geo!.ituRegions, [2]);
      expect(listed.geo!.matches(entityPrefix: 'CE', ituRegion: 2), isTrue);
      expect(listed.geo!.matches(entityPrefix: 'K', ituRegion: 2), isFalse);
    });

    test('a bundle carrying a path-traversing entry is REFUSED, not quietly installed', () async {
      // An entry named `../` is not a packaging accident — the only way one
      // reaches a zip is deliberately. Installing the rest of such a bundle
      // and saying nothing hands the operator an extension nobody agreed to,
      // so it is turned away at inspect, before anything is written.
      await expectLater(
        store().inspect(rebuilt((m) => m, extraEntry: '../escaped.txt')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.unsafeEntry)),
      );
      expect(File(p.join(root.path, 'escaped.txt')).existsSync(), isFalse);
    });

    test('an entry outside the format is refused', () async {
      // The unpacker enforces the format the docs describe, rather than
      // writing whatever the archive happens to hold.
      await expectLater(
        store().inspect(rebuilt((m) => m, extraEntry: 'sneaky.sh')),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.unsafeEntry)),
      );
    });

    test('safeJoin refuses every shape of escape, and allows the ordinary ones', () {
      const dir = '/tmp/extensions/ki2d-my-clock';
      for (final entry in ['../escaped.txt', '../../escaped.txt', 'a/../../escaped.txt', '/etc/passwd', r'..\\windows']) {
        expect(InstalledExtensions.safeJoin(dir, entry), isNull, reason: 'expected "$entry" to be refused');
      }
      expect(InstalledExtensions.safeJoin(dir, 'index.js'), '$dir/index.js');
      expect(InstalledExtensions.safeJoin(dir, 'assets/note.txt'), '$dir/assets/note.txt');
    });

    test('reinstalling replaces the directory rather than merging into it', () async {
      final s = store();
      await s.install(await s.inspect(fixture));
      final stray = File(p.join(root.path, 'ki2d-my-clock', 'assets', 'gone.txt'))..writeAsStringSync('old');

      await s.install(await s.inspect(fixture));

      // A file the new version dropped must not linger and keep being served.
      expect(stray.existsSync(), isFalse);
    });

    test('uninstalling removes it', () async {
      final s = store();
      await s.install(await s.inspect(fixture));

      await s.uninstall('ki2d-my-clock');

      expect(await s.list(), isEmpty);
    });

    test('an installed key that a later release turned into a built-in is dropped', () async {
      final s = store();
      await s.install(await s.inspect(fixture));

      // The built-in set grows with releases, and the loader keys secrets,
      // fetch allowlists and hooks by the extension key — so a key that was
      // free at install time and is shipped later would otherwise be handed
      // whatever the built-in was granted.
      final later = InstalledExtensions(
        builtInKeys: const {'ki2d-my-clock'},
        hostSharedModules: const {'i18next': '23.11.5'},
        rootOverride: root,
      );
      expect(await later.list(), isEmpty);
    });

    test('a damaged install is skipped, not fatal to the others', () async {
      final s = store();
      await s.install(await s.inspect(fixture));
      Directory(p.join(root.path, 'broken')).createSync();
      File(p.join(root.path, 'broken', 'manifest.json')).writeAsStringSync('{ not json');

      // One unreadable directory must not cost the operator every other
      // extension they installed.
      expect((await s.list()).map((i) => i.key), ['ki2d-my-clock']);
    });

    test('a directory whose manifest claims a different key is ignored', () async {
      final s = store();
      await s.install(await s.inspect(fixture));
      Directory(p.join(root.path, 'renamed')).createSync();
      File(p.join(root.path, 'renamed', 'manifest.json'))
          .writeAsStringSync(jsonEncode({'key': 'ki2d-my-clock', 'name': 'X', 'category': 'dashboard'}));

      // The directory IS the identity — it is what uninstall and sourceFor
      // address. A manifest disagreeing with it would give two entries one
      // key, and the loader would pick whichever it saw last.
      expect((await s.list()).length, 1);
    });
  });

  group('isInstalled', () {
    test('says no before an install and yes after', () async {
      // The only thing that reads this is the consent screen's wording —
      // install or update. Every route asks either way.
      final s = store();
      expect(await s.isInstalled('ki2d-my-clock'), isFalse);
      await s.install(await s.inspect(fixture));
      expect(await s.isInstalled('ki2d-my-clock'), isTrue);
    });

    test('an unusable key is refused rather than joined into a path', () async {
      await expectLater(store().isInstalled('../escape'), throwsA(isA<ArgumentError>()));
    });
  });

  group('a manifest the consent screen could not survive is refused', () {
    // These fields are read while BUILDING that screen, from a file supplied
    // by whoever wrote it — unchecked, they throw out of a widget build
    // instead of being turned away. `domains` matters most: it is the fetch
    // allowlist itself, not a description of one.
    // `geo` reads as "does not gate" wherever it cannot be parsed, so each of
    // its shapes below would otherwise install as WORLDWIDE, not as a
    // mistake — and a value outside the vocabulary (the last three) would
    // install as relevant to NOBODY, ranked last for every operator forever.
    for (final bad in [
      {'domains': 'evil.example.org'},
      {'domains': [1, 2]},
      {'name': 7},
      {'version': 3},
      {'geo': 'CE'},
      {
        'geo': {'entities': 'CE'}
      },
      {
        'geo': {
          'entity': ['CE']
        }
      },
      {
        'geo': {
          'ituRegions': ['2']
        }
      },
      {
        'geo': {
          'continents': ['North America']
        }
      },
      {
        'geo': {
          'countries': ['USA']
        }
      },
      {
        'geo': {
          'ituRegions': [7]
        }
      },
    ]) {
      test('$bad', () async {
        await expectLater(
          store().inspect(rebuilt((m) => {...m, ...bad})),
          throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.malformed)),
        );
      });
    }
  });

  group('a bundle far larger than an extension is refused', () {
    test('too many entries', () async {
      final archive = ZipDecoder().decodeBytes(fixture);
      final out = Archive();
      for (final f in archive.files) {
        out.addFile(f);
      }
      for (var i = 0; i < kMaxEntries + 1; i++) {
        final bytes = utf8.encode('x');
        out.addFile(ArchiveFile('assets/f$i.txt', bytes.length, bytes));
      }
      // Decided before anything is written, and before the operator is asked
      // to approve something whose size nobody has looked at.
      await expectLater(
        store().inspect(ZipEncoder().encode(out)),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.tooLarge)),
      );
    });
  });

  test('a bundle gating on an app experiment is refused at install', () async {
    // The packer refuses it too, but its own header calls that a guardrail
    // rather than a gate. Installed, it would report success and then never
    // load — permanently invisible, with nothing in the UI to explain it.
    await expectLater(
      store().inspect(rebuilt((m) => {...m, 'experiments': ['nope']})),
      throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.malformed)),
    );
  });

  test('an installed bundle whose shared dependency the app outgrew is dropped', () async {
    final s = store();
    await s.install(await s.inspect(fixture));

    // Re-validated on every read, not just at install: an app update can raise
    // a library's major, and refusing at the door is the whole point of
    // declaring ranges — otherwise it loads and dies inside a hook.
    final later = InstalledExtensions(
      builtInKeys: const {},
      hostSharedModules: const {'i18next': '24.0.0'},
      rootOverride: root,
    );
    expect(await later.list(), isEmpty);
  });

  group('version ranges', () {
    test('npm-style carets mean what an extension author expects', () {
      expect(InstalledExtensions.satisfies('23.11.5', '^23.0.0'), isTrue);
      expect(InstalledExtensions.satisfies('23.11.5', '^24.0.0'), isFalse);
      expect(InstalledExtensions.satisfies('1.0.2', '>=1.0.0 <2.0.0'), isTrue);
    });

    test('a range nobody can parse is refused, not waved through', () {
      // "I could not tell" must never read as "go ahead".
      expect(InstalledExtensions.satisfies('1.0.0', 'whatever'), isFalse);
    });

    test('an unparseable range is reported as malformed, not as a version mismatch', () async {
      // Telling an author their version is wrong, when the fault is the range
      // they wrote, sends them to inspect the one thing that is fine.
      await expectLater(
        store().inspect(rebuilt((m) => {...m, 'sharedDependencies': {'i18next': 'not-a-range'}})),
        throwsA(isA<BundleException>().having((e) => e.reason, 'reason', BundleRejection.malformed)),
      );
    });
  });

  group('the loader offers installed extensions alongside the app\'s own', () {
    /// The shape `assets/extensions/index.json` has, so this exercises the
    /// real merge rather than a stand-in for it.
    Map<String, dynamic> assetIndex() => {
          'kernel': 'kernel.js',
          'sharedModules': {'i18next': '23.11.5'},
          'extensions': [
            {'key': 'pota', 'file': 'pota.js', 'core': false, 'name': 'Parks on the Air', 'category': 'activity'},
          ],
        };

    test('an installed extension joins the list, carrying its provenance', () async {
      final s = store();
      await s.install(await s.inspect(fixture));
      final service = ExtensionService()..debugInstalledStore = s;

      final available = await service.loadAvailableExtensions(index: assetIndex());

      expect(available.map((i) => i.key), ['pota', 'ki2d-my-clock']);
      // Provenance is what withholds build secrets — an installed entry that
      // arrived flagged as an asset would be handed SOTA_*-shaped credentials
      // by nothing more than calling itself the right thing.
      expect(available.firstWhere((i) => i.key == 'ki2d-my-clock').source, ExtensionSource.installed);
      expect(available.firstWhere((i) => i.key == 'pota').source, ExtensionSource.asset);
    });

    test('a store that cannot be read costs only the installed extensions', () async {
      final service = ExtensionService()
        ..debugInstalledStore = InstalledExtensions(
          builtInKeys: const {},
          hostSharedModules: const {},
          // A path that is a FILE, so listing it throws rather than returning
          // nothing — the difference between "none installed" and "the store
          // is broken", which must not take the app's own extensions down.
          rootOverride: Directory(p.join(root.path, 'not-a-directory')),
        );
      File(p.join(root.path, 'not-a-directory')).writeAsStringSync('');

      final available = await service.loadAvailableExtensions(index: assetIndex());

      expect(available.map((i) => i.key), ['pota']);
    });
  });
}
