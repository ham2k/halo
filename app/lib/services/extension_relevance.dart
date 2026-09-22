// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where, when and for whom an extension is relevant: the manifest's
// `relevance` (docs/extensions/distribution.md), matched against the
// operator's own callsign.

import 'dart:convert' show jsonEncode;

/// The `relevance` an extension's manifest declares.
///
/// The four GEOGRAPHIC lists are allowlists over the operator's own callsign.
/// An empty list does not gate; values within one list are ORed, the lists
/// themselves ANDed; an operator whose own value is unknown fails any list
/// that gates on it.
///
/// That half is the TWIN of the geo filters in notices.dart (`_passes`): the
/// same keys, the same case folding — entities and continents compare
/// uppercased, countries lowercased, ituRegions as integers — and the same
/// fail-closed rule. An author who learned one must be able to write the
/// other, so a change to either belongs in both.
///
/// [dates] and [interests] take no part in [matches]. They say when an
/// extension's events run and what an operator has to be into for it to
/// matter, which orders a list rather than deciding membership of one — and
/// folding them into the geographic match would turn a hint into a gate.
///
/// Relevance, not access: [matches] says whether the operator is in the
/// audience, and the caller decides whether that ranks or hides.
class ExtensionRelevance {
  final List<String> entities;
  final List<String> countries;
  final List<String> continents;
  final List<int> ituRegions;

  /// The UTC days this extension's events start, as `YYYY-MM-DD` — start
  /// days, not spans, because a reader asking "is this soon" needs no more.
  /// Empty for an event that runs to a weekly rule, which says nothing about
  /// timing rather than "never".
  ///
  /// Kept as written rather than parsed: the strings round-trip back into the
  /// manifest byte for byte, and nothing here has to pick a time zone for a
  /// value that has no time in it.
  final List<String> dates;

  /// What an operator has to be into, from [interestCodes] — the interests of
  /// an extension DEDICATED to one, never of one that merely permits it.
  final List<String> interests;

  const ExtensionRelevance({
    this.entities = const [],
    this.countries = const [],
    this.continents = const [],
    this.ituRegions = const [],
    this.dates = const [],
    this.interests = const [],
  });

  /// The six keys a manifest's `relevance` may hold, and the vocabularies
  /// three of them draw on: cty.dat's column-4 continent codes, the three
  /// regions the ITU Radio Regulations define, and the closed interest list.
  /// The Dart authority — [validate] is the twin of `validateRelevance` in
  /// extensions/tools/h2kext.mjs, and `extension_relevance_test.dart` holds
  /// the two literal-for-literal.
  static const relevanceKeys = ['entities', 'countries', 'continents', 'ituRegions', 'dates', 'interests'];
  static const continentCodes = ['AF', 'AS', 'EU', 'NA', 'OC', 'SA', 'AN'];
  static const ituRegionCodes = [1, 2, 3];
  static const interestCodes = [
    'cw', 'phone', 'digital', //
    'hf', 'vhf', 'uhf', 'microwave',
    'satellite', 'portable', 'qrp',
  ];

  static final _entityPattern = RegExp(r'^\*?[A-Z0-9/]+$');
  static final _countryPattern = RegExp(r'^[a-z]{2}$');
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Everything wrong with a manifest's `relevance`, as a list — empty for a
  /// valid one. The packer's rules, restated: the shape rules because the
  /// reader takes a key it cannot parse as "does not gate" (a misspelt key
  /// would make a Chilean extension relevant to the whole world), the
  /// vocabulary rules because a value that can never match anyone is an
  /// extension nobody is shown — and neither mistake says anything on its own.
  static List<String> validate(Object? relevance) {
    if (relevance is! Map) return ["'relevance' must be an object of ${relevanceKeys.join(' / ')}"];
    final problems = <String>[];
    for (final key in relevance.keys) {
      if (!relevanceKeys.contains(key)) {
        problems.add("'relevance' has an unknown key '$key' — only ${relevanceKeys.join(', ')} are read");
      }
    }
    for (final key in relevanceKeys) {
      // `containsKey`, not a null test: JSON `null` is a value the author
      // wrote, and reading it as an absent key admits `{"entities": null}`
      // here while the packer refuses it — the one input on which these twins
      // would otherwise disagree, and it installs as worldwide.
      if (!relevance.containsKey(key)) continue;
      final values = relevance[key];
      if (values is! List) {
        problems.add("'relevance.$key' must be a list");
        continue;
      }
      for (final value in values) {
        final problem = _valueProblem(key, value);
        if (problem != null) problems.add("'relevance.$key' has ${jsonEncode(value)}, which $problem");
      }
    }
    return problems;
  }

