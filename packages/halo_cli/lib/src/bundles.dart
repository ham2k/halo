// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Finding and reading the built extension bundles.
//
// The app reads these through `rootBundle` because they are Flutter assets.
// A CLI has no asset bundle, so it reads the same directory off disk — the
// SAME files the app ships, deliberately, so what halo-ext exercises is what
// the app runs.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// One entry of `index.json`, limited to what the CLI acts on.
///
/// Not a copy of the app's `ExtensionInfo`: that class carries the panel's
/// localization and search behavior, which no command here has any use for.
class BundleEntry {
  final String key;
  final String file;
  final List<String> domains;
  final List<String> webSockets;
  final bool core;
  final bool enabledByDefault;
  final bool requiresLocation;
  final bool allowUserAgentOverride;
  final String name;
  final String? category;

  /// The hook categories the manifest DECLARES. Informational — the runtime
  /// learns the real ones from `registerHook`, which is what `list --hooks`
  /// reports.
  final List<String> hooks;

  /// Served by a dev server rather than read from the built bundle directory
  /// (docs/extensions/development.md). Carries the same consequence it does in
  /// the app: no configured secret is visible to it, whatever key it claims
  /// (HALO-425). The CLI has no installed-bundle store, so this stays a bool
  /// where the app needs a three-way source.
  final bool fromDevServer;

  const BundleEntry({
    required this.key,
    required this.file,
    required this.name,
    this.fromDevServer = false,
    this.domains = const [],
    this.webSockets = const [],
    this.core = true,
    this.enabledByDefault = true,
    this.requiresLocation = false,
    this.allowUserAgentOverride = false,
    this.category,
    this.hooks = const [],
  });

  factory BundleEntry.fromJson(Map<String, dynamic> json) => BundleEntry(
    key: json['key'] as String,
    file: json['file'] as String? ?? '${json['key']}.js',
    domains: ((json['domains'] as List?) ?? const []).cast<String>(),
    webSockets: ((json['webSockets'] as List?) ?? const []).cast<String>(),
    // A stale index without metadata degrades to "everything core", the
    // same fail-safe the app takes: nothing gets silently disabled.
    core: json['core'] as bool? ?? true,
    enabledByDefault: json['enabledByDefault'] as bool? ?? true,
    requiresLocation: json['requiresLocation'] as bool? ?? false,
    allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
    name: json['name'] as String? ?? json['key'] as String,
    category: json['category'] as String?,
    hooks: ((json['hooks'] as List?) ?? const []).cast<String>(),
    fromDevServer: json['fromDevServer'] as bool? ?? false,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    if (category != null) 'category': category,
    'core': core,
    'enabledByDefault': enabledByDefault,
    if (domains.isNotEmpty) 'domains': domains,
    if (webSockets.isNotEmpty) 'webSockets': webSockets,
    if (hooks.isNotEmpty) 'declaredHooks': hooks,
  };
}

/// The built bundle directory: `index.json` plus the sources beside it.
class BundleIndex {
  final Directory directory;
  final String kernelFile;
  List<BundleEntry> extensions;

  BundleIndex({required this.directory, required this.kernelFile, required this.extensions});

  /// Sources fetched from a dev server, by extension key. Consulted before the
  /// directory, so an overlaid extension never touches the built file — which
  /// may not even exist for one the dev server invented.
  final Map<String, String> _devSources = {};

  String get kernelSource => _read(kernelFile);

  String sourceFor(BundleEntry entry) => _devSources[entry.key] ?? _read(entry.file);

  String _read(String file) {
    final source = File('${directory.path}/$file').readAsStringSync();
    if (source.isEmpty) {
      // An interrupted build leaves a zero-length file behind, which would
      // otherwise surface much later as a hook that simply never registered.
      throw BundlesNotBuilt('extension bundle is empty: $file (interrupted build?)\n${_buildHint(directory)}');
    }
    return source;
  }

  /// Reads the index at [dir], or finds one by [locate] when null.
  factory BundleIndex.load({Directory? dir}) {
    final directory = dir ?? locate();
    final indexFile = File('${directory.path}/index.json');
    if (!indexFile.existsSync()) {
      throw BundlesNotBuilt('no index.json in ${directory.path}\n${_buildHint(directory)}');
    }
    // Shape-checked rather than cast: a truncated or hand-edited index throws
    // a TypeError from the cast, with a Dart stack trace in place of the
    // "your bundles are not built" sentence this class exists to give.
    final Object? decoded = jsonDecode(indexFile.readAsStringSync());
    final entries = decoded is Map ? decoded['extensions'] : null;
    if (decoded is! Map || entries is! List) {
      throw BundlesNotBuilt(
        'index.json is malformed (no `extensions` list): ${indexFile.path}\n'
        '${_buildHint(directory)}',
      );
    }
    return BundleIndex(
      directory: directory,
      kernelFile: decoded['kernel'] as String? ?? 'kernel.js',
      extensions: [
        for (final entry in entries)
          if (entry is Map) BundleEntry.fromJson(entry.cast<String, dynamic>()),
      ],
    );
  }

