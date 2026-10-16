// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared access to the extension bundles the tests boot — the core ones built
// into app/assets/extensions, the catalog bundles the app pre-loads, and the
// never-shipped fixtures — and the single place that decides what a missing or
// stale bundle means.
//
// It means a FAILURE, not a skip. `scripts/test.sh` builds the bundles before
// it runs these tests precisely so they can rely on them, so a guard that
// skips instead can only ever fire once that ordering has already broken —
// exactly when a green run is most misleading. Every file here used to open
// each test with its own `markTestSkipped('bundles not built')`, and with the
// bundles moved aside the package reported `+6 ~227: All tests passed!` and
// exited 0, having run 6 of its 233 tests. That is the same failure class as
// the deleted-file copy step in #411 and the `LD_LIBRARY_PATH` glob that
// matched nothing and passed anyway.
//
// The check lives in [bundleSource] rather than in a list each file declares.
// A declared list is a second copy of what the file's own `sharedHost` calls
// already say, and it drifted immediately: the commit that introduced it
// shipped `requireBundles([])` in a file reading seven bundles, and two more
// files naming a third of what they load. Checking the key at the moment it
// is read cannot drift, because the key checked IS the key being read.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

final _assets = Directory('../../app/assets/extensions');
final _preloaded = Directory('../../app/assets/preloaded-extensions');
final _fixtures = Directory('../../extensions/build/fixtures');
final _extensionSources = Directory('../../extensions');

File bundleFile(String key) => File('${_assets.path}/$key.js');

/// The `index.js` of the catalog bundle the app pre-loads as [key], or null
/// when it pre-loads none. The exact bytes the app installs, so a test through
/// one exercises what ships rather than a build of the same source.
String? _preloadedSource(String key) {
  final index = File('${_preloaded.path}/index.json');
  if (!index.existsSync()) return null;
  final entries = (jsonDecode(index.readAsStringSync()) as Map)['preloaded'] as List;
  final entry = entries.cast<Map>().where((e) => e['key'] == key).firstOrNull;
  if (entry == null) return null;
  final archive = ZipDecoder().decodeBytes(File('${_preloaded.path}/${entry['file']}').readAsBytesSync());
  final bundle = archive.findFile('index.js');
  return bundle == null ? null : utf8.decode(bundle.content as List<int>);
}

final Map<String, String> _sourceCache = {};

/// The built bundle for [key], or a loud failure naming it and how to build it.
///
/// Memoized: a suite that boots several hosts would otherwise re-read and
/// re-decode kernel.js (1.8MB) once per boot — ~105 times per package run.
String bundleSource(String key) {
  return _sourceCache.putIfAbsent(key, () {
    final file = [bundleFile(key), File('${_fixtures.path}/$key.js')].where((f) => f.existsSync()).firstOrNull;
    if (file == null) {
      final preloaded = _preloadedSource(key);
      if (preloaded != null) return preloaded;
      fail(
        'extension bundle not built: $key.js, and the app pre-loads no $key\n'
        'Run `npm run build` in extensions/, or use scripts/test.sh, which builds them first.',
      );
    }
    final source = file.readAsStringSync();
    if (source.isEmpty) {
      // An interrupted build leaves a zero-length file behind. Left alone it
      // surfaces later as a hook that simply never registers, which reads as
      // an extension bug rather than a build one.
      fail(
        'extension bundle is empty: $key.js (interrupted build?)\n'
        'Run `npm run build` in extensions/, or use scripts/test.sh, which builds them first.',
      );
    }
    return source;
  });
}

/// Registers this suite's shared-host lifecycle. Call once at the top of
/// `main()` — `setUpAll`/`tearDownAll` have to be registered before tests run.
///
/// Checks the kernel and bundle freshness up front; individual bundles answer
/// for themselves in [bundleSource] as they are read.
void requireBundles() {
  setUpAll(_checkBundlesAreFresh);

  setUp(() async {
    // The kernel caches getSettings/getAccount behind a 3000ms WALL-CLOCK TTL
    // (extensions/sdk/src/kernel.ts). On a shared host that makes what a test
    // sees depend on how fast the previous test ran — an order- AND
    // timing-dependent flake. Dropping the context between tests is the
    // enforcement the doc on [sharedHost] used to only ask for politely.
    for (final pending in _sharedHosts.values.toList()) {
      (await pending).invalidateHookContext();
    }
  });

  tearDownAll(() async {
    // Every host gets a dispose attempt even if one throws: the loop used to
    // abort on the first failure and leak the rest, and an undisposed host
    // leaks QuickJS's malloc'd heap (10-12MB for the kernel alone) because
    // Isolate.kill does not reclaim it.
    final pending = _sharedHosts.values.toList();
    _sharedHosts.clear();
    _sourceCache.clear();
    for (final host in pending) {
      try {
        await (await host).dispose();
      } catch (_) {
        // Best effort — a dispose failure, or a host that never started, must
        // not mask the test results.
      }
    }
  });
}

