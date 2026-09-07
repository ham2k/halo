// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the SET/SHOW/HIDE commands search: every setting the settings screen
// would currently show the user, flattened into one ranked-searchable list.
//
// Derived from the declarative registry (settings_scan.dart), never a
// whitelist — app-polo's SettingsCommands.js hand-lists seven settings and
// silently omits everything added since, which is the failure mode this
// exists to avoid. A setting declared anywhere (core group or extension
// settingsPanel) is reachable by name the day it lands.
//
// Reachability deliberately mirrors the settings screen exactly, because a
// command that changes something the user cannot find, or that reports a
// setting the app is currently hiding, is worse than no command. All three
// of the form layer's visibility mechanisms are honoured:
//
//  - `environment` — applied by [scanSettings] itself.
//  - `devMode` — excluded unless developer mode is on (FormRenderer._elements).
//  - `visibleWhen` — evaluated against the element's own group/panel values
//    (FormRenderer._isVisible, via [elementIsVisibleWhen]).
//
// Not cached. Every search re-scans, which costs a couple of bridge calls per
// debounced keystroke, because the whole point of `SET ZEROBEAT` with no
// value is reporting the CURRENT value — a cache would have to be invalidated
// by every settings write in the app (including the ones these very commands
// make) to stay correct, and a stale answer here is a wrong answer.

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import 'settings_fuzzy.dart';
import 'settings_scan.dart';

/// Which command is searching. SHOW/HIDE reach a deliberately narrower set
/// than SET — see [_matchTermsFor].
enum SettingCommandKind { set, show, hide }

/// The `fieldType`s that can be set from a single typed word. Everything else
/// (multiselect, list, account, secret) opens the settings dialog instead:
/// they either need a multi-value editor, or — for `secret` — must never have
/// their value echoed into a command bar and its describe line.
const _simpleFieldTypes = {'checkbox', 'select', 'text', 'number'};

/// One setting the commands can find.
///
/// Constructible without a scan so the ranking and coercion below can be
/// tested as pure functions against hand-built entries.
class SettingsCatalogEntry {
  /// The key a command action carries back — namespaced `<panelKey>.<key>`
  /// for extension-sourced settings (see settings_scan.dart).
  final String key;

  /// The key as declared, without any panel namespace. What a user is
  /// actually likely to type.
  final String bareKey;

  final String label;
  final String? description;

  /// Short names for this setting, from the element's optional `aliases`
  /// attribute (docs/extensions/settings.md). Matched at the same top tier as
  /// the key, so `SET REPORT` can name one setting exactly where the bare key
  /// `defaultReport` is only a substring hit shared with three siblings.
  final List<String> aliases;

  /// The section the setting lives under, so a match can say where it is.
  final String section;

  final String fieldType;
  final dynamic value;

  /// `select`/`multiselect` options as declared: `{label, value}` maps.
  final List<Map<String, dynamic>> options;

  const SettingsCatalogEntry({
    required this.key,
    required this.bareKey,
    required this.label,
    required this.section,
    required this.fieldType,
    required this.value,
    this.description,
    this.aliases = const [],
    this.options = const [],
  });

  /// Whether a value typed on the command line can set this. False sends the
  /// command to the settings dialog instead.
  bool get isSimple => _simpleFieldTypes.contains(fieldType);

  /// Whether SHOW/HIDE should consider this setting at all: a checkbox whose
  /// KEY or an alias says it controls visibility.
  ///
  /// Deliberately not the label. A label is localized, so falling back to it
  /// would make an extension field keyed `compactHeader` but labelled "Hide
  /// the header" reachable by `HIDE` in English and unreachable in Spanish —
  /// and, worse, flip [isInverted] with the UI language. An extension whose
  /// key doesn't read as show/hide should declare an `aliases` entry that
  /// does; that is a decision its author makes once, not one the running
  /// locale makes for them.
  bool get isVisibilityToggle => fieldType == 'checkbox' && _visibilityName != null;

  /// True when this setting reads "hidden = on" rather than "shown = on", so
  /// SHOW/HIDE know which way to write. Only meaningful for
  /// [isVisibilityToggle].
  bool get isInverted => _visibilityName == 'hide';