  static String? _valueProblem(String key, Object? value) {
    if (key == 'ituRegions') {
      return value is num && ituRegionCodes.contains(value.toInt()) && value == value.toInt() ? null : 'is not an ITU region (${ituRegionCodes.join(', ')})';
    }
    if (value is! String || value.trim().isEmpty) return 'is not a non-empty string';
    if (key == 'entities') {
      return _entityPattern.hasMatch(value.toUpperCase()) ? null : "is not a DXCC entity prefix (letters, digits and '/', with an optional leading '*')";
    }
    if (key == 'countries') {
      return _countryPattern.hasMatch(value.toLowerCase()) ? null : 'is not a two-letter ISO country code';
    }
    if (key == 'dates') return _dateProblem(value);
    if (key == 'interests') {
      return interestCodes.contains(value) ? null : 'is not an interest (${interestCodes.join(' ')})';
    }
    return continentCodes.contains(value.toUpperCase()) ? null : 'is not a continent (${continentCodes.join(' ')})';
  }

  /// Why [value] is not a UTC calendar day, or null.
  ///
  /// The round trip is the whole check: `DateTime.utc` rolls 31 February over
  /// into 3 March rather than refusing it, so a pattern match alone accepts a
  /// day that does not exist and then silently means a different one.
  ///
  /// The four-digit year is required rather than merely matched, because the
  /// packer builds its date with `Date.UTC`, which reads a year under 100 as
  /// 19xx and would refuse `0050-01-01` while this accepts it. Neither
  /// answer is worth having, and a rule both can state is.
  static String? _dateProblem(String value) {
    if (!_datePattern.hasMatch(value)) return 'is not a YYYY-MM-DD date';
    final parts = value.split('-').map(int.parse).toList();
    if (parts[0] < 1000) return 'is not a year an event could fall in';
    final at = DateTime.utc(parts[0], parts[1], parts[2]);
    return at.year == parts[0] && at.month == parts[1] && at.day == parts[2] ? null : 'is not a day that exists';
  }

  /// Lenient, like the notices reader it mirrors: a key that is not a list
  /// reads as absent, and elements of the wrong type are dropped, so a
  /// stale index cannot become a crash over a relevance hint.
  ///
  /// Three of the four things that reach here are checked before they do:
  /// the build refuses a malformed `relevance` in a built-in manifest, the
  /// packer refuses one in a bundle, and InstalledExtensions refuses one at
  /// the door ([validate]). The fourth is not. A catalog LISTING row is a
  /// different document from the bundle manifest it describes, and the only
  /// thing that validated it is the catalog's own code, in another
  /// repository — so for that path this leniency rests on a cross-repo
  /// contract rather than on anything this tree enforces.
  factory ExtensionRelevance.fromJson(Map<String, dynamic> json) => ExtensionRelevance(
    entities: _stringList(json['entities']),
    countries: _stringList(json['countries']),
    continents: _stringList(json['continents']),
    ituRegions: _intList(json['ituRegions']),
    dates: _stringList(json['dates']),
    interests: _stringList(json['interests']),
  );

  /// The manifest shape back, with only the lists that carry something: a
  /// round trip of `{"countries": ["us"]}` yields exactly that, not five
  /// empty siblings.
  Map<String, dynamic> toJson() => {
    if (entities.isNotEmpty) 'entities': entities,
    if (countries.isNotEmpty) 'countries': countries,
    if (continents.isNotEmpty) 'continents': continents,
    if (ituRegions.isNotEmpty) 'ituRegions': ituRegions,
    if (dates.isNotEmpty) 'dates': dates,
    if (interests.isNotEmpty) 'interests': interests,
  };