/// Fails when the bundles are older than the TypeScript they are built from.
///
/// Existence alone is the wrong instrument: the bundles are gitignored and
/// regenerate only on an explicit `npm run build`, so the everyday developer
/// state is present-but-stale, not absent — and per-package `flutter test` is
/// the endorsed inner loop (AGENTS.md). Without this, editing an extension and
/// re-running these tests silently checks the PREVIOUS build.
void _checkBundlesAreFresh() {
  final kernel = bundleFile('kernel');
  if (!kernel.existsSync()) {
    fail(
      'extension bundles not built: kernel.js\n'
      'Run `npm run build` in extensions/, or use scripts/test.sh, which builds them first.',
    );
  }
  if (!_extensionSources.existsSync()) return;

  final newestSource = newestExtensionSource(_extensionSources);
  if (newestSource == null) return;

  final builtAt = kernel.statSync().modified;
  if (newestSource.isAfter(builtAt)) {
    fail(
      'extension bundles are STALE — sources changed after the last build.\n'
      'Run `npm run build` in extensions/, or use scripts/test.sh, which builds them first.',
    );
  }
}

/// When the newest TypeScript or JSON the bundles are built FROM last changed,
/// or null when [root] holds none.
///
/// Build OUTPUT under [root] is not source, and has to be skipped by name: the
/// SDK package build writes `.d.ts`, `.json` and copied sample `.ts` files into
/// `sdk/dist` and `sdk/samples`, and a sample's own build writes a
/// `build/manifest.json`. Counted, any of those built after the bundles makes
/// every test here fail as STALE while no source has changed — and
/// `sdk/samples` loses nothing by being skipped, because it is a copy of
/// `samples/`, which is walked.
DateTime? newestExtensionSource(Directory root) {
  final prefix = root.path.length + 1;
  DateTime? newest;
  final pending = [root];
  final visited = <String>{};
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    // Follow source links without revisiting a directory through a cycle.
    if (!visited.add(directory.resolveSymbolicLinksSync())) continue;
    for (final entry in directory.listSync()) {
      final path = entry.path;
      final parts = path.substring(prefix).split(Platform.pathSeparator);
      // Prune outputs and dependencies before enumerating their contents.
      if (parts.contains('node_modules') || parts.contains('build')) continue;
      if (parts.first == 'sdk' && parts.length > 1 && const {'dist', 'samples', 'docs'}.contains(parts[1])) continue;
      if (entry is Directory) {
        pending.add(entry);
      } else if (entry is File && (path.endsWith('.ts') || path.endsWith('.json'))) {
        final at = entry.statSync().modified;
        if (newest == null || at.isAfter(newest)) newest = at;
      }
    }
  }
  return newest;
}

/// Answers every host call with a successful `null` — except `getSettings`,
/// which the SDK types as never null (the app always answers a map), so an
/// extension reading a setting on its spot or lookup path would throw here
/// and nowhere real.
///
/// Not the same as leaving `onHostCall` unset: an UNSET handler makes the
/// kernel answer `'no host call handler configured'`, i.e. the JS promise
/// REJECTS, so a hook takes its error path instead of its no-data path. Tests
/// that mean "nothing is wired up, carry on" want this.
///
/// A top-level function rather than a closure per call site, because
/// [sharedHost] keys on handler identity — an inline `(m, p) async => null`
/// would be a fresh object every call and boot a host every time.
Future<dynamic> nullHostCall(String method, Map<String, dynamic> params) async => method == 'getSettings' ? const <String, dynamic>{} : null;

final Map<String, Future<ExtensionHost>> _sharedHosts = {};

/// A host carrying [keys], booted once and reused by every later caller in the
/// same suite.
///
/// `ExtensionHost.start` costs ~343ms against the ~1.3ms an actual hook
/// invocation takes — a 264:1 ratio that made this package's runtime almost
/// entirely engine startup once every test booted its own.
///
/// WHAT SHARING DOES AND DOES NOT RESET. [requireBundles] drops the kernel's
/// cached settings/account context before each test, so that much is handled.
/// What it CANNOT reach is module-level state inside the extension bundles
/// themselves, which are evaluated once per host: pota's `parkCache` memoizes
/// even a null result, and sota, call-notes and ham2k-lofi do the same, while
/// satellites caches its whole transponder table after the first load. A test
/// that needs any of those cold — or that needs its own `onHostCall` answers,
/// or counts calls, or reads `host.logs` — must call `ExtensionHost.start`
/// directly with its own `addTearDown`.
///
/// [onHostCall] is part of the cache identity by default, so two call sites
/// passing different handlers over the same bundles get different hosts rather
/// than the first one silently answering for both. Note that identity means
/// the closure OBJECT: a handler written inline at the call site is a new
/// closure every call and so never shares. Hoist it to a single `final` if you
/// want one host, which is what `reference_activity_test.dart` does.
///
/// [cacheKey] replaces the handler identity when you can name the config
/// yourself — a per-fixture handler built fresh each call, as in
/// `satellites_test.dart`, shares correctly under a key naming the fixture.
/// It also lets one config be deliberately split across several hosts: a test
/// whose failure mode is a hung runtime wants its own, so the next test does
/// not inherit it.
Future<ExtensionHost> sharedHost(List<String> keys, {HostCallHandler? onHostCall, String? cacheKey}) {
  final id = [keys.join(','), if (cacheKey != null) cacheKey else if (onHostCall != null) 'h${identityHashCode(onHostCall)}'].join('|');

  // The Future is cached, not the resolved host: caching after the await is
  // check-then-act, and two concurrent callers would each boot one, with the
  // loser overwritten in the map and never disposed.
  return _sharedHosts.putIfAbsent(
    id,
    () => ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [for (final key in keys) ExtensionBundle(key: key, source: bundleSource(key))],
      onHostCall: onHostCall,
    ),
  );
}