  /// `'show'`, `'hide'`, or null — from the key first, then any alias.
  String? get _visibilityName {
    final fromKey = _visibilityPrefix(bareKey);
    if (fromKey != null) return fromKey;
    for (final alias in aliases) {
      final fromAlias = _visibilityPrefix(alias);
      if (fromAlias != null) return fromAlias;
    }
    return null;
  }
}

/// `'show'`, `'hide'`, or null when [text] starts with neither. Case- and
/// separator-insensitive, so it catches `showGridField`, `show_grid` and
/// `"Show Grid"` alike.
String? _visibilityPrefix(String text) {
  final normalized = normalizeSettingTerm(text);
  if (normalized.startsWith('show')) return 'show';
  if (normalized.startsWith('hide')) return 'hide';
  return null;
}

/// Casefolded, stripped of everything that isn't a letter or digit — so
/// `zeroBeat`, `Zero Beat`, `zero-beat` and a typed `ZEROBEAT` all reduce to
/// the same term and match each other.
///
/// Delegates rather than repeating [normalizeFuzzyQuery]'s body: the two are
/// used interchangeably along the same call paths (this one for the exact
/// name comparisons and option coercion, that one for the scorer), and the
/// whole feature's matching contract rests on them agreeing exactly.
String normalizeSettingTerm(String text) => normalizeFuzzyQuery(text);

/// Every setting reachable right now, in settings-screen order.
///
/// [developerMode] gates `devMode: true` elements exactly as FormRenderer
/// does — passed in rather than read here so a test can build both views of
/// the catalog without mutating app state.
Future<List<SettingsCatalogEntry>> buildSettingsCatalog(
  HaLoServices services, {
  required bool developerMode,
}) async {
  final entries = <SettingsCatalogEntry>[];
  for (final scanned in await scanSettings(services)) {
    final el = scanned.element;
    if (!scanned.isField) continue;
    if (el['devMode'] == true && !developerMode) continue;
    if (!elementIsVisibleWhen(el, scanned.siblingValues)) continue;
    final label = el['label'];
    final fieldType = el['fieldType'];
    if (label is! String || fieldType is! String || scanned.key.isEmpty) continue;
    final rawAliases = el['aliases'];
    entries.add(SettingsCatalogEntry(
      key: scanned.key,
      bareKey: scanned.fieldRoute?.fieldKey ?? scanned.key,
      label: label,
      description: el['description'] is String ? el['description'] as String : null,
      aliases: switch (rawAliases) {
        String s => [s],
        List l => l.whereType<String>().toList(),
        _ => const <String>[],
      },
      section: scanned.sectionTitle,
      fieldType: fieldType,
      value: declaredSettingValue(el),
      options: (el['options'] as List?)?.whereType<Map>().map((o) => o.cast<String, dynamic>()).toList() ?? const [],
    ));
  }
  return entries;
}

/// The names a settings element answers to: its key, its label, and any
/// declared `aliases`, exactly as written.
///
/// NOT normalized — the punctuation and camelCase humps are what
/// [fuzzyMatchScore] reads word boundaries from, and stripping them here would
/// throw away most of what makes the ranking useful.
///
/// Shared so the Settings search box and [rankSettings] look at the same
/// things. They do different jobs with them — the box filters and shows every
/// match, the commands rank and act on the best — but a setting one can find
/// must be findable by the other, or `SET RST` resolving to a setting that
/// searching "rst" doesn't even list reads as one of them being broken.
List<String> _searchableNames(Map<String, dynamic> el) => [
  if (el['key'] is String) el['key'] as String,
  if (el['label'] is String) el['label'] as String,
  ...switch (el['aliases']) {
    String alias => [alias],
    List aliases => aliases.whereType<String>(),
    _ => const <String>[],
  },
].where((t) => t.isNotEmpty).toList();

/// The best [fuzzyMatchScore] across [names], or null if [query] is a
/// subsequence of none of them.
int? _bestNameScore(String query, List<String> names) {
  int? best;
  for (final name in names) {
    final score = fuzzyMatchScore(query, name);
    if (score != null && (best == null || score > best)) best = score;
  }
  return best;
}

/// The floor a NAME match is clamped to before [elementSearchScore] returns
/// it, so that one int can be sorted directly.
///
/// A name score has no natural floor — every skipped character costs, so a
/// two-letter query straggling across a long label goes arbitrarily negative
/// — and would otherwise sink beneath [_descriptionPenalty], putting a setting
/// that merely MENTIONS the query above one actually named for it. Clamping
/// only reorders matches already so weak they're indistinguishable.
const _minNameScore = -1000;

