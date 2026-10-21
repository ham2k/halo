// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app knows about an extension without running it: one build-index
// or installed-manifest entry, where its code came from, and the terms the
// Extensions panel searches it by. Pure data — the runtime that loads it is
// ExtensionService, which re-exports this file so callers import one thing.

import 'package:collection/collection.dart' show ListEquality, mergeSort;

import 'package:halo_core/halo_core.dart' show Hooks;
import 'extension_relevance.dart';

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
  List<String> keywordsFor(String locale) => [...keywords, ...((translations[locale]?['keywords'] as List?) ?? const []).whereType<String>()];

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
/// `ref:<type>` is the plain claim: this extension answers for every reference
/// of that type. `ref:<type>/<prefix>` is the qualified one: it answers for
/// the references of that type whose CODE begins with the prefix — `ref:qp/ny`
/// on the New York QSO Party, which answers `{type: 'qp', ref: 'NY'}` without
/// the operation being rewritten.
///
/// The qualified form exists because a type that used to hold fifty events in
/// one extension became fifty extensions, and the operations logged before
/// that still carry the old pair. They are not migrated: the extension reaches
/// back for them.
///
/// Null for anything that is not a `ref:` entry.
({String type, String? code})? refClaimOf(String hook) {
  final body = Hooks.refTypeOf(hook);
  if (body == null || body.isEmpty) return null;
  final slash = body.indexOf('/');
  if (slash < 0) return (type: body, code: null);
  final type = body.substring(0, slash);
  final code = body.substring(slash + 1);
  if (type.isEmpty || code.isEmpty) return null;
  return (type: type, code: code.toLowerCase());
}

/// The word the activity search scopes a reference type by: the type's base
/// name, lowercased — `potaActivation` and `pota` are both `pota`.
///
/// A ref TYPE, not the extension's key, on purpose: a user-published
/// extension is keyed by its author's callsign (`ki2d-pota`), and the
/// operator adding parks from it is still adding POTA parks. The word names
/// what is being searched for, and two extensions serving the same type
/// share it.
///
/// `<base>Activation` / `<base>` is the convention every activity's pair of
/// ref types follows (see `activityRefTypes`), which is what makes the base
/// name derivable at all.
String activityScopeWord(String refType) => refType.replaceFirst(_activationSuffix, '').toLowerCase();

final _activationSuffix = RegExp(r'Activation$');

/// The words the activity search box scopes the extension [key] by, lowercased:
/// the [activityScopeWord] of every plain `ref:<type>` its manifest [hooks]
/// declare, then [key] itself. Typing a type's word reaches every extension
/// declaring that type; typing the key reaches this one alone, which is how
/// an operator picks between two suppliers of the same references.
///
/// The type words come first, so `.first` is the word to put in the box for
/// this extension whenever it declares a type.
///
/// Qualified claims (`ref:qp/ny`) make no word: they reach back for
/// references an older extension wrote, and say nothing about what this one
/// searches.
List<String> activityScopeWordsOf({required String key, required List<String> hooks}) {
  final words = <String>[
    for (final hook in hooks)
      if (refClaimOf(hook) case (type: final type, code: null)) activityScopeWord(type),
  ];
  return {...words, key.toLowerCase()}.toList();
}

/// How strongly [hooks] claims the reference [type]/[code], or null for no
/// claim at all.
///
/// The strength is the length of the prefix that matched, which is what makes
/// "the longest claim wins" a comparison rather than a special case: a plain
/// `ref:qp` claims every `qp` reference at 0, `ref:qp/n` at 1, `ref:qp/ny` at
/// 2. So an extension that named the reference beats one that named the
/// family, and the bundled extension holding all fifty parties yields to the
/// one party's own — without either knowing the other exists.
///
/// Case-folded: a reference code is hand-typed, and `NY` and `ny` are the same
/// county list either way.
///
/// A prefix, not an equality, because the codes under one type are a family —
/// `ref:qp/ny` answers for `NY` and for anything an operator qualified further
/// under it, which is the behaviour a claim on a type nobody owns any more has
/// to have to be worth declaring.
int? refClaimStrength(List<String> hooks, {required String type, String? code}) {
  final folded = code?.toLowerCase();
  int? best;
  for (final hook in hooks) {
    final claim = refClaimOf(hook);
    if (claim == null || claim.type != type) continue;
    final prefix = claim.code;
    final int strength;
    if (prefix == null) {
      strength = 0;
    } else {
      if (folded == null || !folded.startsWith(prefix)) continue;
      strength = prefix.length;
    }
    if (best == null || strength > best) best = strength;
  }
  return best;
}