  /// Replaces this index's entries with what a running dev server is serving
  /// (docs/extensions/development.md), so `halo-ext` exercises the code an
  /// author is editing rather than the last thing they built.
  ///
  /// An OVERLAY, not a replacement: the dev server serves no kernel, and only
  /// the extensions it was asked to watch — so the built bundles are still
  /// needed for the kernel and for everything else. Matching keys are replaced
  /// and new ones appended, exactly as the app merges them.
  Future<void> overlayDevServer(Uri base, {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    try {
      Future<String> get(String path) async {
        final response = await client.get(base.resolve(path)).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw DevServerUnreachable('HTTP ${response.statusCode} from ${base.resolve(path)}');
        }
        return response.body;
      }

      final Map<String, dynamic> ping;
      try {
        ping = jsonDecode(await get('ping')) as Map<String, dynamic>;
      } catch (e) {
        throw DevServerUnreachable(
          'could not reach an extension dev server at $base — $e\n'
          'Start one with `npm run dev` in extensions/.',
        );
      }
      if (ping['server'] != 'halo-ext-dev') {
        throw DevServerUnreachable('$base is not a HaLo extension dev server');
      }
      if ((ping['protocol'] as num?)?.toInt() != devServerProtocol) {
        throw DevServerUnreachable('dev server speaks protocol ${ping['protocol']}, this build speaks $devServerProtocol');
      }

      final index = jsonDecode(await get('index.json')) as Map<String, dynamic>;
      final served = <BundleEntry>[
        for (final entry in ((index['extensions'] as List?) ?? const []).cast<Map<String, dynamic>>()) BundleEntry.fromJson({...entry, 'fromDevServer': true}),
      ];
      for (final entry in served) {
        _devSources[entry.key] = await get(entry.file);
      }

      final byKey = {for (final entry in served) entry.key: entry};
      final unplaced = {...byKey.keys}..removeAll(extensions.map((e) => e.key));
      extensions = [for (final entry in extensions) byKey[entry.key] ?? entry, for (final key in unplaced) byKey[key]!];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Where the bundles are, in order of authority: an explicit
  /// `HALO_EXT_BUNDLES`, then a walk up from the working directory, then a
  /// walk up from the executable's own location.
  ///
  /// Two walks rather than one because the two ways this runs land in
  /// different places: `dart run` from anywhere in the repo (cwd is the
  /// answer) and a compiled `halo-ext` next to a copied bundle directory
  /// (the executable is). Neither subsumes the other.
  static Directory locate() {
    final fromEnv = Platform.environment['HALO_EXT_BUNDLES'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final dir = Directory(fromEnv);
      if (!dir.existsSync()) {
        throw BundlesNotBuilt('HALO_EXT_BUNDLES points at a directory that does not exist: $fromEnv');
      }
      return dir;
    }
    for (final start in [Directory.current, File.fromUri(Platform.script).parent]) {
      final found = _walkUpFrom(start);
      if (found != null) return found;
    }
    throw BundlesNotBuilt(
      'could not find the built extension bundles.\n'
      'Looked for app/assets/extensions/index.json above ${Directory.current.path}\n'
      'and above ${File.fromUri(Platform.script).parent.path}.\n'
      '${_buildHint(null)}'
      'Or point HALO_EXT_BUNDLES at the directory holding index.json.',
    );
  }

  static Directory? _walkUpFrom(Directory start) {
    var dir = start.absolute;
    for (var i = 0; i < 8; i++) {
      for (final candidate in ['${dir.path}/app/assets/extensions', '${dir.path}/assets/extensions']) {
        if (File('$candidate/index.json').existsSync()) return Directory(candidate);
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static String _buildHint(Directory? directory) => 'Run `npm run build` in extensions/, or scripts/test.sh, which builds them first.\n';
}

/// The dev-server protocol this build speaks (extensions/dev-server.mjs).
const devServerProtocol = 1;

/// Accepts what someone actually types for `--dev-server`: a bare host, a
/// host:port, with or without a scheme or a trailing slash. The trailing slash
/// matters — `Uri.resolve` against a path-less base drops the last segment.
Uri normalizeDevServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) throw DevServerUnreachable('--dev-server needs an address');
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.parse(text);
  if (uri.host.isEmpty) throw DevServerUnreachable('could not read a host from "$input"');
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

/// Thrown when `--dev-server` names something that isn't one, or isn't up.
///
/// Its own type for the same reason as [BundlesNotBuilt]: the everyday cause
/// is a dev server that was never started, and that deserves a sentence rather
/// than a stack trace.
class DevServerUnreachable implements Exception {
  final String message;
  DevServerUnreachable(this.message);

  @override
  String toString() => message;
}

/// Thrown when the bundles are missing, empty, or not where we were told.
///
/// A distinct type so `main` can print it as an operator problem — the
/// everyday cause is a checkout that has never run `npm run build` — instead
/// of a stack trace that reads like a crash.
class BundlesNotBuilt implements Exception {
  final String message;
  BundlesNotBuilt(this.message);

  @override
  String toString() => message;
}