/// What [elementSearchScore] answers for a match found only in a description:
/// below every clamped name score, by one.
const _descriptionPenalty = _minNameScore - 1;

/// The Settings search: how well [query] matches this element, or null
/// when it doesn't match at all. Is [query] a subsequence of one of the
/// element's [_searchableNames], or a plain substring of its description?
///
/// Chrome elements (headers, dividers, markdown) never match — while
/// filtering, only the settings themselves show.
///
/// Directly comparable across elements, unlike the raw score [rankSettings]
/// works with: name matches are clamped at [_minNameScore] so a description
/// match can never outrank one. A caller that needs the two kinds told APART
/// (rather than merely ordered) should use [rankSettings]' `viaDescription`.
int? elementSearchScore(Map<String, dynamic> el, String query) {
  if (query.isEmpty) return 0;
  final type = el['type'];
  if (type != 'field' && type != 'link' && type != 'action') return null;
  // A query that is ALL punctuation is not "no filter" — that is the empty
  // query above. Treating it as one would let `-` or `/` match every setting
  // at an equal score, emptying the search box of meaning.
  final term = normalizeFuzzyQuery(query);
  if (term.isEmpty) return null;

  final byName = _bestNameScore(term, _searchableNames(el));
  if (byName != null) return byName < _minNameScore ? _minNameScore : byName;

  // The description is matched as typed and as a plain SUBSTRING, never as a
  // subsequence: a subsequence of a whole sentence matches almost anything,
  // which is why VS Code fuzzy-matches file names and not file contents.
  final description = el['description'];
  if (description is String && description.toLowerCase().contains(query.toLowerCase())) {
    return _descriptionPenalty;
  }
  return null;
}

/// Strips a leading `show`/`hide` from [name], keeping the rest as written.
/// `showGridField` → `GridField`, `"Show Grid Field"` → `"Grid Field"`. Case
/// and punctuation survive, because the fuzzy scorer reads word boundaries
/// off them.
String _withoutVisibilityPrefix(String name) {
  final match = RegExp(r'^(show|hide)[\s_-]*', caseSensitive: false).firstMatch(name);
  return match == null ? name : name.substring(match.end);
}

/// The names [entry] can be found by. For SHOW/HIDE the leading show/hide is
/// stripped, so `SHOW GRID` reaches `showGridField` by the part that actually
/// names the thing rather than by the verb the operator already typed.
List<String> _matchTermsFor(SettingsCatalogEntry entry, SettingCommandKind kind) {
  final names = [entry.bareKey, ...entry.aliases, entry.label].where((t) => t.isNotEmpty);
  if (kind == SettingCommandKind.set) return names.toList();
  return names.map(_withoutVisibilityPrefix).where((t) => t.isNotEmpty).toList();
}

/// One ranked candidate. Higher [score] is better; scores only mean anything
/// relative to other candidates for the SAME query.
/// [viaDescription] is what keeps "a description match always ranks below
/// every name match" true, rather than the two scores' relative size — a name
/// score has no floor and would otherwise sink beneath the description
/// penalty for a badly-scattered match across a long label.
typedef SettingMatch = ({SettingsCatalogEntry entry, int score, bool viaDescription});

/// Whether one of [entry]'s names BEGINS with [query] — both compared with
/// punctuation and case removed, so "avoid zero beat" begins
/// `Avoid Zero-Beating on Spots`.
///
/// A much stronger claim than being a subsequence of it, and the one thing
/// that reliably separates "these words ARE the setting's name" from "these
/// words happen to be scattered through it". `settings_command.dart` splits a
/// typed name from a typed value on it.
bool settingNameBeginsWith(
  SettingsCatalogEntry entry,
  String query, {
  SettingCommandKind kind = SettingCommandKind.set,
}) {
  final term = normalizeSettingTerm(query);
  if (term.isEmpty) return false;
  return _matchTermsFor(entry, kind).any((name) => normalizeSettingTerm(name).startsWith(term));
}

