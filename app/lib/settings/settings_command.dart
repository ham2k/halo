// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app half of the SET/SHOW/HIDE commands: resolving what the operator
// typed against the settings catalog, and writing the result.
//
// The split with the `settings-commands` extension is deliberate. The
// extension owns the grammar and the wording — which words are commands, and
// how the describe line reads in the user's language. Everything here needs
// data the extension cannot have: option lists, current values, per-platform
// and dev-mode visibility, and the commit routing that differs between a core
// group and an extension settingsPanel. So the extension parses, calls
// [searchSettingsForCommand] through the `searchSettings` host call, and hands
// the resolved key and value straight back as a command action, which
// [applySettingCommand] writes.
//
// Re-entrancy note: `searchSettings` is called from INSIDE a running command
// hook, and answering it re-enters the extension runtime to read every
// settingsPanel. That is safe by construction — the host keys calls by id with
// independent completers and takes no lock (halo_extension_host.dart's
// `_send`), so the nested call settles on its own while the outer one waits.

import 'package:flutter/foundation.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import 'settings_catalog.dart';
import 'settings_registry.dart';
import 'settings_fuzzy.dart';
import 'settings_scan.dart';

SettingCommandKind _kindFrom(String? raw) => switch (raw) {
  'show' => SettingCommandKind.show,
  'hide' => SettingCommandKind.hide,
  _ => SettingCommandKind.set,
};

/// Resolves everything the operator typed after the verb — [args] — against
/// the settings catalog, for the `searchSettings` host call.
///
/// Splitting a name from a value is done HERE, not in the command hook,
/// because only this side knows which settings exist: `SET AVOID ZERO BEAT N`
/// and `SET THEME DARK` have the same shape, and the only thing that tells
/// them apart is that "avoid zero beat" names a setting and "theme dark"
/// doesn't. [_splitArgs] weighs every way of splitting them for that reason —
/// a query is a setting's name in preference to being a shorter name plus a
/// value that happens to look plausible.
///
/// SHOW/HIDE never split: their value comes from the verb, inverted for a
/// setting that reads "hidden = on" rather than "shown = on".
///
/// Always answers; never throws. A query matching nothing reports
/// `found: false` rather than an error, because this runs on every keystroke
/// of a half-typed command and "no match yet" is the normal state.
Future<Map<String, dynamic>> searchSettingsForCommand(
  HaLoServices services, {
  required String args,
  String? kind,
}) async {
  final commandKind = _kindFrom(kind);
  final catalog = await buildSettingsCatalog(services, developerMode: services.settings.developerMode);

  final split = _splitArgs(args, catalog, commandKind);
  if (split == null) return {'found': false, 'query': args.trim()};
  final (matches, name, value) = split;

  final best = matches.first;
  // A second candidate that matched just as well means the query doesn't
  // genuinely name one setting — the command opens the dialog rather than
  // silently changing whichever happened to sort first.
  //
  // Compared with [fuzzyScoresTie], not `==`: the final score subtracts the
  // target's length, so exact equality needs two names of identical length as
  // well as identical match structure, and this guard would fire almost never
  // — treating a one-point accident between two settings as a decision.
  // Two things break a tie regardless of the numbers, because the score can't
  // express either: a name match is never "as good as" a description match,
  // and a name that IS the query is never as good as one that merely starts
  // with it (both earn the same raw score — see [settingNameEquals]).
  final runnerUp = matches.length > 1 ? matches[1] : null;
  final isAmbiguous = runnerUp != null &&
      runnerUp.viaDescription == best.viaDescription &&
      settingNameEquals(best.entry, name, kind: commandKind) ==
          settingNameEquals(runnerUp.entry, name, kind: commandKind) &&
      fuzzyScoresTie(best.score, runnerUp.score);

  final entry = best.entry;
  final result = <String, dynamic>{
    'found': true,
    'query': name,
    'key': entry.key,
    'label': entry.label,
    'section': entry.section,
    'fieldType': entry.fieldType,
    'valueLabel': settingValueLabel(entry),
    // The RAW current value beside its formatted one, for the one shape that
    // needs it: a hook that TOGGLES a setting has to know which way, and
    // comparing localized labels to work that out would break in every
    // language but the one it was written in.
    //
    // Booleans and nothing else. This crosses the extension bridge to any
    // extension with a `command` hook, and a secret's plaintext must not —
    // [settingValueLabel] masks it for exactly that reason, and a raw value
    // beside the masked one would hand back what the mask exists to withhold.
    if (entry.value is bool) 'value': entry.value,
    'simple': entry.isSimple,
    'ambiguous': isAmbiguous,
    // EVERY match, best first — not just the winner and not a capped sample.
    // The dialog these open lists them all, so a cap here would silently drop
    // settings the operator's query genuinely named, which is exactly the
    // "where did my setting go" failure the derived catalog exists to avoid.
    // The whole catalog is only a few dozen entries; sending all of them costs
    // nothing worth optimizing.
    'candidates': [
      for (final match in matches)
        {'key': match.entry.key, 'label': match.entry.label, 'section': match.entry.section},
    ],
  };

  if (commandKind != SettingCommandKind.set) {
    // SHOW turns visibility on, HIDE turns it off — which is the opposite
    // boolean for a setting named `hide…`.
    final wantsVisible = commandKind == SettingCommandKind.show;
    final newValue = entry.isInverted ? !wantsVisible : wantsVisible;
    result['newValue'] = newValue;
    result['newValueLabel'] = settingValueLabel(entry, newValue);
    result['unchanged'] = _isUnchanged(entry, newValue);
    return result;
  }

  if (value == null || value.trim().isEmpty) return result;

  if (!entry.isSimple) {
    // A value typed at a multiselect/account/secret isn't an error worth
    // scolding over — the dialog is where that setting is edited, and the
    // command opens it either way.
    return result;
  }

  final parsed = parseSettingValue(entry, value);
  switch (parsed) {
    case UnparsedSettingValue(:final expected):
      result['expects'] = expected;
    case ParsedSettingValue(value: final newValue, :final label):
      result['newValue'] = newValue;
      result['newValueLabel'] = label;
      result['unchanged'] = _isUnchanged(entry, newValue);
  }
  return result;
}

