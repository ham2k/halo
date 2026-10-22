// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `.h2kkey` files (docs/design/keyboard-shortcuts.md § Files): what one
// carries, what is refused with a reason, and how a file written on one
// keyboard reads on another.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/key_bindings_file.dart';
import 'package:ham2k_logger/services/key_bindings_service.dart';

KeyChord chord(String text) => KeyChord.parse(text)!;

Matcher refusedFor(KeyBindingsFileProblem problem) => throwsA(isA<KeyBindingsFileException>().having((e) => e.problem, 'problem', problem));

void main() {
  test('comes back as it went out, with the platform it was written on', () {
    final overrides = const KeyBindingOverrides()
        .withCommand('logging.wipe', [chord('alt+Backspace')])
        .withCommand('app.toggleTheme', const [])
        .withText('20M', [chord('cmd+alt+2')])
        .withText('ESM OFF', [chord('F10')]);
    final file = KeyBindingsFile.parse(KeyBindingsFile(platform: 'macos', overrides: overrides).toYaml());
    expect(file.platform, 'macos');
    expect(file.overrides.commands, overrides.commands);
    expect(file.overrides.text, overrides.text);
  });

  test('reads a file written by hand, in the names a person would use', () {
    final file = KeyBindingsFile.parse('''
ham2k-keys: 1
platform: windows
commands:
  keyer.message1: [F1, Alt+1]
text:
  SPOT: [control+shift+S]
''');
    expect(file.overrides.commands['keyer.message1'], [chord('F1'), chord('alt+1')]);
    expect(file.overrides.text['SPOT'], [chord('ctrl+shift+S')]);
  });

  test('keeps what reads and names what does not', () {
    final file = KeyBindingsFile.parse('''
ham2k-keys: 1
commands:
  app.toggleTheme: [cmd+shift+T, hyper+T]
  app.noSuchCommand: [cmd+J]
''');
    expect(file.overrides.commands['app.toggleTheme'], [chord('cmd+shift+T')]);
    expect(file.unreadable, ['hyper+T']);
    expect(file.unknownCommands, ['app.noSuchCommand']);
  });

  // The recorder refuses these keys; a hand-written file must not be the
  // way round it — Enter would toggle the theme instead of logging.
  test('imports no key the app keeps for itself, and names the ones left out', () {
    final file = KeyBindingsFile.parse('''
ham2k-keys: 1
commands:
  app.toggleTheme: [Enter]
  logView.find: [F9, Escape]
text:
  SPOT: [S]
''');
    final (:overrides, :refused) = file.importable(const {});
    expect(overrides.commands.containsKey('app.toggleTheme'), isFalse, reason: 'every chord refused: the defaults stand');
    expect(overrides.commands['logView.find'], [chord('F9')]);
    expect(overrides.text['SPOT'], isEmpty);
    expect(refused, unorderedEquals([chord('Enter'), chord('Escape'), chord('S')]));
  });

  test('drops command text with no command in it, rather than a key that runs nothing', () {
    final file = KeyBindingsFile.parse('ham2k-keys: 1\ntext:\n  " ; ": [F9]\n  CW: [F10]\n');
    expect(file.overrides.text.keys, ['CW']);
    expect(file.unreadable, ['" ; "']);
  });

  group('is refused, saying why, when it is', () {
    test('not YAML', () => expect(() => KeyBindingsFile.parse('commands: [unclosed'), refusedFor(KeyBindingsFileProblem.notYaml)));
    test('not a shortcuts file', () => expect(() => KeyBindingsFile.parse('ham2k-layout: 1\nwide: {}'), refusedFor(KeyBindingsFileProblem.notKeysFile)));
    test('from a newer version', () => expect(() => KeyBindingsFile.parse('ham2k-keys: 2'), refusedFor(KeyBindingsFileProblem.newerVersion)));
    test('the wrong shape', () => expect(() => KeyBindingsFile.parse('ham2k-keys: 1\ncommands: [F1]'), refusedFor(KeyBindingsFileProblem.malformed)));

    // A few lines of nested aliases expand to billions of values.
    test('too large once its aliases expand', () {
      final levels = StringBuffer('ham2k-keys: 1\na0: &a0 [x, x, x, x, x, x, x, x, x, x]\n');
      for (var i = 1; i < 8; i++) {
        levels.writeln('a$i: &a$i [${List.filled(10, '*a${i - 1}').join(', ')}]');
      }
      expect(() => KeyBindingsFile.parse('$levels'), refusedFor(KeyBindingsFileProblem.tooLarge));
    });
  });

  group('across keyboards', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('a Mac file on Windows trades ⌘ for Ctrl, and leaves ⌥ alone', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final file = KeyBindingsFile.parse('ham2k-keys: 1\nplatform: macos\ntext:\n  20M: [cmd+alt+2]\n  40M: [ctrl+4]\n');
      final translation = suggestedTranslation(file.overrides.platformModifiers, file.platform);
      expect(translation, {KeyModifier.cmd: KeyModifier.ctrl, KeyModifier.ctrl: KeyModifier.meta});
      final read = file.overrides.translated(translation);
      expect(read.text['20M'], [chord('ctrl+alt+2')]);
      expect(read.text['40M'], [chord('meta+4')], reason: 'Ctrl on a Mac is nobody’s command key, so it lands on the spare one');
    });

    test('a Windows file on a Mac trades Ctrl for ⌘', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final translation = suggestedTranslation({KeyModifier.ctrl, KeyModifier.meta}, 'windows');
      expect(translation, {KeyModifier.ctrl: KeyModifier.cmd, KeyModifier.meta: KeyModifier.ctrl});
    });

    test('a file from the same kind of keyboard reads as written', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(suggestedTranslation({KeyModifier.ctrl, KeyModifier.meta}, 'windows'), {KeyModifier.ctrl: KeyModifier.ctrl, KeyModifier.meta: KeyModifier.meta});
    });

    test('alt and shift are never asked about', () {
      final overrides = const KeyBindingOverrides().withText('20M', [chord('alt+shift+2')]);
      expect(overrides.platformModifiers, isEmpty);
    });
  });

  // One device's exports for several profiles must not overwrite each other,
  // and a portable call's slash would read as a folder.
  test("is named for the profile's callsign, safely", () {
    expect(keyBindingsFileStem('KI2D'), 'Keyboard Shortcuts KI2D');
    expect(keyBindingsFileStem('KI2D/P'), 'Keyboard Shortcuts KI2D-P');
    expect(keyBindingsFileStem(''), 'Keyboard Shortcuts');
  });

  test('iOS is sent the ⌘ chords the app-wide handler runs, and only those', () {
    final bindings = const KeyBindingOverrides()
        .withText('20M', [chord('cmd+alt+2'), chord('F10')])
        .withCommand('logView.find', [chord('cmd+F')])
        .resolve(TargetPlatform.iOS);
    final sent = iosKeyCommands(bindings);
    expect(
      sent,
      anyElement(
        equals({
          'id': 'text:20M',
          'input': '2',
          'modifiers': ['cmd', 'alt'],
        }),
      ),
    );
    expect(sent.where((c) => c['id'] == 'text:20M'), hasLength(1), reason: 'F10 is no ⌘ chord, and reaches Flutter on its own');
    expect(sent.where((c) => c['id'] == 'logView.find'), isEmpty, reason: 'the views run Find from their own handlers, which a native command never reaches');
    expect(
      sent,
      anyElement(
        equals({
          'id': 'app.commandDialog',
          'input': 'k',
          'modifiers': ['cmd'],
        }),
      ),
    );
  });
}