/// Whether one of [entry]'s names IS [query] — the same comparison as
/// [settingNameBeginsWith] with nothing left over.
///
/// The score alone can't tell this apart from a prefix match: matching every
/// typed character consecutively from a name's start earns the same raw score
/// whether or not the name continues afterwards, and only the length
/// tie-breaker separates `report` (an alias of `defaultReport`, exact) from
/// `reportCW` (an alias of `defaultReportCW`, merely starting with it). A
/// caller deciding whether a query really picked one setting out has to ask
/// this as well, or those two read as a tie.
bool settingNameEquals(
  SettingsCatalogEntry entry,
  String query, {
  SettingCommandKind kind = SettingCommandKind.set,
}) {
  final term = normalizeSettingTerm(query);
  if (term.isEmpty) return false;
  return _matchTermsFor(entry, kind).any((name) => normalizeSettingTerm(name) == term);
}

/// [entries] that match [query], best first.
///
/// Matching is a SUBSEQUENCE, VS Code Ctrl+P style: the characters typed must
/// appear in the name in order, but need not be adjacent, so `zrbt` finds
/// "Avoid Zero Beat". [fuzzyMatchScore] then ranks them — consecutive
/// characters, word boundaries and short names all earn points — which is what
/// keeps a scattered accidental match well below the name someone meant.
///
/// A setting whose DESCRIPTION mentions the query still matches, but always
/// below every name match ([_descriptionPenalty]); descriptions are matched as
/// plain substrings, never as subsequences.
///
/// SHOW/HIDE additionally restrict the field to visibility toggles
/// ([SettingsCatalogEntry.isVisibilityToggle]) — every other setting is
/// unreachable by those verbs, which is what makes `SHOW GRID` unambiguous
/// where `SET GRID` might not be.
///
/// Ties are NOT broken arbitrarily: when two candidates score the same, the
/// caller is expected to ask rather than guess (settings_command.dart).
List<SettingMatch> rankSettings(
  String query,
  List<SettingsCatalogEntry> entries, {
  SettingCommandKind kind = SettingCommandKind.set,
}) {
  final q = normalizeFuzzyQuery(query);
  if (q.isEmpty) return const [];

  // Paired with its catalog position, which the comparator falls back on —
  // see below.
  final matches = <(int, SettingMatch)>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (kind != SettingCommandKind.set && !entry.isVisibilityToggle) continue;
    final byName = _bestNameScore(q, _matchTermsFor(entry, kind));
    if (byName != null) {
      matches.add((i, (entry: entry, score: byName, viaDescription: false)));
    } else if ((entry.description ?? '').toLowerCase().contains(query.toLowerCase())) {
      matches.add((i, (entry: entry, score: _descriptionPenalty, viaDescription: true)));
    }
  }

  // Name matches first as a class, then by score, then by catalog position.
  //
  // That last step is not decoration. Dart's `List.sort` is NOT stable — it
  // switches to an introsort above 32 elements, and a permissive subsequence
  // query easily matches that many — so equal-scoring candidates would come
  // back in an arbitrary order that differs between calls. `SET <name>` ranks
  // TWICE, once for the debounced preview and once for the `execute: true`
  // pass, so an unbroken tie could preview "Change A to Off?" and then write
  // B, with the confirmation naming A. The index also keeps the dialog's rows
  // and the "and N more" count from reshuffling between keystrokes.
  matches.sort((a, b) {
    final (indexA, matchA) = a;
    final (indexB, matchB) = b;
    if (matchA.viaDescription != matchB.viaDescription) return matchA.viaDescription ? 1 : -1;
    final byScore = matchB.score.compareTo(matchA.score);
    return byScore != 0 ? byScore : indexA.compareTo(indexB);
  });
  return [for (final (_, match) in matches) match];
}

/// A value the command line asked for, resolved against the setting's type.
sealed class SettingValueParse {
  const SettingValueParse();
}

/// [value] is what to write; [label] is how to say it back to the user.
final class ParsedSettingValue extends SettingValueParse {
  final dynamic value;
  final String label;

  const ParsedSettingValue(this.value, this.label);
}

/// The typed value doesn't fit the setting. [expected] describes what would,
/// already localized — so the command can say what to type instead of just
/// refusing.
final class UnparsedSettingValue extends SettingValueParse {
  final String expected;

  const UnparsedSettingValue(this.expected);
}

/// "one of: …", listing a select's options by the names the operator sees.
String _optionsExpected(SettingsCatalogEntry entry) => t.commands.settingExpectsOneOf(
      choices: entry.options.map((o) => o['label'] ?? o['value']).whereType<String>().join(', '),
    );