/// [key]'s value after re-reading only [group], or null when the group no
/// longer declares it (nothing to verify against).
Future<dynamic> _currentValueIn(SettingsGroup group, String key) async {
  for (final el in await group.buildElements()) {
    if (el['type'] == 'field' && el['key'] == key) return declaredSettingValue(el);
  }
  return null;
}

/// Whether a stored value equals what was written, allowing for the same
/// normalization [_isUnchanged] does.
bool _valuesMatch(dynamic stored, dynamic written) {
  if (stored is String && written is String) {
    return stored.trim().toLowerCase() == written.trim().toLowerCase();
  }
  return stored == written;
}

/// Whether writing [newValue] to [entry] would change anything.
///
/// Not a bare `==`, because a group's `commit` may normalize on the way in:
/// every default-report field is stored `trim().toUpperCase()`, so a second
/// `SET REPORT 5nn` compares the typed `5nn` against the stored `5NN`, reports
/// a change that won't happen, and writes again — the exact
/// "reporting a change that didn't happen" this flag exists to prevent.
///
/// Case is therefore ignored for `text`. The cost is that changing ONLY the
/// case of a case-preserving text setting reads as "already set"; every text
/// setting the app declares today is stored upper-cased, so that trade is
/// currently free, and the settings screen is where such an edit belongs.
bool _isUnchanged(SettingsCatalogEntry entry, dynamic newValue) {
  final current = entry.value;
  if (entry.fieldType == 'text' && current is String && newValue is String) {
    return current.trim().toLowerCase() == newValue.trim().toLowerCase();
  }
  return current == newValue;
}

