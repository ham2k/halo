// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyboard shortcuts in named sets (docs/design/keyboard-shortcuts.md § Sets).
//
// The traps: a device's changes from before sets lost on the way in, or left
// behind in the old key to come back later; App Defaults taking a change
// and no longer being the app's own keys; a switch of sets that leaves the
// old keys in force; a MIDI control lost for good because the set in use
// lacked its command text for a while; and a file that lands in the set in
// use instead of as a set of its own.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/key_bindings_file.dart';
import 'package:ham2k_logger/services/key_bindings_service.dart';
import 'package:ham2k_logger/services/sets/cw_message_set_category.dart';
import 'package:ham2k_logger/services/sets/keyboard_shortcut_set_category.dart';
import 'package:ham2k_logger/services/sets/set_category.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

KeyChord chord(String text) => KeyChord.parse(text)!;

const appDefaults = KeyBindingsService.appDefaultsId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => keyBindings.value = LegacyKeyBindings());

  Future<HaLoServices> boot([Map<String, Object> prefs = const {}]) async {
    final services = (await makeHaLoServices(prefs: prefs)).services;
    await services.settings.setExperimentEnabled(keyBindingsExperiment, true);
    return services;
  }

  test("a device's changes from before sets are a set in use, taken over by the first write", () async {
    final before = const KeyBindingOverrides().withCommand('logging.wipe', [chord('F9')]).withText('20M', [chord('alt+2')]).withMidi('logging.wipe', [
      'note:1:60',
    ]);
    final services = await boot({KeyBindingsService.prefsKey: jsonEncode(before.toJson())});
    final service = services.keyBindingsService;

    expect(service.onAppDefaults, isFalse, reason: 'the keys the operator set up keep working');
    expect(keyBindings.value.chordsFor('logging.wipe'), [chord('F9')]);
    expect(service.sets.single.keys.text.keys, ['20M']);

    await KeyboardShortcutSetCategory(service).rename(service.activeSetId, 'Home');
    expect(service.sets.single.name, 'Home');
    expect(keyBindings.value.chordsFor('logging.wipe'), [chord('F9')]);
    // Left there, the old keys would come back as a set of their own the
    // moment the sets entry read as empty — cleared, or unreadable.
    final stored = jsonDecode(services.settings.prefs.getString(KeyBindingsService.prefsKey)!) as Map;
    expect(stored.keys, ['midi'], reason: 'the device keeps its MIDI controls, and only those');
    expect(services.keyBindingsService.midiCommandFor('note:1:60'), 'logging.wipe');
  });

  test('App Defaults are the shipped keys, and stay them', () async {
    final service = (await boot()).keyBindingsService;
    final category = KeyboardShortcutSetCategory(service);
    expect(service.onAppDefaults, isTrue, reason: 'a device with no changes starts on them');
    expect(category.sets.first.id, appDefaults);
    expect(category.canRename(appDefaults) || category.canDelete(appDefaults), isFalse);
    await expectLater(service.setOverrides(const KeyBindingOverrides().withCommand('logging.wipe', [chord('F9')])), throwsStateError);
    expect(service.overrides.commands, isEmpty);

    // A device's MIDI controls are no set's, so they bind on App Defaults too.
    await service.setOverrides(const KeyBindingOverrides().withMidi('logging.wipe', ['note:1:60']));
    expect(service.midiCommandFor('note:1:60'), 'logging.wipe');
  });

  test('picking another set puts its keys in force, and deleting the set in use falls back beside it', () async {
    final service = (await boot()).keyBindingsService;
    final category = KeyboardShortcutSetCategory(service);
    final contest = (await category.duplicate(appDefaults, 'Contest'))!;
    await category.use(contest);
    await service.setOverrides(const KeyBindingOverrides().withCommand('logging.wipe', [chord('F9')]));
    final shipped = const KeyBindingOverrides().resolve().chordsFor('logging.wipe');

    await category.use(appDefaults);
    expect(keyBindings.value.chordsFor('logging.wipe'), shipped);
    await category.use(contest);
    expect(keyBindings.value.chordsFor('logging.wipe'), [chord('F9')]);

    final copy = (await category.duplicate(contest, 'Contest copy'))!;
    expect([for (final set in category.sets) set.id], [appDefaults, contest, copy], reason: 'a copy lands after what it copies');
    expect(service.sets.last.keys.commands, service.sets.first.keys.commands);

    await category.delete(contest);
    expect(category.activeId, copy);
    await category.delete(copy);
    expect(category.activeId, appDefaults, reason: 'the keys have to come from somewhere');
    expect(keyBindings.value.chordsFor('logging.wipe'), shipped);
  });

  test("a MIDI control on command text the set in use lacks waits for it, through that set's Reset All", () async {
    final service = (await boot()).keyBindingsService;
    final category = KeyboardShortcutSetCategory(service);
    final bands = (await category.duplicate(appDefaults, 'Bands'))!;
    final plain = (await category.duplicate(appDefaults, 'Plain'))!;
    await category.use(bands);
    await service.setOverrides(service.overrides.withText('20M', [chord('alt+2')]).withMidi(textCommandId('20M'), ['note:1:60']));

    await category.use(plain);
    expect(service.midiCommandFor('note:1:60'), isNull, reason: 'it would run a command no row shows');
    // Reset All's way of clearing a set: no keys, and the controls bound to
    // the command text it drops.
    await service.setOverrides(KeyBindingOverrides(midi: service.overrides.midiKeptWith(const {})));

    await category.use(bands);
    expect(service.midiCommandFor('note:1:60'), textCommandId('20M'));
  });

  test('dropping command text keeps its MIDI control where another set still holds the text', () async {
    final service = (await boot()).keyBindingsService;
    final category = KeyboardShortcutSetCategory(service);
    final contest = (await category.duplicate(appDefaults, 'Contest'))!;
    await category.use(contest);
    await service.setOverrides(service.overrides.withText('CQ', [chord('alt+1')]).withMidi(textCommandId('CQ'), ['note:1:60']));
    final casual = (await category.duplicate(contest, 'Casual'))!;
    await category.use(casual);

    await service.setOverrides(service.overrides.withoutText('CQ'));
    await category.use(contest);
    expect(service.midiCommandFor('note:1:60'), textCommandId('CQ'), reason: "Contest's CQ row still shows the control");

    // Taking the control off a row the set keeps is the operator's own
    // edit, and must not come back for another set holding the same text.
    final copy = (await category.duplicate(contest, 'Contest copy'))!;
    await service.setOverrides(service.overrides.withMidi(textCommandId('CQ'), const []));
    await category.use(copy);
    expect(service.midiCommandFor('note:1:60'), isNull);
  });

  group('files', () {
    late KeyBindingsService service;

    setUp(() async => service = (await boot()).keyBindingsService);

    test('a set comes back with its keys and its name, as a new set not in use', () async {
      final category = KeyboardShortcutSetCategory(service);
      final home = (await category.duplicate(appDefaults, 'Home'))!;
      await category.use(home);
      await service.setOverrides(const KeyBindingOverrides().withCommand('logging.wipe', [chord('F9')]).withText('20M', [chord('alt+2')]));

      final file = await category.export(home);
      expect(file.filename, 'Keyboard Shortcuts Home.$keyBindingsFileExtension');
      final id = (await category.import(Uint8List.fromList(utf8.encode(file.content as String)), file.filename))!;
      expect(id, isNot(home));
      expect(category.nameOf(id), 'Home 2', reason: 'a name already taken is numbered');
      expect(category.activeId, home, reason: 'an import is not put in use');
      final imported = service.sets.firstWhere((set) => set.id == id).keys;
      expect(imported.commands, {
        'logging.wipe': [chord('F9')],
      });
      expect(imported.text.keys, ['20M']);
    });

    test('a file with no name is named for the file, and one called off adds nothing', () async {
      const text = 'ham2k-keys: 1\ncommands:\n  logging.wipe: [F9]\n';
      final bytes = Uint8List.fromList(utf8.encode(text));
      final id = await KeyboardShortcutSetCategory(service).import(bytes, 'Keyboard Shortcuts KI2D.h2kkey');
      expect(KeyboardShortcutSetCategory(service).nameOf(id!), 'Keyboard Shortcuts KI2D');

      final count = service.sets.length;
      final cancelled = KeyboardShortcutSetCategory(service, translate: (_) async => null);
      expect(await cancelled.import(bytes, 'other.h2kkey'), isNull);
      expect(service.sets.length, count);
    });

    test('a file that is not a shortcuts file is refused as a set file, for what it is', () async {
      // Both kinds take `.yaml`, so each one's picker offers the other's
      // files: one is another kind of set, not "not a set".
      final cw = await CwMessageSetCategory(service.settings).export(service.settings.cwMessageSets.first.id);
      await expectLater(
        KeyboardShortcutSetCategory(service).import(Uint8List.fromList(utf8.encode(cw.content as String)), cw.filename),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.wrongKind)),
      );
      final keys = await KeyboardShortcutSetCategory(service).export(appDefaults);
      await expectLater(
        CwMessageSetCategory(service.settings).import(Uint8List.fromList(utf8.encode(keys.content as String)), keys.filename),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.wrongKind)),
      );
      await expectLater(
        KeyboardShortcutSetCategory(service).import(Uint8List.fromList(utf8.encode('ham2k-layout: 1\n')), 'layout.yaml'),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.unreadable)),
      );
      await expectLater(
        KeyboardShortcutSetCategory(service).import(Uint8List.fromList(utf8.encode('ham2k-keys: 99\n')), 'new.h2kkey'),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.newerVersion)),
      );
    });
  });
}