/// Every word accepted for a boolean, in every locale the app ships — not
/// just the one that happens to be active.
///
/// These are compared against what the operator TYPES, while `settingOn`/
/// `settingOff` and `settingExpectsOnOff` are translated. An English-only list
/// therefore tells a Spanish operator the setting takes "sí o no" and then
/// rejects `sí`, forever. (`no` would keep working by coincidence, which makes
/// it read as a random failure rather than a missing language.) Accepting
/// every locale's words everywhere costs nothing — no setting takes `si` as a
/// text value in a way this could shadow, since coercion only reaches here for
/// `checkbox`.
const _trueWords = {
  'y', 'yes', 't', 'true', 'on', '1', 'enabled', 'enable', // en
  'si', 'sí', 'v', 'verdadero', 'activado', 'activar', // es
};
const _falseWords = {
  'n', 'no', 'f', 'false', 'off', '0', 'disabled', 'disable', // en
  'falso', 'desactivado', 'desactivar', // es
};

/// Reads [raw] as a value for [entry].
///
/// Booleans take the full spoken vocabulary (Y/YES/ON/TRUE/1 and their
/// opposites) — app-polo's SET accepted those and its users type them.
/// Selects match an option by value or by label, exactly then by prefix, so
/// `SET THEME DARK` works without typing the option's internal value.
SettingValueParse parseSettingValue(SettingsCatalogEntry entry, String raw) {
  final trimmed = raw.trim();
  switch (entry.fieldType) {
    case 'checkbox':
      final word = trimmed.toLowerCase();
      if (_trueWords.contains(word)) return ParsedSettingValue(true, settingValueLabel(entry, true));
      if (_falseWords.contains(word)) return ParsedSettingValue(false, settingValueLabel(entry, false));
      return UnparsedSettingValue(t.commands.settingExpectsOnOff);

    case 'select':
      final q = normalizeSettingTerm(trimmed);
      // An empty term would make the prefix matcher below accept the FIRST
      // option — `startsWith('')` is true of everything — and silently write
      // it. Unreachable from the command path today (a punctuation-only
      // trailing token is absorbed into the name by _splitArgs), but this is a
      // public entry point.
      if (q.isEmpty) return UnparsedSettingValue(_optionsExpected(entry));
      for (final matcher in [
        (String s) => normalizeSettingTerm(s) == q,
        (String s) => normalizeSettingTerm(s).startsWith(q),
      ]) {
        for (final option in entry.options) {
          final optionValue = option['value'];
          final optionLabel = option['label'];
          final hit = (optionValue is String && matcher(optionValue)) || (optionLabel is String && matcher(optionLabel));
          if (hit) return ParsedSettingValue(optionValue, settingValueLabel(entry, optionValue));
        }
      }
      return UnparsedSettingValue(_optionsExpected(entry));

    case 'number':
      final parsed = num.tryParse(trimmed);
      if (parsed == null) return UnparsedSettingValue(t.commands.settingExpectsNumber);
      return ParsedSettingValue(parsed, settingValueLabel(entry, parsed));

    default:
      return ParsedSettingValue(trimmed, settingValueLabel(entry, trimmed));
  }
}

/// How to say [value] back to the user for [entry] — an option's own label
/// rather than its internal value, On/Off rather than true/false. Falls back
/// to the entry's current value when [value] is omitted.
String settingValueLabel(SettingsCatalogEntry entry, [Object? value = _unset]) {
  final v = identical(value, _unset) ? entry.value : value;
  switch (entry.fieldType) {
    case 'checkbox':
      return v == true ? t.commands.settingOn : t.commands.settingOff;
    case 'select':
      for (final option in entry.options) {
        if (option['value'] == v && option['label'] is String) return option['label'] as String;
      }
      return v?.toString() ?? '';
    case 'multiselect':
      final count = v is List ? v.length : 0;
      return t.commands.settingSelectedCount(count: count);
    case 'secret':
      // Never echoed, at any length — this line reaches a describe preview
      // that sits on screen while the operator types.
      return (v is String && v.isNotEmpty) ? t.commands.settingSecretSet : t.commands.settingSecretUnset;
    default:
      final text = v?.toString() ?? '';
      return text.isEmpty ? t.commands.settingEmpty : text;
  }
}

const _unset = Object();