/// Splits [args] into "the setting's name" and "the value", against what the
/// catalog actually contains. Returns the ranked matches, the name text they
/// were found by, and the remaining value, or null when no split names
/// anything.
///
/// Every split is scored and the best one wins. Simply taking the longest name
/// that matches anything does not survive subsequence matching, which is far
/// too easy to satisfy to decide this on its own: in `SET ZEROBEAT N` the whole string — trailing `N` included — is
/// a subsequence of the label "Avoid Zero-Beating on Spots", so the value is
/// swallowed into the name and nothing is ever written.
///
/// The measure is score PER QUERY CHARACTER, not raw score. Raw score always
/// grows with a longer query (every matched character earns points), so it
/// would pick the greediest split every time; per character, a tight, boundary
/// aligned match beats one that only fits by straggling across the name. Ties
/// go to the longer name, so `SET WIBBLE EXTRA` still reads as one setting
/// called "Wibble Extra" rather than "Wibble" set to "extra".
///
/// A split whose leftover text the matched setting can't accept is rejected
/// outright and kept only as the fallback for reporting what it does accept.
///
/// SHOW/HIDE take no value at all, so they only ever try the whole string.
(List<SettingMatch>, String, String?)? _splitArgs(
  String args,
  List<SettingsCatalogEntry> catalog,
  SettingCommandKind kind,
) {
  final tokens = args.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return null;

  // SHOW/HIDE take no value, so there is nothing to split off: every word is
  // part of the name.
  if (kind != SettingCommandKind.set) {
    final name = tokens.join(' ');
    final matches = rankSettings(name, catalog, kind: kind);
    return matches.isEmpty ? null : (matches, name, null);
  }

  (List<SettingMatch>, String, String?)? best;
  bool bestViaDescription = true;
  double bestQuality = double.negativeInfinity;
  (List<SettingMatch>, String, String?)? valueRejected;

  for (var nameLength = tokens.length; nameLength >= 1; nameLength--) {
    final name = tokens.take(nameLength).join(' ');
    final termLength = normalizeFuzzyQuery(name).length;
    if (termLength == 0) continue;
    final matches = rankSettings(name, catalog, kind: kind);
    if (matches.isEmpty) continue;
    final value = nameLength == tokens.length ? null : tokens.skip(nameLength).join(' ');
    final entry = matches.first.entry;

    if (value != null && entry.isSimple && parseSettingValue(entry, value) is! ParsedSettingValue) {
      // Remember the first (longest-name) rejection: if nothing else works,
      // this is the one worth reporting, since it is the setting the operator
      // most likely meant. (A non-simple setting opens the dialog whatever
      // follows it, so there is no value to reject.)
      valueRejected ??= (matches, name, value);
      continue;
    }

    // These words BEGIN a real setting's name — they are its name, not a
    // shorter name plus a value. Taken outright, longest first, because no
    // score comparison decides this reliably: `WIBBLE EXTRA` naming
    // "Wibble Extra" and `ZEROBEAT N` naming "Avoid Zero-Beating on Spots"
    // score within about 1% of their shorter alternatives, in opposite
    // directions.
    if (settingNameBeginsWith(entry, name, kind: kind)) return (matches, name, value);

    // Nothing named outright yet. Fall back to score per query character —
    // raw score always grows with a longer query, so it would pick the
    // greediest split every time; per character, a tight boundary-aligned
    // match beats one that only fits by straggling across a long name.
    // A NAME match always beats a description-only one, whatever the numbers
    // say — the same rule `rankSettings` applies within a single query, which
    // it enforces by sorting on `viaDescription` rather than by score. The
    // scores here cannot be compared across that line: `rankSettings` returns
    // name scores unclamped, and a straggling multi-word name match sinks far
    // below the fixed description penalty, so a split whose best hit merely
    // MENTIONS the words would otherwise win — and then be written to.
    final viaDescription = matches.first.viaDescription;
    final quality = matches.first.score / termLength;
    if (bestViaDescription && !viaDescription) {
      bestViaDescription = false;
      bestQuality = quality;
      best = (matches, name, value);
    } else if (viaDescription == bestViaDescription && quality > bestQuality) {
      bestQuality = quality;
      best = (matches, name, value);
    }
  }

  return best ?? valueRejected;
}

