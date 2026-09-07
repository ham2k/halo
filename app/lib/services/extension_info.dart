// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app knows about an extension without running it: one build-index
// or installed-manifest entry, where its code came from, and the terms the
// Extensions panel searches it by. Pure data — the runtime that loads it is
// ExtensionService, which re-exports this file so callers import one thing.

import 'extension_geo.dart';

/// Where an extension's code came from. Not cosmetic: [maySeeBuildSecrets]
/// hangs off it, and so does whether the loader reads the source from the
/// app's assets, the installed store, or a dev server.
enum ExtensionSource {
  /// Shipped inside the app.
  asset,

  /// Installed by the operator from a `.h2kext` (HALO-422).
  installed,

  /// Served by a dev server (HALO-118, docs/extensions/development.md).
  dev;

  /// Only what the app shipped. An extension that arrived any other way gets
  /// nothing, whatever key it claims — see [visibleSecretsFor].
  bool get maySeeBuildSecrets => this == ExtensionSource.asset;

  /// Reads the provenance an index entry carries. Absent means [asset]: the
  /// app's own `index.json` says nothing, because everything in it shipped
  /// with the app.
  static ExtensionSource fromJson(Map<String, dynamic> json) {
    return switch (json['source'] as String?) {
      'installed' => ExtensionSource.installed,
      'dev' => ExtensionSource.dev,
      _ => ExtensionSource.asset,
    };
  }
}

/// What the Extensions panel's search field matches an extension on —
/// the same terms for a built-in, an installed one and a catalog row, so
/// the one field filters all three alike.
mixin ExtensionSearchable {
  String get key;
  String get name;
  String? get description;
  List<String> get keywords;
  Map<String, Map<String, Object?>> get translations;

  String nameFor(String locale) => (translations[locale]?['name'] as String?) ?? name;
  String? descriptionFor(String locale) => (translations[locale]?['description'] as String?) ?? description;

  /// The base [keywords] plus the locale's extra ones — localized keywords
  /// add to the English set (both stay searchable), they don't replace it.
  /// A non-string among them is dropped, not thrown on: the catalog's rows
  /// are whatever a publisher wrote, and one typo is not the panel's to
  /// crash over. The build index's are validated by the packer anyway.
  List<String> keywordsFor(String locale) => [
        ...keywords,
        ...((translations[locale]?['keywords'] as List?) ?? const []).whereType<String>(),
      ];

  /// Whether a user's search text should surface this extension. Matches the
  /// key, the name and description in BOTH the given locale and English (so
  /// either spelling finds it), and the keywords. [query] is expected
  /// already trimmed; an empty one matches nothing, since "show everything"
  /// is the caller's decision, not a match.
  bool matchesSearch(String query, {required String locale}) {
    if (query.isEmpty) return false;
    final needle = query.toLowerCase();
    return key.toLowerCase().contains(needle) ||
        name.toLowerCase().contains(needle) ||
        nameFor(locale).toLowerCase().contains(needle) ||
        (description ?? '').toLowerCase().contains(needle) ||
        (descriptionFor(locale) ?? '').toLowerCase().contains(needle) ||
        keywordsFor(locale).any((keyword) => keyword.toLowerCase().contains(needle));
  }
}

/// One entry of the build index (assets/extensions/index.json) — the static,
/// user-facing metadata the extensions build emits so the app can describe every
/// extension (including disabled ones whose bundles never load). Core
/// entries are always enabled and never listed in the Extensions panel.
class ExtensionInfo with ExtensionSearchable {
  @override
  final String key;
  final String file;
  final List<String> domains;

  /// The manifest's `version`, off the index or an installed bundle's
  /// manifest — so an extension that is installed but DISABLED, whose bundle
  /// never runs, still has a version an update check can compare. The
  /// kernel's listExtensions reports only the running ones. Null only for an
  /// index or a manifest that predates the field.
  final String? version;

  /// Where this extension is relevant (the manifest's `geo`); null is
  /// worldwide. Ranks catalog and panel entries for the operator's own
  /// callsign — see [ExtensionGeo].
  final ExtensionGeo? geo;

  /// Whether this extension may set its own `User-Agent` on host.fetch
  /// (the manifest's `allowUserAgentOverride`). Off by default: the host stamps
  /// HaLo's canonical UA — see docs/design/network.md.
  final bool allowUserAgentOverride;

