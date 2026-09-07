// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where an extension is relevant: the manifest's `geo`
// (docs/extensions/distribution.md), matched against the operator's own
// callsign.

import 'dart:convert' show jsonEncode;

/// The `geo` an extension's manifest declares — four allowlists over the
/// operator's own callsign. An empty list does not gate; values within one
/// list are ORed, the lists themselves ANDed; an operator whose own value is
/// unknown fails any list that gates on it.
///
/// The TWIN of the geo filters in notices.dart (`_passes`): the same keys, the
/// same case folding — entities and continents compare uppercased, countries
/// lowercased, ituRegions as integers — and the same fail-closed rule. An
/// author who learned one must be able to write the other, so a change to
/// either belongs in both.
///
/// Relevance, not access: [matches] says whether the operator is in the
/// audience, and the caller decides whether that ranks or hides.
class ExtensionGeo {
  final List<String> entities;
  final List<String> countries;
  final List<String> continents;
  final List<int> ituRegions;

  const ExtensionGeo({
    this.entities = const [],
    this.countries = const [],
    this.continents = const [],
    this.ituRegions = const [],
  });

  /// The four keys a manifest's `geo` may hold, and the vocabulary two of
  /// them draw on: cty.dat's column-4 continent codes, and the three regions
  /// the ITU Radio Regulations define. The Dart authority — [validate] is the
  /// twin of `validateGeo` in extensions/tools/h2kext.mjs, and
  /// `extension_geo_test.dart` holds the two literal-for-literal.
  static const geoKeys = ['entities', 'countries', 'continents', 'ituRegions'];
  static const continentCodes = ['AF', 'AS', 'EU', 'NA', 'OC', 'SA', 'AN'];
  static const ituRegionCodes = [1, 2, 3];

  static final _entityPattern = RegExp(r'^\*?[A-Z0-9/]+$');
  static final _countryPattern = RegExp(r'^[a-z]{2}$');

  /// Everything wrong with a manifest's `geo`, as a list — empty for a valid
  /// one. The packer's rules, restated: the shape rules because the reader
  /// takes a key it cannot parse as "does not gate" (a misspelt key would
  /// make a Chilean extension relevant to the whole world), the vocabulary
  /// rules because a value that can never match anyone is an extension nobody
  /// is shown — and neither mistake says anything on its own.
  static List<String> validate(Object? geo) {
    if (geo is! Map) return ["'geo' must be an object of ${geoKeys.join(' / ')}"];
    final problems = <String>[];
    for (final key in geo.keys) {
      if (!geoKeys.contains(key)) problems.add("'geo' has an unknown key '$key' — only ${geoKeys.join(', ')} are read");
    }
    for (final key in geoKeys) {
      final values = geo[key];
      if (values == null) continue;
      if (values is! List) {
        problems.add("'geo.$key' must be a list");
        continue;
      }
      for (final value in values) {
        final problem = _valueProblem(key, value);
        if (problem != null) problems.add("'geo.$key' has ${jsonEncode(value)}, which $problem");
      }
    }
    return problems;
  }

  static String? _valueProblem(String key, Object? value) {
    if (key == 'ituRegions') {
      return value is num && ituRegionCodes.contains(value.toInt()) && value == value.toInt()
          ? null
          : 'is not an ITU region (${ituRegionCodes.join(', ')})';
    }
    if (value is! String || value.trim().isEmpty) return 'is not a non-empty string';
    if (key == 'entities') {
      return _entityPattern.hasMatch(value.toUpperCase())
          ? null
          : "is not a DXCC entity prefix (letters, digits and '/', with an optional leading '*')";
    }
    if (key == 'countries') {
      return _countryPattern.hasMatch(value.toLowerCase()) ? null : 'is not a two-letter ISO country code';
    }
    return continentCodes.contains(value.toUpperCase()) ? null : 'is not a continent (${continentCodes.join(' ')})';
  }