/// Writes [value] to the setting [key] names, through whichever commit path
/// that setting was declared by.
///
/// Returns null on success, or a validation error to show. Re-scans rather
/// than trusting a key resolved milliseconds ago: an extension restart or a
/// dev-mode toggle between preview and Enter can retire a setting, and writing
/// to a stale route would put the value somewhere nothing reads.
Future<String?> applySettingCommand(
  HaLoServices services, {
  required String key,
  required dynamic value,
}) async {
  ScannedSetting? target;
  for (final scanned in await scanSettings(services)) {
    if (scanned.isField && scanned.key == key) {
      target = scanned;
      break;
    }
  }
  // Gone between the preview and Enter — the very case the re-scan exists for.
  // This has to come back as an ERROR, never as silent success: the hook has
  // already handed the operator its `confirm` ("Theme set to Dark"), so
  // returning null here leaves them told about a write that never happened,
  // which is exactly what `alreadySet` exists to avoid.
  if (target == null) {
    debugPrint('[settings-commands] no setting named "$key" to write');
    return t.commands.settingVanished(label: key);
  }

  final group = target.group;
  if (group != null) {
    await group.commit(key, value);
    // Verified, not assumed — which relies on a group's `buildElements`
    // reflecting what it just committed. Every core group does: they read
    // back through SettingsService rather than replaying a declaration.
    //
    // Every core group's `commit` type-checks and
    // silently drops what it can't store (`if (value is String)`, an enum name
    // that doesn't resolve, a `default:` branch taking only bools), so a value
    // of the wrong shape leaves the setting untouched while the hook's confirm
    // says it changed. Re-reading one group's elements is cheap — no extension
    // bridge call — unlike the full scan above.
    final after = await _currentValueIn(group, key);
    if (after != null && !_valuesMatch(after, value)) {
      debugPrint('[settings-commands] "$key" did not take $value (still $after)');
      return t.commands.settingNotStored(label: target.element['label'] as String? ?? key);
    }
    return null;
  }

  final route = target.fieldRoute;
  if (route == null) {
    debugPrint('[settings-commands] "$key" has no commit route');
    return t.commands.settingVanished(label: key);
  }

  // The panel's values with THIS field already holding the new one — the same
  // state the settings screen hands an extension, where FormRenderer's
  // `_values` has the edit in it before `_autosave` runs. Passing the pre-edit
  // value would make a hook's cross-field validation (or a `transformField`
  // that reads its own field) behave differently depending on whether the
  // write came from the screen or from a command.
  final state = {...target.siblingValues, route.fieldKey: value};
  final error = await services.extensions.validateSettingsField(
    kind: route.kind,
    hookKey: route.hookKey,
    panelKey: route.panelKey,
    field: route.field,
    fieldKey: route.fieldKey,
    value: value,
    state: state,
  );
  if (error != null) return error;

  final committedValue = route.kind == 'dynamic'
      ? await services.extensions.transformSettingsField(
          hookKey: route.hookKey,
          panelKey: route.panelKey,
          fieldKey: route.fieldKey,
          value: value,
          state: state,
        )
      : value;

  await services.extensions.commitSettingsFieldValue(
    kind: route.kind,
    hookKey: route.hookKey,
    panelKey: route.panelKey,
    fieldKey: route.fieldKey,
    value: committedValue,
    state: state,
    isSecret: route.field['fieldType'] == 'secret',
    restartOnChange: route.field['restartOnChange'] == true,
  );
  return null;
}
