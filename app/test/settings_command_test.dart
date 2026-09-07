// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-151: SET/SHOW/HIDE end to end — the real settings-commands extension,
// running in the real JS runtime, against the real settings catalog.
//
// The point of running it whole rather than stubbing the host call is the
// re-entrancy: `interpret` is a hook call that AWAITS `host.searchSettings`,
// and answering that call re-enters the same runtime to read every extension
// settingsPanel. Nothing else in the app does that, and a stubbed
// `onSearchSettings` would pass happily while the real one deadlocked.
//
// The rest is the behaviour a stub could never check either: that a command
// resolves against the settings actually declared by this app, so a renamed
// or retired setting shows up here as a failure rather than as a command that
// silently stops working.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    // RadioSettingsGroup contributes nothing at all without the Station
    // Configuration experiment, so the zero-beat settings these tests name
    // would simply not be in the catalog — which is itself the behaviour
    // 'a group that declines to contribute' below pins down.
    await settings.setExperimentEnabled('gato', true);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionService();
    services = HaLoServices(db, settings, extensions: extensions);
    await extensions.start();
  });

  Future<Map<String, dynamic>?> interpret(String input) async {
    final entries = await services.extensions.host!
        .invokeHookAll('command', method: 'interpret', args: {'input': input});
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  Map<String, dynamic>? actionOf(Map<String, dynamic>? result, String name) {
    final commands = result?['commands'];
    if (commands is! List) return null;
    for (final command in commands) {
      if (command is Map && command[name] is Map) return (command[name] as Map).cast<String, dynamic>();
    }
    return null;
  }

  group('SET', () {
    test('names a real setting and reports its current value', () async {
      // avoidZeroBeat defaults on, and carries the alias `zeroBeat` precisely
      // so this query doesn't land on the longer `zeroBeatRangeHz`.
      final result = await interpret('SET ZEROBEAT');
      expect(result, isNotNull);
      expect(result!['describe'], isA<String>());
      expect(actionOf(result, 'openSettings')?['keys'], ['avoidZeroBeat'],
          reason: 'no value was given, so Enter should open the setting rather than change anything');
    });

    test('a value that parses becomes an updateSetting carrying the coerced value', () async {
      // Starting state stated, never assumed: this setting's default has
      // already flipped once on main, and a test that silently rode the
      // default failed for a reason that had nothing to do with what it tests.
      await settings.setAvoidZeroBeat(true);
      final result = await interpret('SET ZEROBEAT N');
      expect(actionOf(result, 'updateSetting'), {'key': 'avoidZeroBeat', 'value': false});
      expect(result!['confirm'], isA<String>());
    });

    test('a select takes an option by name', () async {
      final result = await interpret('SET THEME DARK');
      expect(actionOf(result, 'updateSetting'), {'key': 'themeMode', 'value': 'dark'});
    });

    test('a value the setting cannot take errors instead of opening a form', () async {
      final result = await interpret('SET ZEROBEAT MAYBE');
      expect(result, isNotNull);
      expect(result!['error'], isA<String>());
      expect(result['commands'], isNull);
    });

    test('an already-set value says so AFTER Enter, not just before it', () async {
      // A result with no `confirm` still counts as a completed command: the
      // field clears and the ⌘K palette closes, taking the "already On" line
      // the operator was reading with it — so Enter reads as having done
      // nothing at all. `confirm` is what survives execution to explain.
      await settings.setAvoidZeroBeat(true);
      final result = await interpret('SET ZEROBEAT Y');
      expect(result?['confirm'], isA<String>());
      expect(result!['confirm'], result['describe'],
          reason: 'the same words before and after Enter — nothing happened in between');
    });

    test('a value already in place is reported, not re-written', () async {
      await settings.setAvoidZeroBeat(true);
      final result = await interpret('SET ZEROBEAT Y');
      expect(result, isNotNull);
      // `expectsParams` would mean the query matched NOTHING — which also has
      // no commands, and would let this pass without the setting ever being
      // found. Pin the match down before reading anything into the silence.
      expect(result!['expectsParams'], isNot(isTrue), reason: 'the setting must actually have been found');
      expect(result['describe'], isA<String>());
      expect(result['commands'], isNull,
          reason: 'confirming a change that did not happen is how confirmations stop being believed');
    });

    test('an unmatched name stays a command awaiting input, never a callsign', () async {
      final result = await interpret('SET NOTHINGLIKETHIS');
      expect(result, isNotNull, reason: 'falling back to null would let Enter log the text as a QSO');
      expect(result!['expectsParams'], isTrue);
      expect(result['commands'], isNull);
    });

    test('bare SET asks for a parameter', () async {
      final result = await interpret('SET');
      expect(result, isNotNull);
      expect(result!['expectsParams'], isTrue);
      expect(result['commands'], isNull);
    });

    test('every matching setting goes into the dialog, best first — not just the winner', () async {
      // `rst` is an exact alias of defaultReport, so this query has a clear
      // winner AND four weaker matches. Offering only the winner would make
      // the operator guess a different word to reach the others, when the
      // command already knows exactly what they are.
      final result = await interpret('SET RST');
      final keys = (actionOf(result, 'openSettings')?['keys'] as List?)?.cast<String>();
      expect(keys, isNotNull);
      expect(keys!.first, 'defaultReport', reason: 'the preview names the best match, so it must lead the list');
      expect(keys.length, greaterThan(1));
      expect(keys, containsAll(['showRSTFields', 'jumpAfterRST']),
          reason: 'these match "rst" too and the Settings search box lists them — so must this');
    });

    test('a single-match query still opens just that setting', () async {
      // The counterweight to the test above: "all matches" must not mean
      // "always a list". ZEROBEAT names exactly one setting.
      final result = await interpret('SET ZEROBEAT');
      expect(actionOf(result, 'openSettings')?['keys'], ['avoidZeroBeat']);
    });

    test('a query naming several settings equally offers the choice instead of guessing', () async {
      // Every `show…` key starts with this, and none is named exactly "show",
      // so there is no basis to prefer one of them.
      final result = await interpret('SET SHOW');
      final keys = actionOf(result, 'openSettings')?['keys'];
      expect(keys, isA<List>());
      expect((keys as List).length, greaterThan(1),
          reason: 'an ambiguous query must list its candidates rather than silently taking the first');
    });

    test('an exact alias resolves a query that would otherwise tie', () async {
      // "report" is a substring of defaultReport, defaultReportCW and
      // defaultReportFT8 alike; the alias on defaultReport is the only thing
      // making this one setting rather than three.
      final result = await interpret('SET REPORT 59');
      expect(actionOf(result, 'updateSetting'), {'key': 'defaultReport', 'value': '59'});
    });

    test('a setting can be named in the words the settings screen uses', () async {
      // "Avoid Zero Beat" is what the operator reads on screen; typing it that
      // way must work as well as the run-together key does.
      await settings.setAvoidZeroBeat(true);
      final result = await interpret('SET AVOID ZERO BEAT N');
      expect(actionOf(result, 'updateSetting'), {'key': 'avoidZeroBeat', 'value': false});
    });

    test('unrelated input does not match', () async {
      expect(await interpret('SETTLE'), isNull);
    });
  });

  group('SHOW / HIDE', () {
    test('SHOW turns a show-named toggle on', () async {
      expect(settings.showGridField, isFalse);
      final result = await interpret('SHOW GRID');
      expect(actionOf(result, 'updateSetting'), {'key': 'showGridField', 'value': true});
    });

    test('HIDE turns it off', () async {
      await settings.setShowGridField(true);
      final result = await interpret('HIDE GRID');
      expect(actionOf(result, 'updateSetting'), {'key': 'showGridField', 'value': false});
    });

    test('SHOW does not reach a setting that is not a visibility toggle', () async {
      // THEME is a select — SET's territory, not SHOW's. Matching it here
      // would mean SHOW had no value to write and would open a form for a
      // command the operator expected to just flip something.
      final result = await interpret('SHOW THEME');
      expect(result?['expectsParams'], isTrue);
      expect(result?['commands'], isNull);
    });

    test('bare SHOW asks for a parameter', () async {
      final result = await interpret('SHOW');
      expect(result, isNotNull);
      expect(result!['expectsParams'], isTrue);
    });
  });

  group('the ⌘K palette', () {
    test('lists all three commands, each asking for its parameter', () async {
      final entries = await services.extensions.host!.invokeHookAll('command', method: 'catalog', args: {});
      final listed = <String, Map<String, dynamic>>{};
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        for (final item in entry['value'] as List) {
          if (item is Map) listed[item['command'] as String] = item.cast<String, dynamic>();
        }
      }
      for (final command in ['SET', 'SHOW', 'HIDE']) {
        expect(listed, contains(command), reason: 'a command absent from the catalog is undiscoverable — the '
            'palette is where someone who does not know the syntax finds it');
        expect(listed[command]!['expectsParams'], isTrue,
            reason: 'picking $command from the palette must leave the field open, not run a bare $command');
        expect(listed[command]!['suggest'], isNot(isTrue),
            reason: 'these change settings, so they stay out of the empty-field "Try" samples (HALO-87)');
      }
    });
  });

  group('the catalog reached through the bridge', () {
    test('a dev-mode-only setting is invisible to SET until developer mode is on', () async {
      // smartVfoSnap's tuning knobs are emitted only in developer mode. The
      // catalog is rebuilt per call, so the SAME query has to change its
      // answer mid-session — which is the property a cached catalog would
      // quietly break.
      await settings.setSmartVfoSnap(true);
      final before = await interpret('SET SNAPDEBOUNCE');
      expect(before?['expectsParams'], isTrue, reason: 'not reachable while developer mode is off');

      await settings.setDeveloperMode(true);
      final after = await interpret('SET SNAPDEBOUNCE');
      expect(after?['expectsParams'], isNot(isTrue),
          reason: 'the same query must resolve once developer mode makes the setting real');
    });

    test('a group that declines to contribute takes its settings out of reach', () async {
      // RadioSettingsGroup returns nothing at all without the Station
      // Configuration experiment. Nothing filters its settings out by name —
      // they are absent because the group never declared them, which is what
      // keeps the catalog honest as groups come and go.
      await settings.setExperimentEnabled('gato', false);
      final result = await interpret('SET ZEROBEAT');
      expect(result?['expectsParams'], isTrue);
      expect(result?['commands'], isNull);
    });
  });
}