/// Whether [hooks] claims the reference [type]/[code] at all — [
/// refClaimStrength] without the ranking, for a caller with one candidate.
bool hooksClaimRef(List<String> hooks, {required String type, String? code}) => refClaimStrength(hooks, type: type, code: code) != null;

/// The extensions among [available] whose manifest claims any of [refs],
/// strongest claim first — the manifest's own statement of which references it
/// handles, which is what a ref no loaded control recognizes can be matched
/// against. Exact on the type, unlike the search's loose match: a ref type is
/// an identifier, and `sotaActivation` names SOTA, not everything mentioning
/// summits.
///
/// Both claim forms count (see [refClaimStrength]): the plain `ref:<type>`,
/// and the qualified `ref:qp/ny` by which a per-event QSO party answers for
/// the pair every operation logged before the split still carries. Where both
/// answer, the longer prefix leads — the party that named the reference is a
/// better offer than the family that merely contains it.
///
/// An extension is ranked by its BEST claim over all of [refs]: it is offered
/// once, for whichever reference it answers most precisely.
List<ExtensionInfo> extensionsDeclaringRefs(Iterable<ExtensionInfo> available, Iterable<({String type, String? code})> refs) {
  final ranked = <({ExtensionInfo info, int strength})>[];
  for (final info in available) {
    int? best;
    for (final ref in refs) {
      final strength = refClaimStrength(info.hooks, type: ref.type, code: ref.code);
      if (strength != null && (best == null || strength > best)) best = strength;
    }
    if (best != null) ranked.add((info: info, strength: best));
  }
  // Stable within a strength: `available` is the order the app resolved its
  // extensions in, and two equally precise claims have nothing else to be
  // ordered by — reordering them per build would move rows under the pointer.
  mergeSort(ranked, compare: (a, b) => b.strength.compareTo(a.strength));
  return [for (final entry in ranked) entry.info];
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

  /// The hosts `host.webSocket` may connect to (the manifest's `webSockets`),
  /// same entry shape as [domains] and a separate grant.
  final List<String> webSockets;

  /// The manifest's `version`, off the index or an installed bundle's
  /// manifest — so an extension that is installed but DISABLED, whose bundle
  /// never runs, still has a version an update check can compare. The
  /// kernel's listExtensions reports only the running ones. Null only for an
  /// index or a manifest that predates the field.
  final String? version;

  /// Where, when and for whom this extension is relevant (the manifest's
  /// `relevance`); null is worldwide and undated. Ranks catalog and panel
  /// entries for the operator's own callsign — see [ExtensionRelevance].
  final ExtensionRelevance? relevance;

  /// Whether this extension may set its own `User-Agent` on host.fetch
  /// (the manifest's `allowUserAgentOverride`). Off by default: the host stamps
  /// HaLo's canonical UA — see docs/design/network.md.
  final bool allowUserAgentOverride;

  /// Whether this extension may call the `getLocation` host call (the manifest's
  /// `requiresLocation`) — the device's raw GPS fix. Off by default,
  /// same allowlist shape as [domains].
  final bool requiresLocation;

  /// Whether this extension may read the operator's radios (`listRadios`,
  /// `readRadio`, a scene's `spectrum` control; the manifest's
  /// `requiresRadioRead`) and whether it may command them (`setRadio`,
  /// `setRadioConnection`, `setRadioSpectrum` and the keying calls;
  /// `requiresRadioWrite`), and whether it may send them any command at all
  /// (`sendRadioRaw`; `requiresRadioRaw`).
  /// A command answers with the radio's state, so write implies read, and raw
  /// implies both.
  final bool requiresRadioRead;
  final bool requiresRadioWrite;
  final bool requiresRadioRaw;

  /// What this extension may do with the app's DX cluster connection, each
  /// level including the ones before it: read what the node sends
  /// (`requiresClusterRead`), post spots (`requiresClusterSpot`), send any
  /// command (`requiresClusterCommand`). All three log the operator in.
  final bool requiresClusterRead;
  final bool requiresClusterSpot;
  final bool requiresClusterCommand;

  /// Whether [other] declares the same capabilities the host resolves into
  /// allowlists when the runtime STARTS. A dev reload that changes one cannot
  /// be hot-swapped: the running host would keep enforcing the old answer.
  bool sameStartTimeCapabilities(ExtensionInfo other) =>
      requiresLocation == other.requiresLocation &&
      requiresRadioRead == other.requiresRadioRead &&
      requiresRadioWrite == other.requiresRadioWrite &&
      requiresRadioRaw == other.requiresRadioRaw &&
      requiresClusterRead == other.requiresClusterRead &&
      requiresClusterSpot == other.requiresClusterSpot &&
      requiresClusterCommand == other.requiresClusterCommand &&
      allowUserAgentOverride == other.allowUserAgentOverride &&
      const ListEquality<String>().equals(webSockets, other.webSockets);

  final bool core;

  /// The extension API level the manifest declares (see
  /// `ExtensionBundle.api`), null when it declares none.
  final int? api;

  /// The level the runtime holds this extension to. A built-in is always at
  /// the app's own (null); any other that declares none is the oldest, 0 —
  /// as the install check reads it, so nothing installed as API 0 is then
  /// handed what only a newer one was promised, such as frozen QSOs.
  int? get runtimeApi => core ? null : (api ?? 0);

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
    this.relevance,
    this.domains = const [],
    this.webSockets = const [],
    this.allowUserAgentOverride = false,
    this.requiresLocation = false,
    this.requiresRadioRead = false,
    this.requiresRadioWrite = false,
    this.requiresRadioRaw = false,
    this.requiresClusterRead = false,
    this.requiresClusterSpot = false,
    this.requiresClusterCommand = false,
    required this.core,
    this.api,
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
    // A relevance the reader cannot parse is worldwide, never a crash:
    // it is a hint, and its shape is refused upstream (the build, the
    // packer, InstalledExtensions) rather than here.
    relevance: json['relevance'] is Map ? ExtensionRelevance.fromJson((json['relevance'] as Map).cast<String, dynamic>()) : null,
    domains: ((json['domains'] as List?) ?? const []).cast<String>(),
    webSockets: ((json['webSockets'] as List?) ?? const []).cast<String>(),
    allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
    requiresLocation: json['requiresLocation'] as bool? ?? false,
    requiresRadioRead: json['requiresRadioRead'] as bool? ?? false,
    requiresRadioWrite: json['requiresRadioWrite'] as bool? ?? false,
    requiresRadioRaw: json['requiresRadioRaw'] as bool? ?? false,
    requiresClusterRead: json['requiresClusterRead'] as bool? ?? false,
    requiresClusterSpot: json['requiresClusterSpot'] as bool? ?? false,
    requiresClusterCommand: json['requiresClusterCommand'] as bool? ?? false,
    // A stale index without metadata degrades to "everything core" —
    // the fail-safe: nothing gets silently disabled.
    core: json['core'] as bool? ?? true,
    api: (json['api'] as num?)?.toInt(),
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
    translations: {for (final entry in ((json['translations'] as Map?) ?? const {}).entries) entry.key as String: (entry.value as Map).cast<String, Object?>()},
  );
}

