// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-53: call-notes' settingsPanel, against the REAL bundled extension
// (not a mocked host, like settings_panel_dispatch_test.dart's fixtures) —
// this is what actually proves `onActivation` can `await host.getSettings()`
// before its `registerHook` calls land, a pattern no other shipped
// extension uses yet (kernel.ts dispatches `onActivation` fire-and-forget,
// never awaiting it — see extensions/lookups/call-notes/src/index.ts's
// header comment). A mocked host can't catch a timing assumption like that;
// only the real bundle, on the real kernel, can.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late SettingsService settings;
  late ExtensionService extensions;

  Future<void> seedCallNotesSettings(Map<String, dynamic> values) async {
    SharedPreferences.setMockInitialValues({'settings.extension_call-notes': jsonEncode(values)});
    settings = SettingsService(await SharedPreferences.getInstance());
    extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings;
    await extensions.start();
  }

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('with no settings saved yet, only the builtin dataFile registers', () async {
    await seedCallNotesSettings({});
    final host = extensions.host;
    expect(host, isNotNull, reason: 'extension runtime failed to boot');

    final defs = await host!.invokeHookAll('dataFile', method: 'getDefinition');
    final callNotesDefs = defs.where((e) => (e['value'] as Map?)?['category'] == 'call-notes').toList();
    expect(callNotesDefs, hasLength(1), reason: 'no customFiles saved yet, so only the one builtin registers');
    expect((callNotesDefs.first['value'] as Map)['key'], 'hams-of-note');
  });

  test('a customFiles entry saved before boot becomes its own registered dataFile hook', () async {
    // Proves onActivation's `await host.getSettings()` really does complete
    // BEFORE its registerHook('dataFile', ...) calls run — a mocked host
    // can't distinguish "ran before" from "ran but too late", since nothing
    // else queries the registration in between; only the real kernel's
    // actual scheduling can answer that.
    await seedCallNotesSettings({
      'customFiles': [
        {'name': 'My Club Notes', 'location': 'https://example.com/my-club-notes.txt'},
      ],
    });
    final host = extensions.host!;

    final defs = await host.invokeHookAll('dataFile', method: 'getDefinition');
    final callNotesDefs = defs.where((e) => (e['value'] as Map?)?['category'] == 'call-notes').toList();
    expect(callNotesDefs, hasLength(2), reason: 'the builtin plus the one custom file');

    final customDef = callNotesDefs.firstWhere((e) => (e['value'] as Map)['key'] != 'hams-of-note');
    expect((customDef['value'] as Map)['name'], 'My Club Notes');
    expect((customDef['value'] as Map)['url'], 'https://example.com/my-club-notes.txt');
  });

  test("the settingsPanel definition lists the builtin's checkbox, the custom file, and the help block", () async {
    await seedCallNotesSettings({
      'customFiles': [
        {'name': 'My Club Notes', 'location': 'https://example.com/my-club-notes.txt'},
      ],
    });

    final panels = await extensions.getSettingsPanels();
    final panel = panels.firstWhere((p) => p['panelKey'] == 'call-notes');
    expect(panel['kind'], 'dynamic');
    // Declared by getPanels() (HALO-53 followup) so the host knows the real
    // title and can skip this panel in its own top-level nav without first
    // fetching getDefinition.
    expect(panel['title'], 'Callsign Notes');
    expect(panel['sidebar'], false);
    expect(panel['dataFilesSection'], true, reason: 'this is what makes it show up under the data sources');

    final definition = await extensions.getSettingsPanelDefinition(hookKey: 'call-notes', panelKey: 'call-notes', kind: 'dynamic');
    expect(definition!['title'], isNull, reason: "the panel's own title (above) already labels the modal — no in-body title to double it");
    final elements = (definition['elements'] as List).cast<Map<String, dynamic>>();

    final headers = elements.where((el) => el['type'] == 'header').toList();
    expect(headers, hasLength(2), reason: 'Built-in Notes and Custom note files sections');

    final checkbox = elements.firstWhere((el) => el['key'] == 'enabled.hams-of-note');
    expect(checkbox['fieldType'], 'checkbox');
    expect(checkbox['value'], true, reason: 'enabled by default when settings say nothing either way');

    final list = elements.firstWhere((el) => el['key'] == 'customFiles');
    expect(list['fieldType'], 'list');
    expect((list['value'] as List).first, {'name': 'My Club Notes', 'location': 'https://example.com/my-club-notes.txt'});
    expect(list['restartOnChange'], true);
    expect(list['inline'], true);
    expect(list['itemLabel'], isNotEmpty);
    expect(
      list['itemTitle'],
      r'${name}',
      reason: r'the renderer templates ${key}, not {{key}} — a Mustache-style template would show literally, unsubstituted',
    );

    final help = elements.firstWhere((el) => el['type'] == 'markdown');
    expect(help['collapsible'], true);
    expect(help['title'], isNotEmpty);
  });

  test('disabling the builtin note commits without a restart, and getDefinition reflects it immediately', () async {
    await seedCallNotesSettings({});
    final hostBefore = extensions.host;

    await extensions.commitSettingsFieldValue(
      kind: 'dynamic',
      hookKey: 'call-notes',
      panelKey: 'call-notes',
      fieldKey: 'enabled.hams-of-note',
      value: false,
      state: const {},
    );

    expect(extensions.host, same(hostBefore), reason: 'a plain enable/disable toggle needs no restart');

    final definition = await extensions.getSettingsPanelDefinition(hookKey: 'call-notes', panelKey: 'call-notes', kind: 'dynamic');
    final checkbox = (definition!['elements'] as List).cast<Map<String, dynamic>>().firstWhere((el) => el['key'] == 'enabled.hams-of-note');
    expect(checkbox['value'], false);
  });

  test('committing customFiles restarts the runtime, and the new file becomes a registered dataFile hook', () async {
    await seedCallNotesSettings({});
    final hostBefore = extensions.host;

    await extensions.commitSettingsFieldValue(
      kind: 'dynamic',
      hookKey: 'call-notes',
      panelKey: 'call-notes',
      fieldKey: 'customFiles',
      value: [
        {'name': 'My Club Notes', 'location': 'https://example.com/my-club-notes.txt'},
      ],
      state: const {},
      restartOnChange: true,
    );

    expect(extensions.host, isNot(same(hostBefore)), reason: 'restartOnChange must actually replace the runtime');

    final defs = await extensions.host!.invokeHookAll('dataFile', method: 'getDefinition');
    final callNotesDefs = defs.where((e) => (e['value'] as Map?)?['category'] == 'call-notes').toList();
    expect(callNotesDefs, hasLength(2), reason: 're-activation picked up the newly-committed custom file');
  });

  /// Feeds `body` through the real hams-of-note dataFile hook's own
  /// `rawToJSONData` → `onLoadRawData` pipeline — bypassing
  /// DataFileManager.processDataFile's disk-cache write (which needs a
  /// mocked path_provider these tests have no reason to set up) while still
  /// exercising the same JS-side parse-and-load call chain the real app
  /// makes.
  Future<void> loadHamsOfNoteBody(String body) async {
    final host = extensions.host!;
    final processed = await host.invokeHook('dataFile', key: 'hams-of-note', method: 'rawToJSONData', args: {'body': body, 'url': '', 'options': const {}});
    await host.invokeHook('dataFile', key: 'hams-of-note', method: 'onLoadRawData', args: processed);
  }

  test('a call noted in an enabled builtin surfaces through the real lookup fan-out', () async {
    await seedCallNotesSettings({});
    await loadHamsOfNoteBody('KI2D Test Note');

    final result = await extensions.lookupCall('KI2D', qso: const {}, operation: const {}, online: false);
    final lookups = (result?['lookups'] as List).cast<Map<String, dynamic>>();
    final callNotesResult = lookups.firstWhere((l) => l['source'] == 'call-notes');
    expect(callNotesResult['note'], contains('Test Note'));
  });

  test('disabling the builtin excludes its notes from the lookup fan-out, with no restart needed', () async {
    await seedCallNotesSettings({});
    await loadHamsOfNoteBody('KI2D Test Note');
    final hostBefore = extensions.host;

    await extensions.commitSettingsFieldValue(
      kind: 'dynamic',
      hookKey: 'call-notes',
      panelKey: 'call-notes',
      fieldKey: 'enabled.hams-of-note',
      value: false,
      state: const {},
    );
    expect(extensions.host, same(hostBefore), reason: 'the in-memory enabled flag updates immediately, no restart');

    final result = await extensions.lookupCall('KI2D', qso: const {}, operation: const {}, online: false);
    final lookups = (result?['lookups'] as List? ?? const []).cast<Map<String, dynamic>>();
    expect(
      lookups.where((l) => l['source'] == 'call-notes'),
      isEmpty,
      reason: 'a disabled builtin must not surface in lookup results, even though its data is still loaded/cached',
    );
  });

  test('disabling the builtin also excludes its calls from the callNotes directory hook', () async {
    await seedCallNotesSettings({});
    await loadHamsOfNoteBody('KI2D Test Note');
    final host = extensions.host!;

    Future<List<String>> allCalls() async {
      final entries = await host.invokeHookAll('callNotes', method: 'allCalls');
      final entry = entries.firstWhere((e) => e['ok'] == true);
      return (entry['value'] as List).cast<String>();
    }

    expect(await allCalls(), contains('KI2D'), reason: 'enabled by default, so it should show up in the directory');

    await extensions.commitSettingsFieldValue(
      kind: 'dynamic',
      hookKey: 'call-notes',
      panelKey: 'call-notes',
      fieldKey: 'enabled.hams-of-note',
      value: false,
      state: const {},
    );

    expect(
      await allCalls(),
      isNot(contains('KI2D')),
      reason:
          'allCalls (dev-commands\' SEED draws from this) must stay consistent with entriesFor — a call whose '
          'notes are hidden by a disabled source should not still appear via the directory hook',
    );
  });
}
