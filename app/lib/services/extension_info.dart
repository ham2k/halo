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

/// The reference a manifest `hooks` entry claims, in either of the two forms
/// the list allows.
///
/// `ref:<type>` is the plain claim: this extension publishes a control for
/// every reference of that type. `ref:<type>/<code>` is the qualified one:
/// this extension answers for ONE legacy reference under a type it does not
/// publish — `ref:qp/ny` on the New York QSO Party, whose own control is
/// `nyqp`. The second exists because a type that used to hold fifty events in
/// one extension becomes fifty types, and every operation logged before the
/// split still carries the old pair.
///
/// Null for anything that is not a `ref:` entry.
({String type, String? code})? refClaimOf(String hook) {
  if (!hook.startsWith('ref:')) return null;
  final body = hook.substring(4);
  if (body.isEmpty) return null;
  final slash = body.indexOf('/');
  if (slash < 0) return (type: body, code: null);
  final type = body.substring(0, slash);
  final code = body.substring(slash + 1);
  if (type.isEmpty || code.isEmpty) return null;
  return (type: type, code: code.toLowerCase());
}

/// Whether [hooks] claims the reference [type]/[code].
///
/// A plain claim answers for every reference of its type; a qualified one
/// only for the code it names, case-folded because a reference code is
/// hand-typed and `NY` and `ny` are the same county list either way.
///
/// Both count wherever an extension is offered for a reference nothing
/// handles: a plain claim clears that row with a control, and a qualified one
/// clears it by rewriting the reference ([refsMigratedBy]) as the extension
/// comes on. An offer that could do neither is the one this must not make.
bool hooksClaimRef(List<String> hooks, {required String type, String? code}) {
  for (final hook in hooks) {
    final claim = refClaimOf(hook);
    if (claim == null || claim.type != type) continue;
    if (claim.code == null) return true;
    if (code != null && claim.code == code.toLowerCase()) return true;
  }
  return false;
}

/// What a legacy reference this extension claims is rewritten INTO — the one
/// type it publishes a control for.
///
/// Exactly one, or null: the build refuses a manifest that qualifies a claim
/// without a single plain `ref:` entry to name the target (extensions/
/// hook-check.mjs), so null here means an extension built before that rule or
/// one the app is reading from a catalog that never applied it. A rewrite
/// with nowhere to go is not performed.
String? refMigrationTargetOf(List<String> hooks) {
  String? target;
  for (final hook in hooks) {
    final claim = refClaimOf(hook);
    if (claim == null || claim.code != null) continue;
    if (target != null) return null;
    target = claim.type;
  }
  return target;
}

/// The extensions among [available] whose manifest claims any of [refs] —
/// the manifest's own statement of which references it handles, which is what
/// a ref no loaded control recognizes can be matched against. Exact, unlike
/// the search's loose match: a ref type is an identifier, and `sotaActivation`
/// names SOTA, not everything mentioning summits.
///
/// Both claim forms count (see [hooksClaimRef]): the plain `ref:<type>`, and
/// the qualified `ref:qp/ny` by which a per-event QSO party answers for the
/// pair every operation logged before the split still carries.
List<ExtensionInfo> extensionsDeclaringRefs(
  Iterable<ExtensionInfo> available,
  Iterable<({String type, String? code})> refs,
) =>
    [
      for (final info in available)
        if (refs.any((ref) => hooksClaimRef(info.hooks, type: ref.type, code: ref.code))) info,
    ];

/// [refs] with every legacy reference an extension declaring [hooks] claims
/// rewritten into the type that extension publishes, or null when it claims
/// none of them.
///
/// This is what makes a qualified claim worth declaring. Installing the New
/// York QSO Party for an operation carrying `{type: 'qp', ref: 'NY'}` would
/// otherwise leave that row exactly as red as it was, since the extension
/// publishes a control for `nyqp` and nothing answers `qp` any more.
///
/// The code goes and the type takes its meaning — `{type: 'nyqp'}` — while
/// everything else on the reference is kept: a contest reference carries the
/// operator's own setup (exchange, entry class, power), and a migration that
/// dropped it would cost them what the row was for.
List<Map<String, dynamic>>? refsMigratedBy(List<Map<String, dynamic>> refs, List<String> hooks) {
  final target = refMigrationTargetOf(hooks);
  if (target == null) return null;
  // A reference of the target type is the SAME activity the legacy one names,
  // already in the operation and already configured under the extension that
  // is arriving. Rewriting into it would leave the operation carrying two,
  // and every form path here reads the first (`_addFormActivity`), so the
  // second would be uneditable while still scoring and exporting. So the
  // legacy row is dropped instead of duplicated.
  var haveTarget = refs.any((ref) => ref['type'] == target);
  var changed = false;
  final migrated = <Map<String, dynamic>>[];
  for (final ref in refs) {
    final type = ref['type'];
    // Its own type is not a legacy one, whatever a plain claim says about it.
    final code = ref['ref'] is String ? ref['ref'] as String : null;
    if (type is String && type != target && hooksClaimRef(hooks, type: type, code: code)) {
      changed = true;
      if (haveTarget) continue;
      migrated.add({...ref, 'type': target}..remove('ref'));
      haveTarget = true;
    } else {
      migrated.add(ref);
    }
  }
  return changed ? migrated : null;
}

/// [refsMigratedBy] for the extension [key] names among [available], or null
/// when nothing there claims one of [refs] — which is also the answer for a
/// key no longer present, since a runtime restart is what makes a
/// freshly-installed one appear.
List<Map<String, dynamic>>? refsMigratedByExtension(
  Iterable<ExtensionInfo> available,
  String key,
  List<Map<String, dynamic>> refs,
) {
  final info = available.where((i) => i.key == key).firstOrNull;
  return info == null ? null : refsMigratedBy(refs, info.hooks);
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