/// One manifest capability as the host enforces it: which of the LOADED
/// bundles declared it. Resolved when the runtime starts, from the same list
/// the runtime was started with — a grant and the bundle set it is read
/// against must never be from different moments.
///
/// A bundle may define sub-extensions under its own key (`pota-all-parks` from
/// `pota`), and those share its grant. But a bare prefix test hands the grant
/// to anything NAMED like one: a separately installed `rigpanel-themes`, whose
/// consent screen claimed nothing, would command the radio on `rigpanel`'s
/// say-so. So a key that is itself a loaded bundle answers only for itself,
/// and any other key belongs to the LONGEST loaded bundle key it extends.
class CapabilityGrant {
  final Set<String> bundles;
  final Set<String> granted;
  const CapabilityGrant({this.bundles = const {}, this.granted = const {}});

  CapabilityGrant.among(Iterable<ExtensionInfo> loaded, bool Function(ExtensionInfo) declares)
    : bundles = {for (final info in loaded) info.key},
      granted = {
        for (final info in loaded)
          if (declares(info)) info.key,
      };

  /// [extensionKey] is the caller's identity as the KERNEL stamped it.
  bool allows(String? extensionKey) {
    if (extensionKey == null) return false;
    if (bundles.contains(extensionKey)) return granted.contains(extensionKey);
    String? owner;
    for (final key in bundles) {
      if (!extensionKey.startsWith('$key-') && !extensionKey.startsWith('${key}_')) continue;
      if (owner == null || key.length > owner.length) owner = key;
    }
    return owner != null && granted.contains(owner);
  }
}
