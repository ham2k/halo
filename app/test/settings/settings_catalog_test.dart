// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-151: what the SET/SHOW/HIDE commands can find, and what they make of
// the value typed after it.
//
// The catalog's whole reason to exist is that it is DERIVED — a setting is
// reachable because it was declared, not because someone remembered to list
// it. So the traps worth catching here are the ones that would quietly break
// that derivation: a setting the settings screen is hiding (dev mode,
// visibleWhen) still answering to a command, a `hide…` toggle written the
// wrong way round by SHOW/HIDE, and a query that names several settings being
// resolved to whichever happened to sort first instead of asking.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/settings_catalog.dart';
import 'package:ham2k_logger/settings/settings_command.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:ham2k_logger/settings/settings_scan.dart';

import '../support/halo_test_support.dart';

/// A group declaring exactly the shapes this file needs to reason about, so
/// the assertions don't move every time a real settings panel gains a field.
class _TestGroup extends SettingsGroup {
  final List<Map<String, dynamic>> elements;
  final committed = <String, dynamic>{};

  _TestGroup(this.elements);

  @override
  String get key => 'test-group';

  @override
  String get title => 'Test Group';

  @override
  int get order => 999;

  // Rebuilt from the committed values, as every real group does by reading
  // back through SettingsService. A double that returned the same declared
  // elements forever would report every successful write as rejected, since
  // `applySettingCommand` verifies the value took.
  @override
  Future<List<Map<String, dynamic>>> buildElements() async => [
    for (final el in elements)
      if (el['key'] is String && committed.containsKey(el['key'])) {...el, 'value': committed[el['key']]} else el,
  ];

  @override
  Future<void> commit(String fieldKey, dynamic value) async => committed[fieldKey] = value;
}

