// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Booting the real extension runtime outside Flutter.
//
// This is the same ExtensionHost the app starts, given the same bundles, the
// same per-extension fetch allowlists and the same secret scoping — see
// ExtensionService._start, which this deliberately mirrors. What differs is
// only what a CLI can't have: no asset bundle (bundles.dart reads the files),
// no platform channels, and no UI for a hook to ask anything of.

import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart' show extensionMaySeeSecret, parseVersionDart;
import 'package:halo_extension_host/halo_extension_host.dart';

import 'bundles.dart';
import 'config.dart';

/// A booted runtime plus the metadata about what went into it.
class ExtRuntime {
  final ExtensionHost host;
  final BundleIndex index;

  /// The extensions actually loaded, in load order. A disabled or excluded
  /// extension is simply never evaluated — its hooks do not exist, exactly as
  /// in the app.
  final List<BundleEntry> loaded;

  ExtRuntime({required this.host, required this.index, required this.loaded});

  /// Boots the runtime.
  ///
  /// [only] loads exactly those keys (plus nothing else, not even core —
  /// debugging one extension's hook in isolation is the whole point);
  /// otherwise every core extension loads, plus the non-core ones that are
  /// enabled by default, minus [exclude]. [all] additionally loads the
  /// extensions that are off by default.
  static Future<ExtRuntime> start({
    required BundleIndex index,
    required CliConfig config,
    HostCallHandler? onHostCall,
    Set<String> only = const {},
    Set<String> exclude = const {},
    bool all = false,
  }) async {
    final selected = <BundleEntry>[
      for (final entry in index.extensions)
        if (only.isNotEmpty ? only.contains(entry.key) : _enabled(entry, config, all) && !exclude.contains(entry.key)) entry,
    ];

    if (only.isNotEmpty) {
      final missing = only.difference({for (final entry in selected) entry.key});
      if (missing.isNotEmpty) {
        // The catalog extensions the app pre-loads come from beside the built
        // bundles; pointed elsewhere with --bundles, they are simply not there.
        final noPreloads = index.preloadedDirectory == null && missing.any((key) => key.startsWith('ham2k-'));
        throw CliUsageError(
          'no such extension: ${missing.join(', ')} (try `halo-ext list`)'
          '${noPreloads ? ' — no pre-loaded extensions were found beside ${index.directory.path}, where the app keeps them in ../preloaded-extensions' : ''}',
        );
      }
    }

    final secrets = {
      for (final entry in selected)
        // Dev-served and pre-loaded extensions get nothing, whatever key they
        // claim — the same provenance rule the app applies. `--dev-server` can
        // name any machine, and a configured credential must not follow; a
        // pre-load is an installed extension, which sees none in the app.
        if (!entry.fromDevServer && !entry.preloaded)
          if (_secretsFor(entry.key, config) case final visible when visible.isNotEmpty) entry.key: visible,
    };

    final host = await ExtensionHost.start(
      kernelSource: index.kernelSource,
      extensions: [for (final entry in selected) ExtensionBundle(key: entry.key, source: index.sourceFor(entry), api: entry.runtimeApi)],
      onHostCall: onHostCall,
      fetchAllowlists: {for (final entry in selected) entry.key: entry.domains},
      webSocketAllowlists: {for (final entry in selected) entry.key: entry.webSockets},
      secrets: secrets,
      userAgent: cliUserAgent(index),
      userAgentOverrides: {
        for (final entry in selected)
          if (entry.allowUserAgentOverride) entry.key,
      },
      // One-shot commands: the isolate's own startup is pure overhead when
      // nothing competes with the extension work for a UI thread, and it puts
      // the engine somewhere a `--verbose` stack trace can't follow.
      useIsolate: false,
    );

    // Not just "start() returned": kernel.ts fires onActivation
    // fire-and-forget, so a hook an extension registers after its own first
    // await (call-notes waits on host.getSettings) would not exist yet. A
    // single command that raced that would report the hook as missing.
    await host.activated.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        stderr.writeln('halo-ext: warning — extension activation did not settle within 10s, continuing');
      },
    );

    return ExtRuntime(host: host, index: index, loaded: selected);
  }

  static bool _enabled(BundleEntry entry, CliConfig config, bool all) {
    final override = config.extensionOverrides[entry.key];
    if (override != null) return override;
    return entry.core || all || entry.enabledByDefault;
  }

  /// What [key] is allowed to see of the configured build-time secrets —
  /// resolved here, once, so the host holds only that subset and needs no
  /// policy of its own. Same rule the app applies (extensionMaySeeSecret).
  static Map<String, String> _secretsFor(String key, CliConfig config) => {
    for (final entry in config.secrets.entries)
      if (entry.value.isNotEmpty && extensionMaySeeSecret(key, entry.key)) entry.key: entry.value,
  };

  Future<void> stop() => host.dispose();
}

/// The `User-Agent` every `host.fetch` from this process carries.
///
/// Deliberately NOT the app's string: POTA, SOTA and friends see this traffic
/// too, and a debugging CLI hammering an API must be distinguishable from the
/// app doing it — see docs/design/network.md. The version comes from the
/// app's own version.dart when we can see it (an in-repo run), since that is
/// the code these bundles were built beside.
String cliUserAgent(BundleIndex index) => 'Ham2K halo-ext/${cliVersion(index)} (${Platform.operatingSystem} cli)';

/// The version halo-ext reports, from the app's own version.dart when this is
/// an in-repo run — that is the code these bundles were built beside — and
/// `dev` when it can't be read.
String cliVersion(BundleIndex index) => _appVersion(index) ?? 'dev';

String? _appVersion(BundleIndex index) {
  // <repo>/app/assets/extensions → <repo>/app/lib/config/version.dart
  final file = File('${index.directory.parent.parent.path}/lib/config/version.dart');
  if (!file.existsSync()) return null;
  try {
    return parseVersionDart(file.readAsStringSync()).version.value;
  } catch (_) {
    // A drifted version.dart is a release-tooling problem, not this tool's:
    // an unstamped UA beats refusing to run.
    return null;
  }
}

/// A problem with what the operator typed, as opposed to a failure inside a
/// hook. `main` prints these without a stack trace and exits 2.
class CliUsageError implements Exception {
  final String message;
  CliUsageError(this.message);

  @override
  String toString() => message;
}