  /// Whether any of [dates] starts within [window] of [now].
  ///
  /// The window reaches [kRelevanceJustPast] BACK as well as forward, because
  /// a date is the day an event STARTS and most of them run longer than that:
  /// an event that began at the weekend is the one an operator is most likely
  /// to be looking for, and a forward-only window drops it exactly then.
  ///
  /// A date that cannot be read is not soon. The shape is refused upstream,
  /// so anything unreadable here came from a stale index rather than an
  /// author, and guessing at it would rank an extension by a typo.
  bool startsWithin(Duration window, DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    for (final date in dates) {
      final parts = date.split('-').map(int.tryParse).toList();
      if (parts.length != 3 || parts.any((p) => p == null)) continue;
      final at = DateTime.utc(parts[0]!, parts[1]!, parts[2]!);
      final days = at.difference(today).inDays;
      if (days >= -kRelevanceJustPast.inDays && days <= window.inDays) return true;
    }
    return false;
  }

  /// No geographic list gates — the same audience as no `relevance` at all.
  /// [dates] and [interests] do not bear on it: an extension can be worldwide
  /// and still run on two days a year.
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
  bool matchesOperator(OperatorGeo? operator) =>
      matches(entityPrefix: operator?.entityPrefix, countryCode: operator?.countryCode, continent: operator?.continent, ituRegion: operator?.ituRegion);
}

/// How near an extension is to mattering, lowest first — the one order the
/// Extensions panel ranks by, for what is installed and what the catalog
/// offers alike.
///
/// Three bands, and the order between them is the claim:
///
/// 0. **Soon.** One of its `dates` is inside [kRelevanceSoon] of now. A
///    contest this weekend beats one on the other side of the world's
///    doorstep, whoever the operator is.
/// 1. **Here.** Its geography matches the operator's own callsign.
/// 2. **Neither**, which includes everything worldwide and undated — most of
///    the catalog, and correctly last.
///
/// Dates outrank geography because a date expires and a place does not: a
/// QSO party three days out is worth surfacing to somebody who has not
/// decided yet, while the state it runs in is true all year and says nothing
/// about now.
int relevanceBand(ExtensionRelevance? relevance, {required OperatorGeo? operator, required DateTime now}) {
  if (relevance == null) return 2;
  if (relevance.startsWithin(kRelevanceSoon, now)) return 0;
  // Worldwide is not "here": it gates on nothing, so it says nothing about
  // this operator, and ranking it with a genuine match would bury the
  // matches under everything.
  if (!relevance.isWorldwide && relevance.matchesOperator(operator)) return 1;
  return 2;
}

/// How far ahead an extension's next event counts as soon.
///
/// Two weeks: long enough that an operator planning a weekend still has time
/// to install something and read its rules, short enough that the band stays
/// a handful of rows rather than a second catalog.
const kRelevanceSoon = Duration(days: 14);

/// How far back an event that has already started still counts as soon.
///
/// Three days, which is the weekend an event began on: the operator logging
/// on Monday what they worked on Saturday is looking for the same extension
/// as the one who installed it on Friday, and a date is the day an event
/// STARTS rather than the day it ends.
const kRelevanceJustPast = Duration(days: 3);

/// The extensions offered to every operator, whatever their callsign says.
///
/// Curation rather than a property of the bundles, and deliberately not
/// something a manifest can claim: these are the worldwide programmes anyone
/// anywhere can take part in, and a `relevance` key saying so would be
/// written by every author who wanted the room.
///
/// [relevanceBand] does not read it — it ranks by what the author declared,
/// and these carry no claim to rank above a genuine match. It decides
/// membership of the suggestions, not their order.
const kAlwaysSuggested = {'ham2k-pota', 'ham2k-sota', 'ham2k-wwff', 'ham2k-llota', 'ham2k-wwbota'};

/// The four derived values the app knows about the operator's own callsign —
/// what [ExtensionRelevance.matches] takes, and what the catalog request
/// carries (`entity`, `country`, `continent`, `itu`; never the callsign).
/// Each is in the form FlagsService derives for notices, and null when
/// unknown.
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
List<int> _intList(dynamic value) => value is List ? value.whereType<num>().map((n) => n.toInt()).toList() : const [];