SettingsCatalogEntry _entry(
  String key, {
  String? label,
  List<String> aliases = const [],
  String fieldType = 'checkbox',
  dynamic value = false,
  String? description,
  List<Map<String, dynamic>> options = const [],
}) => SettingsCatalogEntry(
  key: key,
  bareKey: key,
  label: label ?? key,
  description: description,
  aliases: aliases,
  section: 'Section',
  fieldType: fieldType,
  value: value,
  options: options,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> servicesWith(List<Map<String, dynamic>> elements, {bool developerMode = false}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    if (developerMode) await settings.setDeveloperMode(true);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(db, settings);
    services.settingsRegistry.register(_TestGroup(elements));
    return services;
  }

  group('catalog reachability follows the settings screen', () {
    test('a devMode field is absent until developer mode is on', () async {
      const el = {'type': 'field', 'fieldType': 'checkbox', 'key': 'secretKnob', 'label': 'Secret Knob', 'value': false, 'devMode': true};

      final off = await servicesWith([el]);
      expect(
        (await buildSettingsCatalog(off, developerMode: false)).map((e) => e.key),
        isNot(contains('secretKnob')),
        reason:
            'FormRenderer hides devMode elements entirely; a command that still reached one would be '
            'changing a setting the user cannot see or find',
      );

      final on = await servicesWith([el], developerMode: true);
      expect((await buildSettingsCatalog(on, developerMode: true)).map((e) => e.key), contains('secretKnob'));
    });

    test('a visibleWhen field is absent while its condition does not hold', () async {
      List<Map<String, dynamic>> elementsWithMode(String mode) => [
        {'type': 'field', 'fieldType': 'select', 'key': 'mode', 'label': 'Mode', 'value': mode},
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'zone',
          'label': 'Zone',
          'value': '',
          'visibleWhen': {'field': 'mode', 'equals': 'contest'},
        },
      ];

      final hidden = await servicesWith(elementsWithMode('casual'));
      expect(
        (await buildSettingsCatalog(hidden, developerMode: false)).map((e) => e.key),
        isNot(contains('zone')),
        reason: 'the settings form would not be showing this field at all with mode: casual',
      );

      final shown = await servicesWith(elementsWithMode('contest'));
      expect((await buildSettingsCatalog(shown, developerMode: false)).map((e) => e.key), contains('zone'));
    });

    test('aliases declared on an element reach the catalog', () async {
      final services = await servicesWith([
        {
          'type': 'field',
          'fieldType': 'checkbox',
          'key': 'avoidZeroBeat',
          'label': 'Avoid Zero Beat',
          'value': true,
          'aliases': ['zeroBeat'],
        },
      ]);
      final entry = (await buildSettingsCatalog(services, developerMode: false)).firstWhere((e) => e.key == 'avoidZeroBeat');
      expect(entry.aliases, contains('zeroBeat'));
    });
  });

  group('the commands and the Settings search box agree', () {
    // The two do different jobs — the box filters and lists every match, the
    // commands rank and act on the best — but they must look at the same
    // things. When they didn't, `SET RST` resolved Default Report (via its
    // alias) while searching "rst" in Settings didn't list it at all, and each
    // looked broken from the other's point of view.
    const queries = ['rst', 'report', 'grid', 'zerobeat', 'zero beat', 'theme', 'show', 'units', 'numbers'];

    test('every setting a command resolves is findable in the search box', () async {
      // The radio group declares nothing without this, and it owns the alias
      // that first exposed the mismatch.
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      await settings.setExperimentEnabled('gato', true);

      // The REAL element maps, as the search box sees them — not rebuilt from
      // catalog entries, which would only prove the reconstruction agrees
      // with itself.
      final elementForKey = {
        for (final scanned in await scanSettings(services))
          if (scanned.isField && scanned.key.isNotEmpty) scanned.key: scanned.element,
      };
      final catalog = await buildSettingsCatalog(services, developerMode: false);
      expect(catalog, isNotEmpty, reason: 'nothing is being compared if the catalog came back empty');

      for (final query in queries) {
        final resolved = rankSettings(query, catalog);
        for (final match in resolved) {
          final element = elementForKey[match.entry.key];
          expect(element, isNotNull, reason: '"${match.entry.key}" is in the catalog but not in the scan');
          expect(
            elementSearchScore(element!, query),
            isNotNull,
            reason:
                'SET "$query" resolves ${match.entry.key}, but searching "$query" in Settings would not '
                'list it — the operator would be told about a setting they cannot then find',
          );
        }
      }
    });

    test('an alias is what the search box finds a setting by, not just the command', () async {
      // The specific regression: `rst` is only an alias of defaultReport, so
      // before aliases were searchable this returned false.
      const element = {
        'type': 'field',
        'fieldType': 'text',
        'key': 'defaultReport',
        'label': 'Default Report',
        'aliases': ['report', 'rst'],
      };
      expect(elementSearchScore(element, 'rst'), isNotNull);
    });

    test('a query with punctuation or spacing finds the setting either way', () {
      const element = {'type': 'field', 'fieldType': 'checkbox', 'key': 'avoidZeroBeat', 'label': 'Avoid Zero Beat'};
      for (final query in ['zerobeat', 'Zero Beat', 'zero-beat']) {
        expect(elementSearchScore(element, query), isNotNull, reason: query);
      }
    });

    test('a query of pure punctuation matches nothing, rather than everything', () {
      // An empty query means "no filter" and matches all. A query that merely
      // normalizes away is not the same thing: treating it as one would show
      // every setting for `-` or `/`, with the section chrome stripped.
      const element = {'type': 'field', 'fieldType': 'checkbox', 'key': 'someToggle', 'label': 'Some Toggle'};
      expect(elementSearchScore(element, '-'), isNull);
      expect(elementSearchScore(element, ''), 0, reason: 'an empty query really is "no filter"');
    });

    test('chrome elements never match, so filtering shows settings only', () {
      const header = {'type': 'header', 'title': 'Reports'};
      expect(elementSearchScore(header, 'report'), isNull);
    });

    test('a description still matches as typed, spaces and all', () {
      // Normalizing the description would let a query span two unrelated
      // words, so it stays a plain substring match.
      const element = {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': 'someToggle',
        'label': 'Some Toggle',
        'description': 'Shows the grid square for each contact',
      };
      expect(elementSearchScore(element, 'grid square'), isNotNull);
      expect(
        elementSearchScore(element, 'thegrid'),
        isNull,
        reason: 'a normalized description would join "the" and "grid" into a match that is not really there',
      );
    });
  });

  group('ranking', () {
    test('a scattered subsequence matches at all — initials find the setting', () {
      // The whole point of the VS Code style: the characters need only appear
      // in order. `zrbt` is not a substring of anything here.
      final entries = [_entry('avoidZeroBeat', label: 'Avoid Zero Beat', value: true)];
      expect(rankSettings('zrbt', entries).single.entry.key, 'avoidZeroBeat');
      expect(
        rankSettings('dfrcw', [_entry('defaultReportCW', label: 'Default Report CW', fieldType: 'text', value: '599')]).single.entry.key,
        'defaultReportCW',
      );
    });

    test('order still matters — a subsequence is not a bag of letters', () {
      final entries = [_entry('avoidZeroBeat', label: 'Avoid Zero Beat', value: true)];
      expect(rankSettings('tbz', entries), isEmpty, reason: 'the same letters in the wrong order must not match, or the ranking is just an anagram check');
    });

    test('a tight run beats the same letters scattered', () {
      final entries = [_entry('showDeletedQSOs', label: 'Show Deleted QSOs'), _entry('sentExchange', label: 'Sent Exchange', fieldType: 'text', value: '')];
      final ranked = rankSettings('sent', entries);
      expect(ranked.first.entry.key, 'sentExchange', reason: '"Show DElemeNTed"-style scatter matches, but must never outrank the word typed in full');
    });

    test('a match at a word boundary beats one buried mid-word', () {
      final entries = [_entry('useCompactFileNames', label: 'Use Compact File Names'), _entry('namedThing', label: 'Named Thing')];
      final ranked = rankSettings('name', entries);
      expect(ranked.first.entry.key, 'namedThing', reason: 'a name STARTING with the query is what the operator most likely meant');
    });

    test('an alias outranks a longer name that merely contains the query', () {
      // The real collision this exists for: `SET ZEROBEAT` must not land on
      // `zeroBeatRangeHz` instead of the toggle the operator meant.
      final entries = [
        _entry('zeroBeatRangeHz', label: 'Zero Beat Range', fieldType: 'number', value: 500),
        _entry('avoidZeroBeat', label: 'Avoid Zero Beat', aliases: ['zeroBeat'], value: true),
      ];
      final ranked = rankSettings('ZEROBEAT', entries);
      expect(ranked.first.entry.key, 'avoidZeroBeat');
      expect(
        ranked.first.score,
        greaterThan(ranked[1].score),
        reason:
            'an exact alias must win outright, not merely sort ahead — an equal score makes the command stop '
            'and ask instead of acting',
      );
    });

    test('the shorter of two equally good names wins', () {
      final entries = [
        _entry('defaultReportCW', label: 'Default Report CW', fieldType: 'text', value: '599'),
        _entry('defaultReport', label: 'Default Report', fieldType: 'text', value: '59'),
      ];
      final ranked = rankSettings('REPORT', entries);
      expect(ranked.first.entry.key, 'defaultReport', reason: 'both match the same way, so the one with least left over is the likelier target');
    });

    test('two names that score identically still tie, so the command can ask', () {
      // Ties are rarer now that scoring is continuous — two names have to match
      // the query the same way AND be the same length — but they still happen
      // (in the real catalog "numbers" ties showNumbersRow with showQsoNumbers)
      // and they are what stops a value being written to a setting the query
      // did not really name.
      final entries = [_entry('alphaMode', label: 'Alpha Mode'), _entry('alphaCode', label: 'Alpha Code')];
      final ranked = rankSettings('alpha', entries);
      expect(ranked.length, 2);
      expect(ranked[0].score, ranked[1].score);
    });

    test('a description match always ranks below every name match', () {
      final entries = [
        _entry('somethingElse', label: 'Something Else', description: 'controls the grid square shown'),
        _entry('showGridField', label: 'Show Grid Field'),
      ];
      final ranked = rankSettings('grid', entries);
      expect(ranked.first.entry.key, 'showGridField');
      expect(ranked.last.entry.key, 'somethingElse');
    });

    test('a description is matched as a substring, never as a subsequence', () {
      // A subsequence of a whole sentence matches almost anything, which is
      // why VS Code fuzzy-matches file names and not file contents.
      final entries = [_entry('somethingElse', label: 'Something Else', description: 'controls the grid square shown')];
      expect(
        rankSettings('ctgs', entries),
        isEmpty,
        reason:
            'those letters are a subsequence of the description, and matching them would make every '
            'setting with prose match every query',
      );
    });

    test('SHOW/HIDE reach only visibility toggles, and match with the prefix stripped', () {
      final entries = [
        _entry('showGridField', label: 'Show Grid Field'),
        _entry('gridSquareFormat', label: 'Grid Square Format', fieldType: 'select', value: 'six'),
      ];

      final asShow = rankSettings('GRID', entries, kind: SettingCommandKind.show);
      expect(
        asShow.map((m) => m.entry.key),
        ['showGridField'],
        reason:
            'gridSquareFormat is not a visibility toggle, so SHOW must not offer it — that narrowing is what '
            'makes SHOW GRID unambiguous where SET GRID is not',
      );

      final asSet = rankSettings('GRID', entries, kind: SettingCommandKind.set);
      expect(asSet.length, 2, reason: 'SET searches everything');
    });

    test('matching ignores case and punctuation on both sides', () {
      final entries = [_entry('zeroBeat', label: 'Zero Beat')];
      for (final query in ['zerobeat', 'ZERO BEAT', 'Zero-Beat']) {
        expect(rankSettings(query, entries), hasLength(1), reason: '"$query" names the setting');
      }
    });
  });

  group('SHOW/HIDE polarity', () {
    test('a hide-named toggle is inverted, so the verb means what it says', () {
      expect(_entry('showNumbersRow', label: 'Show Numbers Row').isInverted, isFalse);
      expect(
        _entry('hideDupes', label: 'Hide Dupes').isInverted,
        isTrue,
        reason:
            'HIDE DUPES must write true to hideDupes but false to a showDupes — reading the polarity off the '
            'name is the only thing keeping the two consistent for the operator',
      );
    });

    test('a non-checkbox named "show…" is not a visibility toggle', () {
      expect(
        _entry('showFormat', label: 'Show Format', fieldType: 'select', value: 'a').isVisibilityToggle,
        isFalse,
        reason: 'SHOW/HIDE have no sensible value to write to a select',
      );
    });
  });

  group('resolving and writing a command', () {
    // No core setting is named `hide…` today, so the end-to-end SHOW/HIDE
    // tests can't tell the polarity logic from a constant `false`. This is
    // where inversion is actually exercised — through the same entry point
    // the host call uses.
    const hideDupes = {'type': 'field', 'fieldType': 'checkbox', 'key': 'hideDupes', 'label': 'Hide Dupes', 'value': false};

    test('HIDE writes true to a hide-named toggle, and SHOW writes false', () async {
      final services = await servicesWith([hideDupes]);

      final hidden = await searchSettingsForCommand(services, args: 'DUPES', kind: 'hide');
      expect(hidden['key'], 'hideDupes');
      expect(hidden['newValue'], isTrue, reason: 'HIDE DUPES means hideDupes = true');

      final shown = await searchSettingsForCommand(services, args: 'DUPES', kind: 'show');
      expect(shown['newValue'], isFalse, reason: 'SHOW DUPES means hideDupes = false');
    });

    test('a search result carries a checkbox\'s raw value, and never a secret\'s', () async {
      final services = await servicesWith([
        hideDupes,
        {'type': 'field', 'fieldType': 'secret', 'key': 'apiKey', 'label': 'Api Key', 'value': 'hunter2'},
      ]);

      // A hook that TOGGLES has to read which way, and comparing localized
      // labels to work that out would break in every language but English.
      final toggle = await searchSettingsForCommand(services, args: 'HIDE DUPES');
      expect(toggle['value'], isFalse);

      // Every one of these crosses the bridge to any extension with a command
      // hook. `valueLabel` masks a secret on purpose; a raw value beside it
      // would hand back exactly what the mask withholds.
      final secret = await searchSettingsForCommand(services, args: 'API KEY');
      expect(secret['key'], 'apiKey');
      expect(secret.containsKey('value'), isFalse);
      expect(secret.toString(), isNot(contains('hunter2')));
    });

    test('a multi-word setting name is read as a name, not as a name plus a value', () async {
      // The split is app-side precisely because "AVOID ZERO BEAT N" and
      // "THEME DARK" are the same shape — only the catalog can say that the
      // first three words are a name here and the first one is a name there.
      final services = await servicesWith([
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'avoidZeroBeat', 'label': 'Avoid Zero Beat', 'value': false},
      ]);

      final result = await searchSettingsForCommand(services, args: 'AVOID ZERO BEAT Y');
      expect(result['key'], 'avoidZeroBeat');
      expect(result['newValue'], isTrue, reason: 'the trailing Y is the value, everything before it the name');
      expect(result['query'], 'AVOID ZERO BEAT', reason: 'the message quotes the name it settled on, not the whole of what was typed');
    });

    test('a longer name wins over a shorter one whose leftover would still parse', () async {
      // Deliberately TEXT settings. A checkbox rejects a stray word as a
      // value, so the split would land on the right setting whichever
      // direction it searched — but a text field accepts anything, so nothing
      // but preferring the longest name stops the second word being written
      // into the shorter setting as its value.
      //
      // Names nothing real is called: this group is registered ON TOP of the
      // app's own, so a plausible name would be matched against the real
      // settings too and stop testing the split at all.
      final services = await servicesWith([
        {'type': 'field', 'fieldType': 'text', 'key': 'wibble', 'label': 'Wibble', 'value': 'a'},
        {'type': 'field', 'fieldType': 'text', 'key': 'wibbleExtra', 'label': 'Wibble Extra', 'value': 'b'},
      ]);
      final result = await searchSettingsForCommand(services, args: 'WIBBLE EXTRA');
      expect(result['key'], 'wibbleExtra');
      expect(result['newValue'], isNull, reason: 'every word was the name — there is no value here to write');
    });

    test('two near-equal matches count as ambiguous, not as a decision', () async {
      // The final score subtracts the target's length, so two settings tie
      // EXACTLY only if their names are the same length as well as matched the
      // same way. Requiring exact equality would make this guard fire almost
      // never, and `SET <vague> <value>` would write to whichever ranked a
      // point higher — silently, since the hook prints its confirm either way.
      final services = await servicesWith([
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'wobbleAlpha', 'label': 'Wobble Alpha', 'value': false},
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'wobbleBravoo', 'label': 'Wobble Bravoo', 'value': false},
      ]);
      final result = await searchSettingsForCommand(services, args: 'wobble Y');
      expect(result['ambiguous'], isTrue, reason: 'both names begin with the query and matched it the same way');
    });

    test('a name that IS the query is not a tie with one that merely starts with it', () async {
      // The counterweight to the test above. Both score the same raw — every
      // typed character matched consecutively from the start — and only the
      // length tie-breaker separates them, so a pure score comparison calls
      // this ambiguous and refuses to write. `SET REPORT 59` must still act.
      final services = await servicesWith([
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'wibbleReport',
          'label': 'Wibble Report',
          'value': '59',
          'aliases': ['wreport'],
        },
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'wibbleReportCW',
          'label': 'Wibble Report CW',
          'value': '599',
          'aliases': ['wreportCW'],
        },
      ]);
      final result = await searchSettingsForCommand(services, args: 'wreport 5nn');
      expect(result['key'], 'wibbleReport');
      expect(result['ambiguous'], isFalse);
      expect(result['newValue'], '5nn');
    });

    test('a text value already in place is recognized through the commit path\'s normalization', () async {
      // LoggingSettingsGroup stores the reports `trim().toUpperCase()`, so a
      // raw `==` against what was typed never matches and every repeat says
      // "Change …" and writes again.
      final services = await servicesWith([
        {'type': 'field', 'fieldType': 'text', 'key': 'reportish', 'label': 'Reportish', 'value': '5NN'},
      ]);
      final result = await searchSettingsForCommand(services, args: 'reportish 5nn');
      expect(result['key'], 'reportish');
      expect(result['unchanged'], isTrue);
    });

    test('equal-scoring matches come back in the same order every time', () {
      // Dart's `List.sort` is NOT stable — it switches to an introsort above
      // 32 elements, and a permissive subsequence query easily matches that
      // many. `SET <name>` ranks twice (the debounced preview, then the
      // `execute: true` pass), so an unbroken tie could preview one setting
      // and write another, with the confirmation naming the first.
      final entries = [for (var i = 0; i < 40; i++) _entry('zzTie${i.toString().padLeft(2, '0')}', label: 'ZZ Tie ${i.toString().padLeft(2, '0')}')];
      final first = rankSettings('zztie', entries).map((m) => m.entry.key).toList();
      expect(first.length, 40, reason: 'past the threshold where Dart stops being stable');
      for (var run = 0; run < 5; run++) {
        expect(
          rankSettings('zztie', entries).map((m) => m.entry.key).toList(),
          first,
          reason: 'run $run disagreed — the order must not depend on the sort implementation',
        );
      }
      expect(first.first, 'zzTie00', reason: 'ties fall back to catalog order');
    });

    test('a description match never outranks a name match, however badly the name scored', () {
      // A name score has no floor — every skipped character costs — so a
      // two-letter query straggling across a long label sinks below any fixed
      // description penalty. Ordering has to separate the two kinds, not
      // compare their numbers.
      final entries = [
        _entry('somethingElse', label: 'Something Else', description: 'mentions ab here'),
        _entry('aVeryLongSettingNameIndeedForTesting', label: 'A Very Long Setting Name Indeed For Testing b'),
      ];
      final ranked = rankSettings('ab', entries);
      expect(ranked.first.entry.key, 'aVeryLongSettingNameIndeedForTesting', reason: 'a weak NAME match still beats a description mention');
      expect(ranked.first.viaDescription, isFalse);
    });

    test('a checkbox that declares no value reads as off, as the form would hold it', () async {
      // FormRenderer fills a missing checkbox in as `false` before anything
      // reads it. Leaving it null here makes `null == false` false, so HIDE on
      // such a setting reports a change and writes one that changes nothing.
      final services = await servicesWith([
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'showThingy', 'label': 'Show Thingy'},
      ]);
      final result = await searchSettingsForCommand(services, args: 'thingy', kind: 'hide');
      expect(result['key'], 'showThingy');
      expect(result['unchanged'], isTrue, reason: 'it is already off — HIDE has nothing to do');
    });

    test('an unmatched query answers found: false rather than failing', () async {
      final services = await servicesWith([hideDupes]);
      final result = await searchSettingsForCommand(services, args: 'NOTHINGLIKETHIS');
      expect(result['found'], isFalse);
      expect(result['key'], isNull);
    });

    test('a write goes through the declaring group commit path', () async {
      final group = _TestGroup([hideDupes]);
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      services.settingsRegistry.register(group);

      expect(await applySettingCommand(services, key: 'hideDupes', value: true), isNull);
      expect(group.committed, {'hideDupes': true}, reason: 'the command must reuse the settings form\'s own commit path, not write storage directly');
    });

    test('a write to a setting that has since vanished reports, rather than passing as done', () async {
      // The hook has already shown its confirm ("… set to …") by the time this
      // runs, so answering null — which the caller reads as success — would
      // leave the operator told about a write that never happened. That is the
      // exact distrust `alreadySet` exists to prevent.
      final services = await servicesWith([hideDupes]);
      final error = await applySettingCommand(services, key: 'noSuchSetting', value: true);
      expect(error, isNotNull);
      expect(error, contains('noSuchSetting'));
    });
  });

  group('value coercion', () {
    test('booleans take the whole spoken vocabulary, both ways', () {
      final entry = _entry('flag');
      for (final word in ['Y', 'yes', 'ON', 'true', '1']) {
        expect((parseSettingValue(entry, word) as ParsedSettingValue).value, isTrue, reason: word);
      }
      for (final word in ['N', 'no', 'OFF', 'false', '0']) {
        expect((parseSettingValue(entry, word) as ParsedSettingValue).value, isFalse, reason: word);
      }
    });

    test('the booleans a Spanish operator would type are accepted too', () {
      // The words compared here are what the operator TYPES, while the "takes
      // sí o no" prompt and the On/Off labels are translated. English-only
      // sets tell a Spanish operator to type `sí` and then reject it forever —
      // and `no` keeps working by coincidence, so it reads as a random failure
      // rather than a missing language.
      final entry = _entry('flag');
      for (final word in ['si', 'sí', 'verdadero', 'activado']) {
        expect((parseSettingValue(entry, word) as ParsedSettingValue).value, isTrue, reason: word);
      }
      for (final word in ['no', 'falso', 'desactivado']) {
        expect((parseSettingValue(entry, word) as ParsedSettingValue).value, isFalse, reason: word);
      }
    });

    test('a boolean given something else reports what it takes instead of guessing', () {
      final parsed = parseSettingValue(_entry('flag'), 'maybe');
      expect(parsed, isA<UnparsedSettingValue>());
      expect((parsed as UnparsedSettingValue).expected, isNotEmpty);
    });

    test('a select matches an option by its label, not just its stored value', () {
      final entry = _entry(
        'themeMode',
        fieldType: 'select',
        value: 'system',
        options: [
          {'label': 'System', 'value': 'system'},
          {'label': 'Dark', 'value': 'dark'},
        ],
      );
      final parsed = parseSettingValue(entry, 'dark') as ParsedSettingValue;
      expect(parsed.value, 'dark');
      expect(parsed.label, 'Dark', reason: 'the confirmation should read back the option the user recognizes');
    });

    test('a select given nothing usable does not silently take the first option', () {
      // `startsWith('')` is true of every option, so an empty term would write
      // whichever happened to be declared first.
      final entry = _entry(
        'themeMode',
        fieldType: 'select',
        value: 'system',
        options: [
          {'label': 'System', 'value': 'system'},
          {'label': 'Dark', 'value': 'dark'},
        ],
      );
      expect(parseSettingValue(entry, '---'), isA<UnparsedSettingValue>());
    });

    test('a select rejects an unknown option and names the real ones', () {
      final entry = _entry(
        'themeMode',
        fieldType: 'select',
        value: 'system',
        options: [
          {'label': 'System', 'value': 'system'},
          {'label': 'Dark', 'value': 'dark'},
        ],
      );
      final parsed = parseSettingValue(entry, 'purple');
      expect(parsed, isA<UnparsedSettingValue>());
      expect((parsed as UnparsedSettingValue).expected, contains('Dark'));
    });

    test("a secret's value is never echoed back", () {
      final entry = _entry('apiKey', fieldType: 'secret', value: 'hunter2');
      expect(
        settingValueLabel(entry),
        isNot(contains('hunter2')),
        reason: 'this string lands in a describe preview that sits on screen while the operator types',
      );
    });
  });
}
