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

/// One entry of `index.json`, limited to what the CLI acts on.
///
/// Not a copy of the app's `ExtensionInfo`: that class carries the panel's
/// localization and search behavior, which no command here has any use for.
class BundleEntry {
  final String key;
  final String file;
  final List<String> domains;
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

  const BundleEntry({
    required this.key,
    required this.file,
    required this.name,
    this.domains = const [],
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
        // A stale index without metadata degrades to "everything core", the
        // same fail-safe the app takes: nothing gets silently disabled.
        core: json['core'] as bool? ?? true,
        enabledByDefault: json['enabledByDefault'] as bool? ?? true,
        requiresLocation: json['requiresLocation'] as bool? ?? false,
        allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
        name: json['name'] as String? ?? json['key'] as String,
        category: json['category'] as String?,
        hooks: ((json['hooks'] as List?) ?? const []).cast<String>(),
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'name': name,
        if (category != null) 'category': category,
        'core': core,
        'enabledByDefault': enabledByDefault,
        if (domains.isNotEmpty) 'domains': domains,
        if (hooks.isNotEmpty) 'declaredHooks': hooks,
      };
}

/// The built bundle directory: `index.json` plus the sources beside it.
class BundleIndex {
  final Directory directory;
  final String kernelFile;
  final List<BundleEntry> extensions;

  BundleIndex({required this.directory, required this.kernelFile, required this.extensions});

  String get kernelSource => _read(kernelFile);

  String sourceFor(BundleEntry entry) => _read(entry.file);

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
      throw BundlesNotBuilt('index.json is malformed (no `extensions` list): ${indexFile.path}\n'
          '${_buildHint(directory)}');
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

  static String _buildHint(Directory? directory) =>
      'Run `npm run build` in extensions/, or scripts/test.sh, which builds them first.\n';
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