  /// Whether this extension may call the `getLocation` host call (the manifest's
  /// `requiresLocation`) — the device's raw GPS fix. Off by default,
  /// same allowlist shape as [domains].
  final bool requiresLocation;

  final bool core;
  @override
  final String name;
  final String? shortName;
  final String? category;
  final bool enabledByDefault;

  /// Experiment keys (experiments.yaml) gating this extension's very
  /// availability — see [ExtensionService.isExtensionAvailable].
  final List<String> experiments;

  /// MDI icon name (resolveIconName), mirroring the icon the extension's
  /// own hooks use (e.g. POTA's 'pine-tree'); null falls back to a
  /// category icon in the panel.
  final String? icon;
  @override
  final String? description;

  /// The extension's brand accent as a #RRGGBB hex string (manifest.json
  /// `accentColor`, e.g. POTA's green) — informational, for hosts that
  /// want to tint extension UI.
  final String? accentColor;

  /// Extra Extensions-panel search terms beyond name/description.
  @override
  final List<String> keywords;

  /// The hook categories the extension's manifest declares. The runtime
  /// learns actual hooks from registerHook, and reads nothing else here — but
  /// the `ref:<type>` entries are load-bearing for the host: they are how an
  /// operation ref no loaded extension handles finds the switched-off
  /// extension to offer (docs/extensions/README.md).
  final List<String> hooks;

  /// Per-locale overrides for [name]/[description] plus extra localized
  /// search [keywords] (manifest.json `translations`, baked into index.json
  /// so they're readable without running any JS, same as the base
  /// metadata). Keyed by language code; a missing locale or field falls
  /// back to the English base value.
  @override
  final Map<String, Map<String, Object?>> translations;

  /// Where this extension's code came from.
  ///
  /// It decides two things: where the source is read from, and — the part that
  /// matters — whether any build secret is visible to it. Only extensions that
  /// ship inside the app get those, whatever key a bundle claims (HALO-425).
  final ExtensionSource source;

  /// Installed from a `.h2kext` the operator chose (HALO-422). Like a
  /// dev-served one, it is code the app did not ship.
  bool get isInstalled => source == ExtensionSource.installed;

  const ExtensionInfo({
    required this.key,
    required this.file,
    this.source = ExtensionSource.asset,
    this.version,
    this.geo,
    this.domains = const [],
    this.allowUserAgentOverride = false,
    this.requiresLocation = false,
    required this.core,
    required this.name,
    this.shortName,
    this.category,
    this.enabledByDefault = true,
    this.experiments = const [],
    this.icon,
    this.description,
    this.accentColor,
    this.keywords = const [],
    this.hooks = const [],
    this.translations = const {},
  });

  String get effectiveShortName => shortName ?? name;

  factory ExtensionInfo.fromJson(Map<String, dynamic> json) => ExtensionInfo(
        key: json['key'] as String,
        file: json['file'] as String? ?? '${json['key']}.js',
        source: ExtensionSource.fromJson(json),
        version: json['version'] as String?,
        // A geo the reader cannot parse is worldwide, never a crash: it is a
        // relevance hint, and its shape is refused upstream (the build, the
        // packer, InstalledExtensions) rather than here.
        geo: json['geo'] is Map ? ExtensionGeo.fromJson((json['geo'] as Map).cast<String, dynamic>()) : null,
        domains: ((json['domains'] as List?) ?? const []).cast<String>(),
        allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
        requiresLocation: json['requiresLocation'] as bool? ?? false,
        // A stale index without metadata degrades to "everything core" —
        // the fail-safe: nothing gets silently disabled.
        core: json['core'] as bool? ?? true,
        name: json['name'] as String? ?? json['key'] as String,
        shortName: json['shortName'] as String?,
        category: json['category'] as String?,
        enabledByDefault: json['enabledByDefault'] as bool? ?? true,
        experiments: ((json['experiments'] as List?) ?? const []).cast<String>(),
        icon: json['icon'] as String?,
        description: json['description'] as String?,
        accentColor: json['accentColor'] as String?,
        keywords: ((json['keywords'] as List?) ?? const []).cast<String>(),
        hooks: ((json['hooks'] as List?) ?? const []).cast<String>(),
        translations: {
          for (final entry in ((json['translations'] as Map?) ?? const {}).entries)
            entry.key as String: (entry.value as Map).cast<String, Object?>(),
        },
      );
}