  /// Lenient, like the notices reader it mirrors: a key that is not a list
  /// reads as absent, and elements of the wrong type are dropped. Shape is
  /// enforced upstream — the packer and the build refuse a malformed `geo`,
  /// and InstalledExtensions refuses one at the door ([validate]) — so a
  /// stricter read here would only turn a stale index into a crash over a
  /// relevance hint.
  factory ExtensionGeo.fromJson(Map<String, dynamic> json) => ExtensionGeo(
        entities: _stringList(json['entities']),
        countries: _stringList(json['countries']),
        continents: _stringList(json['continents']),
        ituRegions: _intList(json['ituRegions']),
      );

  /// The manifest shape back, with only the lists that gate: a round trip of
  /// `{"countries": ["us"]}` yields exactly that, not three empty siblings.
  Map<String, dynamic> toJson() => {
        if (entities.isNotEmpty) 'entities': entities,
        if (countries.isNotEmpty) 'countries': countries,
        if (continents.isNotEmpty) 'continents': continents,
        if (ituRegions.isNotEmpty) 'ituRegions': ituRegions,
      };

  /// No list gates — the same as no `geo` at all.
  bool get isWorldwide => entities.isEmpty && countries.isEmpty && continents.isEmpty && ituRegions.isEmpty;

  /// Whether an operator described by these values is in the audience. Each
  /// is the derived form FlagsService computes for notices — entity prefix
  /// and continent uppercase (`K`, `NA`), country lowercase (`us`), the ITU
  /// region an int — and null when unknown, which fails any list that gates
  /// on it: an operator nothing is known about is not one the author
  /// addressed.
  bool matches({String? entityPrefix, String? countryCode, String? continent, int? ituRegion}) {
    if (entities.isNotEmpty && !entities.any((e) => e.toUpperCase() == entityPrefix)) return false;
    if (countries.isNotEmpty && !countries.any((c) => c.toLowerCase() == countryCode)) return false;
    if (continents.isNotEmpty && !continents.any((c) => c.toUpperCase() == continent)) return false;
    if (ituRegions.isNotEmpty && !ituRegions.any((r) => r == ituRegion)) return false;
    return true;
  }

  /// [matches] over a snapshot. A null snapshot is an operator nothing is
  /// known about, which a gated list fails and a worldwide one admits.
  bool matchesOperator(OperatorGeo? operator) => matches(
        entityPrefix: operator?.entityPrefix,
        countryCode: operator?.countryCode,
        continent: operator?.continent,
        ituRegion: operator?.ituRegion,
      );
}

/// The four derived values the app knows about the operator's own callsign —
/// what [ExtensionGeo.matches] takes, and what the catalog request carries
/// (`entity`, `country`, `continent`, `itu`; never the callsign). Each is in
/// the form FlagsService derives for notices, and null when unknown.
class OperatorGeo {
  final String? entityPrefix;
  final String? countryCode;
  final String? continent;
  final int? ituRegion;

  const OperatorGeo({this.entityPrefix, this.countryCode, this.continent, this.ituRegion});

  /// The catalog's operator-geo query parameters, only for the values known —
  /// an absent parameter is "unknown" to the catalog, an empty one is not.
  Map<String, String> toQueryParameters() => {
        if (entityPrefix != null && entityPrefix!.isNotEmpty) 'entity': entityPrefix!,
        if (countryCode != null && countryCode!.isNotEmpty) 'country': countryCode!,
        if (continent != null && continent!.isNotEmpty) 'continent': continent!,
        if (ituRegion != null) 'itu': '$ituRegion',
      };

  /// A value: the panel compares the snapshot it ranked by against the one
  /// FlagsService holds now, to know whether a refresh changed anything.
  @override
  bool operator ==(Object other) =>
      other is OperatorGeo &&
      other.entityPrefix == entityPrefix &&
      other.countryCode == countryCode &&
      other.continent == continent &&
      other.ituRegion == ituRegion;

  @override
  int get hashCode => Object.hash(entityPrefix, countryCode, continent, ituRegion);
}

List<String> _stringList(dynamic value) => value is List ? value.whereType<String>().toList() : const [];

/// `ituRegions` as JSON numbers, whatever an encoder made of them: `2` and
/// `2.0` both mean region 2 — the notices reader's `(r as num).toInt()`.
List<int> _intList(dynamic value) =>
    value is List ? value.whereType<num>().map((n) => n.toInt()).toList() : const [];
